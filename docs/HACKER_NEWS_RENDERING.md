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
and readiness polling. Both use inactive native windows away from the pointer.
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
