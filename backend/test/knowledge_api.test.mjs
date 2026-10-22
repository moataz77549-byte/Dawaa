import test from 'node:test';
import assert from 'node:assert/strict';
import {createKnowledgeApi} from '../knowledge/api.mjs';
const token='unit-test-fixture-'.repeat(4);
const make=()=>{const calls=[];const api=createKnowledgeApi({base:{fetch:async()=>new Response('base',{status:404})},query:async(sql,args)=>{calls.push({sql,args});return [];},internalQuery:async()=>{throw Error('private query must not execute');},sourceService:{refresh:async()=>({status:'completed'})},serviceToken:token,parseTrigger:async()=>({ok:false})});return {api,calls};};
test('private endpoints reject absent, wrong and client-role credentials before queries',async()=>{
 const {api,calls}=make();for(const headers of [{},{authorization:'Bearer wrong'},{'x-role':'owner','x-user-id':'first-owner'}]){
  const r=await api.fetch(new Request('https://dawa.invalid/v1/internal/review-queue',{headers}));assert.equal(r.status,403);assert.equal(r.headers.get('cache-control'),'no-store');
 }assert.equal(calls.length,0);
});
test('public caller cannot forge a schedule envelope in the handler without verified delivery',async()=>{
 const {api}=make();const r=await api.fetch(new Request('https://dawa.invalid/v1/internal/source-cron',{method:'POST',headers:{'x-neon-trigger-invocation-id':'forged'},body:'{}'}));assert.equal(r.status,403);
});
test('source refresh requires service authentication and validates bounded JSON',async()=>{
 const {api}=make();const r=await api.fetch(new Request('https://dawa.invalid/v1/internal/sources/rxnorm/refresh',{method:'POST',headers:{authorization:`Bearer ${token}`},body:'x'.repeat(3000)}));assert.equal(r.status,413);
});
test('typed identifier lookup binds parameters and never expands product/ingredient kinds',async()=>{
 const {api,calls}=make();const r=await api.fetch(new Request('https://dawa.invalid/v1/drugs/lookup?q=RxCUI%3A161&limit=5'));assert.equal(r.status,200);assert.equal(calls.length,1);assert.equal(calls[0].args[1],'RxCUI');assert.equal(calls[0].args[2],'161');assert.ok(!calls[0].args[0].includes('chemical_compound'));
 const d=await r.json();assert.equal(d.source_query_executed,false);assert.equal(d.coverage,'sampled_cloud_metadata_index');
});
test('invalid UUID, language, type and page are rejected without database access',async()=>{
 for(const path of ['/v1/concepts/not-a-uuid','/v1/search?q=aa&page=9999','/v1/search?q=aa&type=dosing','/v1/search?q=aa&lang=xx']){const {api,calls}=make();const r=await api.fetch(new Request('https://dawa.invalid'+path));assert.equal(r.status,400);assert.equal(calls.length,0);}
});
