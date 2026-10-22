"""Selective read-only smoke of real Neon connector results; never bulk-fetch on CI."""
import hashlib,json,os,time,urllib.request,urllib.error
BASE=os.environ.get('KNOWLEDGE_API_BASE_URL','https://br-broad-recipe-ba4bc7dt-api.compute.c-8.eu-central-1.aws.neon.tech')
def get(p):
 with urllib.request.urlopen(BASE+p,timeout=40) as r:return json.load(r)
sources=get('/v1/sources')['items'];assert len(sources)==10
assert all(s['last_success_at'] for s in sources), 'Every connector must have real successful ingestion evidence'
c=get('/v1/drugs/lookup?q=RxCUI:161')['items'];assert len(c)==1 and c[0]['kind']=='ingredient'
r=get('/v1/concepts/'+c[0]['id']);assert r['facts'] and r['identifiers'];assert r['translation_state']=='needs_review'
compound=get('/v1/search?q=CID:1983')['items'];assert compound[0]['kind']=='chemical_compound' and compound[0]['id']!=c[0]['id']
retracted=get('/v1/research/search?q=PMID:9500320')['items'];assert get('/v1/citations/'+retracted[0]['id'])['retraction_state']=='retracted'
refs=get('/v1/concepts/'+c[0]['id']+'/references')['items'];assert refs
for path in ['/v1/internal/review-queue','/v1/internal/source-jobs']:
 try:urllib.request.urlopen(BASE+path,timeout=30);raise AssertionError('private endpoint leaked')
 except urllib.error.HTTPError as e:assert e.code==403
m=get('/v1/packs/medical-identities/manifest');f=m['files'][0];url=get('/v1/assets/'+f['asset_id']+'/access')['url']
with urllib.request.urlopen(url,timeout=40) as response:data=response.read()
assert len(data)==f['size_bytes'] and hashlib.sha256(data).hexdigest()==f['sha256']
assert len(json.loads(data)['items'])==20
print(json.dumps(dict(environment=BASE,real_sources=len(sources),clinical_approval=False,private_admin='403',ingredient_compound_separation=True,retracted_pmid='9500320',linked_references=len(refs),pack_bytes=len(data),sha256=f['sha256'])))
