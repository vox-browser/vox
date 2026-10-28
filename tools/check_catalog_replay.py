#!/usr/bin/env python3
"""Check an installed Vox against pinned Brave catalog pixels, without a source copy.

Run through tools/run_memory_bounded.py --limit-gib 3. The sealed archive and
successful reference receipt remain external inputs; this never refreshes them,
builds a browser, or forwards missing resources to the network.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import threading
import time

from PIL import Image, ImageChops

from page_archive import Replay
from wikipedia_browser_memory import clean_environment, placement

REPO = Path(__file__).resolve().parents[1]
TITLE = '/pol/ - Politically Incorrect - Catalog - 4chan'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(binary):
    return {str(p): sha(p) for p in [binary, *sorted(binary.parent.glob('*.dylib'))]}


def validate_document(audit, metadata):
    for key, expected in [('url', metadata['url']), ('title', TITLE), ('ready', 'complete'),
                          ('viewport_width', metadata['width']),
                          ('viewport_height', metadata['height'])]:
        if audit.get(key) != expected:
            raise ValueError(f'Unexpected document {key}: {audit.get(key)!r}')
    selections = {s['selector']: s for s in audit['selections']}
    if selections['.thread']['count'] != 201:
        raise ValueError('Archived catalog must contain all 201 threads')
    root = selections['html']['elements'][0]['rect']
    title = selections['.boardTitle']['elements'][0]['rect']
    if abs(title['y'] - metadata['board_title_y']) > .001:
        raise ValueError('Requested scroll position was not reached')
    # The native audit exposes a fractional root bounding box; Brave's CSSOM
    # scrollHeight is an integer and can exclude the fractional trailing edge.
    # This readiness check allows that one CSS pixel; image equality stays exact.
    if abs(root['height'] - metadata['scroll_height']) >= 1:
        raise ValueError('Document height differs from the Brave reference')
    thumbnails = selections['.thumb']['elements']
    if len(thumbnails) < 8 or any(not e['image']['complete'] or
                                e['image']['natural_width'] <= 0 for e in thumbnails):
        raise ValueError('Catalog thumbnails have not decoded')


def compare_pixels(reference, actual, diff_path):
    with Image.open(reference) as a, Image.open(actual) as b:
        if a.size != b.size:
            raise ValueError(f'Viewport pixel dimensions differ: {a.size} != {b.size}')
        diff = ImageChops.difference(a.convert('RGBA'), b.convert('RGBA'))
        count = sum(any(pixel) for pixel in diff.getdata())
        diff.convert('RGB').point(lambda value: min(255, value * 8)).save(diff_path)
        return dict(differing_pixels=count, total_pixels=a.width * a.height)


def load_cases(receipt, requested):
    if receipt.get('strict_controlled_catalog_pixels_pass') is not True:
        raise ValueError('Reference receipt must describe a successful independent comparison')
    cases = [r for r in receipt['checks']
             if re.fullmatch(r'catalog-scroll-\d+|viewport-\d+x\d+', r['name'])]
    if requested:
        missing = set(requested) - {r['name'] for r in cases}
        if missing:
            raise ValueError(f'Unknown catalog cases: {sorted(missing)}')
        cases = [r for r in cases if r['name'] in requested]
    if not cases:
        raise ValueError('No catalog references selected')
    for row in cases:
        if sha(Path(row['reference'])) != row['reference_sha256']:
            raise ValueError(f"Reference image changed: {row['name']}")
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--reference-result', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--binary', type=Path,
                        default=REPO / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--case', action='append', default=[])
    args = parser.parse_args()
    receipt = json.loads(args.reference_result.read_text())
    cases = load_cases(receipt, args.case)
    output, binary = args.output.resolve(), args.binary.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = dict(started=time.time(), binary_identity=identity(binary),
                  reference_receipt=str(args.reference_result.resolve()),
                  reference_receipt_sha256=sha(args.reference_result),
                  reference_identity=receipt['reference_identity'], rows=[],
                  strict_controlled_catalog_pixels_pass=False)

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    config = output / 'audit-config.json'
    config.write_text(json.dumps({'selectors': [dict(name=s, selector=s, limit=n)
                                              for s, n in [('html', 1), ('.boardTitle', 1), ('.thread', 1),
                                                           ('.thumb', 8)]]}) + '\n')
    replay = None
    thread = None
    save()
    try:
        screen = placement()
        if screen['scale'] != 2:
            raise ValueError('These references require native display scale 2')
        report['screen'] = screen
        replay = Replay(args.archive, output / 'replay')
        thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
        thread.start()
        report['replay'] = replay.ready
        for case in cases:
            name = case['name']
            reference = Path(case['reference'])
            metadata = json.loads(reference.with_name(
                reference.name.replace('@2x.png', '.json')).read_text())
            styles = json.loads(reference.with_name(
                reference.name.replace('@2x.png', '-styles.json')).read_text())
            metadata['board_title_y'] = next(
                s['rect']['y'] for s in styles if s['selector'] == 'boardTitle')
            width, height = metadata['width'], metadata['height']
            if (metadata['url'] != replay.manifest['url'] or metadata['title'] != TITLE or
                    metadata['scale'] != 2 or metadata['scroll_x'] != 0):
                raise ValueError(f'Invalid reference document: {name}')
            profile = tempfile.mkdtemp(prefix=name + '-profile-', dir=output)
            env = clean_environment()
            env.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
                       NO_PROXY='', VOX_PROFILE_DIR=profile, LADYBIRD_SCREENSHOT_SCALE='2',
                       VOX_SCREENSHOT_NATIVE_LAYOUT='1', LADYBIRD_SCREENSHOT_DELAY_SECONDS='8',
                       VOX_CAPTURE_AUDIT_PATH=str(output / (name + '-audit.json')),
                       VOX_CAPTURE_AUDIT_CONFIG=str(config))
            window = output / (name + '-window.png')
            actual = output / (name + '.png')
            command = [str(binary), '--window-width', str(width), '--window-height',
                       str(height + 84), '--screenshot-scroll-y', str(metadata['scroll_y']),
                       '--screenshot', str(window), metadata['url']]
            row = dict(name=name, command=command, profile=profile, started=time.time())
            report['rows'].append(row)
            save()
            with (output / (name + '.log')).open('w') as log:
                process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
                row['pid'] = process.pid
                row['timed_out'] = False
                try:
                    process.wait(timeout=70)
                except subprocess.TimeoutExpired:
                    row['timed_out'] = True
                    process.kill()
                    process.wait()
                row.update(exit_code=process.returncode, finished=time.time())
            if row['exit_code'] or row['timed_out']:
                raise RuntimeError(f'Browser capture failed: {name}: {row}')
            validate_document(json.loads((output / (name + '-audit.json')).read_text()), metadata)
            with Image.open(window) as image:
                if image.size != (width * 2, (height + 84) * 2):
                    raise ValueError(f'Unexpected native window size: {image.size}')
                image.crop((0, 120, width * 2, (height + 60) * 2)).save(actual)
            row.update(compare_pixels(reference, actual, output / (name + '-diff.png')))
            row.update(reference=str(reference), reference_sha256=sha(reference),
                       actual_sha256=sha(actual))
            if row['reference_sha256'] != case['reference_sha256']:
                raise ValueError(f'Reference changed during capture: {name}')
            save()
            print(f"{name}: {row['differing_pixels']} / {row['total_pixels']} pixels differ", flush=True)
        report['strict_controlled_catalog_pixels_pass'] = all(
            r['differing_pixels'] == 0 for r in report['rows'])
    except Exception as error:
        report['error'] = str(error)
    finally:
        if replay and thread:
            replay.server.shutdown()
            replay.server.server_close()
            thread.join()
        report['identity_unchanged'] = identity(binary) == report['binary_identity']
        report['reference_receipt_unchanged'] = sha(args.reference_result) == report['reference_receipt_sha256']
        if not report['identity_unchanged'] or not report['reference_receipt_unchanged']:
            report['strict_controlled_catalog_pixels_pass'] = False
        report['finished'] = time.time()
        save()
    return 0 if report['strict_controlled_catalog_pixels_pass'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
