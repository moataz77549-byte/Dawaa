import { createHash } from 'node:crypto';
const idPattern=/^[a-z0-9][a-z0-9-]{0,79}$/;
export const validId=x=>idPattern.test(x||'');
export function createApi({query,access}) {
 let tokens=300,refilled=Date.now();
 let inflight=0; // global per isolate concurrency bound; no untrusted forwarded IP headers
 const reply=(request,data,status=200)=>{
  const text=JSON.stringify(data),etag='"'+createHash('sha256').update(text).digest('hex')+'"';
  const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':status===200?'public, max-age=60':'no-store','X-Content-Type-Options':'nosniff','ETag':etag};
  if(status===200&&request.headers.get('if-none-match')===etag)return new Response(null,{status:304,headers});
  return new Response(text,{status,headers});
 };
 return {async fetch(request){
  const now=Date.now();tokens=Math.min(300,tokens+(now-refilled)*5/1000);refilled=now;
  if(tokens<1)return reply(request,{error:'rate limited'},429);tokens--;
  if(inflight>=16)return reply(request,{error:'busy'},429);
  inflight++;
  try{
   const u=new URL(request.url),p=u.pathname;
   if(request.method!=='GET'&&request.method!=='HEAD')return reply(request,{error:'administrative writes disabled'},403);
   if(request.headers.get('content-length')&&Number(request.headers.get('content-length'))>0)return reply(request,{error:'body not allowed'},400);
   const lang=u.searchParams.get('lang')||'ar';if(!['ar','en'].includes(lang))return reply(request,{error:'invalid language'},400);
   const raw=u.searchParams.get('limit')||'25';if(!/^\d{1,3}$/.test(raw)||+raw<1||+raw>100)return reply(request,{error:'invalid limit'},400);
   const limit=+raw,cursor=u.searchParams.get('cursor')||'';
   if(cursor&&!validId(cursor))return reply(request,{error:'invalid cursor'},400);
   if(p==='/health'){await query('SELECT 1');return reply(request,{ok:true,service:'dawa-hayah',schema:1});}
   if(p==='/v1/catalog'){
    const category=u.searchParams.get('category');if(category&&!['home','anatomy','diseases','medicines'].includes(category))return reply(request,{error:'invalid category'},400);
    const rows=await query(`SELECT canonical_id,category,title,revision,review_status,license FROM public_content WHERE locale=$1 AND canonical_id>$2 AND ($3::text IS NULL OR category=$3) ORDER BY canonical_id LIMIT $4`,[lang,cursor,category,limit+1]);
    return reply(request,{items:rows.slice(0,limit),next_cursor:rows.length>limit?rows[limit-1].canonical_id:null});
   }
   const content=p.match(/^\/v1\/content\/([^/]+)$/);
   if(content){if(!validId(content[1]))return reply(request,{error:'invalid id'},400);const rows=await query('SELECT * FROM public_content WHERE canonical_id=$1 AND locale=$2',[content[1],lang]);return rows.length?reply(request,rows[0]):reply(request,{error:'not found'},404);}
   if(p==='/v1/packs'){
    const scope=u.searchParams.get('scope');if(scope&&!validId(scope))return reply(request,{error:'invalid scope'},400);
    const rows=await query(`SELECT DISTINCT ON(p.id) p.id,p.version,p.manifest FROM public_packs p WHERE true AND p.id>$1 AND ($2::text IS NULL OR p.scope_id=$2) ORDER BY p.id,p.version DESC LIMIT $3`,[cursor,scope,limit+1]);
    return reply(request,{items:rows.slice(0,limit),next_cursor:rows.length>limit?rows[limit-1].id:null});
   }
   const pack=p.match(/^\/v1\/packs\/([^/]+)\/manifest$/);
   if(pack){if(!validId(pack[1]))return reply(request,{error:'invalid id'},400);
    const rows=await query(`SELECT p.manifest FROM public_packs p WHERE p.id=$1 ORDER BY p.version DESC LIMIT 1`,[pack[1]]);
    return rows.length?reply(request,rows[0].manifest):reply(request,{error:'not found'},404);
   }
   const asset=p.match(/^\/v1\/assets\/([^/]+)\/access$/);
   if(asset){if(!validId(asset[1]))return reply(request,{error:'invalid id'},400);
    const rows=await query(`SELECT a.* FROM public_assets a WHERE a.id=$1`,[asset[1]]);
    if(!rows.length)return reply(request,{error:'not found'},404);
    return new Response(JSON.stringify({url:await access(rows[0]),expires_in:300}),{headers:{'Content-Type':'application/json','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}});
   }
   if(p==='/v1/updates'){
    const since=u.searchParams.get('since')||'1970-01-01T00:00:00Z';if(!/^\d{4}-\d\d-\d\dT[\d:.]+Z$/.test(since)||!Number.isFinite(Date.parse(since)))return reply(request,{error:'invalid timestamp'},400);
    const rows=await query(`SELECT canonical_id,revision,updated_at FROM public_content WHERE locale=$1 AND updated_at>$2::timestamptz AND canonical_id>$3 ORDER BY canonical_id LIMIT $4`,[lang,since,cursor,limit+1]);
    return reply(request,{items:rows.slice(0,limit),next_cursor:rows.length>limit?rows[limit-1].canonical_id:null});
   }
   return reply(request,{error:'not found'},404);
  }catch{return reply(request,{error:'temporarily unavailable'},503);}finally{inflight--;}
 }};
}
