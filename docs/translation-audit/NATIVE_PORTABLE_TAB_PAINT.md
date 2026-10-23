# Native painting for the fallback tab strip

Commit `d6b3f0b3` routes fallback tab polygons through the existing
`draw_browser_polygon()` helper. On macOS with native rendering, that helper
fills the polygon in the supplied Cocoa context. Other renderers retain the
helper's existing GG path. Tab geometry, colors and selection behavior are
unchanged.

The defect appeared in a separate current-source normal-GC browser diagnostic
without UI2. All three native observations aborted before the PNG endpoint:
`draw_portable_browser_tabs()` entered Sokol's polygon path without Sokol
initialization. The raw kernel status was 6 (`SIGABRT`); the LaunchServices
launcher itself exited zero. The assertion, crash stack, partial counters and
all three failed observations remain retained. None receives instruction
credit or is replaced by a later observation.

Two focused tests exercise the actual tab painter in an sRGB Cocoa bitmap
context, without a window or Sokol initialization. All 18 assertions pass:
tab-strip and selected/unselected fills, untouched pixels outside the strip,
selection changes and absent GG pipeline/font state. Current V's new frontend,
Boehm and actual Clang C-O2 are used. The C-only frontend and native compilation
both exit zero under a 12 GiB sampled process-tree guard (observed peak
6,617,071,616 bytes). Runtime exits zero under a separate 3 GiB guard (peak
77,692,928 bytes). These memory values describe sampled guard observations.

The first test fixture read bitmap rows in reverse order and failed both cases
with zero sampled colors. Its failed runtime and build receipts remain
unchanged under `tabpaint-attempt`. A small independent CoreGraphics probe
confirmed the bitmap storage orientation. The corrected fixture uses a new
immutable snapshot and `tabpaint-v2-attempt`; no previously passing case was
replayed. The product fix is identical in both snapshots.

Durable evidence is under
`Build/instructions/normal-sealed-current4-20261023/tabpaint-v2-attempt/`:

- `source-manifest.json`: frozen preceding snapshot plus exactly the three
  implementation/test paths; SHA256
  `3766312a54d89d1dd5494f64ecd43c1a7f2d7f6dffbabc2d1e2e911084039814`.
- `focused-{frontend,native,runtime}-{command,result}.json`, corresponding logs
  and separate `normal-sealed-current4-tabpaint-v2-*-guard.json` reports.
- `focused.c.gz`: generated C SHA256
  `d9c8565b9c7c1bbea17ff86fb3dfb1567065554f588d3f16792b9b1b585229ce`;
  archive SHA256
  `86f67f5a57a0735e6d6ad5fbd95e08de2ebdb52e8ad3e382dc03e963b45766d7`.
- `focused-bin.gz`: decompressed binary SHA256
  `d6eb8d521e071b87430297e22dd2f43baef021ba85ab359f4d0fb3b3e25f1f0d`;
  archive SHA256
  `c9b4f18275dad9fd3aa851db887d07267c3cf96ff2f756deceabc73d955db505`.
- `browser.c.gz`: generated C SHA256
  `abc4e1fc79577b3058d73512719d1f611a8f7d3ce29f157fcc6a2391c0b50299`;
  archive SHA256
  `bf510cd4b8288c718f6a379af544097af219fe28777e2451bb65e5102ab6f447`.

The isolated browser's full frontend, native compile, signing, signature
verification and startup all exit zero. GC policy checks perform actual
collections with default marker 1 and override 2. A separately declared fixed
three-pair sealed-page cohort completes all six browser kernel exits and
launch exits with zero, six exact-size PNGs and all strict content gates.
The retained audit exits zero; it checks all 7,061 source pins, 417 runtime
pins, exact source scope, native dispatch in both generated programs, actual
assertions/statuses, PNG hashes and recomputed instruction counters. No
completed observation is replayed or pooled with an earlier attempt.

A separately declared stack-profile diagnostic attaches to actual browser PID
9028 after executable-path and exclusive coalition checks. The browser exits
zero and passes the content gates; `/usr/bin/sample` also exits zero, but its
report contains no call-graph entries. The profiler correctly exits one. Its
original report, launch log and failure receipt are retained under
`sampled-stacks/`; `failed-evidence.json` authenticates them without changing
their status. There is no usable hotspot evidence and no instruction credit
from this diagnostic; it does not extend the completed comparison cohort.

A single CPU-active control confirms that this system can collect sampled
stacks. A newly declared two-second profile defers symbol reading by omitting
`-mayDie`. It captures actual Vox stacks on verified browser PID 35554;
sampler, browser, content gates, controller and guard all pass. The raw report
is retained in `sampled-stacks-deferred-symbols/`, SHA256
`ab6d2c3272c125b20a21754b1354d1cf798dac51128aa2b93e29ff699791416c`.
It covers a short early interval, including style, matching, layout and GC,
and earns no instruction credit. The earlier empty profile is not replaced.

This is the third owned non-performance fix since the preceding broad-test
checkpoint, following `51421166` and `f90ccbe2`. No broad suite is triggered.
There is zero instruction-count credit: accepted control 179, broad baseline
179 and observed carry zero remain unchanged. The separate browser diagnostic
is documented in `docs/GITHUB_PERFORMANCE.md`; it does not establish default
UI2 browser coverage, unrelated snapshot behavior or unconditional Chrome
parity. The canonical app, user GUI browser and concurrent work are preserved.
