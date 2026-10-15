#!/usr/bin/env python3
"""Stage growable HTTP headers for V's compatibility compiler, without editing V."""

from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile


def replace_function(source, signature, replacement):
    pattern = re.compile(re.escape(signature) + r"\s*\{.*?^\}", re.MULTILINE | re.DOTALL)
    result, count = pattern.subn(lambda _: replacement.strip(), source)
    if count != 1:
        raise RuntimeError(f"Unsupported V HTTP header source: expected one {signature!r}, found {count}")
    return result


def patch_header(source):
    """Keep the compiler's header API, enums and parser; replace bounded storage."""
    anchor = "data [max_headers]HeaderKV"
    if source.count(anchor) != 1:
        raise RuntimeError("Unsupported V HTTP header source: fixed Header storage was not found")
    source = source.replace(anchor, "data []HeaderKV", 1)
    source = source.replace("pub const max_headers = 50", "// Retained for source compatibility; Header storage grows beyond this value.\npub const max_headers = 50", 1)
    replacements = {
        "pub fn new_header(kvs ...HeaderConfig) Header": r'''
pub fn new_header(kvs ...HeaderConfig) Header {
    mut h := Header{}
    for kv in kvs { h.add(kv.key, kv.value) }
    return h
}''',
        "pub fn (mut h Header) add(key CommonHeader, value string)": r'''
pub fn (mut h Header) add(key CommonHeader, value string) {
    // Header was a value-copy fixed array. Detach before every mutation so
    // request/response Header copies retain that ownership behavior.
    h.data = h.data.clone()
    h.data << HeaderKV{key.str(), value}
    h.cur_pos = h.data.len
}''',
        "pub fn (mut h Header) add_custom(key string, value string) !": r'''
pub fn (mut h Header) add_custom(key string, value string) ! {
    is_valid(key)!
    h.data = h.data.clone()
    h.data << HeaderKV{key, value}
    h.cur_pos = h.data.len
}''',
        "pub fn (mut h Header) set(key CommonHeader, value string)": r'''
pub fn (mut h Header) set(key CommonHeader, value string) {
    h.vox_replace_header_value(key.str(), value)
}''',
        "pub fn (mut h Header) set_custom(key string, value string) !": r'''
pub fn (mut h Header) set_custom(key string, value string) ! {
    is_valid(key)!
    h.vox_replace_header_value(key, value)
}''',
        "pub fn (mut h Header) delete_custom(key string)": r'''
pub fn (mut h Header) delete_custom(key string) {
    mut retained := []HeaderKV{cap: h.data.len}
    for kv in h.data {
        if !header_key_eq(kv.key, key) { retained << kv }
    }
    h.data = retained
    h.cur_pos = retained.len
}''',
        "pub fn (h Header) custom_values(key string, flags HeaderQueryConfig) []string": r'''
pub fn (h Header) custom_values(key string, flags HeaderQueryConfig) []string {
    mut result := []string{}
    for kv in h.data {
        matched := if flags.exact { kv.key == key } else { header_key_eq(kv.key, key) }
        if matched { result << kv.value }
    }
    return result
}''',
        "pub fn (h Header) keys() []string": r'''
pub fn (h Header) keys() []string {
    mut result := []string{cap: h.data.len}
    for kv in h.data { result << kv.key }
    return arrays.uniq(result)
}''',
        "pub fn (h Header) render_into_sb(mut sb strings.Builder, flags HeaderRenderConfig)": r'''
pub fn (h Header) render_into_sb(mut sb strings.Builder, flags HeaderRenderConfig) {
    for kv in h.data {
        key := if flags.version == .v2_0 {
            kv.key.to_lower()
        } else if flags.canonicalize {
            canonicalize(kv.key.to_lower())
        } else {
            kv.key
        }
        sb.write_string(key)
        sb.write_string(': ')
        sb.write_string(kv.value)
        sb.write_string('\r\n')
    }
}''',
    }
    for signature, replacement in replacements.items():
        source = replace_function(source, signature, replacement)
    source += r'''

// Rebuild rather than mutating a shared array. Empty values are real fields;
// removal deletes an entry instead of using an empty value as a tombstone.
fn (mut h Header) vox_replace_header_value(key string, value string) {
    mut replaced := false
    mut result := []HeaderKV{cap: h.data.len + 1}
    for kv in h.data {
        if header_key_eq(kv.key, key) {
            if !replaced { result << HeaderKV{key, value}; replaced = true }
        } else {
            result << kv
        }
    }
    if !replaced { result << HeaderKV{key, value} }
    h.data = result
    h.cur_pos = result.len
}
'''
    return source


def write_if_changed(path, content):
    if path.is_symlink():
        path.unlink()
    if not path.is_file() or path.read_text() != content:
        path.write_text(content)


def compiler_vlib(compiler, work):
    # Production builds and focused checks can stage modules concurrently.
    # Give each compiler probe its own executable so neither can overwrite a
    # running Mach-O image from another invocation.
    with tempfile.TemporaryDirectory(prefix="compiler-root-", dir=work) as temporary:
        probe = Path(temporary) / "compiler_root.v"
        probe.write_text("module main\nfn main() { println(@VEXEROOT) }\n")
        result = subprocess.run([compiler, "-old-compiler", "run", str(probe)],
                                capture_output=True, text=True, check=True)
    return Path(result.stdout.strip()).resolve() / "vlib"


def main():
    repo = Path(__file__).resolve().parent.parent
    compiler = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "V_BIN", shutil.which("v") or str(Path.home() / "code/v/v"))
    work = repo / "Build/v/httpcompat"
    work.mkdir(parents=True, exist_ok=True)
    vlib = compiler_vlib(compiler, work)
    original = vlib / "net/http"
    header = original / "header.v"
    text = header.read_text()
    patched = patch_header(text)
    modules = repo / "Build/v/modules"
    target = modules / "net/http"
    target.mkdir(parents=True, exist_ok=True)
    for entry in original.iterdir():
        output = target / entry.name
        if entry.name == "header.v":
            write_if_changed(output, patched)
        elif not output.is_symlink() or output.resolve() != entry.resolve():
            if output.is_symlink() or output.is_file():
                output.unlink()
            output.symlink_to(entry, target_is_directory=entry.is_dir())
    write_if_changed(work / "manifest.json", json.dumps({
        "vlib": str(vlib),
        "source_header_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "staged_header_sha256": hashlib.sha256(patched.encode()).hexdigest(),
        "adapter": "growable fields; copy-on-write; preserve empty/repeated fields",
    }, indent=2) + "\n")
    print(modules)


if __name__ == "__main__":
    main()
