import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createApi} from '../functions/api.mjs';
const request=(path,init)=>new Request('https://api.example'+path,init);
test('rejects invalid inputs before any database query',async()=>{
 let calls=0;const api=createApi({query:async()=>{calls++;return [];}});
 for(const path of ['/v1/catalog?lang=fr','/v1/catalog?limit=-1','/v1/catalog?limit=101','/v1/catalog?category=private','/v1/content/a%27','/v1/updates?since=bad'])assert.equal((await api.fetch(request(path))).status,400,path);
 assert.equal(calls,0);
});
test('all mutation methods closed even with client supplied role',async()=>{
 const api=createApi({query:()=>{throw Error('must not query');}});
 for(const method of ['POST','PATCH','DELETE','PUT'])assert.equal((await api.fetch(request('/v1/content/circulation',{method,headers:{role:'owner'}}))).status,403);
});
test('catalog pagination, bound parameters and ETag',async()=>{
 const api=createApi({query:async(sql,args)=>{assert.ok(sql.includes('public_content'));assert.deepEqual(args,['ar','',null,2]);return [{canonical_id:'a'},{canonical_id:'b'}];}});
 const a=await api.fetch(request('/v1/catalog?limit=1'));
 assert.equal(a.status,200);assert.deepEqual(await a.json(),{items:[{canonical_id:'a'}],next_cursor:'a'});
 assert.equal((await api.fetch(request('/v1/catalog?limit=1',{headers:{'If-None-Match':a.headers.get('etag')}}))).status,304);
});
test('draft and unlicensed results absent when publication view returns empty',async()=>{
 const api=createApi({query:async(sql)=>{assert.ok(sql.includes('public_'));return [];}});
 assert.equal((await api.fetch(request('/v1/content/draft'))).status,404);
 assert.equal((await api.fetch(request('/v1/assets/private/access'))).status,404);
});
test('database error never leaks connection details',async()=>{
 const api=createApi({query:async()=>{throw Error('postgres://secret');}});
 const r=await api.fetch(request('/health'));assert.equal(r.status,503);assert.ok(!(await r.text()).includes('secret'));
});
test('presigned access is never cacheable',async()=>{
 const api=createApi({query:async()=>[{bucket:'offline-packs',object_key:'key'}],access:async()=> 'https://storage.example/key?signature=private'});
 const r=await api.fetch(request('/v1/assets/circulation-demo-demo-glb/access'));assert.equal(r.status,200);assert.equal(r.headers.get('cache-control'),'no-store');
});
