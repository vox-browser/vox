"""Read macOS resource-coalition retired instructions, including exited tasks.

This optional private ABI is separate from the existing process-tree counter.
An inherited CLI coalition can contain unrelated work. Callers must establish
exclusive browser membership and matching navigation/content boundaries before
using its deltas for comparisons. GPU and external-service work are excluded.

ABI reference: apple-oss-distributions/xnu, commit
f6217f891ac0bb64f3d375211650a4c1ff8ca1ea, osfmk/mach/coalition.h,
bsd/sys/proc_info.h and bsd/kern/sys_coalition.c. Only the prefix through cycles
is requested; the kernel copies the smaller of its structure and this buffer.
"""
from __future__ import annotations

from collections import deque
import ctypes
import ctypes.util
from dataclasses import dataclass
import os
import sys
import threading
import time


class ResourceUsagePrefix(ctypes.Structure):
    _fields_ = [
        ("tasks_started", ctypes.c_uint64),
        ("tasks_exited", ctypes.c_uint64),
        ("_before_qos", ctypes.c_uint64 * 21),
        ("cpu_time_eqos_len", ctypes.c_uint64),
        ("cpu_time_eqos", ctypes.c_uint64 * 7),
        ("cpu_instructions", ctypes.c_uint64),
        ("cpu_cycles", ctypes.c_uint64),
    ]


@dataclass(frozen=True)
class CoalitionReading:
    coalition_id: int
    instructions: int
    cycles: int
    tasks_started: int
    tasks_exited: int
    sample_started: float
    sample_completed: float


def instruction_delta(before, after):
    """Subtract one coalition's snapshots without losing dead-task rollup.

    Task counts are cumulative, so completed startup tasks cancel in the delta.
    A successfully read group counter alone does not establish its exclusivity.
    """
    if before.coalition_id != after.coalition_id:
        raise ValueError("Cannot combine different resource coalitions")
    if not (before.sample_started <= before.sample_completed <=
            after.sample_started <= after.sample_completed):
        raise ValueError("Coalition sampling intervals overlap or are reversed")
    for reading in [before, after]:
        if not 0 <= reading.tasks_exited <= reading.tasks_started:
            raise ValueError("Invalid coalition task totals")
    names = ["instructions", "cycles", "tasks_started", "tasks_exited"]
    values = {name: getattr(after, name) - getattr(before, name) for name in names}
    if any(value < 0 for value in values.values()):
        raise ValueError("Resource coalition counters decreased")
    return dict(values, coalition_id=before.coalition_id,
                baseline_sample_completed=before.sample_completed,
                endpoint_sample_completed=after.sample_completed)


class MacCoalitionCounters:
    def __init__(self):
        if sys.platform != "darwin":
            raise RuntimeError("Resource coalition counters require macOS")
        self.lib = ctypes.CDLL(ctypes.util.find_library("System"), use_errno=True)
        try:
            self.pidinfo = self.lib.proc_pidinfo
            self.usage = self.lib.coalition_info_resource_usage
        except AttributeError as error:
            raise RuntimeError("This system lacks the resource coalition ABI") from error
        self.pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64,
                                 ctypes.c_void_p, ctypes.c_int]
        self.pidinfo.restype = ctypes.c_int
        self.usage.argtypes = [ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t]
        self.usage.restype = ctypes.c_int

    def resource_coalition(self, pid):
        if pid <= 0:
            raise ValueError("PID must be positive")
        # PROC_PIDCOALITIONINFO: two coalition IDs and three reserved words.
        ids = (ctypes.c_uint64 * 5)()
        ctypes.set_errno(0)
        size = self.pidinfo(pid, 20, 0, ctypes.byref(ids), ctypes.sizeof(ids))
        if size <= 0:
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code), str(pid))
        if size != ctypes.sizeof(ids) or not ids[0]:
            raise RuntimeError("Unexpected process coalition ABI or missing resource ID")
        return ids[0]

    def read(self, coalition_id):
        if coalition_id <= 0:
            raise ValueError("Coalition ID must be positive")
        usage = ResourceUsagePrefix()
        started = time.monotonic()
        ctypes.set_errno(0)
        status = self.usage(coalition_id, ctypes.byref(usage), ctypes.sizeof(usage))
        completed = time.monotonic()
        if status != 0:
            code = ctypes.get_errno()
            raise OSError(code, os.strerror(code), str(coalition_id))
        if usage.cpu_time_eqos_len != 7 or not usage.cpu_instructions:
            raise RuntimeError("Unsupported resource coalition instruction counters")
        if usage.tasks_exited > usage.tasks_started:
            raise RuntimeError("Invalid resource coalition task totals")
        return CoalitionReading(coalition_id, usage.cpu_instructions,
                                usage.cpu_cycles, usage.tasks_started,
                                usage.tasks_exited, started, completed)


class CoalitionCounter:
    """Retain completed reads for a conservative external endpoint boundary.

    A sample completing after the boundary is never selected. The selected
    counter may precede that boundary; callers must disclose that uncertainty.
    This class can be sampled by process_instruction_counts.CounterSampler.
    """
    def __init__(self, api, coalition_id, history=100000):
        if coalition_id <= 0 or history <= 0:
            raise ValueError("Coalition ID and history length must be positive")
        self.api = api
        self.coalition_id = coalition_id
        self.snapshots = deque(maxlen=history)
        self.lock = threading.Lock()

    def sample(self):
        with self.lock:
            reading = self.api.read(self.coalition_id)
            if reading.coalition_id != self.coalition_id:
                raise ValueError("Resource coalition changed")
            if self.snapshots:
                instruction_delta(self.snapshots[-1], reading)
            self.snapshots.append(reading)
            return reading

    def snapshot_before(self, endpoint):
        with self.lock:
            for reading in reversed(self.snapshots):
                if reading.sample_completed <= endpoint:
                    return reading
        raise RuntimeError("No retained coalition sample precedes the endpoint")
