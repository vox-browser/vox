#!/usr/bin/env python3
"""Alternate same-binary GPU options under one canonical-bundle read lease.

Run inside run_memory_bounded.py. Remaining arguments are passed unchanged to
measure_precise_scroll.py; candidate options are absent from the clean control.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

from browser_bundle_lease import ROOT, publication_lease
from freeze_browser_compile import fingerprint, check_fingerprints


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--pairs',type=int,default=2)
    parser.add_argument('--candidate-env',action='append',required=True)
    parser.add_argument('arguments',nargs=argparse.REMAINDER)
    args=parser.parse_args()
    arguments=args.arguments[1:] if args.arguments[:1]==['--'] else args.arguments
    output=args.output.resolve(); output.mkdir(parents=True,exist_ok=False)
    binary=ROOT/'Build/v/Vox.app/Contents/MacOS/Vox'
    env={k:v for k,v in os.environ.items() if not k.startswith(('VOX_','LADYBIRD_','DYLD_'))
         and k.lower() not in ('all_proxy','http_proxy','https_proxy','no_proxy')}
    env['VOX_TEST_WINDOW']='1'
    rows=[]
    with publication_lease(ROOT,shared=True):
        inputs=fingerprint([binary,*binary.parent.glob('*.dylib'),Path(__file__).resolve()])
        (output/'bundle.json').write_text((ROOT/'Build/production-build/latest.json').read_text())
        (output/'inputs.json').write_text(json.dumps(inputs,indent=2)+'\n')
        for pair in range(1,args.pairs+1):
            for role in ('control','candidate'):
                name=f'{role}-{pair}'
                command=[sys.executable,str(ROOT/'tools/measure_precise_scroll.py'),
                         '--output',str(output/name),*arguments]
                if role=='candidate':
                    for value in args.candidate_env:command+=['--env',value]
                with (output/(name+'.log')).open('w') as stream:
                    result=subprocess.run(command,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT)
                row=dict(name=name,command=command,exit=result.returncode)
                rows.append(row)
                (output/'attempts.json').write_text(json.dumps(rows,indent=2)+'\n')
                check_fingerprints(inputs)
                if result.returncode:raise RuntimeError('Invalid trial retained: '+name)
                data=json.loads((output/name/'summary.json').read_text())
                print(name, 'fps',round(data['mean_scroll_fps'],2),
                      'p95_ms',round(data['scroll_interval_us']['p95']/1000,3),
                      'miss_fraction',round(data['fraction_over_budget'],4),flush=True)


if __name__=='__main__':main()
