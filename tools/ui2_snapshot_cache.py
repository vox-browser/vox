"""Bound the UI2 source cache without retiring a live build's inputs."""

from contextlib import contextmanager
import os
from pathlib import Path
import re
import shutil


RETAINED_SNAPSHOTS = 2


def snapshot_cache_path(repo, path=None):
    if path is None:
        base = os.environ.get('XDG_CACHE_HOME') or (
            os.environ.get('LOCALAPPDATA') if os.name == 'nt' else None)
        path = os.environ.get('VOX_UI2_CACHE_DIR') or (
            Path(base or Path.home() / '.cache') / 'vox/ui2-snapshots')
    cache, build = Path(path).expanduser().resolve(), (repo / 'Build').resolve()
    if cache == build or build in cache.parents:
        raise RuntimeError('UI2 source snapshots must be outside Build/; '
                           'set VOX_UI2_CACHE_DIR to an external cache directory')
    return cache


def process_alive(pid):
    if pid <= 0:
        return False
    if os.name == 'nt':
        # os.kill(pid, 0) terminates processes on Windows. Use a query handle.
        import ctypes
        from ctypes import wintypes
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = kernel.OpenProcess(0x100000, False, pid)  # SYNCHRONIZE
        if not handle:
            # Access denied or an unknown failure cannot prove the owner exited.
            return ctypes.get_last_error() != 87  # ERROR_INVALID_PARAMETER
        try:
            return kernel.WaitForSingleObject(handle, 0) != 0
        finally:
            kernel.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


@contextmanager
def snapshot_cache_lock(cache):
    """Serialize publication, lease registration and retirement across processes."""
    cache.mkdir(parents=True, exist_ok=True)
    with (cache / '.lock').open('a+b') as lock:
        if os.name == 'nt':
            import msvcrt
            if lock.tell() == 0:
                lock.write(b'\0')
                lock.flush()
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            if os.name == 'nt':
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(lock, fcntl.LOCK_UN)


def retain_snapshot(cache, stage, owner_pid):
    """Called with the cache lock held before handing a path to its consumer."""
    leases = cache / '.leases' / stage.name
    leases.mkdir(parents=True, exist_ok=True)
    (leases / str(owner_pid)).touch()
    os.utime(stage, None)
    prune_snapshots(cache)


def prune_snapshots(cache):
    """Keep the two most recently used stages plus every live process lease.

    PID reuse can conservatively retain an extra stage until that process exits;
    it can never cause a live consumer's stage to be deleted. Lease metadata is
    outside the verified immutable snapshot. The caller holds the cache lock.
    """
    stages = sorted((path for path in cache.iterdir()
                     if re.fullmatch(r'[0-9a-f]{64}', path.name)
                     and path.is_dir() and not path.is_symlink()),
                    key=lambda path: (path.stat().st_mtime_ns, path.name), reverse=True)
    for index, stage in enumerate(stages):
        leases = cache / '.leases' / stage.name
        active = False
        if leases.exists():
            for lease in leases.iterdir():
                if not lease.name.isdecimal() or process_alive(int(lease.name)):
                    active = True
                else:
                    lease.unlink()
            if not active:
                leases.rmdir()
        if index >= RETAINED_SNAPSHOTS and not active:
            shutil.rmtree(stage)
    # The exclusive lock proves no current preparation owns these leftovers.
    for path in cache.glob('.ui2-*'):
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
