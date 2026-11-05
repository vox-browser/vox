#!/usr/bin/env python3
"""Stage bounded realloc and arena-safe closures without editing V's checkout."""

import fcntl
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile
from prepare_http_compat import compiler_vlib


def patch_allocator(allocation, prealloc):
    used = "prealloc_realloc_copy_size(" in allocation
    defined = "fn prealloc_realloc_copy_size(" in prealloc
    if used and defined:
        return allocation, prealloc
    signature = "pub fn v_realloc(b &u8, n int) &u8"
    pattern = re.compile(re.escape(signature) + r"\s*\{.*?^\}", re.M | re.S)
    matches = list(pattern.finditer(allocation))
    old = "new_ptr = malloc(n)\n\t\t\tC.memcpy(new_ptr, b, n)"
    if (used or defined or len(matches) != 1 or matches[0][0].count(old) != 1
            or "fn prealloc_realloc(" not in prealloc):
        raise RuntimeError("Unsupported V allocator: bounded v_realloc cannot be staged. "
                           "Set V_BIN to a compatible current V compiler.")
    replacement = ("copy_size := prealloc_realloc_copy_size(b, n)\n"
                   "\t\t\tnew_ptr = malloc(n)\n"
                   "\t\t\tif copy_size > 0 { C.memcpy(new_ptr, b, copy_size) }")
    match = matches[0]
    allocation = allocation[:match.start()] + match[0].replace(old, replacement) + allocation[match.end():]
    helper = Path(__file__).with_name("prealloc_runtime") / "bounded_realloc.c.v"
    prealloc += "\n" + helper.read_text().split("module builtin\n", 1)[1]
    return allocation, prealloc


def validate_allocator(builtin):
    allocation = (builtin / "allocation.c.v").read_text()
    prealloc = (builtin / "prealloc.c.v").read_text()
    if ("prealloc_realloc_copy_size(" not in allocation
            or "fn prealloc_realloc_copy_size(" not in prealloc):
        raise RuntimeError(
            "Prealloc requires V's bounded v_realloc copy, including realloc(nil, n). "
            "Set V_BIN to a compatible current V compiler."
        )


def wrap_function(source, signature, before="", after=""):
    pattern = re.compile(re.escape(signature) + r"\s*\{(.*?)^\}", re.M | re.S)
    def replace(match):
        return signature + " {\n" + before + match[1] + after + "}\n"
    result, count = pattern.subn(replace, source)
    if count != 1:
        raise RuntimeError(f"Unsupported V closure runtime: expected one {signature}")
    return result


def prepare(compiler, output_root=None):
    repo = Path(__file__).resolve().parents[1]
    compiler = Path(shutil.which(str(compiler)) or compiler).resolve()
    # A moved compiler can retain a different baked-in standard-library root.
    # Validate and stage the library it actually compiles against.
    with tempfile.TemporaryDirectory(prefix="vox-prealloc-root-") as temporary:
        vlib = compiler_vlib(str(compiler), Path(temporary)).resolve()
    builtin = vlib / "builtin"
    allocation, prealloc = patch_allocator((builtin / "allocation.c.v").read_text(),
                                          (builtin / "prealloc.c.v").read_text())
    source = builtin / "closure"
    if not (source / "closure.c.v").is_file():
        raise RuntimeError("Prealloc requires the current V closure runtime")
    helper = Path(__file__).with_name("prealloc_runtime") / "closure_prealloc_metadata.c.v"
    originals = {p.name: p.read_bytes() for p in builtin.iterdir() if p.is_file()}
    inputs = {"builtin/" + name: data for name, data in originals.items()}
    inputs.update({"builtin/closure/" + p.name: p.read_bytes()
                   for p in source.iterdir() if p.is_file()})
    owned = {"builtin/allocation.c.v": allocation.encode(),
             "builtin/prealloc.c.v": prealloc.encode(),
             "builtin/closure/" + helper.name: helper.read_bytes()}
    for name, data in list(inputs.items()):
        if name.startswith("builtin/closure/"):
            if name.endswith("/closure.c.v"):
                data = wrap_function(data.decode(), "fn closure_init_body()",
                                     before="\tclosure_metadata_enter()\n",
                                     after="\tclosure_metadata_leave()\n").encode()
            elif Path(name).name in ("closure_nix.c.v", "closure_windows.c.v"):
                text = wrap_function(data.decode(), "fn closure_mtx_lock_platform()",
                                     after="\tclosure_metadata_enter()\n")
                data = wrap_function(text, "fn closure_mtx_unlock_platform()",
                                     before="\tclosure_metadata_leave()\n").encode()
            owned[name] = data
    inputs.update(owned)
    compiler_hash = hashlib.sha256(compiler.read_bytes()).hexdigest()
    digest = hashlib.sha256()
    digest.update(str(vlib.resolve()).encode())
    digest.update(compiler_hash.encode())
    for name, data in sorted(inputs.items()):
        digest.update(name.encode() + b"\0" + data)
    digest.update(Path(__file__).read_bytes())
    root = (output_root or repo / "Build/v/prealloc-runtime").resolve() / digest.hexdigest()
    manifest = root / "manifest.json"
    identity = {"compiler": str(compiler), "compiler_sha256": compiler_hash,
                "vlib": str(vlib.resolve()), "sha256": digest.hexdigest(),
                "owned_files": {name: hashlib.sha256(data).hexdigest() for name, data in owned.items()}}
    root.parent.mkdir(parents=True, exist_ok=True)
    # The runtime is determined by the compiler's bytes, not its path: the same
    # binary installed at another path (e.g. as the shared ~/code/v/v) reuses it.
    # The manifest keeps the path of the compiler that first staged it.
    def same_runtime(recorded):
        return ({k: v for k, v in recorded.items() if k != "compiler"}
                == {k: v for k, v in identity.items() if k != "compiler"})

    # Publish a complete immutable view. Concurrent builds sharing this input
    # identity must never overwrite an executable another process is running.
    with (root.parent / (root.name + ".lock")).open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        staged_compiler = root / "compiler/v"
        if (manifest.is_file() and same_runtime(json.loads(manifest.read_text()))
                and staged_compiler.is_file()
                and (root / "compiler/vlib/builtin").resolve() == root / "builtin"
                and hashlib.sha256(staged_compiler.read_bytes()).hexdigest() == compiler_hash
                and all((root / name).is_file() and hashlib.sha256((root / name).read_bytes()).hexdigest() == sha
                        for name, sha in identity["owned_files"].items())):
            return root
        if root.exists():
            raise RuntimeError(f"Incomplete or modified staged V runtime: {root}")
        with tempfile.TemporaryDirectory(prefix=root.name + ".tmp-", dir=root.parent) as temporary:
            staged = Path(temporary) / "runtime"
            write_runtime(staged, root, vlib, builtin, owned, compiler, identity)
            staged.rename(root)
    return root


def write_runtime(staged, root, vlib, builtin, owned, compiler, identity):
    (staged / "builtin/closure").mkdir(parents=True)
    for path in builtin.iterdir():
        name = "builtin/" + path.name
        target = staged / name
        if path.name != "closure" and name not in owned and not target.is_symlink():
            target.symlink_to(path, target_is_directory=path.is_dir())
    for name, data in owned.items():
        (staged / name).write_bytes(data)
    compiler_root = staged / "compiler"
    (compiler_root / "vlib").mkdir(parents=True, exist_ok=True)
    for path in vlib.iterdir():
        target = compiler_root / "vlib" / path.name
        if not target.is_symlink():
            target.symlink_to(root / "builtin" if path.name == "builtin" else path,
                              target_is_directory=path.is_dir())
    for name in ["thirdparty", "cmd", "v.mod"]:
        target = compiler_root / name
        original = vlib.parent / name
        if original.exists() and not target.is_symlink():
            target.symlink_to(original, target_is_directory=original.is_dir())
    shutil.copy2(compiler, compiler_root / "v")
    validate_allocator(staged / "builtin")
    (staged / "manifest.json").write_text(json.dumps(identity, indent=2) + "\n")


if __name__ == "__main__":
    print(prepare(sys.argv[1], Path(sys.argv[2]) if len(sys.argv) > 2 else None))
