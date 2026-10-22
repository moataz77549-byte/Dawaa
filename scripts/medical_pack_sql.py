"""Emit additive SQL for the reviewed rights projection, never clinical approval."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
def q(s):return "'"+str(s).replace("'","''")+"'"
m=json.loads((R/'backend/storage/manifests/medical-identities.json').read_text());f=m['files'][0]
s=["INSERT INTO sources(id,source_type,source_title,source_url,publisher,license,attribution,redistribution_allowed) VALUES('medical-identities-wrapper','original_metadata_wrapper','Dawa & Hayah terminology cards','https://github.com/moataz77549-byte/Dawaa','Dawa & Hayah','CC-BY-4.0','Original wrapper; separately attributed NLM RxNorm identity metadata; independent Arabic drafts',true) ON CONFLICT DO NOTHING"]
s.append("INSERT INTO media_assets(id,source_id,bucket,object_key,mime_type,bytes,sha256,quality,status) VALUES("+','.join(map(q,[f['asset_id'],'medical-identities-wrapper','offline-packs',f['object_key'],f['mime_type']]))+f",{f['size_bytes']},"+q(f['sha256'])+",'text','published') ON CONFLICT DO NOTHING")
s.append("INSERT INTO content_packs(id,version,scope_type,scope_id,manifest,source_id,status) VALUES('medical-identities',1,'knowledge','ingredient-identities',"+q(json.dumps(m,ensure_ascii=False))+"::jsonb,'medical-identities-wrapper','published') ON CONFLICT DO NOTHING")
s.append("INSERT INTO content_pack_files(pack_id,version,relative_path,asset_id) VALUES('medical-identities',1,'content.json','medical-identities-content-v1') ON CONFLICT DO NOTHING")
print(';\n'.join(s)+';')
