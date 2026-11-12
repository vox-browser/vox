# GitHub complete React render, November 12, 2026

**Brave parity remains open.** The script-free GitHub result in
[the earlier comparison](GITHUB_BRAVE_INSTRUCTIONS.md) does not establish the
time to display React's commit messages and dates.

`613351905` avoids unconditional style recomputation for unrelated `data-*`
and ARIA changes. Selector invalidation, including descendant, sibling and
`:has()` dependencies, remains active. Elements using `attr()` still recompute.
Identical metadata assignments retain styles while preserving mutation records
and custom-element reaction scheduling. Other attributes retain the existing
presentational-hint handling. `VOX_DISABLE_METADATA_ATTRIBUTE_STYLE_REUSE=1`
restores the previous behavior for a comparison in the same binary.

Five focused cases pass in the current compiler's C backend with default GC
and `-gc none`, and with the rollback switch enabled. They cover style retention,
positive and negated attribute changes, shadow-host and sibling selectors,
typed `attr()` values, and unchanged writes with observable mutation records.
Builds retain `-memory-limit 10G` and the 12 GiB process-tree guard; separate
executions use the 3 GiB runtime guard. Earlier compiler/bootstrap and fixture
errors are retained in the local evidence. No page instruction savings have
been established, so no broad-suite optimization checkpoint is credited.

`dec6c10e6` adds [the full-render comparison tool](../tools/github_hydrated_render.py).
It requires every retained row ID to contain its commit link before settling,
then compares every row's complete text, the latest commit, README and commit
links with a retained native audit. Merely seeing filenames or the hydrated
Sponsor button cannot pass. Both browsers execute scripts against the same
original-origin offline replay. Brave runs windowed on the display away from
the pointer. The tool requires exact original per-engine PNGs, pins executable,
non-system runtime and resource identities, preserves failed validations, and
requires seven alternating pairs to accept the requested parity target.
Its four focused tests and all 40 existing instruction-driver tests pass.
Python with Pillow is required for exact decoded-pixel validation.

The frozen workload retains the November 8 archived responses and the shared
Date-only prefix; performance clocks and timers continue normally. Fresh private
profiles and HTTP caches are used, with OS filesystem/shader caches retained.
The viewport is 1024×768 at 1×. The recorded exploratory runs use a one-second
settle after content readiness. Vox's endpoint includes document PNG encoding,
audit and process teardown. Brave's endpoint is CDP PNG delivery, before its
audit and teardown. Their process-tree instruction totals are observed lower
bounds and exclude GPU/WindowServer work.

The last **diagnostic pair**, on baseline executable
`ec750b1d98c4e5c65bd042cf35a0309affc61a4ff9b3f668f611bff0e6dc24bb`,
records 3,513.404375 ms / 36,411,030,575 instructions for Vox and
2,065.423999999439 ms / 19,502,962,523 instructions for Brave. All 33 rows,
their React commit text, latest commit, README and commit links match exactly,
with no reported script/native errors and stable pinned runtime identities.
**Both PNG checks fail against the unchanged exploratory references.**
The native mismatch includes file-table glyph positioning and the Sponsor
heart. The earlier Brave reference was headless; the comparison uses windowed
Brave. No reference or tolerance was adjusted to turn these failures into a
pass. This single pair is not an acceptance cohort or an optimization result.

A separate fresh live baseline navigation completes with all 34 current file
rows, latest commit and README and no reported JavaScript errors. It is a
functional check, not a matched live performance measurement.

The metadata optimization is absent from that baseline executable. Its managed
post-commit rebuild was requested, but successive shared build attempts failed
source/compiler manifest verification, including `20261112-193326-cd201345`
and `20261112-193522-a74067eb`. The last completed bundle was reused; no duplicate
production build or app copy was made. Native performance validation of the
optimization remains pending a verified completed build. A fresh stable baseline
at the final-render boundary and a complete matched cohort are still required.

Raw commands, audits, PNGs, counters, host loads, identities, failures and actual
guard exits are retained locally in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261112/evidence.tar.gz`.
The local structured record is
`docs/performance/github-react-rendering-20261112.json`. Neither is committed.
The original replay bodies remain in the separately pinned
`github-site-optimizations-20261108/evidence.tar.gz` cache archive.

Run a new cohort under the memory guard with retained inputs:

```sh
sh tools/run_v_tool.sh run_memory_bounded \
  --lock Build/github-react-UNIQUE.lock --report Build/github-react-UNIQUE.json -- \
  python3 tools/github_hydrated_render.py \
    --archive PATH_TO_ORIGINAL_SCRIPTED_REPLAY \
    --reference-audit PATH_TO_COMPLETE_NATIVE_AUDIT \
    --expected-vox PATH_TO_ORIGINAL_VOX_PNG \
    --expected-brave PATH_TO_ORIGINAL_WINDOWED_BRAVE_PNG \
    --output Build/github-react-UNIQUE --repeat 7 --settle-seconds 1
```
