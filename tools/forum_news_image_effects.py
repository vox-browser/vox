#!/usr/bin/env python3
"""Compare the TechCrunch photo/mask regression over sealed original-origin HTTP.

Run through tools/run_memory_bounded.py. This is a synthetic renderer regression,
not a live homepage. Both browsers receive the original encoded publisher WebP;
file-URL image loading would exercise a different native decoder.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import threading
import time
from types import SimpleNamespace

from check_pixel_equality import compare
from browser_bundle_lease import canonical_bundle_lease
from forum_news_pixels import (BRAVE, REPO, VOX, brave_identity, capture_site_archive,
                               executable_identity, oracle_command, run_case, write_json)
from page_archive import Replay, digest, load_archive

URL = 'https://techcrunch.com/__vox_regressions__/input/techcrunch-gradient-image.html'
IMAGE_URL = 'https://techcrunch.com/__vox_regressions__/resources/techcrunch-hero.webp'
IMAGE_SHA256 = '3598da0413efb545f388773186fad4a8df49d1cbfb5f346db47fae94e858eb89'
FIXTURE = REPO / 'Tests/Browser/Brave/input/techcrunch-gradient-image.html'
IMAGE = REPO / 'Tests/Browser/Brave/resources/techcrunch-hero.webp'
REFERENCE = REPO / 'Tests/Browser/Brave/expected/techcrunch-gradient-image.png'
ROOT_FIXTURE = REPO / 'Tests/Browser/Brave/input/transparent-root-atomic-effects.html'
ROOT_REFERENCE = REPO / 'Tests/Browser/Brave/expected/transparent-root-atomic-effects.png'
ROOT_URL = 'https://techcrunch.com/__vox_regressions__/input/transparent-root-atomic-effects.html'
MASK_TILE_FIXTURE = REPO / 'Tests/Browser/Brave/input/mask-image-parent-tiles.html'
MASK_TILE_REFERENCE = REPO / 'Tests/Browser/Brave/expected/mask-image-parent-tiles.png'
MASK_TILE_URL = 'https://techcrunch.com/__vox_regressions__/input/mask-image-parent-tiles.html'


def case_files(case='image-effects'):
    if case == 'image-effects':
        return FIXTURE, REFERENCE, URL
    if case == 'root-origin':
        return ROOT_FIXTURE, ROOT_REFERENCE, ROOT_URL
    if case == 'mask-tiles':
        return MASK_TILE_FIXTURE, MASK_TILE_REFERENCE, MASK_TILE_URL
    raise ValueError('Unknown image-effects case: ' + case)


def create_seed(directory, case='image-effects'):
    fixture, _, url = case_files(case)
    image = IMAGE.read_bytes()
    if digest(image) != IMAGE_SHA256:
        raise RuntimeError('The original encoded publisher response changed')
    directory.mkdir(parents=True, exist_ok=False)
    (directory / 'bodies').mkdir()
    responses = {}
    for resource_url, body, mime in [(url, fixture.read_bytes(), 'text/html;charset=utf-8'),
                                    (IMAGE_URL, image, 'image/webp')]:
        sha = digest(body)
        (directory / 'bodies' / sha).write_bytes(body)
        responses[resource_url] = dict(status=200, sha256=sha, bytes=len(body), headers=[
            dict(name='Content-Type', value=mime),
            dict(name='Content-Length', value=str(len(body)))])
    write_json(directory / 'manifest.json', dict(version=1, url=url,
        sealed_unix=time.time(), responses=responses,
        workload='Authored image-effects regression; original encoded publisher WebP'))
    load_archive(directory)


def source_pins(case='image-effects'):
    fixture, reference, _ = case_files(case)
    sources = [fixture, IMAGE, reference, Path(__file__).resolve(),
               REPO / 'tools/forum_news_pixels.py', REPO / 'tools/page_archive.py',
               REPO / 'tools/browser_bundle_lease.py',
               REPO / 'tools/check_pixel_equality.py', REPO / 'tools/run_memory_bounded.py']
    sources += sorted((REPO / 'tools/adblock').rglob('*.mjs'))
    return {str(path): digest(path.read_bytes()) for path in sources}


def input_identity(args):
    return dict(brave=brave_identity(args.brave), vox=executable_identity(args.vox),
                sources=source_pins(getattr(args, 'case', 'image-effects')), tools={str(path): digest(path.read_bytes())
                    for path in [args.checker, args.diff_tool]})


def run(args):
    case_name = getattr(args, 'case', 'image-effects')
    _, reference_file, url = case_files(case_name)
    output = args.output
    output.mkdir(parents=True, exist_ok=False)
    before = input_identity(args)
    write_json(output / 'identity.json', before)
    result = dict(status='failure', workload='Synthetic HTTP image-effects regression')
    try:
        seed = output / 'seed'
        create_seed(seed, case_name)
        replay = Replay(seed, output / 'seed-replay')
        thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
        thread.start()
        site = dict(id=case_name, name='Synthetic TechCrunch ' + case_name, url=url)
        case = SimpleNamespace(**vars(args), fixtures=output / 'fixtures', capture=False,
            profile_template=None, capture_proxy=None, cache_policy='cold', audit_config=None)
        case.output = output / 'comparison'
        try:
            public = subprocess.check_output([
                'openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
            der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=public)
            spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
            acquisition = output / 'acquisition'
            acquisition.mkdir()
            capture_site_archive(oracle_command(site, case), [
                '--proxy-server', replay.ready['proxy'].replace('socks5h:', 'socks5:'),
                '--replay-spki', spki], acquisition, case.fixtures / site['id'],
                args.timeout, 'cold')
        finally:
            replay.server.shutdown()
            replay.server.server_close()
            thread.join()
        reference = compare(reference_file, case.fixtures / site['id'] / 'live.png',
                            output / 'checked-reference.diff.png', args.diff_tool)
        write_json(output / 'checked-reference.json', reference)
        if not reference['exact']:
            raise RuntimeError('The fresh full-uBO source differs from the checked reference')
        result = dict(**run_case(site, case), workload=result['workload'])
    except Exception as error:
        result = dict(status='failure', workload=result['workload'], error=str(error))
    finally:
        after = input_identity(args)
        write_json(output / 'identity-after.json', after)
        if before != after:
            result = dict(status='failure', error='Browser or canonical inputs changed during the run')
        write_json(output / 'summary.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--case', choices=['image-effects', 'root-origin', 'mask-tiles'], default='image-effects')
    parser.add_argument('--extension', type=Path, required=True)
    parser.add_argument('--checker', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, required=True)
    parser.add_argument('--brave', type=Path, default=BRAVE)
    parser.add_argument('--vox', type=Path, default=VOX)
    parser.add_argument('--settle', type=float, default=5)
    parser.add_argument('--timeout', type=float, default=180)
    args = parser.parse_args()
    if not 0 < args.settle <= 120 or not 0 < args.timeout <= 3600:
        parser.error('settle must be in (0,120], timeout in (0,3600]')
    for name in ['output', 'extension', 'checker', 'diff_tool', 'brave', 'vox']:
        setattr(args, name, getattr(args, name).resolve())
    with canonical_bundle_lease(args.vox.parent.parent.parent):
        result = run(args)
    print(json.dumps(result), flush=True)
    return 0 if result['status'] == 'pass' else 1


if __name__ == '__main__':
    raise SystemExit(main())
