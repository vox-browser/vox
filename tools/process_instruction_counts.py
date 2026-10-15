"""macOS retired CPU instructions, using the public libproc rusage V4 ABI.

Counts include each process's threads, including system execution charged to
them. Children are separate tasks and must be accumulated explicitly.
"""
from __future__ import annotations

import ctypes
from collections import deque
from dataclasses import dataclass
import errno
import os
import sys
import threading
import time


class RusageInfoV4(ctypes.Structure):
    _fields_ = [("ri_uuid", ctypes.c_ubyte * 16)] + [
        ("ri_" + name, ctypes.c_uint64) for name in (
            "user_time system_time pkg_idle_wkups interrupt_wkups pageins "
            "wired_size resident_size phys_footprint proc_start_abstime proc_exit_abstime "
            "child_user_time child_system_time child_pkg_idle_wkups child_interrupt_wkups "
            "child_pageins child_elapsed_abstime diskio_bytesread diskio_byteswritten "
            "cpu_time_qos_default cpu_time_qos_maintenance cpu_time_qos_background "
            "cpu_time_qos_utility cpu_time_qos_legacy cpu_time_qos_user_initiated "
            "cpu_time_qos_user_interactive billed_system_time serviced_system_time "
            "logical_writes lifetime_max_phys_footprint instructions cycles billed_energy "
            "serviced_energy interval_max_phys_footprint runnable_time"
        ).split()
    ]


@dataclass(frozen=True)
class Reading:
    pid: int
    start: int
    exited: bool
    instructions: int
    cycles: int
    peak_physical_footprint: int = 0

    @property
    def identity(self):
        # ri_uuid identifies an executable, not an individual process.
        return self.pid, self.start


@dataclass(frozen=True)
class CounterSnapshot:
    sampled_at: float
    readings: dict
    paths: dict
    missing_final: frozenset
    denied: dict
    root_identity: tuple | None
    peak_footprints: dict


class MacCounters:
    def __init__(self):
        if sys.platform != "darwin":
            raise RuntimeError("Retired-instruction measurement requires macOS")
        self.lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.lib.proc_pid_rusage.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_void_p]
        self.lib.proc_pid_rusage.restype = ctypes.c_int
        self.lib.proc_listchildpids.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_listchildpids.restype = ctypes.c_int
        self.lib.proc_pidpath.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
        self.lib.proc_pidpath.restype = ctypes.c_int
        if self.read(os.getpid()).instructions == 0:
            raise RuntimeError("This kernel does not expose retired-instruction counters")

    def read(self, pid):
        usage = RusageInfoV4()
        if self.lib.proc_pid_rusage(pid, 4, ctypes.byref(usage)) != 0:
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code), str(pid))
        return Reading(pid, usage.ri_proc_start_abstime, usage.ri_proc_exit_abstime != 0,
                       usage.ri_instructions, usage.ri_cycles,
                       max(usage.ri_lifetime_max_phys_footprint, usage.ri_phys_footprint))

    def children(self, pid):
        capacity = 32
        while True:
            buffer = (ctypes.c_int * capacity)()
            count = self.lib.proc_listchildpids(pid, buffer, ctypes.sizeof(buffer))
            if count < 0:
                code = ctypes.get_errno()
                raise OSError(code, os.strerror(code), str(pid))
            if count < capacity:
                return [p for p in buffer[:count] if p > 0]
            capacity *= 2

    def path(self, pid):
        buffer = ctypes.create_string_buffer(4096)
        if self.lib.proc_pidpath(pid, buffer, len(buffer)) <= 0:
            return f"pid:{pid}"
        return os.fsdecode(buffer.value)


class ProcessTreeCounter:
    """Keep exited samples and distinguish a reused PID from its old task.

    A polled descendant tree can miss a child that starts and exits between
    observations. Aggregate results explicitly retain that coverage limitation.
    The directly launched root can be read as a zombie before wait() reaps it.
    """
    def __init__(self, api, root_pid):
        self.api = api
        self.root_pid = root_pid
        self.root_identity = None
        self.records = {}
        self.paths = {}
        self.missing_final = set()
        self.peak_footprints = {}
        self.denied = {}
        self.lock = threading.Lock()
        # Retain recent completed passes so a CDP screenshot boundary can use
        # only readings taken before its response, never later idle/shutdown
        # work. This is observer memory and does not enter browser counters.
        self.snapshots = deque(maxlen=1024)

    def sample(self):
        with self.lock:
            pending = [self.root_pid] + [r.pid for r in self.records.values() if not r.exited]
            visited = set()
            while pending:
                pid = pending.pop()
                if pid in visited:
                    continue
                visited.add(pid)
                try:
                    reading = self.api.read(pid)
                except OSError as error:
                    previous = [key for key, r in self.records.items() if r.pid == pid and not r.exited]
                    self.missing_final.update(previous)
                    if error.errno not in (errno.ESRCH, errno.ENOENT):
                        self.denied[pid] = error.errno
                    continue
                known_pid = [key for key in self.records if key[0] == pid]
                if known_pid and reading.identity not in known_pid:
                    # The old task has gone; do not count an unrelated new task
                    # which happens to have reused a tracked child's PID.
                    self.missing_final.update(known_pid)
                    continue
                if pid == self.root_pid:
                    self.root_identity = reading.identity
                self.records[reading.identity] = reading
                self.peak_footprints[reading.identity] = max(
                    self.peak_footprints.get(reading.identity, 0), reading.peak_physical_footprint)
                if reading.identity not in self.paths:
                    self.paths[reading.identity] = self.api.path(pid)
                if reading.exited:
                    self.missing_final.discard(reading.identity)
                else:
                    pending.extend(self.api.children(pid))
            self.snapshots.append(CounterSnapshot(
                time.monotonic(), dict(self.records), dict(self.paths),
                frozenset(self.missing_final), dict(self.denied),
                self.root_identity, dict(self.peak_footprints)))
            return dict(self.records)

    def snapshot_before(self, endpoint):
        """Last complete sampling pass no later than a monotonic endpoint.

        A pass after the endpoint is deliberately excluded even if individual
        tasks were sampled earlier. The resulting omission is conservative.
        """
        with self.lock:
            for snapshot in reversed(self.snapshots):
                if snapshot.sampled_at <= endpoint:
                    return snapshot
        raise RuntimeError("No retained instruction sample precedes the requested endpoint")

    def report(self, baseline=None, snapshot=None):
        if snapshot is None:
            self.sample()
            with self.lock:
                snapshot = self.snapshots[-1]
        readings = snapshot.readings
        baseline = baseline or {}
        paths = snapshot.paths
        missing_final = snapshot.missing_final
        denied = snapshot.denied
        root_identity = snapshot.root_identity
        peak_footprints = snapshot.peak_footprints
        processes = []
        for key, reading in sorted(readings.items()):
            old = baseline.get(key)
            instructions = reading.instructions - (old.instructions if old else 0)
            cycles = reading.cycles - (old.cycles if old else 0)
            if instructions < 0 or cycles < 0:
                raise RuntimeError(f"Hardware counters decreased for PID {reading.pid}")
            processes.append({"pid": reading.pid, "start_ticks": reading.start,
                              "executable": paths[key], "instructions": instructions,
                              "cycles": cycles, "final_exit_sample": reading.exited,
                              "lifetime_max_phys_footprint": peak_footprints.get(key) or None,
                              "missing_final_sample": key in missing_final})
        root = readings.get(root_identity)
        root_before = baseline.get(root_identity)
        return {"instructions": sum(p["instructions"] for p in processes),
                "root_instructions": (root.instructions - (root_before.instructions if root_before else 0)) if root else None,
                "root_final_exit_sample": root.exited if root else False,
                # Per-process peaks occur at different times; do not sum them.
                "root_lifetime_max_phys_footprint": peak_footprints.get(root_identity) or None,
                "aggregate_is_lower_bound": True,
                "missing_final_sample_count": sum(p["missing_final_sample"] for p in processes),
                "processes": processes, "unreadable_pids": denied,
                "sample_completed_monotonic": snapshot.sampled_at,
                "descendant_coverage": "observed descendants; short-lived unsampled children may be omitted",
                "counter": "proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions",
                "includes": "CPU instructions in all observed process threads and their charged kernel execution",
                "excludes": "GPU execution and external services such as WindowServer"}


class CounterSampler:
    def __init__(self, counter, interval=.02):
        if interval <= 0:
            raise ValueError("Counter sampling interval must be positive")
        self.counter = counter
        self.interval = interval
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.error = None

    def run(self):
        try:
            while not self.stop_event.is_set():
                self.counter.sample()
                self.stop_event.wait(self.interval)
        except Exception as error:
            self.error = error

    def __enter__(self):
        self.counter.sample()
        self.thread.start()
        return self

    def __exit__(self, *exc):
        self.stop_event.set()
        self.thread.join()
        if self.error is not None and not exc[0]:
            raise self.error
