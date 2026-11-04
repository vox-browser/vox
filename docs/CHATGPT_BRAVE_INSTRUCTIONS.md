# ChatGPT instruction comparison

The requested 5% advantage over Brave remains **unmet**. The latest complete
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
