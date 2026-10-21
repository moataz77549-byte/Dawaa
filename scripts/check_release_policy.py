"""Guard the Stage 1 policy: internal compile permitted; APK publication forbidden."""
import pathlib,json,subprocess
root=pathlib.Path(__file__).resolve().parent.parent
policy=json.loads((root/'release_policy.json').read_text())
if policy['current_stage']<policy['first_beta_stage']:
 assert not policy['public_apk_allowed'],'Public APK publication requires Stage 5 or later'
 for path in (root/'.github/workflows').glob('*.yml'):
  text=path.read_text().lower()
  for banned in ['action-gh-release','gh release create','actions/upload-artifact','releases/upload']:
   assert banned not in text,f'Forbidden pre-beta publication step in {path.name}: {banned}'
 paths=subprocess.check_output(['git','ls-files'],cwd=root,text=True).splitlines()
 assert not any(p.endswith(('.apk','.aab','.apks')) for p in paths),'Compiled Android distribution file tracked before Stage 5'
print('Stage policy passed: internal checks only; no public APK or Release')
