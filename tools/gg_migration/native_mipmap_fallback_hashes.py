#!/usr/bin/env python3
"""Capture the pinned CPU accessor's behavior beyond its mipmap pyramid."""
import ctypes as C
import hashlib
import json
import platform
import sys
from pathlib import Path

reference = Path(sys.argv[1]).resolve()
reference_sha256 = hashlib.sha256(reference.read_bytes()).hexdigest()
library = C.CDLL(str(reference))
library.oracle_mipmap_shader.argtypes = [C.POINTER(C.c_uint8), C.POINTER(C.c_uint8),
                                       C.POINTER(C.c_int32), C.POINTER(C.c_float)]
library.oracle_mipmap_shader.restype = None
source = bytes(c for y in range(4) for x in range(4)
               for c in (x*64, y*64, (x+y)*32, 255))
storage = (C.c_uint8 * len(source)).from_buffer_copy(source)
records = []
for mode, name in [(1, 'nearest'), (2, 'linear')]:
    for scale in [.125, .1, .05, .025]:
        args = [4, 4, 16, 2, 2, mode]
        matrix = [scale, 0, 0, scale, 0, 0]
        output = (C.c_uint8 * 16)()
        library.oracle_mipmap_shader(storage, output, (C.c_int32 * len(args))(*args),
                                    (C.c_float * len(matrix))(*matrix))
        # A missing upper level reloads the 4x4 base, whose clamped edge is
        # 192. If only the lower level is missing, linear mode keeps the
        # final available 1x1 upper level, whose average is 96.
        channel = 96 if mode == 2 and scale >= .1 else 192
        expected = bytes([channel, channel, channel, 255] * 4)
        assert bytes(output) == expected, (name, scale, list(output))
        records.append(dict(mode=name, scale=scale, arguments=args, matrix=matrix,
                            pixels=list(output), sha256=hashlib.sha256(output).hexdigest()))
assert hashlib.sha256(reference.read_bytes()).hexdigest() == reference_sha256
print(json.dumps(dict(platform=platform.platform(), reference_sha256=reference_sha256,
                     tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                     source_sha256=hashlib.sha256(source).hexdigest(), records=records), indent=2))
