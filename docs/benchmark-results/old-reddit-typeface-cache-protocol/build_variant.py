#!/usr/bin/env python3
"""Reproduce the Reddit baseline build in separate guarded emit/compile stages.

Usage:
  python3 Build/reddit-optimization/build_variant.py plan candidate1
  python3 Build/reddit-optimization/build_variant.py emit candidate1
  python3 Build/reddit-optimization/build_variant.py compile candidate1

Every variant is an immutable attempt: choose a new name after failure. This
scratch helper never edits source, the baseline project, or failed receipts.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone


HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
GUARD = REPO / "tools/run_memory_bounded.py"
BASE_PROJECT = HERE / "baseline-c"
BASE_RECEIPT = HERE / "baseline-cgen.guard.json"
ENVIRONMENT = HERE / "environment.json"
ENV_KEYS = (
    "VFLAGS", "CFLAGS", "CPPFLAGS", "LDFLAGS", "CC", "VMODULES", "VROOT",
    "VLIB", "VTMP", "V3CACHE", "VTOOLS_CACHE_DIR", "PKG_CONFIG_PATH",
    "V_MACOS_V3_NO_FALLBACK", "V3_ENABLE_UNCHANGED_BUILD_CACHE",
    "V3_DISABLE_UNCHANGED_BUILD_CACHE", "V3_PARALLEL_MONOMORPHIZE",
    "V3_PARALLEL_CC_JOBS",
)


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def digest_json(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def file_identity(path):
    path = Path(path)
    return {"path": str(path), "resolved_path": str(path.resolve()),
            "bytes": path.stat().st_size, "sha256": sha256(path)}


def write_new_json(path, value):
    with Path(path).open("x") as handle:
        json.dump(value, handle, sort_keys=True, indent=2)
        handle.write("\n")


def command_output(argv, cwd=REPO):
    return subprocess.check_output(argv, cwd=cwd, text=True).strip()


def native_argv(project):
    lines = (project / "build.sh").read_text().splitlines()
    if len(lines) != 3 or lines[:2] != ["#!/bin/sh", "set -eu"]:
        raise ValueError(f"Unexpected generated build.sh format: {project}")
    return shlex.split(lines[2])


def normalized_native(argv, project):
    prefix = str(project) + "/"
    return ["@PROJECT@/" + item[len(prefix):] if item.startswith(prefix) else item for item in argv]


def baseline():
    receipt = json.loads(BASE_RECEIPT.read_text())
    if receipt.get("reason") != "completed" or receipt.get("child_exit_code") != 0:
        raise ValueError("Baseline C generation did not complete successfully")
    argv = receipt["command"]
    required = ["-new-compiler", "-glibc", "-memory-limit", "-enable-globals",
                "-cc", "-exclude", "-path", "-gc", "-dump-c-flags", "-cflags",
                "-generate-c-project"]
    if any(flag not in argv for flag in required) or argv[-1] != ".":
        raise ValueError("Unexpected baseline V command")
    for flag, expected in [("-memory-limit", "10G"), ("-cc", "clang-18"),
                           ("-gc", "boehm"), ("-cflags", "-D_GNU_SOURCE=1 -O2"),
                           ("-generate-c-project", str(BASE_PROJECT))]:
        if argv[argv.index(flag) + 1] != expected:
            raise ValueError(f"Unexpected baseline {flag}")
    return argv, native_argv(BASE_PROJECT)


def paths(name, stage):
    label = "cgen" if stage == "emit" else "native"
    return {"project": HERE / f"{name}-c", "flags": HERE / f"{name}-cflags.txt",
            **{key: HERE / f"{name}-{label}.{suffix}" for key, suffix in
               [("inputs", "inputs.json"), ("result", "result.json"),
                ("receipt", "guard.json"), ("log", "log"), ("lock", "lock")]}}


def emit_argv(name):
    original, _ = baseline()
    argv = list(original)
    p = paths(name, "emit")
    argv[argv.index("-dump-c-flags") + 1] = str(p["flags"])
    argv[argv.index("-generate-c-project") + 1] = str(p["project"])
    return argv


def build_environment():
    environment = os.environ.copy()
    # These are the baseline's explicit compiler/linker arguments. Ambient flags
    # would silently supplement them; refuse them instead of suppressing evidence.
    for name in ("VFLAGS", "CFLAGS", "CPPFLAGS", "LDFLAGS", "VROOT", "VLIB"):
        if environment.get(name):
            raise ValueError(f"Unset ambient {name} to reproduce the baseline")
    environment["PKG_CONFIG_PATH"] = str(REPO / "Build/deps/lib/pkgconfig")
    environment["V_MACOS_V3_NO_FALLBACK"] = "1"
    if environment.get("V3_ENABLE_UNCHANGED_BUILD_CACHE") == "1":
        raise ValueError("Unchanged-build cache must stay disabled")
    if environment.get("V3_PARALLEL_MONOMORPHIZE") == "1":
        raise ValueError("Do not enable a new compiler parallelization mode")
    return environment


def source_identity():
    listed = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=REPO)
    files = {}
    for name in sorted(set(os.fsdecode(item) for item in listed.split(b"\0") if item)):
        # Documentation, regression fixtures and test-only files cannot enter the
        # normal browser build. Ignore them so documentation/tests can be prepared
        # while an immutable generated C project is compiled.
        if (name.startswith(("docs/", "Tests/", "pixel_tests/", "Build/"))
                or name.endswith((".md", "_test.v", "_test.py"))):
            continue
        path = REPO / name
        if path.is_file():
            files[name] = sha256(path)
    return {"head": command_output(["git", "rev-parse", "HEAD"]),
            "files_sha256": digest_json(files), "files": files}


def git_identity(root):
    diff = subprocess.check_output(["git", "diff", "--binary", "HEAD"], cwd=root)
    return {"path": str(root),
            "head": command_output(["git", "rev-parse", "HEAD"], root),
            "tracked_diff_sha256": hashlib.sha256(diff).hexdigest()}


def staged_identity(root):
    files = {}
    visited = set()
    for directory, subdirs, names in os.walk(root, followlinks=True):
        real = str(Path(directory).resolve())
        if real in visited:
            subdirs[:] = []
            continue
        visited.add(real)
        subdirs[:] = sorted(name for name in subdirs if name != ".git")
        for name in sorted(names):
            path = Path(directory) / name
            if path.is_file():
                files[str(path.relative_to(root))] = sha256(path)
    return {"root": str(root), "files_sha256": digest_json(files), "files": files}


def runtime_identity(base_native):
    # Pin every explicit native helper/archive, Skia archives selected by -L/-l,
    # and the optional JPEGXL sidecar. Also retain the baseline loader's actual
    # shared-library resolutions once that binary is available.
    candidates = {Path(item) for item in base_native[1:]
                  if Path(item).is_absolute() and Path(item).is_file()
                  and not str(item).startswith(str(BASE_PROJECT) + "/")}
    candidates.update((REPO / "Build/linux/native").glob("*.a"))
    candidates.update((REPO / "Build/deps/skia/out/Release").glob("*.a"))
    for path in (REPO / "Build/linux/libVoxJPEGXL.so",
                 REPO / "Build/linux/rust-jpegxl/release/libvox_jpegxl.so"):
        if path.is_file():
            candidates.add(path)
    runtime = []
    executable = BASE_PROJECT / "vox2"
    if executable.is_file():
        output = command_output(["ldd", str(executable)])
        for line in output.splitlines():
            match = re.search(r"(?:=>\s+)?(/\S+)", line)
            if match and Path(match[1]).is_file():
                path = Path(match[1])
                candidates.add(path)
                # Loader addresses are randomized on every invocation and are
                # not part of a library's identity.
                library = line.split("=>", 1)[0].strip() if "=>" in line else path.name
                runtime.append({"library": library, "path": str(path)})
    return {"files": [file_identity(path) for path in sorted(candidates)],
            "baseline_shared_library_resolution": runtime}


def identities(environment):
    argv, base_native = baseline()
    compiler = Path(argv[0])
    expected = json.loads(ENVIRONMENT.read_text())
    compiler_file = file_identity(compiler)
    if compiler_file["sha256"] != expected["compiler_sha256"]:
        raise ValueError("V compiler differs from baseline environment identity")
    cc = shutil.which(argv[argv.index("-cc") + 1], path=environment.get("PATH"))
    if cc is None:
        raise ValueError("Baseline native compiler is unavailable")
    cc_version = command_output([cc, "--version"])
    if cc_version != expected["clang"]:
        raise ValueError("Native compiler version differs from baseline")
    module_roots = [Path(item) for item in argv[argv.index("-path") + 1].split("|")
                    if not item.startswith("@") and Path(item) != REPO]
    return {"source": source_identity(),
            "v_compiler": {"binary": compiler_file, "source": git_identity(compiler.parent)},
            "ui2_source": git_identity(REPO.parent / "ui2"),
            "native_compiler": {"binary": file_identity(cc), "version": cc_version},
            "staged_modules": [staged_identity(root) for root in module_roots],
            "native_runtime": runtime_identity(base_native),
            "guard": file_identity(GUARD), "helper": file_identity(__file__),
            "environment": {key: environment.get(key) for key in ENV_KEYS},
            "baseline_inputs": [file_identity(path) for path in
                                (BASE_RECEIPT, BASE_PROJECT / "build.sh", ENVIRONMENT)]}


def generated_identity(project, flags):
    return {name: file_identity(project / name) for name in
            ("vox2.c", "build.sh", "build_command.txt", "Makefile", "build.bat")} | {
                "flags": file_identity(flags)}


def validate_native(project):
    _, original = baseline()
    current = native_argv(project)
    if normalized_native(current, project) != normalized_native(original, BASE_PROJECT):
        raise ValueError("Generated native arguments differ from baseline beyond output/source paths")
    return current


def run_stage(stage, name, timeout):
    p = paths(name, stage)
    for key in ("inputs", "result", "receipt", "log", "lock"):
        if p[key].exists():
            raise FileExistsError(f"Preserving existing attempt: {p[key]}; choose a new variant name")
    environment = build_environment()
    argv = emit_argv(name) if stage == "emit" else ["sh", str(p["project"] / "build.sh")]
    if stage == "emit":
        if p["project"].exists() or p["flags"].exists():
            raise FileExistsError("Generated output already exists; choose a new variant name")
    else:
        emit = paths(name, "emit")
        previous = json.loads(emit["result"].read_text())
        if not previous.get("accepted"):
            raise ValueError("Emit stage was not accepted")
        if (p["project"] / "vox2").exists():
            raise FileExistsError("Native output already exists; choose a new variant name")
        if generated_identity(p["project"], p["flags"]) != previous["generated"]:
            raise ValueError("Generated project changed after emit")
        validate_native(p["project"])
    before = identities(environment)
    if stage == "compile" and before != previous["after"]:
        raise ValueError("Source/toolchain/runtime/environment changed after emit")
    guard_argv = [sys.executable, str(GUARD), "--lock", str(p["lock"]),
                  "--report", str(p["receipt"]), "--timeout", str(timeout), "--", *argv]
    record = {"stage": stage, "variant": name, "started": utc_now(), "cwd": str(REPO),
              "command": argv, "guard_command": guard_argv, "before": before}
    if stage == "compile":
        record["native_command"] = native_argv(p["project"])
    write_new_json(p["inputs"], record)
    if stage == "emit":
        p["project"].mkdir()
    result = {"stage": stage, "variant": name, "accepted": False}
    try:
        with p["log"].open("x") as output:
            completed = subprocess.run(guard_argv, cwd=REPO, env=environment,
                                       stdout=output, stderr=subprocess.STDOUT)
        result["exit_code"] = completed.returncode
        result["guard"] = json.loads(p["receipt"].read_text())
        result["after"] = identities(environment)
        result["inputs_unchanged"] = result["after"] == before
        if completed.returncode == 0 and result["inputs_unchanged"]:
            validate_native(p["project"])
            result["generated"] = generated_identity(p["project"], p["flags"])
            if stage == "compile":
                result["binary"] = file_identity(p["project"] / "vox2")
            result["accepted"] = True
    except BaseException as error:
        result["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        result["finished"] = utc_now()
        write_new_json(p["result"], result)
        print(json.dumps({key: result.get(key) for key in
                          ("stage", "variant", "accepted", "exit_code", "error")}), flush=True)
        print(f"Log: {p['log']}\nResult: {p['result']}", flush=True)
    return 0 if result["accepted"] else result.get("exit_code") or 125


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("plan", "emit", "compile"))
    parser.add_argument("variant")
    parser.add_argument("--timeout", type=int, default=1800,
                        help="Memory-guard stage timeout, seconds (default: 1800)")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9_-]{0,60}", args.variant) or args.variant == "baseline":
        parser.error("Use a new non-baseline variant name containing lowercase letters, digits, _ or -")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if args.stage == "plan":
        print(json.dumps({"emit": emit_argv(args.variant),
                          "compile": ["sh", str(paths(args.variant, "compile")["project"] / "build.sh")],
                          "cwd": str(REPO), "guard_limit_gib": 12,
                          "timeout_seconds": args.timeout}, indent=2))
        return 0
    return run_stage(args.stage, args.variant, args.timeout)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"build_variant: {error}", file=sys.stderr)
        raise SystemExit(2)
