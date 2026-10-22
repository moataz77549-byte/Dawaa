import test from 'node:test';
import assert from 'node:assert/strict';
import {MedicalSourceAdapter,canonicalId,normalizeDoi,normalizeSearch} from '../knowledge/adapters.mjs';
import {SourceTransport} from '../knowledge/transport.mjs';
import {sourceById,futureSources} from '../knowledge/registry.mjs';
const envelope=body=>({text:JSON.stringify(body),source_url:'https://rxnav.nlm.nih.gov/REST/test',fetched_at:'2026-10-22T00:00:00Z',raw_payload_hash:'a'.repeat(64),etag:null,last_modified:null});
const fixtures={
 openfda:{results:[{set_id:'0005aafa-08f8-4990-a54d-cc097195708f',effective_time:'20260101',openfda:{generic_name:['acetaminophen'],rxcui:['161']},dosage_and_administration:['UNREVIEWED CLINICAL TEXT MUST NOT ESCAPE']}]},
 dailymed:{data:[{setid:'0005aafa-08f8-4990-a54d-cc097195708f',title:'acetaminophen product',spl_version:1,published_date:'2026-01-01'}],metadata:{current_page:1,total_pages:2}},
 rxnorm:{properties:{rxcui:'161',name:'acetaminophen',tty:'IN'}},
 rxterms:{rxtermsProperties:{rxcui:'198440',fullName:'acetaminophen 500 MG Oral Tablet',termType:'SCD'}},
 rxclass:{rxclassDrugInfoList:{rxclassDrugInfo:[{minConcept:{rxcui:'161'},rxclassMinConceptItem:{classId:'RESTRICTED',className:'DO NOT COPY'}}]}},
 pubchem:{PropertyTable:{Properties:[{CID:1983,MolecularFormula:'C8H9NO2',MolecularWeight:'151.16',InChIKey:'RZVAJINKPMORJF-UHFFFAOYSA-N'}]}},
 pubmed:{result:{uids:['9500320'],'9500320':{title:'Synthetic fixture',pubtype:['Retracted Publication'],authors:[{name:'Fixture author'}],articleids:[{idtype:'doi',value:'10.1000/example'}]}}},
 europepmc:{resultList:{result:[{id:'9500320',source:'MED',title:'Synthetic fixture',doi:'10.1000/example',isOpenAccess:'Y'}]},nextCursorMark:'next'},
 crossref:{message:{items:[{DOI:'10.1000/example',title:['Synthetic fixture'],abstract:'DO NOT COPY',relation:{},'update-to':[]}]}}
};
for(const [id,body] of Object.entries(fixtures))test(`mock contract ${id}: identity, rights and schema changes`,()=>{
 const adapter=new MedicalSourceAdapter(id),out=adapter.normalize(envelope(body));assert.ok(out.records.length);const r=out.records[0];adapter.validate(r);
 assert.equal(r.review_state,'needs_review');assert.equal(r.content_class,'metadata');assert.equal(r.clinical,false);
 assert.equal(JSON.stringify(r).includes('DO NOT COPY'),false);assert.equal(JSON.stringify(r).includes('UNREVIEWED CLINICAL TEXT'),false);
 assert.throws(()=>adapter.normalize(envelope({changed_schema:true})),e=>e.code==='source_schema_error');
 assert.equal(adapter.deduplicate([r,r]).length,1);
});
test('mock MedlinePlus XML allows metadata only and rejects DTD/entity input',()=>{
 const a=new MedicalSourceAdapter('medlineplus');const xml='<nlmSearchResult><list><document url="https://medlineplus.gov/asthma.html"><content name="title">Asthma</content><content name="fullSummary">DO NOT COPY</content></document></list></nlmSearchResult>';
 const out=a.normalize({...envelope({}),text:xml});assert.equal(out.records[0].title,'Asthma');assert.equal(JSON.stringify(out).includes('DO NOT COPY'),false);
 assert.throws(()=>a.normalize({...envelope({}),text:'<!DOCTYPE x [<!ENTITY e "unsafe">]>'+xml}),e=>e.code==='source_schema_error');
});
test('identifier schemes and entity kinds prevent name-only merging',()=>{
 assert.notEqual(canonicalId('RxCUI','161','ingredient'),canonicalId('PubChemCID','161','chemical_compound'));
 assert.notEqual(canonicalId('RxCUI','161','ingredient'),canonicalId('RxCUI','161','precise_ingredient'));
 assert.equal(normalizeDoi('https://doi.org/10.1000/EXAMPLE'),'10.1000/example');assert.equal(normalizeDoi('javascript:alert(1)'),null);
 assert.equal(normalizeSearch('أَزمة'),'ازمه');
});
const mockTransport=fetchImpl=>new SourceTransport({fetchImpl,wait:async()=>{},random:()=>0,timeoutMs:10});
test('404, malformed payload and UTF8 fail honestly without a fake empty success',async()=>{
 const s=sourceById('rxnorm');let calls=0;const t=mockTransport(async()=>{calls++;return new Response('{}',{status:404,headers:{'content-type':'application/json'}});});
 await assert.rejects(t.get(s,'/REST/test'),e=>e.code==='source_not_found');assert.equal(calls,1);
 const invalid=mockTransport(async()=>new Response(new Uint8Array([0xff]),{headers:{'content-type':'application/json'}}));
 await assert.rejects(invalid.get(s,'/REST/test'),e=>e.code==='source_unavailable');
 const html=mockTransport(async()=>new Response('<html>bad gateway</html>',{headers:{'content-type':'text/html'}}));await assert.rejects(html.get(s,'/REST/test'),e=>e.code==='source_schema_error');
});
for(const status of [429,503])test(`HTTP ${status}: bounded retry and circuit breaker`,async()=>{
 let calls=0;const t=mockTransport(async()=>{calls++;return new Response('{}',{status,headers:{'retry-after':'99999'}});}),s=sourceById('rxnorm');
 for(let i=0;i<3;i++)await assert.rejects(t.get(s,'/REST/test'),e=>e.code==='source_unavailable');
 assert.equal(calls,9);await assert.rejects(t.get(s,'/REST/test'),e=>e.code==='source_unavailable');assert.equal(calls,9);
});
test('timeouts retry at most three times; conditional GET reuses only an actual cached body',async()=>{
 let calls=0;const t=mockTransport(async()=>{calls++;throw new DOMException('timeout','TimeoutError');});await assert.rejects(t.get(sourceById('rxnorm'),'/REST/test'));assert.equal(calls,3);
 let n=0;const c=mockTransport(async(url,options)=>{n++;if(n===1)return new Response('{}',{headers:{'content-type':'application/json',etag:'"v1"'}});assert.equal(options.headers['If-None-Match'],'"v1"');return new Response(null,{status:304});});
 const s=sourceById('rxnorm');assert.equal((await c.get(s,'/REST/test')).cache_hit,false);assert.equal((await c.get(s,'/REST/test')).cache_hit,true);
});
test('disabled sources and URL escapes never execute',async()=>{
 let calls=0;const t=mockTransport(async()=>{calls++;throw Error('not expected');});
 await assert.rejects(t.get({...sourceById('rxnorm'),enabled:false},'/REST/test'),e=>e.code==='source_disabled');
 await assert.rejects(t.get(sourceById('rxnorm'),'https://evil.invalid/'),e=>e.code==='unsafe_source_url');assert.equal(calls,0);
 assert.ok(futureSources.every(x=>!x.enabled&&!x.offline_permission));
});
