from pathlib import Path
import json,time,subprocess,sys
from browser_bundle_lease import canonical_bundle_lease,ROOT
job=ROOT/'Build/github-20-instr';candidate,label=sys.argv[1:];receipt=job/candidate/'receipt/executable.json';guard=ROOT/f'Build/github20-{candidate}-build-guard.json'
while not receipt.exists():
    if guard.exists() and guard.stat().st_size:
        status=json.loads(guard.read_text())
        if status.get('child_exit_code') not in (None,0):
            raise SystemExit('Candidate build failed; cohort not launched')
    time.sleep(.5)
identity=json.loads(receipt.read_text());binary=Path(identity['path'])
command=['python3','tools/github_browser_instructions.py','--html',str(job/'github-frozen.html'),'--cache',str(job/'cache-template'),'--expected',str(job/'brave-reference.png'),'--expected-vox',str(job/'vox-reference.png'),'--network-deny',str(job/'network-deny.dylib'),'--vox',str(binary),'--output',str(job/label),'--required-reduction','.20','--repeat','7']
print(json.dumps({'command':command,'build_identity':identity}),flush=True)
with canonical_bundle_lease(ROOT/'Build/v/Vox.app'):
    result=subprocess.run(command)
raise SystemExit(result.returncode)
