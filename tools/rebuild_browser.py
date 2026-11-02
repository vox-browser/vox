#!/usr/bin/env python3
"""Serialize canonical production builds and coalesce post-commit requests."""
import argparse
from contextlib import contextmanager
import ctypes
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
HOOK = '''#!/bin/sh
# Vox canonical production rebuild hook; managed by tools/rebuild_browser.py.
set -eu
repo=$(git rev-parse --show-toplevel)
exec python3 "$repo/tools/rebuild_browser.py" --request
'''


def git(root, *args):
    env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
    return subprocess.check_output(['git', '-C', str(root), *args], env=env)


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as file:
        json.dump(value, file, indent=2, sort_keys=True)
        file.write('\n')
        temporary = Path(file.name)
    temporary.replace(path)


@contextmanager
def lock(path, nonblocking=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as file:
        try:
            fcntl.flock(file, fcntl.LOCK_EX | (fcntl.LOCK_NB if nonblocking else 0))
        except BlockingIOError:
            yield None
            return
        try:
            yield file
        finally:
            fcntl.flock(file, fcntl.LOCK_UN)


def validate_repository(root):
    if not (root / '.git').is_dir() or git(root, 'branch', '--show-current').strip() != b'master':
        raise RuntimeError('Production builds require master in the canonical checkout')


def production_environment(environment):
    # A commit from a profiling/benchmark shell must not publish its diagnostics
    # or private implementation overrides as the shared production browser.
    retained = {'LADYBIRD_SOURCE_DIR', 'LADYBIRD_VCPKG_TRIPLET'}
    return {k: v for k, v in environment.items()
            if not k.startswith(('GIT_', 'VOX_', 'LADYBIRD_')) or k in retained}


def enqueue(root, background=True):
    validate_repository(root)
    state = root / 'Build/production-build'
    with lock(state / 'queue.lock'):
        write_json(state / 'request.json', dict(id=uuid.uuid4().hex,
                   head=git(root, 'rev-parse', 'HEAD').decode().strip()))
        if background:
            with (state / 'worker.log').open('ab') as log:
                subprocess.Popen([sys.executable, str(root / 'tools/rebuild_browser.py'), '--worker'],
                    cwd=root, env=production_environment(os.environ), stdin=subprocess.DEVNULL,
                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)


def repository_state(root):
    digest = hashlib.sha256()
    names = git(root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0')
    for name in sorted(set(names) - {b''}):
        relative = os.fsdecode(name)
        if relative.endswith('.swp') or '.v3cc.' in relative:
            continue
        path = root / relative
        digest.update(name + b'\0')
        if path.is_symlink():
            digest.update(os.fsencode(os.readlink(path)))
        elif path.is_file():
            with path.open('rb') as file:
                for block in iter(lambda: file.read(1024 * 1024), b''):
                    digest.update(block)
        else:
            digest.update(b'missing')
    return dict(head=git(root, 'rev-parse', 'HEAD').decode().strip(),
                repository_sha256=digest.hexdigest(),
                dirty=bool(git(root, 'status', '--porcelain')))


def exchange_directories(source, target):
    """Publish a complete signed app without exposing an absent/partial bundle."""
    if not target.exists():
        source.replace(target)
        return
    library = ctypes.CDLL(None, use_errno=True)
    if sys.platform == 'darwin':
        exchange = library.renameatx_np
        exchange.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int,
                             ctypes.c_char_p, ctypes.c_uint]
        result = exchange(-2, os.fsencode(source), -2, os.fsencode(target), 2)
    else:
        raise RuntimeError('Atomic application-directory publication requires macOS')
    if result:
        raise OSError(ctypes.get_errno(), 'Atomic bundle publication failed')


def publish(root, stage):
    platform = 'v' if sys.platform == 'darwin' else 'linux'
    target = root / 'Build' / platform
    target.mkdir(parents=True, exist_ok=True)
    if sys.platform == 'darwin':
        exchange_directories(stage / 'Vox.app', target / 'Vox.app')
    # Shared native-test helper libraries remain available at their established
    # paths. The app itself has bundle-local runtime dependencies.
    for path in stage.iterdir():
        if path.is_file() and path.suffix in ('.dylib', '.so'):
            path.replace(target / path.name)
    if sys.platform != 'darwin':
        (stage / 'vox').replace(target / 'vox')


def run_build(root, stage, receipt, environment):
    environment = {k: v for k, v in environment.items() if not k.startswith('GIT_')}
    environment.update(VOX_BUILD_SUPERVISED='1', VOX_BUILD_OUTPUT_DIR=str(stage))
    guard = root / 'tools/run_memory_bounded.py'
    with (receipt / 'build.log').open('wb') as log:
        result = subprocess.run([sys.executable, str(guard), '--lock',
            str(root / 'Build/production-build/memory.lock'), '--report',
            str(receipt / 'memory.json'), '--', 'sh', str(root / 'build-prod-browser.sh')],
            cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        return result.returncode
    executable = (stage / 'Vox.app/Contents/MacOS/Vox' if sys.platform == 'darwin' else stage / 'vox')
    smoke_environment = dict(environment, VOX_PROFILE_DIR=str(stage / 'smoke-profile'), VOX_TEST_WINDOW='1')
    with (receipt / 'smoke.log').open('wb') as log:
        return subprocess.run([sys.executable, str(guard), '--limit-gib', '3', '--lock',
            str(root / 'Build/production-build/smoke.lock'), '--report',
            str(receipt / 'smoke-memory.json'), '--', str(executable), '--headless-smoke'],
            cwd=root, env=smoke_environment, stdout=log, stderr=subprocess.STDOUT).returncode


def build_pending(root, runner=run_build, foreground=False):
    validate_repository(root)
    state = root / 'Build/production-build'
    with lock(state / 'build.lock', nonblocking=True) as build_lock:
        if build_lock is None:
            print('Production build already running; latest request is recorded.', flush=True)
            return 75 if foreground else 0
        while True:
            request = json.loads((state / 'request.json').read_text())
            before = repository_state(root)
            name = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-') + uuid.uuid4().hex[:8]
            receipt = state / 'receipts' / name
            receipt.mkdir(parents=True)
            with tempfile.TemporaryDirectory(prefix='.production-output-', dir=root / 'Build') as temporary:
                stage = Path(temporary)
                code = runner(root, stage, receipt, os.environ.copy())
                record = dict(request=request, inputs=before, exit=code)
                if code:
                    write_json(receipt / 'result.json', record)
                    print('Production build failed; previous bundle retained. See ' + str(receipt), flush=True)
                    with lock(state / 'queue.lock'):
                        latest = json.loads((state / 'request.json').read_text())
                        if latest['id'] != request['id'] or repository_state(root) != before:
                            continue
                        fcntl.flock(build_lock, fcntl.LOCK_UN)
                        return code
                after = repository_state(root)
                if before != after:
                    record['superseded'] = True
                    write_json(receipt / 'result.json', record)
                    continue
                publish(root, stage)
                executable = (root / 'Build/v/Vox.app/Contents/MacOS/Vox' if sys.platform == 'darwin'
                              else root / 'Build/linux/vox')
                record['executable'] = str(executable)
                record['executable_sha256'] = hashlib.sha256(executable.read_bytes()).hexdigest()
                write_json(receipt / 'result.json', record)
                write_json(state / 'latest.json', record)
            # Release the build lock under the queue lock, so a commit between
            # the final request check and unlock cannot lose its wake-up.
            with lock(state / 'queue.lock'):
                latest = json.loads((state / 'request.json').read_text())
                if latest['id'] == request['id'] or repository_state(root) == after:
                    fcntl.flock(build_lock, fcntl.LOCK_UN)
                    print('Published canonical production browser: ' + before['head'], flush=True)
                    return 0


def install_hook(root):
    validate_repository(root)
    path = Path(git(root, 'rev-parse', '--git-path', 'hooks/post-commit').decode().strip())
    if not path.is_absolute():
        path = root / path
    hooks = path.parent
    if not hooks.resolve().is_relative_to(root.resolve()):
        raise RuntimeError('Shared external hooks directory retained; install the Vox request manually')
    hooks.mkdir(parents=True, exist_ok=True)
    if path.exists() and path.read_text() != HOOK:
        raise RuntimeError('Existing post-commit hook retained; install the Vox request manually')
    path.write_text(HOOK)
    path.chmod(0o755)
    print('Installed canonical master rebuild hook: ' + str(path))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument('--install-hook', action='store_true')
    modes.add_argument('--request', action='store_true')
    modes.add_argument('--worker', action='store_true')
    modes.add_argument('--build', action='store_true')
    args = parser.parse_args()
    if args.install_hook:
        install_hook(ROOT)
        return 0
    if args.request:
        enqueue(ROOT)
        return 0
    if args.build:
        enqueue(ROOT, background=False)
    return build_pending(ROOT, foreground=args.build)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('Production build: ' + str(error), file=sys.stderr)
        sys.exit(1)
