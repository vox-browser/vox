#!/usr/bin/env python3
"""Capture independent native expectations for large source-image blurs."""
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import platform
from native_fixture_hashes import Reference, image_pixels, rectangle
from native_large_blur_hashes import background


def capture(library, fixtures, output, verify):
    cases = json.loads(fixtures.read_text())
    pins = [library, fixtures, Path(__file__), Path(__file__).with_name('native_fixture_hashes.py'),
            Path(__file__).with_name('native_large_blur_hashes.py')]
    hashes = {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest() for p in pins}
    ref = Reference(library)
    field = 'expected_linux' if platform.system() == 'Linux' else 'expected_macos'
    for i, c in enumerate(cases):
        src = image_pixels(c['image_width'], c['image_height'], c['image_premultiplied'])
        ref.pattern_sha256 = hashlib.sha256(src).hexdigest()
        storage = (C.c_uint8*len(src)).from_buffer(src)
        ref.library.oracle_pattern(storage)
        filters = [[2, 0, 0, 0, 0, m, 1] for m in c['pre']]
        filters += [[0, 0, c['sigma'], 0, 0, [0]*20, 0]]
        filters += [[2, 0, 0, 0, 0, m, 1] for m in c['post']]
        ref.filters(filters)
        clip = rectangle(5.25, 6.5, 110.75, 100.25) if c['clip'] else []
        ints = [c['width'], c['height'], c['pitch'], c['alpha_type'], 2, int(c['smoothing']),
                *([1, len(clip)//12, 0] if clip else [0]), c['composite'], 0,
                c['image_width'], c['image_height'], c['image_width']*4+4,
                2 if c['image_premultiplied'] else 1, int(c['image_display_p3'])]
        floats = [*c['transform'], c['global_alpha'], *c['destination'], *c['source'], *clip]
        digest = ref.call('oracle_canvas_bitmap', background(c, fixtures.parent), ints, floats,
                          f'large-source-{i}', c['expected_macos'])
        if verify:
            assert digest == c[field], (i, digest, c[field])
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest() == h for p, h in hashes.items()), 'Inputs changed'
    output.write_text(json.dumps(dict(platform=platform.platform(), input_sha256=hashes,
                                    records=ref.records), indent=2)+'\n')
    print(f'{len(cases)} native large source-image fixtures'+(' verified' if verify else ' captured'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--fixtures', type=Path, default=Path(__file__).resolve().parents[2]/'cpuraster/testdata/large-source-blur-cases.json')
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    capture(args.library, args.fixtures, args.output, args.verify)
