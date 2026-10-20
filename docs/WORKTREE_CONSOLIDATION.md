# Master-only development and worktree consolidation

All development happens directly on `master` in `/Users/alex/code/vox2`.
The development-branch rule in `AGENTS.md` requires serialized edits and focused,
linear commits in that checkout.

The 2026-10-20 consolidation audited 301 additional worktrees at 195 distinct
commits. Twenty-eight heads diverged from the original master, containing 1,173
commits outside its ancestry. Patch equivalence, final source contents and
uncommitted changes were compared before integration. Existing master behavior
was retained where it superseded intermediate experiments and fixtures.

Recovered changes include callback ownership and shared image fetch hooks,
current-V borrowing of layout and paint records, conservative tag/attribute
query history, inherited-property iteration, prepared-layout geometry reset,
atomic inline wrapping, lazy compact DOM state, universal browser Chromium
policies, clipped GPU gradients, shared SVG root recordings and Dawn, and
HTTP/2 idle-reader wakeups. Each implementation is committed with its focused
regressions where applicable. Generated test concatenations reuse 4,152 test
functions whose maintained originals remain in the repository. A separate
running Claude session recreated `vox2-pre` during cleanup; its later snapshots
are preserved alongside the original audit.

## Diagnostics

The canonical build script retains the useful experimental switches:

| Setting | Effect |
| --- | --- |
| `VOX_PHASE_DIAGNOSTICS=1` | Print phase allocation measurements in prealloc builds. |
| `VOX_CSS_DIAGNOSTICS=1` | Collect and report CSS instruction and invalidation counters. |
| `VOX_DOCUMENT_RETENTION_DIAGNOSTICS=1` | Enable experimental document teardown tracing and navigation retention probes. |
| `VOX_KEEP_C=1` | Retain the generated C compilation output. |
| `VOX_PRIVATE_GRAPHITE_HELPER=/path/to/helper.py` | Use the diagnostic Graphite helper interface (`--repo`, `--skia-root`, `--output`). |

The retention probe is macOS/Boehm-only and diagnoses reachability; it does
not establish that every document is collected. Its legacy closure-layout
inspection additionally requires `VOX_LEGACY_CLOSURE_LAYOUT=1` with the matching
legacy compiler. Normal builds leave the teardown experiments disabled.

`VOX_PREALLOC_PROBE=1` enables the two `layout/prealloc_frame_*_probe_test.v`
files. `VOX_PREALLOC_PROBE_DIR` selects their output directory (default:
`Build/prealloc-memory`). Run these with current V, `-enable-globals -prealloc
-gc none`. `main_svg_recording_export_probe_test.v` exports one SVG when
`VOX_SVG_RECORDING_INPUT` is set; `VOX_SVG_RECORDING_WIDTH` defaults to 80 and
`VOX_SVG_RECORDING_OUTPUT` defaults to `Build/svg-recording.json`.

## Recovery and audit records

`Build/master-consolidation-20261020/` retains the original and refreshed
inventories, per-worktree binary patches, content-addressed source snapshots,
file-version integration decisions, focused commit manifests, test logs and
worktree removal records. These records are local ignored build data.

`worktree-history.bundle` preserves the divergent histories. It was verified
with `git bundle verify`. The same commits remain reachable through
`refs/archive/worktree-consolidation-20261020/<commit-prefix>`; inspect them with
`git show`. Restore any needed source by reviewing and applying its patch on
master. Each worktree's HEAD, patch, status and source hashes were rechecked
immediately before its removal.

## Validation

Current V (`1e63d0f`) passed the focused DOM, browser binding, HTML, CSS, layout
and root browser test selections with default GC and `-gc none`. HTTP/2 wake,
admission, receive-credit and TLS integration fixtures passed with both
collectors. Native raster-cache and rectangle tests, the prealloc allocation
probes, SVG export and Python capture-tool tests also passed.

The optimized native bundle was packaged, ad-hoc signed and passed deep strict
signature verification and `--headless-smoke`. These viewport comparisons were
exact, with zero differing pixels and zero maximum channel error:

- Brave `svg-shared-root-recording`, `css-linear-gpu` and `font-rasterization`.
- Upstream `svg-image-source-switch-same-size`, `paint-server-id-collision` and
  `paint-server-html-id-collision` reftests.

The full translation suite was not run. The focused source selection,
commands, collector modes and diagnostic limitations are recorded in
`Build/master-consolidation-20261020/validation.json`.
