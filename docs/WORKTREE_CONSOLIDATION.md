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
-gc none`. `paint/main_svg_recording_export_probe_test.v` exports one SVG when
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

## Follow-up audit, 2026-10-21

The canonical checkout is the only remaining worktree, and there are no active
stashes. Six of the seven local branch tips, including `master`, are in master's
ancestry. The remaining branch, `codex/nojs-wikipedia-ram-v10`, has twelve
divergent commits whose patches all have exact equivalents on master. All 25
original integration commits are ancestors of master; all 309 recorded file
decisions and 28 original recovery refs remain available.

The twelve tags were also checked. Older Wikipedia font, text-width and
scrollbar revisions and the Wasm compiled-record revisions map to their revised
master implementations. The 23 commits reachable only through reflogs are
accounted for: four exact patch equivalents and nineteen reviewed integrations,
formatting changes or documentation corrections. This includes the autosquashed
LibRegex invalid-patch panic regression. Recovering
`.main_navigation_document.v.swp` produced an exact file blob already in master's
history; the swap is preserved and contains no additional implementation.

A deeper `git fsck --unreachable` check found 511 older commits outside both
refs and reflogs, including 24 dropped stash heads and their index/untracked
parents. Of the 459 non-stash records, 291 have exact master patch equivalents,
12 have all resulting file blobs in master's history, and 108 have reviewed,
revised integrations. The remainder comprises 29 early translation drafts,
18 superseded documentation revisions and one historical static-frame replay
alternative. The stash changes are integrated or superseded, apart from an
unvalidated geometry-commit shortcut. These alternatives remain recovery material;
the maintained native frame path and complete geometry traversal are retained.

All 135 formerly unreachable commit tips are now preserved under
`refs/archive/master-audit-20261021/<commit-prefix>`. A verified recovery pack
also preserves all 4,200 originally unreachable objects, including 178 loose
file versions outside those commit trees. These source, documentation and fixture
versions remain recovery material; a loose blob alone is not validation for a
fix. Nothing was pruned or reset.

Three remaining checkout changes were validated and committed separately:

- `66952e9d`: reuse viewport ink probes, with allocation and retained-scene tests.
- `ff05607b`: keep table-border test values as explicit sum types for current V.
- `22a0c833`: initialize populated layout slots directly, preserving independent
  geometry, sparse slot identity and retained snapshot ownership.

Ten layout cases and eight painting cases pass with current V in Boehm,
`-prealloc -gc none`, and prealloc with `VOX_ARENA_POISON=1`: 54 passing case
executions. Eight unchanged passing prealloc cases are carried from the initial
selection; only its two corrected cases were repeated. Failed fixture/build
attempts remain recorded. Broad suites and new RAM/instruction comparisons were
not part of this consolidation audit.

Detailed mappings, source hashes, exact compiler arguments, failed and passing
logs, recovered files and the recovery pack/index are retained under
`Build/master-audit-20261021/`. Its `audit.json`, `validation.json`,
`unreachable-commit-coverage.json` and `dropped-stash-coverage.json` describe the
decisions. Historical experiments must be reviewed against current source
before reuse; their old complete trees must not replace master wholesale.

## Branch cleanup, 2026-10-21

The six remaining non-master local branches were deleted after rechecking their
tips against `05d4e7b4`. Five tips were ancestors of master. All twelve divergent
patches on `codex/nojs-wikipedia-ram-v10` had exact equivalents on master; its
original tip remains at
`refs/archive/worktree-consolidation-20261020/a5c6fd2ba7e8`.

Only the local `master` branch and canonical checkout remain. There were no
additional worktrees to remove. Remote-tracking refs, tags, recovery refs and
the untracked editor swap were preserved. The checks and deletion results are
recorded in `Build/master-audit-20261021/branch-cleanup.json`.
