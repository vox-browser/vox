#!/usr/bin/env python3
"""Capture native containment at coincident quadratic, cubic and conic edges."""
import ctypes as C
import hashlib
import json
import platform
import sys
from pathlib import Path


def curve(kind, reverse):
    values = [0.0] * 36
    values[1] = 10 if reverse else 0
    values[12], values[13], values[24] = kind, 0 if reverse else 10, 5
    if kind == 2:
        values[15:17] = [5, 10]
    elif kind == 3:
        values[15:19] = [10 if reverse else 0, 10, 0 if reverse else 10, 10]
    else:
        values[19:21], values[23] = [5, 5], 0 if reverse else 1
    return values


path = Path(sys.argv[1])
library_sha = hashlib.sha256(path.read_bytes()).hexdigest()
library = C.CDLL(str(path.resolve()))
library.oracle_path_contains.argtypes = [C.POINTER(C.c_int32), C.POINTER(C.c_float)]
library.oracle_path_contains.restype = C.c_int32
records, bits = [], ''
for kind in [2, 3, 4]:
    mid_y = {2: 5, 3: 7.5, 4: -5}[kind]
    for reverse in [False, True]:
        segments = curve(kind, False) + curve(kind, reverse)
        for fill in range(4):
            for name, point in [('extremum', [5, mid_y]), ('endpoint', [0, 0]),
                                ('interior', [5, -1 if kind == 4 else 1])]:
                ints, floats = [len(segments)//12, fill], [*point, *segments]
                result = library.oracle_path_contains(
                    (C.c_int32 * len(ints))(*ints), (C.c_float * len(floats))(*floats))
                assert result in [0, 1]
                bits += str(result)
                records.append(dict(case=f'{kind}-{reverse}-{fill}-{name}', result=bool(result),
                                    arguments=ints, floats=floats))
if '--capture' not in sys.argv[2:]:
    expected = '111000000111000000111111111000000111100000011111011000100111000000111111'
    assert bits == expected, bits
assert hashlib.sha256(path.read_bytes()).hexdigest() == library_sha
print(json.dumps(dict(platform=platform.platform(), reference_sha256=library_sha,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     bits=bits, records=records), indent=2))
