#!/usr/bin/env python3
"""Stage arena-safe V closure bookkeeping without editing the compiler checkout."""

import hashlib
import json
from pathlib import Path
import re
import sys


def wrap_function(source, signature, before="", after=""):
    pattern = re.compile(re.escape(signature) + r"\s*\{(.*?)^\}", re.M | re.S)
    def replace(match):
        return signature + " {\n" + before + match[1] + after + "}\n"
    result, count = pattern.subn(replace, source)
    if count != 1:
        raise RuntimeError(f"Unsupported V closure runtime: expected one {signature}")
    return result


def prepare(compiler):
    repo = Path(__file__).resolve().parents[1]
    source = Path(compiler).resolve().parent / "vlib/builtin/closure"
    if not (source / "closure.c.v").is_file():
        raise RuntimeError("Prealloc requires the current V closure runtime")
    helper = Path(__file__).with_name("prealloc_runtime") / "closure_prealloc_metadata.c.v"
    inputs = {p.name: p.read_bytes() for p in source.iterdir() if p.is_file()}
    inputs[helper.name] = helper.read_bytes()
    digest = hashlib.sha256()
    for name, data in sorted(inputs.items()):
        digest.update(name.encode() + b"\0" + data)
    digest.update(Path(__file__).read_bytes())
    root = repo / "Build/v/prealloc-runtime"
    target = root / "builtin/closure"
    manifest = root / "manifest.json"
    identity = {"compiler": str(Path(compiler).resolve()), "sha256": digest.hexdigest()}
    if manifest.is_file() and json.loads(manifest.read_text()) == identity:
        return root
    target.mkdir(parents=True, exist_ok=True)
    for name, data in inputs.items():
        if name == "closure.c.v":
            data = wrap_function(data.decode(), "fn closure_init_body()",
                                 before="\tclosure_metadata_enter()\n",
                                 after="\tclosure_metadata_leave()\n").encode()
        elif name in ("closure_nix.c.v", "closure_windows.c.v"):
            text = wrap_function(data.decode(), "fn closure_mtx_lock_platform()",
                                 after="\tclosure_metadata_enter()\n")
            data = wrap_function(text, "fn closure_mtx_unlock_platform()",
                                 before="\tclosure_metadata_leave()\n").encode()
        (target / name).write_bytes(data)
    for path in target.iterdir():
        if path.is_file() and path.name not in inputs:
            path.unlink()
    manifest.write_text(json.dumps(identity, indent=2) + "\n")
    return root


if __name__ == "__main__":
    print(prepare(sys.argv[1]))
