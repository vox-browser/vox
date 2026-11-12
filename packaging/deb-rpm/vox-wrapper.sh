#!/bin/sh
# /usr/bin/vox wrapper: the real browser and its bundled native libraries
# live together in /usr/lib/vox (the same relative layout as the portable
# tarball). Keep them co-located for $ORIGIN lookup and export the directory
# for loader paths that need it, then exec the real binary.
set -eu
export LD_LIBRARY_PATH="/usr/lib/vox${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec /usr/lib/vox/vox "$@"
