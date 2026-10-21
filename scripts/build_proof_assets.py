"""Reproduce cloud proof bytes without keeping large remote assets in Git."""
import pathlib,json
r=pathlib.Path(__file__).resolve().parent.parent
out=pathlib.Path('/tmp/dawa-pack');out.mkdir(exist_ok=True)
x=json.loads((r/'app/assets/seed/content.json').read_text())['items'][0]
x.update(id='cloud-circulation',title_ar='الدورة الدموية — حزمة سحابية',title_en='Circulation — cloud pack')
(out/'content.json').write_bytes(json.dumps({'version':1,'items':[x]},ensure_ascii=False).encode())
(out/'diagram.png').write_bytes((r/'app/assets/seed/demo.png').read_bytes())
(out/'demo.glb').write_bytes((r/'app/assets/models/sample/demo.glb').read_bytes())
print(str(out))
