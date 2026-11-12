#!/usr/bin/env python3
"""Check a fresh Vox process against the unchanged archived Brave homepage.

This rendering check collects no instruction-count or performance acceptance data.
The existing memory guard supervises its browser child with a 3 GiB budget.
"""
import argparse
import json
import os
from pathlib import Path
import threading

from chatgpt_browser_instructions import (
    SELECTORS, URL, content_gate, source_expectations, viewport_button_identities,
    vox_replay_environment,
)
from check_pixel_equality import compare
from forum_news_pixels import executable_identity, guarded, write_json
from measure_sealed_github_instructions import fingerprint, require
from page_archive import Replay, load_archive

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'Tests/Browser/Brave/archives/chatgpt-home-20261104-v2'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path,
                        default=ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--output', type=Path, required=True,
                        help='New, private job directory; existing output is rejected')
    parser.add_argument('--diff-tool', type=Path,
                        default=ROOT / 'Build/pixel-tools/pixel_diff')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    vox = args.vox.resolve()
    archive = FIXTURE / 'archive'
    reference = FIXTURE / 'reference/document.png'
    manifest = load_archive(archive)
    reference_audit = json.loads((FIXTURE / 'reference/audit.json').read_text())
    paths = {path for path in FIXTURE.rglob('*') if path.is_file()}
    paths.update([Path(__file__).resolve(), args.diff_tool.resolve()])
    pins = fingerprint(paths)
    identity = executable_identity(vox)
    write_json(output / 'inputs.json', dict(files=pins, executable=identity))
    write_json(output / 'audit-config.json', dict(selectors=SELECTORS,
                                                describe_native_errors=True))
    replay = Replay(archive, output / 'replay')
    worker = threading.Thread(target=replay.server.serve_forever, daemon=True)
    worker.start()
    try:
        env = {key: value for key, value in os.environ.items()
               if not key.lower().endswith('_proxy')
               and not key.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_'))}
        env.update(vox_replay_environment(replay.ready['proxy'], replay.ready['ca'], True))
        env.update(VOX_PROFILE_DIR=str(output / 'profile'), VOX_TEST_WINDOW='1',
                   VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_SCALE='2',
                   LADYBIRD_SCREENSHOT_DELAY_SECONDS='8',
                   LADYBIRD_CACHE_DIR=str(output / 'cache'),
                   VOX_CAPTURE_AUDIT_PATH=str(output / 'audit.json'),
                   VOX_CAPTURE_AUDIT_CONFIG=str(output / 'audit-config.json'))
        guarded([vox, '--window-width', '1024', '--window-height', '852',
                 '--screenshot-viewport-height', '768', '--screenshot',
                 output / 'actual.png', URL], output / 'capture', 150, env)
        require(executable_identity(vox) == identity, 'Browser identity changed during capture')
        require(fingerprint(paths) == pins, 'Fixture, reference or diff tool changed')
        audit = json.loads((output / 'audit.json').read_text())
        content = content_gate(audit, reference_audit['title'],
                               source_expectations(archive, manifest),
                               viewport_button_identities(reference_audit))
        pixels = compare(reference, output / 'actual.png', output / 'diff.png', args.diff_tool)
        write_json(output / 'result.json', dict(content=content, pixels=pixels,
                                               executable=identity))
        print(json.dumps(pixels, indent=2))
        require(pixels['exact'], 'ChatGPT differs from the unchanged Brave reference')
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        worker.join(timeout=5)


if __name__ == '__main__':
    main()
