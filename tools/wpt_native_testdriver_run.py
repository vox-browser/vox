#!/usr/bin/env python3
"""Run the upstream manifest runner with Vox's optional native test-driver backend.

    VOX_WPT_TESTDRIVER=1 python3 tools/wpt_native_testdriver_run.py [runner args]

This fills the standard testdriver-vendor.js extension point. Test documents,
assertions, testharness.js, selections, deadlines and result accounting remain
those of wpt_upstream_compare.py. Other test-driver operations stay unsupported.
"""
from pathlib import Path
import os
import wpt_upstream_compare as upstream

VENDOR_PATH = Path(__file__).with_name('wpt_testdriver_vendor.js')


class NativeInputManifestServer(upstream.ManifestServer):
    def __init__(self, *args):
        configured = list(args)
        resources = dict(configured[3])
        resources['/resources/testdriver-vendor.js'] = (
            VENDOR_PATH.read_bytes(), 'text/javascript')
        configured[3] = resources
        super().__init__(*configured)


def main():
    if os.environ.get('VOX_WPT_TESTDRIVER') != '1':
        raise SystemExit('Native WPT input requires VOX_WPT_TESTDRIVER=1')
    original = upstream.ManifestServer
    try:
        upstream.ManifestServer = NativeInputManifestServer
        return upstream.main()
    finally:
        upstream.ManifestServer = original


if __name__ == '__main__':
    raise SystemExit(main())
