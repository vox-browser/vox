"""Explicit Linux instruction counters for complete executable launches.

The perf backend counts real user-space retired instructions with inheritance,
enabled at exec. Callgrind and Cachegrind are separate opt-in software metrics:
their Ir events count instrumented guest instructions, not hardware-retired
instructions. Never mix these metrics or silently fall back between them.
"""
from __future__ import annotations

import ctypes
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import struct
import subprocess
import time


class CounterUnavailable(RuntimeError):
    pass


class LinuxPerfInstructions:
    """One inherited hardware event attached before the measured child execs.

    Kernel and hypervisor instructions are excluded. No scaling or estimates
    are accepted: a multiplexed, unscheduled, or zero counter is invalid.
    """

    def __init__(self, pid):
        if platform.system() != "Linux":
            raise CounterUnavailable("perf_event_open requires Linux")
        syscall_number = {"x86_64": 298, "aarch64": 241}.get(platform.machine())
        if syscall_number is None:
            raise CounterUnavailable("perf_event_open ABI is supported only on x86_64 and aarch64")
        # perf_event_attr ABI version 0 is sufficient and works on older kernels.
        attr = bytearray(64)
        struct.pack_into("=IIQ", attr, 0, 0, len(attr), 1)  # HARDWARE / INSTRUCTIONS
        struct.pack_into("=Q", attr, 32, 3)  # TOTAL_TIME_ENABLED | TOTAL_TIME_RUNNING
        flags = (1 << 0) | (1 << 1) | (1 << 5) | (1 << 6) | (1 << 12)
        # disabled, inherit, exclude_kernel, exclude_hv, enable_on_exec
        struct.pack_into("=Q", attr, 40, flags)
        buffer = (ctypes.c_char * len(attr)).from_buffer(attr)
        libc = ctypes.CDLL(None, use_errno=True)
        libc.syscall.restype = ctypes.c_long
        self.fd = libc.syscall(ctypes.c_long(syscall_number), ctypes.byref(buffer),
                               ctypes.c_int(pid), ctypes.c_int(-1), ctypes.c_int(-1),
                               ctypes.c_ulong(8))  # PERF_FLAG_FD_CLOEXEC
        if self.fd < 0:
            code = ctypes.get_errno()
            raise CounterUnavailable(
                f"perf_event_open hardware instructions unavailable: errno={code} "
                f"({os.strerror(code)}). Use a host with an accessible PMU, or explicitly "
                "select --counter-backend=callgrind for a different software metric.")

    def finish(self):
        data = os.read(self.fd, 24)
        if len(data) != 24:
            raise CounterUnavailable("Incomplete perf counter read (event may be unschedulable)")
        count, enabled, running = struct.unpack("=QQQ", data)
        if count <= 0 or enabled <= 0 or running <= 0:
            raise CounterUnavailable("Hardware instruction counter is zero or was never scheduled")
        if enabled != running:
            raise CounterUnavailable(
                f"Hardware instruction event was multiplexed ({running}/{enabled} ns); "
                "scaled estimates are not accepted")
        return {"instructions": count,
                "instruction_metric": "hardware_retired_user_instructions",
                "counter_backend": "linux-perf",
                "counter": "perf_event_open/PERF_COUNT_HW_INSTRUCTIONS",
                "hardware_retired": True,
                "time_enabled_ns": enabled, "time_running_ns": running,
                "aggregate_is_lower_bound": False,
                "includes": "user-space instructions of the launched task and inherited threads/children",
                "excludes": "kernel, hypervisor, GPU execution, and external services",
                "counter_scope": "inherited event enabled at program exec through program completion"}

    def close(self):
        if self.fd >= 0:
            os.close(self.fd)
            self.fd = -1


def _kill_group(pid):
    try:
        os.killpg(pid, signal.SIGKILL)
    except ProcessLookupError:
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def _live_group_members(group):
    members = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdecimal() or int(entry.name) == group:
            continue
        try:
            fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
        except (FileNotFoundError, ProcessLookupError):
            continue
        if int(fields[2]) == group and fields[0] != "Z":
            members.append(int(entry.name))
    return members


def run_perf_command(command, *, cwd, env, log_path, timeout,
                     counter_factory=LinuxPerfInstructions):
    """Gate exec until the parent attaches perf; never omit the startup prefix.

    The measured task is kept as an unreaped zombie until its event has been
    read. A failed exec, nonzero exit, timeout, or remaining child rejects the
    run; every owned process is cleaned up on failure.
    """
    if timeout <= 0:
        raise ValueError("The watchdog must be positive")
    read_gate, write_gate = os.pipe()
    started = time.monotonic()
    with Path(log_path).open("wb") as log:
        pid = os.fork()
        if pid == 0:
            try:
                os.close(write_gate)
                os.setsid()
                os.dup2(log.fileno(), 1)
                os.dup2(log.fileno(), 2)
                if os.read(read_gate, 1) != b"R":
                    os._exit(126)
                os.close(read_gate)
                os.chdir(cwd)
                os.execvpe(command[0], command, env)
            except BaseException as error:
                os.write(2, (f"Measured exec failed: {error}\n").encode())
                os._exit(127)
        os.close(read_gate)
        counter, reaped = None, False
        try:
            counter = counter_factory(pid)
            os.write(write_gate, b"R")
            os.close(write_gate)
            write_gate = -1
            deadline = started + timeout
            while True:
                status = os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                if status is not None:
                    break
                if time.monotonic() >= deadline:
                    raise RuntimeError("Measured executable exceeded the watchdog")
                time.sleep(.01)
            if status.si_code != os.CLD_EXITED or status.si_status != 0:
                raise RuntimeError(f"Measured executable failed: wait code={status.si_code}, "
                                   f"status={status.si_status}; see {log_path}")
            members = _live_group_members(pid)
            if members:
                raise RuntimeError(f"Measured executable left running children {members}; "
                                   "the process-exit endpoint is incomplete")
            report = counter.finish()
            _, wait_status, usage = os.wait4(pid, 0)
            reaped = True
            report.update(pid=pid, exit=os.waitstatus_to_exitcode(wait_status),
                          root_final_exit_sample=True,
                          root_instructions=None,
                          root_lifetime_max_phys_footprint=None,
                          peak_rss_bytes=usage.ru_maxrss * 1024,
                          missing_final_sample_count=0,
                          command=list(command),
                          process_launch_to_capture_observed_ms=(time.monotonic() - started) * 1000)
            return report
        finally:
            if write_gate >= 0:
                os.close(write_gate)
            if not reaped:
                _kill_group(pid)
                try:
                    os.waitpid(pid, 0)
                except ChildProcessError:
                    pass
            if counter is not None:
                counter.close()


def parse_callgrind(path, *, expected_pid=None):
    """Read the final Ir total, rejecting partial dumps and ambiguous totals."""
    events, summaries, totals, pids, parts, triggers = [], [], [], [], [], []
    with Path(path).open(encoding="utf-8", errors="strict") as source:
        for line in source:
            if line.startswith("events:"):
                events.append(line.partition(":")[2].split())
            elif line.startswith("summary:"):
                summaries.append(line.partition(":")[2].split())
            elif line.startswith("totals:"):
                totals.append(line.partition(":")[2].split())
            elif line.startswith("pid:"):
                pids.append(int(line.partition(":")[2]))
            elif line.startswith("part:"):
                parts.append(line.partition(":")[2].strip())
            elif line.startswith("desc: Trigger:"):
                triggers.append(line[len("desc: Trigger:"):].strip())
    # A live dump resets Callgrind's segment counters. A later successful
    # process exit does not turn its last segment into a whole-run total.
    if parts != ["1"] or triggers != ["Program termination"]:
        raise RuntimeError(f"Callgrind output is not one complete undumped run: {path}")
    if len(events) != 1 or "Ir" not in events[0] or len(set(events[0])) != len(events[0]):
        raise RuntimeError(f"Missing or ambiguous Callgrind Ir event: {path}")
    if expected_pid is not None and pids != [expected_pid]:
        raise RuntimeError(f"Callgrind PID does not match the measured process: {path}")
    if len(totals) != 1 or len(summaries) > 1:
        raise RuntimeError(f"Callgrind output is incomplete or contains multiple dumps: {path}")
    index = events[0].index("Ir")
    try:
        # Missing trailing zero event columns are legal in the Callgrind format.
        count = int(totals[0][index])
        summary = int(summaries[0][index]) if summaries else count
    except (IndexError, ValueError) as error:
        raise RuntimeError(f"Invalid Callgrind Ir total: {path}") from error
    if count <= 0 or summary != count:
        raise RuntimeError(f"Zero or inconsistent Callgrind Ir totals: {path}")
    return count


def parse_cachegrind(path):
    """Validate an Ir-only profile's final footer against its flat cost rows.

    Cachegrind has no PID or termination-trigger field. The caller must select
    the launched root PID's file after verifying successful process exit; a
    terminated process can also leave an internally consistent profile.
    """
    events, summary, row_sum, row_count = [], None, 0, 0
    with Path(path).open(encoding="utf-8", errors="strict") as source:
        for raw in source:
            line = raw.strip()
            if not line:
                continue
            if summary is not None:
                raise RuntimeError(f"Data after the final Cachegrind summary: {path}")
            if line.startswith("events:"):
                events.append(line.partition(":")[2].split())
            elif line.startswith("summary:"):
                fields = line.partition(":")[2].split()
                if len(fields) != 1 or not fields[0].isdigit():
                    raise RuntimeError(f"Invalid Cachegrind Ir summary: {path}")
                summary = int(fields[0])
            elif line.startswith(("cmd:", "desc:", "fl=", "fn=")):
                continue
            else:
                fields = line.split()
                if (events != [["Ir"]] or len(fields) not in (1, 2)
                        or not re.fullmatch(r"(?:[0-9]+|[+-][0-9]+|\*)", fields[0])
                        or (len(fields) == 2 and not fields[1].isdigit())):
                    raise RuntimeError(f"Invalid or ambiguous Cachegrind cost row: {path}")
                # Missing trailing zero event columns are legal.
                row_sum += int(fields[1]) if len(fields) == 2 else 0
                row_count += 1
    if events != [["Ir"]] or not row_count or summary is None or summary <= 0 or row_sum != summary:
        raise RuntimeError(f"Incomplete, zero, or inconsistent Cachegrind Ir profile: {path}")
    return summary


def run_callgrind_command(command, *, cwd, env, log_path, timeout, prefix, valgrind="valgrind"):
    return _run_valgrind_command(command, cwd=cwd, env=env, log_path=log_path, timeout=timeout,
                                 prefix=prefix, valgrind=valgrind, tool="callgrind")


def run_cachegrind_command(command, *, cwd, env, log_path, timeout, prefix, valgrind="valgrind"):
    return _run_valgrind_command(command, cwd=cwd, env=env, log_path=log_path, timeout=timeout,
                                 prefix=prefix, valgrind=valgrind, tool="cachegrind")


def _run_valgrind_command(command, *, cwd, env, log_path, timeout, prefix, valgrind, tool):
    if tool not in ("callgrind", "cachegrind"):
        raise ValueError("An explicit supported Valgrind instruction tool is required")
    display = tool.capitalize()
    executable = shutil.which(str(valgrind))
    if executable is None:
        raise CounterUnavailable(f"{display} was explicitly selected, but {valgrind!s} is unavailable")
    executable = Path(executable).resolve()
    before = hashlib.sha256(executable.read_bytes()).hexdigest()
    # Pin the standard launcher and installed engine as well as the wrapper.
    # VALGRIND_LIB, when supplied, is the actual explicit engine destination.
    arch = {"x86_64": "amd64", "aarch64": "arm64"}.get(platform.machine(), platform.machine())
    library_dirs = ([Path(env["VALGRIND_LIB"])] if env.get("VALGRIND_LIB") else
                    [executable.parent.parent / "libexec/valgrind",
                     executable.parent.parent / "lib/valgrind"])
    inputs = [executable, Path(str(executable) + ".bin")]
    for directory in library_dirs:
        inputs.extend([directory / f"{tool}-{arch}-linux",
                       directory / f"vgpreload_core-{arch}-linux.so"])
    pinned = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
              for path in inputs if path.is_file()}
    version = subprocess.run([str(executable), "--version"], check=True,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.strip()
    output_pattern = str(prefix) + f".{tool}.%p"
    if any(list(Path(prefix).parent.glob(Path(prefix).name + f".{name}.*"))
           for name in ("callgrind", "cachegrind")):
        raise RuntimeError(f"{display} evidence already exists for this prefix; use a new output prefix")
    flags = (["--tool=callgrind", "--trace-children=no", "--separate-threads=no",
              "--cache-sim=no", "--branch-sim=no", "--dump-instr=no",
              "--collect-atstart=yes", "--instr-atstart=yes"] if tool == "callgrind" else
             ["--tool=cachegrind", "--trace-children=no", "--cache-sim=no",
              "--branch-sim=no", "--instr-at-start=yes"])
    instrumented = [str(executable), *flags,
                    "--error-exitcode=97", f"--{tool}-out-file={output_pattern}",
                    f"--log-file={prefix}.valgrind.%p.log", "--", *command]
    started = time.monotonic()
    with Path(log_path).open("wb") as log:
        process = subprocess.Popen(instrumented, cwd=cwd, env=env, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        try:
            # Keep the group leader unreaped while checking and cleaning up its
            # children. poll()/wait() first would release the PID on failure.
            while True:
                status = os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
                if status is not None:
                    break
                if time.monotonic() >= started + timeout:
                    raise RuntimeError(f"{display} executable exceeded the watchdog")
                time.sleep(.01)
            if status.si_code != os.CLD_EXITED or status.si_status != 0:
                raise RuntimeError(f"{display} executable failed (status {status.si_status}); see {log_path} "
                                   f"and {prefix}.valgrind.{process.pid}.log")
            members = _live_group_members(process.pid)
            if members:
                raise RuntimeError(f"{display} executable left running children {members}")
            output = Path(output_pattern.replace("%p", str(process.pid)))
            count = (parse_callgrind(output, expected_pid=process.pid) if tool == "callgrind"
                     else parse_cachegrind(output))
            if any(hashlib.sha256(Path(path).read_bytes()).hexdigest() != digest
                   for path, digest in pinned.items()):
                raise RuntimeError("Valgrind executable or runtime changed during measurement")
            code = process.wait()
        finally:
            if process.returncode is None:
                _kill_group(process.pid)
                process.wait()
    return {"instructions": count, "root_instructions": count,
            "instruction_metric": f"{tool}_guest_instruction_references",
            "counter_backend": tool, "counter": f"Valgrind {display}/Ir",
            "hardware_retired": False, "aggregate_is_lower_bound": True,
            "includes": "instrumented user-space guest instructions in the main process, all threads",
            "excludes": "other processes, kernel, hypervisor, GPU execution, and Valgrind observer code",
            "counter_scope": "main process only; child instruction totals are not added",
            "metric_note": "Software instrumentation metric; not hardware-retired instructions or native latency",
            f"{tool}_output": str(output),
            "valgrind": {"path": str(executable), "sha256": before, "version": version,
                         "runtime_files_sha256": pinned},
            "pid": process.pid, "exit": code, "root_final_exit_sample": True,
            "root_lifetime_max_phys_footprint": None, "missing_final_sample_count": 0,
            "command": instrumented, "browser_command": list(command),
            "process_launch_to_capture_observed_ms": (time.monotonic() - started) * 1000}
