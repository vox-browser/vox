# Hacker News rendering

The discussion is <https://news.ycombinator.com/item?id=50231722>.
The small text in the reported screenshot is the opening sentence of
<https://news.ycombinator.com/item?id=50225695#50226323>:
“This statement stood out to me.” It belongs to the comment body.

Commit `5ffc75c8` projects the parent's inherited style into physical layout
coordinates before creating an anonymous block for bare text beside paragraph
blocks. Previously, that wrapper used the unscaled font while the paragraphs
used the physical font. The focused layout regression covers quirks and
standards modes, scale changes and live font-size changes.

## Native Brave references

Brave 156.1.98.60 references use a fresh profile, sRGB, a native window on the
display away from the pointer, and the display's actual device scale 2. They
use `tools/capture_brave_reference.py --windowed --native-scale`; device
emulation gives different font metrics and is unsuitable for these references.

| Fixture | CSS viewport | Stored reference |
| --- | --- | --- |
| `hacker-news-comment-initial-text` | 800×600 | 800×600, normalized with `sips --resampleHeightWidth 600 800` |
| `hacker-news-item-50231722-complete` | 1024×768 | Raw 2048×1536 |

Text-control intrinsic widths are rounded after projection into physical layout
coordinates. The 80-column reply textarea is 664.5 CSS pixels wide at native
scale 2, including its padding and borders; rounding in CSS pixels first
incorrectly added one physical pixel. The control regression checks scale
changes and the neighboring text input.

The textarea resize grip uses overlapping translucent SVG strokes. Consecutive
solid butt-ended line strokes share a GPU raster pass so their sample coverage
survives until the common antialiasing resolve. Resolving each stroke separately changed 19
physical pixels. The focused grouping tests retain clip, effect, raster-layer,
gradient, dash, curve, join, cap, non-scaling-stroke, and combined fill/stroke
boundaries.

The complete fixture freezes the 2026-10-25 response, removes scripts, and
retains all 101 comment rows, including collapsed and hidden rows. Both
fixtures reuse the archived local Hacker News assets.

Reference SHA-256:

- Comment: `b3dc205771f33b20b452baf5346f49deed96ffad57d4085624b3ba65dfa142fc`.
- Complete discussion: `8d7ac5db8f497cddcc93f28077f7577a411aceef327ed174b948458379fd5b44`.

Run the original discussion, complete Retina discussion, and comment pixel tests with:

```sh
V_BIN=~/code/v-latest/v python3 tools/run_memory_bounded.py \
  --report Build/hn-pixels-job.json -- python3 tools/hacker_news_pixels_test.py
```

## Instruction comparison

```sh
python3 tools/run_memory_bounded.py --report Build/hn-instructions-job.json -- \
  python3 tools/hacker_news_browser_instructions.py --output Build/hn-instructions
```

This runs three alternating pairs by default. Each observation needs exact
reference pixels, all 101 comment IDs, the intended URL, complete readiness,
the correct viewport and a successful kernel-reported exit. A failed load
cannot earn performance credit. The gate requires the largest Vox count to
be at most 90% of the smallest Brave lower bound, including sampling uncertainty.

The measured interval starts at navigation request and ends when the encoded
document PNG is available. Both browsers use fresh processes, profiles and
caches with the same frozen page and local HTTP replay. Vox's native marker
precedes file writing; Brave's CDP endpoint includes PNG base64/IPC delivery
and readiness polling. Vox requests its initial navigation before its first
native window frame, while Brave creates and resizes an `about:blank` window
before requesting the measured navigation. Consequently Vox's interval also
includes initial window work that Brave completes before its interval. The
existing counts retain these boundaries; they must not be presented as an
isolated comparison of page rendering. Both use inactive native windows away
from the pointer.
Exclusive resource-coalition counts include live and exited helpers and owned
Metal compiler services. GPU execution and services outside those coalitions
are excluded. This compares the capture workflows; their internal endpoints
differ, so it does not establish identical internal first-render work.

The regular screenshot tests normalize the raw complete-discussion reference
to logical pixels using the same `sips` conversion as the capture workflow.
The instruction gate additionally requires exact raw native-resolution pixels
on every observation.

The benchmark pins app contents, Vox native dependencies, fixtures, reference,
assets and harness files throughout the trials and saves all raw counts,
endpoint brackets, membership checks and actual exit statuses.

## Validation cadence

The rendering follow-up contains three fixes: anonymous text-wrapper font
projection (`5ffc75c8`), physical textarea width rounding (`956b1d79`), and the
resize-grip stroke resolve. Focused layout, style, control and SVG grouping
checks accompany those changes; the page regressions retain exact pixels.
These checks do not reset the repository's existing broad-verification
cadence or claim completion of a broad suite.

The Brave comparison is a cross-browser acceptance check. It does not assign
optimization savings to a Vox change: that requires matched Vox control and
candidate observations at the same endpoint and workload. No reduction is
credited to the repository's 5,000,000-instruction optimization ledger here.

## Verified production build and remaining target

The pinned production bundle is `Build/hn-small-text/retina-controls-8/Vox.app`.
Its executable SHA-256 is
`9140ff0b754f7cf420af3b2e8ffa66a13e945cfe56d033c6c985d76cea410b17`;
its Graphite library SHA-256 is
`23eaccf96e0bf85b56350784606e39ee4d7addc07884ba2956a7f9be36a56b59`.
It was built from the shared working tree at `8b5ffc58`, with independent native
and message-channel edits in progress. `build-provenance.json` and the full
source manifests in that directory preserve the actual build inputs; the
executable is not claimed to come solely from that commit.

That bundle passes the three regular page tests, exact raw native-resolution
comparisons for the reduced comment, complete discussion and fractional inline
controls, the startup smoke check, and all eight instruction-harness unit tests.
The six focused SVG grouping cases compiled and executed successfully under
`retina-controls-7`; the focused control, anonymous wrapper and device-style
cases passed under `retina-controls-4`. The grip fix is commit `6be8b470`.

The first complete native comparison is retained under
`Build/hn-small-text/retina-controls-9/instructions`. All six observations exited
successfully, matched the unchanged raw reference exactly, and retained all 101
comment IDs:

| Pair | Vox instructions | Brave lower bound | Brave upper bound |
| --- | ---: | ---: | ---: |
| 1 | 7,844,436,549 | 7,156,784,864 | 7,219,008,367 |
| 2 | 7,866,837,218 | 1,735,672,585 | 1,790,574,814 |
| 3 | 7,875,866,652 | 1,727,774,620 | 1,768,761,111 |

**The requested 10% instruction reduction is not achieved.** The strict ratio
is 4.5584, above the required 0.90; Vox's median is 7.867 billion instructions.
Brave's first observation was substantially more expensive than its later
observations; it remains in the results. No observations are discarded or
credited as a Vox optimization. The benchmark and memory guard both returned 1
for the failed acceptance gate, with a sampled peak RSS of 1,148,223,488 bytes.
Earlier disk-space and build failures remain alongside the successful checks.

Fresh live checks of both original URLs also passed, with actual browser exits
zero, the requested URL/title/readiness, and comment identity validated.
Their PIDs were 80439 (discussion) and 80516 (reported comment). Document-only
screenshots and audits are in `retina-controls-9/live-discussion` and
`retina-controls-9/live-comment`. The latter visibly renders the opener at the
comment body's font size. These live checks establish loading and the reported
font correction; exact comparison uses the frozen fixtures above.

## Device projection follow-up

Commit `f207dcb9` skips unchanged dimensionless values and zero pixel lengths
when projecting a computed style into device coordinates. Keyword border
widths and dimensional transforms still scale. The regression checks shared
property identity, percentages, keyword widths, matrix translations and cache
reuse at four scales. Both `device_layout_style_test.v` (12 cases) and
`device_layout_projection_storage_test.v` (two cases) compiled and executed
successfully. The initial new-test crash and its corrected optional-value
handling remain in `Build/hn-small-text/projection-1` and `projection-2`.

The diagnostic sample in `Build/hn-small-text/profile-5` contains real page
installation, CSS projection and table layout stacks; its capture matches the
raw Brave reference exactly. Earlier samples missed rendering and remain
marked unsuitable for attribution. The delayed-response diagnostic earns no
instruction credit.

The current pinned production bundle is `Build/hn-small-text/projection-2/Vox.app`:

- Executable SHA-256: `768900a341df3d56a999e1e8b222d48b403beff0257543ed5fbe06b0db5bd106`.
- Graphite SHA-256: `8cd61beccc720e6e8a1c579b15ff8ddaec87f9b05c16bcdfbbe4575517646a23`.

The production build, startup smoke and all three raw native pixel comparisons
passed. Source manifests preserve the shared working-tree inputs. During the
build HEAD advanced from `d4a75b41` to `1f9184c2`; only the independent
`html/window_post_message_test.v` changed in the source manifest. The two
projection files were unchanged throughout compilation and verification.

The fresh three-pair acceptance check is retained in `projection-2/instructions`:

| Pair | Vox instructions | Brave lower bound | Brave upper bound |
| --- | ---: | ---: | ---: |
| 1 | 9,449,779,492 | 6,966,571,659 | 7,025,559,875 |
| 2 | 7,738,148,309 | 1,792,062,357 | 1,844,963,273 |
| 3 | 7,732,440,745 | 1,739,734,765 | 1,809,886,421 |

All six browsers exited zero, matched the reference exactly and retained all
101 comment rows. **The 10% instruction target still fails**: the strict ratio
is 5.4317 versus the required 0.90. The median Vox count is 7.738 billion and
the median Brave lower bound is 1.792 billion. Both first observations remain
in the results. The benchmark and enclosing guard returned 1 for the failed
acceptance gate; sampled peak aggregate RSS was 7,604,387,840 bytes.

These observations do not isolate the projection change from the other
working-tree changes since the earlier build. No matched Vox optimization
savings, broad-verification credit or ledger reset are claimed.

Fresh live checks of the projection bundle also passed. The discussion process
was PID 30850 and the reported-comment process was PID 30923; both exited zero
and passed URL, title and readiness checks. The comment audit also verified its
identity and opening sentence. Each launch used a new private profile, an
inactive test window, a 1024×768 document viewport at backing scale 2, and a
three-second settle period. The executable hash above was checked again.
`projection-2/live-discussion` and `projection-2/live-comment` retain the native
document-only screenshots, audits, browser logs and actual exit codes. The
comment screenshot visibly renders “This statement stood out to me.” at the
body's font size. The enclosing live-check guard returned zero, with a sampled
peak aggregate RSS of 1,132,789,760 bytes. Live loading and the reported font
correction passed; the frozen fixtures establish exact Brave pixel agreement.

## Declarative-shadow traversal follow-up

Commit `eee01edd` skips child snapshots for leaf nodes during declarative-shadow
materialization. The parent still independently revisits an attached shadow
root, including a host with no light children. All three focused storage and
mutation cases compiled and executed successfully in both Boehm and prealloc
configurations: six case executions, with actual compiler and runtime exits
zero. Commands, source hashes, binaries and logs are retained in
`Build/hn-small-text/shadow-leaf-1`.

The enclosing job subsequently stopped at a CSS test compilation error caused
by an invalid enum-iteration expression. That failure is retained with its
actual exit 1; the guard reports a sampled peak aggregate RSS of
5,587,763,200 bytes. It does not invalidate the completed shadow tests. No
matched instruction reduction or broad-verification credit is claimed for
this change.

## Keyword serialization and table measurement follow-up

Commit `527164ca` reuses static CSS keyword spellings when exposing typed values
to the DOM. Commit `845e1b53` skips unused intrinsic-content probes when deriving
minimum row heights for nonspanning Chromium tables. Spanning tables and the
LibWeb font policy retain the complete measurement path; final-width cell
layout continues to supply Chromium content heights.

`Build/hn-small-text/table-minimum-1/results.json` records successful compilation
and execution of four serialization cases, four table-minimum cases and the
existing final-width footer case in both Boehm and prealloc modes: 18 case
executions, with all six compiler/runtime pairs exiting zero. The table cases
cover standards and quirks modes, both box-sizing modes, separate and collapsed
borders, spanning cells and the LibWeb fallback. The audit mapping's 18 focused
tests also pass, and the upstream method inventory resolves the renamed helper.

FuseCode interrupted the subsequent production compilation. Its build and guard
exit statuses are unknown; `table-minimum-1/interruption.json` records the missing
completion evidence. Completed tests are retained, and unfinished production,
pixel, live-page and instruction checks resume separately. These focused results
do not establish production acceptance or instruction savings. The 10% target
and the existing broad-verification ledger remain unchanged.

## Resumed production rendering verification

Commit `9ad918d3` reads the rendered UTF-16 cache before checking an entire
string for ASCII when inspecting a fragment's trailing whitespace. Its five
focused cases pass in both Boehm and preallocated no-GC modes: both compiler
exits and both executed test-binary exits are zero. The cases cover cached and
uncached UTF-16 offsets, invalidation, and allocation-free repeated whitespace
reads. Commands, source and binary hashes, and the 3 GiB runtime guard reports
are retained in `Build/hn-small-text/chunk-read-1/`.

The resumed production bundle in
`Build/hn-small-text/table-minimum-resume-1/Vox.app` builds successfully with
current V. Its executable SHA-256 is
`fc13e8102e770e061b2fe591a73698fc2c31d07a8611eff3eae5fa02d5301d1f`,
and its `libLadybirdVSkiaText.dylib` SHA-256 is
`f4757faec2bd9cda9cc6a4d72ffb7263d799bc82a097d853b030adf292f4c3f7`.
The before/after source manifests contain no changed build inputs. The shared
working tree includes independent changes, so these results are not isolated
optimization evidence for one commit.

Fresh native-scale captures of `hacker-news-comment-initial-text`,
`hacker-news-item-50231722-complete`, and `device-layout-inline-precision`
all have zero differing pixels, zero maximum channel error, and zero MAE/RMSE
against their raw Brave references. All three browser exits are zero. The
startup smoke check also exits zero. Fresh private-profile live navigations
to both the requested discussion (PID 28144) and the reported comment
(PID 28784) pass document identity/readiness checks and exit zero. The live
comment screenshot, `live-comment/document.png`, shows its opening sentence at
the correct body-text size. Per-launch commands, environments, identities,
actual exits, screenshots and comparisons are retained with that bundle.

The enclosing guard exits one because a subsequent LLDB eligibility probe
stopped before browser execution; this does not turn the completed rendering
checks into failures. Its child exit is one, sampled peak RSS is 8,980,037,632
bytes within the default 12 GiB budget, and elapsed time is 718.680 seconds.
The invalid probe is retained in `table-shortcut-probe/`. Eligibility and
unprofiled instruction checks resume separately. No instruction reduction or
completion of the 10% target is claimed from these rendering results.

## Completed table eligibility and instruction check

The corrected, separate LLDB probe in `table-minimum-resume-1/table-shortcut-probe-2`
validates the executable UUID and symbol range before resuming the browser. It
observes 420 table-cell entries, zero requests for maximum row measurements and
zero full intrinsic row probes. Browser and debugger exits are zero, the
executable hash is unchanged, and the resulting screenshot has zero differing
pixels. This establishes eligibility only; instrumented execution receives no
instruction-saving credit.

`Build/hn-small-text/table-minimum-resume-2/instructions` retains three alternating,
unprofiled pairs against the same pinned production bundle. All six browser and
kernel exits are zero, all contain the complete 101-comment fixture, all native
captures are pixel-exact, and all checked resource-coalition members are owned.
`acceptance-audit.json` records the independent audit and unchanged executable,
native-library, harness and fixture identities.

| Pair | Vox instructions | Brave instruction bounds |
| --- | ---: | ---: |
| 1 | 10,780,005,021 | 6,995,089,720–7,030,309,035 |
| 2 | 8,380,853,904 | 1,788,907,721–1,822,466,697 |
| 3 | 8,316,277,880 | 1,800,995,959–1,837,543,220 |

The median is 8,380,853,904 for Vox and 1,800,995,959 for Brave's lower bound.
The strict worst-Vox/best-Brave ratio is 6.026, above the required 0.90. No first
trial was discarded. On this 18-CPU host, the one-minute load average falls
from 72.897 to 60.487 during the trials; the full load averages and timestamps
remain in the host records. These observations do not isolate an optimization
gain. The instruction gate and enclosing guard exit one; the guard's sampled
peak is 4,227,776,512 bytes. The 10% target remains open and cumulative verified
instruction-saving credit remains zero.

The separate `Build/hn-small-text/profile-6` diagnostic succeeds with the same
executable and exact pixels. Of 412 sampled main-install stacks, 155 include
`Font.system_face`; 115 end in `access` and 37 in environment lookup. The
diagnostic identifies repeated font queries for investigation. Sampling is not
an instruction measurement and receives no performance credit.

## Constrained table-column measurements

Commit `c41ca812` omits a max-content probe for constrained columns whose final
maximum is derived only from their specified width and min-content result.
Unconstrained columns retain both intrinsic probes, and fixed-layout columns
retain their existing direct path. The three focused cases cover both font
policies, separate and collapsed borders, both box-sizing modes, and the
unconstrained and fixed-layout fallbacks. They also compare the result against
the same calculation after populating the previously unused max-content cache.

`Build/hn-small-text/column-width-1/results.json` records successful compilation
and execution in Boehm and preallocated no-GC modes: six case executions, with
both compiler exits and both runtime exits zero and unchanged checked sources.
The enclosing 12 GiB guard exits zero, with a sampled peak aggregate RSS of
9,035,874,304 bytes and elapsed time of 340.400 seconds. Both runtime checks
also pass their separate 3 GiB guards. Production eligibility, pixels and
instruction savings require separate validation; no savings are credited by
these focused tests.

The first rendered-ASCII-cache test attempt is retained in
`Build/hn-small-text/ascii-text-1/`. Its compiler exits zero and its Boehm runtime
exits one because the test incorrectly expected a V string slice to borrow
the original bytes. V's string slicing allocates and copies; the invalid
pointer-identity assertion was removed. The implementation continues to return
owned strings. That failed attempt did not execute its preallocated variant;
the corrected tests are rerun separately.

Commit `0087357b` caches ASCII classification alongside the rendered text and
clears it through the existing text invalidation hook. Fragment slicing uses
that classification; non-ASCII text retains the UTF-16 path. The seven focused
cases in `Build/hn-small-text/ascii-text-2/` pass in both Boehm and preallocated
no-GC modes: fourteen case executions, both compiler exits zero, both runtime
exits zero, and unchanged checked source hashes. Coverage includes transformed
first-letter ranges, cached and uncached fragment offsets, malformed UTF-8,
combining sequences, emoji and live DOM text replacement. The enclosing guard
exits zero, with sampled peak aggregate RSS of 9,096,560,640 bytes and elapsed
time of 328.258 seconds; both separate 3 GiB runtime guards also exit zero.
These focused checks establish behavior, not a measured instruction reduction.

## Font and grapheme lookup follow-up

Commit `e9c99daf` reuses an already resolved non-legacy font face when computing
Chromium inline ascent. Legacy faces, explicit overrides and unresolved faces
retain the live policy lookup. Four new cases compare the shortcut with the
previous calculation across cached families, overrides, test-font policies,
heights and fractional metrics. Together with the existing inline and cached
pixel-metric cases, all sixteen case executions pass in Boehm and preallocated
no-GC modes. All six compile/runtime pairs exit zero, with unchanged checked
platform sources and successful separate 3 GiB runtime guards. Receipts are in
`Build/hn-small-text/font-cache-1/`.

Commit `c9c84ace` uses binary searches over the node's sorted grapheme boundaries
when splitting overflowing text. The selected interval borrows the immutable
cached array; rendered-text invalidation replaces that array. Membership checks
also avoid rebuilding a boundary map for every split. Three new cases cover
boundary vectors and ranges, retained-array ownership through invalidation and
collection, and repeated splits compared with the previous implementation.
All nine cases pass in both memory modes: eighteen case executions, both compiler
exits zero, both runtime exits zero and both separate 3 GiB runtime guards zero.

The combined queue stops before the production build because its deliberately
broad source guard detects changes to five unrelated files during the second
grapheme compilation. The original failure remains recorded in
`font-and-ascii-production-1-guard.json` (child exit one) and
`grapheme-range-1/results.json`. The subsequent
`grapheme-range-1/input-scope-audit.json` checks the compiler's source-selection
rules: those files belong to the browser's root `main` module or are unselected
test files. All other 5,042 checked source hashes match before compilation,
after compilation and at audit time in both modes. The audit preserves the
original failed guard instead of changing its result. Production rendering,
fast-path eligibility and instruction checks resume separately. Verified
instruction-saving credit remains zero; the 10% target remains open.

## Production follow-up attempts

The three subsequent production attempts retain their original failures under
`Build/hn-small-text/`; none supplies additional rendering or performance credit.

| Attempt | Result | Guard elapsed | Sampled peak RSS |
| --- | --- | ---: | ---: |
| `ascii-production-1` | Build exits zero; source guard exits one | 384.073 s | 7,633,960,960 bytes |
| `ascii-production-2` | Focused-input continuity check exits one before building | 1.727 s | 32,997,376 bytes |
| `ascii-production-3` | Build and enclosing guard exit one | 29.567 s | 452,476,928 bytes |

All three guards complete within their 12 GiB limits. Attempt one's report is
`ascii-production-1-resume-guard.json`. Its source manifest catches concurrent
changes to the native renderer, its shape-batch header and a standalone native
test. The resulting bundle is not accepted as a pinned production candidate.
Attempt two's conservative focused-test audit catches two unselected test files;
the later audit follows the compiler's actual test-file selection instead.

Attempt three freezes the native renderer inputs. Its temporary compiler proxy
changes CMake's cached compiler identity, causing CMake to discard the supplied
options and configure Dawn again with default Debug/dependency settings. The
dependency configuration fails before the V browser build. Its before/after
source manifests are identical. The next preparation uses the real absolute
compiler paths and a fresh generated CMake cache, preserving the production
configuration options. This is a correction to the local evidence harness;
the repository's production build driver is unchanged.

The separate `profile-6-font-policy-source-audit.json` confirms that the earlier
profile used executable SHA256
`fc13e8102e770e061b2fe591a73698fc2c31d07a8611eff3eae5fa02d5301d1f`.
Static disassembly shows an unconditional filesystem check after environment
lookup in that binary's `Font.system_face`. Current source skips that check when
the layout-test font path is empty. The old profile therefore does not establish
that this syscall remains a hot spot in a newly built candidate. This diagnostic
receives no instruction credit. The last valid strict Vox/Brave ratio remains
6.026 against the required 0.90.

## Production pixels and authenticated instruction rerun

The accepted `ascii-production-5` candidate has executable SHA256
`65cceaf15ce9a1ece46f3e28feff4b4af94d0adbb985290e0983d8df6f375ab8`.
Its provenance authenticates a shared, successfully guarded production build,
the complete matching source manifests, compiler, native libraries, build
configuration and bundle signature. All three raw native DPR2 captures match
the immutable Brave pixels with zero differing pixels: the comment opener,
the complete 1024 by 768 discussion viewport, and the inline-precision fixture.
Startup and fresh-process checks of both live URLs exit zero and pass document
identity checks. The corrected live comment screenshot is
`Build/hn-small-text/ascii-production-5/live-comment/document.png`.

The separate eligibility probe also exits zero, preserves exact pixels and
authenticates the loaded executable and symbol ranges. It observes 836 column
measurements, including two constrained-auto columns, and the expected 834
max-content probes; cached font and grapheme lookup paths execute. These
instrumented observations supply no performance credit.

The original attempt-five instruction cohort is invalid: macOS maps one Brave
root executable through a `code_sign_clone` directory outside its private app.
The harness rejects that root even though the other coalition members are
accepted. Its failed guard and every observation remain unchanged.
Commit `f099a1ae` authenticates this macOS mapping only for the measured root:
the original argv, bundle-derived exact clone path and executable SHA256 must
all agree. Helpers still require their original exact ownership checks. Ten
harness unit cases pass, including altered-byte, path, argv and helper rejection.

The fresh complete cohort in
`Build/hn-small-text/ascii-production-6-instructions/` passes all six browser
exits, full 101-comment identity checks and exact pixel comparisons. It fails
the instruction target:

| Alternating pair | Vox instructions | Brave instruction interval |
| --- | ---: | ---: |
| 1, Vox then Brave | 12,107,859,595 | 7,010,099,223–7,033,723,193 |
| 2, Brave then Vox | 7,036,003,946 | 1,796,563,851–1,835,999,057 |
| 3, Vox then Brave | 7,075,890,507 | 1,797,023,591–1,830,534,409 |

The strict worst-Vox/best-Brave-lower-bound ratio is **6.739454**, against the
required **0.90**. Medians are 7,075,890,507 and 1,797,023,591 respectively.
The cold first pair is retained. This measures the documented navigation-to-PNG
capture workflow with different internal browser endpoints, including exclusive
coalition work; it is not an identical internal layout-only comparison.
The 18-CPU host's one-minute load averages are 10.295 before and 10.907 after.
The 12 GiB guard completes with child exit one because the target fails, elapsed
35.425 seconds and sampled peak aggregate RSS 134,774,784 bytes. This is a valid
negative result, not a passing performance claim or isolated optimization credit.

The separately gated `profile-9` diagnostic authenticates the same executable,
exits zero and retains exact pixels. Of 149 installation stack samples, 25 end
in libc environment lookup. Sample counts guide the next optimization; they
are not retired instruction counts. Verified isolated savings remain zero,
and the 10% instruction target remains open.


## Per-layout font-policy snapshot

Commit `cc5ba890` snapshots `LADYBIRD_LAYOUT_TEST_FONT` for one synchronous
layout pass, including nested work on that thread. Unscoped lookups remain
live, and a new outer pass observes environment and file changes. This removes
repeated environment scans from cached font-face queries without extending the
snapshot across document updates or sharing it with another thread.

The focused `font-policy-1` and `font-policy-layout-2` receipts record 14 cases
executed in both Boehm and prealloc/no-GC modes: 28 passing case executions.
They cover nested scopes, idempotent cleanup, early returns, thread isolation,
file and environment changes, cached font resolution, existing inline/font
metrics, and the anonymous comment opener at device scales 1, 2, then 1.
The source manifests remain unchanged during all accepted checks. The layout
check's 12 GiB guard records peak sampled aggregate RSS 9,099,018,240 bytes;
focused runtime children use 3 GiB guards. The earlier layout-one preparation
attempt was interrupted before a compiler or test started; it receives no test
credit and its termination receipt remains available.

The separate `font-policy-count-probe` diagnostic makes 16,384 warmed
`Font.system_face()` calls per observation, in ten alternating control/candidate
pairs. All 20 observations validate their resolved font and checksum. Median
retired instructions fall from 15,556,566 to 1,057,677.5, a 93.201% component
reduction. This is neither a full-page measurement nor Brave target acceptance;
verified whole-page credit remains zero pending a matched page comparison.

Production attempt one stops before browser compilation because its compiler
wrapper directory lacks the V library link required by UI staging. Build exit
one, unchanged source manifests and the guard receipt are preserved under
`Build/hn-small-text/font-policy-production-1/`. The replacement wrapper supplies
that link and logs the production C compiler command without adding output to
the staging scripts' compiler-root probes.

Production attempt two completes the official current-V/prealloc build with
unchanged source and compiler manifests. The pinned executable SHA256 is
`8c3d7d76fbde694a98d9edaf748d0794229f1e2fff6cd8ec9320ad10cb986c92`.
All three raw DPR2 comparisons (the comment opener, complete 50231722 viewport,
and device-layout inline precision) have zero differing pixels. Startup exits
zero, as do fresh live-discussion PID 67189 and live-comment PID 67287; their
URL, title and comment identities validate. The latter screenshot, inspected
visually, is `font-policy-production-2/live-comment/document.png` beneath
`Build/hn-small-text/` and displays the opening sentence at the correct size.

All six authenticated browser trials pass pixel and full-comment identity
checks. The instruction target fails:

| Pair | Vox instructions | Brave lower–upper bound |
| --- | ---: | ---: |
| 1 | 7,947,671,569 | 6,949,226,698–7,002,564,981 |
| 2 | 6,817,817,749 | 1,788,256,601–1,837,530,369 |
| 3 | 6,801,397,820 | 1,778,207,780–1,822,742,471 |

The strict all-trial worst-Vox/best-Brave ratio is 4.469484, above 0.90.
These use the same capture-workflow endpoint and limitations described above;
they do not isolate the font-policy change from other repository changes.
The cold first pair is retained. The outer 12 GiB guard records 366.095 seconds,
peak sampled aggregate RSS 10,690,166,784 bytes and child exit one because the
performance gate fails. Detailed build, launch, comparison and count receipts
remain under `Build/hn-small-text/font-policy-production-2/` and its guard JSON.
The Brave target remains open, with zero isolated whole-page optimization
credit at this checkpoint.

The follow-up checksum change (`0e233aa4`) keeps the complete padded-table
bounds check, then reads its big-endian words directly instead of repeating
optional-result construction and bounds checks for every word. Three focused
cases cover unaligned offsets, stored padding, wrapping sums, excluded `head`
checksums, empty tables, invalid ranges, and truncated directories. These and
the fallback metrics, BMP cmap, and layout font-policy tests pass: four files,
17 cases per mode, 34 executed cases across Boehm and preallocated/no-GC builds.
Every compile and guarded runtime exits zero and the platform source hashes
remain unchanged. Receipts are in `Build/hn-small-text/font-checksum-1/`; its
outer guard exits zero, peaks at 420,872,192 sampled RSS bytes, and completes
in 20.915 seconds. This supplies correctness evidence, with no whole-page
instruction credit yet.

The separate `profile-10` diagnostic uses the retained production-2 executable
and frozen page. Browser and sampler exit zero, its screenshot remains exact,
and the executable hash is unchanged. Its first installation/relayout subtree
contains 130 samples; environment lookup accounts for two self samples, versus
25 of 149 in the earlier profile. Repeated temporary font decoding and
style/layout construction remain visible. These samples do not measure retired
instruction savings. The guard exits zero, peaks at 494,518,272 sampled RSS
bytes, and completes in 29.387 seconds.

The first isolated font-policy rebuild fails compilation: a concurrent native
header introduces a field named `complex`, conflicting with the system macro.
The failed attempt and actual exit 1 remain under `font-policy-isolated-1`.
The retry recovers native source bytes against the production-2 source manifest
and uses a private Clang filesystem overlay for both builds; it does not edit
the concurrent native work. Its matched measurements and the checksum
comparison remain pending. The latest accepted Brave comparison is still the
production-2 result above; the 10% instruction target remains open.

The completed isolated comparisons supersede the pending measurements above.
Each uses 30 fresh, alternating control/candidate pairs on the frozen
101-comment page at 1024×768 CSS pixels and DPR2. All 180 browser observations
exit zero, authenticate the complete comment identity, and have zero differing
pixels against the same Brave reference. They measure navigation through PNG
availability, using the existing capture workflow, and compare Vox with Vox.
They do not establish the requested 0.90 Vox/Brave instruction ratio.

| Isolated change | Control median | Candidate median | Median paired saving | Bootstrap 95% interval for paired median saving |
| --- | ---: | ---: | ---: | ---: |
| Per-layout font-policy snapshot | 7,053,785,695.5 | 6,737,573,321 | 318,385,728.5 | 284,260,090.5–329,758,776.5 |
| Word-at-a-time font checksums | 6,749,256,353.5 | 6,582,938,198.5 | 163,878,506.5 | 155,797,834.5–169,317,279 |
| Normalized font directory initialization | 6,572,910,729 | 6,442,902,600.5 | 123,156,624.5 | 111,310,963.5–146,179,732.5 |

The fixed-seed bootstrap uses 10,000 resamples. Its lower endpoints provide
284,260,090.5, 155,797,834.5, and 111,310,963.5 instructions of repeatable
marginal page credit respectively. These are separate comparisons with
successive controls; their intervals must not be added and described as a
joint confidence interval. The respective winning-pair counts are 30, 30,
and 29. Every cold trial is retained, including the normalized candidate's
first-pair regression of 1,279,568,534 instructions. Strict worst-candidate /
best-control ratios are 1.122431, 0.990556, and 1.210301; the paired reductions
do not imply an all-trial speed guarantee.

The frozen production-C builds change only the tested implementation regions.
All remaining C bytes, compiler arguments, native inputs, and page assets are
pinned. The policy build freezes 1,901 native/header/archive inputs, recovering
concurrent native files from the accepted production source manifest without
editing that work. The normalized comparison adds its tested directory helper
and replaces the initializer call; its complete generated-C diff is 1,632 bytes.
Detailed per-trial counts, launch identities, host loads, pixel checks, build
commands, source manifests, and all failed attempts remain under:

- `Build/hn-small-text/font-policy-isolated-2/`
- `Build/hn-small-text/font-checksum-isolated-3/`
- `Build/hn-small-text/font-normalized-isolated-3/`

Their outer guards exit zero, with elapsed times of 440.818, 201.606, and
337.426 seconds and sampled peak aggregate RSS of 5,501,468,672, 119,504,896,
and 5,210,947,584 bytes. LaunchServices-spawned browser work can fall outside
the guard's process-tree RSS sample; coalition instruction counting retains
its separate browser ownership checks. Each host has 18 CPUs. Final load
averages are respectively 4.411/5.260/6.994, 4.823/4.990/5.768, and
5.068/6.257/6.801. The first checksum build's disk-full failure and the next
attempt's ambient-proxy rejection remain retained without acceptance credit.
The normalized source-pin failures also remain retained; the third attempt's
before/after manifests match.

Commit `47e479cf` removes the immediate duplicate checksum verification only
for a bounds-checked sfnt buffer already normalized by `decode_outline_face()`.
It retains metadata, outlines, kerning, and the ordinary initializer's
validation contract. Five Python generator checks and 22 focused V cases in
each of Boehm and prealloc/no-GC modes pass, including exact comparison of the
normalized and complete initialization results. All compiler and guarded
runtime exits are zero. These receipts are in `font-normalized-init-1/`.

The instruction reduction crosses the broad-verification threshold. The
unchanged official LibJS AST driver compares all 100 current upstream fixtures
exactly with `--all` and no case overrides (`font-broad-ast-1`, guard exit zero,
4.219 seconds, peak sampled RSS 589,742,080 bytes). The remaining selected
CSS/layout/SVG/platform cases and 19 screenshot comparisons are being
completed as a composed checkpoint. Initial preparation failures, a missing
embedded data file, and compiler compatibility errors in existing fixtures
receive no whole-suite pass credit; passing files will not be repeated.
The latest accepted complete Brave cohort remains production attempt two:
strict ratio **4.469484**, required **0.90**. The user’s instruction target
remains open.


The composed font checkpoint is now complete, with known baseline failures
retained. It executes 466 selected cases in each GC mode (932 executions):
150 CSS, 79 SVG, 208 platform, and 29 layout. Of these, 926 pass. The remaining
three layout assertions fail in both modes with exactly the same values after
restoring all three measured font changes to their parent implementations:

- Nested block/flex inline baseline fixture: height 768, expected 64.
- Chromium text-control baseline fixture: 13.5, expected 13.
- Projected control intrinsic width fixture: 165.5, expected 166.

No assertion is relaxed. `font-broad-layout-comparison-1/result.json` records
the comparison of the complete failure diagnostics; both source manifests
remain unchanged. The baseline and candidate guards both exit one because
those assertions fail (106.469/106.630 seconds, peak sampled RSS
9,253,371,904/9,217,966,080 bytes). This is regression attribution, not a
whole-suite pass. The anonymous ownership test now avoids reading a native
arena in the ordinary Boehm build, while retaining the preallocated arena
bounds and release checks; it passes in both configurations.

The composed receipts are `font-broad-4` (412 passing platform executions),
`font-broad-platform-assets-1` (four remaining platform executions after
restoring omitted WOFF assets), `font-broad-css-2` (300),
`font-broad-layout-svg-1` (158 SVG), and `font-broad-layout-2` (52 passing
layout executions and six baseline failures). The SVG fixture's explicit
image pointer and the font fixtures' GC ownership corrections are committed
separately. Initial failing attempts remain available.

The 19 screenshot comparisons complete: 13 are exact, one passes its existing
bounds, and five fail. A matched pre-font control has identical actual and
reference pixels for each failing case (`inline-node`, `ordered-list`,
`text-decorations`, `abspos-inside-opacity-inside-relpos`, and
`select-line-height-ignored`). Receipts are `font-normalized-visual-1` and
`font-visual-baseline-1`; no bounds change. The three Hacker News comparisons
remain pixel-exact, startup passes, and fresh live discussion/comment launches
exit zero with authenticated document identities. The inspected corrected
comment screenshot is `font-normalized-visual-1/live-comment/document.png`.
This validates the frozen generated-C candidate; it is not a fresh build of
later independent canonical changes.

The unchanged `--all` AST driver passes all 100 fixtures as recorded above.
The checkpoint covers the three measured font optimizations through
`47e479cf`; subsequent isolated candidates start a new verification interval.
It does not replace the latest complete Brave cohort: strict ratio
**4.469484**, required **0.90**, with the instruction target still open.


The borrowed-value projection fast path inspects the retained typed value before
converting it to the CSS value union. Dimensionless values and zero CSS pixels
remain shared with the cloned property store. Border-width keywords, nonzero
lengths, nested values, and untyped values retain the existing projection path.
The tests cover pointer identity, nested transform lengths, untyped calculations,
border keywords, animation values, and invalidation after a source mutation.
All 32 focused executions pass across Boehm and preallocated/no-GC modes
(`borrowed-projection-2`, unchanged source manifests).

The isolated comparison changes only the tested projection functions and their
helper/prototypes in frozen production C. It preserves the independent production
raw-generation initializer and verifies identical shared record layouts.
`borrowed-projection-isolated-5` retains 30 alternating matched pairs, all 60
actual-zero browser exits, exact captures, and all 101 expected comment rows.
Control/candidate instruction medians are 6,474,586,348/6,452,940,969. The paired
median saving is 18,177,258.5 instructions; its seeded 10,000-resample bootstrap
95% interval is [12,252,661.5, 27,509,165]. The lower bound supplies
12,252,661.5 repeatable page credit for this verification interval.

There are 21 improving pairs and nine regressions. The first cold candidate
uses 8,248,461,327 instructions against 6,480,835,105 for its control; that
1,767,626,222-instruction regression is retained. Control counts span
6,393,078,551–6,557,591,850 and candidate counts
6,384,823,477–8,248,461,327. The strict candidate/control ratio is 1.290217;
this is a Vox/Vox experiment, not Brave acceptance. The 18-CPU host runs other
builds. The first control load averages are 10.088/9.635/4.698, with
9.739/10.164/6.135 at completion; contention and the cold outlier limit causal
claims beyond the paired result. The outer guard exits zero after 339.224
seconds, with sampled peak RSS 5,311,414,272 bytes. All build/native/source
pins remain unchanged. Earlier failed or incomplete attempts retain their
actual receipts and receive zero acceptance credit.

The projection checkpoint executes 152 CSS, 29 layout, and 79 SVG cases in
each GC mode (520 executions): 514 pass. The same three layout assertions
listed above fail in both modes, with complete diagnostics identical to the
prior checkpoint and a byte-identical merged layout fixture (SHA256
`1da462776e329bbf66ee6c5b97a17a91d9cee859c78256a4cfe608576b4b5c61`).
`projection-broad-comparison-1/result.json` records successful regression
attribution; the full selected suite still fails. All source manifests remain
unchanged. The guard exits one after 293.796 seconds with peak sampled RSS
9,192,620,032 bytes. The unchanged 208 platform cases per mode carry from the
preceding checkpoint; they are not rerun or counted among these 520 executions.

All 19 screenshot comparisons complete for this projection candidate: 13 exact,
one within its existing bounds, and the five known failures unchanged. All 34
actual/reference images compare pixel-exact with the preceding font candidate
(`projection-visual-1/control-comparisons.json`). All three Hacker News fixtures
remain exact at their native 2x capture scale; signature verification, startup,
and both fresh live document checks exit zero. The corrected opening sentence
is visibly the same size as the rest of the comment in the inspected
`projection-visual-1/live-comment/document.png`. The unchanged official LibJS
AST driver matches all 100 current upstream fixtures with `--all` and no case
overrides (`projection-broad-ast-1`). Both checks retain unchanged input pins.
This completes the projection checkpoint through `2a695111` with the baseline
failures above retained; it does not establish a whole-suite pass or the Brave
instruction target.

The subsequent canonical production build also passes all three native-scale
Hacker News comparisons, signature verification, startup, and fresh live
discussion/comment checks (`projection-production-1`). Its executable SHA256 is
`309468f5235acd8a1f388e311dcf0f1d8c7f7d5fb5d0ea6c44b71bdbc1cbc2e8`;
the authenticated build manifest is
`72daefe83187a90d258ab746455966aaa1cc1c23497b872216420c07f1cb650d`.
The inspected corrected screenshot is
`projection-production-1/live-comment/document.png`. The build includes
independent native changes, with eight subsequently changed input paths recorded
separately; neither the current HEAD alone nor this comparison isolates the
projection optimization. All validation pins remain unchanged during this run.

The unchanged official Brave tool completes three alternating pairs: all six
browser exits are zero, every capture is exact, and all 101 expected comment rows
are present. Vox's median is 6,480,116,123 instructions; Brave's median lower
bound is 1,774,843,916. The strict largest-Vox/smallest-Brave ratio is
**3.656719**, against the required **0.90**. Brave's first, cold observation is
also retained ([6,954,944,577, 7,010,257,106] instructions); the other two bounds
are [1,774,843,916, 1,815,172,170] and [1,774,507,731, 1,821,439,998].
The previously documented endpoint asymmetry remains. The guard exits one
because the performance target fails, after 57.261 seconds with peak sampled
RSS 1,258,995,712 bytes. Pixel/live validation passes, isolated optimization
credit is zero, and the 10%-below-Brave instruction target remains open.

The invariant-compound projection optimization recursively borrows lists,
background sizes, radii, positions, and text indents only when their complete
absolutized values are identical at every coordinate scale. Relative lengths,
nonzero absolute lengths, calculations, unresolved edges, system colors,
transforms (including number-only matrices), and NaN values retain ordinary
dispatch. Typed and parser-created values use the same proof; no source
property graph is mutated. The two new cases also check nested replacement
and all three scales, 0.5, 2, and 3.

`invariant-projection-2` passes 18 focused cases in both GC modes (36
executions), with compile/runtime/guard exits zero and unchanged input pins.
Its guard takes 74.103 seconds with peak sampled RSS 3,506,356,224 bytes.
The retained `invariant-projection-1` attempt fails compilation because of an
extra closing parenthesis in the new fixture; no test runs or credit came
from that attempt. The correction changes only the fixture construction.

`invariant-projection-isolated-1` transplants only the two tested projection
function bodies and two new helpers into the preceding accepted production C.
All 12 shared record declarations match. Removing the helper definitions and
prototypes and restoring the two original bodies reconstructs the complete
control C byte for byte; the production graph-token initializer is preserved.
No independent canonical changes enter this experiment. Signature verification
and startup pass, and all compiler/native/source pins remain unchanged.

All 30 alternating matched pairs complete (60 zero browser exits), each with
101 comment rows and an exact 3,145,728-pixel image. Control and candidate
medians are 6,458,624,202 and 6,335,498,326 instructions. The median paired
saving is 124,666,130.5; its seeded 10,000-resample 95% interval is
[112,351,039.5, 136,783,443.5]. Conservative repeatable credit is
112,351,039.5, crossing the 5M broad-checkpoint threshold. All 30 pairs improve;
the smallest paired saving is 14,577,396. Every raw observation is retained.
The first cold control/candidate counts are 11,221,218,469 and 7,870,452,184;
control counts span 6,407,221,380–11,221,218,469 and candidate counts
6,275,182,163–7,870,452,184. The strict worst-candidate/best-control ratio is
1.228372. These are Vox/Vox diagnostics, not Brave acceptance. The 18-CPU host
load averages are 3.231/5.072/6.797 before the first control and
2.725/3.962/5.956 at completion; cold-start and host variation limit causal
claims beyond the paired result. The guard exits zero after 292.997 seconds
with peak sampled RSS 5,251,006,464 bytes.

The completed checkpoint for `55ce0a17` carries those 18 focused cases per GC
mode and freshly executes 136 CSS, 29 layout and 79 SVG cases per mode: 488
new executions and a disjoint union of 524. Of that union, 518 pass; the same
three layout assertions fail in each mode. All six broad compilations pass,
and CSS/SVG runtimes pass. The complete normalized layout diagnostics and
merged layout fixture are byte-identical to the preceding checkpoint (fixture
SHA256 `1da462776e329bbf66ee6c5b97a17a91d9cee859c78256a4cfe608576b4b5c61`).
The broad child exits one for those known failures; the checkpoint supervisor
accepts the unchanged regression comparison, not a whole-suite pass. The
unchanged 208 platform cases per mode carry prior evidence and are not new
executions (`invariant-projection-broad-1`,
`invariant-projection-broad-comparison-1`).

All 19 screenshot comparisons retain their preceding results: 13 exact, one
within existing bounds and five unchanged known failures. All 34 actual and
reference images are pixel-identical to the preceding checkpoint. All three
Hacker News fixtures remain exact at native 2x scale. Signature verification,
startup and both fresh live discussion/comment checks pass. The inspected
`invariant-projection-visual-1/live-comment/document.png` shows the opening
sentence at the corrected body size. These captures use the frozen measured
candidate, not a newly built canonical production bundle. The unchanged
LibJS AST driver matches all 100 current upstream fixtures with `--all` and
no overrides (`invariant-projection-broad-ast-1`). All validation source pins
remain unchanged.

The checkpoint supervisor and guard exit zero after 418.319 seconds, with
sampled peak RSS 9,286,844,416 bytes
(`invariant-projection-checkpoint-1`). This completes the required checkpoint
through `55ce0a17`; the next optimization starts a fresh credit interval.
The latest official production/Brave comparison remains the 3.656719 strict
ratio above. The 10%-below-Brave target remains open.

The used-color-scheme projection fix (`126a8656`) avoids constructing a
color-resolution context when projection needs only the already computed scheme.
Its focused 19 cases pass in each GC mode (38 executions), including the retained
prealloc recovery after the first guarded compile failed. The sealed focused
inputs and the exact single-body generated-C transplant remain authenticated;
all 12 shared record layouts match and reverse transplantation reproduces the
whole control C byte for byte (`scheme-projection-3`,
`scheme-projection-sealed-handoff-1`, `scheme-projection-isolated-1`).

All 30 alternating control/candidate pairs complete with 60 zero browser exits,
101 comments and pixel-exact 3,145,728-pixel captures. Control/candidate medians
are 6,358,800,315 and 6,364,877,356 instructions. The paired median saving is
negative: -2,061,960 instructions; its seeded 10,000-resample 95% interval is
[-14,202,742, 10,769,069.5]. Fourteen pairs improve; the worst pair regresses by
1,286,780,493 instructions. Repeatable performance credit is **zero**. The strict
worst-candidate/best-control ratio is 1.234392; this remains a Vox/Vox diagnostic,
not a Brave acceptance run. All observations, including regressions, are retained
under `scheme-projection-isolated-1/paired`.

The 18-CPU host is heavily contended: load averages start at
107.843/87.736/66.172 and end at 86.726/98.709/82.247. This run does not establish
a causal improvement. The required broad checkpoint is deferred below the 5M
cumulative reduction gate, with signed accumulated savings -14,202,742 since the
preceding invariant-projection checkpoint. The followup supervisor and its guard
exit zero after 1,013.811 seconds, with sampled peak RSS 5,310,988,288 bytes;
that duration includes the independent lazy-context focused checks below.

The lazy length-context fix (`5dc544d5`) resolves absolute units using only the
coordinate scale and constructs a full font/viewport context only when a value
requires it. Its two new differential cases compare nine absolute units and
11 relative/nested value forms at four scales against the full resolver, while
checking source immutability. All 21 focused cases pass in each GC mode (42
executions), with compiler/runtime exits zero and unchanged input pins
(`lazy-length-context-1`). Its sealed input handoff preserves the exact tested
bytes before the next font-cache candidate.

Its isolated 30-pair comparison completes with 60 zero browser exits, all 101
comments and exact 3,145,728-pixel captures (`lazy-length-context-isolated-1`).
The control/candidate medians are 6,343,878,613.5 and 6,352,038,907.5 instructions.
The paired median saving is -990,330.5 instructions, with seeded 10,000-resample
95% interval [-20,805,073, 12,549,517.5]. Fifteen pairs improve; the worst pair
regresses by 83,339,233 instructions. Repeatable performance credit is **zero**.
The strict worst-candidate/best-control ratio is 1.019877, a Vox/Vox diagnostic
that does not establish Brave acceptance. On the 18-CPU host, load averages move
from 10.272/17.757/26.463 to 16.370/18.769/25.050. All source pins remain unchanged,
all 12 audited shared records match, and reversing the single tested body
reconstructs the whole control C byte for byte. The production graph-token
initializer retains both generation fields. The signed cumulative lower bounds
since the preceding broad checkpoint total -35,007,815 instructions, below the
5M gate; no new broad checkpoint is due.

The `lazy-length-context-followup-1` supervisor exits zero. Its enclosing
`lazy-font-intrinsic-followup-1` job exits one after 425.457 seconds, with sampled
peak RSS 9,127,936,000 bytes, because the independent font/inline focused checks
failed. Font attempt 2 fails compilation on an immutable range field; the next
fixture replaces the complete entry. Inline attempt 2 compiles and fails its
unsupported-tab assertion: normal whitespace handling has already collapsed
that tab to a supported space. The corrected fixture compares that case with
the full width algorithm and retains a preserved-tab fallback case. Neither
failed attempt earns test or performance credit; their raw receipts remain
under `font-cascade-projection-2` and `intrinsic-inline-2`. Corrected focused
checks are pending. The official 10%-below-Brave target remains open at the
preceding 3.656719 strict ratio.

The physical font-cascade cache (`52b6f5fc`) now passes its corrected focused
checks: 32 cases in each GC configuration, with both compilers and runtimes
exiting zero and all input pins unchanged (`font-cascade-projection-3`). The
committed implementation and tests match the tested snapshot byte for byte.
The cache checks native face identity, size, axes, features, ranges, fallback and
pending-face state before reuse. Preallocated projections stay within their
allocation owner; mutable state and owner retirement invalidate reuse. Tests
also exercise 1,024 repeated projections without new allocations or native
font handles. The isolated page comparison has not run, so this fix receives
no instruction-count credit yet.

The next inline-width candidate passes all 21 normal-GC focused cases. Its
preallocation compiler exits one while writing generated C with `No space left
on device`; that configuration runs no tests (`intrinsic-inline-3`). The
`font-intrinsic-measurements-1` supervisor and guard consequently exit one
(1,617.326 seconds, peak sampled RSS 9,149,202,432 bytes). All 3,341 sealed
inputs remain unchanged after the failure. A separate retry retains the
successful normal-GC evidence and original failure, and retries only the
unfinished configuration. That candidate is not committed or credited yet.
Completed artifacts were compressed with SHA256-verified restoration before
removing their uncompressed copies; raw logs and archive ledgers remain under
`Build/hn-small-text`. The official Brave target remains unmet.


The inline-width retry now passes (`0aa4506a`). The retained normal-GC run and
fresh preallocated/no-GC run each compile and execute all 21 focused cases,
for 42 passing executions. The retry runtime exits zero, peaks at 138,166,272
sampled RSS bytes under its 3 GiB guard, and takes 3.754 seconds. All 3,341
sealed inputs remain unchanged, and the three committed files match the tested
snapshot byte for byte. Ordinary supported inline text now measures minimum
and maximum content widths together, preserving projected text rounding;
unsupported containers, bidi, spacing and atomic content retain full layout.
The isolated page comparison is pending and supplies no instruction credit yet.

The Metal precision rewrite (`ef7c1e1e`) replaces two regular-expression passes
with one linear scan while retaining their byte-level substitutions. Its focused
release and ASan/UBSan builds each pass 23,699 differential cases against the
old expressions. Pristine installation, idempotency, authenticated legacy
upgrade, and atomic rejection of unknown or partial inputs also pass. The
focused guard exits zero after 77.327 seconds, with sampled peak RSS
499,351,552 bytes (`metal-precision-1`). The canonical files match the tested
snapshot. These component checks do not establish page instruction savings.

The first native comparison exits one before any build because its manifest
mixes 63 structured fingerprints with four plain SHA256 strings. All 67 content
hashes still match: this is a metadata-format failure, not changed source.
`metal-precision-build-input-seal-2` verifies every original digest, copies the
same bytes, and normalizes those four entries without relaxing verification.
The failed receipt is retained under `metal-precision-isolated-1`; the separate
retry carries the successful focused checks without replaying them.

Diagnostic `profile-14` has browser and sampler exits zero, exact page pixels,
unchanged input pins and the encoded-PNG endpoint marker, but an empty call
graph. Its validation and guard therefore exit one, with zero performance
credit. A separate profiler retry eagerly collects symbols and keeps the task
alive longer with explicitly diagnostic response and settle delays. Those
changed delays and all profiler counts are excluded from instruction acceptance.
Font, inline-width and native page comparisons remain pending. The last strict
production Vox/Brave ratio remains 3.656719, above the required 0.90.

The adaptive-encoder restoration passes `png-adaptive-restore-1`: all 27
pixel/profile/density/metadata cases execute under both ARC and non-ARC (54
cases), with byte-identical Cocoa output. Both actual native capture entry
points also pass their deferred-delivery, scale, lifetime and invalid-input
checks in both modes. The rescheduled 3 GiB guard exits zero in 4.726 seconds
with sampled peak RSS 183,320,576 bytes. This validates the restoration and
earns no new instruction credit.

The first intrinsic-restoration harness fails to compile because it overlays
newer context-shaping tests onto an older accepted source snapshot. Those tests
require an iterator method absent from that snapshot. No runtime success is
claimed. `intrinsic-inline-restore-2` also stops before compilation because
the selected-test snapshot omits the requested test files. The third harness
reads those tests from immutable revision `47e479cf`, matching the accepted
source and its iterator API. It verifies that the restored implementation is
byte-identical to the accepted snapshot. Both failed runs are retained;
`intrinsic-inline-restore-3` is queued and supplies no runtime validation yet.
The queued canonical production follow-ups are
deferred before starting while the next candidate is prepared; the focused
restoration check remains queued. The cancellation receipt is
`combined-production-2-followups-deferred.json`.

`profile-16` completes with unchanged inputs, browser and sampler exit zero,
and all 3,145,728 pixels exact. It samples the frozen inline-candidate app
(`e4f972e998b9ccd4afce23cc96c468f4faa5438df707e05fdda1591f7300b55d`)
after gating the document response for seven seconds. The 30-second sample
and 35-second capture delay are diagnostic settings, so this run earns zero
performance credit. Recursively overlapping style and layout stacks cannot
be interpreted as independent costs. The raw sample hash is
`00d88b0597e93051b9a2b05eac4adadfff278f58b80a06eaf0c3f936edb3b419`.

`png-filter-prototype-2` repeats the component diagnostic on the actual full
page and a reconstruction of the native premultiplied capture bitmap. All
48 encodings preserve decoded pixels and color profiles. For the reconstructed
bitmap, warm median encoding instructions are 374,309,979 for Cocoa,
548,405,324 for SUB, 326,543,338 for UP and 312,934,803 for NONE. NONE produces
383,892 bytes versus Cocoa's 416,388 on this fixture. These isolated counts
earn zero page credit. The next unfiltered candidate requires focused native
checks, an alternating 30-pair complete-page cohort, and broad verification
only if it establishes the required cumulative reduction.

The first font-cascade page comparison now retains all 30 alternating pairs
under `font-cascade-projection-isolated-1/paired`. It is invalid: pair 23's
control and pair 28's candidate fail the private-helper ownership check before
capture. The other 58 runs exit zero with exact pixels and exact instruction
intervals. No pairs are discarded and no savings are credited. The supervisor
and guard exit one; sampled peak RSS is 9,174,253,568 bytes, elapsed time
2,177.381 seconds. The candidate's compilation, strict bundle signature,
startup smoke check and compiler-input pins remain valid.

The ownership verifier now brackets its private-process and CDP queries with
the coalition's monotonic task counts (`25e629ca`). When a worker starts or
exits after the exact membership scan, it repeats the whole scan within the
original watchdog. Stable unaccounted private or CDP processes still fail;
no task instructions are subtracted and measurement endpoints stay unchanged.
All 15 focused Python tests pass, including five new cases for late fetch/CDP
workers, worker exit, foreign processes and bounded membership churn
(`coalition-ownership-race-2`, unchanged source pins). The interrupted first
test invocation also selected native pixel integration and was stopped during
a stale-bundle rebuild; it supplies no native validation or performance credit.
A fresh complete font cohort is required before accepting page savings.

The fresh cohort now passes all 30 alternating pairs with exact full-page
pixels and unchanged compiler and measurement inputs
(`font-cascade-projection-measurement-2`). Control and candidate medians are
6,410,157,343 and 6,320,903,084.5 instructions. The median paired saving is
93,890,866; its seeded bootstrap 95% interval is
[81,435,157.5, 101,455,208]. Twenty-nine pairs improve; the remaining pair
regresses by 20,902,046 instructions and is retained. The two preceding
projection changes have negative lower bounds totaling 35,007,815, so the
cumulative lower bound since the prior broad checkpoint is 46,427,342.5.
`font-cascade-projection-checkpoint-2` passes the required regression check:
546 selected executions across both GC modes include 540 passes and the same
six baseline failures, whose normalized diagnostics remain identical. All 100
upstream AST fixtures compare exactly. Nineteen visual comparisons retain
their previous outcomes and all 34 decoded control images; the three Brave
fixtures are pixel-exact, startup and both live identity checks exit zero,
and all input pins remain unchanged. The enclosing pipeline exits one only
after the next isolated inline candidate fails compilation because its new
caller references a helper absent from the control's generated C. No inline
page credit is assigned; the failed compile and its guard receipt remain
retained. The pipeline takes 753.840 seconds with sampled peak RSS
9,299,755,008 bytes (`font-intrinsic-measurements-3`).

The independent native Metal comparison completes 30 alternating exact-pixel
pairs (`metal-precision-isolated-2`). Control and candidate medians are
6,369,595,610.5 and 6,077,892,963.5 instructions; the median paired saving is
285,687,373, with bootstrap 95% interval [262,997,121, 315,309,335]. All 30
pairs improve, and the cold first candidate observation of 3,946,071,874
instructions remains in the raw cohort. Both libraries use the same frozen
native sources and flags apart from the authenticated precision patch. Both
bundles sign, verify and pass startup; four native pixel probes pass. The
original visual stage fails because the frozen HTML files lack their relative
CSS and image assets, despite its 19 broad outcomes, 34 decoded control images,
startup and two live checks remaining unchanged. The separate
`brave-fixture-seal-2` authenticates all three HTML files and four assets against
commit `02ba3207`. `metal-precision-visual-recovery-1` carries the successful
checks with their hashes and retries only the three corrected fixture
captures; all are pixel-exact, pins are unchanged and its guard exits zero
(9.005 seconds, peak RSS 262,488,064 bytes). The original failed result and
guard are preserved. This native branch's cumulative lower bound is
227,989,306 instructions; it does not include the independent font branch.

`profile-15` again has successful browser and sampler exits and exact page
pixels, but its samples do not establish the required installation call
graph. Its validation and guard exit one. The response/settle delays and all
profile observations remain diagnostic, with zero instruction credit.

Native screenshot encoding now uses ImageIO's fixed lossless SUB filter
(`4b4cdc23`) while retaining synchronous encoding before the existing
instruction endpoint. The focused prototype reduces median encoding work
from 947,871,049 to 360,162,919.5 instructions on the frozen page bitmap,
with identical decoded pixels and profile, and increases its file from
384,689 to 424,467 bytes. These component counts supply no page credit. The
first focused run catches extra default-resolution metadata. The correction
preserves Cocoa's omission at normal scale and its resolution tags at Retina
and fractional sizes. `png-focused-2` passes all 27 combinations of RGB/alpha
format, color profile and logical size in both ARC and non-ARC builds,
including exact decoded pixels, ICC, density and all non-image-data chunks;
it also verifies that every encoded row uses SUB. Its 3 GiB guard exits zero
after 1.480 seconds, peak RSS 146,915,328 bytes. The actual native entry-point
tests pass in both modes (`png-capture-idle-2`, guard zero, 1.951 seconds,
peak RSS 157,761,536 bytes), including deferred capture, retained pixels,
logical scale, invalid bounds, path lifetime and counting after complete
encoding. All source pins remain unchanged. The initial failure is retained;
the isolated page comparison is pending. The last strict production
Vox/Brave ratio is still 3.656719, above the required 0.90.

## Rejected full-page encoding and intrinsic experiments

The subsequent complete-page cohorts reject both experimental paths. Each
cohort contains 30 alternating control/candidate pairs, with fresh private
profiles, identical frozen full HTML and assets, and the original navigation
through synchronously encoded PNG endpoint. All 60 observations in each
cohort exit zero and retain exact reference pixels and authenticated inputs.
The `passed` field establishes cohort validity; neither result accepts the
Brave target or supplies instruction-saving credit.

| Experiment | Control median | Candidate median | Median paired saving | Bootstrap 95% interval | Improved pairs |
| --- | ---: | ---: | ---: | --- | ---: |
| `png-filter-isolated-2` | 6,318,984,293.5 | 6,473,094,414 | -158,153,091.5 | [-171,466,641, -134,312,907.5] | 0/30 |
| `intrinsic-inline-isolated-2` | 6,318,025,514 | 6,380,283,436.5 | -52,119,701.5 | [-82,164,340, -16,845,966] | 8/30 |

Every observation remains in the cohorts, including the inline experiment's
cold first-pair regression of 2,154,628,174 instructions. The host has 18 CPUs;
the respective ending load averages are [17.018, 16.162, 27.931] and
[31.413, 26.613, 28.117]. Negative results receive zero credit rather than
being attributed to reduced contention. The PNG cohort's guard exits zero
after 420.987 seconds with sampled peak RSS 4,990,582,784 bytes. Its queued
broad follow-up is cancelled before starting because no reduction was
established; the cancellation receipt and supervisor exit -15 are retained.

The actual complete-page PNG explains why the favorable component prototype
was insufficient. Cocoa's adaptive encoding produces 416,388 bytes, whereas
fixed SUB produces 461,476 bytes. On pair 20 the encoding stage retires
380,275,629 versus 553,120,848 instructions. The original prototype used a
different bitmap representation. The source is restored to Cocoa's adaptive
encoder, and the focused regression now requires byte-for-byte agreement with
Cocoa in addition to decoded pixels, profile and metadata. Its new focused
checks are pending; the rejected fixed-SUB observations remain unchanged.

The intrinsic one-pass helper is also removed, restoring
`layout/intrinsic_sizing.v` exactly to the parent of `0aa4506a`. The
`intrinsic-inline-measurements-5` pipeline exits zero after 1,054.815 seconds
with sampled peak RSS 5,769,101,312 bytes. It carries the already authenticated
font checkpoint, validates the negative inline cohort and diagnostic, and
skips broad verification below the cumulative reduction threshold. Its
running lower-bound balance is -82,164,340 instructions. Focused execution
checks of the restored path are recorded below.

`instruction-scopes-8` retains exact 2048 by 1536 pixels and unchanged inputs.
It observes 208 accepted inline probes and 3,375 font-projection cache hits.
The diagnostic records substantial style, table and inline work: style update
761,896,745 instructions, coordinate projection 450,455,938, layout-tree
construction 777,708,628 and completed layout 1,085,592,252. These scopes
overlap, include instrumentation and concurrent process work, and must not be
added together or used as acceptance counts. Three style/layout entries do
not imply three full rebuilds: later entries reuse the retained results.
This diagnostic supplies zero instruction credit. The last accepted strict
production Vox/Brave ratio remains 3.656719, above the required 0.90.


The shared completed production app is reused under `production-reuse-1`;
no additional production build is queued for this task. Its eight files match
both the installed app and the preserved successful production stage after
normalizing fingerprint keys to relative paths. The executable SHA256 is
`a1167c7abc73b8b0ac45f1d3eb0f5ace4f1b44375df75dff3108af46f0de2123`.
Strict signature verification succeeds. The earlier failed clone assertion
compared absolute paths in different directories, not different file contents.
`available-bundle.json` records the identities, source hashes and build receipt.

This bundle includes the anonymous-font fix but predates the integer-length
serializer and unfiltered-PNG candidates. Its prepared fresh-process check
covers the three frozen pixel fixtures, startup, both live pages and the Brave
instruction comparison. The first standard guard attempt exits 125 with
`reason: busy` before launching a browser; the same check is now queued under
`check-1-queued-guard.json`. No fresh rendering or performance result is claimed.
The two candidate test pipelines remain pending behind the shared guard and
receive zero credit. The last strict production ratio remains 3.656719;
the required ratio is at most 0.90.

## Pending serialization and parser experiments

`integer-length-focused-1` compiles in both modes and passes its 12 Boehm
cases, but the preallocated run fails the existing keyword-storage check:
one keyword conversion retains 28 unexpected bytes. Its guard exits 1 after
275.405 seconds, with peak RSS 3,506,651,136 bytes. Generated C shows that
passing the narrowed length by address makes V heap-copy the entire incoming
style value before the keyword branch. The helper now takes the small length
record by value. `integer-length-focused-2` and its full-page follow-up are
queued; the failure remains preserved and no saving is credited.

The original unfiltered-PNG supervisor disappears without a completed exit
receipt or focused output. `png-none-pipeline-1-interrupted.json` records the
unknown exit rather than assigning success. Its separate retry,
`png-none-pipeline-2`, is queued with fresh guard receipts.

The parser candidate adds an allocation-free presence walk before declarative
shadow materialization. It follows ordinary children and existing closed or
open shadow roots. Documents without templates can skip the allocating,
mutation-safe materialization walk; documents with templates retain that walk
unchanged. Three new tests cover allocation-free ordinary traversal, templates
inserted into an existing closed root, and initially inert templates that
become declarative after mutation. `shadow-presence-focused-1` selects 69 HTML
cases per GC mode; its generated-C isolation, eligibility probe, 30-pair page
comparison and conditional broad checkpoint are prepared but have not run.

All three candidates still require full-page measurements. The current
available production app contains none of them. No new production build is
queued, and no pending job earns instruction credit.

## Completed rollback and production reuse check

`19f7a803` restores the full intrinsic layout path after the negative page
cohort. `intrinsic-inline-restore-3` executes all 21 selected cases in each of
Boehm and preallocated no-GC mode, with compiler and runtime exits zero and
unchanged inputs. Its guard completes with exit zero after 309.354 seconds;
sampled peak process-tree RSS is 9,133,522,944 bytes. The rollback receives no
new instruction credit.

The fresh `production-reuse-1/check-1` check verifies the available bundle's
signature, startup, all three frozen pixel comparisons and both live pages.
Every frozen comparison is pixel-exact, including all 101 comment rows. Its
three-pair Brave cohort retains Vox counts of 9,457,434,608, 7,157,291,503 and
7,159,694,937 instructions. Brave's lower interval bounds are 6,963,471,281,
1,786,403,871 and 1,798,982,405. The first, cold pair is retained. The Vox
median is 7,159,694,937 and Brave's median lower bound is 1,798,982,405;
the acceptance statistic, worst Vox divided by best Brave lower bound, is
5.294119, above the required 0.90. The overall guard exits one because the
performance target fails; rendering and live identity checks pass. Elapsed
time is 70.008 seconds with sampled peak RSS 1,353,531,392 bytes. Input hashes
remain unchanged. This newer shared bundle is a baseline, with zero isolated
optimization credit; the earlier 3.656719 production ratio remains historical
evidence rather than the latest result.

`png-none-focused-1` passes both native PNG and capture entry-point checks with
unchanged input hashes. Its retry guard exits zero after 12.254 seconds, with
sampled peak RSS 186,384,384 bytes. Full-page measurement and conditional broad
verification remain pending; these focused results establish no page saving.

## Accepted unfiltered PNG encoding

`6d89c3bc` selects ImageIO's lossless NONE filter for native snapshots. The
focused native checks execute 27 cases with ARC and without ARC, plus both
capture entry points. All 54 PNG cases preserve decoded pixels, color profile,
density and non-image metadata. The earlier rejected SUB experiment remains
separate evidence.

`png-none-isolated-1` changes only the authenticated native snapshot overlay;
its generated browser C is unchanged. All 30 alternating pairs retain exact
pixels for the complete 101-comment page, with zero browser failures. The
control median is 6,340,728,960 instructions and the candidate median is
6,267,956,667. The median paired saving is 70,432,867, with bootstrap 95%
interval [62,428,225, 87,593,967.5]; all 30 pairs improve. The cold first-pair
saving of 2,655,587,914 remains in the cohort. The guard completes with exit
zero after 348.737 seconds and sampled peak RSS 5,020,565,504 bytes.

`png-none-checkpoint-1` passes with unchanged authenticated inputs. It carries
the accepted generated-C parent's V and AST verification, and executes the
19-case visual batch: 13 cases are exact and all 34 comparison images match
the control. Six existing reference mismatches remain, so this is a passing
regression comparison rather than a wholly passing reference suite. The three
HN fixtures are exact; startup and both live-page identity checks exit zero.
The checkpoint credits the measured interval's lower bound, 62,428,225
instructions. It does not sum savings from other experiments or establish
Brave parity. The installed production app predates this change; the latest
production acceptance ratio remains 5.294119 against the required 0.90.


## Accepted text-context scan cursor

`0284e529` retains a private glyph-scan cursor between chunks of the same
immutable shaped run. It resets for a different run or a backwards request,
while preserving partial-ligature fallback and the existing clone, offset and
kerning behavior. Three new tests cover Unicode code-unit boundaries, partial
ligatures, backwards requests and separated shaped segments. The focused
11-file selection passes 26 cases in each GC mode, including the current
segmented-run implementation.

`context-cursor-isolated-1` substitutes only the single-run helper, its private
cursor record and the iterator field/call into the authenticated generated C.
The separate eligibility run confirms resumed scans and fewer glyph visits.
All 60 captures in 30 alternating pairs preserve the complete 101-comment page
pixel for pixel. Control and candidate medians are 6,339,567,752.5 and
6,278,560,873.5 instructions. The median paired saving is 60,034,972.5, with
bootstrap 95% interval [43,393,314.5, 74,882,487.5]. There are 29 improvements
and one regression of 3,912,255 instructions; every pair is retained. No
segmented-run performance saving is inferred from this single-run isolation.

`context-cursor-checkpoint-1` passes with unchanged inputs: 598 distinct test
executions include 592 passes and the same six known layout failures; all
100 upstream AST fixtures compare exactly. The 19 visual cases retain all
34 control images, including the six existing reference mismatches. All three
HN fixtures are exact; startup and both live identity checks pass. Repeatable
page credit is the interval lower bound, 43,393,314.5 instructions. This is
independent candidate evidence, not additive credit or a production Brave
comparison. The installed production bundle still predates this candidate;
the latest production acceptance ratio remains 5.294119, above 0.90.

## Accepted integer-length serialization

`77392faa` builds common computed integer lengths in a small stack buffer and
copies only their final owned text. Keywords keep their static spelling;
fractional, large and nonfinite lengths retain general CSS serialization.
Three focused tests cover every length unit, numeric boundaries, retained
storage after scratch reuse, and bounded preallocated storage.

`integer-length-isolated-2` changes only the authenticated serializer and its
helper in the generated browser C. The separate eligibility check records
46,050 integer fast-path hits from 49,321 serializer calls. All 60 captures in
30 alternating pairs preserve the complete 101-comment page pixel for pixel.
The control median is 6,303,150,817 instructions and the candidate median is
6,077,116,012. The median paired saving is 224,318,402, with bootstrap 95%
interval [210,790,143.5, 231,453,930]; every pair improves. All pairs remain
in the result, including the smallest saving of 158,194,630 instructions.

`integer-length-checkpoint-2` passes with unchanged authenticated inputs.
Its distinct test union has 570 executions: 564 passes and the same six
known layout failures. All 100 upstream AST fixtures compare exactly. The
19 visual cases retain all 34 control images, including the six existing
reference mismatches; all three HN fixtures are exact. Startup and both live
identity checks exit zero. Repeatable page credit is the measured interval's
lower bound, 210,790,143.5 instructions. This independent result is not added
to other candidate savings. The installed production bundle predates this
change; its latest Brave acceptance ratio remains 5.294119 against 0.90.

## Accepted shadow-template presence scan

`3d2f23db` checks for templates through sibling links before entering the
existing mutation-safe materialization walk. Ordinary documents avoid its
temporary child snapshots. The presence scan includes existing closed shadow
roots; three focused tests cover allocation-free ordinary trees, nested roots,
inert templates and later attribute mutations.

`shadow-presence-isolated-1` changes only the authenticated presence helper,
materializer wrapper and recursive worker. A separate eligibility run confirms
both calls take the no-template path. All 60 captures in 30 alternating pairs
retain exact pixels for all 101 comments. Control and candidate medians are
6,316,284,087.5 and 6,233,092,734 instructions. The median paired saving is
88,074,050, with bootstrap 95% interval [74,022,882, 97,762,623.5]. Every pair
improves; the smallest saving, 16,875,673, is retained.

`shadow-presence-checkpoint-1` passes with unchanged authenticated inputs.
Its distinct test union has 684 executions: 678 passes and the same six known
layout failures. All 100 upstream AST fixtures compare exactly. The 19 visual
cases retain all 34 control images, including the six existing reference
mismatches. All three HN fixtures are exact; startup and both live identity
checks pass. Repeatable page credit is the interval lower bound, 74,022,882
instructions. This independent candidate result does not establish combined
savings or Brave parity. The installed production bundle predates the change;
its latest acceptance ratio remains 5.294119 against 0.90.

## Shared production recheck, 2026-10-27

`Build/hn-small-text/production-reuse-2/check-1` checks the latest completed
shared production bundle, preserved from `Build/4chan-catalog-20261027-final-1`.
The executable SHA256 is
`d0b28fb544c7ac9befb56b43402ed9c090f05651a2a2c1936df64f8793498d93`;
`available-bundle.json` pins all eight bundle files and its source receipt.
This bundle contains the anonymous-font fix, integer serialization, shadow
presence scan and PNG changes. It predates the text-context cursor, decoded
SVG ownership, scroll-frame and dedicated-worker candidates. No new production
build was scheduled. The original build receipt retains unrelated failed
checks; this focused HN recheck does not turn them into passes.

Signature verification, startup, all three frozen HN pixel comparisons and
both live-page identity checks pass. Three fresh Vox/Brave pairs retain all
101 comments with exact pixels. Vox instruction counts are 6,598,707,629,
6,527,885,072 and 6,551,639,391. The corresponding Brave accounting intervals
are [1,821,918,736, 1,866,312,001], [1,809,555,159, 1,845,193,682] and
[1,786,588,340, 1,834,331,796]. Every browser exits zero. The unchanged
navigation-through-synchronous-PNG endpoint still includes different internal
capture workflows in the two browsers; it does not establish wall-time parity.

The Vox median is 6,551,639,391 instructions, against Brave's median lower
bound of 1,809,555,159. The strict worst-Vox/best-Brave ratio is **3.693468**,
above the required **0.90**. This supersedes the earlier 5.294119 production
acceptance measurement. The cohort and memory guard correctly exit 1 for the
failed performance target, despite successful functional checks. The guard
records 61.3005 seconds and 1,283,096,576 bytes sampled peak RSS. Inputs remain
unchanged. This is current production baseline evidence with zero isolated
optimization credit; independent candidate savings are not added together.

## Scroll-frame ancestor lookup, uncredited

`layout/viewport_paint_bridge.v` now finds the containing scroll frame only
for boxes that create sticky, overflow or viewport frames. Ordinary boxes
still clear stale ownership and visit their descendants. Two new tests cover
nested scrollers, intervening ordinary boxes, stale indices, and a sticky box
that also scrolls. `scroll-owner-focused-2` passes all nine selected cases in
each GC mode, with unchanged sources.

`scroll-owner-isolated-1` substitutes only the tested assignment function;
shared records match exactly and literal remapping reverses byte for byte.
The separate eligibility diagnostic records 4,029 calls, 4,023 skipped searches
and six necessary searches. All 60 unprofiled captures in 30 alternating pairs
retain exact pixels and all 101 comments. Control and candidate medians are
6,333,204,263.5 and 6,320,148,603.5 instructions. The median paired saving is
12,881,629.5, with bootstrap 95% interval [-3,010,671, 23,866,587]. There are
18 improvements and 12 regressions. The first pair's 1,761,282,800-instruction
regression remains included. These results do not establish a repeatable
page improvement: instruction credit is zero. Broad verification is deferred
below the repeatable 5,000,000-instruction gate; the prior broad baseline is
unchanged. This experiment does not establish production or Brave parity.

## Decoded SVG resource ownership, uncredited

`be9b0d5e` keeps an HTML image's completed decoded SVG when the shell finishes
a separate favicon or background request for the same URL. The dependency
check verifies the committed image box owns that exact decoded document.
Pending images and generated content retain their existing invalidation. Two
new tests cover intrinsic and explicit image sizes, separate response bytes,
request identity, load events, retained geometry, nested painting and generated
content. `svg-owner-focused-2` passes all 17 selected cases in each GC mode
with unchanged source hashes.

`svg-owner-resume-1` authenticates and reuses the compiled isolated candidate
from `svg-owner-isolated-1`; its original failed diagnostic remains retained.
The corrected separate diagnostic records one owned completion, no requested
HTML rebuild, and one HTML layout/build. All 60 unprofiled captures in 30
alternating pairs preserve exact pixels and all 101 comments. Control and
candidate medians are 6,367,767,466 and 6,366,521,917 instructions. Median paired
saving is 8,511,462.5, with bootstrap 95% interval [-2,455,308.5, 13,123,366.5].
There are 18 improvements and 12 regressions; the largest regression is
57,310,882 instructions and remains included. Repeatable page credit is zero.
Broad verification is deferred below the repeatable 5,000,000-instruction
gate, leaving the prior broad baseline unchanged. The guard completes with
exit zero, 306.7954 seconds and 5,192,302,592 bytes sampled peak RSS. This
functional fix and diagnostic do not establish production or Brave parity.

## Dedicated bundled filter worker

`8a77e647` builds and signs `VoxAdblockWorker` beside the browser executable.
The default self-worker configuration selects it only for a browser named
`Vox` inside an application bundle and only when the sibling is an executable
file. Standalone worker-capable tools retain self-exec. The helper runs the
same filter engine, snapshot and private transport, without initializing the
browser's unrelated module globals. Configuration remains lazy. New tests
cover bundle selection, fallback paths, executable permissions, directories,
configuration without engine startup, the actual selected child executable,
real DoubleClick blocking and bounded release/reaping.

`bundled-worker-focused-3-resume-1` completes the retained Boehm checks and
resumed prealloc checks: 16 cases per mode, 32 test executions, helper startup,
native transport, shell syntax and build-command checks. The original prealloc
compile failed for insufficient disk space; that failed run is retained.
The resume pins and reuses its successful Boehm results and frozen sources.
Its guard exits zero after 23.4855 seconds, with 603,406,336 bytes sampled peak
RSS. The isolated C candidate imports only the focused selector/configuration
functions and helper; dependency bodies match the authenticated control, and
reversing the substitutions restores its complete generated C. A separate
eligibility run confirms the selected real helper PID, all 101 comments and
exact pixels, with no observer errors.

The initial 30-pair cohort is invalid: one control process exited zero but
wrote a truncated capture-counter log. All original results remain retained;
no individual trial is replaced. `bundled-worker-resume-1` runs an entirely
fresh alternating cohort. All 60 captures in its 30 pairs preserve exact
pixels and all 101 comments. Control and candidate medians are 6,325,365,608.5
and 6,168,949,930 instructions. Median paired saving is 155,096,853, with
bootstrap 95% interval [147,318,031, 165,990,375]. All 30 pairs improve; the
smallest saving is 103,640,060. Child-helper instructions remain included.
The guard exits zero after 201.9936 seconds, with 128,319,488 bytes sampled
peak RSS. The 18-CPU host ends at load averages 3.5771/4.2490/6.5889.

`bundled-worker-checkpoint-3` carries the byte-identical parent CSS/layout/SVG
and 100-case AST evidence and verifies the complete changed adblock suite.
Its native visual run preserves all 34 control images across 19 cases;
13 cases are exact against their references, with the existing differences
unchanged. Three frozen HN fixtures are pixel-exact, startup succeeds and both
live-page identity checks pass. The checkpoint guard exits zero after
138.2774 seconds, with 1,056,997,376 bytes sampled peak RSS. All source,
compiler, helper and control-app pins remain unchanged.

`Build/hn-small-text/bundled-worker-pipeline-6-result.json` records acceptance
of this isolated improvement and 147,318,031 repeatable instruction credit.
It is a frozen generated-C experiment, not validation of a newly built
canonical production browser. It does not establish Brave parity. The latest
production ratio remains 3.693468; independent optimization savings are not
added. The combined candidate must be measured separately.

## Combined accepted candidates, 2026-10-27

`Build/hn-small-text/combined-accepted-2` combines the accepted font baseline
with the text-context cursor, integer serializer, shadow presence scan,
scroll-frame lookup, dedicated filter worker and decoded SVG ownership changes.
Each generated-C substitution is authenticated against its focused source;
reversing the disjoint substitutions restores the control byte for byte.
The build retains C-O2, the original native libraries, signed worker helper,
fixture, capture endpoint and unchanged compiler/source pins. It is a frozen
candidate, not the installed canonical production bundle.

Signature and startup checks pass. The 19-case visual comparison retains all
34 control images: 13 cases are exact against their references and six existing
reference differences remain unchanged. All three HN fixtures are pixel-exact,
and both live identity checks pass. Three fresh Vox/Brave pairs preserve all
101 comments and exact pixels. Vox's median is 5,775,605,959 instructions,
against Brave's median lower accounting bound of 1,745,297,492. The strict
worst-Vox/best-Brave ratio is **3.439494**, above the required **0.90**.
The performance cohort correctly exits 1; the enclosing validation driver and
memory guard exit zero because they retain and report that target failure.
The guard records 370.3165 seconds and 5,396,578,304 bytes sampled peak RSS.
No independent savings are added or credited again. The latest installed
production acceptance ratio remains 3.693468; Brave parity is still open.

## C-O3 experiment rejected

`Build/hn-small-text/c-opt-level-isolated-1` changes only C-O2 to C-O3 on the
authenticated font baseline. It uses the same source, native inputs, signing,
startup checks and 30 alternating pairs. All 60 captures retain exact pixels
and all 101 comments, but every pair regresses. Control and candidate medians
are 6,366,911,761 and 6,548,317,720 instructions. Median paired saving is
-168,947,413, with bootstrap 95% interval [-185,801,763.5, -160,146,983.5].
The largest regression, 259,494,963 instructions, remains included. The
18-CPU host ends at load averages 16.2236/16.8257/14.8906. The experiment
receives zero credit; the canonical build retains C-O2. Broader verification
is unnecessary for this rejected compiler setting. Its guard exits zero after
427.0078 seconds, with 5,194,186,752 bytes sampled peak RSS.


## Containing-block visit buffer rejected

`Build/hn-small-text/intrinsic-visits-isolated-1` tests eight inline visited
indexes before allocating an overflow map during intrinsic containing-block
seeding. Six focused cases pass in each of Boehm and prealloc/no-GC modes.
The focused guard exits zero after 134.4549 seconds, with 9,294,643,200 bytes
sampled peak RSS. A separate diagnostic confirms 115,333 calls: 26,108 remain
inline and 89,225 spill. It retains exact pixels and all 101 comments.

All 60 unprofiled captures in 30 alternating pairs preserve exact pixels and
all 101 comments. Control and candidate medians are 6,337,462,457 and
6,324,289,652 instructions. Median paired saving is 18,749,848.5, with bootstrap
95% interval [-5,358,836.5, 30,023,679.5]. There are 19 improvements and 11
regressions. The initial candidate regresses by 2,391,240,526 instructions;
that result remains included. The 18-CPU host ends at load averages
14.5205/12.7617/12.7593. The isolated guard exits zero after 544.3779 seconds,
with 5,443,911,680 bytes sampled peak RSS.

The experiment earns zero repeatable instruction credit. Its four candidate
source files are archived with verified SHA256 identities under
`Build/hn-small-text/intrinsic-visits-rejected-1`; the two tracked files are
restored and the two new files removed. Broad verification is deferred below
the repeatable 5,000,000-instruction gate. The latest combined Brave ratio
remains 3.439494; this rejected candidate does not establish parity.

## Chromium context-slice cache rejected

`Build/hn-small-text/context-slice-isolated-4` tests retaining sliced context
glyph runs across intrinsic measurements. The focused checks pass 34 cases
per GC mode; a separate diagnostic observes 25,044 hits in 37,566 calls,
with exact pixels and all 101 comments. The 30 alternating unprofiled pairs
also retain exact pixels and comment identity. Control and candidate medians
are 5,792,975,191 and 5,785,306,704.5 retired instructions. Median paired
saving is 3,103,204.5, with bootstrap 95% interval
[-15,865,810, 17,443,580]. Only 16 of 30 pairs improve; the largest regression
is 130,813,935 instructions and remains included. The 18-CPU host finishes
at load averages 5.7539/4.2046/4.0366. The isolated guard exits zero after
211.7329 seconds, with 124,305,408 bytes sampled peak RSS.

The experiment receives zero repeatable instruction credit. Its five source
files and patch are archived under `Build/hn-small-text/context-slice-rejected-1`;
only the candidate edits are removed, preserving the newer whitespace-shaping
fix. A redundant integration check is cancelled while still queued, before
it starts or snapshots source. Broad verification remains deferred below the
repeatable 5,000,000-instruction gate. The combined Brave ratio remains
3.439494; the performance target is open.


## Latest completed production baseline, 2026-10-27

`Build/hn-small-text/production-reuse-3/check-1` reuses the latest completed
production browser from `Build/4chan-catalog-20261027-catalog-production-3`,
preserved in a sealed app before the shared bundle changes. Its executable
SHA256 is `18ed315192d7be1bbc3a6c0f16a4a710cc664dc3f126c897e0413fff96ceddf9`.
No production rebuild is requested. This build includes collapsed-space
Chromium context shaping but excludes the rejected context-slice cache and
the pending property-page projection cache. The full app, native libraries,
source receipt, fixture and measurement inputs remain pinned and unchanged.

All three frozen HN fixtures are pixel-exact; both live identity checks pass.
Three fresh Vox/Brave pairs preserve all 101 comments and exact pixels.
Vox's median is 11,841,703,712 retired instructions, against Brave's median
lower accounting bound of 1,841,710,731. The strict worst-Vox/best-Brave ratio
is **6.457878**, exceeding the required **0.90** and regressing against the
older combined candidate. This comparison is baseline evidence, not an
isolated attribution or optimization credit. The performance cohort, driver
and memory guard all exit 1 because acceptance fails. The guard records
92.1896 seconds and 3,227,566,080 bytes sampled peak RSS. Diagnostics are
pending to locate the added work; pixel correctness does not establish
Brave performance parity.


## Density projection page cache

`7e462985` caches a conservative density-projection candidate mask on each
shared computed-property page. Typed dimensionless and invariant values skip
repeated inspection. Untyped values, nested lengths, width keywords, animated
properties and transition precedence retain their existing paths. Copy-on-write,
initial-value replacement and page recycling invalidate the mask; shared reads
and publication use atomics. The page grows from 128 to 136 bytes.

`Build/hn-small-text/projection-pages-focused-4` passes 42 focused cases in each
of Boehm and prealloc/no-GC modes. The separate diagnostic in
`projection-pages-isolated-5` observes 77,855 calls, 75,242 cached masks and
43,290 empty pages while preserving all 3,145,728 pixel cells and 101 comments.
Thirty alternating unprofiled pairs preserve the same pixels and identity.
Control and candidate medians are 6,413,400,456 and 6,333,504,531.5 retired
instructions. Median paired saving is 83,577,074; the bootstrap 95% interval
is [73,386,154.5, 98,701,578]. All 30 pairs improve, including the smallest
saving of 7,314,410. The strict worst-candidate/best-control ratio is 1.005053;
this is a repeatable paired gain, not a bound on every independent run.
The 18-CPU host ends at load averages 15.7456/14.3262/13.9390. The isolated
guard exits zero after 524.5164 seconds, with 5,661,966,336 bytes sampled peak RSS.

The 73,386,154.5-instruction conservative credit triggers the broad checkpoint.
`projection-pages-checkpoint-5/result.json` records 482 new and 106 authenticated
focused executions: 582 pass and six retain the baseline's three layout failures
in both GC modes. All 100 upstream AST fixtures match exactly. All 34 retained
control/candidate images are unchanged; 13 of 19 canonical cases match their
references exactly, while the six existing reference failures remain unchanged.
HN is exact, and startup and live checks exit zero. No tolerance changes.
The interrupted job is resumed through `projection-pages-resume-1.py` without
rerunning completed checks. Its guard exits zero after 269.0976 seconds, with
9,089,662,976 bytes sampled peak RSS. The checkpoint resets this workload's
pending broad credit to zero; independent optimization savings are not added.

The executable is a pinned, reversible generated-C candidate on the earlier
font-cascade baseline, not a rebuilt canonical production browser. These results
validate the isolated change but do not establish a gain in the latest production
build. Its strict Vox/Brave ratio remains 6.457878 against the required 0.90.
The user's Brave performance target remains open.


## Reused Canvas production baseline, 2026-10-27

`Build/hn-small-text/production-reuse-4/check-1` checks the newer completed
bundle from `Build/pikabu-dom-canvas-production-1793083416732516000` without
requesting a production rebuild. Its executable SHA256 is
`e10853851e59334a646337d36dce1d4f4fc9e21ae0fc4ffd150bc858ee8a5160`.
The source snapshot lacks the newer Chromium line-end shaping and scalar
context metrics. Other workloads retain open pixel gates in its production
receipt; this check covers only the recorded HN fixtures and live identities.

All three frozen HN screenshots remain pixel-exact, both live identity checks
pass, and signature and startup checks exit zero. Three fresh alternating
Vox/Brave pairs retain exact pixels and all 101 comments. Vox's median is
7,312,044,715 retired instructions; Brave's median lower accounting bound is
1,884,329,466. The strict worst-Vox/best-Brave ratio is **4.013862**, exceeding
the required **0.90**. The acceptance cohort exits 1. All pinned inputs remain
unchanged.

This is baseline evidence, with zero isolated optimization credit. Its different
source content prevents attributing the lower count to any one change. The
line-end optimization continues against the sealed production-3 control that
contains that shaping behavior. The user's performance target remains open.


## Scalar line-end metrics, 2026-10-27

`8e75f2e9` lets read-only line fitting use the shaping cache's scalar advance
and cluster coverage. It avoids cloning glyphs and building playback buffers;
trimming still materializes the exact boundary shape used for painting. Cache
keys, recency, allocation ownership, script/face gates and rounding are retained.
The focused tests compare cold/warm metrics, cancellation, cluster boundaries,
caller mutation, scratch lifetimes and repeated read-only queries against the
materialized shape and final trim in both GC modes: 60 executions pass.

`Build/hn-small-text/line-end-metrics-isolated-2` retains the reversible generated-C
candidate on the sealed production-3 control, using its unchanged O2 command,
252 objects and native libraries. Candidate executable SHA256 is
`7107f8cf87a301d7c682024cae1904954cb47e25ca5a03188d0118c84711b479`.
The separate diagnostic observes 160,560 metric calls, 127,073 cache hits and
58,442 trailing-width queries; it receives no timing credit. Thirty alternating
unprofiled pairs preserve all HN pixels and 101 comments. Control/candidate
medians are 11,866,915,038 / 11,142,270,368 retired instructions. Median paired
saving is 709,926,114.5, bootstrap 95% interval [686,054,815.5, 738,283,012],
with all 30 pairs improving. The strict worst-candidate/best-control ratio is
0.951903. The 18-CPU host ends at load averages 27.8999/33.2280/33.8457;
raw trials, identities, commands, exits and input pins are retained.

The conservative 686,054,815.5-instruction credit triggers the broad checkpoint.
`line-end-metrics-checkpoint-3` records 482 new and 166 distinct carried focused
executions: 642 pass, while six retain the baseline's three layout failures in
both modes. All 100 official upstream AST fixtures compare exactly. All 34
retained control images remain unchanged; 14 of 19 canonical cases are exact,
and five existing reference failures are unchanged. Three HN fixtures are exact;
startup and both live checks pass. No tolerance changes.

The initial checkpoint compared against an older screenshot baseline and stopped
at a select-image mismatch. Recovery captures the exact measured production-3
control afresh, proving that its select image is also exact. Pipeline 3 reuses
the completed cohort and broad tests, then passes fresh control/candidate visual
and AST checks. Its guard exits zero after 284.7712 seconds with sampled peak
RSS 3,248,734,208 bytes. The earlier failed guard and all outputs are retained.
Pending broad credit is reset to zero. Independent gains are not added.

This validates the isolated optimization, not a fresh canonical production build
or Vox/Brave acceptance. The latest completed production baseline above remains
4.013862 against the required 0.90; the user's performance target stays open.


## Decoded SVG ownership on scalar metrics, 2026-10-27

`be9b0d5e` keeps a decoded SVG image's isolated layout completion from
invalidating the HTML document when that image already owns the same decoded
document. Other dependencies still invalidate normally. The focused SVG tests
pass in both memory modes. `Build/hn-small-text/svg-owner-isolated-4` composes
this change onto the measured scalar-metrics candidate, preserving the O2
command, 252 objects and native libraries. Candidate executable SHA256 is
`105395ffb68fa3d2e5323fc877a661005a7ea3ef9d84749a261ba33b70a2c3c3`.

The separate diagnostic observes 207 ownership queries, three owned images,
two completions and zero requested HTML rebuilds. The complete page performs
one HTML layout and rebuild. Diagnostic instrumentation receives zero credit.
Thirty alternating unprofiled control/candidate pairs preserve every pixel and
all 101 comments. Control/candidate medians are 11,127,820,085 / 8,156,710,212.5
retired instructions. Median paired saving is 2,970,719,727; the bootstrap
95% interval is [2,946,085,014, 2,996,329,581]. All 30 pairs improve, with a
minimum saving of 2,823,054,946. The strict worst-candidate/best-control ratio
is 0.745520. The 18-CPU host ends at load averages 15.3101/15.1685/18.2534.
Raw trials, commands, inputs, identities and exits remain retained.

The conservative 2,946,085,014-instruction credit triggers the broad checkpoint.
`svg-owner-checkpoint-4` records 482 new and 200 distinct carried focused
executions: 676 pass, while six retain the baseline's three layout failures in
both modes. All 100 official upstream AST fixtures compare exactly. All 34
control/candidate images remain unchanged; 14 of 19 canonical cases are exact,
and five existing reference failures remain unchanged. All three HN fixtures
are exact; startup and both live checks pass. No tolerance changes.

The first integration attempt completes its O2 build but fails to compile its
separate eligibility probe because the probe uses an absent string macro.
Recovery fixes only that diagnostic macro and reuses the completed O2 candidate
byte for byte. The failed attempt and its actual exit remain retained. The
recovery integration guard exits zero after 767.9450 seconds with sampled peak
RSS 9,347,203,072 bytes. The checkpoint resets pending broad credit to zero;
independent gains are not added.

This validates the isolated composition, not a newly built canonical production
browser or the Brave target. The latest completed production comparison remains
4.013862 against the required 0.90. The combined candidate needs a fresh Brave
comparison; the user's performance target remains open.


## HarfBuzz safe line-end boundaries, 2026-10-27

`423693e9` retains HarfBuzz's safe/unsafe cluster boundaries in the existing
glyph-record padding. Chromium line fitting can reuse a cached ASCII range when
both ends are safe and coverage is exact. Unknown metadata, fallback faces,
non-LTR text, Unicode and collapsed source maps keep independent shaping.
Painting still materializes the boundary shape. Local f64 accumulation,
spacing keys and final rounding remain unchanged; no prefix subtraction is used.

The focused checks exhaustively compare accepted ranges and projected rounding
against independent shaping, including ligatures, negative spacing, cancellation,
cache mutation and scratch ownership. Seventy executions pass in both memory
modes. The initial focused build stopped at a reused test-loop name; the corrected
tests were compiled and executed afresh. The generated-C checks preserve the
48-byte glyph stride and all existing offsets.

`Build/hn-small-text/safe-break-isolated-3` composes the slice onto the validated
SVG-ownership candidate, retaining the O2 command, 252 objects and native libraries.
Executable SHA256 is
`c10ca652eca1d40a2d18c61ad4941e9bb350aa9543b940de7e223ca3b6d362d9`.
The separate diagnostic observes 56,660 queries, 54,174 hits and 29,221 trailing
queries, with exact pixels and all 101 comments. It receives no performance credit.

Thirty alternating unprofiled pairs preserve every HN pixel and all comments.
Control/candidate medians are 8,138,840,010.5 / 7,742,388,413 retired instructions.
Median paired saving is 396,313,943.5; bootstrap 95% interval is
[367,635,578, 422,593,091]. All 30 pairs improve, with a minimum saving of
299,096,547. The strict worst-candidate/best-control ratio is 0.966232.
The 18-CPU host ends at load averages 26.1089/21.8853/15.8921. Raw inputs,
identities, trials, commands and actual exits are retained unchanged.

The conservative 367,635,578-instruction credit triggers
`safe-break-checkpoint-3`: 482 new executions and 210 distinct carried focused
executions give 686 passes and the six unchanged baseline layout failures.
All 100 upstream AST fixtures compare exactly. All 34 control/candidate images
are unchanged; 14 of 19 canonical cases are exact, and five existing reference
failures remain unchanged. The three HN fixtures are exact; startup and both
live checks pass. No tolerance changes. Pending broad credit resets to zero.

This validates the isolated optimization. The combined cache-density candidate
still needs its own measurements and direct Brave comparison; independent gains
are not added. The user's requirement of at least 10% fewer instructions than
Brave remains open.


## Combined cache density and safe boundaries, 2026-10-27

`Build/hn-small-text/density-composed-isolated-6` composes the previously checked
cache-density slice onto the SVG-ownership and safe-boundary candidate. This is
an isolated frozen generated-C composition, not a fresh canonical production
build. Removing the four focused writers, two helpers and record additions
restores the entire parent C byte for byte. The 252 O2 objects, native libraries
and unrelated generated code remain unchanged. Executable SHA256 is
`2f98e90bddf5ab3ab45b32290e939bfcafdac801350f902a8618be8b5fedb5bf`.

Thirty alternating unprofiled pairs retain all 101 comments and exact screenshots.
Control/candidate medians are 7,813,809,141.5 / 7,742,455,117 retired instructions.
The median paired saving is 71,638,468; the bootstrap 95% interval is
[58,588,422, 81,100,061.5]. All 30 pairs improve, with a minimum saving of
1,039,862. The strict worst-candidate/best-control ratio is 1.007853, showing
variation across the cohort despite each matched pair improving. The 18-CPU
host ends at load averages 60.1636/53.4424/36.1460; all raw trials and host
conditions are retained. The separate eligibility diagnostic records 77,855
queries, 75,242 hits and 43,290 empty cases, with exact pixels; it receives no
performance credit.

The conservative 58,588,422-instruction credit triggers checkpoint 6. Its 482
new executions and 210 distinct carried executions produce 686 passes and the
same six baseline layout failures. All 100 upstream AST fixtures compare exactly.
The visual batch retains all 34 fresh control/candidate images unchanged: 14 of
19 reference cases are exact, and five pre-existing reference failures remain
unchanged. Three HN fixtures, startup and two live identity checks pass. No
pixel tolerance changes. Pending broad credit resets to zero.

`Build/hn-small-text/profile-20` is a fresh, separately sampled diagnostic of
this exact executable. Attachment, browser and sampler exits, the PNG endpoint,
all 101 comments, exact pixels and input identities are verified. It still finds
intrinsic line fitting and repeated context/safe-range measurements. Inclusive
counts remove recursive duplicate ancestors; samples are diagnostic only and
receive no instruction credit.

`Build/hn-small-text/composed-brave-acceptance-1` directly compares this combined
candidate with Brave in 30 alternating pairs using the unchanged official
capture workflow. Every capture is valid and exact. Vox's median is
7,754,983,095.5 instructions; Brave's median lower bound is 1,796,922,868.
The strict worst-Vox/best-Brave ratio is 4.554655, exceeding the required 0.90.
The actual benchmark exit is 1; the wrapper's zero exit records a valid completed
measurement, not target acceptance. The 18-CPU host ends at load averages
37.6104/34.9565/34.0786, with one-second samples retained outside both browser
coalitions. The endpoint includes different browser startup and PNG delivery
work, as documented above; it is not an identical internal first-render measure.
The user's requirement of at least 10% fewer instructions than Brave remains
open. Independent candidate gains are not added.

The complete guarded composition/checkpoint/profile/Brave run exits zero after
2,266.215 seconds, with sampled aggregate peak RSS 9,407,561,728 bytes under the
12 GiB guard. Commands, actual child exits and inputs are retained under
`Build/hn-small-text/safe-density-composition-4` and its guard receipt
`Build/hn-small-text/safe-density-composition-5-guard.json`.


## Retained shaping metrics and boundary indices, 2026-10-27

`6849067b` retains scalar context metrics and a bounded UTF-16 boundary index
with the immutable cached glyph snapshot. Queries still accumulate advances
locally in f64 and preserve the original offset and rounding rules. Unknown,
oversized and unsupported runs keep the checked fallback. Cache ownership,
spacing keys, painting and invalidation remain covered by focused tests. Line-end
queries avoid materializing an unused substring or UTF-16 vector, and ASCII
script checks avoid decoding runes.

All 110 focused executions pass in Boehm and preallocation/no-GC modes, including
six new cases for exact rounding, cluster boundaries, conservative fallback,
forged input metadata and scratch ownership. Generated-C checks preserve glyph
ABI and all shared records except the explicitly asserted CachedShape tail.
The first submission stopped at a driver fingerprint mismatch. The second
stopped at a C `float` spelling preflight; its focused executions passed and
were retained. The corrected third submission keeps both failed attempts and
reuses those unchanged focused inputs.

`Build/hn-small-text/text-metrics-isolated-3` composes the validated slice onto
the combined cache-density candidate. It is a frozen generated-C composition,
not a fresh canonical production build. Reversing nine writers and three helpers
plus the asserted record tail restores the complete parent C byte for byte;
the 252 O2 objects and native libraries remain unchanged. Executable SHA256 is
`13862bf904098199ebd6fe3c54bb481404cf3b1e951fb5dbc963ca095e16f791`.
The separate eligibility diagnostic observes 56,660 safe-range queries, 54,174
hits, 29,221 trailing queries, 56,660 indexed queries and 19,261 scalar metric
hits, with exact pixels and all 101 comments. It receives no performance credit.

Thirty alternating unprofiled pairs retain exact screenshots and all comments.
Control/candidate medians are 7,733,818,317 / 7,432,978,953 instructions. Median
paired saving is 305,571,153; the bootstrap 95% interval is
[290,501,259.5, 327,988,172]. All 30 pairs improve, with a minimum saving of
217,709,612. The strict worst-candidate/best-control ratio is 0.974983.
The 18-CPU host ends at load averages 57.6333/38.5986/32.8711. Raw trials,
identities, commands, inputs and actual exits are retained.

The conservative 290,501,259.5-instruction credit triggers checkpoint 3. Its 482
new executions and 250 distinct carried focused executions give 726 passes and
the six unchanged baseline layout failures. All 100 upstream AST fixtures match
exactly. All 34 fresh control/candidate images remain unchanged: 14 of 19
canonical cases are exact, with five existing reference failures unchanged.
Three HN fixtures, startup and both live identity checks pass. No tolerance
changes. Pending broad credit resets to zero.

The complete guarded pipeline exits zero after 1,100.781 seconds, with sampled
aggregate peak RSS 9,319,153,664 bytes under the 12 GiB guard. Evidence is under
`Build/hn-small-text/text-metrics-pipeline-3` and guard receipt
`Build/hn-small-text/text-metrics-submission-3/attempt-012.json`. This comparison
measures the isolated optimization against its parent. It does not establish
the requested 10% fewer instructions than Brave; that target remains open.


## Intrinsic line fitting without unused projected widths, 2026-10-27

`4e404983` skips projected-width shaping only when a soft-wrap decision has an
intrinsic or indefinite constraint. Min-content always breaks and max-content
and indefinite constraints never break, independent of the measured advance.
Definite lines, float-reduced widths and actual overflow splitting retain full
measurement. Two new tests compare decisions across empty/populated lines,
signed/zero advances and all constraints, and verify min-content overflow still
splits into correctly measured glyphs. All 58 focused executions pass in Boehm
and preallocation/no-GC modes, including generated glyph ABI checks.

`Build/hn-small-text/intrinsic-fit-isolated-1` is a frozen generated-C composition,
not a fresh canonical production build. Reversing the two call replacements and
one helper restores the complete parent C byte for byte; 12 shared records,
nine shared helpers, all 252 O2 objects and native libraries remain unchanged.
Executable SHA256 is
`2109cce54961d337e773aff3c8f82c05e0da999f58a44fbdc573937f83217219`.
The separate eligibility diagnostic records 19,347 calls and 12,898 intrinsic
hits, exact pixels and all 101 comments. It receives no performance credit.

Thirty alternating unprofiled pairs preserve every pixel and all comments.
Control/candidate medians are 7,427,138,379 / 6,962,427,923 instructions. The median
paired saving is 458,330,584; bootstrap 95% interval is
[446,881,098, 492,501,144.5]. All 30 pairs improve, with a minimum saving of
333,236,366. The strict worst-candidate/best-control ratio is 0.956386. The
18-CPU host ends at load averages 21.4155/27.0640/32.4995; raw trials, identities,
commands and actual exits are retained.

The conservative 446,881,098-instruction credit triggers the broad checkpoint.
Its 482 new and 288 distinct carried executions give 764 passes and the six
unchanged baseline layout failures. All 100 upstream AST fixtures match exactly.
All 34 fresh control/candidate images remain unchanged: 14 of 19 canonical cases
are exact, with five existing reference failures unchanged. Three HN fixtures
and startup pass. The first live check loaded a navigation-error document, so
pipeline 1 correctly failed. Pipeline 2 stopped before any checks because free
disk space was below 1 GiB. Both failures remain retained. Transparent filesystem
compression recovered 1,185,505,280 allocated bytes from generated C with verified
identical SHA256 content; no evidence was removed. Pipeline 3 reuses pinned,
passing checks, passes both fresh live identity checks and completes the AST
comparison. No tolerance changes. Pending broad credit resets to zero.

The initial guard exits 1 after 1,238.344 seconds with sampled peak RSS
9,323,560,960 bytes. The successful recovery exits zero after 28.436 seconds,
with peak 1,275,871,232 bytes under the 12 GiB guard. Receipts are retained in
`Build/hn-small-text/intrinsic-fit-submission-{1,2,3}`; the successful checkpoint
is `intrinsic-fit-checkpoint-2` and pipeline is `intrinsic-fit-pipeline-3`.
This validates savings against the parent candidate. The requested 10% fewer
instructions than Brave remains open; independent gains are not added.

## Retain geometry when SVG backgrounds finish, 2026-10-28

`6f91ec6e` preserves the existing repaint state until the background-resource
refresh decides whether it can retain layout and the paint projection. It also
allows an independently decoded, eligible static SVG image to keep its own
document when the same URL completes in the shell resource cache. Pending
repaints, unsupported nested SVG content, and resources that can change intrinsic
geometry retain the fallback. Focused tests accompany the implementation, but
their execution is deferred by the user's instruction to wait for Brave speed.

The canonical production build in `Build/hn-master-20261028-14/` completed with
guard/browser-build exits zero in 481.896 seconds, with sampled aggregate peak
RSS 8,082,669,568 bytes. Its executable SHA256 is
`df3277fb186ba4ff5a0da46cb518ec5b75837634b58cffd8c9b2f2482a9ac387`.
The source audit passes. Against the preceding control, native library hashes
are identical and the generated C differs only in the resource-refresh guard.
The separately instrumented `background-eligibility-3` run proves that the
triangle SVG completion takes the retained-geometry path. It preserves all 101
comment IDs and has zero differing pixels against the sealed Brave capture.
Instrumentation changes execution timing and receives no performance credit.
The preceding two diagnostic attempts are retained: one did not reach a
successful refresh, and one failed while reading diagnostic map data.

Four unprofiled matched pairs use the same navigation-to-encoded-capture
endpoint, private profiles, fixture, viewport and seal, with control/candidate
order ABBA. Control Vox instruction counts are 6,877,571,320 and 6,807,141,184;
candidate counts are 6,796,968,486 and 6,838,935,870. The candidate median is
6,817,952,178 against the control median 6,842,356,252 (0.36% lower). Their
ranges overlap, and host load reaches roughly 96 on the 18-CPU machine. This
does not establish an optimization gain. Raw trials, hashes, commands, content
audits and pixel comparisons are retained in `instructions/` beside the build.

The paired Brave lower-bound median is 1,904,225,070 instructions; the worst
candidate/best-Brave ratio is 3.6125. The acceptance driver and guard return 1
because the requested ratio of at most 0.90 is not met. Every browser exits
zero. No regression test suite was executed for this change; formatting and
diff checks pass. The Brave speed target remains open.

## Reject lazy intrinsic geometry copying, 2026-10-28

`Build/hn-master-20261028-15/` measured a prototype that copied external
containing-block geometry when an intrinsic probe first requested it. The
canonical production build completed with build/guard exits zero in 371.396
seconds and sampled peak RSS 6,656,147,456 bytes. Its executable SHA256 is
`5d127037afc98c48b39633282789571019bc9708a8647409f8cb1c955654cb9e`.
The source audit passes and native libraries match build 14. The generated C
also contains concurrent shared-recording validation changes, so full-page
differences cannot be attributed solely to this prototype.

The corrected `cost-breakdown-2` diagnostic observes 128 borrowed-probe
geometry lookups, zero differing Brave pixels and all 101 comment IDs. The
first diagnostic could not attach to an inlined constructor and is retained
as a failure. Neither diagnostic receives performance credit.

Eight unprofiled matched pairs use two ABBA blocks with the original
navigation-to-encoded-capture endpoint. Control counts are 6,819,469,303;
6,849,325,277; 6,799,114,912; and 6,795,298,955. Candidate counts are
6,843,929,463; 6,805,405,667; 6,789,060,978; and 6,830,852,840. Candidate
and control medians are 6,818,129,253.5 and 6,809,292,107.5: the candidate
uses 0.13% more instructions, with overlapping ranges. The 18-CPU host's load
falls from roughly 30 to 23. All 16 browsers exit zero with exact pixels and
all comments. The guard exits 1 solely because the Brave target fails,
after 101.992 seconds with peak RSS 101,974,016 bytes. Candidate Brave
lower-bound median is 1,900,846,818.5; worst-candidate/best-Brave is 3.6579.

The prototype earns no optimization credit and is removed from canonical
sources. It also left cold read-only external containing-block queries
unpopulated, which would require a correctness fix before reuse. Its unrun
focused test and implementation snapshots remain in the evidence directory.
The completed build 14 bundle is restored byte for byte; the rejected binary
is retained separately. Foreign working changes are preserved. No regression
test suite was executed, as requested; the 0.90 Brave target remains open.

## Reuse rendered-text ASCII eligibility, 2026-10-27

`4b8b075b` reads the ASCII fact refreshed with `text_for_rendering()` instead
of rescanning the entire text node for every safe-line query. The existing
invalidation and transformed-source-range handling remain authoritative. Two
new tests compare every valid and invalid range against the independent original
scan/allocation path, including live DOM changes, UTF-16 source ranges, uppercase
expansion, combining characters, emoji, tabs, newlines and empty text. All 52
focused executions pass in Boehm and preallocation modes, including glyph ABI
assertions.

`Build/hn-small-text/safe-line-ascii-isolated-2` is a frozen generated-C
composition, not a fresh canonical production build. Its single writer reverses
to the complete parent C byte for byte; 12 shared records, 11 shared helpers,
252 O2 objects and native libraries remain unchanged. Executable SHA256 is
`77e2758cb36efdccb48fd01305b7a66ee95a48ac00cf90fa0b5916de5ac345c8`.
The separate instrumented eligibility run records 67,427 queries and cached
ASCII reads, exact pixels and all 101 comments. It receives no performance credit.

Thirty alternating unprofiled pairs retain exact pixels and all comments.
Control/candidate medians are 6,753,159,217 / 6,655,149,007 instructions.
Median paired saving is 102,282,724; bootstrap 95% interval is
[81,007,034.5, 112,236,612]. All 30 pairs improve, with a minimum saving of
13,251,684. The strict worst-candidate/best-control ratio is 1.0021092. The
18-CPU host ends at load averages 3.1934/2.5117/1.7280. Raw trials, commands,
actual exits and identities remain retained.

The conservative 81,007,034.5-instruction credit triggers the broad checkpoint.
Its 482 new and 298 distinct carried executions give 774 passes and the six
unchanged baseline layout failures. All 100 upstream AST fixtures match exactly.
All 34 fresh control/candidate images remain unchanged: 14 of 19 canonical cases
are exact, with five existing reference failures unchanged. Three HN fixtures,
startup and both fresh live identity checks pass. No tolerance changes. The
visual receipt inherited the preceding rejection experiment's descriptive label;
its pinned executable, launch commands and captures identify the ASCII candidate.
Pending broad credit resets to zero.

Pipeline 1 stops at its disk-space check. Pipeline 2 completes the focused
checks and candidate build, then fails in the eligibility driver before launching
its diagnostic. Both failures remain retained. Pipeline 3 verifies and carries
that identical signed build, uses the corrected eligibility driver and completes
the paired measurements and checkpoint. Its guard exits zero after 589.704
seconds, with sampled aggregate peak RSS 9,389,408,256 bytes under the 12 GiB
limit. Evidence is in `safe-line-ascii-pipeline-3`,
`safe-line-ascii-checkpoint-1` and
`safe-line-ascii-submission-3/attempt-000.json`, below `Build/hn-small-text/`.
The requested 10% fewer instructions than Brave remains open; these savings
are measured against the previous Vox candidate.

## Rejected fixed-point advance prefix experiment, 2026-10-27

`Build/hn-small-text/safe-prefix-source-1` tried an immutable fixed-point
prefix index for safe-range advances, with the original local sum retained for
ineligible values. All 82 focused executions pass in Boehm and preallocation
modes. The separate eligibility run sees 47,442 queries and 45,208 indexed
hits, with exact HN pixels and all 101 comments. That diagnostic receives no
performance credit.

All 30 alternating unprofiled pairs are valid and pixel-exact. Control and
candidate medians are 6,903,331,382 / 6,910,107,768.5. The median paired saving
is 5,283,348.5 instructions, but its bootstrap 95% interval crosses zero:
[-8,546,261.5, 27,783,629]. Only 15 pairs improve; the worst pair regresses by
66,332,379 instructions. The strict ratio is 1.013301. The experiment earns
zero repeatable credit and is not applied to canonical sources. The broad
verification counter remains zero.

The pipeline stops at its free-space check before additional visual checks;
that failure is retained, without whole-pipeline pass credit. The guard exits
1 after 484.784 seconds, with sampled aggregate peak RSS 9,350,709,248 bytes.
Raw results and identities are under `safe-prefix-isolated-1`, and the guard
receipt is `safe-prefix-submission-1/attempt-011.json`, all below
`Build/hn-small-text/`. This is a frozen generated-C experiment, not a fresh
canonical production build or a Brave acceptance result.

## Reject collapsed safe-line queries before allocation, 2026-10-27

`6b3ac9a5` checks the existing source-map rejection condition before allocating
collapsed text and its map. Only ASCII text with consecutive spaces under
`collapse` or `preserve-breaks` is rejected early; every eligible query still
uses its original text and exact width calculation. The new independent oracle
test covers six white-space modes, ASCII/non-ASCII and control characters,
preserved spaces, valid/invalid ranges and exact floating-point results. All
44 focused executions pass in Boehm and preallocation modes, including glyph
ABI assertions.

`Build/hn-small-text/safe-line-reject-isolated-2` is a frozen generated-C
composition, not a fresh canonical production build. Reversing its single
writer restores the complete parent C byte for byte; 12 shared records, 11
shared helpers, all 252 O2 objects and native libraries remain unchanged.
Executable SHA256 is
`9a6218f7cc2dff16c25072bb8e102f7a214030d8df701c8d14073ecba8f3aac6`.
The separate eligibility run records 67,427 queries and 5,576 source-map
rejections, exact pixels and all 101 comments. It receives no performance credit.

Thirty alternating unprofiled pairs retain exact pixels and all comments.
Control/candidate medians are 6,922,290,756.5 / 6,755,044,684.5 instructions.
Median paired saving is 162,015,137.5; bootstrap 95% interval is
[149,025,641.5, 178,692,608.5]. All 30 pairs improve, with a minimum saving of
67,495,454. The strict worst-candidate/best-control ratio is 1.0003004. The
18-CPU host ends at load averages 2.9375/3.8745/7.7241. Raw trials, identities,
commands and actual exits remain retained.

The conservative 149,025,641.5-instruction credit triggers the broad checkpoint.
Its 482 new and 290 distinct carried executions give 766 passes and the six
unchanged baseline layout failures. All 100 upstream AST fixtures match exactly.
All 34 fresh control/candidate images remain unchanged: 14 of 19 canonical cases
are exact, with five existing reference failures unchanged. Three HN fixtures,
startup and both fresh live identity checks pass. No tolerance changes. Pending
broad credit resets to zero.

The initial pipeline stops at disk exhaustion before the broad checkpoint.
Recovery attempts 3 through 5 also stop before that checkpoint; attempt 4's
compression preflight rejects an invalid signed/unsigned identity assumption
before changing a file. All failed receipts remain retained. Verified transparent
compression preserves artifact bytes, and pipeline 6 revalidates the pinned
focused, isolation and measurement evidence before completing checkpoint 2.
The successful guard exits zero after 380.833 seconds with sampled aggregate
peak RSS 9,409,347,584 bytes under the 12 GiB guard. Evidence is in
`safe-line-reject-pipeline-6`, `safe-line-reject-checkpoint-2` and
`safe-line-reject-submission-6/attempt-000.json`, below `Build/hn-small-text/`.
This validates savings against the parent candidate. The requested 10% fewer
instructions than Brave remains open; independent gains are not added.
