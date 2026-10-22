import {createHash} from 'node:crypto';
export class SourceError extends Error {
 constructor(code,status=503){super(code);this.code=code;this.status=status;}
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
// Shared across adapters in one isolate. DB job leases additionally bound imports across isolates.
const hostQueues=new Map();
async function pace(host,ms,wait){
 const last=hostQueues.get(host)||Promise.resolve();
 const next=last.catch(()=>{}).then(()=>wait(ms));hostQueues.set(host,next);
 await next;
}
export class SourceTransport {
 constructor({fetchImpl=fetch,wait=sleep,timeoutMs=20000,random=Math.random,requestBudget=16,byteBudget=4*1024*1024}={}){
  Object.assign(this,{fetchImpl,wait,timeoutMs,random,requestBudget,byteBudget});this.cache=new Map();this.breakers=new Map();this.metrics={requests:0,cache_hits:0,bytes:0,retries:0};
 }
 resetBudget(){this.metrics={requests:0,cache_hits:0,bytes:0,retries:0};this.deadline=null;}
 async get(source,path,params={}){
  this.deadline??=Date.now()+90000;
  if(Date.now()>=this.deadline)throw new SourceError('source_budget_exceeded',429);
  if(!source.enabled||['LINK_ONLY','FUTURE_DISABLED'].includes(source.usage_mode))throw new SourceError('source_disabled',403);
  const url=new URL(path,source.base_url);
  if(url.origin!==new URL(source.base_url).origin||url.protocol!=='https:'||url.username||url.password)throw new SourceError('unsafe_source_url',400);
  for(const [k,v] of Object.entries(params))if(v!==null&&v!==undefined)url.searchParams.set(k,String(v));
  const key=url.href,b=this.breakers.get(source.source_id)||{failures:0,until:0};
  if(b.until>Date.now())throw new SourceError('source_unavailable');
  const cached=this.cache.get(key),headers={Accept:'application/json, application/xml, text/xml','User-Agent':'DawaHayah/0.2 (+https://github.com/moataz77549-byte/Dawaa)'};
  if(cached?.etag)headers['If-None-Match']=cached.etag;
  if(cached?.last_modified)headers['If-Modified-Since']=cached.last_modified;
  for(let attempt=0;attempt<3;attempt++){
   let retryAfter=0;
   try{
    await pace(url.host,1000/(source.rate_limit?.requests_per_second||1),this.wait);
    if(this.metrics.requests>=this.requestBudget)throw new SourceError('source_budget_exceeded',429);
    this.metrics.requests++;
    const response=await this.fetchImpl(url,{headers,redirect:'error',signal:AbortSignal.timeout(Math.max(1,Math.min(this.timeoutMs,this.deadline-Date.now())))});
    if(response.status===304&&cached){this.metrics.cache_hits++;return {...cached,fetched_at:new Date().toISOString(),cache_hit:true};}
    if(response.status===404){await response.body?.cancel();throw new SourceError('source_not_found',404);}
    if(response.status===429||response.status>=500){retryAfter=Math.min(5000,Math.max(0,Number(response.headers.get('retry-after'))*1000||0));await response.body?.cancel();throw new SourceError('source_unavailable');}
    if(response.status!==200){await response.body?.cancel();throw new SourceError('source_unavailable');}
    const type=response.headers.get('content-type')||'';
    if(!/json|xml/i.test(type)){await response.body?.cancel();throw new SourceError('source_schema_error',502);}
    const chunks=[];let bytes=0;
    if(!response.body)throw new SourceError('source_schema_error',502);
    const reader=response.body.getReader();
    try{for(;;){const {done,value}=await reader.read();if(done)break;bytes+=value.length;this.metrics.bytes+=value.length;if(this.metrics.bytes>this.byteBudget)throw new SourceError('source_budget_exceeded',429);if(bytes>2*1024*1024)throw new SourceError('source_response_too_large',502);chunks.push(value);}}
    finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
    const raw=Buffer.concat(chunks),text=new TextDecoder('utf-8',{fatal:true}).decode(raw);

    const value={text,content_type:type,fetched_at:new Date().toISOString(),raw_payload_hash:createHash('sha256').update(raw).digest('hex'),source_url:key,etag:response.headers.get('etag'),last_modified:response.headers.get('last-modified'),cache_hit:false};
    // Never retain labels, summaries or abstracts in the conditional-response cache.
    if(!['openfda','medlineplus','rxclass'].includes(source.source_id)){
     this.cache.set(key,value);if(this.cache.size>64)this.cache.delete(this.cache.keys().next().value);
    }
    this.breakers.set(source.source_id,{failures:0,until:0});return value;
   }catch(e){
    const error=e instanceof SourceError?e:new SourceError('source_unavailable');
    if(error.status===404||error.code==='source_budget_exceeded'||error.code==='source_schema_error'||error.code==='source_response_too_large')throw error;
    if(attempt<2){this.metrics.retries++;await this.wait(Math.max(retryAfter,250*2**attempt+Math.floor(this.random()*200)));continue;}
    b.failures++;if(b.failures>=3)b.until=Date.now()+60000;this.breakers.set(source.source_id,b);throw error;
   }
  }
 }
}
