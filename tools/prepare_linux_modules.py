#!/usr/bin/env python3
"""Stage V's native codec modules with Linux archives, without editing V."""

import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare_http_compat import compiler_vlib, remove_unused_private_helper, write_if_changed


def patch_fontstash_callbacks(source):
    """Adapt the pinned GG callbacks without relaxing native C diagnostics."""
    declarations = {
        'fn fons_render_update(uptr voidptr, rect &i32, data &u8) {':
            "@[export: 'vox_gg_fontstash_render_update']",
        'fn fons_render_draw(uptr voidptr, verts &f32, tcoords &f32, colors &u32, nverts i32) {':
            "@[export: 'vox_gg_fontstash_render_draw']",
    }
    marker = '#include "@DIR/vox_fontstash_callbacks.h"'
    assignment = re.compile(
        r'(?m)^(\t+)params\.renderUpdate = fons_render_update\n'
        r'\1params\.renderDraw = fons_render_draw$')
    if marker in source:
        if source.count(marker) != 1 or source.count('C.vox_gg_fontstash_callbacks(&params)') != 2 \
                or any(source.count(annotation) != 1 for annotation in declarations.values()) \
                or assignment.search(source):
            raise RuntimeError('Incomplete GG Fontstash callback adapter')
        return source
    if source.count('module gg\n') != 1 or any(source.count(signature) != 1 for signature in declarations):
        raise RuntimeError('Unsupported GG Fontstash callback signatures')
    source, count = assignment.subn(r'\1C.vox_gg_fontstash_callbacks(&params)', source)
    if count != 2:
        raise RuntimeError(f'Expected two GG Fontstash callback assignments, found {count}')
    for signature, annotation in declarations.items():
        source = source.replace(signature, annotation + '\n' + signature, 1)
    return source.replace('module gg\n', 'module gg\n\n' + marker + '\n', 1) \
        + '\nfn C.vox_gg_fontstash_callbacks(params &C.FONSparams)\n'


def condition_private_helpers(source, names, condition):
    """Compile optional helpers with their callers, retaining test access."""
    for name in names:
        pattern = r"(?m)^fn " + re.escape(name) + r"\([^\n]*\{.*?^\}"
        source = re.sub(pattern, lambda match: "$if " + condition + " {\n"
                        + "\n".join("\t" + line for line in match[0].splitlines())
                        + "\n}", source, flags=re.DOTALL)
    return source


def patch_module(package, source):
    if package == "stbi":
        source = source.replace("import os\n", "$if windows && clang {\n\timport os\n}\n")
    if package in {"gg", "net/openssl"}:
        source = re.sub(r'u64\(usize\((voidptr\([^()]*\))\)\)', r'u64(\1)', source)
        source = re.sub(r'\busize\(', 'uint(', source)
    if package == "gg":
        # GG allocates a sampler for every image. Sokol's default sampler pool
        # (64) is smaller than sapp's image pool (1000), so image-heavy pages
        # otherwise exhaust it and render with invalid texture bindings.
        source = source.replace(
            "\tdesc := sapp.create_desc()\n",
            "\tmut desc := sapp.create_desc()\n"
            "\tif desc.sampler_pool_size < desc.image_pool_size {\n"
            "\t\tdesc.sampler_pool_size = desc.image_pool_size\n"
            "\t}\n")
        source = remove_unused_private_helper(source, "gg_fail_fn")
        source = condition_private_helpers(source, ["gg_poison_gfx_render_owner"],
                                           "gg_multiwindow ? || test")
        source = re.sub(r"(?m)^const (err_multiwindow_render_(?!device_lost\b)\w+ = [^\n]+)$",
                        r"$if gg_multiwindow ? || test {\n\tconst \1\n}", source)
        recorder_helpers = ["screenshot_stdout_payload", "emit_recorded_frame_to_stdout",
                            "new_gg_recorder_settings", "parse_screenshot_frames",
                            "parse_screenshot_output", "recorder_env_value",
                            "new_gg_recorder_settings_from_env"]
        if any("fn " + name + "(" in source for name in recorder_helpers):
            source = condition_private_helpers(source, recorder_helpers, "gg_record ? || test")
            source = re.sub(r"(?m)^import ([\w.]+)$",
                            r"$if gg_record ? || test {\n\timport \1\n}", source)
        source = re.sub(r"(?m)^const ((?:recorder_settings|gg_record_stdout_prefix) = [^\n]+)$",
                        r"$if gg_record ? || test {\n\tconst \1\n}", source)
    if package == "net/openssl":
        source = re.sub(r'(?m)^(\s*)unsafe \{\n\s*mut ptr_base := bytes\n',
                        r'\1mut ptr_base := unsafe { bytes }\n\1unsafe {\n', source)
    return source


def stage_module(source, target, package):
    """Keep compiler assets beside patched sources, without changing the compiler."""
    if target.is_symlink():
        target.unlink()
    target.mkdir(parents=True, exist_ok=True)
    expected = set()
    fontstash_adapter = False
    for path in source.rglob("*"):
        if not path.is_file() or path.name.endswith("_test.v"):
            continue
        relative = path.relative_to(source)
        expected.add(relative)
        destination = target / relative
        # UI2's compatibility stage links unmodified directories. Never write
        # through those links when creating Linux's patched module tree.
        parent = target
        for part in relative.parts[:-1]:
            parent = parent / part
            if parent.is_symlink():
                parent.unlink()
            parent.mkdir(exist_ok=True)
        if path.suffix == ".v":
            text = patch_module(package, path.read_text())
            if package == 'gg' and relative == Path('text_rendering.c.v'):
                text = patch_fontstash_callbacks(text)
                fontstash_adapter = True
            write_if_changed(destination, text)
        elif not destination.is_symlink() or destination.resolve() != path.resolve():
            destination.unlink(missing_ok=True)
            destination.symlink_to(path.resolve())
    if fontstash_adapter:
        header = Path('vox_fontstash_callbacks.h')
        expected.add(header)
        destination = target / header
        if destination.is_symlink():
            destination.unlink()
        write_if_changed(destination, Path(__file__).with_name('linux_fontstash_callbacks.h').read_text())
    if target.exists():
        for path in sorted(target.rglob("*"), reverse=True):
            if path.is_dir() and not path.is_symlink():
                if not any(path.iterdir()):
                    path.rmdir()
            elif path.relative_to(target) not in expected:
                path.unlink()


def main():
    repo = Path(__file__).resolve().parent.parent
    work = repo / "Build/linux/native"
    work.mkdir(parents=True, exist_ok=True)
    vlib = compiler_vlib(sys.argv[1], work)
    compiler = os.environ.get("CC", "cc")
    modules = repo / "Build/linux/modules"
    for package, directory, name in [("stbi", "stb_image", "stbi"), ("json", "cJSON", "cJSON")]:
        thirdparty = vlib.parent / "thirdparty" / directory
        if not (vlib / package).is_dir() or not (thirdparty / (name + ".c")).is_file():
            # Current V removed the cJSON-based `json` module (json2 replaces
            # it); Vox does not import it, so skip packages the compiler lacks.
            shutil.rmtree(modules / package, ignore_errors=True)
            continue
        digest = hashlib.sha256(subprocess.check_output([compiler, "--version"]))
        digest.update(Path(__file__).read_bytes())
        for source in sorted(thirdparty.glob("*.h")) + [thirdparty / (name + ".c")]:
            digest.update(source.read_bytes())
        archive = work / (name + ".a")
        stamp = archive.with_suffix(".sha256")
        if not archive.is_file() or not stamp.is_file() or stamp.read_text() != digest.hexdigest():
            object_file = work / (name + ".o")
            subprocess.run([compiler, "-O2", "-fPIC", "-c", str(thirdparty / (name + ".c")),
                            "-o", str(object_file)], check=True)
            subprocess.run(["ar", "rcs", str(archive), str(object_file)], check=True)
            stamp.write_text(digest.hexdigest())
        for source in (vlib / package).rglob("*.v"):
            if source.name.endswith("_test.v"):
                continue
            text = patch_module(package, source.read_text()).replace(
                f"#flag @VEXEROOT/thirdparty/{directory}/{name}.o", f"#flag {archive}")
            target = modules / package / source.relative_to(vlib / package)
            target.parent.mkdir(parents=True, exist_ok=True)
            write_if_changed(target, text)
    for package in ["gg", "net/openssl"]:
        stage_module(vlib / package, modules / package, package)
    print(modules)


if __name__ == "__main__":
    main()
