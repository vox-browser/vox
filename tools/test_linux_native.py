#!/usr/bin/env python3
"""Run focused Linux platform tests with the staged compatibility modules."""

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

CASES = [
    "css/color_interpolation_test.v", "dom/range_mutation_order_test.v",
    "platform/gc_keepalive_linux_test.v",
    "libjs/stack_info_test.v",
    "libregex/compiled_regex_test.v", "libregex/ecmascript_regex_test.v",
    "platform/native_timer_test.v", "platform/native_deferred_test.v",
    "platform/fontconfig_linux_test.v", "browserjs/linux_runtime_test.v",
    "browserjs/jsc_abi_test.v",
    "gfxfont/woff_test.v",
    "browserjs/runtime_test.v", "browserjs/host_function_test.v",
    "browserjs/event_target_binding_test.v", "adblock/engine_test.v",
    "requestserver/curl_transport_test.v", "requestserver/font_fetch_transport_test.v",
    "layout/portable_shadows_test.v", "html/canvas_skia_raster_test.v",
    "webcrypto/openssl_compat_test.v",
]


def main():
    if sys.platform != "linux":
        raise SystemExit("Run these platform checks on Linux")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gc", choices=["boehm", "none", "prealloc"], default="boehm",
                        help="prealloc exercises scoped arena ownership without a collector")
    parser.add_argument("cases", nargs="*", default=CASES)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    compiler = os.environ.get("V_BIN") or shutil.which("v") or str(Path.home() / "code/v/v")
    c_compiler = os.environ.get("CC", "clang")
    c_version = subprocess.check_output([c_compiler, "--version"], text=True)
    c_flags = "-Werror=incompatible-pointer-types"
    if "clang" in c_version.lower():
        c_flags += " -Werror=incompatible-function-pointer-types"
        # Clang groups const-discard warnings under pointer incompatibility.
        # Keep those existing diagnostics as warnings while rejecting actual
        # pointer/output-slot mismatches at native API boundaries.
        c_flags += " -Wno-error=incompatible-pointer-types-discards-qualifiers"
    environment = dict(os.environ, V_C_ERROR_BUG_REPORT_DISABLED="1",
                       V_MACOS_V3_NO_FALLBACK="1")
    bypass = "127.0.0.1,localhost,::1," + environment.get("NO_PROXY", environment.get("no_proxy", ""))
    environment.update(NO_PROXY=bypass, no_proxy=bypass)
    environment["PKG_CONFIG_PATH"] = str(repo / "Build/deps/lib/pkgconfig") + ":" + environment.get("PKG_CONFIG_PATH", "")
    # Stage against this compiler; another host's symlinks may not be accessible.
    http_modules = subprocess.check_output(
        [sys.executable, str(repo / "tools/prepare_http_compat.py"), compiler],
        cwd=repo, env=environment, text=True).strip()
    linux_modules = subprocess.check_output(
        [sys.executable, str(repo / "tools/prepare_linux_modules.py"), compiler],
        cwd=repo, env=environment, text=True).strip()
    module_paths = [str(repo), linux_modules, http_modules]
    # Application tests compile all of module main, including browser chrome.
    # Use the production UI2 adapter only for those cases so engine-only tests
    # retain their existing dependency set.
    if any(re.search(r"(?m)^\s*module\s+main\s*$", (repo / case).read_text())
           for case in args.cases):
        ui2_modules = subprocess.check_output(
            [sys.executable, str(repo / "tools/prepare_ui2.py"), compiler,
             '--lease-pid', str(os.getpid())],
            cwd=repo, env=environment, text=True).strip()
        # The first path selects the immutable UI2 dependency. Put it before
        # shared compatibility modules, which can retain an older UI2 stage.
        module_paths.insert(1, ui2_modules)
    if args.gc == "prealloc":
        # Match the production allocator, including bounded realloc and the
        # persistent closure directory. Flags alone leave global runtime
        # metadata inside whichever document arena first grows it.
        prealloc_modules = subprocess.check_output(
            [sys.executable, str(repo / "tools/prepare_prealloc_runtime.py"), compiler],
            cwd=repo, env=environment, text=True).strip()
        compiler = str(Path(prealloc_modules) / "compiler/v")
        module_paths.insert(1, prealloc_modules)
    paths = "|".join([*module_paths, "@vmodules", "@vlib"])
    output_root = repo / "Build/linux/tests" / args.gc
    output_root.mkdir(parents=True, exist_ok=True)
    output = Path(tempfile.mkdtemp(prefix="run-", dir=output_root))
    print(f"Logs: {output}", flush=True)
    print(f"C diagnostics: {c_compiler} -cstrict {c_flags}", flush=True)
    with tempfile.TemporaryDirectory(prefix="vox-native-") as temporary:
        for case in args.cases:
            # v.mod selects fastc for the application; native ABI diagnostics
            # and the focused prealloc checks use the checked C backend.
            command = [compiler, "-b", "c", "-memory-limit", "10G", "-enable-globals",
                       "-cc", c_compiler, "-cstrict", "-cflags", c_flags,
                       "-gc", "none" if args.gc == "prealloc" else args.gc, "-d", "use_openssl",
                       "-exclude", "@vlib/time/zoneinfo.native.v", "-path", paths]
            if args.gc == "prealloc":
                command += ["-prealloc"]
            elif args.gc == "boehm":
                command += ["-d", "dynamic_boehm"]
            # Compile separately so execution has the focused 3 GiB budget,
            # while the caller's build guard retains its compiler allowance.
            binary = Path(temporary) / Path(case).stem
            command += ["-o", str(binary), case]
            result = subprocess.run(command, cwd=repo, env=environment, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            log = output / (Path(case).stem + ".log")
            log.write_text(result.stdout)
            if result.returncode:
                raise SystemExit(f"FAIL {case} (exit {result.returncode}):\n{result.stdout}")
            command = [sys.executable, str(repo / "tools/run_memory_bounded.py"),
                       "--limit-gib", "3", "--lock", str(output / (binary.name + ".lock")),
                       "--report", str(output / (binary.name + ".json")), "--", str(binary)]
            result = subprocess.run(command, cwd=repo, env=environment, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            with log.open("a") as stream:
                stream.write(result.stdout)
            if result.returncode:
                raise SystemExit(f"FAIL {case} (exit {result.returncode}):\n{result.stdout}")
            print(f"PASS {case} ({args.gc})", flush=True)


if __name__ == "__main__":
    main()
