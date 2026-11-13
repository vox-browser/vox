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

## November 13 continuation

The metadata change is present in completed executable
`081a75f66fbda26d5df97732bce84bfdb4664ea73257ee19ec3f9f381b474829`.
A retained diagnostic pair records **3,563.503333 ms / 36,773,272,120
instructions for Vox**, versus **2,252.528 ms / 20,793,591,610 for Brave**.
The full React text audit passes; both unchanged PNG checks fail. This is
one exploratory pair, with the endpoint differences documented above, and
does not establish parity or a metadata optimization gain.

Eight subsequent native controls use completed executable
`86516f7f2eb9c44f78173c2a4f7acd12834c9d31bb24aa1a7954ec0dca640234`.
Every complete text audit passes. Host load varies from 36 to 53, elapsed
times range from 6.0 to 8.75 seconds, and the file-table origin alternates
between x=32 and x=33. Neither metadata reuse nor a shorter load-render gap
earns performance credit. Disabling throttling increases observed work from
37–39 billion to 60–61 billion instructions without a latency benefit;
the throttle policy remains unchanged. A separate small table fixture stays
at x=33 through 32 text/attribute relayouts and block/flex switches, so no
speculative table correction was applied.

Separate diagnostics identify 18,419 `matches()` calls and 18,595 descendant
queries for React partial selectors. `d496fdafa` returns native selector
match booleans without JSON serialization. Pending facade mutations still
use the original transport, native custom-element reactions settle before
the read, and foreign owners retain their existing route. Selector argument
copies live in scratch storage; parsed selector sources use document storage.
Three focused cases pass with default GC and no GC, including the rollback
route, primitive argument branding, syntax errors, Unicode, adoption, queued
reactions, scratch callers and separate runtime owners.

`2a4d3edfa` returns `null` directly for absent `querySelector()` results.
Positive results keep the original element-state synchronization. It retains
selector validation, scope, fragment and foreign-document behavior and the
same mutation/reaction ordering. Its two focused cases pass in default GC
and no GC, with diagnostic path confirmation and rollback executions under
the 3 GiB guard. Compiles peak at 6.61 GB under the 12 GiB guard. An earlier
attempt rejected a changing UI2 adapter; that failure is retained. The
comparison tool's `--matches-control`
and `--first-control` switches retain the original transports independently;
the browser switches are `VOX_RETAIN_COMPACT_MATCHES_QUERY=1` and
`VOX_RETAIN_COMPACT_FIRST_QUERY=1`.

Production validation remains pending. The old coordinator used a compiler
whose runtime did not match; its idle process was retired after confirming
it had no compiler/guard child, and the supported upgrade worker uses the
matching compiler. Build `20261113-002650-16f47fd6` parsed the exact selector
and metadata sources but rejected a concurrently changed
`tools/ui2/gg_document_image.v` during frozen-input verification. The prior
bundle was preserved. Its successor, `20261113-003619-9c655d8b`, parsed both
committed selector slices and reached sealed single-unit C compilation.
A four-minute guarded wait for a published matching bundle exited 2 without
launching a page check. No unverified executable supplies optimization credit,
and no cumulative instruction saving or broad-check checkpoint is claimed.
The next gates are a diagnostic confirming both native paths on the full
GitHub replay, matched unprofiled controls with unchanged pixels, the bridge's
required SVG mutation captures, and seven complete alternating Vox/Brave pairs.

Continuation logs, counters, audits, PNGs, source-digest proofs, failed attempts
and actual guard exits are retained locally in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261113/evidence.tar.gz`.
Its manifest is `docs/performance/github-react-rendering-20261113.json` (ignored).
The archive contains measurement evidence; browser bundles, generated compiler
outputs and the Python environment are excluded. The shared production build
is left running and no duplicate manual build was requested.

## Production selector regression and cache correction

Completed production executable
`5fb3eb909ae426b7cfcb1b0e8a67ab494177d13b0a0f693d5ae5d1e737561576`
contains both selector transports. A full-render diagnostic exposed a
production-only regression in the absent-query probe: React commit messages,
dates and the latest commit never appear, and native element-owner errors
follow. Disabling only the absent-query path restores the complete content;
the direct `matches()` path remains functional. The incomplete captures'
20–21 billion observed instructions earn no performance credit.

`3afd19a2d` fixes the ownership error. The probe called `node_for_key()`, which
also registers a key in the retained identity map. Its argument belongs to
the host's temporary string buffer, which is freed after the query under
`-prealloc`. The probe now reads registered owners without modifying that
map; unregistered owners retain the original transport. A new retained-key
test and the existing DOM integration test both fail before the fix under
`-prealloc`, then all three cases pass after it. Default GC, rollback and
protected freed-buffer checks also pass. Compilation retains the 12 GiB
guard and `-memory-limit 10G`; separate executions use the 3 GiB guard.

A fresh windowed test executable, compiled with the published build's frozen
compiler and patched preallocation runtime, passes the original full-text
audit for all 33 archived rows, latest commit, README and commit links. Both
native fast-path diagnostics execute, with no reported errors. A separate
fresh live navigation displays all 34 current rows with commit links and date
text, latest commit and README, also without native or script errors.
These are functional checks of a C-O0 test executable; their counters and
timings cannot establish production speed.

All nine focused SVG cases are pixel-exact: same-size image-source replacement,
gradient stop insertion, animation, offset and `moveBefore()`, gradient href
and transform changes, and both paint-server ID collisions. The capture
driver's attempt to compile its diff program selected FastC and failed; the
retained PNG pairs were then verified with the existing pinned
`Build/pixel-tools/pixel_diff` executable at zero tolerance and independently
with decoded-pixel comparison. No capture, reference or tolerance was changed.

Two full-browser `v -profile` builds fail on embedded-asset method/type
resolution. A minimal `$embed_file(...).to_string()` probe reproduces the
compiler failure with profiling enabled. No V profile was collected. A
separate native sample identifies the timed-out capture's repeated readiness
selector polling; it is diagnostic evidence, not optimization credit. An
earlier test executable built with the unmatched compiler crashes while
reallocating PNG data; that failed launch is retained too.

Two alternating native control pairs with the broken absent-query path
disabled retain complete React text. Observed work is 38.120/38.335 billion
instructions with both transports disabled, versus 36.639/35.229 billion
with native `matches()` enabled. One enabled capture has the known 1px table
shift; the host is contended. This is not a seven-pair acceptance cohort, and
neither a qualified instruction saving nor Brave parity is claimed.

`7aaff5e95` removes a production build blocker without weakening verification.
The font-runtime manifest includes the compiler and vlib paths, but its cache
key previously omitted both. Two compilers with identical font sources
therefore collided and rejected an intact cache as modified. The key now
includes those identities. An integration case reproduces the original
collision, then verifies separate reusable entries and continued rejection
of changed staged files. All five build-tool test files pass. The managed
production rebuild has restarted; a new production cohort remains required.

The cache correction lets `20261113-084549-677a637f` compile, seal and link
the production browser successfully (build guard exit 0, peak 8.69 GB).
Its mandatory headless startup then exits 139 in
`platform.enter_retained_allocations`, called by the HTML parser while
installing the smoke document. The smoke guard also records 139. Publication
is rejected and the prior bundle remains installed. Consequently the queued
seven-pair comparison cannot validate this source revision. The retained
startup failure must be resolved before production speed can be measured.

This continuation's raw captures, counters, compiler/profiler failures,
before/after regression checks, cache tests, startup stack and guard exits are
local in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261113-r3/evidence.tar.gz`.
The ignored structured record is
`docs/performance/github-react-rendering-20261113-r3.json`.
No production instruction saving or broad-check optimization checkpoint is
credited. The installed `5fb3…` bundle still requires
`VOX_RETAIN_COMPACT_FIRST_QUERY=1` for complete GitHub hydration until a
corrected production bundle passes startup and is published.
