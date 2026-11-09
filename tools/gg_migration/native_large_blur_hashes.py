#!/usr/bin/env python3
"""Independently capture Skia pixels for the large-sigma blur fixtures."""
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path
import platform
from native_fixture_hashes import Reference


def image_pixels(width, height):
    out = bytearray()
    for y in range(height):
        for x in range(width):
            a = (x*37+y*91) % 256
            if (x+2*y) % 5 == 0:
                a = 255
            if (x*3+y) % 7 == 3:
                a = 0
            out.extend(((x*53+y*17) % 256*a//255, (x*11+y*67) % 256*a//255,
                        (x*29+y*41+100) % 256*a//255, a))
    return out


def background(case, root):
    if case.get('background_file'):
        return bytearray((root/case['background_file']).read_bytes())
    w, h, pitch, alpha = [case[k] for k in ('width', 'height', 'pitch', 'alpha_type')]
    out = bytearray([0x5a])*(pitch*h)
    for y in range(h):
        for x in range(w):
            a = (x*17+y*31) % 256
            rgb = [(x*53+y*17) % 256, (x*11+y*67) % 256, (x*29+y*41+100) % 256]
            out[y*pitch+x*4:y*pitch+x*4+4] = bytes([*(v*a//255 if alpha == 2 else v for v in rgb), a])
    return out


def capture(library, fixtures, output, verify):
    cases = json.loads(fixtures.read_text())
    pins = [fixtures, library, Path(__file__), Path(__file__).with_name('native_fixture_hashes.py')]
    pins += [fixtures.parent/c['background_file'] for c in cases['canvas'] if c.get('background_file')]
    hashes = {str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in pins}
    ref = Reference(library)
    field = 'expected_linux' if platform.system() == 'Linux' else 'expected_macos'
    records = []
    lib = ref.library
    lib.oracle_image_blur.argtypes = [C.POINTER(C.c_uint8), C.POINTER(C.c_int32), C.POINTER(C.c_float), C.POINTER(C.c_uint8), C.POINTER(C.c_int32)]
    for i, c in enumerate(cases['images']):
        src = image_pixels(c['width'], c['height'])
        clip = c['clip']
        pixels = (C.c_uint8*((clip[2]-clip[0]+2)*(clip[3]-clip[1]+2)*4))()
        info = (C.c_int32*5)()
        ints = [c['width'], c['height'], *c['subset'], *clip]
        lib.oracle_image_blur((C.c_uint8*len(src)).from_buffer(src), (C.c_int32*10)(*ints),
                              (C.c_float*2)(*c['sigma']), pixels, info)
        result = bytes(pixels[:info[1]*info[2]*4])
        expected = ('none' if not info[0] else
                    f'{info[1]}x{info[2]} at {info[3]},{info[4]} {hashlib.sha256(result).hexdigest()}')
        records.append(dict(case=f'image-{i}', result=expected, info=list(info), input_sha256=hashlib.sha256(src).hexdigest()))
        if verify:
            assert expected == c[field], (i, expected, c[field])
    for i, c in enumerate(cases['canvas']):
        filters = [[2, 0, 0, 0, 0, m, 1] for m in c['pre']]
        filters += [[0, 0, c['sigma'], 0, 0, [0]*20, 0]]
        filters += [[2, 0, 0, 0, 0, m, 1] for m in c['post']]
        ref.filters(filters)
        path, clip = c['segments'], c['clips']
        clip_ints = [1, len(clip)//12, 0] if clip else [0]
        style_ints = [1, (len(c['gradient'])-7)//5] if c['gradient'] else [0]
        common = [c['width'], c['height'], c['pitch'], c['alpha_type']]
        if c['stroke']:
            ints = common+[len(path)//12, c['color'], c['cap'], c['join'], 0, *clip_ints, c['composite'], *style_ints]
            floats = [*c['transform'], c['global_alpha'], c['line_width'], 10, *path, 0, *clip, 0, *c['gradient']]
            name = 'oracle_canvas_stroke'
        else:
            ints = common+[int(c['even_odd']), len(path)//12, c['color'], *clip_ints, c['composite'], *style_ints]
            floats = [*c['transform'], c['global_alpha'], *path, *clip, 0, *c['gradient']]
            name = 'oracle_canvas_fill'
        digest = ref.call(name, background(c, fixtures.parent), ints, floats, f'canvas-{i}', c['expected_macos'])
        records.append(dict(case=f'canvas-{i}', result=digest))
        if verify:
            assert digest == c[field], (i, digest, c[field])
    assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest() == h for p, h in hashes.items()), 'Native fixture inputs changed'
    output.write_text(json.dumps(dict(platform=platform.platform(), records=records, canvas=ref.records,
        inputs=hashes), indent=2)+'\n')
    print(f'{len(records)} native large-blur fixtures'+(' verified' if verify else ' captured'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('library', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--fixtures', type=Path, default=Path(__file__).resolve().parents[2]/'cpuraster/testdata/large-blur-cases.json')
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    capture(args.library, args.fixtures, args.output, args.verify)
