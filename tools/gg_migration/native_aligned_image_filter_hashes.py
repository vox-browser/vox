#!/usr/bin/env python3
"""Capture pixel-aligned source-image filters, including unknown image edges."""
import ctypes as C
import hashlib
import importlib.util
import json
import platform
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'reference', Path(__file__).with_name('native_fixture_hashes.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
r = m.Reference(Path(sys.argv[1]))
contrast = (2, 0, 0, 0, 0, [1.3, 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15,
                          0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0], 0)
opacity = (2, 0, 0, 0, 0, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
                          0, 0, 1, 0, 0, 0, 0, 0, .65, 0], 1)
def blur(sigma):
    return (0, 0, sigma, 0, 0, [0]*20, 0)
def shadow(sigma, dx=5.25, dy=-3.75, color=0x805030e0):
    return (1, color, sigma, dx, dy, [0]*20, 0)
triangle = m.segment(0, 2, 3) + m.segment(1, 45.5, 10.25) + m.segment(1, 20.5, 38) + m.segment(5)
cases = [
    dict(name='aligned-image-blur', filters=[blur(2.5)]),
    dict(name='aligned-subset-blur', source=[1, 1, 5, 4], destination=[4, 6, 5, 4],
         filters=[blur(.8)], transform=[1, 0, 0, 1, 3, -2], mode='src_in', clip=True),
    dict(name='aligned-image-shadow', filters=[shadow(2.5)], mode='multiply', clip=True),
    dict(name='unknown-image-boundary', iw=10, ih=1, width=86, height=65,
         pixels=[34, 60, 16, 61, 7, 85, 139, 213, 113, 115, 31, 118, 7, 2, 11, 34,
                 158, 206, 247, 247, 5, 79, 27, 87, 158, 135, 41, 159, 30, 6, 46, 46,
                 24, 6, 48, 64, 200, 141, 230, 254],
         source=[4, 0, 6, 1], destination=[52, 2, 6, 1], transform=[1, 0, 0, 1, 9, -6],
         filters=[shadow(-1, 15.59166, 6, 4280761295)], empty=True),
    dict(name='identity-shadow-image-boundary', filters=[contrast, shadow(.01), opacity],
         mode='plus_lighter', clip=True),
    dict(name='image-color-blur-chain', filters=[contrast, blur(.8), opacity, blur(2.5), contrast],
         mode='overlay'),
    dict(name='image-identity-color-chain', filters=[contrast, blur(0), opacity, blur(.01), contrast],
         mode='src_in', clip=True),
    dict(name='image-box-color-chain', filters=[blur(2.5), opacity, blur(12), contrast],
         mode='plus_darker', clip=True),
    dict(name='p3-premul-blur', p3=True, filters=[blur(2.5)]),
    dict(name='p3-unpremul-blur', p3=True, premul=False, filters=[blur(.8)], mode='multiply', clip=True),
    dict(name='p3-color-between-blurs', p3=True, filters=[blur(.8), contrast, blur(2.5)], mode='src_in'),
    dict(name='p3-conversion-after-identity', p3=True, premul=False,
         filters=[blur(.01), blur(2.5), contrast], mode='plus_lighter', clip=True),
    dict(name='srgb-unpremul-blur', premul=False, filters=[blur(2.5)]),
    dict(name='srgb-unpremul-blur-color-identity', premul=False,
         filters=[blur(2.5), contrast, blur(0)], mode='src_in', clip=True),
    dict(name='p3-premul-prefiltered-shadow', p3=True, filters=[contrast, shadow(2.5)]),
    dict(name='p3-unpremul-identity-shadow', p3=True, premul=False,
         filters=[opacity, shadow(.01), contrast], mode='src_in', clip=True),
    dict(name='srgb-unpremul-prefiltered-shadow', premul=False,
         filters=[contrast, shadow(2.5)], mode='multiply', clip=True),
    dict(name='p3-identity-color-chain', p3=True,
         filters=[contrast, blur(0), opacity, blur(.01), contrast], mode='darken', clip=True),
]
for p3 in [True, False]:
    cases.append(dict(name='global-image-shadow-offset-' + ('p3' if p3 else 'srgb'),
        p3=p3, iw=19, ih=14, width=50, height=73, empty=True, pixel_pitch=84,
        pixels=list((Path(__file__).resolve().parents[2] / 'cpuraster/testdata/image-shadow-offset.rgba').read_bytes()),
        source=[1, 2, 15, 9], destination=[15, -3, 15, 9], transform=[1, 0, 0, 1, 9, -9],
        filters=[shadow(3.3989284, 19, 11.136544, 4287222027)]))
for case in cases:
    w, h = case.get('width', 48), case.get('height', 40)
    iw, ih = case.get('iw', 7), case.get('ih', 6)
    premul = case.get('premul', True)
    image = bytearray(case['pixels']) if 'pixels' in case else m.image_pixels(iw, ih, premul)
    image_pitch = case.get('pixel_pitch', iw * 4) if 'pixels' in case else iw * 4 + 4
    storage = (C.c_uint8 * len(image)).from_buffer(image)
    r.library.oracle_pattern(storage)
    r.pattern_sha256 = hashlib.sha256(image).hexdigest()
    r.filters(case['filters'])
    clips = [(triangle, False)] if case.get('clip') else []
    ints = [w, h, w * 4, 2, 2, 1, len(clips),
            *[v for p, even in clips for v in [len(p)//12, int(even)]],
            m.MODES[case.get('mode', 'src_over')], 0, iw, ih, image_pitch, 2 if premul else 1,
            int(case.get('p3', False))]
    floats = [*case.get('transform', m.IDENTITY), 1,
              *case.get('destination', [10, 12, 7, 6]), *case.get('source', [0, 0, 7, 6]),
              *[v for p, _ in clips for v in p]]
    initial = bytearray(w*h*4) if case.get('empty') else m.background(w, h, 'image')
    r.call('oracle_canvas_bitmap', initial, ints, floats, case['name'], 'captured')
expected = ['ed3ad78eb7f39e69', '175b0777ebb477e0', '008e86865ffcec77', 'c109c5a5d05dfb86',
            '6454322bbabaebc8', 'eb747c828384c545', '911409983b836492', '718eb0464fd3d842',
            'b6afd442846f1fe7', 'e9153669efc21a36', 'ec04ff3914c40623', 'fbe1dc130b1bbe80',
            'b584f633e3fc82cf', 'a902cd538e64aca3', 'c62cadba69cd7310', '7f699b125a13e896',
            'a1a9893f167e696e', '001b2763877bb22c', 'f2a7f0ed22c87bab', 'f2a7f0ed22c87bab']
assert len(r.records) == len(expected)
for record, digest in zip(r.records, expected):
    assert record['native_sha256'].startswith(digest), record['case']
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == r.reference_sha256
print(json.dumps(dict(platform=platform.platform(), reference_sha256=r.reference_sha256,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=r.records), indent=2))
