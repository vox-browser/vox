#!/usr/bin/env python3
"""Cache a checked V compiler with isolated late-match locals, without editing V."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from prepare_http_compat import compiler_vlib


def needs_fix(source):
    signature = 'fn (mut t Transformer) lower_remaining_matches_in_used_fns() {'
    if signature not in source:
        return False  # Legacy compiler, with a different transform.
    body = source.split(signature, 1)[1].split('\n}', 1)[0]
    return 'seed_generated_fn_body_context' not in body


def prepare(compiler):
    compiler = Path(compiler).resolve()
    previous = compiler.parent / 'manifest.json'
    if previous.is_file() and (compiler.parent / 'patched.txt').is_file():
        record = json.loads(previous.read_text())
        if record.get('sha256') == hashlib.sha256(compiler.read_bytes()).hexdigest():
            return compiler
    with tempfile.TemporaryDirectory(prefix='vox-v-root-') as scratch:
        vlib = compiler_vlib(str(compiler), Path(scratch)).resolve()
    transform = vlib / 'v/transform/transform.v'
    if not transform.is_file() or not needs_fix(transform.read_text()):
        return compiler
    repo = Path(__file__).resolve().parents[1]
    wrapper = repo / 'tools/v_match_scope_cc.py'
    digest = hashlib.sha256(compiler.read_bytes() + wrapper.read_bytes() + Path(__file__).read_bytes())
    # Include the self-hosted compiler sources, not only the bootstrap binary.
    for path in sorted((vlib / 'v').rglob('*.v')):
        if not path.name.endswith('_test.v'):
            digest.update(str(path.relative_to(vlib)).encode() + b'\0' + path.read_bytes())
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'vox/compilers'
    root = cache / ('match-scope-' + digest.hexdigest()[:24])
    root.mkdir(parents=True, exist_ok=True)
    with (root / 'prepare.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        target = root / 'v'
        manifest = root / 'manifest.json'
        if manifest.is_file() and target.is_file():
            if json.loads(manifest.read_text())['sha256'] == hashlib.sha256(target.read_bytes()).hexdigest():
                return target
        for name in ('vlib', 'thirdparty', 'cmd', 'v.mod'):
            link = root / name
            source = vlib if name == 'vlib' else vlib.parent / name
            if not link.is_symlink() and not link.exists():
                link.symlink_to(source, target_is_directory=source.is_dir())
            if link.resolve() != source.resolve():
                raise RuntimeError('Unexpected compiler cache entry: ' + str(link))
        print('Preparing V late-match scope fix (generic checks stay enabled)…', file=sys.stderr, flush=True)
        (root / 'patched.txt').unlink(missing_ok=True)
        environment = dict(os.environ, VFLAGS='', V_MACOS_V3_NO_FALLBACK='1',
                           VOX_MATCH_SCOPE_CC=shutil.which('clang') or 'cc',
                           VOX_MATCH_SCOPE_RECEIPT=str(root / 'patched.txt'))
        with tempfile.TemporaryDirectory(prefix='build-', dir=root) as scratch:
            scratch = Path(scratch)
            command = [str(compiler), '-b', 'c', '-nocache', '-memory-limit', '10G', '-cc', str(wrapper),
                       '-prod', '-o', str(scratch / 'v')]
            for backend in ('fastc', 'x64', 'amd64', 'arm64', 'ssa', 'eval', 'wasm'):
                command += ['-d', 'skip_' + backend]
            command += [str(vlib.parent / 'cmd/v')]
            guarded = [sys.executable, str(repo / 'tools/run_memory_bounded.py'),
                       '--lock', str(scratch / 'compile.lock'), '--report', str(scratch / 'compile.json'),
                       '--', *command]
            with (root / 'build.log').open('w') as log:
                subprocess.run(guarded, cwd=vlib.parent, env=environment,
                               stdout=log, stderr=subprocess.STDOUT, check=True)
            if not (root / 'patched.txt').is_file():
                raise RuntimeError('V compiler scope fix was not applied; see ' + str(root / 'build.log'))
            os.replace(scratch / 'v', target)
        manifest.write_text(json.dumps({'bootstrap': str(compiler),
                                       'vlib': str(vlib), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest()}))
        return target


if __name__ == '__main__':
    print(prepare(sys.argv[1]))
