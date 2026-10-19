#!/usr/bin/env python3
"""Run focused Linux platform tests with the staged compatibility modules."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

CASES = [
    "platform/native_timer_test.v", "platform/native_deferred_test.v",
    "platform/fontconfig_linux_test.v", "browserjs/linux_runtime_test.v",
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
    parser.add_argument("--gc", choices=["boehm", "none"], default="boehm")
    parser.add_argument("cases", nargs="*", default=CASES)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    compiler = os.environ.get("V_BIN") or shutil.which("v") or str(Path.home() / "code/v/v")
    environment = dict(os.environ, V_C_ERROR_BUG_REPORT_DISABLED="1")
    bypass = "127.0.0.1,localhost,::1," + environment.get("NO_PROXY", environment.get("no_proxy", ""))
    environment.update(NO_PROXY=bypass, no_proxy=bypass)
    environment["PKG_CONFIG_PATH"] = str(repo / "Build/deps/lib/pkgconfig") + ":" + environment.get("PKG_CONFIG_PATH", "")
    # The repository root anchors package names; see build-linux-browser.sh.
    paths = f"{repo}|{repo}/Build/linux/modules|{repo}/Build/v/modules|@vmodules|@vlib"
    output = repo / "Build/linux/tests" / args.gc
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vox-native-") as temporary:
        for case in args.cases:
            command = [compiler, "-enable-globals", "-cc", os.environ.get("CC", "clang"),
                       "-gc", args.gc, "-d", "use_openssl", "-path", paths]
            if args.gc != "none":
                command += ["-d", "dynamic_boehm"]
            # vtest in the compatibility compiler does not quote | in -path.
            # Direct run preserves argument boundaries and runs the same tests.
            command += ["-o", str(Path(temporary) / Path(case).stem), "run", case]
            result = subprocess.run(command, cwd=repo, env=environment, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            (output / (Path(case).stem + ".log")).write_text(result.stdout)
            if result.returncode:
                raise SystemExit(f"FAIL {case} (exit {result.returncode}):\n{result.stdout}")
            print(f"PASS {case} ({args.gc})", flush=True)


if __name__ == "__main__":
    main()
