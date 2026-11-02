#!/usr/bin/env python3
"""Verify real tab PIDs, retained documents, crash isolation and native chrome.

Run through tools/run_memory_bounded.py on macOS. Retains logs and snapshots in
--output; browser windows use the display away from the pointer.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time


def main():
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=repo / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    binary = args.binary.resolve()
    identity_paths = [binary, *sorted(binary.parent.glob('*.dylib'))]
    worker = binary.parent / 'VoxAdblockWorker'
    if worker.is_file():
        identity_paths.append(worker)
    identities = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in identity_paths}
    library = output / 'probe.dylib'
    subprocess.run(['clang', '-dynamiclib', '-fobjc-arc', '-fblocks', '-framework', 'Cocoa',
                    '-framework', 'QuartzCore', str(repo / 'tools/native_browser_tab_process_test.m'),
                    '-o', str(library)], check=True)
    page = output / 'first.html'
    page.write_text('<!doctype html><title>Process First</title><body style="background:#159b53">'
                    '<input id="retained" value="Keep this document">'
                    '<script>window.processIdentity=Math.random();document.title="Process First "+window.processIdentity;</script>')
    second_page = output / 'second.html'
    second_page.write_text('<!doctype html><title>Process Second</title><body style="background:#394cad">Second process')
    profile = output / 'profile'
    profile.mkdir()
    (profile / 'settings.json').write_text(json.dumps({'allow_any_site': True}) + '\n')
    env = dict(os.environ, VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(output / 'profile'),
               LADYBIRD_CACHE_DIR=str(output / 'cache'), VOX_TAB_PROBE_DIR=str(output),
               DYLD_INSERT_LIBRARIES=str(library))
    for name in ('VOX_TAB_GROUP', 'VOX_TAB_ID', 'VOX_PROFILE_SCROLL', 'VOX_PROFILE_INSTRUCTIONS'):
        env.pop(name, None)
    log = (output / 'browser.log').open('w')
    root = subprocess.Popen([str(binary), '--window-width=800', '--window-height=684', str(page)],
                            env=env, stdout=log, stderr=subprocess.STDOUT)
    snapshots = []
    known = {root.pid}
    folder = None

    def state():
        nonlocal folder
        if folder is None:
            # Current V uses /tmp; older compilers honor the launcher's TMPDIR.
            roots = {Path('/tmp'), Path(os.environ.get('TMPDIR', '/tmp'))}
            for candidate in (path for root in roots for path in root.glob('vox-tabs-*')):
                try:
                    data = json.loads((candidate / 'state.json').read_text())
                    if any(tab['pid'] == root.pid and tab['url'] == page.as_uri()
                           for tab in data['tabs']):
                        folder = candidate
                        break
                except (OSError, ValueError, KeyError):
                    continue
        if folder is None:
            return None
        try:
            data = json.loads((folder / 'state.json').read_text())
            known.update(tab['pid'] for tab in data['tabs'])
            return data
        except (OSError, ValueError):
            return None

    def report(pid):
        try:
            return json.loads((output / f'{pid}.json').read_text())
        except (OSError, ValueError):
            return {}

    def wait(description, predicate, timeout=45):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            data = state()
            if data and predicate(data):
                for tab in data['tabs']:
                    window = report(tab['pid'])
                    if window.get('painted'):
                        assert Path(window['executable']).resolve() == binary, window
                snapshots.append({'check': description, 'state': data,
                                  'windows': {pid: report(pid) for pid in sorted(known)}})
                return data
            time.sleep(.05)
        raise AssertionError(f'timed out: {description}; state={state()}; reports={[(pid,report(pid)) for pid in known]}')

    def command(pid, action, **values):
        temporary = output / f'{pid}.command.tmp'
        temporary.write_text(json.dumps(dict(action=action, **values)))
        temporary.replace(output / f'{pid}.command.json')

    def selected(data):
        return next(tab['pid'] for tab in data['tabs'] if tab['id'] == data['selected'])

    try:
        wait('initial page rendered', lambda s: report(root.pid).get('painted') and
             report(root.pid).get('title', '').startswith('Process First'))
        assert Path(report(root.pid)['first_image']).resolve() == library, 'probe did not become dyld image zero'
        first_frame = report(root.pid)['frame']
        first_title = report(root.pid)['title']
        command(root.pid, 'new')
        data = wait('new tab has independent ready process', lambda s: len(s['tabs']) == 2 and
                    selected(s) != root.pid and report(selected(s)).get('visible') and
                    report(selected(s)).get('painted') and not report(root.pid).get('visible'))
        second = selected(data)
        assert second != root.pid
        assert report(second)['frame'] == first_frame
        # AppKit schedules its last-window termination check after orderOut:.
        # Keep the original hidden long enough to catch a group-wide shutdown.
        time.sleep(3)
        assert root.poll() is None, 'hiding the original tab terminated its process'
        os.kill(second, 0)
        command(second, 'navigate', url=second_page.as_uri())
        wait('second process navigated', lambda s: report(second).get('title','').startswith('Process Second'))
        command(second, 'minimize')
        wait('selected tab minimized', lambda s: report(second).get('minimized'))
        command(root.pid, 'reopen')
        wait('reopening hidden original restores selected tab', lambda s: selected(s) == second and
             report(second).get('active') and report(second).get('visible') and
             not report(second).get('minimized') and not report(root.pid).get('visible'))
        assert report(second)['title'].startswith('Process Second')
        assert report(second)['frame'] == first_frame
        command(second, 'select', index=0)
        wait('original document retained after switch', lambda s: selected(s) == root.pid and
             report(root.pid).get('visible') and report(root.pid).get('title') == first_title and
             not report(second).get('visible'))
        command(root.pid, 'new')
        data = wait('third tab has a third PID', lambda s: len(s['tabs']) == 3 and selected(s) not in (root.pid, second)
                    and report(selected(s)).get('visible'))
        third = selected(data)
        assert len({root.pid, second, third}) == 3
        # Kill an inactive page. The selected document must survive and the
        # dead process must disappear from every responsive tab's chrome.
        os.kill(second, signal.SIGKILL)
        wait('crashed background tab removed', lambda s: len(s['tabs']) == 2 and
             selected(s) == third and report(third).get('visible'))
        command(third, 'close', index=0)
        root.wait(timeout=15)
        wait('closing original process leaves child running', lambda s: len(s['tabs']) == 1 and
             s['tabs'][0]['pid'] == third and report(third).get('visible'))
        command(third, 'new')
        data = wait('surviving child can create another process', lambda s: len(s['tabs']) == 2 and
                    selected(s) != third and report(selected(s)).get('visible'))
        fourth = selected(data)
        # A foreground crash transfers selection back to the surviving page.
        os.kill(fourth, signal.SIGKILL)
        wait('foreground crash recovers surviving tab', lambda s: len(s['tabs']) == 1 and
             selected(s) == third and report(third).get('visible'))
        command(third, 'close', index=0)
        data = wait('closing last tab starts replacement process', lambda s: len(s['tabs']) == 1 and
                    s['tabs'][0]['pid'] != third and report(s['tabs'][0]['pid']).get('visible'))
        replacement = data['tabs'][0]['pid']
        command(replacement, 'window-close')
        deadline = time.monotonic() + 15
        while folder.exists() and time.monotonic() < deadline:
            time.sleep(.05)
        assert not folder.exists(), 'closing the visible window did not end the group'
        snapshots.append({'check': 'closing the window ends the group', 'pid': replacement})
        print('PASS native tab processes: unique PIDs, selection, navigation, reopen, crashes, parent exit, last-tab replacement, window close')
    finally:
        state()
        for pid in known:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        try:
            root.wait(timeout=10)
        except subprocess.TimeoutExpired:
            root.kill()
            root.wait()
        log.close()
        (output / 'results.json').write_text(json.dumps(dict(binary=str(binary),
             sha256=identities[str(binary)], identities=identities,
             pids=sorted(known), checks=snapshots), indent=2))
        if folder and folder.exists():
            import shutil
            shutil.rmtree(folder)
        assert all(hashlib.sha256(Path(path).read_bytes()).hexdigest() == digest
                   for path, digest in identities.items()), 'browser build changed during the run'


if __name__ == '__main__':
    main()
