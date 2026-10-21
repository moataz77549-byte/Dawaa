import pathlib,re,sys,subprocess
files=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard'],text=True).splitlines()
patterns=[r'postgres(?:ql)?://[^\s"\']+:[^\s"\']+@',r'AKIA[0-9A-Z]{16}',r'gh[pousr]_[A-Za-z0-9]{30,}',r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----']
errors=[]
for name in files:
 p=pathlib.Path(name)
 if not p.is_file() or p.stat().st_size>2_000_000 or 'node_modules/' in name or '/build/' in name:continue
 try:s=p.read_text()
 except UnicodeError:continue
 scrubbed=re.sub(r'postgresql://postgres:localtest@localhost:5432/dawa_test','',s)
 if any(re.search(pat,scrubbed) for pat in patterns):errors.append(name)
 if name.startswith('app/') and re.search(r'NEON_API_KEY|AWS_SECRET_ACCESS_KEY|DATABASE_URL',s):errors.append(name+' (backend setting in app)')
if errors:print('\n'.join(errors));sys.exit(1)
print('Secret/client boundary scan passed')
