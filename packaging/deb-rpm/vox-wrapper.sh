#!/bin/sh
# /usr/bin/vox wrapper: the real browser and its bundled native libraries
# live together in ../lib/vox relative to this wrapper (the same relative
# layout as the portable tarball). Resolve the payload relative to the
# wrapper itself so the same file works installed as /usr/bin/vox and when
# smoke-testing an extracted package tree (e.g. ./deb-root/usr/bin/vox).
# Keep them co-located for $ORIGIN lookup and export the directory
# for loader paths that need it, then exec the real binary.
set -eu
script="$0"
if command -v readlink >/dev/null 2>&1; then
  resolved="$(readlink -f "$script" 2>/dev/null || printf '%s' "$script")"
  script="$resolved"
fi
bindir="$(CDPATH= cd -- "$(dirname -- "$script")" && pwd)"
libdir="$bindir/../lib/vox"
if command -v readlink >/dev/null 2>&1; then
  libdir="$(readlink -f "$libdir" 2>/dev/null || printf '%s' "$libdir")"
else
  libdir="$(CDPATH= cd -- "$libdir" && pwd)"
fi
export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$libdir/vox" "$@"
