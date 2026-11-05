"""Keep the canonical browser fixed while a read-only check uses it."""
from contextlib import contextmanager
import fcntl
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@contextmanager
def publication_lease(root, shared=False):
    path = root / 'Build/production-build/bundle.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a') as file:
        fcntl.flock(file, fcntl.LOCK_SH if shared else fcntl.LOCK_EX)
        try:
            yield
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
