#!/usr/bin/env python3
"""Capture geometry layers with a rejected drop-shadow blur branch."""
import hashlib
import importlib.util
import json
import platform
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location('reference', Path(__file__).with_name('native_fixture_hashes.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
r = m.Reference(Path(sys.argv[1]))
path = m.segment(0, 10, 8) + m.segment(2, 38, 12, 40, 30) + m.segment(1, 12, 34) + m.segment(5)
shadow = (1, 0x80000000, 2, 3.5, -1.25, [0]*20, 0)
rejected = (1, 0x80000000, -1, 3.5, -1.25, [0]*20, 0)
for alpha_type in [1, 2]:
    r.path(m.background(48, 40, 'image'), 48, 40, path, f'rejected-layer-{alpha_type}', 'captured',
           filters=[shadow, rejected], alpha_type=alpha_type)
if '--capture' not in sys.argv[2:]:
    expected = ['d15d6f0deb8e3adc', '92397e22e3517d7e']
    assert len(expected) == len(r.records)
    for record, digest in zip(r.records, expected):
        assert record['native_sha256'].startswith(digest)
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == r.reference_sha256
print(json.dumps(dict(platform=platform.platform(), reference_sha256=r.reference_sha256,
    tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), records=r.records), indent=2))
