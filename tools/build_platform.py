"""Platform-owned build state for a checkout shared with a Linux VM."""
import sys


def production_state_dir(root):
    # Keep the established macOS receipt and lease paths. Linux has separate
    # queues, compiler locks and receipts beside its executable and archives.
    return root / ('Build/linux/production-build' if sys.platform == 'linux'
                   else 'Build/production-build')
