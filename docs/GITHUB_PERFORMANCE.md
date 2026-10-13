# GitHub rendering investigation

Measured on macOS on 2026-10-13 with `https://github.com/vlang/v` and the
repository's native browser. These are individual diagnostic runs, not an
upstream parity benchmark.

## Causes and changes

- The V 0.5.2 compatibility compiler's `-prod` Boehm code repeatedly snapshots
  nested pointers in live aggregates. Tokenization walks the growing token
  array around calls, turning large stylesheet parsing into quadratic work.
  The browser builder now uses `-gc boehm_full` and C `-O2` without `-prod`.
  Full heap scanning retains nested token strings without these snapshots.
- Block layout measured automatic-height flex subtrees before running their
  actual flex layout. Ordinary horizontal flex containers now resolve their
  own height during that run. Buttons, vertical writing modes, and percentage
  row gaps retain their required preliminary measurement.
- Intrinsic and minimum-height probes allocated individual geometry records
  that survived until collection. These scalar-returning probes now allocate
  `UsedValues` in stable arena chunks and release their owned records and page
  containers when the probe ends. Shared line boxes and rare data keep their
  existing heap ownership; committed layout does not use this temporary arena.
- Recomputed unchanged styles rebuilt font cascades containing pending faces.
  Upstream's pending-cascade equality intentionally returns false, so each
  recomputation invalidated layout. Vox now preserves cascade identity when
  all font inputs, the owning font computer, and its environment generation
  match. Font loading and changes to font properties still invalidate it.
- Document script execution parsed entire ECMAScript modules before rejecting
  their unsupported execution. Execution now checks that capability before
  parsing. The explicit `prepare_script()` API still parses module ASTs and
  reports syntax errors.
- Native navigation constructs an active document without session-history
  traversal. It now grants script readiness before parsing, allowing GitHub's
  import map to run without the script-readiness assertion.

## Observed timings

The native timing log separates processing phases from network fetches and
the screenshot settle delay.

| Phase | Earlier run | Updated run |
| --- | ---: | ---: |
| External stylesheet installation | 78.2 s | 2.0 s |
| Document script startup | 8.2 s | 2.0 s |
| Geometry per initial stabilization pass | about 6–7 s | about 3–4 s |

The updated cached-document install took 14.5 seconds. A subsequent network
refresh returned different HTML and caused another document install lasting
20.6 seconds; the screenshot process exited after 40.7 seconds including both
installs and capture. These values must not be described as a single first
paint time. The repeated geometry passes triggered by unchanged pending-font
styles no longer occur after installation.

GitHub's file rows still show loading placeholders because this browser
JavaScript backend does not implement module execution/linking. Avoiding their
unnecessary parsing does not add module support or full LibJS parity. Equal
rendering speed and functionality with upstream Ladybird have not been
established.

## Allocation policy

Upstream Ladybird uses its tracing `LibGC` collector for DOM and JavaScript
objects alongside reference counting and layout arenas. Vox retains Boehm GC
for live and shared V object graphs. Its scoped measurement arena is an
ownership optimization, not a switch to a globally uncollected heap.
`LADYBIRD_V_GC=none` remains available for ownership diagnostics.

## Validation and reproduction

Focused tests cover forced-GC token retention, arena pointer stability and
release with both `boehm_full` and `none`, flex sizing, pending-font cache
invalidation, import-map navigation, and module rejection followed by classic
script execution. The signed native bundle passes `--headless-smoke`.

```sh
sh build-prod-browser.sh
LADYBIRD_DEBUG_TIMING=1 Build/v/Vox.app/Contents/MacOS/Vox https://github.com/vlang/v
```

Use `sample PID 2 5 -file OUTPUT.txt` during a slow phase to inspect the native
stack. Account for cached-page installation and background refresh separately;
a blank upstream headless screenshot is not a valid speed comparison.
