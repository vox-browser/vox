#!/usr/bin/env python3
"""Anchor replay Date while retaining elapsed time and original module bytes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time

from page_archive import load_archive

RUNTIME = 'https://github.githubassets.com/assets/wp-runtime-b3589eeb1e6a309e.js'
RUNTIME_SHA256 = 'cdee133e4527bd77016783002789cb673143cd385ff73d70e1be1dfe9cad346f'


def date_prefix(epoch_ms):
    if not isinstance(epoch_ms, int) or not 0 < epoch_ms < 8_640_000_000_000_000:
        raise ValueError('Date epoch must be a positive integer in the Date range')
    return r'''// Shared replay clock; original module follows unchanged.
(()=>{
const epoch=EPOCH_MS;
if(globalThis.__voxBenchmarkDateEpoch!==undefined){
 if(globalThis.__voxBenchmarkDateEpoch!==epoch)throw Error('Replay clock changed');
 return;
}
const NativeDate=globalThis.Date, construct=Reflect.construct;
const monotonic=performance.now.bind(performance), start=monotonic();
const now=()=>Math.floor(epoch+monotonic()-start);
function ReplayDate(...args){
 if(!new.target)return new NativeDate(now()).toString();
 return construct(NativeDate,args.length?args:[now()],new.target);
}
Object.setPrototypeOf(ReplayDate,NativeDate);
ReplayDate.prototype=NativeDate.prototype;
Object.defineProperties(ReplayDate,{
 name:{value:'Date',configurable:true},
 length:{value:7,configurable:true},
 now:{value:now,writable:true,configurable:true}
});
Object.defineProperty(ReplayDate.prototype,'constructor',{
 value:ReplayDate,writable:true,configurable:true
});
globalThis.Date=ReplayDate;
Object.defineProperty(globalThis,'__voxBenchmarkDateEpoch',{value:epoch,configurable:true});
document.documentElement.setAttribute('data-vox-benchmark-clock',String(epoch));
})();
'''.replace('EPOCH_MS', str(epoch_ms))


def prepare_archive(source, target, epoch_ms):
    manifest = load_archive(source)
    original = (source / 'bodies' / manifest['responses'][RUNTIME]['sha256']).read_bytes()
    if hashlib.sha256(original).hexdigest() != RUNTIME_SHA256:
        raise ValueError('Unreviewed GitHub runtime')
    prefix = date_prefix(epoch_ms).encode()
    body = prefix + original
    target.mkdir()
    (target / 'bodies').mkdir()
    # Fixture bodies are immutable. Share their bytes without copying browser
    # sources, tools, executables or bundles into benchmark directories.
    for entry in (source / 'bodies').iterdir():
        os.link(entry, target / 'bodies' / entry.name)
    digest = hashlib.sha256(body).hexdigest()
    (target / 'bodies' / digest).write_bytes(body)
    for url, entry in manifest['responses'].items():
        if url == RUNTIME or url.startswith(RUNTIME + '?'):
            if entry['sha256'] != RUNTIME_SHA256:
                raise ValueError('Runtime query alias differs from its original')
            entry.update(sha256=digest, bytes=len(body))
    manifest.update(sealed_unix=time.time(),
        author_scripts='Original bytes with shared Date-only replay prefix; site policies selected separately',
        replay_clock=dict(epoch_ms=epoch_ms, mode='Date advances with performance.now elapsed time',
            runtime=RUNTIME, original_sha256=RUNTIME_SHA256,
            prefixed_sha256=digest, prefix_sha256=hashlib.sha256(prefix).hexdigest(),
            performance_and_timers='unchanged'))
    (target / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    load_archive(target)
    return manifest['replay_clock']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('target', type=Path)
    parser.add_argument('--epoch-ms', type=int, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare_archive(args.source, args.target, args.epoch_ms), indent=2))
