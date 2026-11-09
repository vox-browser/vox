#!/usr/bin/env python3
"""Capture native color filters interleaved with repeated blur passes."""
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

cases = [
    ('colors-around-two-blurs', [contrast, blur(.8), opacity, blur(2.5), contrast], {}),
    ('identity-before-deferred-color', [blur(0), contrast, blur(2.5)], dict(mode='multiply')),
    ('identity-after-deferred-color', [blur(2.5), contrast, blur(0), opacity], dict(mode='src_in')),
    ('all-identity-deferred-colors', [contrast, blur(0), opacity, blur(.01), contrast], dict(mode='plus_lighter')),
    ('box-color-gaussian-pattern', [blur(12), contrast, blur(.8)], dict(
        alpha_type=1, transform=[1.25, 0, 0, .75, 2, 4],
        style=dict(width=7, height=6, display_p3=True, transform=m.IDENTITY))),
    ('three-blur-color-stroke', [contrast, blur(.8), opacity, blur(2.5), contrast, blur(.8)], dict(
        mode='overlay', stroke=(3, 1, 0, 10, [3, 2], .7))),
    ('identity-inside-deferred-colors', [blur(.8), opacity, blur(0), contrast, blur(2.5)], dict(mode='src_in')),
    ('final-color-after-box-blur', [contrast, blur(2.5), opacity, blur(12), contrast], dict(
        alpha_type=1, mode='plus_darker', transform=[1.25, 0, 0, .75, 2, 4])),
]
for name, filters, options in cases:
    reference.path(m.background(48, 40, 'image'), 48, 40, path, name, 'captured',
                   color=0xc0e04010, alpha=.7, clips=[(triangle, False)],
                   filters=filters, **options)
expected = ['7607d02c17545ce9', 'e6fc7d183d6f508a', '853d995ca42ed6ae', 'd44f4631ee09188a',
            'db5ae4482ca62300', '2e2efd552912f6ff', '9094cff4114223f5', 'de48da03ed37df5c']
if platform.system() == 'Linux':
    expected[4] = 'bc75c784f5dc7c47'
for record, digest in zip(reference.records, expected):
    assert record['native_sha256'].startswith(digest), record['case']
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == reference.reference_sha256
print(json.dumps(dict(platform=platform.platform(), reference_sha256=reference.reference_sha256,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=reference.records), indent=2))
