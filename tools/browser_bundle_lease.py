"""Keep the canonical browser fixed while a read-only check uses it."""
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
from build_platform import production_state_dir

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def publication_lease(root, shared=False):
    path = production_state_dir(root) / 'bundle.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    inherited = os.environ.get('VOX_BUNDLE_LEASE_FD')
    if inherited is not None:
        # A comparison controller can lend its exclusive lease to subprocesses
        # while temporarily installing executable outputs in the canonical app.
        # Validate the descriptor and acquire/confirm EX on the SAME open-file
        # description; opening another file here would deadlock its controller.
        fd = int(inherited)
        actual, expected = os.fstat(fd), path.stat()
        if (actual.st_dev, actual.st_ino) != (expected.st_dev, expected.st_ino):
            raise RuntimeError('Inherited browser lease is not the publication lock')
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield fd
        return
    with path.open('a') as file:
        fcntl.flock(file, fcntl.LOCK_SH if shared else fcntl.LOCK_EX)
        try:
            yield file.fileno()
        finally:
            fcntl.flock(file, fcntl.LOCK_UN)


@contextmanager
def canonical_bundle_lease(bundle):
    # Historical bundles have no canonical publisher. Their identity checks
    # still apply; only the shared production bundle needs this read lease.
    if bundle.resolve() != (ROOT / 'Build/v/Vox.app').resolve():
        yield
        return
    with publication_lease(ROOT, shared=True):
        yield
