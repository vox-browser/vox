from pathlib import Path
import os,subprocess,sys,json
root=Path.cwd();job=root/'Build/github-20-instr';label=sys.argv[1];source=sys.argv[2] if len(sys.argv)>2 else 'layout/zz_github20_layout_probe_test.v';compiler=root/'Build/v/prealloc-runtime/70925d4452ce4b83290c0d484dece2a3c2d1404069843eed25cbcdb8c7d46ee2/compiler/v'
command=['python3','tools/run_memory_bounded.py','--lock',f'Build/github20-{label}-compile.lock','--report',f'Build/github20-{label}-compile-guard.json','--timeout','1200','--',str(compiler),'-memory-limit','10G']
if os.getenv('ZZ_PROBE_PROD','1')=='1':command+=['-prod']
command+=['-cflags',os.getenv('ZZ_PROBE_CFLAGS','-O2 -fno-lto'),'-ldflags','-fno-lto','-prealloc','-gc','none','-enable-globals','-d','vox_sparse_ttf','-nocache','-path',(job/'vpath.txt').read_text().strip(),'-o',str(job/(label+'-probe')),source]
(job/(label+'-compile-command.json')).write_text(json.dumps(command,indent=2)+'\n')
with (job/(label+'-compile.log')).open('w') as log:r=subprocess.run(command,env=dict(os.environ,V_MACOS_V3_NO_FALLBACK='1'),stdout=log,stderr=subprocess.STDOUT)
raise SystemExit(r.returncode)
