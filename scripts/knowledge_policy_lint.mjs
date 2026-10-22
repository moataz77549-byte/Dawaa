import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {registry,coreSourceIds} from '../backend/knowledge/registry.mjs';
const read=async path=>JSON.parse(await readFile(new URL('../'+path,import.meta.url)));
assert(coreSourceIds.every(id=>registry.some(s=>s.source_id===id)));
for(const s of registry){assert(s.license_url.startsWith('https://'));assert(s.metadata_only);assert(s.rate_limit.requests_per_second<=1);}
const manifest=await read('backend/storage/manifests/medical-identities.json');
const bytes=await readFile(new URL('../backend/storage/packs/medical-identities/1/content.json',import.meta.url));
assert.equal(bytes.length,manifest.size_bytes);assert.equal(createHash('sha256').update(bytes).digest('hex'),manifest.files[0].sha256);
const content=JSON.parse(bytes);assert.equal(content.items.length,20);
const ids=new Set();
for(const item of content.items){
 const policy=registry.find(s=>s.source_id===item.source_id);
 assert(policy?.offline_permission&&policy.allowed_redistribution);
 assert(!ids.has(item.id));ids.add(item.id);
 assert.equal(item.clinical,false);assert.equal(item.review_status,'needs_review');
 assert.equal(item.provenance.content_class,'identity_metadata');assert.equal(item.provenance.offline_metadata_allowed,true);
 assert.equal(item.provenance.source_native_id,item.source_native_id);
 assert(/^[a-f0-9]{64}$/.test(item.provenance.payload_hash));assert(item.fetched_at&&item.source_url&&item.attribution);
 assert(!item.abstract&&!item.fullText&&!item.dosage_instructions&&!item.verified_latin_term);
 assert(item.provenance.license===policy.license);
}
console.log('Metadata-only license/provenance/offline-policy lint passed');
