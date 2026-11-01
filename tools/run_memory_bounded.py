#!/usr/bin/env python3
"""Serialize a build/test command and stop its process tree on excess RSS.

Usage: python3 tools/run_memory_bounded.py --report Build/job.json -- COMMAND ...
The budget is sampled aggregate RSS, including compiler subprocesses, rather
than a kernel allocation limit. Shared pages may be counted more than once.
"""
import argparse
import fcntl
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time


def process_snapshot():
    output = subprocess.check_output(
        ['ps', '-axo', 'pid=,ppid=,pgid=,rss=,stat=,lstart='], text=True)
    result = {}
    for line in output.splitlines():
        pid, parent, group, rss, status, started = line.split(None, 5)
        if not status.startswith('Z'):
            result[int(pid)] = (int(parent), int(group), int(rss) * 1024, started)
    return result


def read_adopted_processes(path):
    if path is None or not path.exists():
        return {}
    records = json.loads(path.read_text())
    if not isinstance(records, list):
        raise ValueError('Adopted process registry must be a list')
    result = {}
    for row in records:
        if (not isinstance(row, dict) or type(row.get('pid')) is not int
                or row['pid'] <= 1 or row['pid'] == os.getpid()
                or not isinstance(row.get('started'), str) or not row['started'].strip()):
            raise ValueError('Invalid adopted process identity')
        result[row['pid']] = row['started']
    return result


def publish_adopted_processes(path, pids):
    """Explicitly register a job's reparented processes, with PID reuse checks.

    The job owns this private registry. Publish atomically so the guard never
    sees a partly written JSON document. Missing/exited PIDs are not adopted.
    """
    path = Path(path)
    records = read_adopted_processes(path)
    snapshot = process_snapshot()
    for pid in pids:
        if type(pid) is not int or pid <= 1 or pid == os.getpid():
            raise ValueError('Invalid adopted PID')
        if pid in snapshot:
            records[pid] = snapshot[pid][3]
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as file:
        json.dump([dict(pid=pid, started=started) for pid, started in sorted(records.items())], file)
        temporary = Path(file.name)
    temporary.replace(path)


def job_processes(snapshot, root, previous, adopted=None):
    # Remember detached children across reparenting, with creation times to
    # avoid signalling a recycled PID. Also include the command's process group.
    owned = {pid for pid, row in snapshot.items()
             if row[1] == root or previous.get(pid) == row[3]}
    owned.update(pid for pid, started in (adopted or {}).items()
                 if pid in snapshot and snapshot[pid][3] == started)
    if root in snapshot:
        owned.add(root)
    while True:
        added = {pid for pid, row in snapshot.items() if row[0] in owned} - owned
        if not added:
            return {pid: snapshot[pid][3] for pid in owned}
        owned.update(added)


def stop_job(process, owned):
    # Kill the original group as well as observed descendants which created
    # another session. SIGKILL prevents a compiler continuing after the guard.
    snapshot = process_snapshot()
    killed_root = False
    for pid, started in owned.items():
        if pid in snapshot and snapshot[pid][3] == started:
            try:
                os.kill(pid, signal.SIGKILL)
                killed_root |= pid == process.pid
            except ProcessLookupError:
                pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    except PermissionError as error:
        # macOS can retain an exited child's process group after the last
        # owned task has gone. Preserve its real exit instead of losing the
        # receipt to a cleanup error. An active owned task still fails closed.
        # A successful SIGKILL is asynchronous. Reap the verified root before
        # deciding that this is still an active, inaccessible process group.
        if process.poll() is None and killed_root:
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                raise error
        if process.poll() is None:
            raise
        remaining = process_snapshot()
        if any(pid in remaining and remaining[pid][3] == started
               for pid, started in owned.items()):
            raise
    process.wait()


def run(command, limit_bytes, timeout, interval, adopt_path=None):
    start = time.monotonic()
    process = subprocess.Popen(command, start_new_session=True)
    owned = {}
    peak = 0
    reason = 'completed'
    adopted_seen = {}
    adoption_error = None
    try:
        while True:
            snapshot = process_snapshot()
            try:
                adopted = read_adopted_processes(adopt_path)
            except (OSError, ValueError) as error:
                reason, adoption_error = 'adoption_error', str(error)
                break
            adopted_seen.update({pid: started for pid, started in adopted.items()
                                 if pid in snapshot and snapshot[pid][3] == started})
            owned = job_processes(snapshot, process.pid, owned, adopted)
            peak = max(peak, sum(snapshot[pid][2] for pid in owned))
            if peak > limit_bytes:
                reason = 'memory_limit'
                break
            if time.monotonic() - start > timeout:
                reason = 'timeout'
                break
            if process.poll() is not None:
                # A launcher exiting must not leave a compiler/test running.
                snapshot = process_snapshot()
                owned = job_processes(snapshot, process.pid, owned, adopted)
                owned.pop(process.pid, None)
                if owned:
                    reason = 'remaining_children'
                break
            time.sleep(interval)
    finally:
        stop_job(process, owned)
    return dict(command=command, reason=reason, child_exit_code=process.returncode,
                adopted_processes=adopted_seen, adoption_error=adoption_error,
                limit_bytes=limit_bytes, observed_peak_rss_bytes=peak,
                elapsed_seconds=time.monotonic() - start,
                metric='sampled sum of process-tree RSS; shared pages may be counted twice')


def positive(value):
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError('must be finite and positive')
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--limit-gib', type=positive, default=12)
    parser.add_argument('--timeout', type=positive, default=1800)
    parser.add_argument('--interval', type=positive, default=.1)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--adopt-pids-from', type=Path,
                        help='Private atomic PID/start registry for reparented job processes')
    parser.add_argument('--lock', type=Path,
                        default=Path(__file__).resolve().parent.parent / 'Build/.memory-bounded.lock')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('supply a command after --')
    args.lock.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    # Never overwrite evidence or silently launch a second expensive job.
    with args.report.open('x') as report, args.lock.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            result = dict(reason='busy', command=command)
        else:
            result = run(command, int(args.limit_gib * 1024 ** 3), args.timeout, args.interval,
                         args.adopt_pids_from)
        report.write(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result), file=sys.stderr)
    if result['reason'] != 'completed':
        return 125
    code = result['child_exit_code']
    return code if code >= 0 else 128 - code


if __name__ == '__main__':
    raise SystemExit(main())
