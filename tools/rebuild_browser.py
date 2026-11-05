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
from browser_bundle_lease import publication_lease

ROOT = Path(__file__).resolve().parents[1]
# Large optimized C builds need more wall time when the shared host is busy.
# Keep the memory guard's default aggregate RSS budget.
PRODUCTION_BUILD_TIMEOUT_SECONDS = 45 * 60
BUILD_PROTOCOL = 'bundle-lease-v1'
WORKER_UPGRADE_LOCK = 'upgrade-bundle-lease-v1.lock'
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


def read_json(path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return None


def pending_c_mode(state):
    """An explicit single-unit request survives later automatic requests until a build starts it."""
    pending = read_json(state / 'request.json') or {}
    started = read_json(state / 'started.json') or {}
    if pending.get('c_mode') == 'single' and started.get('id') != pending.get('id'):
        return 'single'
    return 'parallel'


def enqueue(root, background=True, c_mode=None):
    validate_repository(root)
    state = root / 'Build/production-build'
    with lock(state / 'queue.lock'):
        write_json(state / 'request.json', dict(id=uuid.uuid4().hex,
                   head=git(root, 'rev-parse', 'HEAD').decode().strip(),
                   c_mode=c_mode or pending_c_mode(state)))
        if background:
            with (state / 'worker.log').open('ab') as log:
                subprocess.Popen([sys.executable, str(root / 'tools/rebuild_browser.py'), '--worker'],
                    cwd=root, env=production_environment(os.environ), stdin=subprocess.DEVNULL,
                    stdout=log, stderr=subprocess.STDOUT, start_new_session=True, close_fds=True)


def production_input_path(relative):
    path = Path(relative)
    # Tests are not compiled into the app. Native headers remain inputs even
    # when their names mention tests: some host environment-driven checks.
    test_tool = relative.startswith('tools/') and (
        (path.stem.endswith('_test') and path.suffix in {'.py', '.c', '.cpp', '.m', '.mm'})
        or (path.name.startswith('test_') and path.suffix == '.py'))
    return not (relative.startswith(('docs/', 'Tests/'))
                or relative.endswith('_test.v') or test_tool
                or relative in {'AGENTS.md', 'OPTIMIZED_SITES.md'})


def repository_state(root):
    digest = hashlib.sha256()
    build_digest = hashlib.sha256()
    names = git(root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0')
    for name in sorted(set(names) - {b''}):
        relative = os.fsdecode(name)
        if relative.endswith('.swp') or '.v3cc.' in relative:
            continue
        path = root / relative
        # Keep the full repository receipt, but publication depends on inputs
        # consumed by the build. Site reports and agent instructions are not
        # compiler, resource, packaging, or helper inputs.
        production_input = production_input_path(relative)
        def update(data):
            digest.update(data)
            if production_input:
                build_digest.update(data)
        update(name + b'\0')
        if path.is_symlink():
            update(os.fsencode(os.readlink(path)))
        elif path.is_file():
            with path.open('rb') as file:
                for block in iter(lambda: file.read(1024 * 1024), b''):
                    update(block)
        else:
            update(b'missing')
    return dict(head=git(root, 'rev-parse', 'HEAD').decode().strip(),
                repository_sha256=digest.hexdigest(),
                build_inputs_sha256=build_digest.hexdigest(),
                dirty=bool(git(root, 'status', '--porcelain')))


def same_build_inputs(before, after):
    if 'build_inputs_sha256' in before and 'build_inputs_sha256' in after:
        return before['build_inputs_sha256'] == after['build_inputs_sha256']
    return before == after


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
    with publication_lease(root):
        publish_unlocked(root, stage)


def publish_unlocked(root, stage):
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
    environment.update(VOX_BUILD_SUPERVISED='1', VOX_BUILD_OUTPUT_DIR=str(stage),
                       VOX_BUILD_COMPILE_PROTOCOL=BUILD_PROTOCOL,
                       VOX_BUILD_RECEIPT_DIR=str(receipt))
    guard = root / 'tools/run_memory_bounded.py'
    # sh reads a script file incrementally. Editing that file while the compiler
    # runs can move its unread tail and manufacture an EOF/quoting error. Read
    # the canonical entry point once, then let the guarded shell consume those
    # bytes in memory. Keep $0 and relative helper paths anchored to the checkout;
    # do not copy repository tools into the receipt or staging directory.
    script = root / ('build-linux-browser.sh' if sys.platform == 'linux' else 'build-prod-browser.sh')
    script_bytes = script.read_bytes()
    write_json(receipt / 'build-script.json', dict(path=str(script), bytes=len(script_bytes),
               sha256=hashlib.sha256(script_bytes).hexdigest(), delivery='memory through stdin'))
    with (receipt / 'build.log').open('wb') as log:
        result = subprocess.run([sys.executable, str(guard), '--lock',
            str(root / 'Build/production-build/memory.lock'), '--report',
            str(receipt / 'memory.json'), '--timeout',
            str(PRODUCTION_BUILD_TIMEOUT_SECONDS), '--', 'sh', '-c',
            'exec sh -c "$(cat)" "$0"', str(script)], input=script_bytes,
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
            write_json(state / 'started.json', dict(id=request.get('id')))
            before = repository_state(root)
            name = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-') + uuid.uuid4().hex[:8]
            receipt = state / 'receipts' / name
            receipt.mkdir(parents=True)
            with tempfile.TemporaryDirectory(prefix='.production-output-', dir=root / 'Build') as temporary:
                stage = Path(temporary)
                write_json(receipt / 'inputs-before.json', before)
                environment = os.environ.copy()
                environment['VOX_BUILD_C_MODE'] = request.get('c_mode') or 'parallel'
                code = runner(root, stage, receipt, environment)
                record = dict(request=request, inputs=before, exit=code)
                c_compile = read_json(receipt / 'c-compile.json')
                if c_compile is not None:
                    record['c_compile'] = c_compile
                if code:
                    write_json(receipt / 'result.json', record)
                    print('Production build failed; previous bundle retained. See ' + str(receipt), flush=True)
                    with lock(state / 'queue.lock'):
                        latest = json.loads((state / 'request.json').read_text())
                        if latest['id'] != request['id'] or not same_build_inputs(repository_state(root), before):
                            continue
                        fcntl.flock(build_lock, fcntl.LOCK_UN)
                        return code
                after = repository_state(root)
                record['verified_inputs'] = after
                frozen_path = receipt / 'frozen-compile.json'
                frozen = None
                if frozen_path.exists():
                    from freeze_browser_compile import validate
                    try:
                        frozen = validate(receipt, before)
                    except Exception as error:
                        record.update(exit=1, frozen_input_error=str(error))
                        write_json(receipt / 'result.json', record)
                        print('Frozen production inputs rejected: ' + str(error), flush=True)
                        with lock(state / 'queue.lock'):
                            latest = json.loads((state / 'request.json').read_text())
                            if latest['id'] != request['id'] or not same_build_inputs(repository_state(root), before):
                                continue
                            return 1
                    record['frozen_compilation'] = str(frozen_path)
                    record['repository_after_build'] = after
                    record['verified_inputs'] = frozen['source_inputs']
                if frozen is None and not same_build_inputs(before, after):
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
                if latest['id'] == request['id'] or same_build_inputs(repository_state(root), record['verified_inputs']):
                    fcntl.flock(build_lock, fcntl.LOCK_UN)
                    print('Published canonical production browser: ' + before['head'], flush=True)
                    return 0


def request_worker_upgrade(root):
    """Let the old worker finish; its next script entry yields without compiling."""
    state = root / 'Build/production-build'
    with (state / 'worker.log').open('ab') as log:
        subprocess.Popen([sys.executable, str(root / 'tools/rebuild_browser.py'),
                          '--worker-after-current'], cwd=root,
                         env=production_environment(os.environ), stdin=subprocess.DEVNULL,
                         stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                         close_fds=True)


def worker_after_current(root):
    state = root / 'Build/production-build'
    # Multiple stale entries can request an upgrade while editors are active.
    # One waiter owns the handoff. It neither interrupts the running compiler
    # nor enqueues another production request.
    with lock(state / WORKER_UPGRADE_LOCK, nonblocking=True) as upgrade_lock:
        if upgrade_lock is None:
            return 0
        with lock(state / 'build.lock'):
            pass
        return build_pending(root)


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
    modes.add_argument('--upgrade-worker', action='store_true')
    modes.add_argument('--worker-after-current', action='store_true')
    parser.add_argument('--no-parallel-cc', action='store_true',
                        help='with --build: compile one C unit for maximum binary performance')
    args = parser.parse_args()
    if args.no_parallel_cc and not args.build:
        parser.error('--no-parallel-cc requires --build')
    if args.install_hook:
        install_hook(ROOT)
        return 0
    if args.request:
        enqueue(ROOT)
        return 0
    if args.upgrade_worker:
        request_worker_upgrade(ROOT)
        return 0
    if args.worker_after_current:
        return worker_after_current(ROOT)
    if args.build:
        enqueue(ROOT, background=False, c_mode='single' if args.no_parallel_cc else 'parallel')
    return build_pending(ROOT, foreground=args.build)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('Production build: ' + str(error), file=sys.stderr)
        sys.exit(1)
