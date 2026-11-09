#!/usr/bin/env python3
"""Capture faint portable-shadow output on the native RGBA canvas surfaces."""
import ctypes as C
import hashlib
import json
import platform
import sys
from pathlib import Path

path = Path(sys.argv[1]).resolve()
reference_hash = hashlib.sha256(path.read_bytes()).hexdigest()
library = C.CDLL(str(path))
cases = [
    dict(name='faint-inner', width=15, height=64, color=761568228, blur=19.790783,
         outer=[6.9186826, 29.3462, 9.195145, 66.073654] + [0]*8,
         inner=[8.042617, 30.470135, 6.947276, 63.825783] + [100]*8,
         content=[8.042617, 30.470135, 6.947276, 63.825783] + [100]*8),
    dict(name='faint-outer', width=64, height=56, color=243986327, blur=18.73592,
         outer=[8, 6, 40, 32] + [10]*8, content=[12, 10, 32, 24] + [8]*8),
]
records = []
for case in cases:
    function = 'oracle_inner_shadow' if 'inner' in case else 'oracle_outer_shadow'
    callback = getattr(library, function)
    callback.argtypes = [C.POINTER(C.c_uint8), C.POINTER(C.c_int32), C.POINTER(C.c_float)]
    ints = [case['width'], case['height'], case['color']]
    if function == 'oracle_outer_shadow':
        ints.append(0)
    floats = [*case['outer'], *case.get('inner', []), *case['content'], 1, 0, 0, 1, 0, 0, case['blur']]
    pixels = (C.c_uint8 * (ints[0] * ints[1] * 4))()
    assert callback(pixels, (C.c_int32 * len(ints))(*ints), (C.c_float * len(floats))(*floats))
    records.append(dict(case=case['name'], function=function, arguments=ints, floats=floats,
                        native_sha256=hashlib.sha256(bytes(pixels)).hexdigest()))
expected = ['4b3523909177b292', '97275a5983102543'] if platform.system() == 'Darwin' else [
    'deeb6f65e7b5859b', '7badb3a3a761b5b0']
for record, digest in zip(records, expected):
    assert record['native_sha256'].startswith(digest), record['case']
assert hashlib.sha256(path.read_bytes()).hexdigest() == reference_hash
print(json.dumps(dict(platform=platform.platform(), reference_sha256=reference_hash,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     records=records), indent=2))
