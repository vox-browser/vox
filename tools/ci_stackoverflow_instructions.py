#!/usr/bin/env python3
"""Build and profile the frozen Stack Overflow workload on a normal Linux VM.

The initial default is one Cachegrind baseline and one separate Callgrind
diagnostic. Optional paired measurements do not replace correctness tests.
No repository writes, worktrees, copied source trees or app bundles are used.
"""
from __future__ import annotations

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
import time

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "tools/ci_stackoverflow_instructions.py"
PINS = {
    "v": ("vlang/v", "a629e6ca3364e9729ce5e043ec7cebddf3823731"),
    "v/vc": ("vlang/vc", "b83fa19d76b8f19977543da4bb7ccbb9455733d6"),
    "v/thirdparty/tcc": ("vlang/tccbin", "60d606e37e6afe1ac5801fd88c55036a56b7caae"),
    "ui2": ("vlang/ui2", "96f5924d73f69c0302de3c5c31d9964d4d11f573"),
}


def digest(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def save(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def read(command, cwd=ROOT):
    return subprocess.check_output(command, cwd=cwd, text=True).strip()


def git(*arguments):
    return read(["git", *arguments])


def sources():
    if git("branch", "--show-current") != "master":
        raise RuntimeError("Use the single local master checkout")
    if git("status", "--porcelain", "--untracked-files=no"):
        raise RuntimeError("Tracked source files changed")
    names = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).split(b"\0")
    return {"head": git("rev-parse", "HEAD"), "sha256": {
        os.fsdecode(name): digest(ROOT / os.fsdecode(name))
        for name in names if name and (ROOT / os.fsdecode(name)).is_file()}}


def compiler_wrapper(arguments):
    if "-memory-limit" not in arguments:
        arguments = ["-memory-limit", "10G", *arguments]
    if "-no-memory-limit" in arguments:
        raise ValueError("Unbounded V compilation is not permitted")
    final = os.environ["VOX_CI_FINAL_OUTPUT"]
    if "-o" in arguments and arguments[arguments.index("-o") + 1] == final:
        stage = Path(final).parent
        # Supported V C-project output retains the driver's complete native
        # command. The large C compile starts only after the V process exits.
        arguments += ["-glibc", "-generate-c-project", str(stage / "generated-c"),
                      "-dump-c-flags", str(stage / "c-flags.txt"),
                      "-dump-files", str(stage / "v-files.txt")]
        save(stage / "v-command.json", arguments)
    real = os.environ["VOX_CI_REAL_V"]
    os.execv(real, [real, *arguments])


class Run:
    def __init__(self):
        relative = os.environ.get("VOX_CI_EVIDENCE", "")
        if not re.fullmatch(r"Build/ci-stackoverflow-[0-9]+-[0-9]+", relative):
            raise ValueError("Use a fresh VOX_CI_EVIDENCE path for this run and attempt")
        self.output = ROOT / relative
        self.output.mkdir(parents=True, exist_ok=True)

    def command(self, name, command, cwd=ROOT, env=None, limit=None,
                timeout=1800, allow_failure=False, bounded=True):
        invoked = [str(part) for part in command]
        if bounded:
            invoked = [sys.executable, str(ROOT / "tools/run_memory_bounded.py"),
                       "--lock", str(self.output / (name + ".lock")),
                       "--report", str(self.output / (name + "-guard.json")),
                       "--timeout", str(timeout),
                       *([] if limit is None else ["--limit-gib", str(limit)]),
                       "--", *invoked]
        started = time.time()
        print(json.dumps({"stage": name, "status": "started"}), flush=True)
        log = self.output / (name + ".log")
        with log.open("x") as stream:
            result = subprocess.run(invoked, cwd=cwd, env=env,
                                    stdout=stream, stderr=subprocess.STDOUT)
        with (self.output / "commands.jsonl").open("a") as stream:
            stream.write(json.dumps({"stage": name, "command": invoked, "cwd": str(cwd),
                "started": started, "ended": time.time(), "exit_code": result.returncode}) + "\n")
        print(json.dumps({"stage": name, "exit_code": result.returncode}), flush=True)
        if result.returncode and not allow_failure:
            print(log.read_text(errors="replace")[-18000:], file=sys.stderr)
            raise RuntimeError(f"{name} failed; full log retained in {log}")
        return result.returncode

    def select(self, sha, runner_bytes):
        if not re.fullmatch(r"[0-9a-f]{40}", sha):
            raise ValueError("Only exact full commit SHAs are accepted")
        subprocess.run(["git", "merge-base", "--is-ancestor", sha, "origin/master"],
                       cwd=ROOT, check=True)
        if subprocess.check_output(["git", "show", f"{sha}:{SCRIPT}"], cwd=ROOT) != runner_bytes:
            raise ValueError("The selected source must contain this exact runner")
        if git("status", "--porcelain", "--untracked-files=no"):
            raise RuntimeError("Refusing to replace uncommitted source files")
        # This is the fresh Actions runner's local branch only. No remote ref
        # changes, detached build or second Vox source checkout is involved.
        subprocess.run(["git", "switch", "-C", "master", sha], cwd=ROOT, check=True)
        return sources()

    def build(self):
        baseline = os.environ["VOX_CI_BASELINE_SHA"]
        candidate = os.environ.get("VOX_CI_CANDIDATE_SHA", "")
        runner_bytes = (ROOT / SCRIPT).read_bytes()
        self.select(baseline, runner_bytes)
        if candidate:
            if not re.fullmatch(r"[0-9a-f]{40}", candidate) or candidate == baseline:
                raise ValueError("A candidate must be a distinct full SHA")
            subprocess.run(["git", "merge-base", "--is-ancestor", baseline, candidate],
                           cwd=ROOT, check=True)
            shared = git("diff", "--name-only", baseline, candidate, "--", "tools",
                         "build-linux-browser.sh", "build-prod-browser.sh",
                         "Tests/Browser/Brave/sites/stackoverflow", "native_jpegxl_rust")
            if shared:
                raise ValueError("Build/observer/workload inputs differ:\n" + shared)
        state = {"baseline": baseline, "candidate": candidate, "dependencies": PINS, "builds": {}}
        if (self.output / "state.json").exists():
            raise RuntimeError("Do not reuse an earlier attempt's evidence directory")
        save(self.output / "state.json", state)
        for name, command in (
            ("host-uname", ["uname", "-a"]), ("host-memory", ["free", "-b"]),
            ("host-disk", ["df", "-h", str(ROOT)]), ("host-cpu", ["lscpu"]),
            ("host-packages", ["dpkg-query", "-W"]),
            ("host-clang", ["clang", "--version"]),
            ("host-rust", ["rustc", "--version", "--verbose"]),
            ("host-cargo", ["cargo", "--version"]),
            ("host-valgrind", ["valgrind", "--version"]),
        ):
            self.command(name, command, bounded=False)
        deps = ROOT / "Build/ci-dependencies"
        for relative, (repository, sha) in PINS.items():
            path = deps / relative
            if path.exists():
                raise RuntimeError(f"Fresh dependency checkout required: {path}")
            path.mkdir(parents=True)
            name = relative.replace("/", "-")
            self.command(name + "-init", ["git", "init"], cwd=path, bounded=False)
            self.command(name + "-origin", ["git", "remote", "add", "origin",
                         f"https://github.com/{repository}.git"], cwd=path, bounded=False)
            self.command(name + "-fetch", ["git", "fetch", "--depth", "1", "origin", sha],
                         cwd=path, bounded=False)
            self.command(name + "-checkout", ["git", "switch", "-c", "master", "FETCH_HEAD"],
                         cwd=path, bounded=False)
            if read(["git", "rev-parse", "HEAD"], cwd=path) != sha:
                raise RuntimeError("Dependency pin mismatch")
        env = dict(os.environ, CC="clang", CXX="clang++", LADYBIRD_V_GC="boehm",
                   VOX_CI_REAL_V=str(deps / "v/v"), UI2_SOURCE_DIR=str(deps / "ui2"),
                   VOX_LINUX_CFLAGS="-O2 -gline-tables-only")
        self.command("build-v", ["make", "-j1", "local=1", "VFLAGS=-memory-limit 10G"],
                     cwd=deps / "v", env=env)
        state["v_executable_sha256"] = digest(deps / "v/v")
        self.command("build-skia", [sys.executable, "tools/build_linux_skia.py"],
                     env=env, timeout=3600)
        for label, sha in [("baseline", baseline)] + ([("candidate", candidate)] if candidate else []):
            before = self.select(sha, runner_bytes)
            stage = self.output / label
            stage.mkdir()
            save(stage / "sources.json", before)
            launcher = stage / "v-launcher"
            launcher.write_text("#!/bin/sh\nexec " + shlex.join(
                [sys.executable, str(ROOT / SCRIPT), "compiler-wrapper"]) + ' "$@"\n')
            launcher.chmod(0o755)
            variant_env = dict(env, V_BIN=str(launcher), VOX_BUILD_SUPERVISED="1",
                               VOX_BUILD_OUTPUT_DIR=str(stage), VOX_CI_FINAL_OUTPUT=str(stage / "vox"))
            self.command(label + "-emit-c", ["sh", "build-linux-browser.sh"],
                         env=variant_env, timeout=3600)
            project = stage / "generated-c"
            c_files = list(project.glob("*.c"))
            if len(c_files) != 1 or not (project / "build.sh").is_file():
                raise RuntimeError("Expected one complete V-generated C project")
            self.command(label + "-compile-c", ["sh", str(project / "build.sh")],
                         env=variant_env, timeout=3600)
            c_files[0].with_suffix("").replace(stage / "vox")
            self.command(label + "-startup", [str(stage / "vox"), "--headless-smoke"],
                         env=dict(env, VOX_PROFILE_DIR=str(stage / "smoke-profile"), VOX_TEST_WINDOW="1"),
                         limit=3, timeout=300)
            if sources() != before:
                raise RuntimeError("Sources changed during the build")
            native = {}
            for directory in (ROOT / "Build/linux/native", ROOT / "Build/libregex/linux",
                              ROOT / "Build/deps/skia/out/Release"):
                native.update({str(p): digest(p) for p in directory.glob("*.a")})
            state["builds"][label] = {"sha": sha, "binary": str(stage / "vox"),
                "binary_sha256": digest(stage / "vox"), "native_sha256": native,
                "runtime_sha256": {p.name: digest(p) for p in stage.glob("*.so")}}
            save(self.output / "state.json", state)
        if candidate:
            first, second = state["builds"]["baseline"], state["builds"]["candidate"]
            if first["native_sha256"] != second["native_sha256"] or first["runtime_sha256"] != second["runtime_sha256"]:
                raise RuntimeError("Native dependencies differ between builds")
        self.command("counter-tests", [sys.executable, "-m", "unittest",
                     "linux_instruction_counts_test", "measure_browser_instructions_test",
                     "process_instruction_counts_test", "stackoverflow_browser_instructions_test"],
                     env=dict(env, PYTHONPATH=str(ROOT / "tools")), limit=3, timeout=600)
        state.update(ready=True, active_source=sources())
        save(self.output / "state.json", state)

    def measure(self, profile=False):
        state = json.loads((self.output / "state.json").read_text())
        if not state.get("ready") or sources() != state["active_source"]:
            raise RuntimeError("Incomplete builds or changed source pins")
        for item in state["builds"].values():
            if digest(item["binary"]) != item["binary_sha256"]:
                raise RuntimeError("Executable pin changed")
            for path, expected in item["native_sha256"].items():
                if digest(path) != expected:
                    raise RuntimeError("Native archive pin changed")
            for name, expected in item["runtime_sha256"].items():
                if digest(Path(item["binary"]).parent / name) != expected:
                    raise RuntimeError("Runtime library pin changed")
        if profile and state["candidate"]:
            raise ValueError("The profile phase is for baseline-only runs")
        label = "callgrind-diagnostic" if profile else "cachegrind-cohort"
        output = self.output / label
        command = [sys.executable, "tools/stackoverflow_browser_instructions.py", "--binary",
                   state["builds"]["baseline"]["binary"], "--counter-backend",
                   "callgrind" if profile else "cachegrind", "--output", str(output),
                   "--timeout", "1800", "--pairs", "3" if state["candidate"] else "1"]
        if state["candidate"]:
            command += ["--candidate", state["builds"]["candidate"]["binary"],
                        "--required-reduction", "0.10"]
        code = self.command(label, command, limit=3,
                            timeout=10860 if state["candidate"] else 1860, allow_failure=True)
        pattern = "*.callgrind.*" if profile else "*.cachegrind.*"
        for index, path in enumerate(sorted(output.rglob(pattern))):
            if path.is_file() and path.name.rsplit(".", 1)[-1].isdigit():
                annotate = ["callgrind_annotate" if profile else "cg_annotate",
                            "--auto=no", "--threshold=99", "--show=Ir"]
                if profile:
                    annotate.append("--inclusive=yes")
                self.command(label + f"-annotation-{index}", [*annotate, str(path)],
                             limit=3, timeout=300, allow_failure=True)
        if sources() != state["active_source"]:
            raise RuntimeError("Sources changed during measurement")
        if code:
            raise RuntimeError(f"{label} failed; its raw profile and failure are preserved")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "compiler-wrapper":
        compiler_wrapper(sys.argv[2:])
        return
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["build", "measure", "profile"])
    args = parser.parse_args()
    run = Run()
    try:
        if args.phase == "build":
            run.build()
        else:
            run.measure(profile=args.phase == "profile")
    except Exception as error:
        save(run.output / (args.phase + "-failure.json"), {"error": str(error), "time": time.time()})
        raise


if __name__ == "__main__":
    main()
