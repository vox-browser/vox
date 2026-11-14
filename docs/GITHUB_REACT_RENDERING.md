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

## November 14 continuation

`78d478971` fixes the rejected production startup. Staging an already staged
compiler inserted closure-allocation hooks twice; the second leave restored
a null allocator. Staging now recognizes complete existing instrumentation
and rejects partial or duplicated hooks. The focused startup contract in
`5636f3c19` uses explicit checks that remain active with literal `-prod`.
The repaired runtime passes; its broken control fails.

Production receipt `20261113-103410-86416163` subsequently publishes executable
SHA-256 `07b5873dc78af20df3f730261db0fb44e79b6b7d061aa210bff1dcb4f9a0316c`
in single-unit C `-prod` mode. A fresh November 14 process passes the complete
33-row archived React text audit, including latest commit, README and commit
links, with no script/native errors. Both native selector transports execute.
The earlier absent-query rollback is no longer required. Browser and memory
guard exits are zero. The host load is 63–66 on 18 CPUs, and a production
compile runs concurrently; this check establishes functionality only.

An interrupted prior turn recorded seven full-content pairs on this build,
with all 14 original PNG comparisons failing and Vox slower than Brave. Its
first pair also overlapped a diagnostic. The original job directory is now
absent. A recovered summary preserves the previously recorded counts and
this limitation; it is not a replacement for raw receipts and supplies no
acceptance or optimization credit. References and tolerances remain unchanged.

The checkout is now `/Users/alex/code/vox`; historical receipts retain its
former `/Users/alex/code/vox2` location. `3d60705b4` fixes regeneration of staged
compiler links after a cache directory moves. The cache key includes the
absolute output root, so moved entries cannot reuse broken absolute symlinks.
The regression fails against the old implementation and all six build-tool
test files pass with the correction. The managed production hook requests
the normal coalesced rebuild.

The explicit embed-helper import in `f11a8b575` clears the V profiler's earlier
embedded-asset resolution failure. Both the test and regular entry points then
hit a separate compiler error: optional tuple returns of two fixed arrays in
`gg.canvas` produce invalid C initializers. The diagnostic executable repairs
only those two initializers to nested braces, with before/after hashes and the
exact compiler command retained. It is **not** a production validation build.
Its fresh capture passes the full archived text audit, both selector paths
execute, and browser and guard exit zero. The resulting 1.5 MB V profile is
retained. It records extensive repeated flow layout and style access, including
244,664 block-box layout calls and 138,235 uncached independent layouts.
These counts belong to the instrumented run; recursive inclusive times overlap
and profiling changes callback scheduling. They establish no production gain.

A separate native sample of the pinned production browser finds repeated
`CTFontCopyVariationAxes` calls while opening registered faces for missing glyphs.
Disassembly places the sampled return address at offset 268 in the registered
descriptor branch, before the collection/file fallbacks. This verifies that
the proposed cache applies to the workload. Axis enumeration also localizes
the names on every open. `6b4924d38` stores the immutable
color/variation flags beside the registry's retained descriptor after its first
successful open. Lookup and publication use the existing mutex. No additional
native font object is retained; ordinary file opens keep their prior behavior.
`VOX_DISABLE_REGISTERED_FACE_FLAGS_CACHE=1` restores the old work in the same
binary for a future comparison.

The native regression fails before the fix. With it, 17 opens query axes once
per registered face, versus 17 with the rollback enabled. Variable-font weights
and color emoji retain identical flags, advances, bounds and glyph pixels;
uncached file opens and failed opens retain their behavior. The new regression,
existing glyph raster references and retained-glyph tests pass in all three
test files with default GC and `-gc none`; the rollback regression passes too.
An initial test-driver error used an unavailable temporary-directory API; its
failed check is retained, followed by the corrected passing checks.

The installed `07b5…` bundle predates this font optimization. Its native sample
identifies the repeated work, and the focused checks validate the correction;
a completed production bundle and matched unprofiled page cohort are still
required to measure its benefit. No site instruction saving or broad-check
optimization checkpoint is credited, and Brave parity remains open.

This continuation's raw profiles, native samples, capture audits, PNGs, exact
commands, guards and failed checks are local in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261114-r5/evidence.tar.gz`
(312 files; SHA-256
`7cca41feabf6bd7dd09154e9db347e328a18f85cac42b6d79ca5359881194007`).
The ignored structured record is
`docs/performance/github-react-rendering-20261114-r5.json`. Generated C units,
executables and the Python environment are excluded from the archive; the
diagnostic C repair's exact hunks, hashes and compiler command are retained.
All job guards have final exit receipts, and the job's scratch directory and
guard files are removed after verification of the archive.

## Production follow-up and checked selector matches

The completed single-unit C `-prod` executable
`6bf5db1e031eea8a68b6a4752ae3f45f603735510d16c6c7c5b43c27a0cde526`
contains the font-flag cache. Receipt `20261114-111608-a68550bc` seals the
expected `glyph_coretext.h` hash. Seven alternating normal/rollback pairs in
this same binary pass every complete-text audit. The observed instruction
medians are 31,911,369,766 normally and 36,066,520,908 with the cache disabled;
the corresponding time medians are 5,967.171 and 7,707.930 ms.
**These remain diagnostic observations, without qualified optimization credit.**
Six pairs have different pixels, and every capture differs from the original
native reference. Both settings produce both observed pixel states: directory
rows start at x=32 or x=33, with 25,387 differing pixels between those states.
The cause has not been isolated. Every attempt is retained, including the
initial controller directory-creation failure before any browser launched.

`60d87b57c` removes another repeated allocation from `Element.matches()`.
The CSS bridge validates and matches its document-owned parsed selector in
one callback. It avoids constructing the DOM's temporary opaque selector
vector and rewalking namespace metadata. Other bridges retain their existing
validation, namespace and matching callbacks. The existing matcher still reads
live element state with the element as its scope.
`VOX_DISABLE_CHECKED_SELECTOR_MATCHES=1` restores the old path.

The preallocation regression retains 49,152 bytes for 768 cached matches before
the change; afterward the same check retains less than 1 KiB. The five new
cases cover live relational/group selectors, `:scope`, syntax errors, foreign
bridge behavior, temporary argument retirement, and SVG/XML case. They pass
with default GC, production preallocation, and rollback. The seven-file
selector selection passes under preallocation; default-GC credit combines six
retained passing files with the corrected storage fixture. `25c94cefc` makes
that existing fixture independent of a helper in another test file, preserving
its assertions. Its original compile failure is retained.

A fresh C-O0 browser compiled from the canonical checkout passes mandatory
startup checks and the complete 33-row React audit without generated-C repairs.
All nine SVG mutation reftests remain pixel-exact in that executable, including
same-size image replacement and paint-server ID collisions. The full CPU
raster package passes all 38 test files in both default and no-GC modes, with
unchanged pinned inputs. The official LibJS AST driver matches all 100 cases.
These checks supply no production speed claim.

Production receipt `20261114-123523-3c4097b7` subsequently publishes executable
`243a18521e40b66394d8b6901294bf718bd8381e2eaf76aade81524ff9b0cb17`.
Its sealed hashes match all three checked-matcher implementation files,
although its recorded HEAD precedes the implementation commit. Seven
alternating normal/rollback pairs pass every content audit. Observed instruction
medians are 34,132,965,456 normally and 34,243,384,391 with checked matching
disabled; time medians are 5,209.788 and 5,330.809 ms. Only five pairs have
identical pixels, and none passes the original native reference. No production
page saving is credited from this cohort.

Two full seven-pair Vox/Brave cohorts retain the same frozen responses, complete
React-text requirement, viewport, private-cache policy and original PNG references:

| Pinned Vox executable | Vox median | Brave median | Highest Vox / lowest Brave |
| --- | ---: | ---: | ---: |
| `6bf5…` | 5,068.551 ms | 2,341.431 ms | 2.6283 |
| `243a…` | 3,629.312 ms | 1,932.544 ms | 2.4758 |

All 28 content audits pass; all 28 original PNG comparisons fail. Both cohorts
fail the requested parity gate. Host contention and other source changes
prevent attributing the difference between builds to this selector change.
These are fresh-launch-through-PNG observations with the previously documented
asymmetric audit/teardown endpoints, not isolated rendering timings. Process-tree
instruction counts remain lower bounds. References and tolerances are unchanged.

The benchmark validator also now rejects the capture format's current
`native_reported_error_count` and `native_reported_error_information` fields,
in addition to the earlier error field. All 44 driver tests pass. Revalidation
of all 56 retained cohort captures passes the stronger content/error check;
none contains previously missed reported native errors. Brave parity and
whole-page pixel conformance remain open.

Raw commands, captures, counter records, failed checks, source identities and
final guard exits are retained locally in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261114-r6/evidence.tar.gz`
(931 files; SHA-256
`17e68bc7150b26f5e40eccb350232b1400f55988c53523dbf261184ebdf57b73`).
The ignored structured record is
`docs/performance/github-react-rendering-20261114-r6.json`. The environment,
private test executable and generated C are excluded. The job directory,
its guard files and its AST output are removed after archive verification.

## Table coordinate restoration (November 14)

`7cea23bf7` fixes the timing-dependent file-table shift. Bounded diagnostics
reproduce rows at x=32 and x=33 even though block layout consistently places
the principal table at x=1 inside its wrapper. Incremental restoration linked
rows, groups and columns to their CSS containing block, the anonymous wrapper,
skipping the table's border offset. Both bounded relayout and clean-subtree
reuse now preserve the resolved principal-table coordinate parent while it
remains an ancestor in the current tree.

Two browser integration cases pass with compiler-default GC and with production
preallocation/GC disabled. They check separate and collapsed borders, captions,
columns, row groups and cells through six unrelated text edits and three clean
subtree reuses. The unchanged-code executable fails the column-coordinate
check. Final builds peak below 6.7 GB under the 12 GiB guard; executions retain
the 3 GiB guard.

Three fresh C-O0 captures pass the complete 33-row React text/error audit and
are pixel-identical, with rows consistently at x=33. Their decoded RGBA digest
is `f0324073630dc41b827460d06c3f91e690c2ccbba24a9a9a8736f26bdac81c81`.
A separate fresh live navigation passes with all 34 current rows carrying
commit links, latest commit and README, without reported native/script errors.
Startup and all nine SVG mutation reftests pass on the final candidate.

Earlier failures remain in the evidence: five compiler memory-guard exits,
temporary V/C signature mismatches during concurrent native-gradient work,
and an 8/9 SVG attempt whose failing actual PNG matches the unchanged-code
control while its reference capture varies. A supplementary preallocation
text-control suite crashes in `Document.cursor_position()` before typing,
including with incremental layout disabled; no pass is claimed for it.

**Brave parity remains open.** These are functional C-O0 checks, and the original
native PNG reference still fails. No references or tolerances changed and no
instruction or latency saving is credited. The latest completed production
executable, `a7d897a12f0d662693441df9110770289fbacf73ebf98b678ce5993f5601481c`,
does not contain the fix. The managed post-commit hook requests its single-unit
literal `-prod` rebuild; production validation and a qualifying matched cohort
remain pending. No duplicate production build was requested.

Raw commands, identities, captures, failures and guard exits are retained in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261114-r7/evidence.tar.gz`
(636 files; SHA-256
`2ebe9d9278093e4519a480ba367b08ef682f04afca32fe28fb904868ebb516e6`).
The ignored structured record is
`docs/performance/github-react-rendering-20261114-r7.json`. Generated C, private
executables and the Python environment are excluded; job scratch is removed
after archive verification.

## Cached query classifications and production follow-up (November 14)

`1cbb2af9d` keeps each valid selector's independent-compound classification and
namespace metadata with its document-owned parsed graph. Matches, scope,
relational contexts and DOM results remain fresh. General descendant walks
reuse the known classification instead of analyzing the selector at every node.
Each distinct valid selector retains one additional plan and compound vector.
`VOX_RECOMPUTE_DOCUMENT_QUERY_PLANS=1` recomputes those projections and uses the
old general walks for a same-executable diagnostic; the parsed-plan map remains
present in both modes.

Five new cases pass with compiler-default GC, preallocation/GC disabled, and
the recompute control. They cover live mutations, scope/relations, invalid
syntax, namespace metadata, separate documents and first-caller scratch
retirement. The 512-call warm-classification check allocates **0 bytes**, versus
**73,728 bytes** when recomputed. Ten existing query files pass in both GC
configurations; two additional namespace/quirks and general-workspace files pass
under preallocation. Startup, all nine SVG mutation reftests, and a fresh live
navigation with all 34 commit-linked rows also pass.

Three alternating C-O0 candidate/control pairs preserve complete archived
React content and identical paired PNGs. Their time medians are 9,923.914 and
10,711.615 ms. These development observations supply no production credit.

Production receipt `20261114-143607-0a077e61` publishes executable
`d94dced5f7643aa17ec662ec0a72400c5bb62a5e1ce87752af0a15ac07c41ce6` with
single-unit literal `-prod`. Its sealed CSS source hash matches the committed
query-plan implementation despite its earlier recorded HEAD. The previous
`314e…` bundle also verifies the table-coordinate fix in a fresh full-content
capture; its rows remain at x=33.

Seven production candidate/recompute pairs pass every complete-content audit.
Observed instruction medians are 31,752,569,697 and 32,103,418,111; time medians
are 6,528.990 and 6,659.184 ms, with overlapping ranges. Six pairs have identical
PNGs; one candidate differs by 54 header pixels in `(32,195)–(576,293)`. All 14
captures keep rows at x=33, but all fail the original native reference.
**No production page saving is credited.**

A separate seven-pair Vox/Brave cohort on `d94d…` passes all 14 complete React
text/error audits but fails every unchanged original per-engine PNG check.
Vox's median is **7,146.097 ms**, versus **2,564.486 ms** for Brave; the
highest-Vox/lowest-Brave ratio is **2.9865**. The requested parity gate fails.
These retain the launch-through-PNG scope, one-second settle, frozen responses,
fresh private HTTP caches and retained OS caches documented above, including
the asymmetric audit/teardown endpoints. Instruction totals remain observed
process-tree lower bounds. No references or tolerances changed.

`f70d47527` fixes the guard failure uncovered before the corrected cohorts:
current JSON decoding represents numeric PIDs as floats. The guard now accepts
finite integral values within signed `pid_t` range while rejecting fractions,
strings, booleans, out-of-range values and its own PID. A registry error also
stops newly observed descendants. Four new guard cases and existing tooling
checks pass, including RSS accounting and cleanup of a separately grouped
64 MiB process. The failed first attempt and identity-verified cleanup of its
one surviving owned Vox process are retained. Both corrected production
cohorts adopt all 14 browser roots without adoption errors and retain the
12 GiB guard.

A separate production sample confirms continuing layout, script and painting
costs; it is diagnostic evidence, not timing acceptance. Setup failures from a
namespace fixture and a mismatched Python/Pillow environment are also retained.
Raw commands, identities, counters, captures, profiles, failures and guard exits
are in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261114-r8/evidence.tar.gz`
(738 files; SHA-256
`826bcab0d61b89292696e4eefe38ac5dfa994d9ebdd8ae73824d0afd550221fa`).
The ignored structured record is
`docs/performance/github-react-rendering-20261114-r8.json`. Generated C,
private test executables and the Python environment are excluded.

## Absolute generated-box measurements (November 14)

`1c21e2e0a` admits ordinary absolute `::before` and `::after` boxes to the
existing within-pass grid/flex measurement cache. The shared collector still
validates generated text, style revisions, fonts, child identities and internal
containing blocks. Replaced content, specialized generated kinds, anchors,
calculated insets and shifted/fixed/sticky positions retain their full paths.
Final absolute layout still runs. `VOX_DISABLE_ABSOLUTE_PSEUDO_MEASUREMENTS=1`
restores the prior admission policy. A separate diagnostic confirms an actual
new cache hit on the archived GitHub page.

Three new cases pass with compiler-default GC and preallocation/GC disabled,
plus the new rollback and existing static-generated rollback controls. They
compare static records, final geometry and glyph positions with an independent
uncached layout after producer scratch retirement, check copy-on-write rare
records, and reject live text/inset/containing-block changes. Test compilation
uses `V3_STR_CAP=1` to bound the current compiler's generated object formatters;
assertions remain active. Both builds peak near 4.12 GB under the unchanged
12 GiB guard, and runtime checks use 3 GiB guards. Initial uncapped attempts hit
the guard; a separate compiler sample identifies automatic formatter synthesis.
Temporary assertion changes were reverted. Transient shared LibJS compilation
failures and the initial missing cross-file test helpers are also retained.

The final C-O0 executable is
`966123836108a671f654a544c7ed0b39af03f1bfc542ace76a3ee802d6bdef5c`.
Startup, all nine SVG mutation reftests, and live navigation with all 34
commit-linked rows pass. Two alternating final candidate/control pairs pass
all four complete 33-row archived React audits, with identical decoded PNGs
(`f0324073…`). Their launch-through-native-PNG/audit/teardown time medians are
**12,140.762 ms candidate and 10,846.641 ms control**; observed instruction
medians are 117,766,534,061 and 115,170,506,267.5. Both counters remain
process-tree lower bounds. The 18-CPU host has recorded one-minute loads of
6.85–7.62, with other builds active. The candidate regresses at these medians.
An earlier, broader candidate had three exact-pixel pairs at 13,592.446 versus
14,753.690 ms; its heading extension never reported a heading hit and was
removed. These development results do not establish a production saving.

The original native PNG reference still fails. No reference or tolerance
changed, no instruction saving or broad-cadence credit is assigned, and Brave
parity remains open. The latest completed production executable remains
`d94d…`, which lacks this change. Its seven-pair Vox/Brave failure above remains
the last measured production comparison. The managed post-commit hook requests
a coalesced single-unit literal `-prod` rebuild; no duplicate build is queued.

Raw commands, identities, counters, captures, profiles, failures and guard exits
are retained in
`~/Library/Caches/Vox/benchmarks/github-react-rendering-20261114-r9/evidence.tar.gz`
(552 files; SHA-256
`5711f7d5d9f5f7f180ae25613e8616b43e886c96c4d98596b84a44757f9df693`).
The ignored structured record is
`docs/performance/github-react-rendering-20261114-r9.json`. Generated C, private
executables and the Python environment are excluded; scratch is removed after
archive verification.
