#!/usr/bin/env python3
"""Capture native mixed canvas-filter fixtures without reading V candidate pixels."""
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
reference = m.Reference(Path(sys.argv[1]))
path = m.segment(0, 10, 8) + m.segment(2, 38, 12, 40, 30) + m.segment(1, 12, 34) + m.segment(5)
triangle = m.segment(0, 2, 3) + m.segment(1, 45.5, 10.25) + m.segment(1, 20.5, 38) + m.segment(5)
contrast = (2, 0, 0, 0, 0, [1.3, 0, 0, 0, -.15, 0, 1.3, 0, 0, -.15,
                          0, 0, 1.3, 0, -.15, 0, 0, 0, 1, 0], 0)
opacity = (2, 0, 0, 0, 0, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0,
                          0, 0, 1, 0, 0, 0, 0, 0, .65, 0], 1)
def blur(sigma):
    return (0, 0, sigma, 0, 0, [0] * 20, 0)
shadow = (1, 0x805030e0, 2.5, 5.25, -3.75, [0] * 20, 0)
cases = [
    ('contrast-blur', [contrast, blur(2.5)], {}),
    ('blur-contrast', [blur(2.5), contrast], {}),
    ('contrast-blur-contrast-pattern', [contrast, blur(.8), contrast], dict(
        mode='multiply', transform=[1.25, 0, 0, .75, 2, 4],
        style=dict(width=7, height=6, display_p3=True, transform=m.IDENTITY))),
    ('identity-blur-deferred-colors', [contrast, blur(0), opacity], dict(mode='src_in')),
    ('drop-shadow-contrast', [shadow, contrast], dict(mode='src_in')),
    ('tiny-blur-deferred-colors', [contrast, blur(.01), opacity], dict(mode='plus_lighter')),
    ('blur-contrast-stroke', [blur(2.5), contrast], dict(mode='overlay', stroke=(3, 1, 0, 10, [3, 2], .7))),
    ('contrast-blur-unpremul-target', [contrast, blur(1.2)], dict(
        alpha_type=1, transform=[1.25, 0, 0, .75, 2, 4])),
    ('contrast-drop-shadow', [contrast, shadow], {}),
    ('opacity-drop-shadow', [opacity, shadow], {}),
    ('identity-shadow-deferred-colors', [contrast, (1, 0x805030e0, 0, 5.25, -3.75, [0]*20, 0), opacity], dict(mode='multiply')),
    ('tiny-shadow-deferred-opacity', [opacity, (1, 0x805030e0, .01, -7.25, 4.5, [0]*20, 0), contrast], dict(mode='src_in')),
    ('invalid-shadow-discards-only-shadow-input-filter', [opacity, (1, 0x805030e0, -1, 5.25, -3.75, [0]*20, 0)], {}),
    ('two-blurs', [blur(.8), blur(2.5)], {}),
    ('identity-then-blur', [blur(0), blur(2.5)], dict(mode='multiply')),
    ('blur-then-identity', [blur(2.5), blur(0)], dict(mode='src_in')),
    ('box-then-gaussian-scaled', [blur(12), blur(.8)], dict(
        alpha_type=1, transform=[1.25, 0, 0, .75, 2, 4])),
    ('three-blurs-with-identity', [blur(2.5), blur(.01), blur(.8)], dict(mode='plus_lighter')),
    ('two-identity-blurs', [blur(0), blur(0)], dict(mode='src_in')),
]
for name, filters, options in cases:
    reference.path(m.background(48, 40, 'image'), 48, 40, path, name, 'captured',
                   color=0xc0e04010, alpha=.7, clips=[(triangle, False)],
                   filters=filters, **options)
expected = ['7ec1657ab2cd72b6', '4fbf747408667051', '4d8eb2b67a5444e4',
            'de2bccc7da8fbd81', '7ef6945c7b9398d3', 'f72a5c3abd3ce4d6',
            'fe667fb7d0c8a804', 'ef47838643df8604', '5e4a0ce475763b5a',
            'f98229fc7ce105d5', '78f5b6e1d62913b4', 'aa5bfe6fe1befdcc', '3cf70ee5009ca31f',
            '65eb7d8f1b75d1cd', '7e03b4439a49e901', '748ca7b57f80635f',
            'f2193c7ef46611fb', '2d6eec02b544f6ed', '115c6c84bcab9406']
if platform.system() == 'Linux':
    expected[0], expected[7] = 'd33ced999498998e', 'eaee08ab4ceff5d3'
    expected[8], expected[9] = '6cb1cc4f7b2ba1c8', 'f0578d3f3c4cca70'
    expected[12] = '1d4747ee62d26c1d'
    expected[13], expected[16] = '2889dc346af37304', '60d1b6760d6fb439'
for record, digest in zip(reference.records, expected):
    assert record['native_sha256'].startswith(digest), record['case']
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == reference.reference_sha256
print(json.dumps(dict(platform=platform.platform(), reference_sha256=reference.reference_sha256,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=reference.records), indent=2))
