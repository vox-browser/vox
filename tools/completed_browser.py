"""Select and pin an available completed browser without waiting for a build."""
from contextlib import contextmanager
from dataclasses import dataclass
import fcntl
import hashlib
import json
from pathlib import Path
from typing import Optional

from browser_bundle_lease import browser_executable_lease
from build_platform import production_state_dir


@dataclass(frozen=True)
class CompletedBrowser:
    executable: Path
    receipt: Optional[dict]
    staged: bool = False


def read_record(path):
    try:
        record = json.loads(path.read_text())
        return record if isinstance(record, dict) else None
    except (OSError, ValueError):
        return None


def digest(path):
    value = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


@contextmanager
def staged_browser_lease(ready_path, requested=None):
    try:
        handle = (ready_path.parent / 'artifact.lock').open('a')
    except OSError:
        yield None
        return
    with handle as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
        except BlockingIOError:
            yield None
            return
        ready = read_record(ready_path)
        result = read_record(ready_path.parent / 'result.json') or {}
        if (not ready or ready.get('exit') != 0 or result.get('superseded')
                or not ready.get('ready_executable') or result.get('exit', 0) != 0):
            yield None
            return
        executable = Path(ready['ready_executable']).resolve()
        if requested is not None and executable != requested:
            yield None
            return
        expected = ready.get('ready_executable_sha256')
        try:
            available = digest(executable) == expected
        except OSError:
            available = False
        if not available:
            yield None
            return
        try:
            yield CompletedBrowser(executable, ready, staged=True)
        finally:
            try:
                unchanged = digest(executable) == expected
            except OSError:
                unchanged = False
            if not unchanged:
                raise RuntimeError('Completed browser changed during its check')


@contextmanager
def completed_browser_lease(root, executable=None):
    root = Path(root).resolve()
    state = production_state_dir(root)
    latest = read_record(state / 'latest.json') or {}
    requested = Path(executable).resolve() if executable is not None else None
    published = Path(latest['frozen_compilation']).parent.name if latest.get('frozen_compilation') else ''
    for ready_path in sorted((state / 'receipts').glob('*/ready.json'), reverse=True):
        if requested is None and ready_path.parent.name <= published:
            continue
        with staged_browser_lease(ready_path, requested) as selected:
            if selected is not None:
                yield selected
                return
    if requested is not None and any(part.startswith('.production-output-') for part in requested.parts):
        raise RuntimeError('Requested staging browser is no longer available as a completed artifact')
    if requested is None:
        if not latest.get('executable'):
            raise RuntimeError('No completed production browser is available')
        requested = Path(latest['executable']).resolve()
    with browser_executable_lease(requested):
        # Publication can finish between discovery and acquisition of the lease.
        latest = read_record(state / 'latest.json') or {}
        if executable is None:
            if not latest.get('executable'):
                raise RuntimeError('No completed production browser is available')
            requested = Path(latest['executable']).resolve()
        receipt = latest if latest.get('executable') and Path(latest['executable']).resolve() == requested else None
        if receipt and digest(requested) != receipt.get('executable_sha256'):
            raise RuntimeError('Published browser differs from its completed receipt')
        yield CompletedBrowser(requested, receipt)
