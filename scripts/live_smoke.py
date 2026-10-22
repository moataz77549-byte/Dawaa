"""Real remote API + Storage proof, then local-only hash/read proof (not Android)."""
import os,json,urllib.request,hashlib,tempfile,pathlib,datetime,struct
BASE=os.environ.get('API_BASE_URL','https://br-still-mode-balcyppo-api.compute.c-8.eu-central-1.aws.neon.tech')
def get(path):
 with urllib.request.urlopen(BASE+path,timeout=30) as r:return json.load(r)
assert get('/health')['ok']
assert len(get('/v1/catalog')['items'])==12
assert get('/v1/content/circulation?lang=en')['locale']=='en'
m=get('/v1/packs/circulation-demo/manifest');root=pathlib.Path(tempfile.mkdtemp(prefix='dawa-live-proof-'))
results=[]
for f in m['files']:
 uri=get('/v1/assets/'+f['asset_id']+'/access')['url']
 with urllib.request.urlopen(uri,timeout=30) as r: data=r.read()
 assert len(data)==f['size_bytes']; assert hashlib.sha256(data).hexdigest()==f['sha256']
 (root/f['relative_path']).write_bytes(data)
 results.append(dict(path=f['relative_path'],bytes=len(data),sha256=f['sha256'],verified=True))
# This phase deliberately has no network access calls.
assert json.loads((root/'content.json').read_text())['items'][0]['body_ar']
assert (root/'diagram.png').read_bytes().startswith(b'\x89PNG')
assert struct.unpack('<I',(root/'demo.glb').read_bytes()[:4])[0]==0x46546c67
for f in m['files']:assert hashlib.sha256((root/f['relative_path']).read_bytes()).hexdigest()==f['sha256']
report=dict(tested_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),api=BASE,pack_id=m['pack_id'],version=m['pack_version'],total_bytes=m['size_bytes'],files=results,host_local_only_read='passed',android_airplane_mode='NOT_TESTED',three_d_render='NOT_TESTED')
print(json.dumps(report,indent=2))
