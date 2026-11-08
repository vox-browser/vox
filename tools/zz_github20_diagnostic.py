import sys,json,shutil,os,hashlib
from pathlib import Path
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).resolve().parent))
from browser_bundle_lease import canonical_bundle_lease
from process_instruction_counts import MacCounters
from reddit_browser_instructions import private_measurement_environment,vox_launch_arguments
import measure_browser_instructions as m
job=Path('Build/github-20-instr').resolve();out=job/sys.argv[1];out.mkdir();cache=out/'cache';shutil.copytree(job/'cache-template',cache)
args=SimpleNamespace(binary=Path(os.getenv('ZZ_VOX_BINARY','Build/v/Vox.app/Contents/MacOS/Vox')).resolve(),url=(job/'github-frozen.html').as_uri(),width=1024,height=768,timeout=90,scratch_dir=out,sample_interval=.005,vox_arg=vox_launch_arguments('javascriptcore'))
with canonical_bundle_lease(Path('Build/v/Vox.app')):
 with private_measurement_environment(job/'network-deny.dylib',out):
  os.environ['VOX_DIAGNOSTIC_LOAD_STAGES']='1'
  for flag in sys.argv[2:]:
   k,v=flag.split('=',1);os.environ[k]=v
  r=m.run_vox(args,out/'vox',MacCounters(),cache)
  r['executable_sha256']=hashlib.sha256(args.binary.read_bytes()).hexdigest()
(out/'summary.json').write_text(json.dumps(r,indent=2));print(r['instructions'])
