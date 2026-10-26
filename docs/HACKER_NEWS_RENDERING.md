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
