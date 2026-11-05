#!/usr/bin/env python3
"""Build and run the pooled layer frame-buffer test in MRC and ARC modes.

Run through tools/run_memory_bounded.py (3 GiB suffices).
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="vox-frame-pool-"))
    output.mkdir(parents=True, exist_ok=True)
    failed = False
    for mode, flag in (("mrc", "-fno-objc-arc"), ("arc", "-fobjc-arc")):
        binary = output / mode
        command = [shutil.which("clang"), "-O2", "-fblocks", flag,
                   "-framework", "Cocoa", "-framework", "QuartzCore", "-framework", "IOSurface", "-framework", "CoreGraphics",
                   "-I", str(root), str(root / "tools/native_layer_frame_pool_test.m"), "-o", str(binary)]
        with (output / (mode + ".log")).open("w") as log:
            compiled = subprocess.call(command, stdout=log, stderr=subprocess.STDOUT)
            tested = subprocess.call([str(binary)], stdout=log, stderr=subprocess.STDOUT) if compiled == 0 else None
            cleared = subprocess.call([str(binary)], env={**os.environ,
                'VOX_CLEAR_OPAQUE_FRAME_BUFFERS': '1'}, stdout=log,
                stderr=subprocess.STDOUT) if compiled == 0 else None
            spare = subprocess.call([str(binary), '--spare'], stdout=log,
                                    stderr=subprocess.STDOUT) if compiled == 0 else None
        failed = failed or tested != 0 or cleared != 0 or spare != 0
        print(json.dumps(dict(mode=mode, compile_exit=compiled, test_exit=tested,
                             cleared_test_exit=cleared, spare_test_exit=spare,
                             log=str(output / (mode + ".log")))), flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
