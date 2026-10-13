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
- Column flex layout now retains its first inside-layout when flexing leaves
  both dimensions unchanged and no descendant consumes the new definite-height
  basis. Grids with only implicit automatic rows can use the same optimization;
  explicit, percentage, flexible, and subgrid rows retain the relayout guard.
- Immutable platform font handles retain their resolved file and decoded face.
  Glyph coverage and bounds no longer repeat file checks and global cache-key
  construction for every character. An unavailable explicit source continues
  to be retried instead of permanently selecting its temporary fallback.
- CSS component text serialization now uses linear builders. Unescaped
  identifier tokens borrow their contiguous filtered-input span; escaped names
  still use the decoder and builder. Optimized forced-GC tests cover a late
  identifier retained after the tokenizer and other tokens have gone away.
- The compact script bridge reads `innerHTML` and `textContent` lazily from
  captured native element identities. Initial state and unchanged snapshots
  no longer serialize every ancestor's complete subtree. Pending script writes
  and CSSOM rule mutations preserve their existing replay behavior.

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

### Chrome comparison and continued optimization

A subsequent native run at a 1024×768 document viewport reduced cached-document
installation from 16.2 seconds to 5.1 seconds after the column-flex, font-handle,
linear serialization, and lazy-content changes. Its script startup took 138 ms
instead of 2209 ms, and its two geometry passes took 1047 ms and 790 ms instead
of 4509 ms and 4083 ms. The process used a peak RSS of about 1.5 GiB.

The final build also includes the grid dependency refinement and identifier
source spans. Its two subsequent document-install measurements were 7.9 and
8.8 seconds. At that point the host load average was about 100 with many
unrelated compiler processes running. The differing phase timings do not
establish a regression or an additional speedup; repeat them on an idle host
before drawing either conclusion.

An isolated, clean-profile Chrome 155.0.8059.40 process loading the live URL
reported first contentful paint at 1516 ms, DOMContentLoaded at 1827 ms, and load
at 2722 ms through the Chrome DevTools Protocol. Its screenshot showed populated
file rows and 72 file/directory links. The Chrome measurement includes a cold
network navigation; the Vox measurements use cached HTML/resources and native
window capture. They are different workloads, and Vox has not reached Chrome
load-speed or functionality parity.

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
The continued optimization tests also cover column/grid percentage bases,
changed flex heights, font-file retention and late availability, large CSS
component serialization, and lazy DOM reads with pending writes and inserted
nodes. Final native comparisons pass for `inline-node`, `ordered-list`,
`text-decorations`, and `svg-image-source-switch-same-size`; the ordered list
and SVG source-switch comparisons are pixel-exact. The earlier lazy-content
build also passes `selection-focus-between-text-controls` exactly.

```sh
sh build-prod-browser.sh
LADYBIRD_DEBUG_TIMING=1 Build/v/Vox.app/Contents/MacOS/Vox https://github.com/vlang/v
```

Use `sample PID 2 5 -file OUTPUT.txt` during a slow phase to inspect the native
stack. Account for cached-page installation and background refresh separately;
a blank upstream headless screenshot is not a valid speed comparison.
