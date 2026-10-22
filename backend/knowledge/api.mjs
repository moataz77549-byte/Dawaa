import {createHash} from 'node:crypto';
import {checkServiceToken} from './service.mjs';
import {normalizeSearch,normalizeDoi} from './adapters.mjs';
import {registry,sourceById,futureSources} from './registry.mjs';
import {SourceError} from './transport.mjs';
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const escapeLike=s=>s.replace(/[\\%_]/g,'\\$&');
async function body(request){
 const reader=request.body?.getReader();if(!reader)return {};
 const parts=[];let bytes=0;
 try{for(;;){const {done,value}=await reader.read();if(done)break;bytes+=value.length;if(bytes>2048)throw new SourceError('request_too_large',413);parts.push(value);}}
 finally{await reader.cancel().catch(()=>{});reader.releaseLock();}
 try{return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(parts)));}catch{throw new SourceError('invalid_json',400);}
}
export function createKnowledgeApi({base,query,internalQuery,sourceService,serviceToken,parseTrigger=async()=>({ok:false})}){
 let tokens=180,refilled=Date.now(),inflight=0;
 const reply=(r,data,status=200,privateResponse=false)=>{
  const value=JSON.stringify(data),tag='"'+createHash('sha256').update(value).digest('hex')+'"';
  const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':privateResponse||status!==200?'no-store':'public, max-age=60','X-Content-Type-Options':'nosniff'};
  if(!privateResponse&&status===200){headers.ETag=tag;if(r.headers.get('if-none-match')===tag)return new Response(null,{status:304,headers});}
  return new Response(r.method==='HEAD'?null:value,{status,headers});
 };
 return {async fetch(request){
  const now=Date.now();tokens=Math.min(180,tokens+(now-refilled)*2/1000);refilled=now;
  if(tokens<1||inflight>=12)return reply(request,{error:'rate_limited'},429,true);tokens--;inflight++;
  try{
   const u=new URL(request.url),p=u.pathname;
   if(p==='/v1/internal/source-cron'){
    if(request.method!=='POST')return reply(request,{error:'forbidden'},403,true);
    const parsed=await parseTrigger(request);
    if(!parsed.ok||parsed.invocation.type!=='schedule'||parsed.invocation.trigger.name!=='medical-source-metadata')return reply(request,{error:'forbidden'},403,true);
    const at=Date.parse(parsed.invocation.data.scheduledAt);if(!Number.isFinite(at)||Math.abs(Date.now()-at)>86400000)return reply(request,{error:'invalid_schedule'},400,true);
    const source=registry[Math.floor(at/(6*3600000))%registry.length];
    const key='schedule-'+createHash('sha256').update(parsed.invocation.invocationId).digest('hex');
    return reply(request,await sourceService.refresh(source.source_id,{key,limit:1}),200,true);
   }
   if(p.startsWith('/v1/internal/')){
    if(!checkServiceToken(request,serviceToken))return reply(request,{error:'forbidden'},403,true);
    const refresh=p.match(/^\/v1\/internal\/sources\/([a-z0-9-]+)\/refresh$/);
    if(refresh&&request.method==='POST'){
     const b=await body(request);if(!b||Array.isArray(b)||typeof b!=='object')return reply(request,{error:'invalid_json'},400,true);
     return reply(request,await sourceService.refresh(refresh[1],{query:b.query??null,cursor:b.cursor??null,key:b.idempotency_key??null,limit:b.limit??5,identifiers:b.identifiers??null}),200,true);
    }
    if(p==='/v1/internal/review-queue'&&request.method==='GET')return reply(request,{items:await internalQuery(`SELECT id,source_id,source_native_id,concept_id,reason,status,created_at FROM article_candidates ORDER BY created_at DESC LIMIT 50`),publication:'requires separate qualified human approval; no automatic clinical publication endpoint'},200,true);
    if(p==='/v1/internal/source-jobs'&&request.method==='GET')return reply(request,{items:await internalQuery(`SELECT id,source_id,status,items_seen,imported,updated,skipped,duplicates,quarantined,failed,request_count,response_bytes,cache_hits,duration_ms,error_code,cursor_value,attempts,started_at,finished_at FROM source_fetch_jobs ORDER BY started_at DESC LIMIT 50`),conflicts:await internalQuery(`SELECT id,kind,status,created_at FROM source_conflicts WHERE status='open' ORDER BY created_at DESC LIMIT 50`)},200,true);
    return reply(request,{error:'not_found'},404,true);
   }
   const known=p==='/v1/sources'||/^\/v1\/sources\/[^/]+\/status$/.test(p)||p==='/v1/search'||p==='/v1/drugs/lookup'||p==='/v1/diseases/lookup'||p==='/v1/research/search'||/^\/v1\/concepts\/[^/]+(?:\/references)?$/.test(p)||/^\/v1\/citations\/[^/]+$/.test(p)||p==='/v1/catalog/updates';
   if(!known)return await base.fetch(request);
   if(!['GET','HEAD'].includes(request.method))return reply(request,{error:'forbidden'},403,true);
   const lang=u.searchParams.get('lang')||'ar';if(!['ar','en','la'].includes(lang))return reply(request,{error:'invalid_language'},400,true);
   const rawLimit=u.searchParams.get('limit')||'25',rawPage=u.searchParams.get('page')||'1';
   if(!/^\d{1,2}$/.test(rawLimit)||+rawLimit<1||+rawLimit>50||!/^\d{1,3}$/.test(rawPage)||+rawPage<1||+rawPage>100)return reply(request,{error:'invalid_pagination'},400,true);
   const limit=+rawLimit,page=+rawPage,offset=(page-1)*limit;
   if(p==='/v1/sources'){
    const rows=await query(`SELECT * FROM public_medical_sources ORDER BY id`);
    return reply(request,{items:rows,future_sources:u.searchParams.get('include_future')==='true'?futureSources:undefined,clinical_notice:'Source access does not grant clinical approval or unrestricted redistribution.'});
   }
   const status=p.match(/^\/v1\/sources\/([^/]+)\/status$/);
   if(status){if(!sourceById(status[1]))return reply(request,{error:'not_found'},404,true);const rows=await query('SELECT * FROM public_medical_sources WHERE id=$1',[status[1]]);return rows.length?reply(request,rows[0]):reply(request,{error:'source_not_ready'},503,true);}
   const concept=p.match(/^\/v1\/concepts\/([^/]+)(\/references)?$/);
   if(concept){
    if(!uuid.test(concept[1]))return reply(request,{error:'invalid_identifier'},400,true);
    const rows=await query('SELECT * FROM public_concepts WHERE id=$1::uuid',[concept[1]]);if(!rows.length)return reply(request,{error:'not_found'},404,true);
    if(concept[2])return reply(request,{items:await query(`SELECT r.* FROM public_references r WHERE r.concept_id=$1::uuid OR r.concept_id IN (SELECT reference_id FROM public_citation_links WHERE concept_id=$1::uuid) ORDER BY r.concept_id LIMIT $2 OFFSET $3`,[concept[1],limit,offset]),coverage:'linked references only; not a treatment recommendation'});
    const facts=await query(`SELECT DISTINCT ON(claim_type,locale,source_id,source_native_id) * FROM public_knowledge_facts WHERE concept_id=$1::uuid ORDER BY claim_type,locale,source_id,source_native_id,fetched_at DESC LIMIT 50`,[concept[1]]);
    return reply(request,{...rows[0],identifiers:await query('SELECT scheme,value,source_id,source_native_id,verified_at FROM public_concept_identifiers WHERE concept_id=$1::uuid ORDER BY scheme,value',[concept[1]]),facts:facts.map(f=>({...f,source_name:sourceById(f.source_id)?.source_name||f.source_id})),display_language:lang,translation_notice:rows[0].translation_state==='approved'?null:'Arabic/Latin names are not medically approved translations.'});
   }
   const citation=p.match(/^\/v1\/citations\/([^/]+)$/);
   if(citation){if(!uuid.test(citation[1]))return reply(request,{error:'invalid_identifier'},400,true);const rows=await query('SELECT * FROM public_references WHERE concept_id=$1::uuid',[citation[1]]);return rows.length?reply(request,rows[0]):reply(request,{error:'not_found'},404,true);}
   if(p==='/v1/catalog/updates'){
    const since=u.searchParams.get('since')||'1970-01-01T00:00:00Z';if(!/^\d{4}-\d\d-\d\dT[\d:.]+Z$/.test(since)||!Number.isFinite(Date.parse(since)))return reply(request,{error:'invalid_timestamp'},400,true);
    const rows=await query('SELECT id,kind,revision,updated_at,stale FROM public_concepts WHERE updated_at>$1::timestamptz ORDER BY updated_at,id LIMIT $2 OFFSET $3',[since,limit+1,offset]);return reply(request,{items:rows.slice(0,limit),next_page:rows.length>limit?page+1:null,content_updates_endpoint:'/v1/updates'});
   }
   const q=u.searchParams.get('q')||'';if(q.trim().length<2||q.length>200)return reply(request,{error:'invalid_query'},400,true);
   const allowed=['ingredient','precise_ingredient','clinical_drug','product','chemical_compound','research','disease_topic','anatomy_term'];
   const type=u.searchParams.get('type');if(type&&!allowed.includes(type))return reply(request,{error:'invalid_type'},400,true);
   const kinds=p==='/v1/drugs/lookup'?['ingredient','precise_ingredient','clinical_drug','product']:p==='/v1/diseases/lookup'?['disease_topic']:p==='/v1/research/search'?['research']:type?[type]:allowed;
   const normalized=normalizeSearch(q),code=q.match(/^(rxcui|cid|pmid|pmcid|doi|ndc):(.+)$/i),scheme=code?({rxcui:'RxCUI',cid:'PubChemCID',pmid:'PMID',pmcid:'PMCID',doi:'DOI',ndc:'NDC'})[code[1].toLowerCase()]:null;
   const identifierValue=scheme==='DOI'?normalizeDoi(code[2]):code?.[2].trim();if(code&&!identifierValue)return reply(request,{error:'invalid_identifier'},400,true);
   const rows=await query(`SELECT c.* FROM public_concepts c WHERE c.kind=ANY($1::text[]) AND (($2::text IS NOT NULL AND EXISTS(SELECT 1 FROM public_concept_identifiers i WHERE i.concept_id=c.id AND i.scheme=$2 AND i.value=$3)) OR ($2::text IS NULL AND c.normalized_search LIKE $4 ESCAPE '\\')) ORDER BY c.preferred_name,c.id LIMIT $5 OFFSET $6`,[kinds,scheme,identifierValue||null,'%'+escapeLike(normalized)+'%',limit+1,offset]);
   return reply(request,{items:rows.slice(0,limit),next_page:rows.length>limit?page+1:null,coverage:'sampled_cloud_metadata_index',source_query_executed:false,notice:'An empty sampled index result does not mean no drug, disease or research exists. External links and clinical review remain separate.'});
  }catch(e){return reply(request,{error:e instanceof SourceError?e.code:'temporarily_unavailable'},e instanceof SourceError?e.status:503,true);}finally{inflight--;}
 }};
}
