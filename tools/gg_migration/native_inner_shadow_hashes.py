#!/usr/bin/env python3
"""Capture native nonintersecting rounded inner-shadow fixtures."""
import ctypes as C
import hashlib
import json
import platform
import sys
from pathlib import Path

library_path = Path(sys.argv[1]).resolve()
identity = [1, 0, 0, 1, 0, 0]
cases = [
    dict(name='rounded-outer', outer=[-8, -8, 80, 72] + [16]*8,
         inner=[12, 10, 40, 30, 8, 6, 7, 4, 3, 9, 10, 5],
         content=[4, 4, 56, 44] + [9, 11]*4, color=0x804080c0, blur=4),
    dict(name='scaled-elliptical-outer', outer=[0, 0, 64, 56, 18, 14, 12, 20, 22, 14, 16, 18],
         inner=[10, 10, 44, 36] + [8]*8,
         content=[0, 0, 64, 56, 18, 14, 12, 20, 22, 14, 16, 18],
         color=0xc0e04010, blur=6.5, transform=[1.25, 0, 0, .75, 2, 4]),
    dict(name='rotated-oval-outer', outer=[-5, -5, 74, 66] + [37, 33]*4,
         inner=[15, 12, 34, 30] + [10]*8, content=[2, 2, 60, 48] + [12]*8,
         color=0xff204080, blur=3, transform=[.9, .4, -.4, .9, 5, 2]),
    dict(name='rounded-outer-aa-overlap', outer=[3.25, 4.5, 54, 45, 13, 9, 11, 16, 12, 14, 8, 10],
         inner=[16, 16, 28, 20] + [5]*8,
         content=[3.25, 4.5, 54, 45, 13, 9, 11, 16, 12, 14, 8, 10],
         color=0x80ff00ff, blur=0),
    dict(name='concentric-rounded-inset', outer=[3.25, 4.5, 54, 45, 13, 9, 11, 16, 12, 14, 8, 10],
         inner=[6.25, 7.5, 48, 39, 10, 6, 8, 13, 9, 11, 5, 7],
         content=[3.25, 4.5, 54, 45, 13, 9, 11, 16, 12, 14, 8, 10],
         color=0xc0306090, blur=4),
    dict(name='concentric-oval-inset', outer=[4, 4, 56, 48] + [28, 24]*4,
         inner=[6, 6, 52, 44] + [26, 22]*4, content=[4, 4, 56, 48] + [28, 24]*4,
         color=0x804080c0, blur=6),
]
reference_hash = hashlib.sha256(library_path.read_bytes()).hexdigest()
library = C.CDLL(str(library_path))
library.oracle_inner_shadow.argtypes = [C.POINTER(C.c_uint8), C.POINTER(C.c_int32), C.POINTER(C.c_float)]
records = []
for case in cases:
    ints = [64, 56, case['color']]
    floats = [*case['outer'], *case['inner'], *case['content'], *case.get('transform', identity), case['blur']]
    pixels = (C.c_uint8 * (64 * 56 * 4))()
    assert library.oracle_inner_shadow(pixels, (C.c_int32 * 3)(*ints), (C.c_float * len(floats))(*floats))
    records.append(dict(case=case['name'], arguments=ints, floats=floats,
                        native_sha256=hashlib.sha256(bytes(pixels)).hexdigest()))
expected = ['62b9e388d577040d', '33844d7d5e684240', 'e8859d5d90b39fe9',
            '0eb29f0256d0c181', 'dd6fbeed97c40dc1', 'c5b95d2f6b2d939b']
if platform.system() == 'Linux':
    expected = ['883f172b4d99012d', 'ffe733dccd5bd96f', '55ca45b11915426a',
                '0eb29f0256d0c181', '6a1d6087eca72401', 'b1515516d61cae7c']
for record, digest in zip(records, expected):
    assert record['native_sha256'].startswith(digest), record['case']
assert hashlib.sha256(library_path.read_bytes()).hexdigest() == reference_hash
print(json.dumps(dict(platform=platform.platform(), reference_sha256=reference_hash,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=records), indent=2))
