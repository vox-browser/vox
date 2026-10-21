#!/usr/bin/env python3
"""Stage a glyph-index-only x.ttf initializer without editing V's checkout."""

import hashlib
import json
from pathlib import Path
import re
import sys
import tempfile

from prepare_http_compat import compiler_vlib


def glyph_index_initializer(source):
    signature = "pub fn (mut tf TTF_File) init()"
    matches = list(re.finditer(re.escape(signature) + r"\s*\{(.*?)^\}", source, re.M | re.S))
    if len(matches) != 1 or matches[0][1].count("tf.read_cmap_table()") != 1:
        raise RuntimeError("Unsupported x.ttf initializer: expected one explicit cmap-table read")
    body = matches[0][1].replace("tf.read_cmap_table()", "// Unicode lookup belongs to the caller.")
    return ("module ttf\n\n"
            "// Same metadata, outlines and kerning as init(), without dense Unicode caches.\n"
            "pub fn (mut tf TTF_File) init_for_glyph_indices() {" + body + "}\n")


def prepare(compiler, output_root=None):
    with tempfile.TemporaryDirectory(prefix="vox-font-root-") as temporary:
        vlib = compiler_vlib(compiler, Path(temporary))
    source = vlib / "x/ttf"
    if not (source / "ttf.v").is_file():
        raise RuntimeError("The active V library has no x.ttf reader")
    inputs = {p.relative_to(source).as_posix(): p.read_bytes()
              for p in source.rglob("*") if p.is_file()}
    generated = glyph_index_initializer(inputs["ttf.v"].decode()).encode()
    inputs["vox_glyph_index_init.v"] = generated
    digest = hashlib.sha256(Path(__file__).read_bytes())
    for name, data in sorted(inputs.items()):
        digest.update(name.encode() + b"\0" + data)
    identity = {"compiler": str(Path(compiler).resolve()), "vlib": str(vlib),
                "sha256": digest.hexdigest(),
                "files": {name: hashlib.sha256(data).hexdigest() for name, data in inputs.items()}}
    base = output_root or Path(__file__).resolve().parents[1] / "Build/v/font-runtime"
    root = base / digest.hexdigest()
    manifest = root / "manifest.json"
    if manifest.is_file() and json.loads(manifest.read_text()) == identity:
        return root
    for name, data in inputs.items():
        target = root / "x/ttf" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.is_file() or target.read_bytes() != data:
            with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as temporary:
                temporary.write(data)
                temporary_path = Path(temporary.name)
            temporary_path.replace(target)
    manifest.write_text(json.dumps(identity, indent=2) + "\n")
    return root


if __name__ == "__main__":
    print(prepare(sys.argv[1]))
