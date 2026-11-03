#!/usr/bin/env python3
"""Stage HTTP header, cookie and verified-proxy fixes without editing V."""

from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from http_tls_dial import patch_transport_tls, tls_dial_helper
from http_h2_fairness import patch_h2_pooled_transport
from http_h2_receive_credit import patch_h2_mux_receive_credit
from http_h2_wakeup import patch_h2_wakeup
from http_receive_buffer import patch_receive_buffer, receive_buffer_helper


def replace_function(source, signature, replacement):
    pattern = re.compile(re.escape(signature) + r"\s*\{.*?^\}", re.MULTILINE | re.DOTALL)
    result, count = pattern.subn(lambda _: replacement.strip(), source)
    if count != 1:
        raise RuntimeError(f"Unsupported V HTTP header source: expected one {signature!r}, found {count}")
    return result


def remove_unused_private_helper(source, name):
    """Drop compiler helpers made obsolete by our replacement implementations."""
    pattern = re.compile(
        r"(?m)^(?:\s*//[^\n]*\n|@\[[^\n]*\]\n)*fn "
        + re.escape(name) + r"\([^\n]*\{.*?^\}\n?", re.DOTALL)
    remaining, count = pattern.subn("", source)
    if count > 1:
        raise RuntimeError(f"Multiple private HTTP helpers named {name}")
    # Some compiler revisions still call these helpers from unpatched APIs.
    code = re.sub(r"//[^\n]*", "", remaining)
    if count == 1 and not re.search(r"\b" + re.escape(name) + r"\b", code):
        return remaining
    return source


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
    return remove_unused_private_helper(source, "header_value_without_ows")


def write_if_changed(path, content):
    if path.is_symlink():
        path.unlink()
    if not path.is_file() or path.read_text() != content:
        path.write_text(content)


def patch_request(source):
    """Preserve request-target bytes and explicit Cookie headers."""
    # Pointer identity must retain its full width with both compiler generations.
    source = re.sub(r'u64\(usize\(([^()]*)\)\)', r'u64(voidptr(\1))', source)
    if 'fn (req &Request) method_and_url_to_response(' in source:
        old_target = "p := url.escaped_path().trim_left('/')\n\tpath := if url.query().len > 0 { '/${p}?${url.query().encode()}' } else { '/${p}' }"
        # Parsing a request query as form fields treats semicolons as separators,
        # changing URLs such as Google Fonts' wght@400;500 selection. The URL's
        # request URI already preserves escapes, duplicates and an empty query.
        if source.count(old_target) == 1:
            source = source.replace(old_target, 'path := url.request_uri()', 1)
        elif source.count('path := url.request_uri()') != 1:
            raise RuntimeError('Unsupported HTTP request-target source')
    signature = 'fn (req &Request) build_request_cookies_header_with_header(header Header) string'
    if 'cookie_header_value_with_header(header)' in source:
        # Current V already serializes an explicit Cookie header itself.
        return source
    start = source.index(signature)
    end = source.index('\n}', start) + 2
    function = source[start:end]
    old = "if req.cookies.len < 1 {\n\t\treturn ''\n\t}"
    new = "if req.cookies.len < 1 {\n\t\tvalues := header.values(.cookie)\n\t\treturn if values.len == 0 { '' } else { 'Cookie: ' + values.join('; ') + '\\r\\n' }\n\t}"
    if function.count(old) != 1:
        raise RuntimeError('Unsupported HTTP cookie serialization source')
    return source[:start] + function.replace(old, new, 1) + source[end:]


def patch_proxy(source):
    """Keep request TLS verification and origin-form targets inside proxy tunnels."""
    source = source.replace('struct HttpProxy {', 'pub struct HttpProxy {', 1)
    old = "pr.ssl_dial('${host_name}:${port}')"
    if source.count(old) != 1:
        raise RuntimeError('Unsupported HTTP proxy TLS call')
    source = source.replace(old, "pr.ssl_dial('${host_name}:${port}', req)", 1)
    old = "'${host.scheme}://${host_name}${port_part}${path}', data, header)"
    if source.count(old) == 1:
        # Both HTTP CONNECT and SOCKS establish an end-to-end tunnel. The
        # request inside it is addressed to the origin, not to a forward HTTP
        # proxy. Current V already builds that origin-form target.
        source = source.replace(old, 'path, data, header)', 1)
        start = source.index('\tport_part :=')
        end = source.index('\n\ts :=', start)
        source = source[:start] + source[end:]
    elif 'req.build_request_headers_with(method, host_name, port, default_port, path, data' not in source:
        raise RuntimeError('Unsupported HTTP proxy request target')
    source = replace_function(source, 'fn (pr &HttpProxy) ssl_dial(host string) !&ssl.SSLConn', r'''
fn (pr &HttpProxy) ssl_dial(host string, req &Request) !&ssl.SSLConn {
    mut ssl_conn := ssl.new_ssl_conn(
        verify: req.verify
        cert: req.cert
        cert_key: req.cert_key
        validate: req.validate
        in_memory_verification: req.in_memory_verification
    )!
    mut tcp := pr.connect_tcp(host)!
    tcp.set_read_timeout(req.read_timeout)
    tcp.set_write_timeout(req.write_timeout)
    ssl_conn.connect(mut tcp, host.all_before_last(':')) or {
        tcp.close() or {}
        ssl_conn.shutdown() or {}
        return err
    }
    ssl_conn.owns_socket = true
    ssl_conn.set_read_timeout(req.read_timeout)
    return ssl_conn
}''')
    return remove_unused_private_helper(source, "proxy_request_target")


def compiler_vlib(compiler, work):
    # Production builds and focused checks can stage modules concurrently.
    # Give each compiler probe its own executable so neither can overwrite a
    # running Mach-O image from another invocation.
    with tempfile.TemporaryDirectory(prefix="compiler-root-", dir=work) as temporary:
        probe = Path(temporary) / "compiler_root.v"
        probe.write_text("module main\nfn main() { println(@VEXEROOT) }\n")
        result = subprocess.run([compiler, "-memory-limit", "10G", "run", str(probe)],
                                capture_output=True, text=True, check=True)
    return Path(result.stdout.strip()).resolve() / "vlib"


def staged_modules(work, vlib):
    identity = hashlib.sha256(str(vlib.resolve()).encode()).hexdigest()[:16]
    return work / identity / "modules"


def remove_obsolete_entries(target, original):
    names = {entry.name for entry in original.iterdir()} | {
        "vox_h2_wake.h", "vox_receive_buffer.h", "vox_receive_buffer.v",
        "vox_receive_buffer_test.v"}
    for entry in target.iterdir():
        if entry.name not in names:
            if entry.is_symlink() or entry.is_file():
                entry.unlink()
            else:
                shutil.rmtree(entry)


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
    request_text = (original / 'request.v').read_text()
    patched_request = patch_receive_buffer(patch_request(request_text))
    proxy_text = (original / 'http_proxy.v').read_text()
    patched_proxy = patch_proxy(proxy_text)
    transport_text = (original / 'transport.v').read_text()
    patched_transport = patch_transport_tls(transport_text) + '\n' + tls_dial_helper()
    h2_text = (original / 'transport_h2.v').read_text()
    patched_h2 = patch_transport_tls(h2_text, http2=True)
    h2_pooled_text = (original / 'h2_pooled_transport.v').read_text()
    patched_h2_pooled = patch_h2_wakeup(patch_h2_pooled_transport(h2_pooled_text))
    h2_mux_text = (original / 'h2_mux_conn.v').read_text()
    patched_h2_mux = patch_h2_mux_receive_credit(h2_mux_text)
    modules = staged_modules(work, vlib)
    target = modules / "net/http"
    target.mkdir(parents=True, exist_ok=True)
    remove_obsolete_entries(target, original)
    write_if_changed(target / 'vox_h2_wake.h', (repo / 'tools/httpcompat/h2_wake.h').read_text())
    receive_header = (repo / 'tools/httpcompat/receive_buffer.h').read_text()
    write_if_changed(target / 'vox_receive_buffer.h', receive_header)
    write_if_changed(target / 'vox_receive_buffer.v', receive_buffer_helper())
    for entry in original.iterdir():
        output = target / entry.name
        if entry.name == "header.v":
            write_if_changed(output, patched)
        elif entry.name == 'request.v':
            write_if_changed(output, patched_request)
        elif entry.name == 'http_proxy.v':
            write_if_changed(output, patched_proxy)
        elif entry.name == 'transport.v':
            write_if_changed(output, patched_transport)
        elif entry.name == 'transport_h2.v':
            write_if_changed(output, patched_h2)
        elif entry.name == 'h2_pooled_transport.v':
            write_if_changed(output, patched_h2_pooled)
        elif entry.name == 'h2_mux_conn.v':
            write_if_changed(output, patched_h2_mux)
        elif not output.is_symlink() or output.resolve() != entry.resolve():
            if output.is_symlink() or output.is_file():
                output.unlink()
            output.symlink_to(entry, target_is_directory=entry.is_dir())
    write_if_changed(modules.parent / "manifest.json", json.dumps({
        "vlib": str(vlib),
        "source_header_sha256": hashlib.sha256(text.encode()).hexdigest(),
        "staged_header_sha256": hashlib.sha256(patched.encode()).hexdigest(),
        "source_request_sha256": hashlib.sha256(request_text.encode()).hexdigest(),
        "staged_request_sha256": hashlib.sha256(patched_request.encode()).hexdigest(),
        "receive_buffer_header_sha256": hashlib.sha256(receive_header.encode()).hexdigest(),
        "receive_buffer_helper_sha256": hashlib.sha256(receive_buffer_helper().encode()).hexdigest(),
        "source_proxy_sha256": hashlib.sha256(proxy_text.encode()).hexdigest(),
        "staged_proxy_sha256": hashlib.sha256(patched_proxy.encode()).hexdigest(),
        "source_transport_sha256": hashlib.sha256(transport_text.encode()).hexdigest(),
        "staged_transport_sha256": hashlib.sha256(patched_transport.encode()).hexdigest(),
        "source_h2_sha256": hashlib.sha256(h2_text.encode()).hexdigest(),
        "staged_h2_sha256": hashlib.sha256(patched_h2.encode()).hexdigest(),
        "source_h2_pooled_sha256": hashlib.sha256(h2_pooled_text.encode()).hexdigest(),
        "staged_h2_pooled_sha256": hashlib.sha256(patched_h2_pooled.encode()).hexdigest(),
        "source_h2_mux_sha256": hashlib.sha256(h2_mux_text.encode()).hexdigest(),
        "staged_h2_mux_sha256": hashlib.sha256(patched_h2_mux.encode()).hexdigest(),
        "adapter": "growable fields; copy-on-write; preserve empty/repeated fields; verified proxy TLS; TCP before TLS setup",
    }, indent=2) + "\n")
    print(modules)


if __name__ == "__main__":
    main()
