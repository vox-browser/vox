# ChatGPT instruction comparison

The current target is **20B instructions** for the frozen ChatGPT launch-through-PNG workload. The latest absolute-descendant measurement diagnostic observes a **24.237B** candidate median versus **24.223B** for its full-layout control. Ranges overlap; no page savings are credited. All 20 captures pass content and exact pixels, and 416 final focused test executions pass. The [latest verification](performance/chatgpt-absolute-measurements-verification-20261106.json) retains every observation. Four pairs remain below seven-pair acceptance; historical cohorts below retain their pinned builds.

The requested 5% advantage over Brave remains **unmet**. The latest complete
seven-pair cohort uses executable
`8a1e86fa09d39144053b74e3df2b6703701d67d85c2b6dfdae02656fd12a2dcb`.
All fourteen fresh browser captures pass content, readiness, JavaScriptCore
bootstrap, unchanged reference pixels and browser/kernel exits.

| Launch through encoded document PNG | Retired CPU instructions |
| --- | ---: |
| Vox median | 30,006,382,557 |
| Brave median lower bound | 16,334,249,687 |
| Highest Vox upper bound | 30,273,445,119 |
| Lowest Brave lower bound | 16,231,931,273 |

The conservative observed ratio is **1.8651**. The exact gate fails:
`100 * 30273445119 > 95 * 16231931273`. No samples are excluded. Both engines
use exclusive coalition counters and the original single SOCKS capture, author
scripts, five-second unfocused settle, empty private profiles/caches, 1024×768
viewport and scale 2. OS filesystem/shader caches remain retained. The boundary
includes browser/window startup and PNG encoding; Brave also includes CDP PNG
delivery. GPU execution and outside services remain excluded.

Host contention is substantial: starting load averages for Vox captures span
35.76–91.49 on 18 CPUs, while frame checkpoints range 212–310. An instrumented
compiler and other host work ran concurrently. This verifies a failed target on
this pinned build; it does not attribute historical count differences to an
individual optimization or establish live-site performance. The guard adopts
51 process identities and peaks at 1,846,689,792 bytes. Driver/guard child exit
one reflects the failed target, with all browser/kernel exits zero. No broad
checkpoint is due and no qualifying catalog entry is added.

The [sealed-profile and seven-pair receipt](performance/chatgpt-sealed-profile-20261105.json)
links all counters, PNGs, ownership audits, host observations, commands, guards
and build identities in verified durable archives. Earlier cohorts remain below.

A newer four-pair animation-clock diagnostic observes 1.860% fewer candidate
instructions than its matched control, with exact pixels and 47 broad checks
passing. It remains below seven-pair acceptance and above Brave's count; see
[HTML animation clock ownership](#november-5-html-animation-clock-ownership).

The latest four-pair URL-input-cache diagnostic observes **3.432% fewer
instructions than its matched base-only control**, with exact page pixels and
32 focused plus 47 broad check jobs passing. Its production bundle uses parallel
C/ThinLTO; the comparison pins one executable for both variants. Each diagnostic
has its own control. The Brave target remains unmet; see
[admitted URL input caching](#november-5-admitted-url-input-caching).

## Previous complete baseline

The requested 5% advantage over Brave remains **unmet**. The earlier complete
cohort uses production executable `95bb7c3db15e05f49facaac092c1e83c012adddaed3c24c3ad74d4a452b21240`
and seven alternating fresh Vox/Brave pairs. All fourteen observations exited
successfully and matched the retained document PNG exactly, with complete content,
readiness, bootstrap and ownership audits.

It uses the authorized replacement fixture, now committed under
[`Tests/Browser/Brave/archives/chatgpt-home-20261104-v2`](../Tests/Browser/Brave/archives/chatgpt-home-20261104-v2).
Its reference was established once and validated in two additional fresh Brave
replays before measurements. Raw evidence is also packaged in version control
so another `Build/` cleanup will not remove it.

| Launch through document PNG encoding | Retired CPU instructions |
| --- | ---: |
| Vox median | 33,643,398,375 |
| Brave median lower bound | 20,843,396,122 |
| Highest Vox upper bound | 33,852,620,702 |
| Lowest Brave lower bound | 16,834,385,510 |

The conservative observed ratio is 2.0109. The exact gate fails:
`100 * 33852620702 > 95 * 16834385510`. Every sample is retained, including the
lower-count seventh Brave observation. All browser/kernel exits are zero; driver
and guard child exits are one solely because the requested threshold fails.
Exact counts, commands, identities, ownership audits and boundaries are in the
[replacement receipt](performance/chatgpt-baseline-20261104-v2.json), with
[complete controlled-job evidence](performance/chatgpt-baseline-20261104-v2-evidence.zip).
No qualifying entry is added to `OPTIMIZED_SITES.md`.

The workload replays the new anonymous homepage captured through SOCKS; all
measurement runs use disk replay without forwarding. Original author scripts remain
enabled under JavaScriptCore; the homepage bootstrap executes. Both engines
use a 1024×768 CSS viewport, scale 2, unfocused documents, five-second settle
period and fresh private profiles/caches. OS filesystem and shader caches are
retained. Exclusive resource-coalition counters include startup and exited
helpers; GPU execution and outside services are excluded. Brave's endpoint
also includes CDP PNG delivery. These are startup/capture workflow counts,
with no live-site, signed-in conversation, isolated-render-time or FPS claim.

The earlier `401745782b25...` cohort recorded Vox/Brave medians of
32,363,448,715 / 16,375,554,889 and a conservative ratio of 2.0535. Its raw
`Build/` inputs were deleted by disk cleanup; historical counts survive in the
[earlier receipt](performance/chatgpt-instructions-20261104.json). The replacement
does not reconstruct those deleted source bytes. Its reference PNG happens to
have the same `6e81a153...` byte hash, but differing archives prevent crediting
instruction changes across these workloads.

The first replacement attempt timed out at the CDP socket's generic fifteen-second
limit before recording any response. The corrected watchdog completed the page
and saved 311 response URLs. The raw capture remained unsealed because the
homepage and two preparation endpoints varied during that navigation. Disk-only
sealing preserved the first response for each URL and all alternate bodies;
no further fetch or body substitution was used. This frozen-response fixture
does not emulate request-dependent APIs or establish chat-submission behavior.

The capture fixes pass 34 tooling tests and a real loopback Brave check of HTML,
module JavaScript, binary bodies and redirects. Browser profiles remain in
`Build/`; the source fixture, reference and capture provenance are committed.

The probed native ink scan showed a 144,206,062-instruction conservative saving
in its matched component-library page trials. Its broad checkpoint passed ten
native scripts, SVG ASan, 100 exact upstream AST cases and twenty screenshot
checks with unchanged references/tolerances. Literal media-query caching and
primitive URL string projection are committed and execute in the production
page. Their focused checks pass in both GC modes, including controls. URL
projection improves the isolated component test, but whole-page trial ranges
overlap, so it receives no conservative page-level instruction credit.

An earlier seven-pair attempt failed because a preexisting interactive Brave
window spawned a new renderer during measurement. Commit `9dfcb790e` verifies
the new helper's pinned ancestry, creation times, executable and separate
coalition before excluding it; ninety counter/harness tests pass. The failed
cohort is retained. This audit correction earns no engine optimization credit.

## V compiler profile

The requested `v -profile` diagnostic now completes on the same saved page with
the original scripts, bootstrap marker and **zero differing pixels**. It uses
`-profile - -profile-no-inline -profile-fns main__main`, an instrumented `-O1`
standalone executable, and the canonical installed native libraries. Generated
compiler inputs and the executable are pinned; the shared source checkout
changed during generation, so this identifies an executable rather than a clean
source commit. No app bundle or source tree was copied.

| V function boundary | Calls | Inclusive ms | Self ms |
| --- | ---: | ---: | ---: |
| `end_chromium_text_scroll_layer` | 43 | 3,779.516 | 3,779.516 |
| `array.get` | 166,018,177 | 1,592.800 | 1,592.800 |
| `ModuleHost.supply` | 265 | 12,975.292 | 1,157.963 |
| `Runtime.call_engine_function` | 2,887 | 8,312.833 | 924.719 |
| `BrowserApp.draw_command` | 609 | 1,198.354 | 836.845 |

These are instrumented elapsed times. Self time includes native/JavaScriptCore
calls, waits and instrumentation overhead; it cannot separate CPU work from
GPU or OS waits. Inclusive rows overlap, and a recursive function's aggregate
inclusive time can exceed the run's wall time. The main-thread scope excludes
V module initialization and unscoped background-thread counters.

Short-settle captures ended before the author bootstrap and are retained as
failures. The successful diagnostic explicitly uses a **30-second settle**,
versus five seconds for acceptance. Its standalone filter-worker entry also
differs from the production minimal helper. It earns no instruction or Brave
acceptance credit. The [profile receipt](performance/chatgpt-v-profile-20261104.json)
records all attempts, rankings from the 11,269-function report, input identities,
compiler flags, memory guards and the raw report hash. The original 5% goal remains open.

Summarize the retained raw report with:

```sh
python3 tools/summarize_v_profile.py \
  Build/chatgpt-v-profile-20261104-1230/current-settled/profile.txt \
  --output Build/chatgpt-v-profile-20261104-1230/current-settled/summary.json
```

The summary tool's eight tests cover units, independent rankings, mixed-process
duplicate rejection, malformed counters and negative-self diagnostics.

## Selective performance collection experiment

An offline audit of 292 saved scripts found four review candidates. Existing
EasyPrivacy rules already block ChatGPT's event endpoints. The analytics module
has eight static importers, and native telemetry also performs service-worker
cleanup and lifecycle work, so a filename-based block would remove required
behavior. The [tracking audit](performance/chatgpt-tracking-audit-20261104.json)
retains the dependency graph and rule decisions.

The comparison tool now accepts `--script-policy chatgpt-home-performance` for
an explicit experiment on the sealed anonymous homepage. It verifies the exact
manifest and script hashes, creates an independent derived fixture, and bypasses
performance collection while preserving the module's exports, promise contract,
queue/observer cleanup and original fallback for other pages and authenticated
users. The HTML and other scripts retain their original bytes. Both browsers
receive the same changed script policy; this supplies no engine optimization
credit or live-site result. Default production filtering is unchanged.

A separate `--policy-diagnostics` run confirms that the guard executes in both
engines, with bootstrap completion and exact pixels in all four captures. Eight
uninstrumented observations then alternate original/suppressed/suppressed/original
policy pairs, using production executable
`19356cf6d7702f408fcb22c0a4a9ebdd40d069d6c3da630ecdd3af77ff80619e`.

| Two-trial diagnostic median | Original instructions | Suppressed instructions |
| --- | ---: | ---: |
| Vox | 33,536,277,314.5 | 33,139,297,591 |
| Brave lower bound | 16,369,831,910 | 16,358,415,242.5 |

The observed Vox median reduction is 1.184%; the small cohort's conservative
reduction is 205,996,983 instructions (0.616%). Brave's ranges overlap. All eight
browser/kernel exits are zero and every content/pixel check passes, with stable
inputs. Each one-pair API invocation retains its ordinary summary error because
that summary requires two pairs. Aggregating the two retained pairs per policy
provides diagnostic statistics only; the seven-pair acceptance minimum remains
enforced. Host load is 42–45 on 18 logical CPUs, limiting attribution.

Both original trials request the performance module twice and web-vitals once;
suppression requests neither, while native telemetry and service-worker cleanup
remain requested in both engines. Complete original web-vitals execution in Vox
is unproven. Visible homepage correctness does not establish signed-in or chat
submission behavior. Suppressed Vox still costs about twice Brave. The
[experiment receipt](performance/chatgpt-performance-policy-20261104.json)
preserves exact counts, all attempts, hashes, ownership audits, commands and guard
exits. The original 5% goal remains open.

## URL ASCII classification

The next engine change replaces repeated character-array scans with bounded
64-bit membership masks. It covers forbidden host characters and all nine
percent-encode sets. Unicode, invalid code-point values and the boundary between
the two ASCII words retain their original behavior. The earlier V profile
recorded 1,057,335 host checks and 2,798,357 extra-character membership checks.
The original implementations remain available with
`VOX_DISABLE_URL_ASCII_MEMBERSHIP=1` for matched controls; a separate
`VOX_URL_ASCII_MEMBERSHIP_DIAGNOSTICS=1` run verifies both optimized paths.

All 103 URL cases pass in both GC modes with both implementations, including an
independent exhaustive comparison across U+0000–U+10FFFF and large invalid
values. Candidate verification combines twenty passing files with the recovered
file-origin test. That preexisting test required sum-type method dispatch before
narrowing for the current compiler; every assertion is retained. The initial
cached bridge-link failures and original narrowing failures remain recorded.

A separate optimized component benchmark parses and serializes the saved
archive's 305 response URLs one hundred times. Its matched
control/candidate/candidate/control trials preserve the same result checksum.

| 30,500 URL parse/serialize operations | Retired CPU instructions |
| --- | ---: |
| Control median | 1,957,572,915.5 |
| Candidate median | 1,817,028,482 |
| Conservative reduction | 134,270,407 |

The component median falls 7.18%. These counters cover the parsing loop only,
excluding launch and input loading; they do not establish a page or Brave gain.
Original author scripts remain unchanged. The
[URL optimization receipt](performance/chatgpt-url-ascii-20261104.json)
records the exact commands, raw counts, checks and production validation status.

The initial production page validation was pending. The first shared replacement failed at
linking when the disk filled; the next attempt also failed with insufficient
space and could not finish its guard receipt. Space later became available and
another shared build began. The completed bundle available during the bounded
wait lacks the URL masks, so it cannot validate this code. The failed attempts
and the pending build are recorded; one earlier failed receipt disappeared
during external disk cleanup, and the receipt distinguishes its captured
transcript from original files. No page instruction saving, broad-cadence
advance or Brave acceptance credit is claimed for this change yet.

Production executable
`0994c97bdcaddf9dedbcbcea73c1b6c97e1d41323c10b0324df0867284787d7f`
now contains the URL masks. A fresh process passes the embedded JavaScript DOM
mutation/click checks and native wheel-routing checks with stable executable and
runtime input identities. This is startup evidence, not a ChatGPT page result.

The first page-test preflight found that cleanup had also removed the old
pixel-diff helper. Its replacement passes independent exact/mismatch controls.
A recovery survey then found the original sealed archive and retained PNG/audit
missing, with no matching copy in the surveyed repository manifests, document
PNGs, named ChatGPT directories or default Vox page caches. No browser comparison
launched, no page was downloaded again, and no reference was regenerated.

The comparison driver now verifies retained input files and archived body hashes
before creating an output directory or starting browser setup. Twenty-eight
focused tooling tests pass, including missing inputs, corrupt/deleted bodies,
the audit's companion PNG, executable checks and input preservation. The
[production follow-up receipt](performance/chatgpt-url-ascii-production-20261104.json)
records the startup, recovery, preflight failure and exact missing-input hashes.
The original single-download restriction requires authorization before replacing
the lost fixture with a fresh SOCKS capture and a separately labelled baseline.

That authorization was subsequently supplied by the user's continuation. The
replacement above now completes production page validation. A separate two-pair
diagnostic confirms both URL mask paths execute on this exact production build.
All four diagnostic captures and eight uninstrumented matched captures pass the
same pixel/content checks with stable inputs.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Scanning control median | 33,693,295,061.5 |
| Mask candidate median | 33,621,009,236.5 |
| Conservative reduction | −115,247,033 |

The median point reduction is 72,285,825 instructions, but the trial ranges
overlap. The URL masks receive zero conservative page credit, and the cumulative
5,000,000-instruction broad-check cadence does not advance. Their isolated 7.18%
component gain is not a whole-page gain. The replacement receipt retains every
control, candidate and diagnostic observation separately from the seven-pair
Brave comparison. No reference or tolerance was changed to obtain credit.

## Contoured compositor leaves

Commit `6d335d14a` avoids a redundant leaf raster when an isolated compositor
picture already owns the complete contoured fill, border or shadow. The existing
clip, ink-bound and deferred-publication guards retain the ordinary fallback,
including a full redraw if publication fails. The focused native checks cover
162 exact scenes and guard/failure cases, plus 24 existing exact Brave
picture/native cases, at both raster scales.

Two separate page diagnostics verify that each capture records 32 contour calls
and defers three eligible leaves: two shadows and one border. Loader logs verify
the candidate native library. Four uninstrumented captures then alternate
control/candidate/candidate/control in the same installed executable and candidate
bridge. All twelve Vox/Brave diagnostic and matched captures retain the original
author scripts and pass unchanged pixel/content checks, with stable inputs.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Ordinary leaf control median | 33,255,021,540 |
| Deferred leaf candidate median | 33,050,893,475 |
| Conservative reduction | −127,861,982 |

The median point reduction is 204,128,065 instructions, but the ranges overlap.
This change receives zero conservative whole-page credit and does not advance
the 5,000,000-instruction broad-check cadence. The selected library is unpublished;
these fresh production-executable processes establish component validation, not
production-bundle acceptance. The original 5% Brave goal remains open.

The [contour receipt](performance/chatgpt-contour-defer-20261104.json) retains
every count, command, guard exit and identity, including the two preflight failures
that occurred before compilation/browser launch. Its linked evidence archive
preserves raw logs, counters, audits and PNGs independently of `Build/` cleanup.
No additional live download or reference/tolerance change was made.

## CSS numeric dimension iteration

The retained V profile recorded 713,035 calls to numeric-type entry selection.
Commit `22f933332` replaces the repeatedly allocated seven-dimension vector with
a fixed array, retaining the order and all eleven callers' numeric algorithms.
The profile used the earlier archived page; a production run on the replacement
fixture is still required before attributing a whole-page gain.

All 78,125 combinations of absent, zero, negative and positive exponents pass in
default GC, `-gc none`, and `-prealloc -gc none` modes. The checks cover dimension
matching, copying, inversion, percentage hints, cancellation and serialization
order. Another 32 existing calculation/resolution tests pass in both GC modes.
Under `-prealloc`, 4,096 visits to the dimension list consume zero arena bytes.

An optimized component benchmark compares the old dynamic-list selector with
the public fixed-array selector in one executable. All four alternating trials
verify equal results over the complete exponent corpus before measurement.
Counters surround 781,250 selections, excluding corpus construction and launch.

| Two component trials per implementation | Retired CPU instructions |
| --- | ---: |
| Dynamic-list control median | 126,292,238.5 |
| Fixed-array candidate median | 24,950,272.5 |
| Conservative component reduction | 100,538,370 |

The component median falls 80.24%. This is not a page or Brave gain and receives
zero whole-page credit or broad-cadence advance. The latest completed production
bundle recorded in the receipt predates this CSS change. Shared builds own the
pending replacement; no duplicate production build was queued.

The first optimized component compile also exposed a deprecated `usize` in an
existing allocator helper. Commit `1d90f6b86` uses explicit 64-bit address
arithmetic. Production-mode idle-page retirement and cross-thread pool tests
pass, followed by the successful optimized component build.

The [numeric iteration receipt](performance/chatgpt-numeric-iteration-20261104.json)
and its linked evidence archive preserve every compile attempt, command, guard,
counter, checksum and source identity, including the one-off benchmark input.
Production ChatGPT validation and the requested 5% Brave advantage remain open.

Production executable
`8eeafcba18c3a7fa5b216063dc3b3785eb1c179d9cd9ff6e5015088f0e064269`
now contains the numeric-array change. Five fresh Vox observations pass the
unchanged pixel, complete content and author-bootstrap checks. Their surrounding
browser comparison attempts are both invalid and receive no instruction credit.

The first seven-pair attempt stopped after pair two: its ownership audit rejected
new renderers of a pinned, unrelated interactive Brave root whose command had no
arguments. Commit `c1dd3bbc5` recognizes an exact executable command as well as
one with arguments, retaining creation-time, ancestry, executable and separate
coalition checks. Twelve focused ownership tests and 264 instruction-tool tests
pass. A live identity check confirms three surviving rejected helpers belong to
the older interactive root and its separate coalition.

The corrected protocol completed three pairs and a fourth Brave observation,
then rejected the cohort because a new shared production bundle replaced its
pinned inputs. All eleven observations across both attempts remain recorded;
neither partial cohort can satisfy the seven-pair acceptance rule. The
[production follow-up](performance/chatgpt-numeric-production-20261104.json)
preserves the failures, tool checks, input identities and raw evidence. There is
no isolated page credit for the numeric change: these different browser builds
do not supply a matched control.

## Animation arena ownership scans

The earlier V profile recorded 495,660 conservative scans of retained animation
style records. Commit `0ab6f0528` reads each settled arena's address envelope once
per record, rejects words outside it, and keeps the exact block-ownership check
for possible matches inside it. Holes between mapped blocks remain unowned.
`VOX_DISABLE_ANIMATION_SAMPLE_WORD_PREFILTER=1` retains the original scalar loop
for matched controls.

Sixteen focused runtime executions pass: byte boundaries at every candidate word
position, block starts/ends, unrelated pointers, partial words, empty/reset/
released arenas, and existing typed-payload, property-page, density-projection
and target-storage lifetime cases. Candidate, scalar-control and poisoned-arena
runs preserve the same ownership decisions. Default GC, `-gc none` and production
`-prealloc` platform checks also pass.

| Two component trials per implementation, 256,000 records | Retired CPU instructions |
| --- | ---: |
| Scalar control median | 233,335,805 |
| Prefilter candidate median | 201,916,609 |
| Conservative component reduction | 31,275,652 |

The component median falls 13.47%; it excludes browser launch and rendering.
Separate fresh production processes on executable
`666161a760ca7d580cfba54d07d4a2cc1a24ab465065dafb18f53980e3b9d968`
confirm that the optimized CSS branch executes on the replacement ChatGPT page.
Both diagnostic pairs and all four uninstrumented matched pairs pass unchanged
pixels, complete content, script bootstrap and kernel-exit checks with stable
inputs. Both browsers use their canonical installed bundles and the original
author-script bytes; no library is injected.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Scalar control median | 33,088,309,954.5 |
| Prefilter candidate median | 33,073,731,227 |
| Conservative reduction | −299,880,878 |

The whole-page ranges overlap. The median point reduction is only 14,578,727.5
instructions, so this change receives zero conservative page credit and no
5,000,000-instruction broad-cadence advance. The 5% Brave target remains unmet.

A subsequent native stack sample used a different 15-second settle. Its Vox
document retained exact content/bootstrap but differed in 25,320 pixels within
a 334×80 device-pixel cookie-button rectangle, with maximum channel error 13.
That exploratory attempt stopped after one pair and receives no performance
credit; its native trace and both browser observations are retained. The
five-second diagnostic and matched captures above remain separate and exact.

The [arena scan receipt](performance/chatgpt-arena-words-20261104.json) and its
linked evidence archive preserve every test, failed compile, diagnostic,
control/candidate count, PNG, audit, native sample, input identity and guard exit.

## Tab favicon discovery

The exploratory native trace also showed repeated document-head walks and
`link_relations` parsing beneath chrome favicon updates. That failed sampled
capture supplied a hypothesis only. Commit `1f8baee0b` caches discovery using
document identity, tree and attribute versions, document/base URLs and encoding.
The new DOM attribute version tracks edits that leave tree structure unchanged.
Chrome retains owned strings and scalar identities, and reuses the strings when
an unrelated attribute edit invalidates discovery without changing either URL.
The original live scan remains available with
`VOX_DISABLE_TAB_FAVICON_DISCOVERY_CACHE=1`.

Five focused cache cases pass with default GC and the production allocator,
including the original control and poisoned-memory runs. They cover live href,
rel and node-backed attribute edits, head tree order/removal, base/document/about-
base URL changes, encoding, empty results, navigation and retired caller/document
storage. The allocation checks verify 128 warm lookups add zero arena bytes and
128 unrelated invalidations retain fewer than 1,024 base-arena bytes. Separate
DOM-version, base-element lifecycle and existing favicon image/fallback checks
also pass. The final cache suite was recompiled after the string-retention
refinement; prerequisite results retain their earlier source identities.

Production executable
`7aa5ec34a86aaf97eb46225343d5b608d9d01b74901b9c82c192790ecce0b489`
contains the final retention guards, verified in its frozen generated function.
Two separate diagnostic pairs confirm both initial scanning and cached lookups
execute on ChatGPT. All four captures pass unchanged pixels, complete content,
author bootstrap and kernel-exit checks with stable inputs. Four captures from
the preceding implementation revision remain separately labelled.

The uninstrumented control/candidate cohort stopped in its first pair. Vox's
control observation completed, but Brave's ownership audit rejected a transient
crash handler and code-sign cleanup helper outside the measured coalition. Both
were observed with parent PID 1 and had exited before a later identity survey;
their earlier ownership cannot be established. No candidate observation,
instruction reduction or acceptance statistic can be computed from that cohort.
It receives zero page credit and no broad-cadence advance. The 5% Brave goal
remains unmet.

Commits `9c4f681b5` and `8fb5d3f23` enrich future failure receipts with creation
times, executable paths and coalition identities through two observations. These
extra reads run only for rejected helpers; every ownership rejection remains in
place. The final 268 instruction-tool tests and 15 helper-identity tests pass.
This diagnostic improvement does not repair the earlier cohort.

The [favicon discovery receipt](performance/chatgpt-favicon-discovery-20261104.json)
links durable raw commands, compiler/runtime identities, guards, audits, PNGs and
every attempt. Trials use the retained SOCKS capture and original author-script
bytes, with no additional live download or reference/tolerance change.

The subsequent [favicon follow-up receipt](performance/chatgpt-favicon-followup-20261104.json)
records a complete, separately pinned cohort using production executable
`5aea11987f231d53605b77e66b3e53ea13be353e0a585710cd86be6e774fddf4`.
The ownership checks remain unchanged. Two diagnostic pairs confirm live
discovery and cached lookup, and four uninstrumented alternating browser pairs
complete with exact pixels, content and author bootstrap. All browser and kernel
exits are zero, adopted browser RSS is accounted for, and inputs stay unchanged.
Vox's implementation order is control, candidate, candidate, control.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Original discovery median | 33,730,590,481.5 |
| Cached discovery median | 33,454,034,495 |
| Conservative reduction | 72,701,625 |

The median reduction is 276,555,986.5 instructions, or 0.820%. The conservative
reduction subtracts the highest candidate count from the lowest control count.
This is a small matched experiment on one pinned build; shared host contention
and every raw count remain recorded. It does not establish seven-pair acceptance
against Brave. The mixed control/candidate cohort's worst Vox/Brave ratio is
1.7934, and the 5% Brave target remains unmet.

The saving crosses the 5,000,000-instruction regression threshold. The completed
47-job checkpoint includes six pixel-diff controls, 20 visual cases, 11 native
renderer tests, and all 100 upstream AST fixtures with default GC and `-gc none`.
Seventeen visual cases are exact, including all nine SVG mutation cases; the
other three pass their existing canonical tolerances. Every compile and runtime
guard exits zero. Visual checks pin a later completed production bundle
independently; they do not replace the performance cohort's executable identity.
The broad-check instruction cadence resets after this checkpoint. The earlier
ownership-rejected attempt remains retained in its original receipt.

## Overlapping scroll-raster rows

Commit `19ab7a17f` forms the union of exposed and damaged device-row intervals
before storing the final canvas in the scroll raster ring. Damage rectangles can
cover the same rows even when they are separate horizontally. The planner uses
a fixed 49-entry stack array, bounds every interval, and merges adjacent or
overlapping ranges without allocating. The existing pitched ring-copy helper
stores each resulting range once.

The planner passes 39,000 coverage/canary cases plus `SIZE_MAX` boundaries.
Another 395,136 scalar/union pixel cases exercise every tested ring origin,
padded pitches, zero/full/partial exposed strips, and zero through 48 damage
rectangles. Both suites pass normally and with AddressSanitizer and
UndefinedBehaviorSanitizer. Existing scroll-raster regression checks pass too.

Production executable
`4d55ec4468623f9d2449dd9fef4c3a34515da8ce9a0a99faf33035cab142bc34`
contains the development implementation, verified against its frozen compiler
input. Two separate diagnostic pairs pass exact content, author bootstrap,
pixels and exits; each Vox run reports an initial union avoiding 72 duplicate
rows across 16 input ranges. The optional diagnostic in this bundle predates
the extra owner/dimension fields; its uninstrumented planner and copying work
match the committed implementation.

| Two matched Vox trials per implementation | Launch-to-PNG instructions |
| --- | ---: |
| Original separate stores median | 31,527,939,267.5 |
| Union stores median | 32,154,424,113.5 |
| Conservative reduction | −701,563,198 |

All eight uninstrumented browser captures pass with stable inputs. The candidate
median regresses by 626,484,846 instructions, or 1.987%. It also completes 250
and 266 settling frames, compared with controls' 196 and 220. A layout checkpoint
differs too, and shared host load is high and variable. These differences leave
causal attribution unresolved; reduced duplicate copying has not established a
whole-page gain. No saving or broad-cadence advance is credited.

Commit `4debf9168` therefore keeps the original default and requires
`VOX_ENABLE_SCROLL_RASTER_ROW_UNION=1` to opt into the experiment.
`VOX_DISABLE_SCROLL_RASTER_ROW_UNION=1` still forces the original path. The final
focused suites repeat every case and compare default, forced scalar and explicit
union results in both sanitizer modes. They all pass. At that point, production
validation of the final opt-in gate was pending; the earlier measured executable
could not validate code added afterward.

The [row-union receipt](performance/chatgpt-row-union-20261104.json) links both
focused revisions, all diagnostic and matched observations, PNGs, counters,
commands, host loads, frozen function excerpts and memory-guard exits. The
original 5% Brave goal remains unmet.

The subsequent [production gate receipt](performance/chatgpt-row-gate-20261104.json)
closes that validation gap using completed production executable
`6e17496ff30b300a11d6d015d162d4e8a9ed40e5b6717f6ecd0c96d12724d332`.
Its frozen planner, ring-copy helper and complete store function match the final
opt-in source. Four fresh Vox processes run default/opt-in/opt-in/default,
interleaved with four Brave references. All eight captures pass exact pixels,
content, bootstrap and zero browser/kernel exits, and every input identity stays
stable. Default runs report no union execution; both explicit opt-in runs report
72 duplicate rows avoided across 16 input ranges merged into 13 at 2048×1536.
The diagnostic confirms the final gate and content, with no performance credit.
The original page regression remains retained, and the broad cadence stays zero.

## Follow-up diagnostic boundaries

The [frame-phase receipt](performance/chatgpt-frame-phases-20261104.json) preserves
two new instrumented pairs with the same five-second frozen workload and
production executable `4d55ec4468623f9d2449dd9fef4c3a34515da8ce9a0a99faf33035cab142bc34`.
`VOX_DIAGNOSTIC_FRAME_PARTS=1` records explicit frame boundaries, while
`VOX_DIAGNOSTIC_STYLE_REASONS=1` records cumulative style-update visit counts.
All four captures pass unchanged pixels, content, bootstrap and exits, with
stable executable, library, fixture and tool identities.

| Process instructions within frame intervals | First Vox run | Second Vox run |
| --- | ---: | ---: |
| Completed frames | 169 | 177 |
| Document replay intervals | 5,960,598,681 | 5,833,710,358 |
| Chrome update intervals | 35,274,221 | 41,735,361 |

These are differences of current-process cumulative counters at ordered frame
boundaries. Concurrent threads in that process can contribute. They are not
exclusive function costs or the separately measured coalition totals. Other
consecutive log intervals ending at `build_boxes` accumulate 12.16–12.32 billion
instructions, but include preceding style, event-loop and concurrent work; those
numbers cannot be attributed to the box builder alone. Full-document style
updates visit 2,681 elements in each run, and node-specific updates visit 1,925.
The measurements identify replay and style/layout preparation as further areas
to investigate. They provide no optimization credit.

Three additional native sample files contain process/image metadata but no
thread stacks or call graph. The first twelve-second sampler also exceeded its
twenty-second finish wait. Two later three-second samplers exit zero and their
four browser captures pass, but their empty graphs remain unusable for hotspot
attribution. The receipt retains the failed attempt and both subsequent files;
a successful sampler exit or present output file is not profiling evidence.

## Unit-opacity integer compositing

Commit `ba84455e0` replaces float normalization and fused arithmetic with an
exact NEON integer calculation for mixed-alpha spans at group opacity 1 and
round-to-nearest mode. It computes `s + round(d * (255 - a) / 255)` with bounded
16-bit products and saturating byte addition. The odd denominator has no
half-level ties. Empty and fully opaque vector blocks retain their existing
shortcuts; scalar tails, other opacities and other rounding modes retain the
previous arithmetic. `VOX_DISABLE_UNIT_OPACITY_INTEGER=1` selects the original
float SIMD control.

The independent float/FMA oracle matches all 134,217,728 exhaustive pixels in
both ordinary and AddressSanitizer/UndefinedBehaviorSanitizer runs. Coverage
includes every source/background byte and source coverage at eight opacities,
varying backdrop alpha, invalid premultiplication, saturation, unaligned buffers,
in-place output, vector tails, runtime control selection and rounding modes.
Each run also passes 33,280 ink-bound cases. Native integration passes 144
shared-layer scenes, 720 exact raster comparisons and empty-prefix ownership,
backdrop and cleanup checks.

Tooling commit `336f4cf49` adds a component benchmark. Every scene composites
2,097,152 pixels across repeated 2048×128 surfaces. Process instruction snapshots
bracket the compositing loops; input construction, checksums, startup and
teardown are excluded. Two uninstrumented observations per implementation run
in control/candidate/candidate/control order, followed by a separate diagnostic.
All scene checksums match.

| Component scene | Float control median | Integer candidate median | Conservative reduction |
| --- | ---: | ---: | ---: |
| Mixed alpha | 53,838,610 | 14,168,321.5 | 39,418,080 |
| Mixed, empty and opaque blocks | 22,545,696 | 9,355,027 | 13,184,623 |
| Sparse mixed alpha | 9,467,415.5 | 7,012,723 | 2,440,446 |
| Opaque | 7,870,157.5 | 7,861,708.5 | 0 |
| Empty | 6,551,063.5 | 6,550,963.5 | −25 |

The mixed-alpha median reduction is 73.684%; mixed blocks improve by 58.506%
and sparse blocks by 25.928%. The unchanged and negative controls remain in the
report. These component results do not establish a ChatGPT saving.

A separately compiled current graphics library was inserted into the latest
completed browser for two diagnostic Vox/Brave pairs. All four captures pass
unchanged pixels, content, bootstrap and exits with stable inputs. The selected
library is logged, but neither Vox run reports an executed mixed-alpha integer
span. The older main executable still contains its previous static compositor;
these diagnostics cannot establish eligibility of the new main-executable path.
At that point no unprofiled page comparison or broad-cadence advance was
credited, and whole-browser validation required a newer shared production build.
The production follow-up below establishes execution of the integer path, with
no confirmed page-level saving. The 5% Brave target remains unmet.

The [unit-opacity receipt](performance/chatgpt-unit-opacity-20261104.json) links
all focused checks, component counts, both exact diagnostic pairs, source and
library identities, commands, host loads and actual memory-guard exits. It also
retains the initial benchmark compile failure caused by a POSIX macro hiding
Darwin libproc types; the same source compiles after removing that flag. No
additional live download, altered script, reference or tolerance was used.

## Refreshed V profile

The [fresh V profile receipt](performance/chatgpt-v-profile-refresh-20261104.json)
records a separate `v -profile - -profile-no-inline -profile-fns main__main`
diagnostic. It uses a standalone signed executable, C `-O1`, thread-local profile
scope and a thirty-second diagnostic settle. JavaScriptCore executes the original
author bootstrap, all content checks pass, and the document is pixel-exact to the
unchanged retained reference. All 11,305 function rows are unique and no self
time is negative. No production bundle or source tree was copied.

Initial source sealing rejected a repository input change during V generation.
That failure remains retained. A separate diagnostic sealed the unchanged
generated C and its native/link inputs with normal checks. Its generated,
preprocessed and executable hashes identify the diagnostic; it cannot attribute
cost to a single source commit or establish an unprofiled speedup.

| Instrumented function | Calls | Self time |
| --- | ---: | ---: |
| Text-scroll layer completion | 91 | 2,564.017 ms |
| Contoured corner drawing | 632 | 2,220.060 ms |
| `array.get` | 140,315,258 | 1,367.449 ms |
| `CSSRuleList.evaluate_media_queries` | 6,704,997 | 525.429 ms |

Self time includes native/JSC callees and waits. Recursive inclusive rows overlap
and must not be added or treated as CPU instruction partitions. The thirty-second
settle and profiling instrumentation differ from acceptance conditions. The
repeated media-query traversal is a lead for a focused empty-child-list guard;
this profile gives no page credit or broad-cadence advance.

## Production follow-up and evidence retention

An initial production unit-opacity follow-up completed its captures, but its
raw `Build/` directory disappeared before durable archival. The separately
[qualified historical record](performance/chatgpt-unit-opacity-production-20261104-missing.json)
retains the values previously printed by the tools: control and candidate
medians of 31,447,108,311 and 32,142,181,927 instructions, respectively. The
original counters, PNGs, audits and guards cannot now be independently checked.
Those figures receive no independently verified credit and have not been
reconstructed as raw evidence.

Fresh [production diagnostics](performance/chatgpt-media-diagnostic-20261104.json)
pin executable
`2550c9ecb64182bed1badb761c10ca6f11bdf116d0cfbf8a4a10d64a58428a44`.
Both Vox processes independently report an executed integer mixed-alpha span
of 1,596 pixels. All four Vox/Brave captures pass exact pixels, content, author
bootstrap and browser/kernel exits with stable inputs. This closes the path
eligibility gap without granting performance credit.

The new controllers atomically journal the raw evidence under `docs/performance`
after every observation, outside `Build/`. Their ZIPs retain earlier checkpoints,
production and frozen compiler receipts, commands, logs, counters and PNGs.
Archive writes occur after each browser's capture and teardown, outside its
instruction interval. The initial preflight failure caused by a removed diff
binary is retained too; the replacement diff tool passes strict unchanged and
one-pixel-change controls. Actual controller and memory-guard exits are zero.
The comparison driver returns one for the unmet Brave gate, separately from
successful browser exits.

## Empty nested media-query lists

Commit `1c32ec1ef` checks each nested rule list's live length before recursing
into it. Empty lists contain no media state to evaluate. The containing rule's
condition and imported stylesheet media still run, and later CSSOM insertions
and removals require no cache invalidation. Nonempty lists retain the previous
traversal. `VOX_RETAIN_EMPTY_MEDIA_QUERY_RECURSION=1` selects the original control;
`VOX_EMPTY_MEDIA_QUERY_LIST_DIAGNOSTICS=1` reports an executed skip once.

Four new tests exercise first evaluation, viewport transitions, later nested
insertion/removal/reinsertion, inactive supports groups, and imported empty
stylesheets. They run in both GC modes with the guard enabled and disabled.
Five existing media-query tests also pass in both GC modes, covering color
scheme, fractional viewport units and display density: 26 test-function
executions in total. Current V compilation and runtime guards all pass. The
initial fixture compile error and its correction remain retained.

Tooling commit `4aaa57922` measures 512 media evaluations on the two original
archived CSS bodies after parsing and warmup. Their graph contains 10,159 child
lists, including 8,436 empty ones. Control/candidate/candidate/control component
runs produce identical zero-change checksums. Median instructions fall from
194,624,178 to 166,144,462, a 14.633% reduction; the conservative component
reduction is 27,907,522 instructions. Parsing, startup and teardown are excluded,
so these figures do not establish a browser saving.

The production diagnostic reports the empty-list skip only when enabled. A
subsequent [unprofiled matched comparison](performance/chatgpt-media-matched-20261104.json)
pins the newer completed executable
`abd2573bff7d8b855a48fdf8822e1f1a381be2a6e2e669ede9144fa259cc8927`.
Both builds' sealed media traversal and guard functions are byte-identical.
Four fresh Vox processes run control/candidate/candidate/control, interleaved
with four Brave references. Original scripts, private caches, viewport, five-second
settle and launch-to-encoded-PNG boundaries remain matched.

| Whole-page Vox result | Launch-to-PNG instructions |
| --- | ---: |
| Original recursion median | 32,177,240,225.5 |
| Empty-list guard median | 32,309,902,899 |
| Conservative reduction | −343,709,729 |

All eight captures pass unchanged pixels, complete content, bootstrap and zero
browser/kernel exits. Counts overlap, and the candidate median is 0.412% higher.
Shared host load and settling work vary. No whole-page gain is established,
and the broad-check cadence remains zero after the prior favicon checkpoint.
This four-pair diagnostic cohort is not the required seven-pair acceptance
cohort and does not meet the 5% Brave goal.

The [empty-list receipt](performance/chatgpt-empty-media-20261104.json) links
focused checks, component observations, both production identities, source
excerpts, complete diagnostic and matched journals, memory guards and all failed
attempts. No additional live download, author-script change, pixel reference or
tolerance change was used. Results remain limited to the frozen anonymous
homepage; live sign-in and submission behavior have not been established.

## Media-query candidate lists

Commit `65ad25a94` caches the ordered rules that can reach a media condition or
an import, avoiding repeated traversal through ordinary style-only branches.
Media rules remain eligible even when empty. Imports remain eligible before
their stylesheet arrives. Inactive grouping branches are included so their
first evaluation still occurs when the parent condition becomes active.
Match results are never cached.

Every CSSOM structural change increments an atomic process-wide epoch before
change callbacks. This invalidates summaries even for detached or shared lists
without parent links. Candidate buffers are reused and old references cleared;
publication uses the existing retained/persistent allocation boundaries so
scratch retirement cannot leave dangling summaries, including in shared UA
sheets. `VOX_DISABLE_MEDIA_RULE_CANDIDATES=1` selects the previous traversal.
`VOX_MEDIA_RULE_CANDIDATE_DIAGNOSTICS=1` reports a pruned list once.

Eight new tests cover filtering, nested detached/shared edits, same-length
replacement, inactive conditions, live media-text edits, late imports, ignored
group types, callback ordering and allocation lifetime. Together with the nine
existing empty-list and media-evaluation tests, they pass 68 test-function
executions in default GC and no-GC modes with both implementations. Another 16
test-function executions pass with preallocation and poisoned retired arenas;
the storage assertions execute in both of those variants. Initial compiler and
fixture failures remain retained separately from the final stable checks.

The same fixed-work archived-CSS component benchmark observes:

| 512 warmed stylesheet evaluations | Retired instructions |
| --- | ---: |
| Previous traversal median | 168,388,656.5 |
| Candidate-list median | 118,937,107.5 |
| Conservative reduction | 48,979,711 |

The median reduction is 29.368%. All evaluations retain the zero-change
checksum. Parsing, summary construction, startup and teardown are excluded;
this is a warmed traversal result, not a page-level claim.

[Production diagnostics](performance/chatgpt-media-candidates-diagnostic-20261104.json)
pin executable
`d83a3d8367719c90a632deaaabc068210b57d9dcac3104a5f7136bf7b6bf3c6e`.
The enabled process reports 155 of 206 rules pruned in its first large eligible
list; the control reports no pruning. All four captures pass exact pixels,
content, author bootstrap and exits. Sealed function excerpts establish the
candidate iteration, allocation boundaries and invalidation before callbacks.

The [first matched attempt](performance/chatgpt-media-candidates-matched-20261104.json)
is rejected because a shared production build replaced the executable during
capture. All seven observations and the failing controller/guard exit remain
retained; no partial-cohort benefit is extracted.

A [new complete cohort](performance/chatgpt-media-candidates-matched2-20261104.json)
pins completed executable
`62b566b5d18cc6658acf55c2d23b9605aad23ee1fe1ea08ee8ecd1a58147f62c`.
Its sealed candidate, traversal and change-hook functions are byte-identical to
the diagnostic's. Control/candidate/candidate/control Vox runs interleave with
four Brave references under the unchanged launch-to-encoded-PNG protocol.
All eight captures pass unchanged pixels, complete content, bootstrap and zero
browser/kernel exits, with stable inputs and successful guard PID adoption.

| Observed whole-page Vox result | Launch-to-PNG instructions |
| --- | ---: |
| Previous traversal median | 32,417,125,422 |
| Candidate-list median | 31,304,223,405 |
| Conservative observed reduction | 999,069,050 |

The observed median is 3.433% lower. However, controls complete 269 and 276
frames, while candidates complete 180 and 170; paint checkpoints vary too.
All four runs retain eleven box-building checkpoints. Host load ranges from
29.1 to 33.7 at the Vox launches on eighteen CPUs. The
[frame-work analysis](performance/chatgpt-media-candidates-frame-work-20261104.json)
retains these differences and the ordered current-process frame intervals.
Those intervals are not exclusive function costs or coalition totals. The
entire observed saving cannot be assigned to CSS traversal alone, and no
isolated engine saving is credited or acceptance endpoint changed.

The observed count difference crosses the regression threshold. All 47 broad
jobs pass: six diff controls, twenty visual cases, eleven compiled native
renderer tests, and all one hundred upstream AST fixtures in both GC modes.
Seventeen visual cases are pixel-exact, including all nine SVG mutation cases;
the other three pass their existing tolerances. Visual and feature identities
remain stable, and every compile/runtime guard exits zero. The broad cadence
is zero after this checkpoint.

Evidence review found that the six diff controls wrote their result array to
the guard's report filename. The mixed file and original zero-exit guard log
remain retained. A control-only rerun uses separate result and guard paths;
all six expected outcomes pass. This makes 48 job attempts for the 47 selected
checks, with no visual or native test retried to obtain a pass.

The [candidate-list receipt](performance/chatgpt-media-candidates-20261104.json)
links all checks, raw observations, rejected attempts, function proofs, PNGs,
guards and per-observation evidence journals. The four-pair cohort remains
diagnostic; it neither supplies seven-pair acceptance nor meets the 5% Brave
goal. Original author scripts, the single SOCKS capture and all references and
tolerances remain unchanged. No additional live download was performed.

## UTF-16 ASCII-prefix encoding

Commit `b92a8c9f1` copies the current ASCII prefix directly into a length-sized
byte buffer, then preserves the existing Unicode/WTF-8 encoding loop for the
remaining units. An empty input returns immediately. The bounded copy does not
depend on mutable storage metadata. Raw unchecked ASCII storage retains its
existing separate byte-preservation behavior.

The retained V profile reports 96,954 `encode_utf16` calls. This is a shared
string utility used by JavaScriptCore bindings; the browser's scripting backend
has not changed to LibJS. The instrumented row identifies the lead without
establishing exclusive CPU cost or runtime parity.

Sixty-four focused test-function executions pass: normal GC and no-GC runs
with both paths, plus AddressSanitizer/UndefinedBehaviorSanitizer and
preallocation runs with both paths. They exercise all 65,536 individual UTF-16
units, all 1,048,576 valid surrogate pairs in both encoding modes, nulls, prefix
boundaries, mixed tails, stale private units and returned-byte ownership.
The canonical AST driver also matches all one hundred upstream fixtures in
each GC mode, with no case overrides.

Both complete LibJS selections finish at **235/237 files passing**. The failing
files are `regex_matching_corpus_test.v` and `string_case_test.v`; both Greek
casing mismatches reproduce with the ASCII path enabled and disabled. A
separate C probe using literal bytes and units, without this encoder, reproduces
the same system-ICU results under `en_US_POSIX`. These are independent
ICU/retained-fixture mismatches. Actual nonzero test and guard exits remain
retained; no full-suite pass, skipped case or reference correction is claimed.

Tooling commit `4c5139eb8` measures conversions after input construction using
current V, C `-O2` and Boehm. The scalar control uses the same buffer setup and
trim while disabling prefix copying and the empty return. The result isolates
those paths within the shared entrypoint; it is not an earlier-release
allocation baseline. Two observations per variant run in
control/candidate/candidate/control order, followed by a separate diagnostic.

| Component scene | Scalar control median | Candidate median | Conservative reduction |
| --- | ---: | ---: | ---: |
| 311 archived URLs, 39,808 conversions | 95,520,547 | 56,272,888.5 | 38,458,289 |
| Long ASCII | 134,255,906 | 60,565,502 | 71,647,888 |
| Unicode first | 92,659,174 | 97,495,762 | −11,084,285 |
| ASCII with surrogate tail | 42,269,415.5 | 25,776,870 | 15,196,165 |
| Empty | 17,689,206.5 | 8,989,923 | 8,402,720 |

The archived-URL median falls 41.088%, and long ASCII falls 54.888%. All encode
counts and checksums match. The Unicode-first median is 5.220% higher, with
overlapping observation ranges; that regression remains in the report. These
are current-process conversion/checksum intervals including allocator and GC
work, excluding input construction, launch and teardown. They provide no
whole-page credit.

The initial prototype's empty-string median regressed 8.732%. Its in-progress
LibJS selection was deliberately stopped before adding the explicit empty
return. The prototype measurements, completed focused checks and actual
interrupted exit remain retained separately from the complete final selections.
A continuation-wrapper path error occurred before any additional test launch;
that failed preflight is retained too.

The [production prefix diagnostic](performance/chatgpt-utf16-prefix-diagnostic-20261104.json)
pins completed executable
`b3e9470671f7a1e315a7ab093c7b24492b97d8cfcbfc1d443a8c2c0abd6fefeb`.
Its enabled Vox process reports prefix execution, while its control does not.
All four captures pass exact pixels, content, bootstrap and browser/kernel exits
with stable inputs and successful guard PID adoption. The sealed encoder still
lacks the final empty-return branch. This validates the present nonempty copier
only; final production integration and an unprofiled matched page comparison
remain pending a completed bundle containing the final branch. The existing
shared build worker remains active; no separate build was launched for this
experiment.

The [UTF-16 receipt](performance/chatgpt-utf16-prefix-20261104.json) links complete
module selections, focused and AST checks, native ICU reproductions, both
component revisions and the qualified production journal. Original author
scripts, fixture bytes and references remain unchanged, with no additional
live download. Whole-page credit and the broad-check cadence remain zero.
The 5% Brave target remains unmet.

### Final encoder production validation

The later completed production bundle
`487c784603bfc8b057dce64c7107540f174b08c8e4b07cfc7c51dadcfdfefb4e`
contains the final empty-return branch in its sealed C source. Four separate
diagnostic captures verify execution of the prefix path only in the candidate.
All four pass exact pixels, content and JavaScriptCore bootstrap checks.

An unprofiled control/candidate/candidate/control sequence, interleaved with
four fresh Brave captures, also passes all eight pixel/content checks. The
launch-through-encoded-PNG Vox median falls from **33,140,397,993.5** to
**32,489,529,756.5** observed instructions, a **1.964%** reduction. The highest
candidate is 140,485,707 instructions below the lowest control. Both paths
share the new buffer setup; this is not a comparison against the complete
previous-release allocation path.

Work varies across those four Vox captures: frame-completion checkpoints are
350, 369, 386 and 359; box-building checkpoints are 11, 11, 10 and 11. The
second candidate performs one fewer box-building pass. Starting load averages
range from 113.1 to 115.1 on 18 CPUs. These differences limit attribution of
the whole-page saving to encoding, so isolated engine credit remains zero.
All browser/kernel exits and the enclosing guards are zero, input identities
remain stable, and both guards successfully account for adopted browser PIDs.
The comparison driver returns one because the Brave target remains unmet.

The observed conservative saving crosses the broad-check threshold. All
47 follow-up jobs pass: twenty visual cases (seventeen exact and three at their
existing tolerances), all nine SVG mutation cases exact, eleven native tests
compiled and executed, six diff controls, and one hundred upstream AST fixtures
in each GC mode. Every job guard exits zero. The cadence resets to zero; the
earlier 235/237 LibJS module results and independent ICU failures remain
qualified above.

The [final encoder receipt](performance/chatgpt-utf16-final-20261104.json)
links source proofs, original commands, raw counters, PNGs, host conditions,
guards and completed broad checks. This four-pair diagnostic does not establish
seven-pair acceptance or the requested 5% advantage over Brave. Original author
scripts and the single SOCKS capture remain unchanged.

## Owned URL input filtering

Commit `6f1b280b2` compacts the freshly decoded rune array instead of allocating
a second filtered array. Normal parsing still trims leading/trailing C0 controls
and spaces; state-override setters retain them. Both remove only TAB, LF and CR
internally. The UTF-8 decoder and parsed URL ownership remain unchanged.

Thirty-eight focused test-function executions pass across normal/no GC,
preallocation with poisoned arenas, and AddressSanitizer/UndefinedBehaviorSanitizer
with both implementations. All 22 URL module files also pass in each GC mode.
Cases cover every byte, BMP scalars, invalid UTF-8, control policies, independent
returned arrays and component setters. Every selected guard exits zero.

Tooling commit `d4c61162a` validates full serialized output against the 311 frozen
canonical resource URLs and fixed setter references. Separate branch diagnostics
confirm that the corrected control disables compaction.

| Component scene | Copy control median | Candidate median | Median reduction |
| --- | ---: | ---: | ---: |
| 9,952 archived URL parses | 542,639,021 | 524,037,532.5 | 3.428% |
| 9,952 parses with edge controls | 530,725,659 | 513,217,162.5 | 3.299% |
| 16,384 path overrides | 164,989,355 | 155,540,969.5 | 5.727% |

These current-process intervals include parsing, serialization, full reference
comparison, checksum, allocation and GC. Input construction and warm validation
precede the counters. They do not establish a whole-page saving. An initial C
compile failed before measurement; a subsequent controller used the wrong
environment-variable names, making every variant a candidate. Its branch check
rejected the entire cohort. Both attempts remain retained with zero credit.

Production diagnostics on two successive shared builds pass all eight exact
pixel/content captures and confirm compaction only in the candidate. The first
matched preflight rejects an executable replacement before collecting a capture.
The replacement is independently revalidated, then pinned as
`f7a36b29f87e6b334ac7aa14e177598eeb5e6ec18648f4af26e8c973090ea18c`
throughout a fresh unprofiled four-pair comparison.

All eight matched captures pass unchanged pixels, content, JavaScriptCore
bootstrap and browser/kernel exits. The Vox control median is
**32,620,265,294**, versus **32,763,713,289** for the candidate: a **0.440%
regression**, with overlapping ranges. The conservative reduction is
−639,452,640 instructions. Frame checkpoints are 339, 389, 364 and 355;
all four have eleven box-building passes. Starting host load ranges from 31.1
to 37.8 on 18 CPUs. This result earns zero page-level credit and leaves the
broad cadence at zero after the prior encoder checkpoint. It does not meet
the 5% Brave target.

The [URL input receipt](performance/chatgpt-url-input-20261104.json) retains
the component failures, rejected preflight, all successful observations, source
proofs, guards and raw PNGs. It also corrects the initial diagnostic controller's
inherited implementation tag without modifying that raw report. Original author
scripts, fixture bytes and references remain unchanged; no additional live
download was performed.

## Bulk URL authority encoding

Commit `26d7b1f24` replaces repeated rune-string allocation and prefix
concatenation while rebuilding a URL authority with V's bulk rune encoder.
Both use the same underlying UTF-32 encoder. The temporary rune slice does not
escape; the result owns its bytes. The existing parser and decoded input remain
unchanged. `VOX_RETAIN_URL_AUTHORITY_CONCAT=1` selects the scalar control, and
`VOX_URL_AUTHORITY_DIAGNOSTICS=1` reports candidate execution separately.

The retained V profile records 96,958 calls to `parser_runes_to_string`.
Thirty focused test-function executions pass across both GC modes, both paths,
poisoned preallocation arenas and AddressSanitizer/UndefinedBehaviorSanitizer.
They cover all 1,114,112 code-point values (including surrogate halves), further
invalid rune values, mixed-string subranges, embedded nulls, independent result
bytes and authority parsing. All 23 URL files pass in each GC mode. All 24
compile/runtime guards exit zero with unchanged source identities.

The existing canonical-reference benchmark supplies two unprofiled observations
per path in control/candidate/candidate/control order, followed by separate
positive and negative execution diagnostics.

| Component scene | Scalar control median | Candidate median | Conservative reduction |
| --- | ---: | ---: | ---: |
| 9,952 archived URL parses | 523,618,631 | 509,860,353.5 | 9,666,108 |
| 9,952 parses with edge controls | 517,168,700 | 501,376,831.5 | 14,031,640 |
| 16,384 path overrides | 159,696,026.5 | 159,555,202 | −366,303 |

The archived-URL median falls **2.628%**, and the edge-control median falls
3.054%. Every full serialized reference, parse count and checksum matches.
The path-override interval uses an already parsed seed and does not encode an
authority; its overlapping variation supplies a neutral control. These remain
current-process parse/serialize/reference/checksum intervals including allocation
and GC, with input construction and warm validation outside the counters.

The [authority receipt](performance/chatgpt-url-authority-20261104.json) retains
raw observations, source and generated-helper proofs, pinned V encoder inputs,
guards and test logs. The latest completed production executable
`f7a36b29f87e6b334ac7aa14e177598eeb5e6ec18648f4af26e8c973090ea18c`
still contains the scalar helper. The already-running shared build also sealed
inputs without this change. No separate production build was queued. Production
path verification, exact browser rendering and matched page measurements remain
pending a completed bundle containing the bulk helper. Page credit and the
broad cadence remain zero; the 5% Brave target remains unmet.

### Authority production follow-up

Subsequent production diagnostics verify the bulk helper in completed builds
`fb66bde798d3ee02b96daca3c25cd11d97e33ca270e086a21a9ce6b02f07c2f2`
and `c71667cf92e9fb20f67cf74e5f172c00fc80f41251f786cdb3a2a104ee8f6c37`.
All eight diagnostic captures pass exact pixels, content and JavaScriptCore
bootstrap checks, with the execution marker present only for the candidate.

The first unprofiled attempt stops after Brave's ownership audit cannot verify
an exiting renderer from another session's headless WIRED replay, rooted at PID
86450. Its successful Vox control and failed Brave attempt remain retained;
neither supplies a complete pair or performance credit. No ownership gate was
relaxed. After that foreign root exits, a separately identified four-pair cohort
requires no other Brave root at preflight and uses the same strict counters.

On executable `c71667cf…`, all eight subsequent captures pass exact pixels,
content, bootstrap and browser/kernel exits. Both authority variants also enable
the later direct USV encoder. Vox's control median is **32,977,936,176.5** and
the candidate median **32,960,169,798.5**, a **0.054%** observed reduction.
The ranges overlap: the conservative reduction is **−85,584,681**. Frame
checkpoints are 376, 408, 388 and 384; every capture has eleven box-building
passes. Starting load averages range from 17.1 to 19.4 on 18 CPUs.

The [authority production receipt](performance/chatgpt-url-authority-production-20261104.json)
links both execution diagnostics, the rejected attempt, the later cohort,
source proofs, raw counts, PNGs and actual guards. It earns zero conservative
page credit and leaves the broad cadence at zero. Four pairs do not establish
seven-pair acceptance, and the 5% Brave target remains unmet.

## Direct USV string encoding

Commit `afeca8bd5` makes URL and URLSearchParams bindings encode UTF-16 directly
with replacement of unpaired surrogates. This replaces their
`to_well_formed().str()` composition, avoiding a separate validation pass and,
for malformed input, an intermediate repaired UTF-16 allocation. It preserves
the unchecked ASCII byte-view contract and leaves JavaScript coercion, exception
ordering and the other string callers unchanged.

The retained separate V profile recorded 96,381 `is_well_formed` calls. That
instrumented row supplies the lead; the browser still executes page scripts
through JavaScriptCore. The optimization does not substitute the translated
LibJS VM.

All **116 focused test-function executions** pass: 56 pure UTF-16 executions
across GC modes and control/candidate paths, poisoned preallocation arenas and
AddressSanitizer/UndefinedBehaviorSanitizer; plus 60 actual JavaScriptCore
binding executions. Cases include every UTF-16 unit and valid surrogate pair,
589,824 two-unit adjacency combinations, prefix boundaries, nulls, unchecked
bytes, stale metadata, independent output ownership, URL components,
URLSearchParams conversion, object coercion and original exceptions.

Complete LibJS selections finish at **236/238 files passing in each GC mode**.
The same `regex_matching_corpus_test.v` and `string_case_test.v` Greek casing
mismatches remain. Their independent system-ICU reproduction is retained in the
earlier encoder evidence. Actual nonzero module/guard exits are preserved; no
fixture changes, skipped cases or full-suite pass is claimed. All one hundred
upstream AST fixtures match exactly in each GC mode.

Tooling commit `cf766a1dd` compares complete output against the existing
repair-then-encode path, after constructing and warming the input. Both variants
keep the prior ASCII-prefix encoder enabled. Two unprofiled observations per
variant run in control/candidate/candidate/control order, with separate positive
and negative execution diagnostics.

| Component scene | Repair control median | Direct median | Median reduction |
| --- | ---: | ---: | ---: |
| 39,808 archived URL encodes | 101,748,826.5 | 72,700,084.5 | 28.549% |
| Long ASCII | 112,575,130.5 | 66,110,142.5 | 41.275% |
| Unicode first | 123,850,749.5 | 113,492,062.5 | 8.364% |
| ASCII with surrogate tail | 78,896,209.5 | 21,204,546 | 73.123% |
| Empty | 16,395,408.5 | 10,103,990 | 38.373% |
| Unchecked byte storage | 23,882,526 | 20,873,575.5 | 12.599% |

All serialized references, encode counts and checksums match. These are
current-process conversion/reference/checksum intervals, including allocation
and GC, rather than whole-page costs.

Sealed executable
`c71667cf92e9fb20f67cf74e5f172c00fc80f41251f786cdb3a2a104ee8f6c37`
contains this helper and both binding callers before the source commit. Its
function excerpts identify the implementation independently of the dirty build
head. Four separate production diagnostic captures pass exact pixels, content
and bootstrap checks; the execution marker occurs only with direct encoding.

An unprofiled four-pair comparison on that same executable passes all eight
captures with unchanged inputs, successful PID adoption and zero browser/kernel
exits. The repair-control median is **32,927,840,011** instructions; direct
encoding measures **32,759,483,554.5**, a **0.511%** observed reduction. Ranges
overlap, with a conservative reduction of **−63,243,445**. Frame checkpoints are
386, 385, 380 and 380, with eleven box-building passes each. Starting load ranges
from 17.1 to 21.0 on 18 CPUs. No conservative page saving is credited; the broad
cadence remains zero.

The [USV encoding receipt](performance/chatgpt-usv-encoding-20261104.json)
links all focused/full selections, actual failures, AST logs, component controls,
sealed source proofs, raw page counters, PNGs, host conditions and guards.
Original author scripts and the single SOCKS fixture remain unchanged, with no
new live download. This frozen replay does not establish live sign-in or chat
submission support. Four pairs do not establish acceptance; the requested 5%
advantage over Brave remains unmet.

## Shared layout reuse eligibility

The separate [layout eligibility diagnostic](performance/chatgpt-layout-eligibility-verified-20261104.json)
uses completed executable
`f029d0f4ec0b2648879303914eff0cc151932e08a50bf2903258a52aded645e3`.
It confirms actual flex-measurement replay, including unshifted relative boxes;
the grid replay marker remains absent. Disabling both flex/grid replay produces
none of those markers. All four captures pass unchanged pixels, content,
JavaScriptCore bootstrap and browser/kernel exits, with stable identities and
successful guard PID adoption.

Instrumented launch counts are 32,947,401,474 for the candidate and
32,673,424,561 for its control. They provide no unprofiled optimization credit
or broad-cadence advance. This audit establishes execution of the shared path,
not that layout reuse closes the ChatGPT/Brave gap. The initial preflight used
an incorrect generated C symbol spelling and stopped before any browser launch;
its failed script, log and actual guard exit remain in the diagnostic archive.

## Per-binding parsed-base cache

Commit `cb055fe71` retains one parsed base URL per URL binding, keyed by the
converted raw base string. Inputs above 4096 bytes and calls without a base keep
the original parser path. Invalid bases retain their negative result, including
when the requested URL is absolute. JavaScript coercion and exceptions still
occur before lookup. Each binding owns a separate arena, recycled on replacement
and released on close; returned URL records survive producer retirement,
eviction and cache release.

All **106 focused test-function executions** pass: 40 parser executions across
both GC modes and paths, poisoned preallocation arenas and sanitizers; plus 66
actual JavaScriptCore executions, including poisoned-arena binding close checks.
All six DOMURL files pass in each GC mode. Tests cover raw-key changes, invalid
bases, oversized bypass, independent paths, warm arena usage, coercion reentry,
fresh wrappers, live Blob ownership and native URLs surviving runtime close.
All 36 selected compile/runtime guards exit zero with stable source identities.

Tooling commit `dd030a748` validates complete canonical output, parse counts and
checksums. Inputs and warm validation precede the measured current-process
parse/serialize/reference/checksum interval; allocation and GC are included.
Each variant has two observations in control/candidate/candidate/control order,
followed by separate positive and negative cache diagnostics.

| Component scene | Original median | Cache median | Median reduction |
| --- | ---: | ---: | ---: |
| 9,952 archived absolute URLs, common base | 627,354,534.5 | 528,907,566 | 15.692% |
| 16,384 relative inputs, common base | 613,651,489 | 176,570,765.5 | 71.226% |
| 9,952 rotating bases | 591,032,310 | 606,229,390.5 | −2.571% |
| 128 oversized-base parses | 2,378,420,000.5 | 2,396,245,505.5 | −0.749% |

The rotating-base regression is retained; oversized observations overlap.
These component results supply no whole-page credit. The browser hit pattern
and a complete matched comparison are required before attributing page savings.

A production diagnostic on executable
`efbd9bb05ad26dc97a1954934d4be54f0b7f2ffd9ef7eae1c273fa47fd396a2f`
confirms an actual candidate cache hit. Its Vox and Brave captures both pass
exact pixels, content, bootstrap and browser/kernel exits. The canonical app is
then replaced before the control trial, so the identity guard rejects the
partial cohort. Its actual nonzero guard exit and both observations remain
retained, with zero performance credit.

A subsequent nonblocking publication-lease attempt finds the shared build lock
busy and exits 75 before launching a browser. It neither waits for that build,
copies an app nor enqueues a separate production request. The prepared lease
would protect one complete diagnostic and matched cohort while preserving
wake-ups for any existing queued requests. Complete control-path rendering and
matched page validation remain pending an available stable publication interval.

The [base-cache receipt](performance/chatgpt-url-base-cache-20261104.json)
links all checks, regressions, raw component observations, source proofs,
partial browser evidence and the busy-lock report. Original author scripts,
fixture bytes and references remain unchanged, with no new live download.
Page credit and the broad cadence remain zero. The requested 5% Brave advantage
remains unmet.

### Completed base-cache production comparison

A second nonblocking lease attempt also exits 75 without launching a browser.
The next attempt acquires the publication lock and holds it across a separate
diagnostic and unprofiled four-pair comparison, then releases it. No app is
copied and no new build request is enqueued. Completed executable
`6c57297b8944be97201dec4dc929ac71a75f5be8272f8419830a81070942621b`
remains unchanged throughout both phases.

All four diagnostic and eight unprofiled captures pass exact pixels, content,
JavaScriptCore bootstrap and browser/kernel exits. The cache-hit marker occurs
only with caching enabled. The enclosing guard exits zero, successfully adopts
43 process identities and observes a peak aggregate RSS of 1,977,843,712 bytes.

The original-parser Vox median is **33,613,803,772.5** instructions, versus
**33,591,232,705** with the cache, a **0.067%** observed reduction. Ranges overlap;
the conservative reduction is **−302,609,715**. Frame-completion checkpoints are
472, 477, 465 and 474; all four Vox captures have eleven box-building passes.
Starting load averages range from 4.45 to 5.39 on 18 CPUs. No conservative page
saving is credited, and the broad cadence remains zero.

Disk exhaustion initially prevented a shell here-document. Cleanup removed
only this work's completed generated test outputs, retaining durable source
proofs, commands, logs, raw counters and PNGs. Two handwritten ICU source probes
are restored byte-exact from their verified archives. The production bundle,
frozen receipts, repository source and single SOCKS fixture remain intact.

The [completed production receipt](performance/chatgpt-base-cache-production-20261104.json)
links the successful phases, lease and guard records, second busy-lock attempt
and exact cleanup receipt. Earlier partial and busy attempts remain unpooled in
their prior receipts. This four-pair diagnostic does not establish seven-pair
acceptance or the requested 5% Brave advantage.

### Production-condition V profile

A fresh `v -profile` executable uses `-prod`, `vox_production` and the current
prealloc compiler. C compilation remains `-O1` for this instrumented diagnostic.
The generated profiler gate is thread-local, enabled at main entry and disabled
on worker threads. `-profile-no-inline` skips instrumentation of V-inline
functions; it does not disable inlining. The frozen compile and build guard
complete successfully with unchanged source-input identity. Executable SHA-256:
`0cef98e602e068bdc9b041a5368f660ee59b5e820c1ff9b847b9eaff60bc4e83`.

The five-second run exits normally but fails full content identity: deferred
cookie-consent buttons have not appeared. Its controller and guard exit 1;
its raw profile, audit and PNG remain retained as an incomplete-page diagnostic.
A separately identified thirty-second diagnostic passes bootstrap, full content
identity and all 3,145,728 reference pixels. Its browser and guard exit zero,
with 11,309 unique profile rows and no negative self times. The guard adopts
the browser and observes peak aggregate RSS of 1,905,246,208 bytes.

The valid profile records 518 calls to the preload/display-eligibility helper,
16,419 animation-retirement element scans and 63,853,284 arena-membership checks.
These are investigation leads. Instrumented elapsed times include native calls
and waits; recursive inclusive rows overlap, and profiling can retain otherwise
empty production guard helpers. They establish neither instruction savings nor
unprofiled performance. Both runs use the existing disk-only SOCKS replay and
original author scripts; no new downloads occur. The thirty-second diagnostic
does not change the five-second acceptance protocol.

The [production-condition profile receipt](performance/chatgpt-v-profile-production-20261104.json)
links both attempts, raw profiles, audits, PNGs, commands, frozen compile proof,
memory guards and the receipt for removing completed private benchmark caches
during disk-pressure cleanup. Profile credit and the broad cadence remain zero;
the requested 5% Brave advantage remains unmet.

Later disk exhaustion also blocks shared publication and a shell log
redirection before a benchmark can start. The first attempt to archive all
generated profile sources at once runs out of space without removing a source.
A separate recovery archives and verifies each file before removing its
redundant `Build/` copy. All 763,874,213 raw bytes of generated and preprocessed
C remain recoverable from four lossless archives totaling 77,925,886 bytes.
Both instrumented executables, native inputs, receipts, raw profiles, audits,
PNGs and the captured fixture remain intact. The
[source-storage receipt](performance/chatgpt-profile-generated-sources-20261105.json)
links the four archives, successful memory guard, initial failure and separate
cleanup of this work's completed generated test outputs.

### Shared property pages during animation retirement

Commit `f1f9a4867` avoids rechecking a fully inspected clean property page during
one synchronous inspection of one retiring animation arena. A bounded table
compares exact page identities; collisions cause rescans and partial pages do
not establish full-page cleanliness. No memo survives the call. Typed payloads,
page ownership, animated/custom properties, layout snapshots and retained
density projections keep their existing checks. V heap-promotes the memo, so
the caller supplies a temporary scope and releases it before returning.

All **44 final check jobs, with 110 test-function executions**, pass. These
cover poisoned preallocation, every longhand slot, shared pages, collisions,
partial pages, mutations between inspections, retained projections, typed
payloads and unchanged caller-arena usage. Ordinary-GC/no-GC property-store and
alignment checks pass, as do both page-scan variants under address and
undefined-behavior sanitizers.

The initial sanitizer run in both variants exposed a separate tokenizer
alignment bug before the test bodies: an odd number of 32-bit code-point slots
misaligned the following 64-bit offset table. Commit `fb0373636` adds alignment
padding and a focused ASCII/Unicode regression test. Commit `64ccbb9bf` corrects
the existing property-page footprint assertion from 144 to 152 bytes to account
for its previously added semantic hash. Initial failed exits and source proofs
remain retained; the full final selection is rerun after these fixes.

A synthetic C-`-O2` preallocation component measures complete ownership
inspections, including the temporary scope, with identical checked results.
Control/candidate/candidate/control medians are:

| Scene | Scalar instructions | Candidate instructions | Observed reduction |
| --- | ---: | ---: | ---: |
| Shared clean pages | 1,075,378,490 | 67,428,587 | 93.730% |
| Distinct pages | 109,458,103.5 | 106,865,990.5 | 2.368% |
| Sample held in first target | 452,166.5 | 463,802 | −2.573% |
| Sample held in last target | 1,074,191,753 | 67,339,677 | 93.731% |

These are component results, including the early-return regression; they do not
establish browser savings or advance the whole-page broad-check cadence. The
[page-scan receipt](performance/chatgpt-animation-page-scan-20261105.json)
links raw observations, all final checks and retained initial failures. A final
production-path diagnostic and matched browser comparison require a completed
shared bundle containing the temporary-scope fix. The previous completed
bundle contains the unscoped prototype, so it supplies no final validation.
The frozen fixture, original author scripts and references remain unchanged,
with no new downloads. The requested 5% Brave advantage remains unmet.

#### Completed production comparison

Completed executable
`809de706df254e9eae5e050935001349e3f398daf97ab433a7225f55ffffe30d`
contains the final temporary-scope fix. A nonblocking publication lease pins
that bundle across a separate execution diagnostic, unprofiled comparison and
broad verification, then releases it without enqueuing a build. Sealed source
excerpts identify the final scanner. All four diagnostic and eight unprofiled
captures pass full content, JavaScriptCore bootstrap, exact reference pixels
and browser/kernel exits. A shared-page hit is reported only with the memo
enabled.

In control/candidate/candidate/control order, scalar Vox counts are
**33,788,710,254** and **33,514,183,574**, versus candidate counts
**32,984,374,144** and **32,763,543,127**. Medians fall from
**33,651,446,914** to **32,873,958,635.5**: **2.310%** fewer observed instructions.
The conservative separation is **529,809,430** instructions. The scalar control
shares the new temporary scope and memo allocation while retaining the original
per-property loop; it isolates scan reuse rather than reproducing every
instruction of an older release.

Frame checkpoints are 457, 477, 475 and 474, with eleven box-building passes
in every capture. Starting load averages range from 5.13 to 5.43 on 18 CPUs;
shared source/build activity and source-archive/Git work also occur on the host.
Candidate captures complete slightly more frame checkpoints while using fewer
instructions, but this remains a small frozen-page cohort. It does not establish
isolated rendering time, a fixed-frame CPU cost or scrolling FPS.

The observed separation crosses the 5,000,000-instruction verification
threshold. **All 47 broad checks pass**, including twenty screenshot/reftest
cases, live image and SVG paint-server mutations, eleven compiled/executed
native Skia checks, diff controls and exact 100-case AST comparisons with both
GC modes. The broad cadence resets to zero. The enclosing memory guard exits
zero, adopts 42 process identities and observes peak aggregate RSS of
1,928,331,264 bytes.

Both canonical comparison drivers retain exit 1 because the Brave target and
seven-pair minimum are unmet; their validation controllers exit zero. The worst
candidate count divided by the lowest Brave lower bound is **1.822**, well above
0.95. These four pairs provide no seven-pair acceptance or live ChatGPT
interaction claim. The
[completed production receipt](performance/chatgpt-animation-pages-production-20261105.json)
links every raw count, PNG, audit, source proof, guard, lease and broad result.
The original author scripts, five-second settle, fixture and references remain
unchanged, with no new download. The requested 5% Brave advantage remains unmet.

### Reuse of ancestor class hashes

Commits `bad13c8f1` and `e768f1d1f` add bounded reuse for substantial ancestor
class attributes. The final path memoizes only 64–8192-byte class strings with
at most 128 token hashes. Tag, ID and attribute-name hashing stays live. Each
style computer owns 128 slots containing scalar hashes, keyed by full live
node/document identities, attribute epoch, class-source address/length and
quirks mode. Foreign documents bypass the cache. Slot buffers use the caller's
retained document storage and keep their reservation across replacement;
the scalar payload is capped at 65,536 bytes, plus descriptors and allocator
storage.

The first whole-sequence prototype regresses the captured ancestor chain by
5.0% and full traversal by 10.3%. Restricting it to long classes initially
still regresses traversal by 5.2%. A separate diagnostic explains the misses:
Vox node IDs are aligned addresses, and selecting their low bits collapses
the table. It records 256 hits versus 2,304 misses for the chain, and zero hits
versus 30,464 misses for traversal. The final table mixes address bits above
alignment and keeps the first admitted node within an epoch, avoiding repeated
copies for colliding cold nodes. Earlier results remain retained and unpooled.

**All 36 final focused jobs, with 118 test-function executions, pass.** These
cover epoch changes, named-map/token-list edits, adoption, quirks changes,
collisions, empty vectors, byte/token limits, reentrant attribute callbacks,
foreign-document bypass, scratch retirement and stable warm storage. Existing
ancestor and computed-query tests pass with both variants, ordinary GC and no
GC. Poisoned preallocation and address/undefined-behavior sanitizers also pass.
The initial zeroed fixed-array vector descriptors produced wrong buckets and
hit the 3 GiB runtime guard; explicit typed vector initialization fixes that
attempt. Its actual failure and source remain in evidence.

The final C-`-O2` preallocation component uses V's default source conditions,
the staged production allocator and the captured HTML's 36-element
deepest chain and all 833 elements. Each measured pass resets buckets, balances
push/pop and checks every scalar hash against an independent reference. Input
construction, launch and teardown are excluded. Control/candidate/candidate/
control medians are:

| Scene | Scalar instructions | Candidate instructions | Observed reduction |
| --- | ---: | ---: | ---: |
| Captured ancestor chain | 59,268,600 | 49,121,546.5 | 17.120% |
| Captured full traversal | 450,852,929.5 | 401,665,134.5 | 10.910% |
| Attribute epoch changes every pass | 31,936,001 | 32,212,901.5 | −0.867% |
| Oversized class input | 36,955,532 | 36,980,035.5 | −0.066% |

The [ancestor class-cache receipt](performance/chatgpt-ancestor-class-cache-20261105.json)
links complete final and prototype observations, original failures, source
proofs, diagnostics and guards. These component counts provide no browser
instruction credit. A separate final production diagnostic and matched page
comparison are required; the requested 5% Brave advantage remains unmet.

#### Completed ancestor-cache production comparison

The first production preflight rejects parenthesized shift operands in the
generated C, before any browser launches. A corrected nonblocking lease attempt
finds the build lock busy and exits 75 without collecting observations. The
next attempt uses the available completed bundle immediately: all four
diagnostic captures pass and verify a class-cache hit, but publication changes
the bundle during the matched phase. Its partial cohort is rejected, retained
and given no instruction credit.

After publication, a nonblocking lease pins completed executable
`1bf1abc80e1129b5ed9a2a731288de2a109921c9341f160a43145d960a04856f`
across the final diagnostic and unprofiled comparison, then releases it. No
bundle is copied and no separate build request is enqueued. All four diagnostic
and eight unprofiled captures pass full content, JavaScriptCore bootstrap,
exact reference pixels and browser/kernel exits. The marker occurs only with
class reuse enabled.

Scalar Vox counts are **33,092,910,315** and **32,395,850,447**, versus candidate
counts **32,154,424,930** and **32,969,935,129**. Medians are
**32,744,380,381** and **32,562,180,029.5**, an observed **0.556%** reduction.
Ranges overlap substantially: the conservative separation is **−574,084,682**.
No whole-page saving is credited. Frame checkpoints are 476, 489, 472 and 487;
box-building checkpoints are 11, 10, 11 and 11. Starting loads range from 3.22
to 4.61 on 18 CPUs. The work and host variation prevent a page-level attribution
from this small cohort.

The guard exits zero, adopts 42 process identities and observes peak aggregate
RSS of 1,925,365,760 bytes. Both canonical drivers retain exit 1 because the
Brave target and seven-pair minimum are unmet; validation controllers exit zero.
The highest candidate count divided by the lowest Brave lower bound is 1.744,
above the requested 0.95. No new broad checkpoint is due, and the broad cadence
remains zero.

The [completed ancestor-cache production receipt](performance/chatgpt-ancestor-production-20261105.json)
links every attempt, raw counter, PNG, audit, source proof, guard and identity
change. The original author scripts, fixture, five-second settle and references
remain unchanged, with no new live download. This frozen-page diagnostic
establishes neither the requested 5% Brave advantage nor live interaction parity.

## November 5: direct numeric unit checks

`225685a15` replaces NumericType's seven-dimension dispatch loop with direct
optional-exponent reads and a scalar unit sentinel. Invalid powers and duplicate
units still reject immediately; missing entries, explicit zeros and percent hints
retain their behavior. The original loop remains available through
`VOX_RETAIN_NUMERIC_DIMENSION_ITERATION` for matched controls. A separate
`VOX_NUMERIC_DIMENSION_DIAGNOSTICS` marker verifies execution during the complete
startup-through-capture workload, without claiming document-local call counts.

The retained production-condition V profile reported 1,367,119 calls to this
method, with 249.414 ms self and 337.277 ms inclusive instrumented time. Those
timings selected the work and receive no performance credit. All 33 focused jobs
pass: 124 test-function executions across both branches, including poisoned
preallocation, ordinary GC, no GC, AddressSanitizer and UndefinedBehaviorSanitizer.
The new cases cover all 78,125 optional/negative/zero/one/two combinations, wide
signed exponents, percent hints, immutability and allocation-free arena use.

The final component uses V `-prod`, C `-O2`, the production preallocation runtime
and current-process hardware counters. Every result is checked against an
independent oracle. Construction, the oracle, startup and teardown lie outside
the measured interval. Two control and two candidate observations run in
control/candidate/candidate/control order, followed by separate diagnostics.

| Component | Median instruction reduction |
| --- | ---: |
| Single unit, all seven dimensions and optional-zero masks | 19.904% |
| Dimensionless | 25.948% |
| Invalid first exponent | **−1.580%** |
| Invalid final exponent | 25.298% |
| Two nonzero unit entries | 10.488% |
| Exhaustive mixed entries | 4.213% |

The initial whole-vector OR/sum prototype improved some cases but regressed
immediate rejection by 44.44% and mixed entries by 20.18%. Its raw results remain
unpooled. Initial option-unwrapping compile errors, the consequent missing-binary
run and a source-proof regex rejection also remain retained with no pass credit.
The revised code avoids exponent arithmetic and preserves early rejection.

The [numeric-dimension receipt](performance/chatgpt-numeric-dimension-20261105.json)
links both prototypes, commands, counters, source/executable identities and every
focused-check guard. These component results grant no whole-page instruction
credit and do not advance the broad-check cadence. The original single SOCKS
capture, author scripts and pixel references remain unchanged. The requested
5% advantage over Brave remains open pending production browser measurements.

## November 5: numeric predicate production comparison

The latest completed canonical production executable
`0265539a5c31ef86517916e4870b19e0161a3562345694249a07da6a2f632d2b`
contains the final direct predicate, scalar sentinel and original-loop control,
verified from its sealed compiler input. No separate build was requested for
this comparison. Its identity stayed unchanged throughout all captures while
another shared build was running.

Two preflights remain retained: the first rejected a source-proof assumption
that V stored the diagnostic message inline, before any browser launch; the
second could not acquire the nonblocking publication lease and launched nothing.
The completed run uses the available bundle with full input fingerprints. Its
four diagnostic and eight unprofiled captures all pass the unchanged content
and pixel audits, JSC bootstrap and browser/kernel exits. The direct-path marker
appears only in the candidate diagnostic.

Original-loop control counts are **33,051,566,692** and **32,839,599,342**;
direct-predicate counts are **32,973,831,878** and **33,819,350,563**. Medians
are **32,945,583,017** and **33,396,591,220.5**: the observed candidate is
**1.369% more expensive**. The conservative separation is **−979,751,221**,
so no whole-page saving is credited. Frame checkpoints vary 426–467 and one
candidate has twelve box-building checkpoints rather than eleven. Starting
loads range 6.07–6.94 on 18 CPUs; the ranges and differing frame/layout work
prevent attributing this page difference to the predicate.

The enclosing guard exits zero, adopts 42 process identities and observes peak
aggregate RSS of 1,931,575,296 bytes. Both canonical drivers retain exit 1 for
the Brave target and seven-pair minimum; validation controllers exit zero. The
highest candidate divided by the lowest Brave lower bound is **1.640**, above
the requested 0.95. Broad verification is not due and its cadence remains zero.

The [production receipt](performance/chatgpt-numeric-production-20261105.json)
retains both rejected preflights, all counters, PNGs, audits, source proofs,
identities and guard exits. These four alternating Vox/Brave pairs are a
diagnostic cohort, below seven-pair acceptance. The original single SOCKS
capture and author scripts, empty private profiles/caches, five-second settle,
viewport/scale and references remain unchanged. This result establishes neither
the requested 5% Brave advantage nor live interaction parity.

## November 5: bounded animation sample batching

Commit `d0b4a8c58` extends the animation sample arena's rotation threshold to
64 updates' estimated demand, while retaining the original 256 KiB floor and
16-update lower bound. Expansion stops at a 16 MiB threshold; larger original
thresholds stay unchanged. This bounds the expansion, not total live memory:
an update can overshoot, and retiring/spare arenas have separate lifetimes.
`VOX_RETAIN_SHORT_ANIMATION_SAMPLE_BATCH` selects the original policy.
The diagnostic marker confirms a deferred rotation on the ChatGPT document.

**All 48 final focused jobs pass**: sixteen compilations and thirty-two test
executions, covering both policies, poisoned preallocation, ordinary GC, no GC,
AddressSanitizer and UndefinedBehaviorSanitizer. Cases cover threshold floors,
signed extremes, bounded repeated rotation/reuse, inherited selector context,
property pages, typed payloads, retained projections, timelines and compositor
sampling. The initial stress test accidentally used V's array-initializer
`index` instead of its outer loop counter; both failed runs and the corrected
source remain retained. A component compile interrupted by session migration
also remains recorded without a completed-guard claim.

The component compares 512 fixed 16 ms animation updates across 49 elements
per scene. Every color, opacity, transform and width value matches independently
precomputed ordinary-storage frames. It uses V `-prod`, C `-O2`, production
preallocation and current-process hardware counters, excluding construction,
reference generation, startup and teardown. Control/candidate/candidate/control
observations retain this tradeoff:

| Scene | Median instruction reduction | Rotations, control → candidate | Peak sample bytes used, control → candidate |
| --- | ---: | ---: | ---: |
| Inherited color | **−1.714%** | 22 → 9 | 276,271 → 651,247 |
| Opacity and transform | 4.392% | 25 → 10 | 282,656 → 732,336 |
| Registered custom-property width | 1.608% | 35 → 9 | 1,030,911 → 3,737,053 |

These byte peaks include current and retiring arenas, excluding spares and
allocator overhead. They are not RSS limits. Component runtime guards stay
below 3 GiB, with a highest observed peak of 2,272,673,792 bytes across the six
measured/diagnostic executions. The page receives no credit from these results.

The first production diagnostic passes all four captures, but its controller
searches for an incorrectly copied numeric-predicate marker. An independent
audit of the archived logs verifies the actual marker, document URL and
`original <= used < expanded <= 16 MiB`, preserving the initial parser failure.
Publication then changes the bundle during the first unprofiled cohort; all its
partial observations remain invalid for performance credit. A second attempt
finds the nonblocking publication lease busy and launches no browsers.

The final attempt uses completed canonical executable
`e4705bb167d9077304bc62a8d547a392c2a9dbd98b6be5a61015fe43ce6c70fe`
with unchanged identities throughout both phases. All four diagnostic and eight
unprofiled captures pass full content, JavaScriptCore bootstrap, exact reference
pixels and browser/kernel exits. The deferred-rotation marker appears only with
the extended policy. No bundle was copied or production build requested.

Control counts are **32,424,475,410** and **31,762,255,706**; candidate counts
are **30,465,291,451** and **30,933,120,910**. Medians are
**32,093,365,558** and **30,699,206,180.5**, an observed **4.344%** reduction,
with **829,134,796** instructions separating the observed ranges.

This difference has a material qualification: control captures complete
416/350 frame checkpoints, versus 297/352 for candidates, with eleven
box-building checkpoints in each. Starting load averages range 14.99–16.41 on
18 CPUs. The candidate's lower frame volume and host contention prevent
attributing the whole difference to batching. **Causal page savings credit is
zero.** This is a capture-workflow observation, not an isolated render cost,
fixed-frame efficiency result or scrolling FPS claim.

The observed-count separation triggers the verification checkpoint. **All 47
broad jobs pass**, including twenty screenshot/reftest cases with unchanged
references and tolerances, live image and SVG paint-server mutations, eleven
compiled/executed native graphics checks, diff controls and all 100 exact AST
fixtures in each GC mode. The cadence resets to zero. The enclosing guard exits
zero, adopts 49 process identities and observes peak aggregate RSS of
1,937,096,704 bytes. Canonical comparison driver exits remain one because the
Brave threshold and seven-pair minimum are unmet; final validation controllers
exit zero.

The worst candidate divided by the lowest Brave lower bound is **1.891**,
above 0.95. These four alternating pairs do not establish seven-pair acceptance
or live ChatGPT behavior. The original single SOCKS capture, author scripts,
private profiles/caches, five-second settle, viewport/scale and references stay
unchanged. The [batching receipt](performance/chatgpt-animation-batch-20261105.json)
links every attempt, source proof, component result, raw counter, PNG, ownership
audit, memory guard and broad check in verified durable archives. The requested
5% advantage over Brave remains unmet.

The following fresh-profile attempts both finish V code generation but fail
source sealing because canonical build inputs change before C preprocessing.
Neither produces a profiled executable or launches a browser. The
[profile-refresh receipt](performance/chatgpt-profile-refresh-blocked-20261105.json)
retains both generated C inputs, commands, source identities, failures and memory
guards. New profiling remains pending a stable canonical input window; neither
failed build changes the measured workload or supplies optimization credit.

## November 5: profiling the completed sealed build

Tooling commits `5274bb629` and `af68bcf86` add
`tools/sealed_browser_profile.py` and its separate native callback helper.
The builder consumes the completed production receipt's immutable preprocessed
C and sealed link objects. It injects the profiling gate after module
initialization, compiles with Clang's after-inlining instrumentation and C
`-O1`, and pins every consumed input before and after compilation. No V source
regeneration, source-tree copy or production build request is involved.
The callback helper is compiled separately without instrumentation.

The first preflight rejects the signed bundle's changed dylib bytes. The final
resolver finds the byte-identical unsigned linker input in the canonical build
cache, preserving strict digest checks. It does not accept a newer or merely
similarly named library. Seven focused tooling tests pass, including real
compiler callbacks, recursion, background-thread exclusion, partial exits,
entry-point formats, changed-input rejection and library identity. The initial
callback test's symlink-spelling assertion failure remains retained; its final
assertion compares resolved executable paths.

The instrumented executable compiles successfully in 696.85 seconds within the
default guard, peaking at 9,662,185,472 bytes. A planned stop finds compilation
already finished; no process is cancelled. The fresh thirty-second diagnostic
capture exits zero with complete bootstrap/content and **zero differing
pixels**, using the same original author scripts and fixture. Its 3 GiB guard
exits zero and peaks at 1,772,044,288 bytes. Input identities remain unchanged.

The profile contains **4,270 uniquely addressed functions**, no unresolved
symbols and zero callback faults. Three still-active frames are closed at
shutdown and explicitly marked partial. Selected observations are:

| Function | Calls | Instrumented self ms |
| --- | ---: | ---: |
| `native_end_css_effect_layer` | 186 | 3,723.595 |
| `native_draw_contoured_box_srgb` | 33 | 1,742.533 |
| `native_draw_rounded_rect_srgb` | 86 | 1,720.982 |
| `string__eq` | 46,036,873 | 899.556 |
| `css__string_to_length_unit` | 1,170,716 | 858.522 |

These are elapsed diagnostic timings, including instrumentation and native
waits. Inlined work belongs to its caller, recursive inclusive totals overlap,
and main-thread timing excludes background work. Module initialization is
outside the gate. The standalone adblock self-worker fallback also differs from
the production minimal helper. The thirty-second settle differs from the
five-second acceptance protocol. None of these timings or call counts supplies
instruction, frame-rate or optimization credit.

The [combined receipt](performance/chatgpt-sealed-profile-20261105.json)
preserves the profiler inputs, source transformation, guards, initial failures,
full raw profile, exact capture and the separate seven-pair production cohort.
This resolves the earlier V-source regeneration blocker without relaxing the
measurement or memory guards. The requested 5% Brave advantage remains unmet.

## November 5: packed CSS length-unit lookup

Commit `ef58a6de6` replaces the length-unit parser's lowercase/string comparison
chain with a bounded scalar key. All 49 supported spellings contain ASCII
letters and at most five bytes. Folding bit 5 and shifting each byte into an
explicit position preserves ASCII case matching independently of native byte
order. No other byte can become a supported lowercase letter. Empty and longer
inputs reject before packing, and no normalized string or borrowed input is
retained. The original implementation remains selectable with
`VOX_RETAIN_LENGTH_UNIT_ITERATION`; diagnostics have a separate opt-in marker.

**All 27 focused jobs pass**, including both implementations, poisoned
preallocation, ordinary GC, no GC and AddressSanitizer/UndefinedBehaviorSanitizer.
The tests cover all 49 spellings and ASCII case permutations, every possible
byte substitution at every position, Unicode, NUL, whitespace and length
boundaries, and allocation-free mixed-case lookup in a caller arena. Existing
length resolution, arithmetic, Typed OM and calculation-context checks also
pass. The current staged compiler matches the canonical compiler byte for byte,
with fallback disabled and the required compiler/runtime memory guards.

The unprofiled component uses V `-prod`, C `-O2`, production preallocation and
current-process hardware counters. Every public lookup is checked against the
original iteration. Construction, tokenization, oracle preparation, startup,
scratch retirement and teardown are outside the measured interval. Two control
and two candidate observations run in control/candidate/candidate/control order,
with separate branch diagnostics.

| Component | Lookups per observation | Control median instructions | Candidate median instructions | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Original archived CSS dimension tokens | 656,600 | 455,410,008.5 | 62,751,473 | 86.221% |
| All 49 lowercase units | 490,000 | 246,543,257.5 | 50,818,181.5 | 79.388% |
| All 49 uppercase units | 490,000 | 373,591,171 | 50,930,532 | 86.367% |
| Original first-match `cap` | 500,000 | 72,586,795.5 | 57,618,843.5 | 20.621% |
| Invalid and out-of-range spellings | 600,000 | 453,446,147 | 44,023,694.5 | 90.291% |

The captured-token scene repeats the 6,566 dimension-unit spellings from the
two original archived CSS responses one hundred times. It represents authored
token frequency, **not runtime lookup frequency**. The initial component file
list included its test source twice and failed compilation before collecting
observations. Its original list, command, hashes and errors remain retained;
the corrected component and all subsequent result checks pass.

These are component results. No browser instruction saving, Brave acceptance
or broad-cadence advance is credited. The latest completed bundle inspected
after the feature commit lacks the packed lookup, while the shared production
lock is busy with a pending request. No separate production build is queued.
The production diagnostic and matched cohort are prepared for an eligible
completed bundle; an older binary cannot validate this feature.

The [length-unit receipt](performance/chatgpt-length-unit-20261105.json)
links source proofs, complete component counts, the initial failure, all focused
checks, compiler/fixture identities, memory guards and verified durable archives.
The original single SOCKS capture, scripts, pixel references and five-second
acceptance workload remain unchanged. The requested 5% Brave advantage remains
unmet. The subsequent whole-page validation is recorded below.

## November 5: packed lookup production validation and selected instruction scopes

The latest completed single-C-unit bundle, executable
`557eb0c8a7012096e4002361f9b66f873bd6ac15c97d5e151f127f4e876f4dcf`,
contains the packed lookup. Sealed source proofs and separate execution markers
confirm both the candidate and original iteration control. All 12 production
captures pass bootstrap, complete content identity and the unchanged pixel
reference. Per-capture executable, dependency, tool and fixture identities stay
stable. No separate build or app copy was needed.

The unprofiled four-pair diagnostic retains control/candidate/candidate/control
Vox order and alternating Brave captures. Control counts are 30,411,172,659 and
30,449,275,864; candidate counts are 30,598,811,866 and 30,123,102,072. Their
medians are **30,430,224,261.5 versus 30,360,956,969**, an observed 0.228%
reduction. The ranges overlap: conservative separation is **−187,639,207**.
There is **zero whole-page savings credit** and no new broad-check checkpoint.
The candidate completes 193/168 frame checkpoints versus the controls' 240/213;
all four record 11 box-build checkpoints. Host load ranges roughly 62–81 on 18
CPUs. These differences prevent attributing the median change to the lookup.
Every browser and kernel exit is zero; the underlying driver's exit 1 records
the unmet target. Four pairs also remain below seven-pair acceptance.

The [production receipt](performance/chatgpt-length-unit-production-20261105.json)
preserves every observation, source proof, content/pixel check, ownership audit,
raw counter interval, host condition and verified evidence archive. The memory
guard adopts 46 processes without errors and peaks at 1,904,001,024 bytes under
12 GiB. Original scripts, the saved SOCKS fixture, private profiles/caches,
five-second settle, 1024×768 viewport, scale 2 and launch-through-encoded-PNG
coalition boundary remain unchanged. OS filesystem/shader caches are retained.
The requested 5% advantage over Brave remains unmet.

Tooling commit `c072bc10f` adds selected current-process instruction scopes to
the sealed-source diagnostic profiler. All nine focused tooling tests pass,
including real recursive/partial scopes, background-thread exclusion, strict
counter validation and the optional no-inline compiler mode. The separately
instrumented browser builds from the same completed production receipt in
96.36 seconds, peaking at 3,852,615,680 bytes under 12 GiB. Its thirty-second
diagnostic passes bootstrap, full content and exact pixels with stable inputs,
zero profiler faults and one partial root frame. Runtime peak is 1,729,249,280
bytes under 3 GiB.

The [selected-scope profile](performance/chatgpt-targeted-profile-20261105.json)
records 352,666,095,950 process instructions while its gate is active. Selected
self scopes include animation-style updates (94,996,573,420), retained layout
contexts (69,812,481,469), module delivery (59,093,683,054) and drawing
(35,068,195,619); the native effect-layer completion scope records
3,689,908,341. These are leads for component experiments. C `-O1`, disabled
optional inlining and callback overhead change the workload substantially.
Scopes include concurrent process threads, and self subtracts only selected
children. Recursive inclusive totals overlap and cannot be summed. Module
initialization is excluded and the standalone adblock worker differs from the
production helper. This profile establishes neither production function costs
nor an unprofiled saving; it receives no acceptance or instruction credit.

## November 5: HTML animation clock ownership

Commit `1ff3be42a` removes a second animation sample from native drawing when
the displayed document belongs to the BrowserApp's actual Page and local-root
navigable. HTML's rendering task already samples animations before rAF and
layout, as upstream `HTML/EventLoop/EventLoop.cpp` does. Native sampling after
that task advanced another timestamp and dirtied the newly produced styles.
The native callback still requests future display ticks. Standalone documents
and mismatched or uninstalled page roots retain their native clock. Hidden and
render-blocked documents keep HTML's eligibility rules. The original native
sample remains selectable with `VOX_RETAIN_NATIVE_ANIMATION_TICK`; a separate
opt-in diagnostic marks clock ownership.

**All 14 final focused jobs pass**, covering 168 case executions. The 26-case
main-module selection passes with both clock modes under poisoned production
preallocation, ordinary GC and no GC. It covers real HTML rendering tasks,
unchanged timestamps through native paint, adoption of current animated
geometry, subsequent frames, hidden/blocked eligibility, standalone fallback,
existing paint batching, rAF delivery, font deferral and live image replacement.
The three new clock cases also pass with AddressSanitizer/UndefinedBehaviorSanitizer
in both modes at densities 1 and 2. Peak compile RSS is 9,123,495,936 bytes under
12 GiB; peak runtime RSS is 638,828,544 bytes under 3 GiB.

The [focused receipt](performance/chatgpt-animation-clock-20261105.json)
retains the initial optional-unwrapping/UI2-path compile error, the duplicated
grouped-source list, and a Retina run that exposed coordinate assumptions in
two existing tests and the new geometry assertion. The grouped selection then
passes at an explicit logical density of 1; the new assertion now normalizes
device coordinates and passes at density 2 as well. A sanitizer compile also
stopped when the shared disk filled. Only completed generated outputs and
private benchmark profiles/caches were retired; archived generated-C copies
were hash-verified before removal. The identical sanitizer flags subsequently
pass. Every original failure and corrected run remains retained.

The completed single-C-unit executable
`e9b0f545f8f76ca40e0702a144698e401df74cac834dd27cbde11be8d7300a24`
contains the final clock policy. Source proofs and a separate two-pair execution
diagnostic pass. All twelve captures across that diagnostic and the unprofiled
comparison pass JavaScriptCore bootstrap, complete content identity and the
unchanged pixel reference. Browser/kernel exits are zero and input identities
remain stable throughout. No separate production build or app copy is used.

| Four-pair diagnostic, launch through encoded document PNG | Observed instructions |
| --- | ---: |
| Native duplicate-sample control observations | 30,544,793,863; 30,709,289,768 |
| HTML-clock candidate observations | 29,950,837,855; 30,164,074,824 |
| Control median | 30,627,041,815.5 |
| Candidate median | 30,057,456,339.5 |
| Observed median reduction | 1.860% |
| Conservative control/candidate separation | 380,719,039 |

The positive separation triggers the 5,000,000-instruction checkpoint:
**all 47 broad checks pass**, including the screenshot set, live image/SVG
mutation reftests, native rendering checks and 200 exact AST comparisons across
the two GC modes. The cadence resets to zero. This cohort keeps
control/candidate/candidate/control Vox order and alternating Brave captures.
It uses the same saved SOCKS fixture, original scripts, private profiles/caches,
five-second unfocused settle, 1024×768 viewport, scale 2 and exclusive coalition
launch-through-PNG boundary. OS filesystem/shader caches remain retained.

Control frame checkpoints are 377/283; candidate checkpoints are 343/349.
All four record 11 box-build checkpoints. Starting Vox load averages range
12.56–15.45 on 18 CPUs. Sanitizer compilation overlaps part of the cohort and
the shared disk fills during that compile. These conditions and the differing
frame counts qualify causal attribution: the result is an observed four-pair
diagnostic, with no acceptance credit. Brave's four lower bounds range
17,576,370,228–19,477,715,158. Vox still exceeds them; four pairs, including only
two candidate observations, also fall short of the required seven-pair cohort.
The [production receipt](performance/chatgpt-animation-clock-production-20261105.json)
links every count, ownership audit, capture, source proof, memory guard and broad
check. Its guard adopts 46 processes without errors and peaks at 1,932,427,264
bytes under 12 GiB. Driver exit 1 records the unmet Brave target.

A separate [clock-advancement diagnostic](performance/chatgpt-animation-clock-timeline-20261105.json)
verifies that the displayed page continues animating. Observations at the
Document update and native-tick entries join the displayed document pointer to
**2,470 strictly increasing timestamps**, from 1,783.9 to 35,238.7 ms. The profile
records exactly 2,470 HTML rendering updates, Document animation updates and
animation-style callbacks, alongside 2,516 native-tick entries. Full content,
bootstrap and pixels pass exactly. The first observation compile used an
unavailable macro in preprocessed C and launched no browser; its failure and
corrected recipe are retained. C `-O1`, disabled optional inlining, observation
printing and the thirty-second settle make this eligibility evidence only.
It receives no timing or instruction acceptance credit.

The requested **5% advantage over Brave remains unmet**. These frozen-page
results establish neither live-site performance nor isolated rendering time or
scrolling FPS, and no qualifying catalog entry is added.

## November 5: production stack and frame-stage diagnostics

Two fresh production launches collect native stack samples; a third enables
the existing frame-stage instruction checkpoints. All three pass bootstrap,
full content, exact pixels and stable input identities. `xctrace` is unavailable
on this host, so these runs use `/usr/bin/sample`. The first sampler recipe
performs symbol lookup before collection; the second defers it. Their requested
windows and actual command durations are retained. Waiting threads dominate
the reports, and neither recipe establishes production instruction costs.

The checkpoint capture records 1,724 ordered cumulative readings with no
decreases. Its 312 context-ready/document-replayed intervals total
6,049,734,466 current-process instructions. Eight frame-complete/build-boxes
gaps total 8,016,038,231, but include intervening style and other work before
the box marker; they do not isolate tree construction. Frame-complete/prepared
gaps total another 5,110,390,928. These are leads for a finer profile, with
concurrent process threads included and no optimization credit. The
[production diagnostic receipt](performance/chatgpt-production-diagnostics-20261105.json)
retains every command, sample, checkpoint, PNG, identity, guard and host condition.

Tooling commit `c19ede019` adds `--optimization production` to the sealed C
profiler. It preserves the completed receipt's optimization and inlining flags;
the original `O1` mode remains the default. All eleven tooling tests pass,
including exact compiler-option preservation, CLI forwarding, invalid-mode
rejection and real recursive/partial callback execution under C `-O3`. Profiles
remain diagnostic because their callbacks and counters add work.


## November 5: profile with production compiler flags

The completed single-unit receipt for executable
`fc1b35e2a33b03af8106ca59b65b3f4961ed02cad05a2abff8fa1953c6135c1a`
supplies the sealed source and link inputs for a separate diagnostic executable.
The profiler retains the original C `-O3` and inlining flags. Compilation takes
1,360.49 seconds under heavy host contention and peaks at 10,358,833,152 bytes
under the 12 GiB guard. No production bundle is rebuilt or copied.

Both five-second captures pass bootstrap, complete content identity, unchanged
pixels and stable input identities. The selected-counter capture has zero
profiler faults and one partial root frame. Its active gate records
41,144,053,373 current-process instructions. Selected self scopes include module
fulfillment (11,106,078,835), retained layout (6,598,737,046), the document style
callback (5,155,118,184) and native CSS effect-layer completion (2,672,909,818).
Self excludes only selected children; concurrent process threads and callback
costs remain included. Recursive inclusive totals overlap. Module fulfillment
includes JavaScriptCore jobs and native binding calls, so it does not isolate
JavaScript parsing or execution. These counts cannot be compared directly with
the unprofiled launch-through-PNG coalition totals.

The second capture collects surviving function call counts and elapsed scopes,
with zero faults and three partial frames. It observes 48,237 URL constructions,
101,292 protected-value registrations and 155,050 host-function dispatches.
Counts alone establish neither redundant inputs nor an optimization opportunity.
A separate production leaf diagnostic passes the same rendering gates. Its
labels charge grouped handlers to their first command; elapsed times include
host waits at load averages above 100 on 18 CPUs. These observations guide
component experiments and receive no performance credit.

The [profile receipt](performance/chatgpt-production-optimized-profile-20261105.json)
links the verified archive containing compiler inputs, commands, raw profiles,
leaf observations, captures, guards and all eleven tooling-test results. Runtime
peaks stay below the 3 GiB guards. Original author scripts and the saved SOCKS
capture remain unchanged. The broad-check cadence stays at zero, and the
requested 5% advantage over Brave remains unmet.


## November 5: admitted URL input caching

Commit `cf91de94e` adds a binding-local memo of successful converted URL input
and optional-base pairs. It keeps 512 entries in two-way sets, compares the full
raw strings and base presence on every hit, and returns independent copies of
all record components. URL objects and searchParams owners remain fresh. A
32,768-bit admission filter avoids copying first-seen inputs into storage and
clears after 4,096 successful misses. Inputs or bases above 2,048 bytes bypass
the memo. Production preallocation resets replaced storage at a 2 MiB threshold
plus one bounded entry. Closing the binding clears both this memo and its
existing parsed-base cache. `VOX_RETAIN_URL_INPUT_PARSE` selects the base-only
control; separate diagnostics report cache hits.

A source-injected diagnostic records **48,258 constructions and 1,354 distinct
input/base pairs**, all in one binding. It prints after both WebIDL conversions,
so the engine still executes conversion order, reentry and exceptions. The
thirty-second C `-O1`/no-inline capture passes bootstrap, complete content and
unchanged pixels with stable identities. Its printing and instrumentation earn
no instruction credit. A separate five-second production style-invalidation
trace also passes those gates and is retained as a diagnostic lead.

**All 32 final focused jobs pass**, covering **572 case executions** with the
current compiler. Forty-five DOM URL cases and 25 JavaScriptCore binding cases
pass in both cache modes under poisoned preallocation, ordinary GC, no GC and
AddressSanitizer/UndefinedBehaviorSanitizer. Three workspace ownership cases pass
in each mode. Coverage includes raw keys, invalid and absent bases, hash
collisions, admission-filter saturation, oversized inputs, producer retirement,
cache resets/close, independent paths and query owners, coercion reentry,
original exceptions and unmodified upstream URL/query fixtures. Compile peak is
9,772,597,248 bytes under 12 GiB; runtime peak is 922,157,056 bytes under 3 GiB.
V frontend invocations retain their 10G limit.

The first no-GC stress run exceeded its 3 GiB guard at 3,275,014,144 observed
bytes. Arena retirement is inactive in that mode, leaving long-input parser
allocations unreclaimed. Final ordinary/no-GC runs use 64 short stress inputs;
poisoned preallocation and sanitized runs retain all 4,096 long inputs. The
failed run stays archived. An early component controller also ran before its
binary was published and stopped in preflight without samples. The prototype's
8.54% unique-input regression is retained with its source and counters.

Benchmark commit `4509b41d6` compares the same observed constructor sequence
against canonical parse/serialization results. Each scene uses alternating
control/candidate/candidate/control executions of one C `-O2` preallocated
component binary, with separate execution diagnostics. Reference setup and cache
teardown lie outside the measured parse/serialize intervals. The final observed
component medians are:

| Component scene | Fewer observed instructions |
| --- | ---: |
| Observed constructor sequence, empty memo | 60.733% |
| Observed constructor sequence, warm memo | 63.283% |
| Repeated relative inputs | 69.324% |
| Unique inputs | 0.339% |
| Oversized inputs | −0.157% |

The admission filter removes the prototype's material unique-input regression.
The small oversized-input regression is preserved. These component results do
not establish browser costs. The [focused/component receipt](performance/chatgpt-url-input-cache-20261105.json)
links all versions, raw observations, compiler/source proofs, guards, host
conditions, the observed input sequence and verified archives.

The latest completed production executable is
`f2762ca3223ba199dab08c476096c61accdd00ac812f125c9a6da279f9708b4d`,
compiled as 33 parallel C units with ThinLTO. Its completed receipt has identical
aggregate build-input hashes before and after compilation. Parallel builds do
not publish sealed preprocessed C; retained parser disassembly verifies the
admission filter, 4,096-miss reset, 2 MiB retirement threshold and independent
record-copy path. Separate candidate/control diagnostics confirm cache hits
only with the memo enabled. All twelve captures across diagnostics and the
unprofiled cohort pass bootstrap, full content, exact reference pixels and zero
browser/kernel exits. Executable, dependency, tool and fixture identities stay
stable. No separate production build or app copy is used.

| Four-pair launch-through-encoded-PNG diagnostic | Observed instructions |
| --- | ---: |
| Base-only control observations | 30,700,369,364; 30,605,155,434 |
| Input-memo candidate observations | 29,148,338,369; 30,052,916,083 |
| Control median | 30,652,762,399 |
| Candidate median | 29,600,627,226 |
| Observed median reduction | 3.432% |
| Conservative control/candidate separation | 552,239,351 |

The positive separation triggers the 5,000,000-instruction checkpoint:
**all 47 broad checks pass**. The screenshot set has 17 exact cases and three
within its existing bounds (`inline-node`: 13 pixels; `text-decorations`: 1,341;
`canvas-text`: 2,033). Native rendering checks and all 200 exact upstream AST
comparisons pass. No references or tolerances change; the cadence resets to zero.

The cohort retains the saved SOCKS fixture, original scripts, empty private
profiles/caches, five-second unfocused settle, 1024×768 viewport, scale 2 and
exclusive resource-coalition launch-through-encoded-PNG boundary for both
browsers. OS filesystem/shader caches remain retained. The guard adopts 45
process identities without errors and peaks at 1,770,110,976 bytes under 12 GiB;
controller/guard exit is zero. Driver exit 1 records the unmet target.

Controls complete 292/280 frame checkpoints and 10/11 box builds; candidates
complete 255/312 frames and 10/11 box builds. Starting Vox load averages range
22.64–33.19 on 18 CPUs, with focused sanitizer compilation overlapping the
cohort. Different frame counts and host load qualify causal attribution. This
is an observed four-pair diagnostic with only two candidate observations, below
seven-pair acceptance. Brave's four lower bounds range
16,235,663,407–16,433,599,280, still below Vox. No historical single/parallel-C
comparison receives optimization credit.

The [production receipt](performance/chatgpt-url-input-cache-production-20261105.json)
links every capture, raw count, ownership audit, disassembly proof, broad check
and verified archive. The requested **5% advantage over Brave remains unmet**.
These frozen-page results establish neither live-site performance, isolated
rendering time nor scrolling FPS, and no qualifying catalog entry is added.


## November 5: uniform-border effect surfaces and eligibility rejection

Commit `0413bb099` lets the effect-bounds pass enclose a uniform rounded border
instead of treating it as unknown ink. It retains a full stroke width and an
antialiasing fringe, covers both transformed native/SVG strokes and the portable
line renderer's screen-space width, and rejects non-finite geometry, unsupported
radii and native precision loss. Unknown operations and spatial filters keep
unbounded surfaces. `VOX_RETAIN_UNBOUNDED_BORDER_EFFECTS` selects the original
behavior; an opt-in diagnostic reports bounded groups.

All **12 final focused jobs pass**, covering **224 case executions** across
both variants, poisoned preallocation, ordinary GC, no GC and ASan/UBSan.
Checks include nesting, ancestor clips, fractional/rotated/shrinking/collapsed
transforms, scrolling, prior recording ownership and existing paint/border
regressions. Compile peak is 9,055,305,728 bytes under 12 GiB; runtime peak is
351,092,736 bytes under 3 GiB. The native static fixture is pixel-exact between
control and candidate at capture/backing scales 1 and 2, with full title,
readiness, viewport and element-count audits on all four fresh captures.

The isolated native scan benchmark (`6835e42ea`) uses identical synthetic ink
and exact expected bounds. Narrow versus full-viewport regions reduce observed
scan instructions by 12.74%/12.22% in the sparse-write scenes and 65.73%/64.87%
after full zero writes, at scales 1/2. This bypasses V lowering and excludes
painting, compositing and browser startup/output. It establishes no browser
saving or physical-residency guarantee.

The production diagnostic uses completed single-unit executable
`c21405463324fee09b119a326f4c2e047c30225650af19f8ee44763464b1cd57`.
Sealed-source checks confirm the final portable extent, guards and control.
All four frozen-page captures pass JavaScriptCore bootstrap, full content,
unchanged pixels, stable input identities and zero browser/kernel exits. Both
Vox variants report **zero eligible bounded border groups**. The harness rejects
eligibility and starts no unprofiled optimization comparison. **No whole-page
instructions are credited**, and no broad checkpoint is due.

A separate valid production command trace explains the rejection: each visible
effect group containing a uniform border also contains an SVG path, whose ink
remains unknown to this pass. The trace omits some offscreen commands and is a
diagnostic lead, not a complete rejection audit. Original scripts, the saved
SOCKS capture, pixel/content references and five-second page protocol remain
unchanged. Historical single/parallel compiler modes are not compared for credit.

The [receipt and verified archives](performance/chatgpt-effect-border-20261105.json)
retain the initial test's missing Chromium painting policy, the precursor
selection stopped after the portable-extent source refinement, a component
compile's unused shared-header function error, and a fixture audit using the
wrong selector JSON shape. All corrected final focused and native fixture
checks pass; every original failure remains retained. The broad-check cadence
stays at zero. The requested **5% advantage over Brave remains unmet**.


## November 5: solid SVG-fill effect surfaces

Commit `4cfd616db` lets solid SVG fills contribute a known ink envelope to an
opacity group. It reuses the serialized native path bounds, including both
transforms, curve controls and arc extrema, with a screen-space antialiasing
fringe. Strokes, gradients, patterns, malformed/non-finite paths and unsupported
effects retain the original unbounded behavior. The existing border envelope
can now participate in groups that also contain an eligible SVG fill.
`VOX_RETAIN_UNBOUNDED_SVG_EFFECTS` selects the original SVG behavior.

All **15 focused jobs pass**, covering **192 case executions**: the 23-case
selection runs in both variants under poisoned preallocation, ordinary GC,
no GC and ASan/UBSan, followed by two fresh four-case executions after the
format-only test commit `73471acda`. Sanitizers use C `-O0`. Compile peak is
5,531,303,936 bytes under 12 GiB; runtime peak is 282,001,408 bytes under 3 GiB.
Tests cover transformed bounds, curve/arc envelopes, rejected geometry, nesting,
clipping and live path replacement without altering an earlier recording.
The native static fixture is pixel-exact between variants at scales 1 and 2;
all four fresh captures pass title, readiness, viewport and element-count audits.
The original formatter verification and optional-comma classifier failures are
retained with the corrected verification and fresh executions.

Completed parallel executable
`e987541d3c1f1285d790a9886f45292a64c9a4671eb627d152f731f6b2e62cae`
uses 33 C units. Its receipt has identical aggregate build-input hashes before
and after compilation. Exact owned-source blobs at its recorded Git head and
available bounds-function disassembly are retained; this is not a sealed-C
proof. A nonblocking shared publication lease pins the canonical bundle through
the four native fixture captures, eligibility diagnostic and matched cohort.
No production build or app copy is made. The lease is released on completion.

All twelve frozen-page captures pass JavaScriptCore bootstrap, full content,
unchanged reference pixels, stable input identities and zero browser/kernel
exits. Separate diagnostics confirm bounded SVG groups with the candidate and
none with the control; diagnostics are disabled in the matched comparison.

| Four-pair launch-through-encoded-PNG diagnostic | Observed instructions |
| --- | ---: |
| Unbounded-SVG control observations | 29,615,362,005; 29,294,512,158 |
| Bounded-SVG candidate observations | 29,562,561,612; 29,137,324,292 |
| Control median | 29,454,937,081.5 |
| Candidate median | 29,349,942,952 |
| Observed median reduction | 0.356% |
| Conservative control/candidate separation | −268,049,454 |

The count ranges overlap, so **no whole-page instruction saving is credited**.
No broad checkpoint is due and the cadence stays at zero. Controls complete
348/300 frame checkpoints; candidates complete 358/375. Starting Vox load
averages range 21.97–30.37 on 18 CPUs. Those differences qualify causal
attribution. Brave's four lower bounds range 16,131,979,373–19,398,305,754,
below Vox; four pairs also remain below seven-pair acceptance.

The cohort retains the saved SOCKS fixture, original author scripts, empty
private profiles/caches, five-second unfocused settle, 1024×768 viewport,
scale 2 and exclusive-coalition launch-through-encoded-PNG boundary. OS
filesystem/shader caches remain retained. The memory guard adopts 50 process
identities without errors and peaks at 1,715,683,328 bytes under 12 GiB;
controller/guard exit is zero. Driver exit 1 records the unmet Brave target.

The [receipt and verified archives](performance/chatgpt-effect-svg-20261105.json)
retain the focused checks, source proofs, every raw count, ownership audit,
capture, command, guard and host condition. The requested **5% advantage over
Brave remains unmet**. These frozen-page results establish neither live-site
performance, isolated rendering time nor scrolling FPS; no catalog entry is added.


## November 5: shared JavaScript protection links

Commit `e537b584c` replaces the per-handle protection-index arrays with links in
a shared dense array and a map to each handle's newest protection. Every
JavaScriptCore protection still owns one root. Releasing a root updates both
neighbors and any moved root after swap removal, including when an older
duplicate moves into its removed tail's slot. Runtime close clears the links
and releases every actual JSC protection. The original array index remains
available with `VOX_RETAIN_PROTECTED_VALUE_ARRAY_INDEX=1`; the pre-existing
scalar control also remains available.

All **16 final focused jobs pass**, covering **384 case executions** across
candidate, array control and scalar control in poisoned preallocation, ordinary
GC, no GC and C `-O0` ASan/UBSan. The 32-case selection covers duplicate chains,
multiset churn and full drains, absent releases, actual JSC collection, runtime
close, WebIDL bindings, idle callbacks, custom elements and native host functions.
The earlier three-variant preflight also passes its 15 case executions. Final
focused compile peak is 6,366,199,808 bytes under 12 GiB; runtime peak is
233,259,008 bytes under 3 GiB.

The component benchmark (`ea384f9fa`) uses real JSC protection APIs on a bank of
objects independently kept alive by a JS global. Each measured interval excludes
bank setup, final bank verification and runtime close. One executable, compiled
with production C `-O3` and preallocation, runs array/candidate/candidate/array;
two additional diagnostic runs confirm branch execution separately. Checksums
match the exact number of protections in every run.

| Component scene | Median instruction reduction |
| --- | ---: |
| Distinct-handle churn | 9.405% |
| One handle with many protections | 0.112% |
| Duplicate fanout | 1.736% |
| Absent-handle releases | −0.388% |

The absent-handle ranges overlap; the small regression remains retained. These
component results do not establish browser savings or trigger a whole-page broad
checkpoint. The initial benchmark compile's deprecated cast and the archive
finalizer's incorrect generated-C path are retained; corrected independent
compilation, measurements and archive verification pass without rerunning or
dropping successful observations.

The [focused/component receipt](performance/chatgpt-protected-value-links-20261105.json)
links the raw counts, source proofs, guards, host conditions and verified archive.

The earlier browser-validation checkpoint was blocked. Its completed executable,
`d0eac328379f92fcaef0206c83caad98113c17c97b78748df06f1995ba79758e`,
predated the linked registry. Shared builds failed first on an unfinished
navigation method, then on a generated-C optional CSP request-pointer conversion
in navigation embedding policy. The availability receipt, harness and failed
builds remain retained; that checkpoint launched no browser captures.

The subsequent completed production executable is
`142853c750815d0bf22b98526a0bca75806620c7c58e768b2e1f9c58364eb0f0`,
compiled as 33 parallel C units. Its aggregate build-input hashes match before
and after compilation. Exact owned-source blobs at its recorded Git head and
available registry-function disassembly are retained; no sealed-C proof is
claimed. A nonblocking shared publication lease pins the canonical bundle
through the separate execution diagnostic, matched cohort and broad checks.
The lease is released after completion. No separate production build or app
copy is used.

All twelve frozen-page captures pass JavaScriptCore bootstrap, full content,
unchanged reference pixels, stable inputs and zero browser/kernel exits. Separate
diagnostics confirm the linked registry only in the candidate and the original
array registry only in the control. Diagnostics are disabled in the matched runs.

| Four-pair launch-through-encoded-PNG diagnostic | Observed instructions |
| --- | ---: |
| Array-registry control observations | 30,015,745,038; 30,214,494,522 |
| Linked-registry candidate observations | 29,933,821,350; 29,528,988,360 |
| Control median | 30,115,119,780 |
| Candidate median | 29,731,404,855 |
| Observed median reduction | 1.274% |
| Conservative control/candidate separation | 81,923,688 |

The positive separation triggers the 5,000,000-instruction checkpoint:
**all 47 broad checks pass**. The screenshot set has 17 exact cases and three
within existing bounds (`inline-node`: 13 pixels; `text-decorations`: 1,341;
`canvas-text`: 2,033). Native rendering checks and all 200 exact upstream AST
comparisons pass. No references or tolerances change; the cadence resets to zero.

Controls complete 484/471 frame checkpoints; candidates complete 468/476.
Starting Vox load averages range 5.85–7.91 on 18 CPUs. The frame and host-load
differences qualify causal attribution. This is a four-pair diagnostic with two
candidate observations, below seven-pair acceptance. Brave's four lower bounds
range 18,526,748,178–19,454,558,194, still below Vox. No historical compiler-mode
comparison receives instruction credit.

The cohort retains the saved SOCKS fixture, original scripts, empty private
profiles/caches, five-second unfocused settle, 1024×768 viewport, scale 2 and
exclusive-coalition creation-through-encoded-PNG boundary. OS filesystem/shader
caches remain retained. The memory guard adopts 42 process identities without
errors and peaks at 1,751,695,360 bytes under 12 GiB. Controller/guard exit is
zero; driver exit 1 records the unmet Brave target.

The [production receipt](performance/chatgpt-protected-value-links-production-20261105.json)
links every count, capture, source proof, ownership audit, broad check, guard,
host condition and verified archive, including the earlier unavailable-bundle
checkpoint. The requested **5% advantage over Brave remains unmet**. These
frozen-page results establish neither live-site performance, isolated rendering
time nor scrolling FPS, and no qualifying catalog entry is added.


## November 5: byte percent encoding and nested cache initialization

Commit `78a6b88be` percent-encodes valid UTF-8 with an exact-sized owned byte
buffer. All encode sets escape non-ASCII code points, so their original UTF-8
bytes can be escaped directly. Unchanged ASCII still returns an owned clone;
malformed UTF-8 keeps the original rune decoder and its replacement behavior.
`VOX_RETAIN_RUNE_PERCENT_ENCODING` selects the original encoder for comparisons.

The native binding sanitizer uncovered a bug in the earlier input cache,
reproduced with both encoders. An explicit fixed pointer-array default became
an array expression inside a nested C aggregate initializer. Clang treated that
expression as the first pointer element, leaving cache slot zero pointing to
stack storage. Generated-C probes and a small strict Clang reproducer confirm
the conversion. Commit `3d1dba1a8` removes the explicit default and uses aggregate
zero initialization. The nested-owner regression fails before this change and
passes afterward, including all 512 initial slots, bucket-zero admission and
clear/reuse. The direct constructor alone did not reproduce the bug. The native
owner's generated constructor and actual JSC sanitizer checks confirm the fix.

The combined **48-job focused verification passes 1,488 case executions**. It
carries 24 successful URL and isolated file-policy jobs with unchanged encoder
sources; those generated programs do not include DOMURL. It freshly runs 24
DOMURL/native binding jobs after the cache fix, covering 576 executions in both
encoder modes. Poisoned preallocation, ordinary GC, no GC and C `-O0` ASan/UBSan
pass. Checks cover every ASCII byte, all nine sets and both space policies,
Unicode boundaries, malformed sequences, random scalar sequences, input-arena
retirement, actual JSC coercion/reentry, cache eviction and close. Compile peak
is 5,411,192,832 bytes under 12 GiB; runtime peak is 947,634,176 bytes under 3 GiB.

The component benchmark (`25fb5ec5c`) uses production C `-O3`, **unpoisoned**
preallocation, exact rune-based output oracles and one executable for
control/candidate/candidate/control observations. Setup and oracle creation are
outside the instruction interval; output checks and scratch retirement remain
inside, with workspace setup amortized across 64 repetitions. Two additional
execution diagnostics remain separate from the unprofiled summary.

| Component scene | Median instruction reduction |
| --- | ---: |
| Single ASCII path characters | 62.042% |
| Single escaped query characters | 63.010% |
| Unchanged ASCII string | 86.641% |
| Mixed query | 46.670% |
| Space-as-plus form input | 52.881% |
| Unicode | 80.761% |
| Malformed UTF-8 | −3.655% |

The malformed-input regression remains retained. Preliminary cohorts used a
workspace per repetition and/or poisoned allocation; all their observations and
source versions remain preserved. A preliminary summary accidentally included
the diagnostic control and is corrected from the unchanged raw observations.
Changes in benchmark boundaries or poisoning receive no engine optimization
credit. The initial whole-URL selection also combined a process-wide file-origin
test with tests requiring default policy; the final selection isolates it without
changing assertions. The costly full-DWARF diagnostic build was stopped after
the relevant IR/assembly was retained and receives no validation credit.

The [encoder receipt](performance/chatgpt-percent-encoding-bytes-20261105.json)
and [cache correctness receipt](performance/url-input-slot-initialization-20261105.json)
link the focused checks, raw observations, failing controls, source proofs,
guards, host conditions and verified archives. The cache fix is shared by both
encoder modes and receives no percent-encoder performance attribution.

Browser validation remains pending. Completed executable
`e05f01a6c41853464760ce4b59cf1782813fca8b9b1e45de22d7fe22be7a1b5c`
contains the encoder marker, but its recorded source head and aggregate input
hash do not establish the final encoder and cache fix. The current source hash
is stable across two reads and differs from that receipt. Another shared build
is active; no separate production build or app copy is made. No page captures
or instruction trials are launched for this change. The prepared comparison
retains the original SOCKS fixture, author scripts and content/pixel references.
The [availability receipt](performance/chatgpt-percent-encoding-bytes-production-20261105.json)
preserves that preflight and harness. **No whole-page saving is credited**, no
broad checkpoint is due, and the cadence stays at zero. The requested **5%
advantage over Brave remains unmet**.


## November 5: tracking audit of the current frozen capture

The existing read-only detector now audits the current v2 SOCKS capture:
**293 scripts, 3,610,641 bytes, four name-based review candidates and no parse
errors**. No archived script matches an existing script-blocking rule. All 380
unresolved imports are computed dynamic imports; an empty direct-importer list
therefore does not establish an unused module.

| Review candidate | Bytes | Direct static importers | Source files mentioning its filename |
| --- | ---: | ---: | ---: |
| `analytics-C3m-dpbI.js` | 4,171 | 8 | 14 |
| `analytics-ces-business-context-DAjYxggM.js` | 112,410 | 0 | 1 |
| `native-telemetry-CLXxBfSg.js` | 10,679 | 0 | 1 |
| `performance-metrics-CiFEOZ7n.js` | 46,391 | 0 | 1 |

Each of the three candidates with no direct importer appears in a wrapped
dynamic-import expression. Telemetry also contains `visibilitychange`,
`pagehide` and `pageshow` listener code. These are dependency and lifecycle
review leads, not proof of execution or of a resolver's semantics. **No safe
additional script removal is established**, and filtering is not changed.

Existing rules block both XHR and Ping probes for the business, performance and
stats-flush event endpoints. These are explicit policy probes: retained replay
logs do not distinguish Fetch from Beacon and do not by themselves establish
which browser blocked a request. All script, manifest, request-log, detector,
lexer and filter-engine hashes remain stable throughout the audit. It executes
no author code, downloads nothing and launches no browser. The
[receipt and verified archive](performance/chatgpt-tracking-audit-v2-20261105.json)
retain the dependency graph, wrapped-import contexts, exact decisions and guards.

The requested **5% advantage over Brave remains unmet**.


## November 5: encoder production availability follow-up

Two newer parallel builds completed compilation and smoke checks but were
superseded after their source inputs changed. The next attempt failed in
`native_graphite_canvas.h`: the pinned Skia API has no
`SkCanvas::writePixels(SkPixmap, int, int)` overload. That graphics file belongs
to concurrent work and is not changed by this task. The
[availability receipt](performance/chatgpt-percent-encoding-bytes-production-20261105.json)
retains the completed/superseded attempts, compiler failure, memory guards and
verified archives. A read lease confirmed that the available executable still
has SHA-256 `e05f01a6c41853464760ce4b59cf1782813fca8b9b1e45de22d7fe22be7a1b5c`;
its receipt still cannot prove the final encoder and nested-cache source.

The shared build guard remains busy. No separate build is queued, no app is
copied and no browser trial is launched. The 48 focused jobs and component
results remain valid in their separate receipts; final production comparison
is pending. No whole-page saving is credited, broad-check cadence stays at
zero, and the requested **5% advantage over Brave remains unmet**.


## November 5: completed byte-encoder production comparison

Completed parallel executable
`4cd3e2050a02a7bead8658f1c6dbe031cb1dd446feddd757a31c3cb12fe45d35`
contains the final byte encoder and nested URL-cache initialization fix. Its
33-unit receipt has matching before/after aggregate build-input hashes. The
four owned source blobs match the receipt's recorded Git head; available
encoder disassembly is retained. A nonblocking shared publication lease pins
the canonical bundle throughout the comparison. No app is copied or separate
production build requested.

All **12 fresh captures pass bootstrap, complete content and exact unchanged
pixels**. Separate diagnostics show the byte-encoder marker only in the
candidate. The matched captures disable that marker and keep the original
rune encoder as the control. The cache initialization fix remains enabled in
both variants and receives no encoder performance attribution.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Rune control 1 | 29,659,100,317 |
| Byte candidate 1 | 29,697,680,502 |
| Byte candidate 2 | 29,246,617,410 |
| Rune control 2 | 29,672,904,438 |
| Control median | 29,666,002,377.5 |
| Candidate median | 29,472,148,956 |

The median is **0.653% lower**, but the observed ranges overlap: the conservative
separation is **−38,580,185 instructions**. One candidate regresses against both
controls. Therefore **no whole-page saving is credited**, no broad checkpoint
is triggered and the cadence stays at zero. Frame checkpoints are 362/361 for
controls and 363/359 for candidates. Host one-minute load rises from 82.35 to
132.75 on 18 CPUs; that contention and frame variation further limit attribution.
The four Brave references range from 16,096,373,487 to 16,358,539,431 observed
instructions across their lower/upper bounds. Four matched pairs are below
seven-pair acceptance and remain far from the requested 5% advantage.

The original frozen SOCKS capture and author bytes, private profiles/caches,
five-second unfocused settle, 1024×768 viewport, backing scale 2 and exclusive
coalition creation-through-encoded-document-PNG scope remain unchanged. OS
filesystem/shader caches are retained; GPU and outside-coalition service work
are excluded. This is frozen-page evidence, with no live-site, isolated-rendering
or scrolling claim. The outer guard exits zero, adopts 47 process identities
without errors and peaks at 1,739,374,592 sampled RSS bytes under 12 GiB. Both
phase controllers exit zero; the browser comparison driver's separate exit one
records the unmet Brave gate.

The [completed receipt](performance/chatgpt-percent-encoding-bytes-production-20261105.json)
links counters, audits, PNGs, commands, source proofs, actual exits and six
verified archives. It preserves the earlier pending receipt and all inspected
superseded/failed build attempts. The publication lease is released. **The
requested 5%-below-Brave target remains unmet**.


## November 5: direct compact DOM identity replies

Commit `e3a4a961c` serializes already-materialized element replies directly as
`{"bridgeKey":...}` instead of constructing a one-property JSON map. The
existing JSON string encoder still owns escaping and byte behavior. Keys over
256 bytes keep the original map encoder. First-use hydration, non-element
node states, wrapper identity, live mutation replay and collection reply arenas
retain their existing behavior. `VOX_RETAIN_IDENTITY_REPLY_MAP=1` selects the
map control; `VOX_IDENTITY_REPLY_DIAGNOSTICS=1` reports direct execution once.

All **24 final focused jobs pass**, comprising eight compile jobs and sixteen
runtime jobs: both reply modes under poisoned preallocation, ordinary GC,
no GC and AddressSanitizer/UndefinedBehaviorSanitizer. Generated-C test calls
confirm **296 test-function executions**: seven query-wire cases and thirty
native bridge cases, each in both reply modes and all four allocation/check
modes. New cases cover arbitrary/escaped/invalid byte keys, the size boundary,
input-arena retirement, first hydration, non-element state and actual
JavaScriptCore wrapper identity after live mutations. Existing collection
checks also retain temporary reply bytes only until the JavaScript copy.

Tooling commit `31d22d688` runs four alternating unprofiled component trials,
with separate execution diagnostics and exact output/checksum checks. Setup,
oracle construction and warmup are outside the interval; allocation, batched
scratch scopes and output checks are counted.

| Synthetic reply-key component | Median observed instruction reduction |
| --- | ---: |
| Generated element/query/created keys | 70.305% |
| Empty key | 74.108% |
| Escaped keys | 55.360% |
| Unicode keys | 69.108% |
| 255-byte key | 37.415% |
| 256-byte key | 45.304% |
| 257-byte map fallback | −0.244% |
| 16 KiB map fallback | −0.872% |
| Malformed UTF-8 key | 69.417% |

The unrestricted prototype regressed 7.227% on the 16 KiB key, prompting the
bounded fallback. That cohort and all 24 prototype checks remain retained.
The initial fixture compile error and an unregistered-parent fixture crash,
also reproduced with the map control, are retained as failures. The final
fixture registers the parent before querying child node state. No failed
attempt is relabeled as a passing check.

The [focused/component receipt](performance/chatgpt-identity-reply-20261105.json)
links the exact counts, source/executable hashes, commands, guards and verified
archives. Component gains establish no whole-page saving or Brave acceptance;
production validation is recorded separately below.


## November 5: compact identity reply production comparison

The first production attempt rejects during source preflight: the available
bundle contains the marker, but neither recorded Git head proves the final
owned source. Its controller and guard failure are retained, with **zero
browser launches and no instruction credit**. A later completed canonical
bundle supplies the final twelve owned implementation blobs at its recorded
head and stable before/after aggregate build-input hashes. Available reply
and caller disassembly is retained, without a sealed-C claim.

The valid cohort pins 33-unit parallel executable
`c5a048a5d30aeb1f1acde7e869d3c6a3a2335657f1499a6964db0b1300b7203f`
under a nonblocking shared publication lease. All **12 fresh captures pass
bootstrap, complete content and exact unchanged pixels**. The separate
diagnostic confirms direct reply execution only in the candidate; matched
captures disable diagnostics. Both modes preserve hydration and oversized-key
fallback. No author script or resource bytes are changed.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Map control 1 | 30,055,670,421 |
| Direct candidate 1 | 29,358,366,728 |
| Direct candidate 2 | 29,770,021,754 |
| Map control 2 | 30,154,698,113 |
| Control median | 30,105,184,267 |
| Candidate median | 29,564,194,241 |

The observed median reduction is **1.797%**. The ranges separate by a
conservative **285,648,667 instructions**, triggering the required broad
checkpoint. All **47 checks pass**: twenty screenshot cases (seventeen exact,
three within existing fuzzy limits), twenty-two native compile/runtime jobs,
four AST compile/runtime jobs covering 100 exact fixtures in each GC mode,
and one pixel-diff control job. References and tolerances remain unchanged.
The existing fuzzy cases differ in 13 inline-node pixels, 1,341 text-decoration
pixels and 2,033 canvas-text pixels (578 sparse outliers).

Control frame checkpoints are 450/472 versus 478/472 for candidates. One-minute
host load falls from 19.21 to 10.06 on 18 CPUs over the matched cohort. Frame
variation, changing contention and only two observations per variant limit
causal attribution. The four Brave reference intervals span 18,488,464,895 to
19,318,261,884 observed instructions. The candidate's highest observed count
is still about 1.61 times the lowest Brave count. Four matched pairs remain
below seven-pair acceptance; **the requested 5% advantage remains unmet**.

The original SOCKS capture and author scripts, fresh private profiles/caches,
five-second unfocused settle, 1024×768 viewport, scale 2 and exclusive-coalition
creation-through-encoded-document-PNG scope remain unchanged. OS filesystem/
shader caches are retained; GPU and outside-coalition services are excluded.
There is no live-site, isolated-rendering or scrolling claim. The outer guard
exits zero, adopts 46 process identities without error and peaks at
1,744,633,856 sampled RSS bytes under 12 GiB. Both phase controllers and broad
checks exit zero; the comparison driver's separate exit one records the unmet
Brave gate.

The [completed production receipt](performance/chatgpt-identity-reply-production-20261105.json)
links raw counters, audits, PNGs, source proofs, host conditions, commands,
actual exits and six verified archives. The rejected preflight, prototype
regression and corrected fixture failures remain preserved. The publication
lease is released and broad-check cadence resets to zero. **No 5%-below-Brave
acceptance is claimed**.


## November 5: media-feature name dispatch

Commit `6dd324679` replaces repeated media-feature name chains with a lookup by
byte length followed by a `MediaFeatureID` switch. The original inexpensive
hover branch stays ahead of general dispatch. There is no name/value cache:
each call observes the current feature name, viewport, display density and
preferences. The original complete name-chain function body remains unchanged
as a control, selected with `VOX_RETAIN_MEDIA_FEATURE_NAME_CHAIN=1`.
`VOX_MEDIA_FEATURE_LOOKUP_DIAGNOSTICS=1` reports an executed new path once.

All **12 final focused jobs pass**: four compilations and both lookup modes
under poisoned preallocation, ordinary GC, no GC and AddressSanitizer/
UndefinedBehaviorSanitizer. Generated-C call sites confirm **344 test-function
executions** (43 cases × four allocation/check modes × two lookup modes).
The new cases cover all 37 supported identifiers, case-sensitive and arbitrary
byte names, zero/fractional viewports, live preference/density changes, direct
expression-name edits and caller-storage retirement. Existing media-query,
CSSOM, shadow-root, precision, owned-value and parse-retention cases pass too.

Tooling commit `8fd13f0fb` measures the public parsed-query evaluator, including
lookup, result checks, allocation and batched scratch scopes. Parsing, oracle
creation and warmup are excluded. Four alternating unprofiled trials retain
every observation, with separate execution diagnostics.

| Synthetic query component | Median observed instruction reduction |
| --- | ---: |
| Width queries | 34.256% |
| Early feature names | −1.818% |
| Preference queries | 33.403% |
| Resolution and ratio queries | 28.239% |
| Boolean queries across every supported name | 18.724% |

The first version regressed 2.979% on early-name queries. Preserving the hover
branch reduces that regression but does not eliminate it. Both cohorts and
their passing correctness matrices remain in verified archives; the regression
is not excluded from the report. These are synthetic query-evaluation costs,
not isolated classifier costs or whole-page savings, and do not advance the
broad-check cadence.

The [focused/component receipt](performance/chatgpt-media-feature-lookup-20261105.json)
links source/executable hashes, generated test calls, counters, checksums,
commands, memory guards and verified archives. The production comparison
below uses the existing original-script SOCKS capture and unchanged references.


## November 5: media-feature lookup production comparison

The completed 33-unit parallel bundle supplies final source proof for the
lookup, original name chain and enum definition. Its before/after aggregate
build-input hashes match; the three owned/dependency blobs match the recorded
Git head. Available feature/caller disassembly is retained, without a sealed-C
claim. A nonblocking shared publication lease pins canonical executable
`9a2431f805058be888099948b5299edebb507a36db306d4eb2703eeef9ded69e`.
No app is copied or separate production build requested.

All **12 fresh captures pass bootstrap, complete content and exact unchanged
pixels**. The separate diagnostic marker confirms entry into the candidate
lookup only when enabled; individual name/enum branch counts are not collected.
Matched captures disable diagnostics and retain the original chain as control.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Name-chain control 1 | 29,772,715,411 |
| Dispatch candidate 1 | 29,718,826,655 |
| Dispatch candidate 2 | 29,890,442,132 |
| Name-chain control 2 | 29,792,562,184 |
| Control median | 29,782,638,797.5 |
| Candidate median | 29,804,634,393.5 |

The candidate median is **0.074% higher**. The ranges overlap, with conservative
separation **−117,726,721 instructions**. Therefore **no whole-page saving is
credited**, no broad checkpoint is triggered and the cadence stays at zero.
Both candidates are retained, including the one that regresses against both
controls. Component gains and their early-name regression remain separate.

Control frame checkpoints are 472/466 versus 458/452 for candidates. One-minute
host load ranges from 10.85 to 15.66 on 18 CPUs. The four Brave reference
intervals span 16,187,500,778 to 19,233,554,705 observed instructions. Variation,
only two observations per variant and four total pairs limit attribution and
fall short of seven-pair acceptance. **The requested 5% advantage over Brave
remains unmet**.

The original frozen SOCKS capture, author scripts and pixel/content references,
fresh private profiles/caches, five-second unfocused settle, 1024×768 viewport,
scale 2 and exclusive-coalition creation-through-encoded-document-PNG scope
remain unchanged. OS filesystem/shader caches are retained; GPU and services
outside the coalition are excluded. This establishes no live-site,
isolated-rendering or scrolling improvement. The outer guard exits zero,
adopts 43 process identities without error and peaks at 1,763,131,392 sampled
RSS bytes under 12 GiB. Both phase controllers exit zero; their comparison
driver's separate exit one records the unmet Brave gate.

The [completed production receipt](performance/chatgpt-media-feature-lookup-production-20261105.json)
links raw counters, audits, PNGs, source proof, host conditions, commands,
actual exits and five verified archives. Every component and page observation
is retained. The publication lease is released; **no 5%-below-Brave acceptance
is claimed**.


## November 5: one snapshot and scan for animation property changes

Commit `566c5cb96` takes one owned snapshot of the current animated-property
map and scans the old/new union once for invalidation, compositor eligibility
and local/background paint classification. Previously the callback cloned the
current map three times and repeated overlapping value comparisons. Public
snapshot callers still receive independent maps, and no map/sample reference
escapes in the new result. Custom-property handling, sample retirement and
subsequent descendant/style updates retain their existing ownership rules.

The three original classifiers are byte-identical and remain the control via
`VOX_RETAIN_SEPARATE_ANIMATION_CHANGE_SCANS=1`.
`VOX_ANIMATION_CHANGE_SCAN_DIAGNOSTICS=1` reports an executed nonempty candidate
scan once. All **12 final focused jobs pass**, with **376 test-function
executions**: 47 cases × four allocation/check modes × two variants. The matrix
covers every longhand's addition/change/removal, non-longhand and added-key
classification, mixed insertion orders, public snapshot isolation, inherited
values, compositor behavior and sample-arena retirement/projection. Both
variants run with poisoned preallocation, ordinary GC, no GC and ASan/UBSan.

Tooling commit `ed8c5e961` measures 128 deterministic animation/style updates
on 64 targets. Each counted update checks five computed properties against an
ordinary-storage reference frame. Setup, reference construction, layout, paint
and teardown are excluded; updates, snapshot/scanning work and value checks are
included. Four unprofiled control/candidate/candidate/control runs retain every
observation, with separate execution diagnostics.

| Animation/style component | Median observed instruction reduction |
| --- | ---: |
| Opacity and transform | 3.539% |
| Inherited color | 0.756% |
| Mixed layout and paint properties | 2.445% |
| Unchanged opacity | 2.262% |

The separate correctness preflight and its raw counts are retained outside
that prescribed comparison: it lacked before/after fingerprints and a
host-before receipt. Component gains establish no page or Brave result.

### Correcting the focused test runtime

The first poisoning run faults in V's closure live directory. It omitted the
explicit staged-runtime module search path, so the compiler used its default
closure runtime. The unchanged standalone
`platform/closure_metadata_arena_test.v` independently reproduces the same
poisoned-directory failure without this optimization. The corrected command
uses the production overlay path; that standalone probe and the entire final
matrix pass. Generated-C initialization/lock excerpts confirm the metadata
arena hooks in the corrected tests and their absence in the first binary.
The component's module path and metadata globals confirm the overlay helper.
The staged runtime manifest and all its owned-file hashes also verify exactly.

The production build already uses this overlay. This is a test-configuration
correction, with **no engine/runtime change or instruction credit**. Earlier
commands in this log that omitted the module search path identify compiler
bytes but do not establish use of the production closure overlay. Historical
raw results are preserved; no prior result is silently rewritten.

The [focused/component receipt](performance/chatgpt-animation-change-scan-20261105.json)
links source/executable hashes, all 376 generated test calls, both closure
probes and their actual exits, the failed initial matrix, counters, checksums,
commands, guards and the verified archive. No whole-page saving is credited by
this component evidence, and the broad-check cadence remains unchanged.


## November 5: animation change-scan production comparison

The first standalone source check stops before launching a browser because a
concurrent `RuleCache` field addition changes a dependency file. An intended
harness edit does not match the spaced source list; the first guarded controller
therefore rejects the same overbroad preflight, also with zero browsers. Both
records and the incorrect harness are retained. The corrected controller proves
the two owned feature blobs at the completed receipt head, checks the snapshot/
invalidation functions against current text, and archives the receipt-head
dependency as a **reference, not a sealed copy of a dirty dependency**. Unrelated
RuleCache work receives no validation credit.

The valid cohort pins 33-unit parallel executable
`9078cb555e014f8651a73ef59b2219fc924b41bc0adcc12b901908cb7f4c2ad6`
with a nonblocking shared publication lease. Before/after aggregate build-input
hashes match, and available scan/callback disassembly is retained. There is no
sealed-C claim. All **12 fresh captures pass bootstrap, complete content and
exact unchanged pixels**. A separate nonempty-scan marker appears only in the
candidate; matched captures disable diagnostics. Both variants use the same
production runtime overlay, so the focused-test correction gets no credit.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Separate-scan control 1 | 30,126,652,599 |
| Single-scan candidate 1 | 29,982,530,837 |
| Single-scan candidate 2 | 28,789,416,597 |
| Separate-scan control 2 | 29,610,304,198 |
| Control median | 29,868,478,398.5 |
| Candidate median | 29,385,973,717 |

The candidate median is **1.615% lower**, but ranges overlap substantially:
the conservative separation is **−372,226,639 instructions**. Therefore **no
whole-page saving is credited**, no broad checkpoint is triggered and the
cadence remains zero. Every sample is retained, including the first candidate
that exceeds the second control. The component result remains separate.

Control frame checkpoints are 476/479 versus 473/479 for candidates. One-minute
host load ranges from 20.81 to 24.81 on 18 CPUs. The four Brave reference
intervals span 16,215,913,246 to 17,001,783,414 observed instructions. Variation,
only two observations per variant and four total pairs limit attribution and
fall short of seven-pair acceptance. **The requested 5% advantage remains unmet**.

The original SOCKS fixture, author scripts and pixel/content references,
fresh private profiles/caches, five-second unfocused settle, 1024×768 viewport,
scale 2 and exclusive-coalition creation-through-encoded-document-PNG scope
remain unchanged. OS filesystem/shader caches remain retained; GPU and
outside-coalition services are excluded. No live-site, isolated-rendering or
scrolling improvement is established. The outer guard exits zero, adopts 42
process identities without error and peaks at 1,737,506,816 sampled RSS bytes
under 12 GiB. Both phase controllers exit zero; the comparison driver's
separate exit one records the unmet Brave gate.

The [completed production receipt](performance/chatgpt-animation-change-scan-production-20261105.json)
links counters, audits, PNGs, source proofs, host conditions, commands, actual
exits and four verified archives. It preserves the failed preflights, test-runtime
mismatch and independent closure probes. No app is copied or duplicate build
queued. The publication lease is released; **no 5%-below-Brave acceptance is
claimed**.


## November 5: direct matrix field multiplication

Commit `4073ac8c1` replaces indexed `FloatMatrix4x4` multiplication with sixteen
direct field dot products. Each preserves the original zero-initialized,
left-to-right accumulation, including zero terms. It introduces no identity or
affine shortcut and no floating-point reassociation. The original accessor
loop is byte-identical apart from its method name and remains the control via
`VOX_RETAIN_ACCESSOR_MATRIX_MULTIPLY=1`. The diagnostic flag
`VOX_MATRIX_MULTIPLY_DIAGNOSTICS=1` reports the executed candidate once.

All **15 focused arithmetic jobs pass**, with **40 test-function executions**:
four cases × five modes × both variants. The cases cover noncommuting
transforms, all 256 basis pairs, 1,024 randomized finite/raw-bit matrix pairs,
signed zero, subnormals, infinities and NaNs, and no preallocation-arena growth.
Non-NaN results match the original loop bit for bit; NaN classification is
checked without claiming equal NaN payloads or floating-point exception flags.
The five modes include poisoned preallocation, ordinary GC, no GC, production
C `-O3`, and ASan/UBSan. Every compiler invocation uses the explicit production
runtime overlay, its 10 GiB compiler limit and a memory guard.

The complete wider CSS selection is retained and **does not pass**. Its 768
test-function calls have identical failure sets in both variants: the existing
geometry-provenance expectation and extrapolated-opacity expectation fail
under preallocation and sanitizers; opacity also fails under ordinary GC and
no GC. The initial failed selection and a separate accessor-control execution
are retained as well. No case is removed or weakened, and these failures are
not counted as passing arithmetic checks.

Tooling commit `f46fe400c` measures 32,768 products per scene through the public
method. Each counted product checks all sixteen results against the accessor
oracle. Fixture/oracle construction and warmup are excluded; a common
non-inlined wrapper, result checks and checksum remain included. Four
unprofiled control/candidate/candidate/control observations have matching
checksums, with two execution diagnostics kept separately.

| Matrix component | Median observed instruction reduction |
| --- | ---: |
| Identity | 2.976% |
| Affine | 3.224% |
| Perspective and rotation | 2.807% |
| Dense | 2.481% |
| Nonfinite | 2.525% |

The [focused/component receipt](performance/chatgpt-matrix-multiply-20261105.json)
links all raw jobs, failures, test-call counts, source/executable hashes,
counters, checksums and the verified archive. These are component results,
with **no whole-page instruction credit**. The broad-check cadence remains
zero. Browser validation requires a completed bundle whose source receipt
proves the final change; the original SOCKS capture, scripts and references
remain unchanged. **The 5%-below-Brave target remains unmet**.


## November 5: matrix multiplication production comparison

The initial available bundles contain a matrix diagnostic string, but their
recorded source heads do not match the owned feature files. No browser samples
are launched against them. A later shared build completes with identical
before/after aggregate build-input hashes and exact owned-source blobs at its
recorded head. The harness acquires a nonblocking shared publication lease on
33-unit parallel executable
`25c6fc5a0763e211baa538fe8746649a58381e25b62ab603e5dc1ee45b5e081e`.
Available multiplication/accessor disassembly is retained; no sealed-C claim
is made. No browser bundle is copied and no additional build is requested.

All **12 fresh production captures pass bootstrap, complete content and exact
unchanged pixels**. The direct-field marker appears only in the candidate
diagnostic. Matched captures disable diagnostics and retain the original
accessor loop as their control.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Accessor control 1 | 29,692,488,336 |
| Direct-field candidate 1 | 29,703,629,551 |
| Direct-field candidate 2 | 29,587,253,808 |
| Accessor control 2 | 29,421,808,702 |
| Control median | 29,557,148,519 |
| Candidate median | 29,645,441,679.5 |

The candidate median is **0.299% higher**. The observed ranges overlap, with a
conservative separation of **−281,820,849 instructions**. Therefore **no
whole-page saving is credited**, no broad checkpoint is triggered and the
cadence remains zero. Both candidates and controls remain retained; the
component reductions do not establish a whole-page improvement.

Control frame checkpoints are 420/360 versus 378/376 for candidates. One-minute
host load ranges from 19.80 to 71.23 on 18 CPUs. The four Brave reference
intervals span 16,395,030,859 to 17,237,823,506 observed instructions. Heavy
contention, varying frame work and only two samples per variant limit causal
attribution. Four total matched pairs fall short of seven-pair acceptance,
and **the requested 5% advantage over Brave remains unmet**.

The original SOCKS fixture, author scripts, content/pixel references, fresh
private profiles/caches, five-second unfocused settle, 1024×768 viewport,
scale 2 and exclusive-coalition creation-through-encoded-document-PNG scope
remain unchanged. OS filesystem/shader caches are retained; GPU and
outside-coalition services are excluded. The outer guard exits zero, adopts
47 process identities without error and peaks at 1,736,146,944 sampled RSS
bytes under 12 GiB. Both phase controllers exit zero; the comparison driver's
separate exit one records the unmet Brave gate. No live-site,
isolated-rendering or scrolling improvement is established.

The [completed production receipt](performance/chatgpt-matrix-multiply-production-20261105.json)
links all raw counters, audits, PNGs, source proofs, commands, actual exits and
four verified archives. It retains the unavailable source-proof checks and
the wider CSS provenance/opacity failures in both variants; **no overall CSS
suite pass is claimed**. The publication lease is released. This result earns
no page instruction credit or 5%-below-Brave acceptance.


## November 5: refreshed production-condition profile

A fresh standalone V `-profile` executable uses the current canonical source,
`-prod`, the explicit production runtime module overlay and C `-O1` with the
generated LTO flags. It retains the main-thread TLS profiling gate and
thirty-second diagnostic settle. Source sealing succeeds before compilation;
generated and preprocessed C are preserved. Later repository changes are
recorded separately and do not alter those sealed inputs. The build, signing
and memory guard exit zero, with 8,808,333,312 bytes peak sampled RSS under
12 GiB. The signed executable SHA-256 is
`a16878db7d45e6b32cc355728b462d461a1680e3ac1d3256b06ba82d51a50889`.

The fresh process passes JavaScriptCore bootstrap, the complete content/button
audit and every unchanged reference pixel. Browser and guard exit zero; the
guard adopts the browser identity and peaks at 1,819,869,184 sampled RSS bytes.
All input fingerprints remain unchanged throughout capture. One-minute host
load falls from 8.48 to 7.08 on 18 CPUs. There are **11,421 unique profile rows
and no negative self times**.

The profile records 481 preload/display-eligibility calls, 3,862 animation
retirement element inspections and 6,414 property computations. These remain
investigation leads. Recursive inclusive intervals overlap, self intervals
include native/JSC work and waits, and instrumentation and C optimization
settings change the workload. In particular, high counts for array/string
accessors do not establish that those calls survive production inlining.
The standalone executable also uses an adblock self-worker fallback rather
than the canonical minimal helper. No engine instruction saving is assigned
from this profile.

The [refreshed profile receipt](performance/chatgpt-v-profile-refresh-20261105.json)
links the raw rows, audits, PNGs, commands, actual exits, guarded source seal,
generated/preprocessed C and verified evidence archive. Native libraries and
sealed link objects are identified by hashes; no app bundle or source tree is
copied. The original disk-only SOCKS replay and author scripts are retained,
with no new download. Thirty seconds applies only to this instrumented
diagnostic; the unprofiled five-second protocol and references remain unchanged.
Instruction credit stays zero, the broad cadence stays zero and **the requested
5% advantage over Brave remains unmet**.

After archive verification, a separate guarded cleanup removes only this job's
redundant generated and preprocessed main C files. Their exact bytes remain
recoverable from the 58,110,030-byte lossless archive. The source-storage receipt
records each removed hash and requires restoration before recompiling or
rerunning the frozen-source validator. The signed diagnostic, canonical bundle,
raw measurements and original fixture remain in place.


## November 5: reuse of clean computed styles during retirement

Commit `2e547acea` adds a bounded 256-slot memo for complete clean root
`ComputedProperties` inspections. The live element and its last-applied layout
snapshot often share that owner. Reusing its completed result avoids repeating
the struct, property, layout-cache and projection checks. Address collisions
fall back to scanning. Recursive projections retain the original depth limit;
only a fully scanned root enters the memo. The memo lives inside one existing
temporary inspection scope and is discarded before returning, so later
mutations at the same addresses are rescanned.

`VOX_RETAIN_ANIMATION_SAMPLE_COMPUTED_SCAN=1` retains the full root scan;
the previous property-page memo remains enabled in both modes.
`VOX_ANIMATION_SAMPLE_COMPUTED_DIAGNOSTICS=1` reports an actual reuse once.
All **12 focused jobs pass**, covering **416 test-function executions**:
52 cases × four modes × both variants. The modes are poisoned preallocation,
ordinary GC, no GC and ASan/UBSan; preallocation-specific assertions run in the
preallocation/sanitizer builds. The new cases force memo coverage in either
environment and check collisions, mutable payloads between inspections,
root-only caching, projection depth/cycles and caller-arena lifetime. Existing
selected cases exercise the environment-selected paths and retained sample
pages, typed values, density projections, inherited and custom properties.
All compiles use the explicit production runtime overlay, 10 GiB compiler
limits and guards; runtimes use 3 GiB guards.

Tooling commit `f943f703a` measures 128 actual retirement inspections per
scene with live DOM styles and applied layout owners. A separate nonmemoizing
oracle verifies each scene before counting. Setup, the oracle and warmup are
excluded; scan allocation, temporary lifetime and result checks are included.
Four unprofiled control/candidate/candidate/control observations retain all
results, with execution diagnostics kept separately.

| Retirement component | Median observed instruction reduction |
| --- | ---: |
| Shared live/applied owners | 41.897% |
| Repeated targets | 82.646% |
| Live-only owners | −0.438% |
| First target holds a sample | 0.087% |
| Last applied owner holds a sample | 41.394% |

The live-only regression remains retained. Both modes use the extended scan
record, including its extra bounded 2 KiB memo, so this algorithm control on
one executable is not an older-binary memory comparison. The benchmark source
is renamed without content changes after compilation and before measurement
to keep it outside ordinary test discovery; that receipt and the original
generated assertion locations are retained.

The [focused/component receipt](performance/chatgpt-animation-computed-scan-20261105.json)
links all commands, actual exits, raw counters, checksums, generated test-call
lists, source hashes and the verified archive. It establishes no whole-page,
overall CSS-suite, live-site, scrolling or Brave result. No page instructions
are credited and the broad cadence stays zero. The browser comparison awaits
a completed bundle proving the final source. **The 5%-below-Brave target remains
unmet**.


## November 5: computed-style memo rejected and reverted

The first production diagnostic confirms a candidate reuse and exact
content/pixels. Its final control launch is stopped by the unchanged ownership
audit: an independent new Vox window for `https://vlang.io/` appears outside
the capture's resource coalition. That attempt remains rejected, with all four
observations retained and zero instruction credit. No missing helper is
silently excluded or added to the count.

A later standalone cohort uses fresh processes/profiles and the unchanged
ownership checks after that external launch. It pins 33-unit parallel executable
`01ba55f53219901430ef3478f3661a69e7837c85ec0588c8db8aadfa235401f4`.
Exact owned-source blobs at a recorded receipt head, stable aggregate build
inputs and available scan disassembly verify the code; there is no sealed-C
claim. All twelve captures in this complete cohort pass bootstrap, complete
content and exact unchanged pixels. Separate diagnostics confirm reuse only
in the candidate; matched captures disable diagnostics. The rejected first
attempt is not pooled into these observations.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Full-root-scan control 1 | 29,104,997,099 |
| Clean-style memo candidate 1 | 29,874,670,960 |
| Clean-style memo candidate 2 | 30,532,235,947 |
| Full-root-scan control 2 | 29,111,159,071 |
| Control median | 29,108,078,085 |
| Candidate median | 30,203,453,453.5 |

The candidate median is **3.763% higher**, with both candidates exceeding both
controls. Conservative separation is **−1,427,238,848 instructions**. The
component gains do not justify retaining this page regression. No whole-page
credit or broad checkpoint follows; the cadence remains zero. Control frame
checkpoints are 479/482 versus 452/452 for candidates, and one-minute host load
ranges from 7.15 to 8.29 on 18 CPUs. The four Brave reference intervals span
18,669,631,228 to 19,658,003,181 observed instructions. Only two observations
per variant and four matched pairs limit attribution and fall short of
seven-pair acceptance. No 5%-below-Brave result is claimed.

Commit `cf8124f26` **reverts the memo and its internal benchmark**. Both engine
files are byte-identical to before the experiment; the prototype, its focused
tests and measurements remain in linear history and durable archives. All
eight rollback jobs pass, with 188 test-function executions across poisoned
preallocation, ordinary GC, no GC and ASan/UBSan. Preallocation-only ownership
assertions remain conditional in the other modes.

A fresh completed rollback bundle
`ccefa34b26745cef0c79af04d915b5f9bb0b5ee019488dba531d7488fcdcfb9d`
proves the restored source at its verified receipt head. A fresh Vox/Brave pair
passes bootstrap, full content and exact pixels. The removed memo's flag and
execution string are absent from the image. This validates restored rendering
only, with no new performance credit. Its guard exits zero and adopts seven
process identities without error.

The [complete experiment receipt](performance/chatgpt-animation-computed-scan-production-20261105.json)
links both cohorts, raw counters, audits, PNGs, commands, actual exits and six
verified archives. The [rollback checks](performance/chatgpt-animation-computed-scan-rollback-20261105.json)
and [rollback production validation](performance/chatgpt-animation-computed-scan-rollback-production-20261105.json)
preserve their separate evidence. A postprocessor initially read the retained
first-cohort paths; that metadata-only error is recorded and corrected before
the final statistics, without changing any capture or counter.

Every run keeps the original SOCKS fixture and author scripts, unchanged
references, fresh private profiles/caches, five-second unfocused settle,
1024×768 viewport, scale 2 and exclusive-coalition creation-through-encoded-PNG
scope. OS filesystem/shader caches are retained; GPU and outside-coalition
services are excluded. No app bundle is copied or extra build requested.
Publication leases are released. **The requested 5% advantage remains unmet**;
this experiment is not an optimized-site entry or a live-site, isolated-rendering
or scrolling improvement.


## November 5: current optimized C profile

Commit `230673dc5` fixes the diagnostic entry injector for current V's tab
indentation before `_vinit()`. Twelve Python tests pass, including preservation
of every other source byte across spaces, tabs and CRLF, and rejection of
missing or duplicate initialization boundaries. The initial attempt generates
C but stops at that boundary before native compilation or any browser launch;
its raw generated source, command, log and failed guard remain archived.

A later diagnostic regenerates current canonical source with `-prod` and the
explicit production runtime module overlay, seals its compiler inputs, and
compiles with C `-O3`, inlining threshold 1500 and Clang's instrumentation after
inlining. Its one generated C unit with ThinLTO differs from the canonical
33-unit layout, so it supplies diagnostic leads only. No app bundle or source
tree is copied. The main-thread gate starts after module initialization;
helpers compile separately without instrumentation.

Build, signing, browser and guards exit zero. The thirty-second frozen-page
capture passes JavaScriptCore bootstrap, complete content/button identity and
every unchanged reference pixel. All runtime input fingerprints stay stable.
There are **3,496 resolved function rows, no unresolved functions and zero
profiler faults**. Three open frames are explicitly closed and marked partial
at shutdown. Native waits and profiling overhead enter self time, and recursive
inclusive intervals overlap. The standalone adblock self-worker fallback also
differs from the canonical minimal helper.

The profile records 112,480 keyframe-value computations and 3,195,930 general
map writes. These identify temporary keyframe lookup construction for further
measurement; they establish no savings. The 26.12-second `sapp_run` self
interval includes idle waits and must not be treated as CPU work. Thirty seconds
applies only to this diagnostic; the unprofiled five-second protocol, original
SOCKS fixture, author scripts and references remain unchanged.

The [current optimized profile receipt](performance/chatgpt-current-c-profile-20261105.json)
links raw rows, source seals, generated/preprocessed C, commands, actual exits,
guards, the initial failed attempt and three verified archives. Its generated
source duplicates and eight completed test-source duplicates are removed only
after individual lossless-archive verification. The combined storage receipts
account for 711,784,647 removed raw bytes; all exact source bytes remain
recoverable. Executables, native inputs, audits, PNGs, canonical app/source and
the original fixture remain in place. No instruction credit or broad checkpoint
is assigned, and **the requested 5% advantage over Brave remains unmet**.


## November 5: ordered keyframe property unions

Commit `6cec4f7e3` replaces a temporary bool-map union with an ordered
property-ID vector during keyframe-value computation. Explicit keys come
first, followed by initial-value keys absent from the explicit map. The bool
payload does not affect presence. Specified/computed value resolution,
substitution, keyword handling and physical/logical alias overwrite order stay
on the existing path. There is no cross-frame cache or new invalidation rule.

The original function is byte-identical apart from its name and remains the
control via `VOX_RETAIN_KEYFRAME_ID_UNION_MAP=1`.
`VOX_KEYFRAME_ID_UNION_DIAGNOSTICS=1` reports an executed nonempty vector path
once. All **12 final focused jobs pass**, with **408 test-function executions**:
51 cases × four modes × both variants. These cover union order, false-valued
initial keys, explicit duplicates, shorthand IDs, live input-map changes,
independent vectors, temporary storage lifetime, substitutions, inheritance,
relative fonts and logical-alias collisions in horizontal/vertical writing
modes. Existing selected cases retain the animation sample ownership guards.
Modes include poisoned preallocation, ordinary GC, no GC and ASan/UBSan, with
preallocation-specific assertions conditional in the other modes. Every
compile uses the explicit production runtime overlay, 10 GiB compiler limit
and memory guard; runtimes use 3 GiB guards. The first fixture uses a nonexistent
enum name and fails compilation before executing any test; its log is retained.

The unchanged, pinned animation/style component tool from `ed8c5e961` checks
five computed properties on 64 targets during each of 128 updates against
ordinary-storage frames. Fixture/reference construction, layout, paint and
teardown are excluded; updates and result checks are counted. Four unprofiled
control/candidate/candidate/control observations have equal checksums, with
execution diagnostics kept separately.

| Animation/style component | Median observed instruction reduction |
| --- | ---: |
| Opacity and transform | 2.391% |
| Inherited color | −0.265% |
| Mixed layout and paint properties | 3.147% |
| Unchanged opacity | 1.573% |

The inherited-color regression remains retained. The
[focused/component receipt](performance/chatgpt-keyframe-union-20261105.json)
links all commands, actual exits, test-call counts, raw counters, source hashes,
checksums and the verified archive. This establishes no whole-page or overall
CSS-suite pass. Browser attribution still requires a completed bundle proving
the final source, an executed-path diagnostic and unprofiled comparison.
Page instruction credit and the broad cadence remain zero; **the requested
5% advantage remains unmet**.


## November 5: keyframe-union production comparison

The shared build first supersedes a compilation whose aggregate source inputs
change. A later completed 33-unit parallel bundle contains exact owned-source
blobs at its recorded head with stable aggregate build inputs. The harness pins
executable `a7182e18afe3dc48049af878dc9ab78951e2a1e26f07b5a19f5b17b17f812698`
with a nonblocking publication lease and retains available function disassembly;
no sealed-C claim is made for this production bundle.

All **12 fresh captures pass bootstrap, complete content and exact unchanged
pixels**. Separate diagnostics confirm the ordered-vector path executes only
in the candidate. Matched captures disable diagnostics and retain the original
map-union function as their control.

| Unprofiled frozen-page variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Map-union control 1 | 30,148,694,411 |
| Ordered-vector candidate 1 | 29,961,008,966 |
| Ordered-vector candidate 2 | 30,512,891,249 |
| Map-union control 2 | 30,318,805,723 |
| Control median | 30,233,750,067 |
| Candidate median | 30,236,950,107.5 |

The candidate median is **0.0106% higher**, with overlapping ranges and
conservative separation of **−364,196,838 instructions**. Therefore **no
whole-page saving is credited**, no broad checkpoint is triggered and the
cadence remains zero. The first candidate's reduction and second candidate's
regression both remain retained. Component gains and the inherited-color
regression remain separate from this page result.

Control frame checkpoints are 427/425 versus 440/445 for candidates. One-minute
host load ranges from 14.97 to 22.62 on 18 CPUs. The four Brave reference
intervals span 16,476,347,924 to 19,503,680,438 observed instructions. Variation,
different completed frame work, only two observations per variant and four
total matched pairs limit attribution and fall short of seven-pair acceptance.
**The requested 5% advantage over Brave remains unmet**.

The original SOCKS fixture, author scripts and content/pixel references,
fresh private profiles/caches, five-second unfocused settle, 1024×768 viewport,
scale 2 and exclusive-coalition creation-through-encoded-document-PNG scope
remain unchanged. OS filesystem/shader caches are retained; GPU and
outside-coalition services are excluded. The outer guard exits zero, adopts
42 process identities without error and peaks at 1,739,046,912 sampled RSS bytes
under 12 GiB. Both phase controllers exit zero; the comparison driver's separate
exit one records the unmet Brave gate. No live-site, isolated-rendering or
scrolling improvement is established.

The [completed production receipt](performance/chatgpt-keyframe-union-production-20261105.json)
links raw counters, audits, PNGs, source proofs, commands, host conditions,
actual exits and four verified archives. No app bundle is copied or duplicate
build requested, and the publication lease is released. No optimized-site
entry or 5%-below-Brave acceptance is claimed.

### Native counter attribution remains pending

An optional selected-function counter probe is attempted only after the
unprofiled cohort finishes. Restoring the archived C sources first runs out
of disk space. The exact full/prefix reconstruction files are verified against
the durable archive before removal, reclaiming 306,501,949 bytes; the originals
remain recoverable.

A separate archive-backed verifier passes five tests for changed existing
inputs, missing unlisted inputs, archive/blob/length mismatches and valid
missing-source authentication. It checks the same explicitly archived source
hashes without materializing duplicates, retaining every live linker-input
and library-resolution check. The subsequent probe rejects a changed shared
`libLadybirdVSkiaText.dylib` before launching any browser. It accepts no changed
library and produces no native function instruction counts. The earlier
elapsed-time profile remains valid for its own pinned inputs; it cannot fill
this attribution gap.

The [rejected counter-probe receipt](performance/chatgpt-native-counter-probe-rejected-20261105.json)
preserves both actual failed exits, the verifier tests, cleanup hashes and
source. No instruction credit, broad checkpoint or 5%-below-Brave claim follows.

### Byte-unit opacity compositing (2026-11-05)

The native profile's effect-layer lead prompted an exact CPU compositor change
in `e33f08b32`. Long nonunit-opacity spans reuse the original normalized alpha
coverage while computing RGB in byte units. An analytical error bound below
2^-14 byte levels permits the result only outside a wider 2^-10 exclusion
around half levels. Ambiguous blocks retain the original float32/FMA and
double-precision quantization; repeated ambiguity stops probing. Short spans,
scalar tails, unusual opacity values and nondefault rounding retain the old
arithmetic. Mutable diagnostic state uses `VOX_NATIVE_STATE`.

Five focused executions pass: optimized candidate/control, scalar-only, and
ASan/UBSan candidate/control. Each checks 134,217,728 exhaustive pixels,
2,103,144 additional large-span/alias pixels, tails, all rounding modes and
33,280 ink-bound comparisons against the unchanged independent oracle. Both
native SVG integration builds pass another 304 total scope, float-opacity GPU
and image/mask GPU comparisons. The first integration link failure exposed
the fixture's missing `-fno-rtti`; `5d5639bc5` corrects that harness separately.
The original failed commands remain retained.

`80dab8d51` adds a component benchmark with an independent scalar oracle.
Two unprofiled samples per mode, ordered control/candidate/candidate/control,
cover 2,097,152 pixels per scene. Median observed instruction reductions are
12.256% for mixed pixels, 7.469% for mixed empty/opaque spans and 3.389% for
opaque spans. Short spans regress 0.021%. The halfway fallback, unit-opacity
and empty controls also remain in the receipt; environment lookup overhead
and system work can affect these counts, so their reductions receive no
compositing credit. Two separate diagnostics establish branch execution;
all output checksums and exact oracle comparisons agree. The first benchmark
compile's unused-function warning is retained with the corrected command.

The [focused/component receipt](performance/chatgpt-byte-opacity-20261105.json)
links authenticated source, commands, raw counts, logs and memory guards.
These are component results. Production page validation is pending, the broad
cadence remains zero, and the 5%-below-Brave target remains unmet. The original
SOCKS capture, author scripts and pixel references are unchanged.

### Opacity refinement and production eligibility (2026-11-05)

The final compositor (`d5f611436`) admits spans from 32 pixels, caches its
process-start control policy in atomic shared native state, and leaves half
opacity on the original path. A widened prototype regressed repeated halfway
ties by 14.266% at 32 pixels; that full failed experiment and its exact source
remain retained. The final halfway control is essentially neutral, varying
by at most 0.007% across the measured widths.

Two unprofiled samples per mode at each of 32, 64, 128, 256 and 2048 pixels
show 10.968–11.997% lower mixed-pixel medians, 5.508–6.655% lower mixed
empty/opaque medians, and 1.779–2.723% lower opaque medians. Every output
matches the independent oracle. Unit-opacity negative-control reductions
receive no credit: its existing per-row environment lookup scans the extra
control flag. Five final focused executions also pass 512 concurrent
first-use/span-boundary comparisons each, alongside all previous exhaustive
checks. Both native integration builds pass with the identical final header.
The [refined component receipt](performance/chatgpt-byte-opacity-refined-20261105.json)
retains every prototype result, source hash, test and raw sample.

Both production attempts finish four valid captures apiece, passing complete
content/bootstrap audits and unchanged pixel checks. Neither candidate emits
the byte-opacity execution marker, despite its recorded launch environment
enabling diagnostics. The first long-span attempt uses executable
`19d7298d57c459d32684ed6761a9d3d9327923c88fb78278960eaf5fb22c3902`;
the final 33-unit production bundle is
`df6e738381e56ff1829e20e7ccb0ff5a195cf88e459101d8bd1f49e97671528d`,
with exact owned-header bytes at its recorded `494ae2fd1` source head.
Each cohort pins its own executable/native inputs with a nonblocking shared
publication lease; no app copy or manual production build is used. The first
attempt additionally authenticates its initially uncommitted header through
an identical aggregate-input receipt after that header is committed.

The eligibility gate rejects both attempts. No matched page comparison or
broad checkpoint follows, and no component gain is attributed to ChatGPT.
The [production receipt](performance/chatgpt-byte-opacity-production-20261105.json)
and [verification receipt](performance/chatgpt-byte-opacity-verification-20261105.json)
retain both actual nonzero controller exits, successful finalizers, adopted
browser memory accounting and six authenticated archives. The verification
checks all eight render captures and confirms the absent candidate markers.
Whole-page instruction credit and the broad cadence remain zero. The
5%-below-Brave target remains unmet; the original frozen SOCKS capture,
author scripts, settle period and references are unchanged.

### Optimized selected-function instruction diagnostic (2026-11-05)

A fresh selected-function diagnostic uses ordinary `-prod` V source conditions,
the explicit production runtime overlay, C `-O3` with inlining threshold 1500,
and a single generated C unit with ThinLTO. It remains distinct from the shared
33-unit production bundle. One nonblocking publication lease pins native
libraries across code generation, sealing, compilation and capture. No
production build, browser app copy or source-tree copy is requested.

The initial attempt runs out of disk space during preprocessing, then also
encounters ENOSPC while reporting and archiving the failure. It launches no
browser. A streaming archival follow-up verifies each complete generated or
partial preprocessing file against a durable gzip before removing its
duplicate, reclaiming 344,772,016 bytes. All failed commands and the first
incomplete archive remain preserved in the
[rejected-attempt receipt](performance/chatgpt-selected-native-profile-r1-rejected-20261105.json).

The second attempt compiles and captures successfully under the 12 GiB guard,
peaking at 9,272,672,256 sampled RSS bytes over 302.12 seconds. Its signed
executable is
`71316e5e1c63380dcbe9428ac934786fdb14345ef7656135f4bfacb3b3aadba5`.
The thirty-second frozen-page capture passes JSC bootstrap, the complete
content/button audit and every unchanged reference pixel. All runtime input
hashes remain stable; browser and guard exits are zero. Selected counters
record 64,822,160,774 process instructions with zero faults and one explicit
partial root frame.

| Selected self scope | Calls | Instrumented process instructions |
| --- | ---: | ---: |
| Animation style callback | 3,443 | 9,836,119,633 |
| Keyframe value computation | 114,650 | 9,613,578,846 |
| Document layout update | 6,910 | 8,894,694,618 |
| Module delivery | 288 | 8,812,667,606 |
| Preload/display eligibility | 518 | 4,902,838,828 |
| Native effect-layer completion | 156 | 3,180,481,447 |
| Rounded-rectangle native bridge | 103 | 694,147,899 |
| Contoured-box native bridge | 36 | 531,364,762 |

These are investigation leads. Counters include other process threads and
instrumentation; self subtracts only selected children, recursive inclusive
totals overlap, and module initialization precedes the gate. The standalone
adblock self-worker differs from production's minimal helper. Native elapsed
time also includes waits. No unprofiled speedup or Brave acceptance follows.
The [selected-profile receipt](performance/chatgpt-selected-native-profile-20261105.json)
retains source seals, raw rows, commands, actual exits, audits and PNGs.
It also authenticates 399,053,950 bytes of generated C/preprocessing output
before deleting the duplicates. Profile credit and the broad cadence remain
zero; the 5%-below-Brave target remains unmet.

### Context-free keyframe values (2026-11-05)

`099584b70` avoids building font, viewport and query-container computation
context for keyframe values whose computation cannot use it. It reuses the
cascade's existing resolved-scalar allowlist. Numeric/percentage opacity still
runs the original clamping/conversion algorithm. Constant transforms admit
only numbers, angles, percentages and pixel lengths. Other lengths,
calculations, contextual colors and special property algorithms retain the
full path and its dependency tracking. Substitutions, CSS-wide keywords and
logical aliases resolve before this shortcut. There is no endpoint cache or
additional retained owner; temporary lookup and result ownership are unchanged.

All 12 focused compile/runtime jobs pass. The generated runners authenticate
61 selected test calls per execution in candidate/control across ordinary GC,
no-GC, poisoned preallocation and ASan/UBSan: 488 function executions total.
Native arena assertions remain conditional in the other modes. Five new cases
cover scalar/transform equivalence, contextual rejection, opacity clamping,
substitutions, CSS-wide keywords, logical aliases, initial-key presence, live
mutations, viewport dependencies and retained values after scratch retirement.

The unchanged animation/style component benchmark checks five output properties
for 64 targets over 128 updates against ordinary-storage reference frames.
Two unprofiled observations per variant, control/candidate/candidate/control,
and two separate path diagnostics produce matching outputs and checksums.

| Component median | Control instructions | Candidate instructions | Reduction |
| --- | ---: | ---: | ---: |
| Opacity/transform | 220,434,159 | 170,162,066 | 22.806% |
| Inherited color | 2,984,512,840 | 2,985,797,466.5 | -0.043% |
| Mixed layout/paint | 298,737,597 | 285,458,498.5 | 4.445% |
| Unchanged opacity | 118,256,807.5 | 100,817,353.5 | 14.747% |

One early component-driver invocation started before compilation finished and
failed its executable preflight. It launches no sample and remains retained;
the subsequent cohort waits for the successful compile. The
[focused/component receipt](performance/chatgpt-keyframe-scalar-20261105.json)
authenticates every command, guard, raw count, generated runner and source.
It verifies the archived generated C before removing 61,837,680 duplicate bytes.
These component results receive no whole-page credit. The production comparison
below completes validation; the broad cadence remains zero and the
5%-below-Brave target remains unmet.

### Context-free keyframes: production comparison (2026-11-05)

The latest completed 33-unit production bundle contains the exact final sources
at its recorded `099584b70` head. Executable SHA-256 is
`02254e17c54bcee6b71f8f4d2d0f813f156cad0eade69c344c41863b6e864aa4`.
A nonblocking shared publication lease pins that executable and its native
inputs throughout four diagnostic and eight unprofiled captures. Candidate-only
execution markers establish that ChatGPT uses the shortcut. Every capture
passes bootstrap, the complete content/button audit, kernel/browser exits and
the unchanged pixel reference. The original single SOCKS capture and author
scripts are retained.

The matched order is control/candidate/candidate/control, each paired with a
fresh Brave reference. Scope remains exclusive-coalition creation through
encoded document PNG, including startup/window setup, with fresh private
profiles/caches, 1024×768 viewport, scale 2 and an unfocused five-second settle.
OS filesystem/shader caches are retained; GPU and outside-coalition services
are excluded.

| Unprofiled observed instructions | Control | Candidate |
| --- | ---: | ---: |
| First observation | 30,356,841,053 | 30,749,907,172 |
| Second observation | 30,091,508,057 | 29,842,790,436 |
| Median | 30,224,174,555 | 30,296,348,804 |

The candidate median is **0.239% higher**, with overlapping ranges. The
conservative separation is negative, -658,399,115 instructions, so no page
reduction is credited and no broad checkpoint is triggered. Controls complete
477 frame checkpoints each; candidates complete 476 and 489. One-minute host
load declines from 6.38 to 4.14 on 18 CPUs. These counts are retained without
normalizing the instruction endpoint by frame count or dropping the outlier.

The highest Vox observation divided by the lowest Brave lower bound is 1.7291,
far above the requested 0.95. Four pairs also remain below the seven-pair
acceptance minimum. The 5%-below-Brave target remains unmet.

The outer guard and controller exit zero over 110.69 seconds, peaking at
1,727,545,344 sampled RSS bytes with 44 adopted process identities and no
adoption error. Finalization and independent verification also exit zero.
The [production receipt](performance/chatgpt-keyframe-scalar-production-20261105.json)
links every raw observation, command, PNG, audit, source proof and guard.
The [verification receipt](performance/chatgpt-keyframe-scalar-production-verification-20261105.json)
authenticates all four archives, 488 focused calls, 12 valid captures, source
hashes, branch selection, exact median/separation arithmetic and the failing
integer Brave gate. Whole-page credit and broad cadence remain zero. No live
site, isolated rendering-time or scrolling improvement is claimed.

### Production JSC entry and native callback diagnostics (2026-11-05)

`88d37101d`, `53c55ddf7` and `9cd883093` add a separately injected,
opt-in diagnostic library. It records main-thread C API and Objective-C
entry scopes with current-process retired instructions. Public registration
APIs also wrap native callable callbacks, preserving receivers, arguments,
private data and exception identity. Selected labels come from native
constructor arguments; the probe never reads JavaScript `.name` getters or
author source text. Immutable wrapper slots hold original callbacks and labels,
without an object-address cache, extra JS root or private V-record ABI access.
Private Objective-C method encodings are checked before installing wrappers.
Caller addresses resolve through their actual `dladdr` image and Mach-O text
range; callback rows explicitly identify a function entry rather than a return
site. Background entries forward unchanged and do not enter the scope stack.

The final focused selection passes seven guarded jobs: both warning-clean
compiles, both signatures, baseline, inactive injection and active injection.
It verifies recursion, original exceptions, private data, UTF-16 metadata,
Unicode registration labels, a throwing `.name` getter, original observable
output, address ranges and complete scope retirement. Earlier rejected runs
are retained: syntax errors can be deferred until evaluation; injecting the
guard also injected Python; an Objective-C `out` qualifier needed ABI handling;
and JSC may supply a non-null argument pointer with zero arguments. None of
these failed checks supplies performance evidence.

Two independent production cohorts each capture the frozen page at five and
thirty seconds, using fresh canonical processes, the original SOCKS replay and
author scripts, private profiles/caches, 1024×768 viewport and scale 2. Both
cohorts acquire nonblocking shared publication leases and pin bundle, libraries,
probe and fixture identities throughout. All four captures exit normally and
pass bootstrap, full content/button identity and exact unchanged pixels.
No manual production build or app copy is used.

Entry-only probe: executable SHA-256
`8d0d0946f3a2939554782046edb7e73008ed47fa1ddb7b7e5f166322fd7c3a6a`,
33 C units.

| Settle | Process diagnostic instructions | Script factories | Native callable callbacks |
| --- | ---: | ---: | ---: |
| 5 s | 29,832,556,690 | 290 | unobserved |
| 30 s | 40,049,473,702 | 290 | unobserved |

Native-callback probe: executable SHA-256
`c9d2093c14326096351d04f7b00931de87f33b5adbaa6008ba294ed0ae0e75ec`,
33 C units.

| Settle | Process diagnostic instructions | Script factories | Native callable callbacks |
| --- | ---: | ---: | ---: |
| 5 s | 39,681,181,054 | 289 | 232374 |
| 30 s | 49,721,766,676 | 289 | 232433 |

Script factories use about 9 million observed instructions per capture;
compilation can be deferred into evaluation, so this does not establish total
parse/compile cost. Module delivery enters large synchronous JSC work scopes.
With callback observation enabled, the five-second capture records 232,374
native callable invocations. Their self scopes total 11.33 billion instructions,
including observer cost; generic string/value host trampolines dominate these
rows. Named selector wrappers contribute a small part. These are leads for
investigation, not isolated VM or native engine costs.

The callback probe substantially increases process work at this call volume.
The cohorts use different pinned builds and instrumentation and must not be
compared as a speedup. Current-process counts include concurrent threads;
self subtracts only observed nested scopes and leaves unobserved native
property callbacks in their parent. Inclusive totals overlap. Constructor-to-
atexit process counts differ from the exclusive-coalition capture endpoint;
neither profile supplies unprofiled optimization or Brave acceptance credit.
The entry and callback guards exit zero, adopt both browser PIDs, and peak at
1,672,642,560 and 1,678,229,504 sampled RSS bytes respectively under 3 GiB.

The [entry receipt](performance/chatgpt-jsc-entry-profile-20261105.json),
[callback receipt](performance/chatgpt-jsc-native-profile-20261105.json) and
[verification receipt](performance/chatgpt-jsc-probe-verification-20261105.json)
authenticate raw rows, all development attempts, source revisions, commands,
guards, original PNGs and audits in content-addressed ZIP archives. Whole-page
credit and the broad cadence remain zero. The 5%-below-Brave target remains
unmet; no live-site, rendering-time or scrolling improvement is claimed.

### Bounded stack storage for JSC string conversion (2026-11-05)

`a91326b15` avoids a temporary heap array when JavaScriptCore reports that a
string's maximum UTF-8 C-string capacity fits in 256 bytes. JSC writes into a
fixed stack buffer; the exact result is copied into the caller's allocation
owner before returning. Longer strings retain the old heap-array conversion.
The returned string has no stack dependency or extra retained capacity.
ToString ordering, original conversion failures, embedded NULs and JSC's
Unicode handling are unchanged. There is no retained cache or JS root.

All 12 final focused compile/runtime jobs pass. Generated runners authenticate
30 selected test calls in candidate/control under ordinary GC, no-GC, poisoned
preallocation and ASan/UBSan: 240 function executions. Three new cases compare
every UTF-16 unit, empty and large values, NULs, surrogates and the 85/86-unit
capacity boundary against an independent copy of the old path. They also verify
results after stack reuse and context release and the caller-arena allocation.
Existing native ABI, raw-value, coercion/reentry, temporary input/reply and
exception ownership tests pass in the same selection. Generated C confirms
`u8 buffer[256]` on the stack and a cloned result before `JSStringRelease`.

An earlier broader selection failed `runtime_json_test.v:63`: script depth is
2 where the test expects 1. The same executable with the original heap control
fails identically. Both failures are retained; this unrelated test was omitted
from the final focused selection without changing its assertion.

The unprofiled component uses one executable with production source conditions,
C O3 and poisoned preallocation. Setup/teardown are excluded; each measured
conversion compares every output byte and contributes to an invariant checksum.
Two observations per variant run control/candidate/candidate/control, followed
by separate path diagnostics. Small scenes use 20,000 conversions and the long
fallback uses 2,000. This single-C-unit component differs from the parallel
production browser and receives no page credit.

| Component median | Control instructions | Candidate instructions | Reduction |
| --- | ---: | ---: | ---: |
| empty | 19,961,230.5 | 16,360,325.0 | 18.0395% |
| short-ascii | 39,726,360.5 | 36,056,200.5 | 9.2386% |
| query-envelope | 56,312,982.0 | 51,015,553.5 | 9.4071% |
| nul-unicode | 40,353,785.0 | 36,602,731.5 | 9.2954% |
| inline-boundary | 60,253,442.5 | 54,650,077.5 | 9.2997% |
| heap-boundary | 60,843,411.0 | 60,804,674.5 | 0.0637% |
| long-fallback | 170,637,753.0 | 170,642,038.0 | -0.0025% |

The heap-boundary ranges overlap; the long fallback has a 0.0025% higher median.
Neither is represented as an improvement. The
[focused/component receipt](performance/chatgpt-jsc-string-buffer-20261105.json)
links all raw counts, failed selections, commands, guards, source and generated
runners. Its content-addressed archive is fully verified before removing
294,114,785 bytes of redundant generated C from Build. Whole-page credit and
the broad cadence remain zero pending the production comparison below. The
5%-below-Brave target remains unmet.

### JSC stack conversion: production path and rejected comparison (2026-11-05)

The completed 33-unit production executable has SHA-256
`55161b147ee98fa38d061a01f8a95bdb7ec999e02211f41f129783c89208b14a`.
A nonblocking shared publication lease keeps its executable and native inputs
stable through the separate path diagnostic and attempted four-pair comparison.
The source receipt matches the exact final owned blobs at `a91326b15`.
ThinLTO inlines the conversion helper, so its enclosing function disassembly is
joined to Mach-O import stub addresses for both JSC string conversion APIs.
The two rejected source preflights are retained: the first required an absent
inlined symbol; the second expected imported function names in an objdump view
that printed numeric stub addresses. Neither attempt launches a browser.

All four diagnostic captures pass bootstrap, complete content/button identity,
unchanged pixels and normal exits. The stack-copy marker appears only in the
candidate Vox process. This establishes that the final production code executes
on the original frozen page. The subsequent unprofiled cohort is incomplete:

| Attempted pair | Variant | Observed Vox instructions | Observed Brave interval |
| --- | --- | ---: | ---: |
| 1 | Control | 30,009,849,443 | 19,245,343,734–19,264,343,483 |
| 2 | Candidate | 29,968,283,759 | 19,137,299,578–19,199,059,460 |
| 3 | Candidate | 30,502,945,091 | Rejected ownership audit |
| 4 | Control | Not launched | Not launched |

The third Brave capture rejects with `A private browser helper is outside its
resource coalition`. Its raw ownership receipt identifies renderer PID 3735
with another private profile and parent 3716; it exits before identity
rechecking. That suggests concurrent benchmark churn, but its final identity
cannot be established. The original ownership gate remains unchanged and the
sample is neither replaced nor excluded to obtain a result. Three Vox and two
Brave observations before rejection pass all render/content/exit checks, in
addition to the four path diagnostics: nine valid captures over ten attempts.
The partial Vox samples also overlap. No complete-cohort median, conservative
saving, Brave ratio or acceptance result is assigned.

Scope remains exclusive-coalition creation through encoded document PNG,
including startup and window/target setup, original SOCKS replay and author
scripts, fresh private profiles/caches, 1024×768 viewport, scale 2, an unfocused
five-second settle, retained OS filesystem/shader caches, and excluded GPU and
outside-coalition services. All inputs remain pinned; the controller/guard exit
1 for the ownership rejection after 99.50 seconds, peaking at 1,707,638,784
sampled RSS bytes with 39 adopted identities and no adoption error. The
publication lease is released. No manual production build or app copy is used.

The [production receipt](performance/chatgpt-jsc-string-buffer-production-20261105.json)
and [verification receipt](performance/chatgpt-jsc-string-buffer-production-verification-20261105.json)
authenticate four archives, every raw attempt, source proof, command, actual
exit, counter, original PNG and content audit. Finalization and independent
verification exit zero; production comparison status remains rejected.
Whole-page credit and the broad cadence stay at zero, so no broad checkpoint
is due. The 5%-below-Brave goal remains unmet. The component gain is not a
live-site, isolated rendering or scrolling claim.

### Current production stack sampling (2026-11-05)

A fresh canonical 33-unit executable, SHA-256
`1a354e7f5f3e54dbf9e84e6f3d2943ed5ca5fd3a7e712aaa4b0b49374ec7ac61`,
is sampled through macOS `/usr/bin/sample` under a nonblocking shared publication
lease. The first requested five-second sample starts immediately after launch;
the second starts ten seconds after launch. Both request 1 ms sampling cadence.
These are sampling diagnostics, not instruction or timing acceptance. They
include idle and worker threads, recursive stack counts and unsymbolized JIT
frames; no sampled percentage is assigned to engine instruction cost.

The early sample still shows substantial nested grid/flex layout work. The
settled sample mostly waits in the main event loop, with animation keyframe
substitution, calculation parsing and compositor style refresh among the active
stacks. This supports investigating calculation parsing without assuming that
the older profile's preload visibility cost remains representative after the
SVG device-layout changes. No visibility policy is changed by this diagnostic.

The original SOCKS fixture, author scripts, private profiles/caches, 1024×768
viewport, scale 2 and unfocused window are retained. The separate diagnostic
capture uses a thirty-second settle and passes bootstrap, complete content and
button identity, exact unchanged pixels, normal exit and all input hash checks.
Both sampler commands exit zero. The outer controller/guard exit zero over
32.04 seconds, adopt the actual browser PID and peak at 1,759,608,832 sampled RSS
bytes under 3 GiB. Host one-minute load is about 7.3 on 18 CPUs. Sampling changes
scheduling, so no speedup, Brave acceptance or live-site claim follows.

The [receipt](performance/chatgpt-production-native-sample-20261105.json)
authenticates raw stack reports, commands, browser/guard exits, executable and
library identities, original audit and PNG in a verified content-addressed
archive. No app copy or manual production build is used. Whole-page credit and
the broad cadence remain zero; the 5%-below-Brave target remains unmet.

### Direct folding of calculation terms (2026-11-05)

`3eac0d2ac` folds the validated CSS calculation term sequence directly into
products and sum children. It removes the temporary operands, operators,
sum-operands and sum-operators arrays. A single operand returns its existing
node. Products retain one invert node per divided operand; subtraction retains
one negate node around the entire following product. The parser still consumes
and validates the complete alternating sequence before folding, and the exact
unsimplified tree is unchanged. This adds no retained cache or owner.

All 12 focused compile/runtime jobs pass. Generated runners authenticate 68
selected test calls per candidate/control execution under ordinary GC, no-GC,
poisoned preallocation and ASan/UBSan: 544 function executions. Four new tests
cover all 1,365 operator sequences for one through six operands against the
original fold, exact unsimplified trees and serialization, signed zero/nonfinite
leaf bits, nested operands, unchanged input, invalid grammar, nonassociative
numeric results and output survival after the input workspace is poisoned.
Existing calculation resolution, NumericType, Typed OM, syntax contexts,
keyframe substitution, scalar values and arena ownership cases also pass.

Two separate component workloads retain every observation. The first retires
and poisons a workspace for each calculation. Its original result calls it
unprofiled because it has no function profiler, but poisoning is diagnostic
instrumentation and its 0.4–2.7% point reductions receive no unprofiled credit.
That scope is retained explicitly and is not pooled with the next workload.

The second workload disables poisoning and parses 100 calculations per
workspace, retaining all 100 retirements per 10,000-calculation scene inside the
counter interval. Immutable component input is prepared before measurement;
parsing, exact unsimplified AST comparisons and serialized-output checks are
included. Each variant has two observations in control/candidate/candidate/
control order, followed by separate path diagnostics. C O3, production source
conditions and the explicit runtime overlay are used in a single-C-unit
component executable, which differs from the parallel production browser.

| Batched component median | Control instructions | Candidate instructions | Reduction |
| --- | ---: | ---: | ---: |
| singleton | 23,555,525.0 | 17,025,499.5 | 27.7218% |
| nested-length | 117,911,683.0 | 96,374,763.0 | 18.2653% |
| mixed-precedence | 174,443,846.5 | 143,892,579.5 | 17.5135% |
| division-chain | 73,605,921.5 | 62,683,048.5 | 14.8397% |
| long-sum | 260,570,413.0 | 218,908,276.0 | 15.9888% |
| function | 83,070,520.0 | 63,323,048.5 | 23.7719% |
| invalid-tail | 15,620,385.0 | 15,640,050.5 | -0.1259% |

Invalid-tail rejection never reaches the changed fold. Its observed median is
0.1259% higher and is retained without attributing that difference to a branch
that cannot execute. Valid calculations show 14.8–27.7% lower component medians.
The [focused/component receipt](performance/chatgpt-calc-fold-20261105.json)
authenticates both complete workloads, commands, every guard, generated runner,
source and raw count. Its verified content-addressed archive preserves
385,535,771 generated C bytes before deleting redundant Build outputs.
Whole-page credit and the broad cadence remain zero pending the production
comparison. The 5%-below-Brave goal remains unmet.

### Calculation term folding: complete production comparison (2026-11-05)

The completed canonical 33-unit executable has SHA-256
`29fbee8c8ef36b55aad8f9f95037b2ab6cc8ed0fbe57440269ea3f1d8ee24d91`.
Its stable build-input receipt matches the final owned sources at `3eac0d2ac`;
raw available parser/fold disassembly is retained. A separate source check
confirms that the control fold body is byte-for-byte identical to its original
body before extraction. No manual production build or app copy is used.

A nonblocking shared publication lease pins the bundle through four diagnostic
and eight unprofiled captures. All twelve pass bootstrap, complete content and
button identity, unchanged pixels, normal browser/kernel exits and input-hash
checks. The separate fold marker appears only in the candidate diagnostic,
confirming that the changed parser executes on the captured page.

The matched order is control/candidate/candidate/control, each paired with a
fresh Brave reference. Scope is exclusive-coalition creation through encoded
document PNG, including startup/window and target setup. Original SOCKS replay,
author scripts and references, fresh private profiles/caches, 1024×768 viewport,
scale 2 and an unfocused five-second settle remain unchanged. OS filesystem and
shader caches are retained; GPU execution and outside-coalition services are
excluded. These remain observed CPU counts for the full startup/capture workflow.

| Unprofiled observed Vox instructions | Control | Candidate |
| --- | ---: | ---: |
| First observation | 30,582,191,856 | 30,544,345,135 |
| Second observation | 30,541,903,415 | 30,356,128,928 |
| Median | 30,562,047,635.5 | 30,450,237,031.5 |

The observed candidate median is **0.3658% lower**, but the ranges overlap:
30,544,345,135 candidate instructions exceed the lower control by 2,441,720.
Conservative separation is therefore **-2,441,720**, so no whole-page gain is
credited and no 5,000,000-instruction broad checkpoint is triggered. Controls
complete 454 and 455 frame checkpoints; candidates complete 453 and 460.
The counts are not normalized by frame count. One-minute host load spans about
13.4–26.6 on 18 CPUs, further limiting attribution of a small point difference.
No attempt is dropped or repeated to improve the result.

The mixed diagnostic cohort's highest Vox upper bound divided by its lowest
Brave lower bound is 1.8693, far above 0.95. Every candidate also exceeds its
Brave reference. Four pairs remain below seven-pair acceptance. The requested
5%-below-Brave target remains unmet.

The controller and outer guard exit zero over 119.99 seconds, peak at
1,734,328,320 sampled RSS bytes, and adopt 44 process identities without an
adoption error. The publication lease is released. Finalization and independent
verification also exit zero. The
[production receipt](performance/chatgpt-calc-fold-production-20261105.json)
and [verification receipt](performance/chatgpt-calc-fold-production-verification-20261105.json)
authenticate all four archives, 544 focused test calls, both component workloads,
12 valid captures, raw counters, commands, source/control proof, original PNGs,
audits, actual exits and exact comparison arithmetic. Whole-page credit and the
broad cadence remain zero. No live-site, isolated rendering-time or scrolling
improvement is claimed.

### Owned export of closed calculated values (2026-11-05)

`3d2562f6f` avoids reparsing a calculated property after its temporary grammar
workspace has already produced a complete numeric tree. The exporter rebuilds
each numeric/sum/product/negate/invert/math-function payload and child vector,
clones unit/function/strategy strings and serialization, clones the accepted
range map, and copies inline NumericType and calculation-context fields.
Relative units and percentages keep their original trees and are resolved later
with the ordinary context. No new retained cache or allocation owner is added.

An allocation-free scan accepts one-root trees up to 64 levels and 4,096 nodes.
Empty/malformed, saturated, anchor, tree-counting and random graphs keep the
original reparse path. Unsupported parent values, including transformations,
retain their complete path even when a numeric child would be exportable.
Parent graph validation finishes before publishing any caller-owned payload.

All 12 final focused compile/runtime jobs pass. Generated runners authenticate
80 test calls per candidate/control execution under ordinary GC, no-GC,
poisoned preallocation and ASan/UBSan: 640 test-function executions. Five new
cases cover every supported payload and numeric unit kind, signed zero and
nonfinite bits, copied context maps, source mutation and arena retirement,
normal/resolved serialization, lists and ratios, unsupported leaves, exact
inspection limits and malformed trees. Existing parser, calculation, Typed OM,
keyframe substitution and value-workspace ownership tests pass in the same
selection. Generated C confirms a stack-local inspection budget. Native arena
assertions remain conditional outside preallocation.

Two development rejections are preserved separately. The first compile used a
mutable primitive budget, which V rejects; it was replaced with a stack record.
The next test incorrectly expected the `rotate` transformation wrapper to be
eligible. Its existing fallback is retained and the expectation corrected.
Neither rejected selection supplies performance credit.

The unprofiled component measures complete property parsing from text, including
its real tokenizer and grammar workspaces, equality, normal/resolved serialization
and exact calculation-tree/type/context comparisons where present. The parsed
value cache is disabled. One hundred published values share each outer workspace;
all internal and outer retirements remain in the instruction interval. Poisoning
and profiling are disabled. Two observations per variant use control/candidate/
candidate/control order, followed by separate execution diagnostics. This C O3
single-unit component uses production source conditions and the explicit runtime
overlay, and differs from the parallel production browser.

| Component median | Reparse control instructions | Candidate instructions | Reduction |
| --- | ---: | ---: | ---: |
| unchanged-scalar | 95,471,300.0 | 94,663,649.5 | 0.8460% |
| calculated-number | 339,580,608.0 | 230,521,386.5 | 32.1159% |
| substituted-length-shape | 571,552,625.5 | 366,380,163.5 | 35.8974% |
| mixed-units-function | 588,608,347.0 | 377,865,880.5 | 35.8035% |
| calculated-ratio | 769,220,419.0 | 505,768,762.0 | 34.2492% |
| dependent-fallback | 401,458,071.5 | 403,280,480.0 | -0.4539% |
| wrapper-fallback | 359,881,159.0 | 359,664,053.5 | 0.0603% |
| invalid | 153,425,246.5 | 153,093,034.0 | 0.2165% |

Supported calculated values use 32.1–35.9% fewer observed component instructions.
The dependent-leaf fallback regresses 0.4540% and is retained. Unchanged scalar,
wrapper and invalid-input ranges overlap, so those point differences receive
no savings credit. Complete browser attribution still requires a source-verified
published bundle and an unprofiled matched page cohort.

The [focused/component receipt](performance/chatgpt-calculated-export-20261105.json)
authenticates all attempts, source revisions, commands, guards, generated runners
and raw counts in verified content-addressed archives. It preserves 242,570,562
generated C bytes before removing redundant Build outputs. Whole-page credit and
the broad cadence remain zero; the 5%-below-Brave goal remains unmet.


### Closed calculated-value export: production comparison (2026-11-05)

The published parallel production bundle contains `3d2562f6f` at recorded source
head `ec04bb475bb717ca490de0c4d41219b73480b506`. Its executable SHA-256 is
`988088f68706ab0abf9b602f06ee2b433bb31b902f5afd362334b9e041a0fa57`, with 33
C compilation units. A nonblocking shared publication lease pins this executable,
its native libraries, tools, fixture and unchanged pixel references throughout.
No additional production build or page download is requested.

Four separate diagnostic captures verify the candidate-only closed-tree export
marker; the reparse control does not emit it. Eight subsequent unprofiled
captures make four alternating Vox/Brave pairs with the control/candidate order
control/candidate/candidate/control. All 12 captures pass script bootstrap, full
content and button identity, unchanged per-engine exact pixel references and
normal browser/kernel exit checks. Cross-browser pixel equality is not claimed.

The original SOCKS archive and author scripts remain unchanged. This is the
fresh-launch exclusive-coalition interval through completed document PNG capture,
including startup, native window/target setup, the unfocused five-second settle
and encoded PNG delivery, with the existing per-engine audit/teardown endpoints.
The viewport is 1024 by 768 CSS pixels at backing scale two; each process uses a
fresh private profile and cache. OS filesystem/shader caches remain retained;
GPU execution and services outside the owned coalition remain excluded. This is
a frozen-page diagnostic, not a live-site or isolated rendering-time result.

| Unprofiled Vox observation | Reparse control instructions | Export candidate instructions |
| --- | ---: | ---: |
| First | 30,565,709,827 | 30,414,734,040 |
| Second | 29,572,954,030 | 30,539,363,129 |
| Median | 30,069,331,928.5 | 30,477,048,584.5 |

The candidate median is **1.3559% higher**. Observed ranges overlap substantially:
the highest candidate exceeds the lowest control by 966,409,099 instructions.
Conservative separation is therefore **-966,409,099**; whole-page credit remains
zero and no 5,000,000-instruction broad checkpoint is due. The component gains
and dependent-fallback regression above remain valid component observations.
No attempt is excluded or repeated to improve the result.

Controls complete 456 and 473 frame checkpoints; candidates complete 465 and
463. Counts are not normalized by frame count. One-minute host load falls from
about 28.1 to 13.4 on 18 CPUs during the matched cohort, limiting attribution of
the point difference. The highest Vox upper bound divided by the lowest Brave
lower bound is 1.7871, far above the requested 0.95. Four pairs also remain below
the seven-pair acceptance requirement. The **5%-below-Brave target remains unmet**.

The controller and memory guard exit zero over 115.37 seconds, peak at
1,702,363,136 sampled RSS bytes and adopt 42 process identities without an
adoption error. The publication lease is released. Finalization and independent
verification exit zero. The
[production receipt](performance/chatgpt-calculated-export-production-20261105.json)
and [verification receipt](performance/chatgpt-calculated-export-production-verification-20261105.json)
authenticate five archives, 640 focused test calls, both rejected development
attempts, all component scenes, 12 valid captures, source/control proof, original
PNGs, audits, raw counters and exact comparison arithmetic. Whole-page credit
and the broad cadence remain zero. No live-site or scrolling improvement is
claimed.


### Owned export of numeric transform arguments (2026-11-05)

`013c9d6b9` extends completed property-workspace export to
`TransformationStyleValue`, including transform lists and the individual rotate,
scale and translate properties. A bounded allocation-free scan accepts one to
sixteen scalar or closed calculated arguments. Publication rebuilds the concrete
transform payload and its argument vector in caller storage. Calculated children
use the existing bounded deep exporter; relative lengths and percentages retain
their original specified trees until ordinary absolutization or matrix resolution.
There is no additional retained cache or owner.

Dependent calculations, unsupported leaves such as `perspective(none)`, empty or
oversized vectors and unresolved inputs retain reparsing. The independent
`VOX_RETAIN_TRANSFORM_VALUE_REPARSE` control disables transform export;
`VOX_RETAIN_CALCULATED_VALUE_REPARSE` independently disables calculated children.
A separate diagnostic marker reports actual transform export once.

All 20 final compile/runtime jobs pass: 87 test functions execute in four modes
(ordinary GC, no GC, poisoned preallocation and ASan/UBSan) with four combinations
(candidate, transform control, calculation control and both controls), for
**1,392 authenticated test calls**. Five new tests cover all 21 transform functions,
individual transform properties, normal/resolved serialization, matrices with
multiple reference-box sizes, relative-unit and density computation, argument
mutation and arena retirement, recursively owned calculations and copied range
maps, rejection/fallback behavior and allocation-free inspection. Existing
calculation, parser, Typed OM, substitution and ownership regressions pass in the
same selection. Generated C authenticates each selected runner call.

The unprofiled single-unit C O3 component measures complete property parsing from
text, including internal token and grammar workspaces, equality, normal/resolved
serialization and all outer batch retirements. Setup and reference parsing are
excluded. The parsed-value cache, poisoning and profiling are disabled. Each
scene parses 10,000 values in batches of 100; checksums match across all trials.
Control/candidate/candidate/control observations precede separate execution
diagnostics. This component differs from the 33-unit production browser.

| Component median | Reparse control instructions | Export candidate instructions | Reduction |
| --- | ---: | ---: | ---: |
| unchanged-scalar | 95,644,921.0 | 95,623,800.5 | 0.0221% |
| scalar-transform-list | 431,664,843.0 | 331,063,092.5 | 23.3055% |
| calculated-transform-list | 798,808,365.5 | 543,900,156.0 | 31.9111% |
| matrix3d | 891,635,030.5 | 672,742,853.5 | 24.5495% |
| individual-translate | 468,576,739.5 | 331,832,479.0 | 29.1829% |
| individual-rotate | 361,932,709.0 | 242,272,491.5 | 33.0615% |
| dependent-fallback | 466,687,311.5 | 468,687,651.5 | -0.4286% |
| keyword-fallback | 219,428,477.0 | 219,597,562.0 | -0.0771% |
| invalid | 179,556,577.5 | 179,491,616.5 | 0.0362% |

Supported transforms use 23.3–33.1% fewer observed component instructions.
The dependent fallback regresses 0.4286%; the keyword fallback point estimate is
0.0771% higher with overlapping ranges. Unchanged scalar ranges overlap; invalid
input has a small 0.0362% point difference. Those ineligible cases supply no
transform-path credit. Every observation and regression is retained.

The first test compile rejected an immutable struct alias; the fixture was fixed
before execution. Sanitizer linking and the first component staging/link attempts
failed under disk exhaustion; a later component link reported LLVM's bad file
descriptor error. No failed build supplied runtime samples. The unchanged final
sources pass all modes, and the final production-condition component compiles
with the exact Clang command recorded. Generated C, completed test binaries and
private benchmark profiles were archived and verified before duplicate removal.
Later cleanup removed generated shader caches only from completed private Brave
benchmark profiles after reauthenticating their retained PNGs/logs against committed
archives; no default/user profile, counter, audit, fixture or reference was removed.

The [focused/component receipt](performance/chatgpt-transform-export-20261105.json)
authenticates source revisions, the rejected attempts, all final jobs, generated
runners, component commands, counts, guards, host load and cleanup receipts.
The latest completed browser contains the transform diagnostic flag but predates
its committed source proof; the newer shared build failed. A source-verified
production comparison remains pending. Whole-page credit and broad cadence remain
zero. The **5%-below-Brave target remains unmet**.


### Numeric transform export: production comparison (2026-11-05)

The subsequent completed parallel bundle includes `013c9d6b9` at recorded source
head `6ccf1b4998d0d6863e98b500d269e870f4e4ddcf`. Its executable SHA-256 is
`2ef9f79d170a63c3a26e413cd8bd387760928564e671be48e61ceef2724ad1c7`, with 33
C units. Exact owned-source Git blobs, stable aggregate build-input hashes and
available parser/export disassembly authenticate the candidate and independent
transform-only reparse control. A nonblocking shared publication lease pins the
canonical executable and native libraries throughout all captures. The previous
shared build failure remains retained; no manual or duplicate build is requested.

Four separate diagnostic captures verify actual transform export only in the
candidate. Eight subsequent unprofiled captures form four alternating Vox/Brave
pairs with Vox control/candidate/candidate/control order. All 12 captures pass
script bootstrap, full content/button identity, unchanged per-engine exact pixel
references and normal browser/kernel exits. Cross-browser pixel equality is not
claimed. The original SOCKS fixture and author scripts remain unchanged.

The workload retains the fresh-launch exclusive-coalition interval through
completed encoded document PNG capture, including startup and native target/window
setup, with the existing audit/delivery/teardown endpoints. Each process uses a
fresh private profile/cache, 1024 by 768 CSS-pixel viewport, backing scale two and
unfocused five-second settle. OS filesystem/shader caches remain retained; GPU
execution and outside-coalition services remain excluded. This is a frozen-page
diagnostic rather than live-site, isolated rendering or scrolling evidence.

| Unprofiled Vox observation | Reparse control instructions | Export candidate instructions |
| --- | ---: | ---: |
| First | 30,171,170,996 | 29,699,357,426 |
| Second | 29,676,642,247 | 30,026,960,878 |
| Median | 29,923,906,621.5 | 29,863,159,152.0 |

The candidate median is 0.2030% lower, but the ranges overlap. The highest
candidate exceeds the lowest control by 350,318,631 instructions, making
conservative separation **-350,318,631**. Whole-page credit remains zero;
no 5,000,000-instruction broad checkpoint is due and cadence remains zero.
The supported component gains and fallback regressions remain component results.
No attempt is dropped or repeated to improve these counts.

Control captures complete 456 and 457 frame checkpoints; candidates complete
455 and 460. Counts are not normalized by frame count. One-minute host load spans
about 8.1–16.0 on 18 CPUs, further qualifying attribution of the small point
difference. The observed Vox/Brave bounds remain well above the requested 0.95,
and four pairs remain below seven-pair acceptance. The **5%-below-Brave target
remains unmet**.

The controller and outer guard exit zero over 116.95 seconds, peak at
1,679,917,056 sampled RSS bytes and adopt 42 process identities without an
adoption error. The publication lease is released. Finalization and independent
verification also exit zero. The
[production receipt](performance/chatgpt-transform-export-production-20261105.json)
and [verification receipt](performance/chatgpt-transform-export-production-verification-20261105.json)
authenticate eight archives, all 1,392 focused calls, every failed development and
infrastructure attempt, all component scenes, 12 valid captures, raw commands and
counters, source/control proof, original PNGs, audits and exact comparison
arithmetic. No whole-page, Brave, live-site or scrolling improvement is claimed.


### Singleton media-rule groups (2026-11-06)

The retained all-function profile records 399,601 recursive
`CSSRuleList.evaluate_media_queries` calls. Instrumentation changes scheduling and
includes waits; these counts are a lead, not current production cost or instruction
credit. Inspection shows that container, function, layer, scope and style groups
are unconditional during media evaluation, while media/supports conditions and
imported stylesheet evaluation are observable live gates.

`e372241a6` initially flattens unconditional groups with a 256-slot expansion
limit. Its 576 focused calls pass, but the component's deep summary-rebuild case
regresses 15.16% despite 17.01% lower warmed instructions. The original archived
CSS shows only a 0.3192% warm reduction and a 0.1373% rebuild regression. These
results, the initial source, generated C and all raw observations remain retained.

The refinement `7b39ce38d` replaces only an unconditional group with exactly one
candidate by that live descendant. It never widens a candidate vector. Wider
groups keep recursive evaluation, and order, duplicate/shared rule identities,
live media/supports/import gates, delayed first evaluation and the existing
structural epoch remain intact. Existing reusable buffers and retained/persistent
owners are unchanged. No match-result cache or new allocation owner is added.
The independent `VOX_RETAIN_MEDIA_GROUP_RECURSION` control retains recursion while
leaving candidate filtering enabled; `VOX_DISABLE_MEDIA_RULE_CANDIDATES` supplies
a separate full-traversal correctness control. A consumer-side diagnostic marker
confirms that a flattened list actually reaches evaluation.

All 16 final compile/runtime jobs pass. Forty-eight test functions execute in
ordinary GC, no GC, poisoned preallocation and ASan/UBSan under all three variants:
**576 authenticated calls**. Five new cases cover every unconditional group type,
ordered single-candidate chains and wider boundaries, current viewport/preferences,
inactive supports and media ancestors, delayed first evaluation, nested CSSOM
replacement, late imports and imported-sheet media, retained owner lifetime and
allocation-free warmed lookup. Existing candidate, empty-list, media precision,
font/viewport-cache, display-density, link mutation and registered shadow/adoption
checks pass in the same selection. Generated C verifies all selected runner calls.

The benchmark tool `a549c1474` uses the two unchanged original archived CSS bodies
and fixed synthetic grouping shapes. Its unprofiled C O3/LTO single-unit executable
measures warmed evaluation or explicit same-rule CSSOM replacement, summary rebuild
and evaluation. Parsing, first evaluation, match-state checks, startup and teardown
are excluded. Match-state checksums and zero-change results agree across every
control/candidate/candidate/control observation. Poisoning and profiling are off;
separate execution diagnostics follow. This component differs from the parallel
production browser.

| Refined component median | Recursive control instructions | Candidate instructions | Reduction |
| --- | ---: | ---: | ---: |
| archived-warm | 97,424,046.5 | 97,386,473.5 | 0.03857% |
| archived-rebuild | 349,672,043.5 | 349,606,694.5 | 0.01869% |
| flat-warm | 1,544,013.0 | 1,544,000.5 | 0.00081% |
| deep-warm | 1,860,428.5 | 1,570,385.5 | 15.59012% |
| deep-rebuild | 2,986,393.5 | 2,951,168.5 | 1.17952% |
| oversized-warm | 12,458,846.0 | 12,168,723.0 | 2.32865% |
| oversized-rebuild | 19,406,359.0 | 19,369,564.5 | 0.18960% |

The deep synthetic case now uses 15.59% fewer warmed instructions and 1.18% fewer
rebuild instructions. The original archived CSS improvement is only 0.0386% warm;
its rebuild ranges overlap, as do the unchanged flat warm ranges. The oversized
nested shape still bypasses single-candidate ancestors while retaining its wide
leaf boundary; it is not an ineligible control. Every observation is retained,
including the initial deep-rebuild regression; no component supplies page credit.

The first compile rejected a mutable-array descriptor and an incorrect stylesheet
media accessor. A later new fixture incorrectly expected an imported-sheet media
edit to report a change instead of resetting its baseline; both candidate and
recursive control reject that expectation. The corrected test independently
checks later import-gate transitions. A final component build exhausts disk before
runtime; its controller rejects without samples. The unchanged final sources then
compile and run successfully. Generated C from completed jobs is archived and
verified before removing duplicates; counters, raw logs, fixtures, audits and
references remain intact.

The [focused/component receipt](performance/chatgpt-media-groups-20261106.json)
and [initial receipt](performance/chatgpt-media-groups-initial-20261106.json)
authenticate both policies, every rejected attempt, commands, guards, source
revisions, generated runners, raw measurements, host load and verified cleanup.

### Singleton media groups: production comparison (2026-11-06)

The source-matched 33-unit parallel bundle has executable SHA-256
`25daa7b67a9a345998128325be4795c68bd552fc8439f6e8717cbeec22690c8d` at recorded
source head `a549c1474e017cd9860d1515efb555e3d2462ba8`. Exact owned-source Git
blobs, stable aggregate build-input hashes and available media candidate/evaluation
disassembly authenticate the final code and recursive control. A nonblocking shared
publication lease pins the canonical executable, native libraries, tools, fixture
and references throughout. No bundle is copied, additional production build is
manually queued or page downloaded.

Four separate diagnostic captures verify candidate-only consumption of flattened
groups. Eight subsequent unprofiled captures form four alternating Vox/Brave pairs,
with Vox control/candidate/candidate/control order. All 12 pass script bootstrap,
complete content and button identity, unchanged per-engine exact pixel references
and normal browser/kernel exits. Cross-browser pixel equality is not claimed.

The original SOCKS fixture and author scripts remain unchanged. The scope remains
fresh exclusive-coalition creation through completed encoded document PNG capture,
including startup and native window/target setup, with the established audit,
delivery and teardown endpoints. Each process has a fresh private profile/cache,
1024 by 768 CSS-pixel viewport, backing scale two and unfocused five-second settle.
OS filesystem/shader caches remain retained; GPU execution and services outside
the owned coalition remain excluded. These are frozen-page observations.

| Unprofiled Vox observation | Recursive control instructions | Candidate instructions |
| --- | ---: | ---: |
| First | 30,482,784,771 | 30,212,061,756 |
| Second | 30,256,143,599 | 30,561,870,363 |
| Median | 30,369,464,185.0 | 30,386,966,059.5 |

The candidate median is **0.05763% higher** and the ranges overlap. The highest
candidate exceeds the lowest control by 305,726,764 instructions, so conservative
separation is **-305,726,764**. Whole-page credit and broad cadence remain zero;
no 5,000,000-instruction broad checkpoint is due. No attempt is dropped or repeated
to improve the comparison.

Controls complete 458 and 475 frame checkpoints; candidates complete 465 and 459.
Counts are not normalized by frame count. One-minute host load spans about 6.0–8.9
on 18 CPUs. The highest observed Vox upper bound divided by the lowest Brave lower
bound is 1.7227, far above the requested 0.95. Four pairs also remain below seven-pair
acceptance. The **5%-below-Brave target remains unmet**.

The controller and outer guard exit zero over 113.43 seconds, peak at
1,691,910,144 sampled RSS bytes and adopt 46 process identities without an adoption
error. The publication lease is released. Finalization and independent verification
exit zero and authenticate eight archives. The
[production receipt](performance/chatgpt-media-groups-production-20261106.json)
and [verification receipt](performance/chatgpt-media-groups-production-verification-20261106.json)
preserve all focused/component evidence, the initial regression, failed attempts,
12 valid captures, original PNGs, commands, counters, audits, source/control proofs
and exact comparison arithmetic. No whole-page, Brave, live-site, isolated rendering
or scrolling improvement is claimed.


## Fixed document reply encoding (2026-11-06)

Implementation `fde9a1f40` avoids rebuilding a four-entry JSON map for each
Document identity reply. The root document returns its static envelope; ordinary
bridge keys use the existing JSON string encoder inside the same fixed envelope.
The original map encoder remains available for keys over 256 bytes and through
`VOX_RETAIN_DOCUMENT_REPLY_MAP`. Output preserves the original exact bytes,
including sorted field order. Document lookup and foreign-document registration
still run on every request; no owner or document identity is cached. This applies
to ownerDocument, detached document creation and generic document-node replies.

All 24 final focused jobs pass: eight compilations and sixteen executions, with
408 authenticated test-function calls across ordinary GC, no GC, poisoned
preallocation and address/undefined-behavior sanitizers, in both control and
candidate modes. Coverage includes every single-byte key, Unicode/control/invalid
byte sequences, randomized keys, 255/256/257-byte boundaries, large fallback,
input/reply arena retirement, root allocation behavior, foreign registration,
native adoption and actual JavaScriptCore ownerDocument identity after adoption.
Existing document, identity, fragment, template, shadow-root, child, form-control,
hit-testing and parent-cache checks are included. Preallocation-specific ownership
assertions remain conditional; this is a selected test pass, not a full repository
suite claim.

The first focused attempt rejected the prototype's different JSON field order.
That failure and its source are retained. A later native compilation exhausted disk
space before execution; its successful preceding jobs and failed generated source
are retained separately. The final run uses the explicit preallocation runtime
module overlay in every mode. Completed generated outputs were removed only after
archive hash verification. Cleanup receipts also retain the initial incomplete
receipt assertion and report-name collision; neither represents a passing check.

Tool `ddbcf74c2` reads keys from a pinned runtime manifest, preventing compile-time
specialization of a literal root key. The component interval includes encoding,
exact output comparison, checksum and scratch-workspace retirement every 100
replies. Native lookup/registration, request decoding, JavaScriptCore, input/oracle
setup and startup/teardown are excluded. It uses production V conditions with
single-unit C O3/LTO, distinct from the parallel production browser. Two control
and two candidate executions alternate, with separate branch diagnostics:

| Encoder scene | Calls per execution | Control median instructions | Candidate median instructions | Observed change |
| --- | ---: | ---: | ---: | ---: |
| Root document | 128,000 | 711,792,747 | 6,446,103 | 99.0944% fewer |
| Foreign document keys | 64,000 | 365,362,381.5 | 38,449,909 | 89.4762% fewer |
| Escaped keys | 32,000 | 190,717,888.5 | 27,719,200.5 | 85.4659% fewer |
| Oversized fallback | 8,000 | 85,834,967.5 | 85,910,807 | 0.0884% more |

The first component cohort's oversized fallback regressed 0.1325%; the final
length-first guard reduces that observed regression but does not erase it.
Encoder-only reductions supply no page-level credit. The
[focused/component receipt](performance/chatgpt-document-reply-20261106.json) and
[initial component receipt](performance/chatgpt-document-reply-initial-20261106.json)
retain all observations, failed attempts, runner authentication, source snapshots,
commands, guards and cleanup evidence.

### Production comparison and required broad checkpoint

The latest completed parallel production bundle has executable SHA-256
`90def6833d5d2a238dd36a10a7eb8030e8cab0a2470d51d7a034682862224075`, receipt
source head `781b3aefabc1c9be49f249ef9750492eb4b426bf`, and 33 C units. Stable
aggregate build-input hashes, exact owned-source Git blobs and available function
disassembly establish identity. A nonblocking shared publication lease pins the
canonical bundle and libraries through diagnostics, matched captures and broad
checks. No manual production build, app copy or new download was requested.

The original SOCKS capture, author scripts, references and tolerances remain
unchanged. Each browser starts fresh with private profiles/caches, a 1024×768
logical viewport, backing scale two and an unfocused five-second settle. The
observed exclusive-coalition scope runs from creation through encoded document
PNG, with the existing engine-specific audit/delivery/teardown boundaries recorded
in the raw receipts. OS filesystem/shader caches remain warm; GPU execution and
services outside the owned coalition are excluded. These are frozen-page workflow
counts, not isolated rendering or scrolling measurements.

All four diagnostic and eight unprofiled captures pass complete bootstrap,
content/button identity, normal exits and unchanged per-engine pixel references.
The candidate-only document-encoder marker verifies execution separately. Vox
control order is control/candidate/candidate/control across four alternating
Vox/Brave pairs:

| Vox variant | Observed launch-through-PNG instructions |
| --- | ---: |
| Control 1 | 30,196,324,014 |
| Candidate 1 | 29,986,944,196 |
| Candidate 2 | 29,290,709,194 |
| Control 2 | 30,437,510,317 |

The control median is **30,316,917,165.5**, the candidate median
**29,638,826,695**, an observed **2.2367% reduction**. The conservative separation
`min(control) - max(candidate)` is **209,379,818 instructions**. This exceeds the
5,000,000-instruction broad-check threshold. All **47 required jobs pass**: 20
screenshot comparisons including live image replacement and SVG paint-server
mutations, 22 native compile/runtime jobs, four LibJS AST compile/runtime jobs
with all 100 fixtures exact in both modes, and one pixel-diff control. The credited
conservative page saving is 209,379,818 and the cadence resets to zero.

Controls complete 476 and 466 frame checkpoints; candidates complete 478 and 484.
Counts are not normalized by frames. One-minute host load spans about 4.69–5.54
on 18 CPUs during the matched cohort. The highest Vox upper bound divided by the
lowest Brave lower bound is about 1.7468, far above 0.95; the exact requested gate
fails: `608750206340 > 331061504794`. Four pairs also remain below seven-pair
acceptance. The **5%-below-Brave target remains unmet**.

The controller and outer guard exit zero over 275.43 seconds including the broad
checkpoint, peak at 1,710,751,744 sampled RSS bytes and adopt 43 process identities
without an adoption error. The publication lease is released. Finalization and
independent verification exit zero and authenticate eight archives. The
[production receipt](performance/chatgpt-document-reply-production-20261106.json)
and [verification receipt](performance/chatgpt-document-reply-production-verification-20261106.json)
preserve exact counts, source/control proofs, all 12 captures and original PNGs,
commands, guards, audits, raw failed attempts and the required broad checkpoint.
No live-site, cross-browser pixel equality or Brave advantage is claimed.


## Live root document owner read (2026-11-06)

Implementation `bde01623f` adds a synchronous JavaScriptCore boolean read for
registered nodes whose current native owner is the binding's root document. The
facade returns the existing root Document only when there are no pending DOM
operations or dirty element states. Foreign or unknown identities, Documents,
unmaterialized nodes and pending edits retain the existing ownerDocument query
and mutation replay. Ownership is read on every call; there is no identity cache
or DOM write. The host borrows its key inside a temporary scratch scope and
returns only a boolean. The native callback and intrinsic Set size getter are
captured before author scripts. `VOX_RETAIN_DOCUMENT_OWNER_QUERY` retains the
ordinary query path; other engine optimizations remain enabled in both variants.

All 24 focused jobs pass: eight compilations and sixteen executions, with **296
authenticated test-function calls** across ordinary GC, no GC, poisoned
preallocation and address/undefined-behavior sanitizers, for both variants.
Coverage includes native Element/Text/Comment/DocumentFragment ownership, foreign
adoption and adoption back, unchanged identity maps, exact boolean results,
non-string argument rejection without coercion, separate runtime owners, close
behavior, temporary-key retirement, branding, replaced native/Set intrinsics,
foreign and unknown fallbacks, and pending unrelated edits that adopt the queried
node synchronously during replay. Existing document, identity, fragment, parent,
child, template, shadow-root and actual-value host tests are included.
Preallocation-specific ownership assertions remain conditional.

The focused controller and 12 GiB guard exit zero over 219.24 seconds, peaking at
8,919,171,072 sampled RSS bytes. Runtime jobs use separate 3 GiB guards. Runner
verification authenticates the exact generated-C call sets against each selected
source file. Its first parser assumed a module prefix for main-package test calls;
it rejected before archiving or deleting anything. The corrected parser preserves
that failed attempt and verifies all eight runners. After archive readback and
hash checks, 270,234,967 bytes of generated C duplicates were removed. The
[focused receipt](performance/chatgpt-document-owner-20261106.json) retains source
hashes, all commands, logs, guards, generated C and runtime evidence. These focused
checks supply no page-level instruction credit.

The available production executable `304c4496bc6c2fa36ce9b5e161cf4cc956ca50f273bca19a2e79e42e5739b78d`
exposes the new feature flag and marker, but its receipt points to `b4402f9a2`,
before these owned sources were committed. It is not used to validate the final
change. The already coalesced build at `bde01623f` contains the exact final owned
source blobs, uses 33 parallel C units, and passes compilation and headless smoke.
Canonical publication is waiting behind another session's broad-browser lease.
No additional build or app copy is requested.

The [pending production receipt](performance/chatgpt-document-owner-production-pending-20261106.json)
archives that availability check, build/smoke receipts and prepared source/branch,
matched-capture and conditional 47-job broad harnesses. They have not launched a
browser for this optimization. **Page validation remains pending, with zero new
page instruction credit and unchanged zero broad carry.** The preceding 2.2367%
document-envelope result remains separate. The **5%-below-Brave target remains
unmet**.


## Production validation of live root document owner read (2026-11-06)

The pending comparison above is now complete on canonical executable SHA-256
`69f5f5130505252da73043d304375ffe1009e2a5b0555854fb21c2813f25fdd7`, source
head `bde01623f70f4caba3d1737f0f5654f6a043edc4`, using 33 parallel C units.
The owned source blobs match exactly, and the before/after aggregate build-input
hashes agree. A nonblocking shared publication lease pins the executable and all
native libraries through separate diagnostics, matched captures and broad checks.
No additional build, app copy or download is requested.

All four diagnostic and eight unprofiled captures pass JavaScriptCore bootstrap,
complete content/button identity, normal browser exits and unchanged per-engine
pixels. The native root-owner marker appears only in the candidate. The original
SOCKS fixture, author scripts, references, tolerances, private profiles/caches,
1024×768 logical viewport, scale two and unfocused five-second settle are unchanged.
The scope remains exclusive-coalition creation through encoded document PNG,
including startup and the existing documented per-engine audit/delivery/teardown
boundaries. OS filesystem/shader caches remain warm; GPU execution and services
outside the owned coalition are excluded.

| Vox variant | Observed launch-through-PNG instructions | Frame checkpoints |
| --- | ---: | ---: |
| Control | 30,135,767,733 | 417 |
| Candidate | 28,708,687,125 | 494 |
| Candidate | 28,988,902,700 | 485 |
| Control | 29,423,835,325 | 483 |

The control median is **29,779,801,529** instructions and the candidate median
**28,848,794,912.5**, an observed **3.1263% reduction**. Conservative separation
`min(control) - max(candidate)` is **434,932,625 instructions**, exceeding the
5,000,000-instruction broad-check threshold. All **47 required jobs pass**:
20 screenshot comparisons including live image replacement and SVG paint-server
mutations, 22 native compile/runtime jobs, four AST compile/runtime jobs with all
100 fixtures exact in both GC modes, and one pixel-diff control. The credited
conservative page saving is 434,932,625 and broad carry resets to zero.

One-minute host load spans about 8.35–14.51 on 18 CPUs during the matched cohort.
Controls complete 417 and 483 frame checkpoints; candidates complete 494 and 485.
The first control's smaller frame count and substantial host contention qualify
this four-pair observation. Counts are not normalized by frames, and no confidence
interval or seven-pair acceptance is inferred. Every observation remains retained.
The cohort's highest Vox upper bound divided by the lowest Brave lower bound is
about 1.6577, far above 0.95. Candidate counts alone also exceed Brave's counts.
The exact cohort gate fails: `602715354660 > 345399281412`. The **requested
5%-below-Brave target remains unmet**.

The controller and outer 12 GiB guard exit zero over 278.32 seconds including the
broad checkpoint, peaking at 1,576,730,624 sampled RSS bytes and adopting 42 process
identities without an adoption error. The publication lease is released.
Finalization and independent verification exit zero and authenticate six archives,
including the earlier pending attempt. The
[production receipt](performance/chatgpt-document-owner-production-20261106.json)
and [verification receipt](performance/chatgpt-document-owner-production-verification-20261106.json)
retain exact raw counts, all 12 captures and original PNGs, source/control proofs,
commands, guards, audits, focused evidence and the complete broad checkpoint.
The earlier document-envelope saving remains separate; no live-site, cross-browser
pixel equality, isolated rendering or scrolling claim is added.


## Scalar href URL text (2026-11-06)

Implementation `b6463ad4c` lets the HTML href getter use the existing native URL
parser and USVString conversion to return copied text without creating a DOMURL
or JavaScript URL wrapper. Native constructor, prototype and original href-getter
witnesses authenticate this path. Author replacements, non-string inputs and
invalid URLs keep ordinary construction; foreign owners keep their existing
native query. Value/owner/base handling and setters remain unchanged, including
existing base-resolution limitations. There is no new URL or DOM identity cache.
Temporary input/result storage retires only after the JavaScript string is copied.
`VOX_RETAIN_HREF_URL_OBJECTS` retains ordinary construction. Bootstrap capture runs
before element facades can invoke the new hook.

All 24 final focused jobs pass: eight compilations and sixteen executions, with
**304 authenticated test-function calls** across ordinary GC, no GC, poisoned
preallocation and address/undefined-behavior sanitizers, in both modes. Cases
compare native URL results across relative, absolute, escaped, Unicode, lone
surrogate, opaque and invalid inputs; reject non-strings without coercion; verify
unchanged URL wrapper/owner map sizes during repeated scalar reads; retire caller
inputs and churn/evict parser entries; close independent runtimes; and exercise
actual HTML href getters, pending writes, foreign adoption, replaced constructors,
replaced accessor/data properties and exact constructor read counts. Existing URL,
URLSearchParams, document, owner, identity, fragment and parent tests are included.
Preallocation-specific ownership assertions remain conditional.

The first compilation used the DOM URL serialization signature for a parser
record; it rejects before running tests. That source and failure are retained.
The next integration run exposes a bootstrap ordering error: element construction
can invoke the hook before its captured constants initialize. Its failed execution,
preceding successful jobs and generated C are preserved. Moving capture before
facade construction fixes the ordering; every final focused job passes. The final
focused controller and guard exit zero over 290.43 seconds, peaking at
9,732,915,200 sampled RSS bytes under 12 GiB. Runtime guards use 3 GiB. After
lossless archive readback and hash checks, 450,519,963 bytes of generated C
duplicates are removed. No app bundle or source tree is copied.

Tool `46d61a75e` loads inputs from a pinned manifest, including 108 href values
extracted from the original frozen HTML. The same-executable JavaScriptCore
component includes evaluation/result delivery, exact per-read output checks,
parsing/serialization and scratch retirement every 100 reads. Oracle/setup,
runtime startup/close and HTML ownership/replay/constructor guards are excluded.
The oracle warms the existing parser for both modes before measurement. It uses
production V conditions and single-unit C O3/LTO preallocation, distinct from the
parallel browser, without poisoning or profiling. Two control and two candidate
executions alternate, followed by separate path diagnostics:

| Scene | Reads | Control median instructions | Candidate median instructions | Observed change |
| --- | ---: | ---: | ---: | ---: |
| Archived hrefs | 16,000 | 498,548,596 | 330,792,258 | 33.6489% fewer |
| Relative and escaped | 8,000 | 237,281,830.5 | 168,369,853.5 | 29.0422% fewer |
| Rotating bases | 8,000 | 335,225,803.5 | 257,762,346 | 23.1078% fewer |
| Invalid fallback | 2,000 | 73,987,321.5 | 94,304,698 | 27.4606% more |

Invalid inputs still take ordinary construction after scalar parsing refuses them;
that regression is retained. Component results supply no page-level credit. The
[focused/component receipt](performance/chatgpt-href-text-20261106.json) links all
six component executions, exact output checksums, authenticated runners, source
snapshots, guards, both failed development attempts and verified archives.

### Scalar href production comparison

The completed canonical executable SHA-256 is
`04ea81d85142b2d71de231567d6e70ff4aa615d0def376e1bb7635667c916d6f`, using 33
parallel C units. Its receipt starts at `44b8ffd4a32efa032c39f6f264ff1683b1ef103e`
and verifies at `c82ce8a13e8d0ec094355778edf12cc5905ad4c8`: aggregate build-input
hashes are identical, and the latter head contains exact final owned source blobs.
Available disassembly and a separate candidate-only execution marker provide
additional source/path evidence. A nonblocking shared publication lease pins all
browser/native inputs through the entire comparison; no extra build is requested.

All four diagnostic and eight unprofiled captures pass JavaScriptCore bootstrap,
complete content/button identity, normal browser exits and unchanged per-engine
pixels. The original SOCKS fixture, author scripts, references and tolerances,
fresh private profiles/caches, 1024×768 viewport, scale two and unfocused five-second
settle are unchanged. Scope remains exclusive-coalition creation through encoded
document PNG, including startup and the documented per-engine capture/audit/delivery/
teardown boundaries. OS filesystem/shader caches remain warm; GPU execution and
services outside the owned coalition are excluded.

| Vox variant | Observed launch-through-PNG instructions | Frame checkpoints |
| --- | ---: | ---: |
| Control 1 | 29,055,580,148 | 463 |
| Candidate 1 | 28,826,962,375 | 461 |
| Candidate 2 | 28,348,216,390 | 473 |
| Control 2 | 28,166,051,765 | 470 |

The control median is **28,610,815,956.5**, the candidate median
**28,587,589,382.5**, an observed **0.0812% reduction**. Conservative separation
`min(control) - max(candidate)` is **−660,910,610 instructions**. The observed
ranges overlap substantially: **no whole-page saving is credited**. Broad carry
remains zero and no additional 5,000,000-instruction broad checkpoint is due.
The prior owner-read checkpoint remains complete and separate.

One-minute host load spans about 4.88–6.63 on 18 CPUs. Frame counts are retained
without normalization. Four pairs remain diagnostic only, below seven-pair
acceptance. The highest observed Vox upper bound divided by the lowest Brave
lower bound is 1.5991, far above 0.95. The **5%-below-Brave target remains unmet**.

The controller and outer guard exit zero over 113.99 seconds, peaking at
1,575,698,432 sampled RSS bytes and adopting 42 process identities without an
adoption error. The publication lease is released. Finalization and independent
verification exit zero and authenticate six archives. The
[production receipt](performance/chatgpt-href-text-production-20261106.json)
and [verification receipt](performance/chatgpt-href-text-production-verification-20261106.json)
retain exact counters, commands, actual exits, audits, all 12 captures and original
PNGs, source/control proofs, focused/component checks and development failures.
No observation is dropped or repeated to improve the result, and no whole-page,
Brave, live-site, isolated rendering or scrolling gain is claimed for this change.


## Detailed loading instruction budget (2026-11-06)

The requested stage table is measured with opt-in process-counter boundaries,
implemented in `8bc8e1f68`, summarized by `23199e8c5`, and extended for asynchronous
module completion in `5dee51672`. **JavaScript-related scopes are the largest
combined bucket: 9,071,443,857 instructions, or 30.3244%**. This combines module
compilation/completion and the other engine evaluation/callback scopes below.
It includes native DOM bindings inside those entries, while separately measured
style/layout work is charged to its own rows. It is not a pure JavaScript VM
instruction count. Native replay is also large at 21.3657%, and document style
updates consume another 14.5511%.

The detailed diagnostic totals **29,914,657,752 instructions**. This is a fresh
instrumented capture, not a retroactive subdivision or scaling of the earlier
**29,055,580,148** control sample. That exact historical sample is fully reconciled
by the [historical checkpoint CSV](performance/chatgpt-load-stages-historical-20261106.csv)
and [JSON](performance/chatgpt-load-stages-historical-20261106.json). Its 1,090
cumulative checkpoints name the ends of non-overlapping gaps; a gap can include
unmarked parent work, so those labels cannot establish exclusive function costs.
The original archived browser log and its hashes remain linked in the evidence.

The table covers exclusive-coalition creation through encoded document PNG,
including startup, window setup and the unfocused five-second settling/rendering
period. It measures CPU instructions rather than elapsed network waiting time.
The original SOCKS-captured fixture and author scripts, private profiles/caches,
1024×768 viewport, scale two and existing per-engine references are unchanged.
No new live download is made. OS filesystem/shader caches remain retained.
GPU execution and services outside the owned coalition remain excluded.

| Stage (measured child scopes subtracted) | Instructions | Share | Calls |
| --- | ---: | ---: | ---: |
| Native document replay / retained raster handling | 6,391,481,365 | 21.3657% | 443 |
| Async JavaScript module compilation, execution and bindings | 5,309,660,307 | 17.7494% | 288 |
| Document style updates | 4,352,914,044 | 14.5511% | 882 |
| Other browser startup / native event-loop work (residual) | 4,044,932,744 | 13.5216% | 1 |
| Other JavaScript evaluation, callbacks and bindings | 3,761,783,550 | 12.5751% | 1,883 |
| Absolutely positioned descendants | 2,219,264,679 | 7.4187% | 13 |
| Owned helpers + process/coalition endpoint remainder | 693,367,685 | 2.3178% | — |
| CSS parsing / stylesheet conversion | 595,660,990 | 1.9912% | 11 |
| Background resource completion, excluding measured children | 324,871,080 | 1.0860% | 443 |
| Document installation, including HTML/navigation work | 301,653,948 | 1.0084% | 1 |
| Document layout coordination | 279,503,528 | 0.9343% | 870 |
| Frame setup / completion, excluding measured children | 247,065,571 | 0.8259% | 443 |
| Frame preparation, excluding measured children | 224,732,255 | 0.7512% | 443 |
| Viewport relayout coordination | 188,535,731 | 0.6302% | 10 |
| Normal flow layout | 170,208,736 | 0.5690% | 13 |
| Layout tree construction | 144,567,280 | 0.4833% | 11 |
| Process startup before/between instrumented roots | 136,394,595 | 0.4559% | — |
| Paint command recording | 118,085,931 | 0.3947% | 20 |
| Apply JavaScript document state | 106,809,575 | 0.3570% | 882 |
| JavaScript runtime setup, excluding measured children | 85,459,284 | 0.2857% | 1 |
| Browser chrome | 63,350,800 | 0.2118% | 449 |
| HTML rendering opportunity scheduling | 47,045,927 | 0.1573% | 443 |
| Animation driver | 40,105,473 | 0.1341% | 443 |
| Other layout geometry | 33,889,771 | 0.1133% | 13 |
| PNG encoding | 18,025,983 | 0.0603% | 1 |
| Separately traced style computation / interpolation | 7,939,932 | 0.0265% | 29 |
| Document snapshot | 5,845,115 | 0.0195% | 1 |
| Relative-position offsets | 1,454,731 | 0.0049% | 13 |
| Snapshot pixel conversion | 47,142 | 0.0002% | 1 |
| **Total** | **29,914,657,752** | **100%** | |

Every row is additive: **29,221,290,067 root-process instructions plus
693,367,685 coalition/endpoint remainder equals 29,914,657,752**. The
[full CSV](performance/chatgpt-load-stages-final-traced-20261106.csv) and
[JSON](performance/chatgpt-load-stages-final-traced-20261106.json) retain exact
counts, shares, calls and overlapping inclusive counts. Never add the inclusive
column. Scope calls are entries rather than distinct frames, modules or DOM
objects. The open browser-main scope is clipped at the encoded-PNG endpoint.

The 4,044,932,744 browser-main residual is outside finer measured scopes:
startup, native event-loop/platform work and concurrent process activity. It is
not attributed to JavaScript or a specific native subsystem. The additional
136,394,595 instructions precede/between instrumented root scopes. The
693,367,685 remainder includes owned helpers and differences between process and
coalition endpoint reads; it is not a separately measured helper total. Thus all
instructions reconcile, but this table does not pretend every instruction has
been identified down to a function. Process counters include other threads active
during a main-thread scope and the tracer's own work.

HTML decoding/parsing and navigation-document setup use the compact embedder's
entry point rather than the standalone HTML parser scopes; their unseparated
cost is inside document installation, with measured CSS/style/layout children
subtracted. Native replay includes retained-raster reuse and frame graphics
handling; 443 replay entries do not mean 443 complete rerasterizations. Only 20
paint-command-recording entries and 13 geometry-layout entries execute in this
capture. These are workload counts, not displayed FPS.

### Diagnostic validation and limits

The final canonical executable SHA-256 is
`cecb4831bb22703167e25ea23d1f2bcccfe5c34f7ba2a17776f74286eead16ac`, using 33
parallel C units. Both receipt heads are
`b54c3d910de4a4424bec106496c4b29ce577b297`, aggregate build-input hashes match,
and all 18 owned implementation source blobs match that completed head exactly.
Source snapshots, receipt, helper/main disassembly and branch events are retained.
A nonblocking shared publication lease pins the bundle for all four final captures
and is released afterward. No separate production build or app copy is made.

The initial tracer misses asynchronous module completion entered directly from a
network callback. Its complete diagnostic is retained, including its larger
unattributed browser-main row; it cannot establish that JavaScript is small.
Tracing `ModuleHost.supply` captures source transformation, JavaScriptCore module
compilation/evaluation, drained jobs and native bindings, with nested scopes
subtracted. The final diagnostic proves that path executes 288 times. The
5,309,660,307 module-exclusive instructions are combined with 3,761,783,550
other JavaScript-exclusive instructions for the 30.3244% headline.

| Attempt | Traced Vox instructions | Untraced Vox instructions | Qualification |
| --- | ---: | ---: | --- |
| Initial scopes | 29,881,013,517 | 28,719,717,898 | Async module path not yet isolated; retained |
| Final module-aware scopes | 29,914,657,752 | 27,177,417,699 | Detailed additive table above |

All eight captures across both attempts (four Vox and four Brave) pass bootstrap,
complete content/button identity, unchanged per-engine pixels and normal browser
exits; executable/native-library/fixture/tool identities remain stable within each
attempt. Per-engine stability does not imply cross-browser pixel equality. A fresh
process is launched each time. Generic driver summaries mix traced/untraced Vox
variants and return one for the unmet Brave threshold; they are retained raw and
are not performance acceptance results. The custom diagnostic controllers and
memory guards exit zero because all four captures in each attempt are valid.

The two traced and two untraced observations use different instrumentation and
completed builds; their differences are not optimization savings or a calibrated
tracer-overhead estimate. One-minute host load spans roughly 10.28–14.25 across the
attempts on 18 CPUs. Tracing changes scheduling/frame opportunities and contributes
instructions. No values are normalized by frame count or rescaled to 29B.
These runs explain a frozen loading workload; they do not establish live-site
network time, pure VM cost, displayed FPS, or the 5%-below-Brave target.

All 24 final stage/native check jobs pass with **152 authenticated test-function
executions**, across ordinary GC, no GC, poisoned preallocation and address/
undefined-behavior sanitizers, with tracing on and off. The module addition passes
all 12 jobs and **48 authenticated test-function executions** in the same modes.
All **22 parser tests** pass, covering nesting, clipping, PID ownership, invalid
counters, capture transfers and exact additive reconciliation. An earlier broader
processmetrics selection fails the existing inherited shared-coalition monotonicity
assertion (2,156,917,076,108,014 then 2,156,917,073,946,191). The final focused selection
excludes that unrelated assertion, retains its failure/source/logs, and makes no
whole-processmetrics-suite pass claim. Browser captures use their audited exclusive
coalition instead of that inherited shared-coalition test.

The final capture guard exits zero over 39.42 seconds, peaking at 1,362,313,216
sampled RSS bytes under 12 GiB. It adopts 14 process identities without error.
The independent finalizer exits zero, authenticating five indexed archives and
all eight captures, exact historical/final totals, actual compiled test runners
and source groups. The original 119,553,554-byte focused container is replaced by
two smaller archives only after verifying an identical union of every indexed
payload path, length and SHA-256 value. All earlier failures and superseded
profiles remain retained. Finalization guards and full provenance are included.

See the [verification receipt](performance/chatgpt-load-stages-verification-20261106.json),
[focused receipt](performance/chatgpt-load-stages-focused-20261106.json),
[initial production diagnostic](performance/chatgpt-load-stages-production-r1-diagnostic-20261106.json)
and [final production diagnostic](performance/chatgpt-load-stages-production-r2-diagnostic-20261106.json).
**Instruction optimization credit is zero; broad-check carry remains zero.** This
is diagnostic tooling and a CPU budget table; the overall Brave target remains unmet.


## Refined native and HTML stage budget (2026-11-06)

Implementation `3339c9466` adds opt-in boundaries around native frame bitmap
setup/finalization, native layer publication, HTML event-loop processing and
individual networking/rendering/timer/posted-message/other tasks. It also splits
graphics-context setup from raster replay and instruments the compact navigation
parser and initial resource path actually used by this page. Native callbacks
share V identities and carry the previous JavaScript nesting state in a scalar
token; Objective-C `@finally` closes them on early return and exceptions.
Callbacks use `VOX_NATIVE_STATE` and install only when both diagnostics and
instruction counters are enabled.

The fresh diagnostic totals **30,368,705,509 instructions**. **JavaScript-related
scopes total 9,130,285,975 (30.0648%)**. The largest native scope is **document
raster replay: 6,843,019,533 (22.5331%)**. Native bitmap/presentation self work
outside the V frame totals **206,869,453**, and HTML task/loop self work totals
**716,847,402**, with measured children subtracted. The browser-main residual is
still **3,171,913,355 (10.4447%)**; it remains unattributed to a specific subsystem.

| Stage (measured children subtracted) | Instructions | Share | Calls |
| --- | ---: | ---: | ---: |
| Document raster replay, caches, filters and compositing | 6,843,019,533 | 22.5331% | 381 |
| Async JavaScript module compilation, execution and bindings | 5,331,851,467 | 17.5571% | 288 |
| Document style updates | 4,139,431,519 | 13.6306% | 741 |
| Other JavaScript evaluation, callbacks and bindings | 3,798,434,508 | 12.5077% | 1,850 |
| Other browser startup / native event-loop work (residual) | 3,171,913,355 | 10.4447% | 1 |
| Absolutely positioned descendants | 2,249,604,394 | 7.4076% | 13 |
| Owned helpers + process/coalition endpoint remainder | 712,069,331 | 2.3447% | — |
| CSS parsing / stylesheet conversion | 578,580,082 | 1.9052% | 11 |
| Background resource completion, excluding measured children | 326,932,343 | 1.0765% | 381 |
| HTML networking task, excluding measured children | 318,087,630 | 1.0474% | 581 |
| Document layout coordination | 255,705,586 | 0.8420% | 730 |
| Frame setup / completion, excluding measured children | 214,158,477 | 0.7052% | 381 |
| HTML event-loop coordination, excluding tasks | 206,883,370 | 0.6812% | 1,133 |
| Frame preparation, excluding measured children | 196,606,469 | 0.6474% | 381 |
| HTML response decoding and navigation parsing | 183,705,630 | 0.6049% | 1 |
| Viewport relayout coordination | 179,713,859 | 0.5918% | 10 |
| Normal flow layout | 168,403,145 | 0.5545% | 13 |
| Process startup before/between instrumented roots | 163,553,915 | 0.5386% | — |
| Layout tree construction | 154,406,446 | 0.5084% | 11 |
| HTML rendering task, excluding measured children | 151,188,189 | 0.4978% | 353 |
| Native bitmap setup/finalization outside V frame | 143,846,137 | 0.4737% | 381 |
| Native replay wrapper/checkpoints, remaining work | 118,680,476 | 0.3908% | 381 |
| Paint command recording | 117,351,047 | 0.3864% | 18 |
| Apply JavaScript document state | 100,531,279 | 0.3310% | 758 |
| JavaScript runtime setup, excluding measured children | 81,032,450 | 0.2668% | 1 |
| Initial resource preload planning/installation | 67,292,367 | 0.2216% | 1 |
| Native layer publication and transactions | 63,023,316 | 0.2075% | 381 |
| Browser chrome | 58,914,959 | 0.1940% | 388 |
| Document installation, including HTML/navigation work | 58,025,428 | 0.1911% | 1 |
| HTML rendering opportunity scheduling | 39,824,274 | 0.1311% | 381 |
| Animation driver | 36,247,412 | 0.1194% | 381 |
| Other layout geometry | 34,921,258 | 0.1150% | 13 |
| Other HTML tasks | 33,812,375 | 0.1113% | 178 |
| Native frame graphics-context setup | 29,400,838 | 0.0968% | 381 |
| PNG encoding | 18,223,797 | 0.0600% | 1 |
| Separately traced style computation / interpolation | 8,244,181 | 0.0271% | 29 |
| HTML posted-message tasks | 6,072,584 | 0.0200% | 17 |
| Document snapshot | 5,882,975 | 0.0194% | 1 |
| Relative-position offsets | 2,277,575 | 0.0075% | 13 |
| HTML timer tasks | 803,254 | 0.0026% | 5 |
| Snapshot pixel conversion | 48,279 | 0.0002% | 1 |
| **Total** | **30,368,705,509** | **100%** | |

All 41 rows sum exactly: **29,656,636,178 root-process instructions plus
712,069,331 coalition/endpoint remainder equals 30,368,705,509**. Native bitmap
and presentation rows exclude V frame children; they do not duplicate the 6.84B
raster count. Inclusive counts overlap and must not be added. See the
[full CSV](performance/chatgpt-load-stages-refined-traced-20261106.csv) and
[JSON](performance/chatgpt-load-stages-refined-traced-20261106.json).

Scope remains exclusive-coalition creation through encoded document PNG, using
the original SOCKS fixture and scripts, private profiles/caches, 1024×768 viewport,
scale two and unfocused five-second settle. No new live download is made.
OS filesystem/shader caches are retained; GPU execution and outside-coalition
services are excluded. Process scopes include concurrent threads and tracer
work. The residual includes startup, native platform/event-loop and concurrent
activity outside measured scopes. These are CPU instructions, not network wait
or isolated navigation/rendering time.

The canonical executable SHA-256 is
`2108b479b0b4af86534077ae60bb8e7851ec19c4c1c8f76c58432d07d827d452`.
The shared worker publishes a **single C unit with explicit V `-prod`**, with
**C O2, full LTO and inline threshold 75** in its sealed compiler command.
This differs from the previous parallel build/source conditions. These counts
are not an optimization comparison or a rescaling of the prior 29.915B table.
The untraced reference is **28,957,081,479 instructions**; traced/untraced frame
checkpoints are **381/425**. No normalization or calibrated tracer-overhead claim
is made.

The receipt begins at `ae97a4d456afa662af57b87005d7192d5ba2d0d6`, verifies at
`aac02463bfd1d01227cbddf0c00831e1789639dd` and records after-build head
`bc97e794141d0df8d2769992db2b2fc0bb9ba18d`. All three aggregate build-input hashes
are identical. The source commit occurs after the verified-head metadata read;
all 17 focused source/test blobs match the after-build head exactly. SHA-verified
sealed preprocessed compiler input supplies excerpts of the native finally
wrappers, scalar ABI and HTML task/loop functions. Actual events prove all new
required paths execute. The latest completed matching bundle is reused under a
nonblocking shared publication lease, released after capture. No extra build
request or app/source-tree copy is made.

All four captures (traced Vox, two Brave references, untraced Vox) pass bootstrap,
complete content/button identity, unchanged per-engine pixels and normal exits.
Executable/native-library/resource/tool identities remain stable. Per-engine
stability does not imply cross-browser pixel equality. The generic driver mixes
traced/untraced variants and exits one for the unmet Brave threshold; its summary
is retained without acceptance interpretation. The diagnostic controller and
guard exit zero over **47.38 seconds**, peaking at **2,057,682,944 sampled RSS
bytes** under 12 GiB and adopting 14 process identities without error. One-minute
host load spans **7.10–8.92 on 18 CPUs**.

All **36 final focused jobs** pass: twelve compilations and twenty-four executions,
with **336 authenticated test-function calls**, across ordinary GC, no GC,
poisoned preallocation and address/undefined-behavior sanitizers, with tracing
both on and off. Tests cover native token/JavaScript restoration, worker
exclusion, callback nesting, early returns, Objective-C exceptions, callback
unregistration during a live scope, existing frame/capture/scale ownership,
navigation origin/readiness, initial image preload and HTML task ordering,
pausing, step-one callbacks and VM generation. Every final trace is balanced,
PID-owned and monotonic. The focused controller and guard exit zero over
**299.07 seconds**, peaking at **9,083,551,744 sampled RSS bytes** under 12 GiB;
runtime guards use 3 GiB.

The first focused attempt crashes in PNG decoding under the harness's unbounded
preallocation `v_realloc`. Starting the staged compiler from the repository root
selects the wrong builtin runtime. The corrected harness compiles from the
staged compiler directory, sets `VEXE` explicitly and verifies bounded copy code
in generated C before each preallocation/sanitizer execution. No engine allocator
change is made. The original failed source, C, stack, preceding successful jobs
and exit 139 are retained without whole-run pass credit. Final checks use the
bounded production-compatible allocator. Earlier results retain their original
compiler setup and are not silently relabeled.

The first finalizer expects an unparenthesized shift; V emits casts/parentheses.
That failure is retained, the predicate is corrected against sealed C, and the
finalizer succeeds without rerunning any browser capture. Independent parsing
reproduces every row and the exact endpoint; every published LF CSV row matches
JSON, while raw archived exports keep their original bytes. The
[focused receipt](performance/chatgpt-load-stages-refined-focused-20261106.json),
[production diagnostic](performance/chatgpt-load-stages-refined-production-r1-diagnostic-20261106.json)
and [verification receipt](performance/chatgpt-load-stages-refined-verification-20261106.json)
link raw commands, logs, counters, original PNGs, guards, actual exits, compiled
runners and failures. **Optimization credit and broad-check carry remain zero;
the Brave target remains unmet.**


## Raster-phase budget and bounded tracing (2026-11-06)

Implementation `cbb5b5cff` partitions raster replay into stationary-cache
eligibility/lookup, viewport planning, tile setup, scroll-damage lookup, command
dispatch, final GPU/CPU canvas handling and storage/publication. It also measures
timer delivery, tab-frame coordination and native window initialization outside
the old document-frame scope. Boundaries are opt-in and retain the original
rendering/resource/script policy.

The **55-stage diagnostic totals 30,551,514,602 instructions**. The largest single
row is **paint-command dispatch: 5,652,377,055 (18.5011%) over 19 passes**. It
includes native drawing/grouping/culling and any unseparated native work called
there. Final canvas synchronization/closing layers adds **718,200,266 (2.3508%)**.
Together these two rows account for **6,370,577,321 instructions**. The trace has
478 frame callbacks; 19 command passes can include retry attempts and do not
mean 19 unique changed/presented frames. No displayed-FPS inference is made.

Viewport planning (1,004,650), tile setup (4,115,307), stationary eligibility
(25,241,181) and stationary lookup self work (52,706,927) are much smaller than
command dispatch on this workload. The additive raster sub-buckets, including
the remaining wrapper and blank/scroll/storage paths, sum to **6,861,063,859**.
These are subdivisions within the new capture, not a scaling of the preceding
6.84B lead. **JavaScript-related scopes total 8,755,929,487 (28.6596%)**. The
broader main residual is still **3,013,123,881 (9.8624%)** and remains explicitly
unattributed. It includes activity outside measured scopes, concurrent threads
and tracer overhead; it is not a pure native-platform or JS total.

| Stage (measured children subtracted) | Instructions | Share | Calls |
| --- | ---: | ---: | ---: |
| Paint-command dispatch and native drawing | 5,652,377,055 | 18.5011% | 19 |
| Async JavaScript module compilation, execution and bindings | 5,057,918,889 | 16.5554% | 288 |
| Document style updates | 4,407,764,122 | 14.4273% | 951 |
| Other JavaScript evaluation, callbacks and bindings | 3,698,010,598 | 12.1042% | 1,846 |
| Other browser startup / native event-loop work (residual) | 3,013,123,881 | 9.8624% | 1 |
| Absolutely positioned descendants | 2,253,985,838 | 7.3777% | 13 |
| GPU/CPU canvas synchronization and finalization | 718,200,266 | 2.3508% | 19 |
| Owned helpers + process/coalition endpoint remainder | 689,644,695 | 2.2573% | — |
| Platform timer delivery, excluding measured children | 649,471,499 | 2.1258% | 2,591 |
| CSS parsing / stylesheet conversion | 557,350,895 | 1.8243% | 11 |
| Background resource completion, excluding measured children | 315,923,271 | 1.0341% | 478 |
| HTML networking task, excluding measured children | 295,790,154 | 0.9682% | 581 |
| Document layout coordination | 235,812,623 | 0.7719% | 941 |
| Frame setup / completion, excluding measured children | 212,850,585 | 0.6967% | 478 |
| HTML response decoding and navigation parsing | 182,339,750 | 0.5968% | 1 |
| Frame preparation, excluding measured children | 178,526,636 | 0.5843% | 478 |
| Viewport relayout coordination | 177,980,238 | 0.5826% | 10 |
| Normal flow layout | 164,951,212 | 0.5399% | 13 |
| Stationary raster finalization | 164,835,158 | 0.5395% | 478 |
| Process startup before/between instrumented roots | 159,288,514 | 0.5214% | — |
| HTML rendering task, excluding measured children | 158,736,741 | 0.5196% | 459 |
| HTML event-loop coordination, excluding tasks | 153,008,187 | 0.5008% | 1,298 |
| Layout tree construction | 149,997,415 | 0.4910% | 11 |
| Document raster replay, caches, filters and compositing | 123,184,129 | 0.4032% | 478 |
| Paint command recording | 120,830,592 | 0.3955% | 21 |
| Native replay wrapper/checkpoints, remaining work | 110,329,746 | 0.3611% | 478 |
| Apply JavaScript document state | 78,556,300 | 0.2571% | 952 |
| Native window/context initialization | 72,334,986 | 0.2368% | 1 |
| Initial resource preload planning/installation | 66,934,910 | 0.2191% | 1 |
| Native bitmap setup/finalization outside V frame | 63,285,879 | 0.2071% | 478 |
| Scroll-raster lookup and damage setup | 61,917,536 | 0.2027% | 19 |
| JavaScript runtime setup, excluding measured children | 61,146,877 | 0.2001% | 1 |
| Document installation, including HTML/navigation work | 56,834,269 | 0.1860% | 1 |
| Browser chrome | 54,590,565 | 0.1787% | 486 |
| Native layer publication and transactions | 53,012,119 | 0.1735% | 478 |
| Stationary raster lookup, excluding eligibility | 52,706,927 | 0.1725% | 471 |
| Tab-frame coordination, excluding document frame | 48,979,058 | 0.1603% | 478 |
| Raster storage/retirement and deferred publication | 38,552,703 | 0.1262% | 19 |
| HTML rendering opportunity scheduling | 38,320,845 | 0.1254% | 478 |
| Other layout geometry | 33,016,198 | 0.1081% | 13 |
| Animation driver | 30,927,385 | 0.1012% | 478 |
| Other HTML tasks | 27,443,885 | 0.0898% | 236 |
| Stationary raster command eligibility | 25,241,181 | 0.0826% | 471 |
| Native frame graphics-context setup | 24,119,003 | 0.0789% | 478 |
| Raster-frame setup, excluding measured children | 18,550,597 | 0.0607% | 19 |
| PNG encoding | 18,202,177 | 0.0596% | 1 |
| Separately traced style computation / interpolation | 7,412,163 | 0.0243% | 29 |
| Document snapshot | 5,836,687 | 0.0191% | 1 |
| HTML posted-message tasks | 4,145,418 | 0.0136% | 18 |
| Raster tile/image-decode setup | 4,115,307 | 0.0135% | 19 |
| Relative-position offsets | 1,118,892 | 0.0037% | 13 |
| Viewport raster plan check/update | 1,004,650 | 0.0033% | 19 |
| HTML timer tasks | 550,118 | 0.0018% | 5 |
| Blank stationary-raster lookup | 378,350 | 0.0012% | 7 |
| Snapshot pixel conversion | 46,928 | 0.0002% | 1 |
| **Total** | **30,551,514,602** | **100%** | |

Every row reconciles: **29,861,869,907 process instructions plus 689,644,695
coalition/endpoint remainder equals 30,551,514,602**. Inclusive values overlap
and must not be added. See the [55-stage CSV](performance/chatgpt-raster-stages-traced-20261106.csv)
and [JSON](performance/chatgpt-raster-stages-traced-20261106.json). The GPU-labelled
row measures CPU instructions around canvas synchronization/finalization; actual
GPU execution remains excluded. Input-delivery instrumentation is present, but
this capture observes no entries in that path and assigns it no separate cost.

### Tracer ownership correction and focused verification

Adding the timer scope exposes a diagnostic allocation problem: V interpolation
for each record accumulates **77,826 arena bytes**, failing the existing unchanged
**<8,192-byte** cooperative-timer bound. The logger now sends PID, IDs, counter,
and explicit-length label bytes directly to C stdio. It makes no V-arena string
for a record, and the original bound passes with tracing on and off. This is a
tracer correction, not an engine instruction optimization. `uint` replaces an
initial deprecated `usize` spelling rejected by production preflight.

A new ownership case retires both allocation owners from nested timer callbacks
and checks callback ordering, payload readability and complete arena retirement.
The final selected checks compose **36 passing jobs from r4** with **47 isolation
jobs from r9**: **83 jobs, thirteen compilations and seventy fresh executions**.
Generated-C runner/dispatch authentication proves **108 original test functions
run once in each of four GC/storage modes and both tracing settings: 864 original
test-function executions**. Dispatcher helpers earn no extra test credit. Modes
are ordinary GC, no GC, poisoned preallocation and address/undefined-behavior
sanitizers. Every final trace has monotonic counters, balanced nesting and one
PID. The existing timer allocation threshold and all runtime caps stay unchanged.

The original combined native sanitizer process exceeds 3 GiB. A tab-only process,
then half of its cases in one process, also exceed that cap. The final sanitizer
route runs all **23 tab cases individually**, in both trace settings, using one
compiled dispatcher that calls the unchanged canonical test bodies. Generated
main calls only that dispatcher, its body contains exactly all 23 original calls,
and each process logs its selected case's start/end. Every isolated execution
passes, with maximum sampled RSS **1,067,466,752 bytes**, below 3 GiB. This proves
per-case sanitizer coverage; it does not claim the earlier combined batches fit
within the cap or establish aggregate leak freedom across those batches.

All partial attempts remain retained: initial fixture mutability compilation
errors; the original arena-bound failure; the combined/tab/half-tab guard kills;
a wrong case-count preflight; and dispatcher preparation that explicitly included
disabled GG or Linux files. The final route makes the canonical tab test the
primary source and supplies only the dispatch fixture as an additional input,
letting V apply its normal platform/feature selection. No test body is copied,
modified, skipped or replaced with a stub. The final source hashes are identical
across the composed r4/r9 selections. The original failed controller exits remain
visible and are not presented as whole-run passes.

### Raster capture identity and limits

The latest completed matching canonical bundle has executable SHA-256
`e843423715b8f606d48616c9038b79f335cfb34cb1fa06d61ca105755598495b`, using a
single C unit and explicit V `-prod`; the sealed compiler command records O2,
full LTO and inline threshold 75. Before/verified heads are
`6e1874edca549e0dc9981387454ea7159a389365`; after-build head is
`b443fb926a3e4d67c7ba5cdce64cf3ba8e0db4fc`. Aggregate build-input hashes match.
The raster/logger source is captured before its final Git commit while the last
sanitizer cases finish. All nine captured implementation source files match the
final tested/committed bytes exactly. SHA-verified sealed preprocessed compiler
input contains the C logger and raster/timer/tab boundaries, and actual events
prove their execution. Receipt-head timing alone is not claimed as source proof.

All four captures (traced Vox, two Brave references, untraced Vox) pass bootstrap,
complete content/button identity, unchanged per-engine pixels and normal exits.
App/native-library/tool/fixture identities stay fixed under a nonblocking shared
publication lease, released afterward. No app/source-tree copy or extra build
request is made. The untraced reference counts **28,631,574,024 instructions**;
traced/untraced frame checkpoints are **478/479**. Differences do not calibrate
tracer overhead or establish engine savings. Instrumentation, scheduling and
other shared source/build changes prevent causal comparison with older captures.

The original frozen SOCKS archive, original author scripts, fresh private profiles
and caches, 1024×768 viewport, scale two, unfocused five-second settle and PNG
endpoint remain unchanged. No new live download is made. Scope includes startup,
window setup, audit/capture work and settling through encoded PNG, with existing
per-engine delivery/teardown qualifications. OS filesystem/shader caches remain
retained. Process intervals include concurrent threads and logging; external
services and GPU execution remain excluded. Counter totals describe CPU work,
not elapsed network waiting time, isolated VM cost, rendering time or scrolling.

The production controller and memory guard exit zero over **40.14 seconds**,
peaking at **2,052,489,216 sampled RSS bytes** under 12 GiB and adopting 14 process
identities without an error. Host one-minute load is **4.22–4.42 on 18 CPUs**.
The generic comparison driver mixes instrumented/uninstrumented variants and
returns one for the unmet Brave threshold; its raw result gets no acceptance
interpretation. The independent finalizer authenticates all source/runner groups,
raw logs, counters, PNGs, guards, actual exits and exact additive endpoints.
The [focused receipt](performance/chatgpt-raster-stages-focused-20261106.json),
[production diagnostic](performance/chatgpt-raster-stages-production-r1-diagnostic-20261106.json)
and [verification receipt](performance/chatgpt-raster-stages-verification-20261106.json)
retain those artifacts and every failed development attempt. **Optimization credit
and broad-check carry remain zero; the 5%-below-Brave target remains unmet.**

## 20B target, paint boundaries and transparent picture-cache experiment (2026-11-06)

The requested target is now **20,000,000,000 instructions** for the existing frozen ChatGPT launch-through-encoded-document-PNG workload. It remains unmet. This experiment uses the original SOCKS capture and author scripts, private profiles, 1024×768 viewport at scale 2, five-second unfocused settle, unchanged content audits and per-engine pixel references. No new live download occurred.

The pinned production executable is `86088fc0d93210cfdd8dcf4a60bed2a686d469fc1f68e4fd774a36867072c706` (single C unit, V `-prod`, existing O2/full-LTO configuration). Its native picture-cache prototype is compared with its own uncached path; all other code and libraries stay identical. The final opt-in policy is a later change and is verified separately by native tests.

| Untraced variant | Instructions, all four retained trials | Median |
| --- | --- | ---: |
| Uncached control | 28,370,885,450, 28,625,179,310, 28,244,585,034, 28,213,601,111 | 28,307,735,242 |
| Picture-cache prototype | 28,384,084,156, 28,093,519,327, 28,391,441,464, 28,272,716,090 | 28,328,400,123 |

The candidate median is **0.0730% higher**. The conservative separation is **-177,840,353 instructions**; the ranges overlap. Credit and broad-check carry remain **zero**, so no new broad checkpoint is due. The uncached control median is still **8,307,735,242 instructions above 20B**. All 20 diagnostic/matched browser captures pass bootstrap, complete content identity, exact retained pixels and normal browser exits. Both comparison drivers return 1 for the unmet Brave target; their successful capture wrappers/controller return 0. Four candidate trials do not constitute seven-pair acceptance.

`ee1be20e6` caches only successfully completed transparent picture rasters before current-backdrop composition. Its key owns serialized paint bytes and all raster geometry; exact equality, bounded entries/storage, padded rows, image mutations and release are checked. The production diagnostic records actual reuse. The page count provides no instruction gain, so `dbc3f5400` makes it **opt-in** with `VOX_ENABLE_PICTURE_RASTER_CACHE=1`; it is not an accepted default optimization.

`3a2f05b8c` independently fixes a sanitizer-detected NaN/out-of-range height conversion before raster-grid arithmetic. Its 22 valid/invalid native cases pass in both cache/control modes. Final cache checks pass ASan/UBSan: two vector/scalar snapshot unit modes, 48 exact current-backdrop/grid/phase/image/mutation scenes, 144 existing compositor pictures, 22 extent cases and 44 deferred-layer ownership/failure scenes. The later opt-in/default bypass checks also pass. Two nonblocking publication leases launch no runtime; a subsequent available-bundle check passes with library hashes verified before/after. No app or library copy is used.

`52223dfd4` adds separate paint-leaf, grouped-operation and compositor-transition scopes. Enabled checks caught repeated V environment-string allocations; the flag lookup now borrows the native environment value and preserves dynamic unset/empty/nonempty behavior. All 24 final diagnostic check jobs pass across four GC/storage modes with tracing enabled/disabled, including poisoned preallocation and ASan/UBSan. Failed fixture/driver/link attempts and the sanitizer finding remain archived.

The existing wall-time leaf lead includes a transition before the command; it cannot assign that cost to a rectangle. The existing GPU deferred-layer experiment produces no actual GPU layer composites, while the retained-tile experiment has misses but no cache hits. Both retain exact page pixels and receive no performance credit.

The following **63-row additive table** is the traced prototype candidate, totaling **28,828,843,071 instructions**, rather than the untraced median. JavaScript module completion plus JS execution/bindings totals **8,925,433,977**. Nested native work is subtracted from its JS parent. Tracing and concurrent-thread work remain in these process-counter intervals; inclusive columns overlap and must not be added. The process/coalition endpoint remainder is explicitly unassigned. No counts are scaled to 29B or to the untraced median.

| Stage | Calls | Exclusive instructions | Share | Inclusive instructions |
| --- | ---: | ---: | ---: | ---: |
| `javascript_module_completion` | 289 | 5,254,105,972 | 18.2252% | 8,177,646,590 |
| `style_update` | 286 | 3,724,352,503 | 12.9188% | 3,736,528,036 |
| `javascript_execution_and_bindings` | 1,757 | 3,671,328,005 | 12.7349% | 5,013,175,085 |
| `browser_main` | 1 | 2,843,623,225 | 9.8638% | 27,921,765,660 |
| `paint_layer_transition` | 145 | 2,618,300,810 | 9.0822% | 2,618,300,810 |
| `absolute_positioned_layout` | 13 | 2,276,223,094 | 7.8956% | 2,276,223,094 |
| `coalition_endpoint_remainder` | 0 | 728,289,869 | 2.5263% | — |
| `gpu_frame_finalization` | 13 | 686,586,669 | 2.3816% | 686,586,669 |
| `paint_leaf_text` | 290 | 644,663,158 | 2.2362% | 644,663,158 |
| `paint_leaf_shadow` | 35 | 578,060,348 | 2.0051% | 578,060,348 |
| `platform_timer_delivery` | 1,748 | 577,621,161 | 2.0036% | 11,554,501,259 |
| `css_parsing` | 11 | 560,997,153 | 1.9460% | 560,997,153 |
| `paint_leaf_fill` | 204 | 552,110,960 | 1.9151% | 552,110,960 |
| `paint_leaf_border` | 97 | 494,629,487 | 1.7157% | 494,629,487 |
| `paint_leaf_svg` | 198 | 391,291,293 | 1.3573% | 391,291,293 |
| `html_networking_task` | 581 | 284,787,206 | 0.9879% | 8,522,746,089 |
| `background_resource_completion` | 163 | 284,007,402 | 0.9852% | 4,562,608,316 |
| `paint_command_dispatch` | 13 | 220,675,465 | 0.7655% | 5,665,598,870 |
| `viewport_relayout` | 10 | 190,557,172 | 0.6610% | 3,672,786,493 |
| `navigation_html_parsing` | 1 | 182,963,339 | 0.6347% | 182,963,339 |
| `document_layout` | 275 | 178,069,563 | 0.6177% | 4,326,969,193 |
| `flow_layout` | 13 | 168,701,827 | 0.5852% | 168,701,827 |
| `paint_leaf_effect_end` | 44 | 164,168,500 | 0.5695% | 164,168,500 |
| `unscoped_process` | 0 | 160,144,121 | 0.5555% | — |
| `layout_tree_construction` | 11 | 156,007,587 | 0.5412% | 156,007,587 |
| `html_event_loop` | 880 | 115,225,829 | 0.3997% | 10,971,997,361 |
| `paint_command_recording` | 15 | 112,100,222 | 0.3888% | 112,100,222 |
| `stationary_raster_finish` | 163 | 89,805,546 | 0.3115% | 89,805,546 |
| `html_rendering_task` | 126 | 75,825,989 | 0.2630% | 2,226,941,642 |
| `native_window_initialization` | 2 | 72,148,594 | 0.2503% | 72,148,594 |
| `initial_resource_preload` | 1 | 68,754,198 | 0.2385% | 371,376,525 |
| `frame` | 163 | 68,341,810 | 0.2371% | 13,359,637,917 |
| `frame_preparation` | 163 | 66,520,678 | 0.2307% | 6,638,887,734 |
| `script_runtime_setup` | 1 | 61,076,604 | 0.2119% | 1,077,705,314 |
| `document_install` | 1 | 57,832,469 | 0.2006% | 2,961,716,615 |
| `script_state_replay` | 322 | 46,910,016 | 0.1627% | 1,588,401,167 |
| `native_raster_replay` | 163 | 37,195,085 | 0.1290% | 6,589,935,959 |
| `layout_geometry` | 13 | 33,608,278 | 0.1166% | 2,479,690,449 |
| `browser_chrome` | 174 | 30,457,227 | 0.1056% | 30,457,227 |
| `scroll_raster_probe` | 13 | 30,397,496 | 0.1054% | 30,397,496 |
| `raster_frame_commit` | 13 | 29,936,686 | 0.1038% | 31,290,374 |
| `native_frame_bitmap` | 163 | 29,129,027 | 0.1010% | 13,478,170,984 |
| `native_document_replay` | 163 | 27,176,926 | 0.0943% | 6,625,717,494 |
| `native_frame_presentation` | 163 | 22,342,932 | 0.0775% | 13,500,513,916 |
| `stationary_raster_probe` | 156 | 19,016,506 | 0.0660% | 27,763,992 |
| `png_encoding` | 1 | 18,223,809 | 0.0632% | — |
| `html_other_task` | 149 | 17,973,505 | 0.0623% | 81,590,594 |
| `browser_tab_frame` | 163 | 17,331,420 | 0.0601% | 13,376,969,337 |
| `raster_frame_setup` | 13 | 16,747,934 | 0.0581% | 50,947,041 |
| `html_rendering_opportunity` | 163 | 14,391,229 | 0.0499% | 14,391,229 |
| `animation_driver` | 163 | 13,609,262 | 0.0472% | 13,609,262 |
| `stationary_raster_eligibility` | 156 | 8,747,486 | 0.0303% | 8,747,486 |
| `native_frame_context` | 163 | 8,604,609 | 0.0298% | 8,604,609 |
| `style_computation` | 29 | 7,547,827 | 0.0262% | 7,547,827 |
| `capture_snapshot` | 1 | 5,895,587 | 0.0205% | — |
| `html_posted_message_task` | 18 | 4,239,431 | 0.0147% | 22,954,742 |
| `raster_tile_setup` | 13 | 3,122,068 | 0.0108% | 3,122,068 |
| `paint_leaf_effect_begin` | 44 | 3,052,537 | 0.0106% | 3,052,537 |
| `relative_positioned_layout` | 13 | 1,157,250 | 0.0040% | 1,157,250 |
| `stationary_blank_probe` | 7 | 748,382 | 0.0026% | 748,382 |
| `viewport_raster_plan` | 13 | 679,543 | 0.0024% | 679,543 |
| `html_timer_task` | 7 | 654,906 | 0.0023% | 2,698,020 |
| `capture_conversion` | 1 | 48,279 | 0.0002% | — |
| **Total (exclusive)** | | **28,828,843,071** | **100%** | |

The [verification receipt](performance/chatgpt-picture-cache-verification-20261106.json) links every authenticated archive, exact raw instruction count, command, guard, PNG, source witness, host condition and actual exit. The [candidate table](performance/chatgpt-picture-cache-candidate-stages-20261106.csv) and [control table](performance/chatgpt-picture-cache-control-stages-20261106.csv) are machine-readable. **The 20B target and the original 5%-below-Brave target remain open.**

## Lazy Wasm module lexer toward 20B (2026-11-06)

`c43317438` lazily initializes the pinned es-module-lexer 1.7.0 Wasm implementation when a specifier actually needs lexing. Keyword-free scripts initialize neither lexer. The original asm build remains available with `VOX_RETAIN_ASM_MODULE_LEXER=1` and is the fallback when Wasm is unavailable or initialization fails. The module declarations, linking, live bindings, cycles, author-script bytes and native JavaScriptCore backend remain unchanged.

The Wasm implementation reuses the exact strict string-literal decoder from the retained asm distribution. Its upstream eval-based decoder did not preserve every existing escape/error behavior; the failed candidate and its module/import-map errors are retained. Native Wasm constructors and instance/memory/global accessors are captured before author replacement. The private fixed-payload decoder adds no global Buffer/atob dependency. No runtime network request is added. The npm archive integrity, matching original asm bytes/license and pinned Wasm hash are recorded.

All **293 captured JavaScript responses (3,610,641 bytes)** produce byte-identical rewritten output in the actual native Runtime. These include archived resources outside any particular page execution path, so their component totals are not a page attribution. The separate fresh system-JSC CLI lexer comparison also has identical structural output.

| Native rewrite component, browser warm-up 10,000 | asm median | Wasm median | Reduction |
| --- | ---: | ---: | ---: |
| Factory creation | 7,563,185 | 7,568,128 | -0.0654% |
| First corpus rewrite, including lazy initialization | 11,812,075,210 | 5,844,158,200 | 50.5239% |
| Five warm corpus rewrites | 58,926,864,320 | 28,879,633,612 | 50.9907% |

The factory/cold/warm intervals exclude Runtime construction and corpus reads; they include V/JS conversion, the existing keyword filter, strict decoding, rewriting, and concurrent process-thread work. Factory construction slightly regresses and is retained. The system-default-JIT cohort, original CLI lead, oracles, checksums and all guarded processes remain archived. No component result receives whole-page credit.

Final focused selections pass **32 guarded jobs / 276 test-function executions**: normal GC, no GC, poisoned preallocation and ASan/UBSan, each with Wasm, retained asm and engine-disabled Wasm. They cover lazy initialization, escaped/invalid literals, unavailable/rejected Wasm, replaced constructors/accessors, linear-memory growth, native import maps/cycles/top-level-await, concurrent native transport, classic dynamic imports and module/classic worker ownership.

`2aae223d7` corrects the worker retention fixture: its receiving sender Runtime was itself created in the scratch arena that the test deliberately retired. Both the Wasm and retained-asm controls faulted on that fixture. The receiving Runtime now shares the persistent fixture lifetime; the agent payloads still cross both retired scratch arenas and every ownership assertion remains. Two earlier fixture/driver compile errors, disabled-Wasm fixture assumptions and the decoder mismatch are also retained.

| Untraced frozen-page variant | All four retained instruction counts | Median |
| --- | --- | ---: |
| Retained asm control | 28,175,907,519, 27,819,624,822, 27,686,796,850, 28,398,629,584 | 27,997,766,170 |
| Lazy Wasm candidate | 27,685,872,840, 27,587,051,242, 27,785,065,572, 26,840,437,789 | 27,636,462,041 |

The page median is **1.2905% lower**, but the conservative separation is **-98,268,722 instructions**, so the observed ranges overlap. Page credit, broad carry and cadence reset remain **zero**; no new 5M checkpoint is due. All **20** diagnostic/matched captures pass complete content/bootstrap identity, unchanged pixel references and normal browser exits. Separate candidate markers prove Wasm consumption without fallback, while control markers prove actual asm execution. The comparison drivers return 1 for the failed Brave threshold; guarded capture/controller wrappers return 0. Four candidate/control pairs are diagnostic, below seven-pair acceptance.

The measured production executable is `03bdf80d7cdd730a593b9a840cd086ddf35771bdf7a6cdd8f82a2f43ec44f41a` with its single-unit V `-prod` build receipt and pinned native libraries. The original SOCKS capture, five-second unfocused settle, viewport 1024×768 at scale 2, fresh profiles and encoded-document-PNG endpoint are unchanged. OS filesystem/shader caches remain warm; GPU work and outside-coalition services remain excluded. Host load and frame/checkpoint counts are retained in the raw logs rather than normalized away.

The candidate median remains **7,636,462,041 instructions above the 20B target**. This later cohort does not retroactively alter the preceding 63-row table, which belongs to its separately pinned instrumented executable. The [verification receipt](performance/chatgpt-wasm-lexer-verification-20261106.json) links every counter, source witness, PNG, guard, failure and authenticated archive. **Both the 20B goal and the original 5%-below-Brave goal remain unmet.**

## JIT warm-up retune with Wasm lexing (2026-11-06)

An unchanged production executable tests baseline JIT warm-up 500 against the current 10,000 default, with the new Wasm lexer active in both variants. Separate native option dumps confirm the actual thresholds; both diagnostic markers confirm Wasm consumption without fallback. This is a parameter experiment, with **no source change**.

| Warm-up | All four retained launch-through-PNG instruction counts | Median |
| --- | --- | ---: |
| 10,000 control | 27,556,826,297, 27,523,486,496, 28,078,183,661, 27,902,188,569 | 27,729,507,433 |
| 500 candidate | 27,106,339,036, 27,335,635,957, 28,188,922,531, 28,138,988,313 | 27,737,312,135 |

The candidate median is **0.0281% higher**. The conservative separation is **-665,436,035 instructions**, so the observed ranges overlap. Keep the 10,000 default; page savings credit and broad cadence stay zero. All 20 diagnostic/matched captures pass the complete content/bootstrap audit, exact unchanged pixel references and normal browser exits. Four control/candidate pairs are diagnostic, below acceptance requirements. The Brave threshold and 20B goal remain unmet.

Executable `ee6ae85297215e158de7326a57b72649c0aaf0706a6cf0dee90c1e7de4ed9563` uses the retained single-unit V `-prod` build. One nonblocking shared publication lease pins the canonical bundle/native libraries throughout. The original one-time SOCKS fixture, author scripts, private profiles/caches, five-second unfocused settle and 1024×768 scale-two document capture remain unchanged. OS filesystem/shader caches are retained; GPU work/outside-coalition services are excluded. Native option dumps occur only in the separate diagnostic. All counters, host loads, scripts, guards, identity proofs, audits and PNGs are preserved by the [verification receipt](performance/chatgpt-jit-retune-verification-20261106.json).

## Native UTF-16 module-source copy toward 20B (2026-11-06)

`c8ae81d78` replaces the Wasm lexer embedding's per-character JavaScript copy with a private JavaScriptCore UTF-16 array and a captured native typed-array setter. The temporary array owns its bytes and does not escape to author code. NULs and lone surrogates remain exact; the setter is captured before author replacement and fresh views follow Wasm memory growth. The original JavaScript loop remains the fallback and the `VOX_RETAIN_JS_MODULE_LEXER_COPY=1` control. The pinned vendor distributions and author scripts are unchanged.

The first direct-pointer prototype failed: JSC withholds the movable backing store of Wasm memory. Both failed runs, their source witnesses and the diagnostic refinement are retained. The final implementation never borrows that pointer. Thread-local diagnostic state uses `VOX_NATIVE_STATE` for native-header splitting.

All **293 archived JavaScript bodies (3,610,641 bytes)** rewrite identically against the retained JavaScript-copy oracle in the actual native Runtime. Four alternating observations per variant use the browser's warm-up 10,000, production preallocation, V `-prod` and C O2. Runtime creation and corpus reads are outside the measured factory/cold/warm intervals; conversion, lexical prefiltering, rewriting and concurrent process-thread work remain inside. The corpus includes resources outside a given page execution path and uses a mock resolver; its totals are not a page attribution.

| Rewrite component | JavaScript-copy median instructions | Native-copy median instructions | Reduction |
| --- | ---: | ---: | ---: |
| Factory construction | 7,789,049 | 7,785,712 | 0.0428% |
| First corpus rewrite, including lazy initialization | 5,843,913,989 | 3,514,091,132 | 39.8675% |
| Five warm corpus rewrites | 28,886,858,176 | 17,218,819,290 | 40.3922% |

Final focused validation passes **40 guarded jobs / 432 test-function executions** across normal GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers. Each mode exercises native copy, retained JavaScript copy, retained asm lexer and disabled Wasm. Checks include code-unit preservation, independent arrays, author-hook rejection, memory growth, replaced intrinsics, full module linking/import maps/live bindings/top-level await, concurrent transport and actual module/classic worker lifetimes.

| Untraced frozen-page variant | All four retained launch-through-PNG instruction counts | Median |
| --- | --- | ---: |
| JavaScript-copy control | 27,583,250,124, 27,501,381,217, 27,223,317,847, 26,782,297,176 | 27,362,349,532 |
| Native-copy candidate | 27,537,747,469, 27,130,764,990, 27,521,736,122, 27,104,388,411 | 27,326,250,556 |

The observed median falls **0.1319%**, but conservative separation is **-755,450,293 instructions**: the ranges overlap. Page credit and broad carry remain zero, with no new 5M broad checkpoint. Every one of the **20** diagnostic/matched captures passes JavaScriptCore bootstrap, complete content/button identity, exact unchanged per-engine pixel references and normal browser exits. Separate diagnostics prove both variants consume Wasm and only the candidate executes native copies. Four candidate/control pairs remain below seven-pair acceptance.

Executable `46a1582b0e9154230c9da4467b441322cb5d2aeae8185676441e8922a296256a` and native libraries stay pinned under one nonblocking shared publication lease, using the completed single-unit V `-prod` receipt. One shared build fails source sealing because repository inputs changed and is not used; the completed successor contains the final native helper. The original one-time SOCKS capture and author scripts, fresh private profiles/caches, 1024×768 scale-two viewport and five-second unfocused settle remain unchanged. Counts run from exclusive coalition creation through encoded document PNG; OS filesystem/shader caches remain retained, and GPU work/outside-coalition services remain excluded. Host load, raw counters and all actual exits are retained. Capture/controller guards exit zero; the underlying comparison drivers return 1 for the unmet Brave threshold.

The candidate median remains **7,326,250,556 instructions above 20B**. This cohort does not revise earlier instrumented stage tables or credit the component saving to the page. The [verification receipt](performance/chatgpt-lexer-copy-verification-20261106.json) links all source, command, counter, PNG, guard, failure and authenticated archive evidence. **The 20B target and original 5%-below-Brave target remain unmet.**

## Sampled native JavaScript callbacks toward 20B (2026-11-06)

Commits `56f5eb9d0` and `4e6d0b77f` add opt-in per-binding callback diagnostics and a non-destructive report at the capture-audit boundary. Ordinary runs create no diagnostic records. Registration stacks identify anonymous bindings without reading author values; native symbol offsets are validated against the executable image. The final code passes **24 guarded jobs / 148 test-function executions** across ordinary GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers, with diagnostics both disabled and enabled. Earlier 88 passing executions remain retained.

One production diagnostic passes bootstrap, complete content/button identity, normal exit and exact unchanged pixels against the original one-time SOCKS capture. It records **185,737 callbacks and 2,950 inclusive instruction samples**. Samples cover the first call and each 64th call, and reporting follows encoded PNG and the content audit.

| Binding | Exact calls at diagnostic capture | Sampled calls | Inclusive instructions in those samples |
| --- | ---: | ---: | ---: |
| __ladybirdSerializeURLText | 46,629 | 729 | 36,929,659 |
| __ladybirdElementQuery | 25,058 | 392 | 31,277,900 |
| __ladybirdRootDocumentOwner | 51,133 | 799 | 27,942,649 |
| __ladybirdDOMTreeVersion | 49,860 | 780 | 23,348,269 |
| querySelectorAll | 799 | 13 | 3,194,580 |
| querySelector | 205 | 4 | 1,788,713 |

**These instruction samples are not an additive breakdown of the page.** Nested callbacks overlap, process threads run concurrently, systematic sampling can alias phases, and counter reads have an observed floor around 15,000 instructions. Multiplying sample means by call counts would therefore overstate costs. Exact call frequencies identify leads; no sample receives optimization credit or changes the retained stage table.

The rejected generic JSON encoder prototype, poisoned-memory failure and corrected manual report encoding remain archived. The first production preflight used the wrong Mach-O header symbol and launched no browser; the corrected diagnostic uses `__mh_execute_header`. All archives are rehashed and decompressed entry by entry. The [verification receipt](performance/chatgpt-host-callbacks-verification-20261106.json) links focused checks, source witnesses, failures and the pinned production report. The **20B target remains unmet**.

## Bounded href serialization cache toward 20B (2026-11-06)

Commit `74e3ff826` keeps successful native href serialization in a realm-private JavaScript Map keyed by the exact primitive input string and raw base. Each hit still performs String conversion, live document ownership, current URL-constructor identity and original href-getter authentication. Foreign ownership, invalid results, author overrides and oversized values retain the ordinary path. Captured Map intrinsics resist author replacement.

The cache admits at most 256 entries and 262,144 logical UTF-16 code units across keys, bases and results. Input/base limits are 2,048 units and result limit 4,096. These limits bound retained logical text, not the physical JavaScript heap. When full, the cache preserves admitted entries; changing a key's base only replaces its entry if the same budget still fits. Runtime close releases the realm. `VOX_RETAIN_UNCACHED_HREF_TEXT=1` retains the uncached control.

The initial FIFO prototype improves captured-link repetition but regresses the 320-link overflow component by about 39%. It is retained and receives no credit. The admission policy removes that cyclic eviction behavior. Four alternating component observations per variant use an actual native Runtime and the 108 hrefs extracted from the original archived HTML; setup is outside the cold/warm retired-instruction intervals.

| Component | Uncached median instructions | Cached median instructions | Reduction |
| --- | ---: | ---: | ---: |
| 108 captured hrefs, first read | 6,276,320 | 6,383,137 | -1.7019% |
| 108 captured hrefs, repeated reads | 1,179,693,856 | 672,084,173 | 43.0289% |
| 320 distinct hrefs, first read | 15,368,597 | 17,113,100 | -11.3511% |
| 320 distinct hrefs, repeated reads | 667,698,810 | 402,928,198 | 39.6542% |
| One bypassed 2,049-unit href, first read | 2,182,715 | 2,069,990 | 5.1644% |
| One bypassed 2,049-unit href, repeated reads | 3,158,712,344 | 3,163,301,878 | -0.1453% |

All **24 focused guarded jobs / 232 test-function executions** pass across normal GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers, with cache and diagnostics controls exercised. Coverage includes live adoption/reentrant ownership, pending edits, raw-base changes, constructor/getter replacement, String conversion hooks, native URL semantics, saturation, logical bounds, oversized bypasses, independent runtimes and close. The bootstrap-order dependency `9fd90822a` initializes shared intrinsics before this bootstrap; its regression test is included. The initial mock-coercion error, old-order bootstrap failures, debug-only logger, component pointer typo and native-test filename typo are preserved. The temporary logger was removed after identifying the bootstrap dependency.

Separate production diagnostics reduce native URL serializations from **46,629** to **1,852** and show a cache-hit marker only in the enabled variant. The first preflight misses the generated string declaration prefix and launches no browsers; the corrected preflight verifies the exact final JavaScript bytes against the sealed compiled string table. No reference or tolerance changes occur.

| Unprofiled frozen-page variant | All four retained launch-through-PNG instructions | Median |
| --- | --- | ---: |
| Uncached control | 27,097,178,160, 27,805,314,565, 27,810,399,045, 27,662,399,690 | 27,733,857,128 |
| Bounded-cache candidate | 26,347,498,738, 26,671,218,189, 26,177,107,040, 26,571,222,056 | 26,459,360,397 |

The observed median falls **4.5955%**; conservative observed separation is **425,959,971 instructions**. The observed four-pair reduction is separated across the retained ranges. This crosses the 5M checkpoint: all **47 broad jobs pass**, including screenshot/selection/live image and SVG mutations, native paint checks and exact 100-fixture AST comparisons in both GC modes. Broad carry resets to zero.

All **20** diagnostic/matched captures pass JavaScriptCore bootstrap, complete content/button identity, unchanged exact per-engine reference pixels and normal browser/kernel exits. Executable `f65412afd9dddae25023cc25814192b75379842d59c9f7727c26dd3e32ef6cbe` and libraries stay pinned under a shared publication lease using the latest completed single-C-unit V `-prod` bundle; no separate build is queued. The original one-time SOCKS fixture/scripts, fresh private profiles/caches, 1024×768 scale two and five-second unfocused settle remain unchanged. The scope runs from exclusive coalition creation through encoded document PNG, including startup and window setup. OS filesystem/shader caches remain retained; GPU execution/outside-coalition services remain excluded. Host load, all raw counts and actual exits are retained. The underlying comparison drivers still return 1 for the unmet Brave threshold while browser/capture/controller exits are zero.

The candidate median remains **6,459,360,397 instructions above 20B**. Four control/candidate pairs cannot establish formal seven-pair acceptance or live-site performance. Component results and sampled callback costs are not scaled into the page budget. The [verification receipt](performance/chatgpt-href-cache-verification-20261106.json) links all focused, component, source, counter, PNG, memory-guard, rejected-attempt and archive evidence. **The 20B target and original 5%-below-Brave target remain unmet.**

Frame-complete checkpoints are 433, 333, 333, 394 for controls and 323, 377, 372, 399 for candidates. Vox launch load averages span 12.58–14.69 on 18 CPUs. The fixed settle window permits frame-count variation; the retained observed reduction is not an isolated per-frame or scrolling measurement.

## Optimizing-tier experiments and current native sample (2026-11-06)

A fresh statistical stack sample of completed production executable `e81e1c454f7c699026166b48f917397dbec4a456e40cd96dd0d41d861ba5932d` passes original author bootstrap, complete content/button identity, exact unchanged reference pixels and normal exit. It observes active grid/flex/absolute-positioned layout, style, native opacity scans and actual JavaScriptCore DFG compilation. Its 1ms requested samples include waits, recursion, concurrent threads and startup/attachment gaps; the process exits before the requested 12-second ceiling with `-mayDie`. Frequencies are investigation leads and do not update the additive instruction table. No browser app, repository checkout or tool is copied, and no build is requested.

Two four-pair parameter experiments retain baseline JIT, baseline warm-up 10,000 and the Wasm lexer. Separate native option dumps verify the selected options. The first disables DFG and FTL; the second keeps all tiers enabled and raises `thresholdForOptimizeAfterWarmUp`, `thresholdForOptimizeAfterLongWarmUp` and `thresholdForOptimizeSoon` from 1,000 to 10,000. Original author scripts, SOCKS fixture, private profiles/caches, five-second unfocused settle, 1024×768 scale two and launch-through-encoded-PNG scope stay fixed. Each experiment pins one completed canonical single-unit V `-prod` executable under its own shared publication lease.

| Experiment | Control median instructions | Candidate median instructions | Median reduction | Conservative observed separation |
| --- | ---: | ---: | ---: | ---: |
| DFG/FTL disabled | 26,630,637,794.5 | 26,089,475,464.5 | 2.0321% | 346,319,842 |
| Longer DFG warm-up, all tiers enabled | 26,406,853,665.5 | 26,461,970,498.5 | -0.2087% | -1,555,989,186 |

| Experiment / variant | Every retained Vox instruction count |
| --- | --- |
| DFG/FTL disabled / control | 26,697,555,414; 26,592,928,364; 26,513,160,369; 26,668,347,225 |
| DFG/FTL disabled / candidate | 25,971,342,138; 26,166,840,527; 26,162,221,260; 26,016,729,669 |
| Longer DFG warm-up / control | 25,226,868,438; 26,455,776,408; 26,357,930,923; 26,457,276,187 |
| Longer DFG warm-up / candidate | 26,782,857,624; 26,473,521,892; 26,450,419,105; 25,637,293,959 |

The tier-disabled policy crosses the 5M checkpoint and passes all **47 broad checks**, including exact screenshots, selection, live image/SVG mutations, native paint tests and 200 exact AST comparisons. Correctness alone does not justify adopting it: the sustained probes below expose a large execution regression. Broad carry resets to zero. The longer-warm-up experiment regresses its page median and/or overlaps the control range, so it earns no instruction credit and triggers no additional broad checkpoint.

The first standalone probe is rejected despite zero runtime exits and matching checksums: it lacks the production `allow-jit` entitlement and reports no DFG compilation. Its source, commands, counters and rejection remain archived. A separately identified signed copy of that generated component binary uses the canonical entitlement; no browser bundle or repository tool is copied. Four observations per policy and three workloads retain **36 measured component rows**, plus six separate diagnostic rows. An independent periodic-integer oracle verifies all **42 checksums**, and compile-time reports prove DFG compilation of every workload in both enabled-tier policies. Runtime creation and setup are outside the synchronous API instruction intervals; concurrent process-thread work inside those intervals is included, while pending work after the final sample is outside. These components do not supply page savings.

| Sustained five-million-iteration component | Current policy median instructions | DFG/FTL disabled median | Disabled change | Longer warm-up median | Warm-up change |
| --- | ---: | ---: | ---: | ---: | ---: |
| Numeric | 149,000,106.5 | 616,877,614.0 | +314.0115% | 113,927,879.0 | -23.5384% |
| Array | 83,916,154.5 | 540,417,667.0 | +543.9972% | 85,464,959.0 | +1.8457% |
| Objects | 135,983,161.0 | 620,396,834.0 | +356.2306% | 138,294,431.0 | +1.6997% |

The longer-warm-up cold 100,000-iteration components also regress **9.23% numeric, 2.86% array and 6.25% object**. Disabling optimizing tiers makes sustained work use about **4.1–6.4×** the instructions. Both parameter proposals are rejected; **the browser keeps all JIT tiers and its existing warm-up defaults**. Standalone component claims without a JIT entitlement/path receipt cannot establish production-tier costs, even when their checksums and exit codes pass. Independently verified same-executable browser comparisons remain separate.

All **40** diagnostic/matched browser captures pass full content, JavaScriptCore bootstrap, unchanged per-engine pixels and normal browser/kernel exits. Capture/controller guards exit zero; comparison drivers return one for the unmet Brave threshold. Host contention and frame checkpoints remain in the raw evidence. The two experiments use different completed executable identities (`065088847096502fc917a23c0d8231e9344e1edb7baa2bfbb2a38185fa99d97d` and `af59afe1347543bc6ba3db97a9c19e17fda817c629f7fa416597c3d4b6762a9a`); their absolute counts are never pooled or attributed across builds. OS filesystem/shader caches remain retained, and GPU work/outside-coalition services remain excluded.

The [verification receipt](performance/chatgpt-jit-policy-verification-20261106.json) links the sample, option probes, all raw counts, complete reports, source/identity proofs, guard exits, rejected probe and authenticated evidence archives. Neither experiment changes engine defaults or earns page instruction credit. The last adopted href-cache comparison remains 26.46B on its own pinned build. **The 20B target and original 5%-below-Brave target remain unmet.**

## Rooted native module source strings toward 20B (2026-11-06)

Commit `c0d43ac78` supplies transformed JavaScript strings directly to native module construction. The old path copies a JSC UTF-16 result into V UTF-8, then Foundation decodes those bytes back into a native string. The new path roots the primitive result, copies its UTF-16 code units into owned NSString storage, and retains that ownership through script construction and a possibly reentrant resolve call. No borrowed pointer survives `JSStringRelease`. Empty strings, NULs, BMP/supplementary characters and separated lone surrogates remain exact. Non-strings fail without author conversion hooks.

The existing HTML import-map resolution, fetch metadata, module lexer/rewrite, import.meta handling, native grammar, cycles/live bindings and top-level await remain in place. The native delegate receives already-resolved identifiers ([WebKit's delegate contract](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/API/JSContextPrivate.h)); HTML resolution remains owned by ModuleHost. Classic-source and diagnostic callers still receive their copied V string. `VOX_RETAIN_UTF8_MODULE_SOURCE=1` retains the old transport for comparisons. No author-script bytes or pinned lexer distribution change.

Final validation passes **24 guarded jobs / 232 test-function executions** in ordinary GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers, with direct and UTF-8 transports. Coverage includes explicit source roots after caller-arena retirement/GC, diagnostic exceptions, native execution of actual NUL/Unicode/lone UTF-16 units, non-string hook rejection, large concurrent transport, module/classic workers, independent realms, imports/maps/cycles/TLA and shutdown. The first fixture accidentally paired its two intended lone surrogates; it is retained and corrected with an intervening character. The first component driver has a V assertion-spacing error and launches no component runtime; that attempt is retained too.

The signed component creates native module scripts and invokes a fake resolver 100 times per case, with source/runtime setup outside the process-instruction interval. It does not execute author module bodies or perform networking. Four observations per variant preserve all results. The native option diagnostic confirms JIT/baseline/DFG/FTL availability under the canonical `allow-jit` entitlement. All tiers stay enabled; warm-up remains 10,000.

| Native transfer / construction component | UTF-8 control median instructions | Rooted UTF-16 median | Reduction |
| --- | ---: | ---: | ---: |
| 1 KiB ASCII payload × 100 | 6,869,191.5 | 6,655,788.5 | 3.1067% |
| 256 KiB ASCII payload × 100 | 438,664,045.0 | 350,182,622.5 | 20.1707% |
| 65,536 repetitions of éĀ😀 × 100 | 2,178,825,423.0 | 67,487,637.0 | 96.9026% |

These component totals are not a page attribution. Separate production diagnostics prove Wasm lexer consumption in both variants and native UTF-16 transfer only in the candidate. Source preflight authenticates both the sealed V caller/root handling and the separate preprocessed Objective-C helper; passing source checks alone receives no performance credit.

| Unprofiled frozen-page variant | Every retained launch-through-PNG instruction count | Median |
| --- | --- | ---: |
| UTF-8 transport control | 26,604,548,336; 26,699,430,434; 26,393,835,089; 26,565,586,312 | 26,585,067,324.0 |
| Rooted UTF-16 candidate | 26,421,156,099; 26,158,905,929; 26,404,280,264; 26,892,286,933 | 26,412,718,181.5 |

The observed median falls **0.6483%**; conservative observed separation is **-498,451,844 instructions**. Observed ranges overlap; no new page instruction credit is assigned. No new 5M broad checkpoint is due. Whole-page credit and carry remain zero.

All **20** diagnostic/matched captures pass full content/button identity, JavaScriptCore bootstrap, unchanged exact per-engine references and normal browser/kernel exits. Executable `a98fec324fbb4ab4da6bebe090dcef8dc517d5a552b606ed6cf5a472c0c12941` and libraries remain pinned under one nonblocking shared publication lease using the latest completed single-C-unit V `-prod` bundle. The bundle already contains the final implementation; no app is copied and no separate build is queued. The original one-time SOCKS capture/scripts, fresh private profiles/caches, 1024×768 scale two and five-second unfocused settle remain unchanged. Exclusive-coalition counts include startup, window setup and completed PNG encoding; OS filesystem/shader caches remain retained. GPU execution/outside-coalition services remain excluded. Capture/controller guards exit zero; comparison drivers return one for the unmet Brave threshold.

Frame-complete checkpoints are 439, 422, 391, 391 for controls and 430, 430, 401, 272 for candidates. Raw counters, identities, host contention and endpoints remain preserved; no result is normalized to a fixed frame count or another build.

The candidate median remains **6,412,718,181.5 instructions above 20B**. Four pairs do not establish formal seven-pair acceptance or live-site performance. The [verification receipt](performance/chatgpt-module-source-value-verification-20261106.json) links source witnesses, focused/component checks, commands, memory guards, counters, PNGs, failures and every authenticated archive. **The 20B target and original 5%-below-Brave target remain unmet.**

## Reuse module input normalization toward 20B (2026-11-06)

Commit `6037d9a2d` returns input normalization metadata from HTML module-specifier resolution. The native module host previously resolved the target, then repeated URL parsing and serialization to publish its resolved-module record. It now uses the first result. The mapped target stays separate from the original normalized input and URL-like classification: an HTTPS input mapped to a data URL must still be recorded as the HTTPS input. A bare input, data input or relative input likewise retains its original classification.

No persistent resolution cache is introduced. Exact/scoped/prefix maps, late import-map mutation and filtering, blocked/missing/backtracking errors, parent fetch options, target integrity and referrer handling remain tested. Bare normalized text is copied into the output owner; URL records retain their existing immutable snapshot ownership. `resolve_module_specifier()` remains the URL-only compatibility wrapper. `VOX_RETAIN_DUPLICATE_MODULE_NORMALIZATION=1` uses that wrapper and repeats normalization for the control; both variants share the metadata implementation. The original author scripts and lexer bytes are unchanged.

Final focused validation passes **20 guarded jobs / 256 test-function executions** across ordinary GC, no GC, poisoned preallocation and AddressSanitizer/UndefinedBehaviorSanitizer. Checks include temporary caller-input retirement, original-input metadata after remapping, late-map updates, failures without publishing state, descendant fetch metadata, real native linking/cycles/live exports/import.meta/top-level await, concurrent transport and independent workers. An initial test merged into a pre-install map whose scope array was copied on installation; the corrected test updates the installed map. That failed attempt and its authenticated source are retained.

The component calls the real V module host directly. Document/import-map/host setup is outside each instruction interval; URL resolution, record publication, source lookup, assertions and rotating-map updates are inside. Four alternating observations per variant are retained. URL cases use eight exact asset URLs from the frozen archive, plus their derived relative spellings. These components execute no author JavaScript and perform no networking.

| Resolver component | Calls | Duplicate normalization median | Reused metadata median | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Archived absolute asset URLs | 2,400 | 180,421,711.5 | 92,120,244.0 | 48.9417% |
| Relative spellings of archived assets | 2,400 | 111,471,472.5 | 58,234,506.0 | 47.7584% |
| Mapped bare name | 300 | 2,447,747.5 | 1,436,997.5 | 41.2931% |
| Scoped and top-level prefixes | 600 | 12,392,153.5 | 10,318,808.5 | 16.7311% |
| Changing the installed map each round | 300 | 2,569,528.5 | 1,617,042.0 | 37.0685% |
| Unmapped bare-name failure | 300 | 1,625,619.5 | 1,668,595.5 | -2.6437% |

The failure-case regression is retained; component savings are not extrapolated to the page. Initial preparation assumed a CDN origin absent from this archive and stopped before compilation; the corrected driver takes the same-origin asset URLs from its manifest.

| Unprofiled frozen-page variant | Every retained launch-through-PNG instruction count | Median |
| --- | --- | ---: |
| Duplicate-normalization control | 26,568,544,158; 26,760,958,133; 26,626,675,239; 26,556,225,279 | 26,597,609,698.5 |
| Reused-metadata candidate | 26,518,770,071; 25,686,414,173; 26,652,455,808; 26,702,963,468 | 26,585,612,939.5 |

The observed median changes by **0.0451% fewer instructions**; conservative observed separation is **-146,738,189 instructions**. Observed ranges overlap; no new page instruction credit is assigned. No new 5M broad checkpoint is due. Whole-page credit and carry remain zero.

A source preflight first rejected the generated clone symbol spelling before launching any browser. A subsequent four-capture diagnostic passed content/pixels/exits but its adapter searched for an outdated marker. Those captures remain separately rejected, with no instruction credit. The corrected independent diagnostic verifies the normalization marker only in the candidate and the Wasm module lexer in both variants. All **20** captures in the final diagnostic/matched run pass bootstrap, full content/button identity, unchanged exact per-engine references and normal browser/kernel exits.

Executable `f981e667dca81d3c4c665d70f1943cda1dee5b946f0f23825e5d3a0049e38869` and native libraries remain pinned under one nonblocking shared publication lease. The latest completed single-C-unit V `-prod` bundle contains the final implementation; no app was copied and no manual build was queued. The original single SOCKS capture/scripts/references, 1024×768 scale two, five-second unfocused settle and fresh private profiles/caches remain fixed. Exclusive-coalition creation through completed document PNG includes startup/window work; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work is excluded. Guard adoption succeeds and the controller exits zero; comparison drivers exit one for the unmet Brave gate.

Frame-complete checkpoints are 426, 386, 397, 432 for controls and 441, 429, 431, 393 for candidates. Counts are not rescaled for frames, host load or a different build.

The candidate median remains **6,585,612,939.5 instructions above 20B**. Four pairs do not establish formal seven-pair acceptance or live-site performance. The [verification receipt](performance/chatgpt-module-normalization-verification-20261106.json) links every raw observation, command, memory guard, source witness, PNG and verified evidence archive. **The 20B target and original 5%-below-Brave target remain unmet.**

## Opacity interior rows: focused verification; browser pending (2026-11-06)

Commits `27a879435` and `dcd2d0b53` stop reading opacity-layer interior rows after the painted pixels establish both horizontal crop limits. The remaining unknown is the last painted row, found by a reverse search. Any nonzero channel still counts as ink; clipping, empty output sentinels and row tails stay exact. The ordinary scan remains for unresolved horizontal limits. The final code reads the retained-control policy once per scan. Its initial per-row-policy prototype is preserved separately and earns no page credit.

**20 final guarded check jobs pass.** Six optimized/scalar/ASan+UBSan candidate/control runs each pass 32,252 comparisons against the independent full-pixel oracle. Protected tail pages verify bounded vector loads; protected interior pages prove omitted rows are unread. Existing exhaustive compositing/bounds checks pass in both modes. Optimized and sanitized sparse bitmap integration preserves exact geometry, alpha, image/data/worker lifetime and release behavior. A two-unit C build verifies shared `VOX_NATIVE_STATE`. The initial sparse test omitted CoreFoundation and failed to link; its corrected command and the original failure remain retained.

Four alternating direct-C component observations per variant use a 2048×1024 raster and 100 calls per scene. Input generation and the independent oracle are outside the counter interval; calls, assertions and checksums remain inside.

| Bounds component | Complete-row control median | Reverse last-row search median | Reduction |
| --- | ---: | ---: | ---: |
| Dense full-width ink | 4,423,331.5 | 27,066.5 | 99.3881% |
| Horizontal limits reached on different rows | 147,238,231.0 | 392,949.0 | 99.7331% |
| Dense first half / empty tail | 75,748,504.5 | 72,997,900.5 | 3.6312% |
| Central stripe / unresolved horizontal limits | 161,062,213.5 | 161,101,297.0 | -0.0243% |
| Empty raster | 146,981,863.5 | 147,660,366.5 | -0.4616% |
| Only first row painted | 146,941,823.0 | 145,855,647.5 | 0.7392% |

The stripe and empty-raster regressions are retained. These component counts are not page attribution.

Shared production builds failed to link IOSurface functions used by GPU canvas presentation. Commit `992b82c7a` adds the missing framework. Shell syntax and a real production-flags Skia bridge link pass; `otool -L` confirms IOSurface. The first standalone command used the wrong nested libdeflate include path and failed before linking; both attempts are retained. A subsequent shared build completed with the initial scan prototype. The next build failed its source seal because repository inputs changed before preprocessing; a newer shared build is running.

The latest completed executable `fe2d2e8e8f79669f9f63b519e849069936558d9d10777205211fc77c78c54396` lacks the final once-per-scan policy placement. It cannot validate the final change. Browser content/pixel/path checks and an unprofiled matched comparison remain pending. No separate manual production build is queued, no app is copied and the original SOCKS capture/scripts/references remain fixed. **Page credit and broad carry stay zero; the 20B and original Brave goals remain unmet.**

The [focused verification receipt](performance/chatgpt-opacity-ink-rows-focused-verification-20261106.json) links committed source, both component generations, exact test results, memory guards, commands, link failures and authenticated evidence archives.

The final production compile subsequently finished normally under the memory guard (196.148 seconds, peak sampled RSS 5.69 GiB). Its authenticated sealed C contains the final once-per-scan policy. A nonblocking exclusive publication-lease attempt reports busy, and the completed bundle remains unpublished behind another reader; the canonical app still has the earlier prototype. No staging app is launched or copied. [Publication evidence](performance/chatgpt-opacity-ink-rows-publication-pending-20261106-evidence.zip) preserves the successful compile, exact source witness, lock observation and pending canonical identity. Final browser validation remains pending.

## Opacity interior rows: production eligibility result (2026-11-06)

The publication block above cleared. The final completed canonical bundle was checked in four fresh diagnostic captures under one nonblocking shared publication lease. Sealed C proves the once-per-scan policy, reverse last-row search and complete-row control; both the executable and Skia bridge images contain the new control and diagnostic strings.

| Diagnostic variant | Content / bootstrap | Exact reference pixels | Browser / kernel exits | Skipped-interior marker |
| --- | --- | --- | --- | --- |
| Vox candidate | Pass | Pass | 0 / 0 | Absent |
| Vox complete-row control | Pass | Pass | 0 / 0 | Absent |
| Brave reference, both captures | Pass | Pass | 0 / 0 | Not applicable |

**No useful skipped-interior execution was observed on this ChatGPT capture.** This does not establish that the bounds function never runs. The source path is present, but neither Vox log contains its benefit marker. The controller correctly rejects the path audit with exit one; the outer memory guard records that same exit, successful process adoption and no budget violation. Every browser/kernel exit is zero. No matched optimization cohort is launched, and no instruction difference from this instrumented diagnostic is credited.

Executable `4fa001c1a7e820167c920a5739e3aa7def2267045c199af51ba42cdedff050ab` and native libraries stay unchanged through the captures. Original author scripts, frozen one-time SOCKS capture/references, fresh profiles/caches, 1024×768 scale two and the five-second unfocused settle remain fixed. Both Vox variants confirm the Wasm module lexer and JavaScriptCore bootstrap. GPU/outside-coalition work remains excluded; OS filesystem/shader caches remain retained.

The exact focused/component results above remain useful general rendering evidence. They do not establish a ChatGPT improvement. **Page credit and broad carry stay zero. The latest complete matched result remains 26.586B versus 26.598B for module normalization, with overlapping ranges; the 20B and original Brave targets remain unmet.** The [production verification](performance/chatgpt-opacity-ink-rows-browser-verification-20261106.json) links all four captures, source witnesses, guards, counters, PNGs, the rejected path audit and earlier focused/build/publication evidence.

## Current production stage budget after module and opacity work (2026-11-06)

The new diagnostic uses completed executable `204abd9c10a1f5bc74f6a52a0dae65b0e5967575079a37593825e74debda38ff`. A fresh native stack sample and a separate traced/untraced capture pair all pass full content/bootstrap audits, exact unchanged per-engine pixels and normal exits. The same one-time SOCKS capture/scripts, 1024×768 scale two, five-second unfocused settle and private profiles/caches remain fixed. The app and native libraries stay pinned under a shared publication lease for each diagnostic; no bundle is copied and no build is requested.

The traced total is **28,048,917,731 instructions**. Its **63** exclusive stage rows below sum exactly to that total. The separate untraced observation is **26,195,148,792 instructions**; one observation per mode is not a performance cohort, and their difference is not an instrumentation-overhead estimate. No table row is scaled to the earlier 26.59B/29B totals or the 20B target.

The module-completion and JS/bindings scopes together account for **6,847,976,634** instructions (24.41% of this trace). Module completion includes native host/source/loading/engine callback work, so this sum is not an isolated JavaScript engine total. Style updates alone account for **4,099,468,162**. Main-thread scope boundaries read process-wide counters: concurrent native/JSC work is charged to the active interval. The explicit coalition/process endpoint remainder remains unattributed. Inclusive scopes overlap and must not be added.

| Exclusive stage | Calls | Instructions | Share of traced total |
| --- | ---: | ---: | ---: |
| style_update | 754 | 4,099,468,162 | 14.6154% |
| javascript_module_completion | 281 | 4,014,987,308 | 14.3142% |
| paint_layer_transition | 147 | 2,936,182,435 | 10.4681% |
| javascript_execution_and_bindings | 1,757 | 2,832,989,326 | 10.1002% |
| browser_main | 1 | 2,798,863,766 | 9.9785% |
| absolute_positioned_layout | 12 | 2,070,653,437 | 7.3823% |
| coalition_endpoint_remainder | 0 | 808,538,959 | 2.8826% |
| gpu_frame_finalization | 15 | 720,976,913 | 2.5704% |
| paint_leaf_text | 292 | 623,459,106 | 2.2228% |
| platform_timer_delivery | 2,272 | 619,081,344 | 2.2071% |
| paint_leaf_shadow | 35 | 604,438,564 | 2.1549% |
| css_parsing | 11 | 587,735,064 | 2.0954% |
| paint_leaf_fill | 206 | 524,779,894 | 1.8709% |
| paint_leaf_border | 99 | 497,219,050 | 1.7727% |
| paint_leaf_svg | 198 | 402,434,253 | 1.4348% |
| background_resource_completion | 383 | 311,931,374 | 1.1121% |
| html_networking_task | 567 | 276,359,549 | 0.9853% |
| document_layout | 741 | 213,566,812 | 0.7614% |
| frame | 383 | 186,168,718 | 0.6637% |
| navigation_html_parsing | 1 | 183,149,504 | 0.6530% |
| paint_leaf_effect_end | 44 | 167,359,446 | 0.5967% |
| viewport_relayout | 9 | 162,468,157 | 0.5792% |
| unscoped_process | 0 | 159,873,678 | 0.5700% |
| paint_command_dispatch | 15 | 158,860,870 | 0.5664% |
| frame_preparation | 383 | 156,050,027 | 0.5563% |
| flow_layout | 12 | 155,669,974 | 0.5550% |
| html_event_loop | 1,149 | 146,946,745 | 0.5239% |
| layout_tree_construction | 10 | 143,833,604 | 0.5128% |
| html_rendering_task | 359 | 141,466,578 | 0.5044% |
| stationary_raster_finish | 383 | 123,499,511 | 0.4403% |
| paint_command_recording | 17 | 114,986,033 | 0.4099% |
| native_raster_replay | 383 | 108,318,278 | 0.3862% |
| native_document_replay | 383 | 96,299,585 | 0.3433% |
| native_window_initialization | 2 | 72,836,686 | 0.2597% |
| script_state_replay | 761 | 71,741,538 | 0.2558% |
| initial_resource_preload | 1 | 68,388,375 | 0.2438% |
| script_runtime_setup | 1 | 62,842,389 | 0.2240% |
| native_frame_bitmap | 383 | 62,124,629 | 0.2215% |
| document_install | 1 | 59,422,229 | 0.2119% |
| browser_chrome | 391 | 55,606,658 | 0.1982% |
| native_frame_presentation | 383 | 50,224,392 | 0.1791% |
| scroll_raster_probe | 15 | 48,644,775 | 0.1734% |
| stationary_raster_probe | 375 | 47,625,209 | 0.1698% |
| browser_tab_frame | 383 | 43,481,816 | 0.1550% |
| html_rendering_opportunity | 383 | 32,585,358 | 0.1162% |
| layout_geometry | 12 | 31,385,913 | 0.1119% |
| raster_frame_commit | 15 | 30,944,884 | 0.1103% |
| animation_driver | 383 | 26,995,585 | 0.0962% |
| html_other_task | 202 | 23,053,466 | 0.0822% |
| raster_frame_setup | 15 | 22,583,558 | 0.0805% |
| stationary_raster_eligibility | 375 | 22,032,443 | 0.0786% |
| native_frame_context | 383 | 21,347,807 | 0.0761% |
| png_encoding | 1 | 18,055,441 | 0.0644% |
| style_computation | 29 | 7,750,046 | 0.0276% |
| capture_snapshot | 1 | 5,854,697 | 0.0209% |
| html_posted_message_task | 17 | 4,227,431 | 0.0151% |
| raster_tile_setup | 15 | 3,478,376 | 0.0124% |
| paint_leaf_effect_begin | 44 | 3,294,043 | 0.0117% |
| relative_positioned_layout | 12 | 1,781,721 | 0.0064% |
| viewport_raster_plan | 15 | 866,116 | 0.0031% |
| html_timer_task | 5 | 622,781 | 0.0022% |
| stationary_blank_probe | 8 | 444,440 | 0.0016% |
| capture_conversion | 1 | 58,905 | 0.0002% |

| Total | | 28,048,917,731 | 100% |

The native stack sample again observes active grid/flex/absolute layout, style, DOM query traversal and opacity scans. Recursive counts and unknown JIT symbols cannot be ranked as additive instruction costs; the requested 1ms statistical samples include waits, concurrent threads and attachment gaps. These are leads only. The previous opacity fast path still has no observed useful execution on this fixture.

The [verification receipt](performance/chatgpt-current-budget-verification-20261106.json), [traced JSON](performance/chatgpt-load-stages-current-r1-traced-20261106.json), [CSV](performance/chatgpt-load-stages-current-r1-traced-20261106.csv) and [fresh native sample](performance/chatgpt-current-native-sample-20261106-r2.json) retain exact totals, every stage, raw logs, PNGs, counters, source witnesses, guards and authenticated archives. **No optimization credit is assigned; the 20B and original Brave targets remain unmet.**

## One parent lookup per inherited-style refresh (2026-11-06)

Commit `3d3682afb` resolves the inheritance parent once for a synchronous inherited-style refresh. Previously the base-value and animation helpers each resolved the same DOM inheritance source for every property. The new loop borrows that parent, then reads its live stores per property. The parent is resolved again on the next call. No pointer or match result is retained after returning.

The ordinary setters, important/inherited/transition flags, animation removal, specified-value restoration, font-relative computation, invalidation and published property pages remain in place. Existing public helpers retain their behavior and supply the repeated-parent control through `VOX_RETAIN_REPEATED_INHERITED_PARENT=1`. The new path does not skip a cascade, suppress a mutation or change author scripts.

**12 guarded jobs / 752 test-function executions pass**, in ordinary GC, no GC, poisoned preallocation and ASan/UBSan, with both variants. The 94-test selection covers live base/animation stores, transition flags, own animations, parent replacement, explicit inheritance overrides, orphan fallback, font-relative values, CSSOM/adoption, slots/shadow inheritance and rule deletion. Commit `a39e25cce` independently fixes two optional display assertions required for this test selection to compile. Initial optional-unwrapping errors, an initial fixture combining an override with a font-relative expectation that fails both controls, and the first component property-ID unwrap error remain retained. The final fixture tests font-relative reparenting and explicit overrides separately.

The direct V component repeats each refresh 300 times. Setup and full-property checksums are outside each process-counter interval; refresh calls and changing-parent writes remain inside. Four alternating observations per variant retain every sample. All full-property output checksums match across both variants.

| Inherited refresh component | Repeated-parent control median | Borrowed-parent median | Reduction |
| --- | ---: | ---: | ---: |
| Ordinary unchanged inheritance | 24,190,531.5 | 22,824,772.0 | 5.6458% |
| Unchanged font-relative values | 205,955,576.0 | 204,722,646.5 | 0.5986% |
| Inherited transition | 28,713,816.5 | 27,379,785.0 | 4.6460% |
| Own animation preserved | 28,585,744.0 | 27,172,440.5 | 4.9441% |
| Explicit inheritance override | 23,642,997.0 | 22,871,479.5 | 3.2632% |
| Parentless fallback | 206,382,537.5 | 205,450,464.5 | 0.4516% |
| Changing parent value | 201,846,204.0 | 200,497,717.5 | 0.6681% |
| No inherited properties | 5,882,706.0 | 5,877,558.0 | 0.0875% |

Component results are not extrapolated to the page. The small changes in the final cases remain subject to the raw ranges in the verification receipt.

| Unprofiled frozen-page variant | Every retained launch-through-PNG instruction count | Median |
| --- | --- | ---: |
| Repeated-parent control | 24,760,307,522; 24,459,639,122; 24,545,935,262; 24,392,269,326 | 24,502,787,192.0 |
| Borrowed-parent candidate | 24,107,759,625; 24,467,205,854; 24,370,337,505; 24,542,773,282 | 24,418,771,679.5 |

The observed median falls **0.3429%**. Conservative observed separation is **-150,503,956 instructions**. Observed ranges overlap; no whole-page savings credit is assigned. No new 5M broad checkpoint is due. Page credit and broad carry remain zero.

All **20** final diagnostic/matched captures pass bootstrap, full content/button identity, unchanged exact per-engine references and normal browser/kernel exits. Sealed production source proves the one-parent loop and its repeated-parent control; the candidate marker appears after the first native layer submission, and is absent in the control. The Wasm module lexer executes in both. Executable `f6b60a240c069e4b72543e5241375e88d7d242c7326e0c779ed76ca7f618a740` and native libraries stay pinned under one nonblocking shared publication lease. The latest completed single-C-unit V `-prod` bundle already contains the change; no app is copied and no separate manual build is queued.

Both variants use one pinned current build. This build contains concurrent repository work, so only its candidate/control difference measures this slice. Earlier 26.59B or other-build totals receive no credit here. Original author scripts, single SOCKS fixture/references, 1024×768 scale two, five-second unfocused settle and fresh private profiles/caches remain fixed. Coalition creation through encoded document PNG includes startup/window work; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded. Controller and guard exit zero with successful PID adoption; comparison drivers exit one for the unmet Brave gate.

Frame-complete checkpoints are 455, 449, 477, 502 for controls and 463, 492, 446, 469 for candidates. No count is normalized to a fixed frame count, another build or host load.

The candidate median remains **4,418,771,679.5 instructions above 20B**. Four pairs do not establish formal seven-pair acceptance or live-site performance. The [verification receipt](performance/chatgpt-inherited-parent-verification-20261106.json) links all raw observations, components, focused checks, commands, source witnesses, counters, guards, PNGs and authenticated evidence archives. **The 20B target and original 5%-below-Brave target remain unmet.**

## Opacity margins and backed row bands toward 20B (2026-11-06)

Commit `9366f00e1` first finds the top and bottom nonempty rows of an opacity layer. It then examines only the unresolved left/right margins of interior rows, widening the bounds when necessary. A fully bounded interior cannot change the answer and is not read. The original row scan remains byte-identical in its own helper. Queries narrower than 64 pixels or shorter than four rows retain that helper. No pixel data changes and no result survives the call.

Commit `c8549a965` exposes that useful path on mapped canvases: consecutive rows whose entire requested interval has backing are passed as one band. Previously VM-page subdivision reduced these calls to single rows. Untouched rows still avoid pixel reads; mixed rows retain the per-page walk. Compressed/unknown nonzero dispositions remain readable, and failed or short metadata queries fall back to the ordinary scan. Only requested pixels qualify; padding outside the crop does not. The existing whole-canvas VM metadata query is unchanged.

`VOX_RETAIN_OPACITY_ROW_SCANS=1` supplies the original row/page control for both changes. `VOX_RETAIN_FULL_OPACITY_INK_ROWS=1` also disables the new path and preserves the earlier full-row control. Diagnostic messages are absent from unprofiled runs. All mutable native-header state uses the split-build state boundary.

**45 final guarded jobs pass:** 24 ordinary-bounds/context/state jobs and 21 backed-band/context/state jobs. Optimized NEON, scalar, ASan/UBSan and both controls run. Each ordinary bounds test performs 33,116 exact independent pixel-oracle comparisons, including irregular/cropped/hollow bands, protected row tails and protected interior pages. Protected memory proves the bounded interior is not accessed. Each backed test performs 888,960 crop/backing classifications and 1,636 clipped scans; the 136 new scans use an independent pixel oracle, while the existing 1,500 retain their earlier helper comparison. Failed/short queries, compressed/unknown pages, small malloc fallback, reuse and split-unit state are covered. The existing under-4-MiB viewport footprint guard and new under-1-MiB cropped-padding guard pass.

The initial policy-first size gate and all its checks/results remain retained. The final gate checks query dimensions first, avoiding the new policy lookup on short queries. A separate policy-state diagnostic observes the candidate initializing the retained row policy once in the short-wide case; the control had initialized it earlier. Both are initialized before the tiny case. This explains a component cold-path difference without adjusting or discarding any sample.

Both component tables use four alternating observations per variant and 100 calls per scene. Ordinary inputs are 2048×1024 except short-wide (2048×3) and tiny (32×3). Allocation/input construction and independent oracle setup are outside the process-instruction interval; bounds calls, assertions and checksum accumulation are inside. The mapped component also includes real VM queries, metadata allocation/free and context metadata calls. Its independent pixel oracle runs **after** the interval so it cannot materialize untouched pages before measurement. All output checksums match.

Initial component attempts did not pin the compiled executable throughout sampling; those diagnostic results remain retained. The first attempt to add that gate fails before sampling because the external compiler path is outside the repository. Fresh final attempts correct that path handling and pin executable, compiler, source, controller and memory-guard hashes across every observation. Tables below use those final attempts, not a selection of the fastest samples.

| Ordinary bitmap scene | Row control median instructions | Margin candidate median | Reduction |
| --- | ---: | ---: | ---: |
| dense | 34,006.5 | 35,565.5 | -4.5844% |
| separated-extremes | 384,992.0 | 323,793.0 | 15.8962% |
| trailing-empty | 73,819,929.0 | 74,073,236.0 | -0.3431% |
| central-stripe | 155,464,196.0 | 153,797,712.0 | 1.0719% |
| empty | 147,681,764.0 | 148,092,494.5 | -0.2781% |
| first-row-only | 147,463,516.5 | 147,968,935.5 | -0.3427% |
| hollow-half-width | 145,627,885.0 | 80,219,222.0 | 44.9149% |
| hollow-near-full-width | 147,412,146.0 | 4,321,125.5 | 97.0687% |
| dense-padded | 5,953,713.0 | 4,321,125.5 | 27.4213% |
| interior-extremes | 147,573,606.5 | 43,682,838.0 | 70.3993% |
| short-wide | 31,462.0 | 32,547.5 | -3.4502% |
| tiny | 31,213.0 | 31,225.5 | -0.0400% |

| VM-backed canvas scene | Page/row control median instructions | Backed-band margin median | Reduction |
| --- | ---: | ---: | ---: |
| backed-dense | 103,434,909.5 | 84,314,168.5 | 18.4858% |
| backed-hollow-wide | 243,066,765.5 | 89,189,713.0 | 63.3065% |
| backed-hollow-half | 243,369,710.5 | 165,078,549.5 | 32.1696% |
| backed-central-stripe | 253,473,376.0 | 238,250,341.5 | 6.0058% |
| untouched-empty | 4,918,238.5 | 4,305,399.5 | 12.4605% |
| sparse-two-points | 81,529,273.5 | 81,505,912.0 | 0.0287% |
| sparse-text-bands | 95,309,620.5 | 92,078,307.5 | 3.3903% |
| mixed-page-rows | 196,179,985.5 | 196,551,898.5 | -0.1896% |
| clipped-backed-column | 196,909,818.0 | 125,344,262.5 | 36.3443% |
| first-row-only | 243,771,736.5 | 232,642,787.0 | 4.5653% |

Negative values are regressions. Tiny differences remain subject to the raw ranges and host contention; none is extrapolated to the page.

The first production preflight rejects a completed bundle containing the prototype gate order before launching browsers. The next available completed single-C-unit V `-prod` bundle contains both final changes. Sealed source witnesses cover eight functions, the exact size-first gate, margin intervals, backing classifier, grouping and accounting. The executable and native bridge contain both diagnostic markers and the control flag. Separate candidate diagnostics observe **both** skipped-interior columns and coalesced backed rows; both markers are absent in the control. Both variants execute the Wasm module lexer and JavaScriptCore bootstrap.

| Unprofiled frozen-page variant | Every retained launch-through-PNG instruction count | Median |
| --- | --- | ---: |
| Row/page control | 24,734,221,337; 25,047,589,713; 24,396,124,432; 24,726,432,620 | 24,730,326,978.5 |
| Margin/backed-band candidate | 24,692,555,692; 24,691,410,726; 24,664,484,466; 24,717,131,905 | 24,691,983,209.0 |

The observed median falls **0.1550%**, but conservative observed separation is **-321,007,473 instructions**. Ranges overlap; no whole-page savings credit is assigned. No 5M broad checkpoint is due, and carry remains zero.

All **20** diagnostic/matched captures pass full content/button identity, bootstrap, unchanged exact per-engine references and normal browser/kernel exits. Executable `dece7e71f67587cc0fb0c5ab73af36283b28b78e84cadc50bf27f4df668d605a` and native libraries stay pinned under one nonblocking shared publication lease. The bundle contains concurrent work; differences from earlier builds receive no credit. No app is copied and no separate manual build is requested. Original author scripts, the single SOCKS fixture/references, private profiles/caches, 1024×768 scale two and the five-second unfocused settle stay fixed. Coalition creation through encoded document PNG includes startup/window work; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded. Controller/guard exit zero with successful PID adoption; comparison drivers exit one for the unmet Brave threshold.

Frame-complete checkpoints are 497, 508, 505, 510 for controls and 501, 508, 500, 508 for candidates. Counts are not normalized to a fixed frame count or host load.

A separate later-build geometry diagnostic passes content/pixels and records 76 VM queries; 42 request partial canvas rectangles. Whole-canvas VM address spans sum to 1,060,896,768 bytes, while requested rectangle coverage sums to 695,691,248 bytes. These are neither actual pixel reads nor instruction costs. Crop coordinates are not logged; a narrow horizontal crop can still span most contiguous VM pages. This remains a lead, with no performance credit.

The candidate median remains **4,691,983,209.0 instructions above 20B**. Four pairs do not establish formal seven-pair acceptance or live-site performance. The [verification receipt](performance/chatgpt-opacity-margins-verification-20261106.json) links every focused/component attempt, regression, rejected preflight, source witness, command, counter, memory guard, PNG and authenticated evidence archive. **The 20B target and original 5%-below-Brave target remain unmet.**

## Crop-bounded opacity VM metadata queries (2026-11-06)

Commit `e332a5dfa` restricts each mapped opacity canvas metadata query to the contiguous VM pages spanning its requested rectangle. Previously even a one-row crop queried every page in the viewport-sized mapping. The first page is aligned down, the final page is capped at the owned allocation, and all disposition accesses subtract the explicit first-page index. No pointer precedes the allocated metadata array. Full-width/full-height queries keep their complete span. The scan, any-channel ink definition, read eligibility, fallback and output bounds remain the same; no pixel or page cache is added.

`VOX_RETAIN_FULL_OPACITY_PAGE_QUERY=1` supplies the whole-canvas query control while keeping the preceding margin scans and backed-row bands enabled. Separate diagnostics log crop coordinates and actual queried address spans. These byte spans describe metadata requests, not pixel loads or instruction savings.

**24 guarded jobs pass**, including optimized NEON/scalar, ASan/UBSan, both query policies, retained row/full-row controls, bitmap-context ownership and split-unit state. Each bounds runtime covers 888,960 backing-classification cases with both zero and nonzero metadata origins, plus 1,876 clipped scans. Of those scans, 376 use an independent scalar pixel oracle and the original 1,500 retain their earlier helper comparison. New cases exercise nonzero vertical origins, single rows, sparse/empty data, partial final allocation pages, real/failed/short queries and compressed/unknown dispositions. Tests verify the exact VM query address, byte count and metadata capacity independently. Existing footprint guards pass. The first compile fails because the test wrapper macro `query_pages` collides with a new local count; the corrected `queried_pages` name and original failure/patch are retained.

The real-VM component takes four alternating observations per variant and 100 calls per scene. Construction and expected-bounds setup are outside each process-counter interval; metadata queries/allocation, context calls, scans, assertions and checksum accumulation are inside. The independent pixel oracle runs after timing, preserving untouched pages during measurement. Executable, compiler, sources, controller and guard identities remain pinned. All output checksums match. Every full-canvas and cropped scene is retained, including regressions.

| VM-backed component | Whole-canvas query median instructions | Cropped query median | Reduction |
| --- | ---: | ---: | ---: |
| backed-dense | 84,395,759.5 | 84,414,629.5 | -0.0224% |
| backed-hollow-wide | 89,407,797.5 | 89,360,258.5 | 0.0532% |
| backed-hollow-half | 165,637,233.5 | 165,333,588.5 | 0.1833% |
| backed-central-stripe | 238,619,970.5 | 238,797,997.5 | -0.0746% |
| untouched-empty | 4,422,045.0 | 4,424,707.5 | -0.0602% |
| sparse-two-points | 80,906,625.5 | 81,185,264.5 | -0.3444% |
| sparse-text-bands | 91,802,635.0 | 91,838,467.0 | -0.0390% |
| mixed-page-rows | 196,582,999.0 | 197,040,117.5 | -0.2325% |
| clipped-backed-column | 125,898,795.0 | 125,072,659.0 | 0.6562% |
| first-row-only | 232,895,897.0 | 233,161,115.5 | -0.1139% |
| cropped-backed-rows | 83,351,821.5 | 7,014,051.5 | 91.5850% |
| cropped-sparse-rows | 80,839,617.0 | 3,417,037.5 | 95.7731% |
| cropped-empty-rows | 2,023,634.0 | 1,358,720.0 | 32.8574% |
| cropped-tiny-rect | 80,353,838.0 | 1,571,250.0 | 98.0446% |
| cropped-tail-partial | 13,857,051.0 | 2,021,248.5 | 85.4136% |
| cropped-single-row | 79,087,813.5 | 1,350,655.0 | 98.2922% |
| cropped-near-full | 89,504,422.0 | 89,179,305.0 | 0.3632% |
| cropped-middle-page | 118,168,071.5 | 5,436,200.0 | 95.3996% |

These component gains are not extrapolated to the page. Separate production diagnostics verify the cropped-query marker only in the candidate, Wasm module lexer execution in both variants, full bootstrap/content identity and exact unchanged pixels. The sealed production source proves the cropped range, final partial page, local indices, query count validation and full-query control; executable and native bridge contain the marker/flag.

The candidate geometry diagnostic logs 76 queries, 42 with a reduced page span: 769,032,192 queried address bytes out of 1,060,896,768 whole-canvas address bytes. This is instrumented metadata evidence only; captures may perform different amounts of work.
The control geometry diagnostic logs 76 queries, 0 with a reduced page span: 1,060,896,768 queried address bytes out of 1,060,896,768 whole-canvas address bytes. This is instrumented metadata evidence only; captures may perform different amounts of work.

| Unprofiled frozen-page variant | Every retained launch-through-PNG instruction count | Median |
| --- | --- | ---: |
| Whole-canvas metadata control | 24,549,735,140; 24,116,668,639; 24,452,033,578; 24,272,000,529 | 24,362,017,053.5 |
| Cropped metadata candidate | 24,204,225,256; 24,493,357,212; 24,329,229,392; 24,364,787,606 | 24,347,008,499.0 |

The observed median change is **0.0616% fewer instructions**; conservative observed separation is **-376,688,573 instructions**. Observed ranges overlap; no whole-page savings credit is assigned. No new 5M broad checkpoint is due; whole-page credit and carry remain zero.

All **20** diagnostic/matched captures pass full content/button identity, bootstrap, exact unchanged per-engine references and normal browser/kernel exits. Executable `b9e783c0673acd78e7c623047e7aa7b6add10e9acec5e03a9f54563850dd235e` and native libraries stay pinned under a nonblocking shared publication lease. The latest completed single-C-unit V `-prod` bundle supplies the code; no app is copied or separate manual build requested. Concurrent work in that build receives no credit for this slice. Original author scripts, single SOCKS fixture/references, private profiles/caches, 1024×768 scale two and five-second unfocused settle stay fixed. Coalition creation through encoded document PNG includes startup/window work; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded. Controller/guard exit zero with successful PID adoption; comparison drivers exit one for the unmet Brave gate.

Frame-complete checkpoints are 502, 505, 513, 509 for controls and 506, 501, 515, 516 for candidates. Raw counters and host load remain preserved without normalization.

The candidate median remains **4,347,008,499.0 instructions above 20B**. Four pairs do not establish formal seven-pair acceptance or live-site performance. The [verification receipt](performance/chatgpt-opacity-crop-pages-verification-20261106.json) links source witnesses, focused/component checks, every regression, commands, counters, memory guards, PNGs and authenticated archives. **The 20B target and original 5%-below-Brave target remain unmet.**

## Empty descendant-call elision in independent queries (2026-11-06)

Commit `d5e07fd87` avoids descending into children with no descendants in the independent `querySelector` and `querySelectorAll` walkers. Each child still passes through the existing element matcher first. Nonempty branches retain the same recursive walk and early first-match return; grouped results retain tree order and deduplication. The query parse cache, matcher, namespace/quirks rules, scope boundary and result ownership stay in place. No persistent result/index cache is introduced. `VOX_RETAIN_LEAF_QUERY_RECURSION=1` retains the empty calls for the comparison.

A fresh completed-bundle native sample passes bootstrap, full content, unchanged pixels and normal exits. It still observes selector traversal alongside style, grid/flex/absolute layout and native opacity work. Recursive counts, unknown JIT symbols, waits and concurrent threads cannot become instruction shares or performance credit. The document ID index was also inspected: form callbacks precede ID-map updates, so it cannot safely reject reentrant selector queries as it stands. This change uses only the live child vector.

**12 guarded jobs / 264 focused test executions pass**: 33 cases in ordinary GC, no GC, poisoned preallocation and ASan/UBSan, with both recursion policies. Coverage includes element-first matching, HTML/XML/quirks case rules and namespaces, duplicate IDs, comma order, text/element leaves, mixed-depth branches, fragments, shadow/detached roots, root exclusion, live append/remove/reparenting, parsed-selector reuse and results surviving scratch retirement. The initial shadow-root fixture omitted HTML document mode and fails with NotSupportedError; the corrected fixture and original failed selection remain retained.

The component uses the original captured HTML parsed into a server DOM, plus synthetic flat, deep and empty trees. It does not run the page bootstrap. Four alternating observations per variant and 400 public API calls per row retain all samples. Construction, parsing and independent full-walk reference setup are outside the process-instruction interval; API calls, assertions and checksum accumulation are inside. Full output order is checked after timing. Executable, source, controller and guard identities stay fixed, and all checksums match.

| Query component | API | Selector | Retained-recursion median instructions | Leaf-skip median | Reduction |
| --- | --- | --- | ---: | ---: | ---: |
| captured-buttons | first | `button` | 19,642,239.5 | 15,994,642.5 | 18.5702% |
| captured-buttons | all | `button` | 95,314,253.5 | 75,471,550.5 | 20.8182% |
| captured-attributes | first | `[aria-label]` | 43,126,331.0 | 39,535,413.5 | 8.3265% |
| captured-attributes | all | `[aria-label]` | 190,243,129.0 | 170,054,549.5 | 10.6120% |
| captured-missing-attribute | first | `[data-leaf-probe-absent]` | 208,421,168.5 | 184,366,086.0 | 11.5416% |
| captured-missing-attribute | all | `[data-leaf-probe-absent]` | 205,223,555.0 | 185,034,327.0 | 9.8377% |
| captured-last-editor | first | `#mobile-composer-prompt` | 51,120,726.5 | 36,946,539.5 | 27.7269% |
| captured-last-editor | all | `#mobile-composer-prompt` | 84,195,116.5 | 64,024,536.0 | 23.9569% |
| captured-group | first | `span, button` | 29,142,264.5 | 25,580,176.0 | 12.2231% |
| captured-group | all | `span, button` | 129,352,480.0 | 109,279,365.0 | 15.5182% |
| captured-absent-class | first | `.vox-leaf-probe-absent` | 121,042,252.0 | 97,192,601.5 | 19.7036% |
| captured-absent-class | all | `.vox-leaf-probe-absent` | 117,965,872.0 | 97,787,324.0 | 17.1054% |
| flat | first | `span` | 975,776.0 | 966,576.0 | 0.9428% |
| flat | all | `span` | 64,513,979.0 | 55,484,050.5 | 13.9969% |
| flat | first | `[data-leaf-probe-absent]` | 123,794,154.0 | 113,139,027.0 | 8.6071% |
| flat | all | `[data-leaf-probe-absent]` | 122,796,859.5 | 113,770,970.5 | 7.3503% |
| deep | first | `span` | 975,776.0 | 966,576.0 | 0.9428% |
| deep | all | `span` | 18,127,981.0 | 17,165,217.5 | 5.3109% |
| deep | first | `[data-leaf-probe-absent]` | 32,686,351.0 | 31,498,807.0 | 3.6331% |
| deep | all | `[data-leaf-probe-absent]` | 32,458,619.5 | 31,473,788.5 | 3.0341% |
| empty | first | `span` | 758,588.5 | 758,576.0 | 0.0016% |
| empty | all | `span` | 759,739.5 | 759,727.0 | 0.0016% |
| empty | first | `[data-leaf-probe-absent]` | 889,339.5 | 878,939.5 | 1.1694% |
| empty | all | `[data-leaf-probe-absent]` | 916,188.5 | 907,376.0 | 0.9619% |

Component reductions are not extrapolated to the page. Tiny differences remain subject to raw ranges and host contention. Separate production diagnostics confirm both first/all leaf-skip markers only in the candidate, Wasm module lexer execution in both variants, full bootstrap/content identity and exact unchanged pixels. Sealed source proves both walker guards, recursive branches and element matching. The V executable contains the control and marker; libraries are pinned for identity. The phase reports retain an inherited phrase saying “both native images”; the function/control/marker proof applies to the V executable only.

| Unprofiled frozen-page variant | Every retained launch-through-PNG instruction count | Median |
| --- | --- | ---: |
| Retained-recursion control | 24,620,990,558; 24,013,145,054; 24,070,546,522; 24,217,680,532 | 24,144,113,527.0 |
| Leaf-skip candidate | 24,335,019,182; 24,714,061,567; 24,117,183,992; 24,097,806,606 | 24,226,101,587.0 |

The observed candidate median is **0.3396% higher**; conservative observed separation is **-700,916,513 instructions**. Observed ranges overlap; no whole-page savings credit is assigned. No new 5M broad checkpoint is due; whole-page credit and carry remain zero.

All **20** diagnostic/matched captures pass full content/button identity, bootstrap, exact unchanged per-engine references and normal browser/kernel exits. Executable `c51e685ab95e31e2505dcf18a267c81b37774f5c29002bb4b89ed9814ddd40c3` and native libraries stay pinned under a nonblocking shared publication lease. The latest completed single-C-unit V `-prod` bundle already supplies the final path; no app is copied or separate manual build requested. Concurrent work in that build receives no credit for this slice. Original author scripts, single SOCKS fixture/references, private profiles/caches, 1024×768 scale two and five-second unfocused settle stay fixed. Coalition creation through encoded document PNG includes startup/window work; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded. Controller/guard exit zero with successful PID adoption; comparison drivers exit one for the unmet Brave gate.

Frame-complete checkpoints are 426, 466, 470, 460 for controls and 437, 465, 481, 464 for candidates. Raw counters and host load remain preserved without normalization.

The candidate median remains **4,226,101,587.0 instructions above 20B**. Four pairs do not establish formal seven-pair acceptance or live-site performance. The [verification receipt](performance/chatgpt-leaf-query-verification-20261106.json) links the fresh profile, source witnesses, focused/component checks, every failure, commands, counters, memory guards, PNGs and authenticated archives. **The 20B target and original 5%-below-Brave target remain unmet.**

## Opacity-only animation measurements within one pass (2026-11-06)

Commit `fc2be3446` permits pass-local grid/flex measurement reuse when a subtree has only an opacity animation and no animated custom properties. Opacity does not change the numeric geometry being restored. The full property-graph revision still invalidates a snapshot after any animation or raw-value write, alongside membership, text, font, dimensions and containing-block keys. A borrowed single-property query inspects the live animation map without cloning it or retaining a sample value. Persistent layout/paint caches keep their previous animation rejection. Other animations, SVG/UA-shadow/generated-content exclusions and other existing eligibility rules remain in place.

The first implementation rebuilt snapshots after every sample mutation, regressing the mutation components by 88–103% and single-use pools by 19%. All those results remain retained. The final policy waits until a second animated measurement before retaining its geometry. When a matching cached opacity entry fails input validation, it marks the context rejected for the rest of that pass. Both admission and rejection metadata live in the shared pool owner; rejection writes enter retained allocation scope, and pool release clears the admission map.

**24 final guarded jobs / 464 test-function executions pass**: 10 CSS and 48 layout cases in ordinary GC, no GC, poisoned preallocation and ASan/UBSan, with both policies. Coverage includes borrowed-map allocation checks, alias writes, custom-property separation, producer scratch retirement, numeric/glyph geometry versus unpooled algorithms, copy-on-write line storage, repeated opacity replacement, raw width changes, persistent-cache rejection and complete pool retirement. The initial focused prototype also passes its own 24 jobs. The first component compile includes existing test assertions that require explicit pointer-map unwraps under `-prod`; that failed attempt is retained. The replacement component driver supplies an independent unpooled geometry oracle without changing those tests.

Each component has four alternating observations per variant and 100 calls. Construction, initial document layout, style setup and one warm measurement are outside the process-instruction interval. Measurement-state creation/release, layout, requested mutations/pool replacements and scalar checksums are inside. Because admission is delayed, the final policy can still populate its first retained entry during the measured interval. The complete numeric/glyph oracle runs after timing. Executable, source, controller and guard identities stay fixed. All output checksums match.

| Measurement component | Full-layout control median | Final candidate median | Reduction |
| --- | ---: | ---: | ---: |
| plain-grid | 1,717,380.0 | 1,717,397.0 | -0.0010% |
| opacity-grid | 12,523,525.5 | 1,935,477.5 | 84.5453% |
| plain-flex | 1,551,346.0 | 1,551,284.0 | 0.0040% |
| opacity-flex | 15,676,681.0 | 1,770,110.0 | 88.7086% |
| opacity-plus-width | 12,574,908.5 | 12,575,308.5 | -0.0032% |
| opacity-custom | 12,524,215.0 | 12,524,908.5 | -0.0055% |
| changing-opacity | 12,543,508.5 | 13,432,681.0 | -7.0887% |
| changing-width | 12,533,000.5 | 13,422,233.0 | -7.0951% |
| opacity-root | 7,979,583.5 | 1,858,648.0 | 76.7075% |
| fresh-pool | 62,546,928.5 | 66,097,591.5 | -5.6768% |

Negative values are regressions. Stable reuse saves 76.7–88.7% in these components; repeated mutations still regress about 7.1%, and fresh single-use pools regress 5.7%. Static and unsupported-animation controls are nearly unchanged. No component total is extrapolated to ChatGPT.

The latest completed production bundle, executable `8fe7188244335c797d346b295b77fb6781eb5368b7f9e00118d2331d393abca9`, contains the final admission and retained-scope rejection policy. Sealed C witnesses cover the borrowed property query, opacity predicate, unchanged persistent collector, shared collector/validator, grid/flex cache paths, admission and pool release. The executable contains the control flag and diagnostic marker. Libraries stay pinned for identity. No copied app or separate manual build is requested.

| Production diagnostic | Content / bootstrap | Exact reference pixels | Browser / kernel exit | Useful opacity-measurement reuse |
| --- | --- | --- | --- | --- |
| Vox candidate | Pass | Pass | 0 / 0 | Not observed |
| Vox retained full-layout control | Pass | Pass | 0 / 0 | Not observed |
| Brave, both reference captures | Pass | Pass | 0 / 0 | Not applicable |

**No useful opacity-measurement reuse is observed on this frozen ChatGPT capture.** Presence of the code is not evidence of execution. The path audit correctly rejects the diagnostic with controller/guard exit one; every browser/kernel exit is zero, identities stay fixed and PID adoption succeeds. No unprofiled matched cohort is launched, no instruction difference is credited and no 5M broad checkpoint is due. Carry remains zero.

Original author scripts, single SOCKS fixture/references, fresh private profiles/caches, 1024×768 scale two and five-second unfocused settle remain fixed. Both Vox variants confirm Wasm module lexer execution and JavaScriptCore bootstrap. Counts cover coalition creation through encoded document PNG, including startup/window work; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded. These instrumented counts supply no performance credit.

The latest complete matched result remains **24.226B versus 24.144B control** for leaf-query elision, with overlapping ranges. The [verification receipt](performance/chatgpt-opacity-measurements-verification-20261106.json) retains every focused/component attempt, prototype regression, source witness, command, counter, memory guard, PNG and rejected path audit. **The 20B target and original 5%-below-Brave target remain unmet.**

## Measurement-cache rejection diagnostics (2026-11-06)

Commits `af4e779c7` and `a1f81a253` add default-off, bounded scalar logging at actual measurement-collector failures. This diagnostic changes no eligibility rule. It prints at most 256 events and never formats layout/style owner graphs. Final checks pass **30 guarded jobs / 960 test-function executions** across ordinary GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers; each selected test runs with both opacity policies. The position-kind refinement additionally passes poisoned preallocation and both sanitizers.

Two fresh original-origin replay captures pass full content/button identity, JavaScriptCore bootstrap and exact unchanged reference pixels. Every executable/library/tool/fixture hash stays fixed during each capture, both browsers exit zero and the memory guards record successful PID adoption. The final capture authenticates executable `ef8e74bbedd96aa8828432a72ace6380c310aa669f7476d27f7d36252304888a`. The first position preflight expected the wrong generated getter name and exits before any browser launch; its corrected attempt is retained alongside the failure.

| Bounded diagnostic | First capture events | Position-kind capture events |
| --- | ---: | ---: |
| All collector rejections | 139 | 154 |
| Unshifted-position guard false | 116 | 128 |
| Pseudo-element flag true | 40 | 44 |
| Animated styles among reported inputs | 0 | 0 |

| Position kind in final capture | Rejection events |
| --- | ---: |
| Absolute | 99 |
| Relative | 26 |
| Static | 26 |
| Sticky | 3 |

These are rejection **events**, not distinct DOM elements, elapsed-time shares or instruction counts. Multiple flags coexist, the combined guard does not isolate a single cause, and layout node addresses can be reused after a rebuild. Earlier subtree rejection can hide animated descendants; zero reported animations does not mean the page has no animations. The records motivate checking ordinary absolute descendants whose containing/static-position dependencies stay within a measured subtree. Persistent reuse, generated content, controls, shifted relative/sticky positioning and external dependencies still need their full algorithms.

No unprofiled optimization cohort or broad checkpoint follows from logging. The [verification receipt](performance/chatgpt-measurement-rejections-verification-20261106.json) retains the test controllers, source witnesses, generated C, rejected preflight, both captures, PNGs and memory guards. **The 20B target remains unmet.**

## Ordinary absolute descendants in within-pass measurements (2026-11-06)

Commits `7bab2ab7c` and `55b347634` extend the shared within-pass grid/flex measurement cache to ordinary absolute HTML descendants. The snapshot owns their static-position/grid-area records, line/glyph payloads and rare data after producer scratch retirement. Final absolute sizing/positioning still executes. The root stays caller-owned; persistent layout caches retain their original guard. Only a bounded set of ordinary HTML tags is admitted, and containing/static-position dependencies must stay inside the captured subtree. Absolute roots, controls/specialized elements, generated content, fixed/sticky/shifted relative positions, anchors/calculated insets and external dependencies remain excluded.

The final policy waits for a second question before retaining a context. A matching cached entry that fails validation, or an absolute entry that fails post-layout validation, retires this context for the rest of the pass. Exact geometry keys and complete style revision, text, membership, font and image checks remain. Absolute subtrees explicitly fail the proof that external heights are unused, so height-relaxed reuse cannot apply. Admission state is released with the pass pool.

Final validation passes **12 guarded jobs / 416 test-function executions**: 52 selected functions, both policies, ordinary GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers. Tests compare complete numeric/glyph/static/grid-area geometry with a separate unpooled algorithm before and after final absolute layout, including inline static positions, percentages, RTL/alignment, nested positioning, committed consumption, producer retirement, rare-data copy-on-write, mutations/raw aliases, containing-block changes and pool release. Two initial test attempts incorrectly required readmission after a style mutation despite stale absolute-text font projections; the corrected test demands invalidation and exact outputs while allowing safe fallback. Both rejected attempts and the passing earlier prototype selection are preserved.

| Component: 100 calls | Final control median | Final candidate median | Reduction |
| --- | ---: | ---: | ---: |
| Ordinary absolute child, grid | 8,425,672.5 | 2,223,441.5 | 73.6111% |
| Ordinary absolute child, flex | 5,476,414.0 | 2,027,056.5 | 62.9857% |
| Nested absolute child | 13,408,588.0 | 2,582,639.0 | 80.7389% |
| Plain grid control | 2,085,897.5 | 2,085,939.5 | -0.0020% |
| Plain flex control | 1,865,364.0 | 1,865,376.5 | -0.0007% |
| External containing block | 8,315,164.0 | 8,305,976.5 | 0.1105% |
| Fixed descendant | 8,315,595.0 | 8,315,176.5 | 0.0050% |
| Inset changes each call | 8,434,756.0 | 8,458,193.0 | -0.2779% |
| Fresh pool each call | 69,064,505.5 | 70,992,755.0 | -2.7920% |

Setup, first document layout/styles and one warm question are outside the component counter interval. The interval includes 100 probe creation/layout/release operations and any mutations, pool turnover and checksums. A separate final-absolute numeric/glyph oracle runs outside timing. Four observations per variant are retained. The immediate-admission prototype saves 64.8–82.2% on repeated eligible scenes but regresses 25.1266% with changing insets and 12.5800% with fresh pools; the final policy reduces those regressions to 0.2779% and 2.7920%. These are component totals, not a page attribution.

The production source preflight authenticates the final collector, dependency closure, input validation, delayed admission, retained-scope rejection, owned geometry and conservative height guard. The first preflight expected a symbolic absolute enum after preprocessing; V -prod emits numeric `((css__Positioning)(2))`. That attempt launched no browsers. The corrected preflight passes, and separate diagnostics observe the useful reuse marker only with the candidate; both Vox modes confirm Wasm lexer execution and bootstrap.

| Unprofiled frozen-page variant | Every retained launch-through-PNG count | Median |
| --- | --- | ---: |
| Retained full-layout control | 24,213,674,700; 24,231,495,382; 24,210,542,578; 24,233,397,083 | 24,222,585,041.0 |
| Absolute-descendant candidate | 24,240,110,557; 24,250,780,084; 24,214,104,062; 24,232,933,993 | 24,236,522,275.0 |

The candidate median is **0.0575% higher**. Conservative observed separation is **-40,237,506 instructions**. Ranges overlap; page credit and broad carry remain zero, so no new 5M broad checkpoint is due. The result does not demonstrate a whole-page gain.

All **20** captures pass complete content/button identity, JavaScriptCore bootstrap, exact unchanged per-engine pixels and normal browser/kernel exits. Executable `4c101683471d3cac7e38dc42222c043a42317c49004c678c686e079848aaff2f` and native libraries/tools/fixture stay fixed under one nonblocking shared publication lease. Capture/controller guards exit zero and verify PID adoption; comparison drivers return one for the unmet Brave threshold. This uses the latest completed single-C-unit V -prod bundle, with no copied app or manual build request.

The same one-time SOCKS capture and original scripts/references, private profiles/caches, 1024×768 scale two and five-second unfocused settle remain fixed. Counts cover coalition creation through completed encoded document PNG, including startup/window setup; Brave also includes CDP delivery. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded. Four control/candidate pairs are diagnostic, below seven-pair acceptance. No live-site or isolated rendering claim follows.

The candidate median remains **4,236,522,275.0 instructions above 20B**. The [verification receipt](performance/chatgpt-absolute-measurements-verification-20261106.json) retains every component/prototype result, failed test/preflight, source witness, guard, PNG, counter, command and identity. **The 20B target and original 5%-below-Brave target remain unmet.**

## Inner measurements of ordinary absolute roots (2026-11-06)

Commit `2cbfbfeef` admits ordinary absolute grid/flex roots to the same bounded within-pass inner measurement cache. The caller still owns and recomputes outer sizing/positioning; the cache restores local descendant geometry and grid tracks only. Complete root dimensions, edges, constraints, immediate containing-block dimensions/definiteness and external size bases remain in the key. Absolute roots fail the unused-height proof, so relaxed external-height matching cannot apply. Non-root absolute dependencies must still remain inside the subtree. Persistent caches and specialized elements/positions retain their guards.

The final **12 guarded jobs / 440 test-function executions** pass: 55 functions, two policies, ordinary GC, no GC, poisoned preallocation and address/undefined-behavior sanitizers. Additional tests compare numeric/glyph/static/grid-area geometry before and after full outer absolute positioning, including changed external dimensions, RTL, auto/percentage insets, nested absolute children, committed consumption, root style mutation and caller-owned static rectangles. The first test/component oracle omitted the external block for static-position adjustment and correctly tripped the subtree scope check; the repaired harness explicitly supplies that context without weakening engine guards. Both failed attempts remain archived.

| Inner-layout component: 100 calls | Control median | Candidate median | Reduction |
| --- | ---: | ---: | ---: |
| Absolute grid root | 9,880,896.5 | 1,983,535.0 | 79.9256% |
| Absolute flex root | 6,587,773.0 | 1,735,460.0 | 73.6563% |
| Nested absolute root | 10,409,233.0 | 2,296,674.0 | 77.9362% |
| Alternating external width | 10,045,291.0 | 2,291,395.5 | 77.1894% |
| Root inset changes each call | 9,892,102.5 | 9,969,258.5 | -0.7800% |
| Fresh pool each call | 77,102,979.0 | 79,239,182.0 | -2.7706% |
| Plain grid control | 1,993,244.0 | 1,993,249.0 | -0.0003% |
| Plain flex control | 1,772,710.5 | 1,772,735.5 | -0.0014% |
| Fixed root, excluded | 9,880,935.5 | 9,880,910.5 | 0.0003% |

Setup, initial document layout/styles and one warm question are excluded. The counter interval includes 100 inner probe create/layout/release operations and mutations/pool turnover/checksums. Full outer absolute positioning and an independent unpooled numeric/glyph oracle run outside timing. Four observations per variant retain the changing-inset and fresh-pool regressions. No component count is extrapolated to the page.

Completed production executable `f8fa18eac7016b66459b67811bcf509141983f0948ac801ae1bc8463d6aa04f2` contains the final code and passes sealed-source proof. Four fresh Vox/Brave diagnostics pass full content/button identity, JavaScriptCore bootstrap, exact unchanged per-engine pixels and normal browser/kernel exits. Both Vox variants confirm Wasm lexer execution. **Neither Vox variant emits the useful absolute-root reuse marker.** The path audit therefore rejects with controller/guard exit one, while PID adoption succeeds and identities remain fixed. No unprofiled matched comparison is launched.

The original one-time SOCKS capture/scripts/references, fresh private profiles/caches, 1024×768 scale two and five-second unfocused settle remain fixed. The latest completed single-C-unit V -prod bundle and libraries stay pinned under a nonblocking shared publication lease; no app is copied or build manually requested. Diagnostic counters supply no optimization credit. OS filesystem/shader caches remain retained; GPU/outside-coalition work remains excluded.

Page credit and broad carry remain zero; no new 5M broad checkpoint is due. The latest complete matched result remains **24.237B candidate versus 24.223B control** for ordinary absolute descendants, with overlapping ranges. The [verification receipt](performance/chatgpt-absolute-root-measurements-verification-20261106.json) retains both failed harnesses, all final tests/components, source witnesses, commands, guards and four audited captures. **The 20B target and original 5%-below-Brave target remain unmet.**

## Main-thread instructions separated from concurrent work (2026-11-06)

Commits `f30e39128` and `74cea9071` add a separate opt-in main-thread counter stream and reconciliation tool. [XNU defines the calling-thread counter ABI](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/resource_private.h). The adapter weak-imports the SPI, checks the 16-byte layout, and fails closed when unavailable or zero. Existing process/coalition readings remain independent. Native capture records matching main-thread PNG checkpoints; no thread count substitutes for a process count in performance acceptance.

Validation passes **21 successful guarded jobs**, **144 V test-function executions**, native O2/ASan/UBSan separation/error tests and **28 parser tests**. Actual native worker probes record roughly 35M worker instructions while the waiting main thread records about 50K–93K. All four V storage/GC modes have matching and balanced process/thread scope IDs; disabled and process-only runs emit no thread scopes. Unavailable/missing/malformed/crossing/regressing traces are rejected. The initial reserved V variable and copied controller allocator-source check are retained, and the controller continuation executes the already-compiled sanitizer binary without repeating completed checks.

The completed executable `9323ac1487ca70d40d7edf5c6f282a19faad57b74cab8d1201a1c5f078ed020d` passes source proof and all four fresh content/button/bootstrap/pixel/browser/kernel audits. The dual trace totals **27,755,338,707** coalition instructions, with **24,064,901,879** cumulative instructions on the main thread and **3,690,436,828** in the signed remainder. The separate untraced observation is **24,227,403,169**. One observation per mode cannot estimate tracing overhead or establish optimization acceptance. No value is scaled to the untraced run, historical 29B totals or the 20B target.

The main-thread style scope records **4,335,621,050** instructions. Module-completion and JS/bindings scopes together record **5,443,528,378** on that thread; those phases also include native host/source/callback work and are not a pure JavaScript-engine total. The 3,690,436,828 remainder includes other threads, helpers and endpoint sampling differences; it cannot be assigned wholesale to JavaScript.

| Exclusive main-thread stage / explicit residual | Calls | Instructions | Share of traced coalition total |
| --- | ---: | ---: | ---: |
| style_update | 1,009 | 4,335,621,050 | 15.6209% |
| other_threads_helpers_and_endpoint_skew | 0 | 3,690,436,828 | 13.2963% |
| javascript_module_completion | 264 | 3,351,384,879 | 12.0747% |
| browser_main | 1 | 2,470,842,828 | 8.9022% |
| javascript_execution_and_bindings | 1,931 | 2,092,143,499 | 7.5378% |
| absolute_positioned_layout | 11 | 1,871,842,080 | 6.7441% |
| paint_layer_transition | 103 | 1,787,885,705 | 6.4416% |
| platform_timer_delivery | 2,454 | 644,056,641 | 2.3205% |
| css_parsing | 11 | 555,771,161 | 2.0024% |
| paint_leaf_text | 222 | 554,267,938 | 1.9970% |
| gpu_frame_finalization | 17 | 399,689,762 | 1.4400% |
| paint_leaf_fill | 160 | 362,083,574 | 1.3046% |
| frame | 504 | 357,209,708 | 1.2870% |
| frame_preparation | 504 | 353,453,794 | 1.2735% |
| background_resource_completion | 504 | 348,340,399 | 1.2550% |
| paint_leaf_shadow | 27 | 344,792,903 | 1.2423% |
| paint_leaf_border | 89 | 324,552,038 | 1.1693% |
| document_layout | 1,000 | 296,205,261 | 1.0672% |
| html_networking_task | 533 | 253,287,930 | 0.9126% |
| html_rendering_task | 489 | 238,196,503 | 0.8582% |
| paint_leaf_svg | 166 | 232,959,498 | 0.8393% |
| html_event_loop | 1,270 | 232,466,406 | 0.8376% |
| native_raster_replay | 504 | 217,388,281 | 0.7832% |
| native_document_replay | 504 | 199,842,597 | 0.7200% |
| navigation_html_parsing | 1 | 182,892,953 | 0.6589% |
| unscoped_main_thread | 0 | 164,761,884 | 0.5936% |
| paint_command_dispatch | 17 | 152,427,005 | 0.5492% |
| layout_tree_construction | 9 | 134,360,729 | 0.4841% |
| viewport_relayout | 7 | 130,234,848 | 0.4692% |
| flow_layout | 11 | 122,466,660 | 0.4412% |
| stationary_raster_finish | 504 | 117,357,040 | 0.4228% |
| paint_command_recording | 19 | 111,918,882 | 0.4032% |
| script_runtime_setup | 1 | 107,364,826 | 0.3868% |
| native_frame_bitmap | 504 | 101,333,461 | 0.3651% |
| native_frame_presentation | 504 | 91,095,203 | 0.3282% |
| stationary_raster_probe | 496 | 90,509,557 | 0.3261% |
| browser_tab_frame | 504 | 87,111,269 | 0.3139% |
| paint_leaf_effect_end | 26 | 86,564,803 | 0.3119% |
| script_state_replay | 1,003 | 71,537,509 | 0.2577% |
| native_window_initialization | 1 | 70,940,628 | 0.2556% |
| document_install | 1 | 57,428,886 | 0.2069% |
| html_other_task | 226 | 55,064,822 | 0.1984% |
| browser_chrome | 511 | 43,793,841 | 0.1578% |
| scroll_raster_probe | 17 | 43,625,406 | 0.1572% |
| html_rendering_opportunity | 504 | 31,193,279 | 0.1124% |
| layout_geometry | 11 | 30,804,685 | 0.1110% |
| raster_frame_commit | 17 | 29,983,802 | 0.1080% |
| animation_driver | 504 | 22,684,679 | 0.0817% |
| png_encoding | 1 | 18,660,878 | 0.0672% |
| stationary_raster_eligibility | 496 | 16,868,704 | 0.0608% |
| native_frame_context | 504 | 15,472,635 | 0.0557% |
| raster_frame_setup | 17 | 14,964,397 | 0.0539% |
| initial_resource_preload | 1 | 8,728,282 | 0.0314% |
| html_posted_message_task | 17 | 8,164,127 | 0.0294% |
| style_computation | 29 | 6,923,862 | 0.0249% |
| capture_snapshot | 1 | 5,875,085 | 0.0212% |
| raster_tile_setup | 17 | 3,556,690 | 0.0128% |
| paint_leaf_effect_begin | 26 | 1,332,976 | 0.0048% |
| html_timer_task | 5 | 907,387 | 0.0033% |
| relative_positioned_layout | 11 | 750,314 | 0.0027% |
| viewport_raster_plan | 17 | 562,200 | 0.0020% |
| stationary_blank_probe | 8 | 310,108 | 0.0011% |
| capture_conversion | 1 | 83,142 | 0.0003% |

| Total | | 27,755,338,707 | 100% |

The [process table](performance/chatgpt-thread-load-stages-production-r1-traced-20261106.json) remains separately available. Each stream subtracts its own nested children and clips open scopes at its own PNG reading. Inclusive rows overlap. Per-stage process-minus-main differences are not additive worker counts: the counter reads are interleaved and instrumentation is charged differently between parent/child self intervals. The residual is explicitly qualified rather than labeled as measured JS or helper work.

The traced and untraced runs complete **504** and **506** frame checkpoints. Neither result is normalized by frame count. The same original SOCKS fixture/scripts/references, 1024×768 scale two, five-second unfocused settle, fresh private profiles/caches and retained OS filesystem/shader caches apply. One current completed single-C-unit V -prod executable/libraries/tools/fixture stays fixed under a nonblocking shared publication lease. No app is copied or build manually requested. GPU/outside-coalition work remains excluded.

The [verification receipt](performance/chatgpt-thread-load-stages-verification-20261106.json), [main-thread JSON](performance/chatgpt-thread-load-stages-production-r1-main-thread-20261106.json) and [CSV](performance/chatgpt-thread-load-stages-production-r1-main-thread-20261106.csv) retain every exact count, old/new table, command, source witness, counter, PNG, memory guard and failed attempt. Both additive 63-row tables sum exactly to the same captured total. No page savings or broad carry are credited. The latest complete unprofiled matched comparison remains 24.237B candidate versus 24.223B control with overlapping ranges. **The 20B target remains unmet.**

## Style recomputation causes on the frozen page (2026-11-06)

The independent main-thread budget identifies style updates as a substantial cost. Two fresh captures enable existing runtime style-cause/element diagnostics; the second also enables bounded invalidation-source examples. Both pass complete content/button/bootstrap identity, exact unchanged reference pixels, normal browser exits and stable input identities under their publication leases. No source change, copied app or manual build is required.

| Recompute cause | First capture events | Second capture events |
| --- | ---: | ---: |
| Full document style update | 2,681 | 2,681 |
| Explicit dirty flag | 1,909 | 1,909 |
| Parent display changed | 1 | 1 |
| Ancestor requested descendant recomputation | 433 | 459 |
| Custom-property dependent | 298 | 370 |
| if() media dependency | 0 | 0 |
| Font-only refresh succeeded | 0 | 0 |
| Font-only fallback | 0 | 0 |

Each capture reports **1,909 explicit dirty events** across **342 label strings**. The same URL/tag/ID/class label can describe multiple elements and repeated updates. Link elements with empty ID/class account for 553 events, paths 239, groups 79 and use elements 61. These are not instruction shares or evidence that any particular update can be skipped. The bounded source trace observes stylesheet replacement/addition, DOM insertion/removal, shadow-root installation and attribute changes, including link `rel` and document data attributes. A full document style pass can legitimately be required after stylesheet changes; source examples are capped at eight events per source/reason key and cannot establish exact causal totals.

The [verification receipt](performance/chatgpt-style-causes-verification-20261106.json) preserves both raw logs, commands, source proofs, PNGs, audits and memory guards. The next style investigation must distinguish required cascade updates from avoidable recomputation while preserving selector, inherited/custom-property, font, shadow and live stylesheet behavior. No optimization cohort or new 5M broad checkpoint follows from these logs. **The 20B target remains unmet.**
