#!/usr/bin/env python3
"""Run the actual V resource scope and curl adapter without the DOM/UI graph.

The temporary module contains byte-for-byte copies of the listed production
sources and their tests, plus a v.mod manifest. There are no replacement types,
stubs, or rewritten implementation bodies. Run under tools/run_memory_bounded.py
as with other focused repository tests. --prealloc also selects -gc none.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


SOURCES = (
    "browsernet/request_scope.v",
    "browsernet/request_scope.h",
    "browsernet/body_progress.v",
    "browsernet/cancellable_transport.c.v",
    "browsernet/cancellable_transport.h",
    "browsernet/request_scope_test.v",
    "browsernet/cancellable_transport_test.v",
    "browsernet/cancellable_http2_test.v",
    "browsernet/fixtures/http2_server.mjs",
    "platform/curl_api.h",
    "platform/native_state.h",
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--v", default=os.environ.get("V_BIN") or shutil.which("v"),
                        help="V compiler (defaults to V_BIN, then v on PATH)")
    parser.add_argument("--cc", default=os.environ.get("CC", "cc"), help="C compiler passed to V")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--gc-none", action="store_true", help="exercise explicit native ownership")
    modes.add_argument("--prealloc", action="store_true", help="exercise production arena allocation")
    args = parser.parse_args()
    if not args.v:
        parser.error("provide --v or set V_BIN to the repository's supported V compiler")
    compiler = shutil.which(args.v) or str(Path(args.v).resolve())
    if not Path(compiler).is_file():
        parser.error(f"V compiler does not exist: {compiler}")
    dependencies = {}
    for name, flag in (("node", "--version"), ("openssl", "version")):
        executable = shutil.which(name)
        if not executable:
            parser.error(f"{name} is required; the TLS/HTTP2 tests must not be skipped")
        dependencies[name] = subprocess.check_output([executable, flag], text=True).strip()
    repo = Path(__file__).resolve().parent.parent
    source_bytes = {path: (repo / path).read_bytes() for path in SOURCES}
    hashes = {path: digest(data) for path, data in source_bytes.items()}
    mode = "prealloc" if args.prealloc else "none" if args.gc_none else "default"
    version = subprocess.check_output([compiler, "-memory-limit", "10G", "version"], text=True).strip()
    compiler_hash = digest(Path(compiler).read_bytes())
    print(json.dumps({"mode": mode, "v": version, "compiler_sha256": compiler_hash,
                      "dependencies": dependencies,
                      "source_sha256": hashes}, sort_keys=True), flush=True)
    with tempfile.TemporaryDirectory(prefix="vox-resource-v-") as temporary:
        isolated = Path(temporary)
        for path, data in source_bytes.items():
            target = isolated / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        (isolated / "v.mod").write_text("Module { name: 'resource_lifecycle_tests' }\n")
        scratch = isolated / "tmp"
        scratch.mkdir()
        environment = dict(os.environ, TMPDIR=str(scratch), V_C_ERROR_BUG_REPORT_DISABLED="1",
                           V_MACOS_V3_NO_FALLBACK="1")
        command = [compiler, "-memory-limit", "10G", "-enable-globals", "-cc", args.cc,
                   "-cstrict", "-cflags", "-Werror=incompatible-pointer-types"]
        if args.prealloc:
            command += ["-prealloc", "-gc", "none"]
        elif args.gc_none:
            command += ["-gc", "none"]
        command += ["-path", f"{isolated}|@vlib", "test", str(isolated / "browsernet")]
        try:
            result = subprocess.run(command, cwd=isolated, env=environment, check=False)
        finally:
            changed = [path for path, expected in hashes.items()
                       if digest((repo / path).read_bytes()) != expected
                       or digest((isolated / path).read_bytes()) != expected]
            if digest(Path(compiler).read_bytes()) != compiler_hash:
                changed.append("V compiler")
            if changed:
                raise SystemExit("Inputs changed while resource tests ran: " + ", ".join(changed))
        print(json.dumps({"mode": mode, "exit_code": result.returncode,
                          "source_files_verified": len(hashes)}, sort_keys=True), flush=True)
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
