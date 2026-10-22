"""Emit reproducible draft terminology and explicitly scoped bibliography links.
No reviewer, clinical assertion, or name-based entity merging is created.
"""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def q(s):return "'"+str(s).replace("'","''")+"'"
rows=json.loads((R/'backend/db/seed/verified_ingredient_metadata.json').read_text())
print("INSERT INTO sources(id,source_type,source_title,source_url,publisher,license,attribution,redistribution_allowed) VALUES('dawa-editorial-drafts','original_translation_draft','Independent Arabic terminology drafts','https://github.com/moataz77549-byte/Dawaa','Dawa & Hayah','CC-BY-4.0','Independent drafts; no NLM endorsement or medical review',true) ON CONFLICT DO NOTHING;")
for r in rows:
 id=q(r['id']);name=q(r['arabic_name']);norm=q(r['arabic_name'].replace('أ','ا').replace('إ','ا').replace('آ','ا').replace('ى','ي').replace('ة','ه'))
 print(f"UPDATE canonical_concepts SET arabic_name={name},translation_state='needs_review',normalized_search=normalized_search || ' ' || {norm} WHERE id={id} AND arabic_name IS NULL;")
 print(f"INSERT INTO concept_aliases(concept_id,locale,alias,normalized,source_id) SELECT {id},'ar',{name},{norm},'dawa-editorial-drafts' WHERE EXISTS(SELECT 1 FROM canonical_concepts WHERE id={id}) ON CONFLICT DO NOTHING;")
 print(f"INSERT INTO translation_reviews(concept_id,locale,revision,text_value) SELECT {id},'ar',1,{name} WHERE EXISTS(SELECT 1 FROM canonical_concepts WHERE id={id}) ON CONFLICT DO NOTHING;")
# Title mentions are explicitly not clinical evidence. No association is inferred from chemical/ingredient name similarity.
print("INSERT INTO citation_links(id,concept_id,reference_id,source_id,source_native_id,relation_context) SELECT md5('mention:' || i.concept_id::text || ':' || r.concept_id::text)::uuid,i.concept_id,r.concept_id,c.source_id,c.source_native_id,'bibliographic_title_mentions_acetaminophen_not_efficacy_or_dosing' FROM concept_identifiers i CROSS JOIN reference_works r JOIN canonical_concepts c ON c.id=r.concept_id WHERE i.scheme='RxCUI' AND i.value='161' AND i.entity_kind='ingredient' AND lower(r.bibliography->>'title') LIKE '%acetaminophen%' ON CONFLICT DO NOTHING;")
print("INSERT INTO content_pack_exports(pack_id,version,source_policy_snapshot,record_count,metadata_only) SELECT 'medical-identities',1,jsonb_build_object('source_id','rxnorm','license_evidence',p.license_evidence_url,'terms_checked_at',p.terms_checked_at,'projection','non-proprietary names and RxCUI only','arabic','independent draft, needs_review'),20,true FROM source_policies p WHERE p.source_id='rxnorm' AND p.enabled AND p.offline_metadata_allowed ON CONFLICT DO NOTHING;")
