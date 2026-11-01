# BBC homepage instruction comparison

**The requested 10% advantage remains open. BBC does not qualify for
`OPTIMIZED_SITES.md`.** The latest seven-pair cohort (30) has a Vox median of
**35,907,301,467** retired instructions and a Brave lower-bound median of
**15,955,255,013**. All 21 content audits, unchanged pixel comparisons and native
exits pass. Its conservative ratio is **2.3261551572669523**, above 0.9:
`369121266050 > 142814695059` fails the integer gate. Every observation,
including first launches, remains included.

The same-binary user-style-change control has median 35,633,312,221. The
candidate median regresses 0.7689%, with conservative control ratio
1.0717219893655683; neither gate passes. Earlier failing and invalid observations
remain retained; no accepted BBC savings are claimed here.

The machine-readable [evidence](benchmark-results/bbc-brave-instructions-2026-11-01.json)
retains 743 attempts and 30 cohorts, including failures and first launches;
616 complete cohort raw results were independently checked against the recorded
vectors, medians and integer gates. It also retains ownership audits, commands and artifact hashes. Raw archives, logs,
PNGs, executable copies, PID registries, compiler output and guard receipts are
under `Build/bbc-home-instructions-20261101-054807/` in the canonical checkout.

## Workload and endpoints

The page is **https://www.bbc.com/**, rather than `/news`. A sealed, non-forwarding
HTTPS replay supplies 595 recorded responses and preserves the original author
scripts, 88 ordered card headlines and all 70 real photo sources. Its original
document is 641,643 bytes, SHA256
`f70fea0eaef611591f788542cfe93124c2e2768784d215c44204fd8c832968fa`.
The BBC font URLs which originally returned 404 still return 404; the audit
accepts only source-proven local Arial fallback faces.

Both engines use fresh processes, empty private profiles and browser caches,
clean proxy environments, a 1024×768 CSS-pixel document viewport, capture scale
2, the same replay and two seconds of settlement. OS filesystem and shader
caches remain warm. Vox uses JavaScriptCore explicitly, author JavaScript
enabled and cookie-banner blocking disabled. Brave uses V8 and its default
Shields policy. This is a frozen-page measurement; it does not establish that
the current live site is fixed.

Both counters cover exclusive resource-coalition creation through encoded
document PNG availability, including browser startup and native window setup.
Vox ends before writing the PNG; Brave includes CDP screenshot delivery and
window/target creation. Readiness polling and settlement are included; semantic
audits and teardown follow the endpoint. Coalition totals include exited
helpers and explicitly permitted owned services. GPU execution, the replay and
observer, and services outside the owned coalition are excluded. The guard
adopts LaunchServices browser PIDs and records their RSS.

The first seven-pair cohort failed because BBC relative timestamps changed
320 pixels. It remains in the evidence. The corrected fixture inserts one
shared wall-clock shim freezing `Date` at 1793503154007; monotonic timers remain
real. Its document SHA256 is
`81cf44b6b1539aef724eda00a1e1034def2170162fcdfa84d9bb5608c06cf171`.
This correction and the later visible-image decode readiness check earn no
engine optimization credit. Neither reference pixels nor tolerances changed.

## Complete cohorts

All statistics below include every trial in the respective seven-pair cohort.
Brave figures are medians of lower bounds; Vox bounds are equal at its native
capture marker. An invalid cohort is retained for diagnosis, not acceptance.

| Cohort | Vox median | Brave median | Maximum Vox upper / minimum Brave lower | Result |
| --- | ---: | ---: | ---: | --- |
| Corrected-clock baseline | 109,038,368,077 | 15,214,425,439 | 7.482949915090812 | Content and fixed references pass; instruction gate fails |
| Grid block-height reuse | 90,700,737,334 | 15,566,813,595 | 6.241506185808689 | Gate fails; Brave pair 5 photo differs |
| Disposable grid width probes | 71,087,924,913 | 15,830,667,000 | 4.987054269056659 | Gate fails; Brave pairs 3 and 6 photo differs |
| Stationary raster reuse | 75,303,556,310 | 15,575,369,841 | 5.409313292632096 | Gate fails; Brave pair 7 photo differs |
| Client-geometry index and tracked-arena shortcut | 65,708,093,045 | 15,584,042,718 | 4.367784478797594 | Gate fails; Brave pair 1 photo differs |
| JIT entitlement | 49,813,515,416 | 15,679,077,351 | 3.3100826753570693 | Gate fails; Brave pair 2 photo differs |
| Attribute-name buckets and scope-parent jumps | 47,129,217,196 | 15,646,633,009 | 3.2509168791412764 | All observations valid; gate fails |
| Guarded CSS-wide and border-slice reuse | 45,124,755,934 | 15,540,480,007 | 3.1224368328405316 | Gate fails; Brave pair 3 photo differs |
| Guarded RGB reuse | 44,077,336,320 | 15,549,390,499 | 3.340949257394858 | Gate fails; Brave pair 4 photo differs |
| Retained-command direct reads | 44,466,503,621 | 15,579,542,542 | 3.565802776525631 | Gate fails; Brave pair 4 photo differs |
| Retained ordinary flow items in grid/flex | 44,521,001,422 | 15,591,881,320 | 3.681015720678472 | All observations valid; gate fails |
| Selected-face display/failure invalidation | 46,582,465,131 | 15,619,372,290 | 3.3740750674717432 | All observations valid; gate fails; median regresses against control |
| Numeric-ratio, font-style and duration reuse | 44,005,434,509 | 15,397,702,164 | 3.037884119847623 | Gate fails; Brave pair 4 photo differs |
| Completed shared O3 production build | 42,995,770,723 | 15,723,370,671 | 3.110810439568189 | All observations valid; gate fails; no isolated compiler attribution |
| Intrinsic sizes across unrelated font completions | 43,359,803,356 | 15,823,854,730 | 3.368777312785835 | Gate fails; control pair 5 and Brave pairs 4/7 differ; median regresses against control |
| Original live pending-font intrinsic reuse | 40,329,352,824 | 15,970,908,247 | 2.8081095382756427 | All observations valid; Brave and matched-control gates fail |
| Text chunks and shapes with original live pending fonts | 40,577,716,115 | 15,788,336,728 | 2.6331015373715503 | All observations valid; Brave and matched-control gates fail |
| Original pending-font snapshots during style refresh | 39,333,822,066 | 15,621,067,131 | 3.1776463343078 | Gate fails; Brave pair 6 differs; median regresses against control |
| Selective style-only conditional-rule insertion | 38,669,617,935 | 15,723,338,132 | 2.5598256625689984 | All observations valid; Brave and matched-control gates fail |
| Filtering helper JIT entitlement | 37,990,584,359 | 15,546,241,164 | 3.0270279597468543 | All observations valid; median regresses against control; both gates fail |
| Skip inactive conditional-rule insertion | 37,396,821,455 | 15,731,322,435 | 2.514265550853879 | Brave pair 3 differs; Brave and matched-control gates fail |
| Classic-script import identifier filter | 37,463,386,894 | 15,655,612,802 | 2.4762586430968168 | All observations valid; median regresses against control; both gates fail |
| Viewport, grid-placement and radius longhand reuse | 37,314,150,142 | 15,652,929,710 | 2.510631500286319 | All observations valid; median regresses against control; both gates fail |
| Check own eligibility before inherited hashing | 36,574,920,629 | 15,732,111,035 | 2.43280501847826 | Brave pair 6 differs; median regresses against control; both gates fail |
| Indexed JavaScript roots | 36,723,883,384 | 15,720,570,525 | 2.4371307290010487 | All observations valid; median regresses against control; both gates fail |
| Shared geometry accessors, recovered production build | 34,949,303,465 | 15,879,294,537 | 2.31320003135991 | All observations valid; Brave and matched-control gates fail |
| Shared compact Node properties | 36,123,754,014 | 15,806,323,773 | 2.3259499042136356 | All observations valid; median regresses against control; both gates fail |
| Required attribute buckets before tag buckets | 36,673,262,472 | 16,116,361,443 | 2.3992396531867937 | All observations valid; Brave and matched-control gates fail |
| Selective ordinary style-rule deletion | 36,552,719,392 | 16,368,303,379 | 2.3885773998393387 | Brave pair 7 photo differs; median regresses against control; both gates fail |
| Plain user stylesheet subject invalidation | 35,907,301,467 | 15,955,255,013 | 2.3261551572669523 | All observations valid; median regresses against control; both gates fail |

The grid block-height cohort alternates an older control, candidate and Brave;
control/candidate medians are 101,567,929,247 and 90,700,737,334 (10.70% observed
reduction). The grid width cohort uses one binary with that path disabled only
in controls: 83,319,256,016 versus 71,087,924,913 (14.68% observed reduction).
These point estimates do not clear the conservative 10% control/candidate
gate. Shared builds also contain concurrent changes; unrelated binary changes
receive no credit for these individual paths.

The stationary cohort uses exactly the same binary on both sides, with only
`VOX_DISABLE_STATIONARY_RASTER_REUSE` differing. Its disabled control median is
73,283,491,627, so enabling the cache **regresses the median by 2.76%**. A
separate diagnostic proves 149 cache reuses and zero differing reference
pixels. Faster replay admits more native frames during settlement, increasing
preparation work; no net instruction improvement is credited to this cache.

The geometry/arena cohort uses one binary with both paths disabled only in
controls: medians 69,618,641,818 versus 65,708,093,045 (5.62% observed reduction).
Its conservative matched-control gate fails.

The JIT cohort compares the same compiled executable and libraries, differing
only in the code signature's `com.apple.security.cs.allow-jit` entitlement.
Every file-backed Mach-O section and other bundle file is verified unchanged.
WebKit's [executable allocator](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/JavaScriptCore/jit/ExecutableAllocator.cpp)
checks this entitlement on the measured system; Apple's
[entitlement documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.allow-jit)
describes its purpose. Controls have a median of 68,622,675,849 versus
49,813,515,416 with JIT (27.41% reduction). The conservative matched-control
ratio, 0.796913029622123, clears 0.9. Separate diagnostics positively observe
JavaScriptCore JIT/DFG compilation threads and identical results in a C API
probe. Probe counts are diagnostic, not BBC optimization credit. The BBC cohort
still fails the Brave target and retains its Brave photo difference.

The attribute/scope cohort compares the same binary with only attribute-name buckets
and allocation-scope jumps disabled in controls. Medians are 50,918,264,203
versus 47,129,217,196 (7.44% observed reduction); its conservative matched-control
ratio is 1.0424294404793093 and fails. Separate diagnostics execute both paths,
record one JavaScriptCore context and 2,002 evaluations, and match the original
Vox image exactly.

The CSS-wide/border cohort compares the same binary with only those cache
extensions disabled in controls. Medians are 45,745,943,469 versus
45,124,755,934 (1.36% observed reduction), but the conservative control ratio
is 1.1245313509465262 and fails. The RGB cohort leaves those extensions on
and disables only RGB reuse in controls: 44,235,991,934 versus 44,077,336,320
(0.36% observed reduction), with a failing conservative ratio of
1.2120385588929428. These point estimates do not establish optimization credit.
The RGB cohort retains the first Brave launch at 31,143,310,575 instructions;
no outlier was removed. Separate diagnostics prove both reuse paths execute
and preserve the original Vox image. RGB snapshots guard each channel, optional
name and syntax, and validate retained as well as candidate inputs against
in-place mutation. A component diagnostic reduces full property loops from
3,321 to 2,165 on copied SSR markup; it is not a browser instruction result.

The direct-read cohort uses one binary with value iteration enabled only in
controls. Generated C confirms that the old path allocates and copies each
complete retained command, while the candidate reads its fields through a
pointer. Medians are 45,081,443,598 versus 44,466,503,621 (1.36% observed
reduction); its conservative matched-control ratio is 1.2917547717477877 and
fails. Both paths preserve the fixed Vox reference in separate diagnostics,
with one JavaScriptCore context and 2,430/2,409 evaluations. Fresh processes
and all seven triples remain recorded, including first-launch outliers.
A later disassembly corrects the working diagnosis of the large sampled copy
under `begin_stationary_document_raster`: the call at offset +1212 follows
`CGContextFlush` and restores `native_stationary_raster.pixels`. The earlier
330 sample weights cannot be attributed to command scanning. Generated-C and
runtime witnesses still establish the direct-read path, but its conservative
instruction comparison fails and no accepted gain is claimed.

An initial attempt stopped after one control because another session changed
`tools/hacker_news_browser_instructions.py`. Its raw result and changed hashes
remain recorded. The complete replacement cohort uses an immutable copy of
15 exact committed measurement scripts, with the original script hash restored
by copying its committed version. No browser sources were copied. Original
failed-cohort data remain included in durable evidence.

A summary bug passed three-engine records to a strict two-engine evaluator,
which reported “Incomplete measured pair.” Commit `376a3c0b` projects the
Vox/Brave and Vox/control comparisons independently, validates all observations
and keeps the integer gate. Recomputed summaries use the original raw counts;
no endpoint, reference or trial changes. Earlier original summaries remain
retained. The corrected attribute/scope summary fails solely on the instruction gate.
Later cohorts retain their original pixel failures as well as failing counts.

For acceptance, at least seven alternating complete pairs must pass content,
pixels, identities and exits, and integer arithmetic must satisfy
`10 * max(Vox upper) <= 9 * min(Brave lower)`. No recorded cohort meets this.

## Rendering and execution limits

Every Vox image in the corrected cohorts matches its original reference
exactly. The attribute/scope cohort also has seven exact Brave captures. Earlier
recurring Brave differences affect 64,177 pixels within one photo.
The direct-read cohort differs at 304,064 pixels in that photo, with a maximum
channel error of 18. These failures have
unchanged image bytes, source URL, intrinsic dimensions and geometry.
Awaiting visible `img.decode()` did not remove these differences. Their cause remains unresolved;
those attempts are retained without exclusions or relaxed tolerances.

Per-engine stability is distinct from cross-browser equality. The reference
images differ at 2,448,723 of 3,145,728 pixels (77.8428%). Vox and Brave have
different consent/ad spacing and vertical positions; their hydrated image
counts also differ, despite matching all source headlines and real photos.
Vox rejects a BBC module fetch lacking the required CORS header, and another
BBC script reports a load timeout. These are rendering and scripting limits.

A separate injected JavaScriptCore diagnostic records one context, one group
and 1,938 evaluations, with the runtime initialized and React/CSSOM hydration
executed. The grid diagnostics separately prove the optimized paths execute.
The selected backend has no observed LibJS fallback. These instrumented runs
receive no hardware-counter performance credit.

The newest measured executable is SHA256
`2226008c70cb493c9decd4092b9dd0e695854300ba39c488c703ce91520f45d6`.
The preceding font-display candidate is
`5aae83a4408e023380d51e4430003b519ec427bcd96b3701b634930eeda62952`.
The JIT-only candidate is
`ea63463d5d1e7c6d28c320fbf2060eead45490e549a2ac45f607ccdff8e65c89`.
Native-library identities, source snapshots, entitlement checks and generated-C
witnesses are recorded. Concurrent source edits are disclosed; same-binary
controls isolate the measured runtime switches.

One RGB validation attempt passed its image checks but is invalid because an
early executable search path loaded Skia from shared `Build/v`, where another
build replaced it during validation. Commit `b3e01505` removes that search path
before signing. The corrected private candidate loads its own bundled Skia,
verified in a fresh process with dyld logging. All file-backed executable code
and data sections and bundled libraries remain byte-identical; only load
commands and the signature change. This packaging repair receives no engine
instruction credit. The original failed identity validation remains recorded;
the later checks and RGB cohort have stable private library identities.

## Verification and remaining work

Focused grid, CSSOM, initial-value cache and native raster checks pass in their
recorded GC modes. The pinned production browser passes `--headless-smoke`,
all 11 default screenshot cases (eight exact, three under existing bounds),
and all eight required SVG mutation cases exactly. All 100 upstream LibJS AST
fixtures match exactly.

The current broader rerun enters all 397 cases in both normal and no-GC
modes (80 fresh no-GC processes). Each mode passes 396 cases and retains one
input baseline mismatch: Vox returns 13.5 where the unchanged test and an
independent Brave content-box oracle require 13. The prior font-fingerprint
memory failure is corrected and its previously interrupted cases now complete.
Earlier failed attempts, including the missing receipt after guard cleanup
failed, remain recorded. The input baseline failure keeps broad verification
open.

All 45 allocator checks pass in normal, no-GC and preallocated modes, including
a preallocated run with scope jumps disabled. Nine selector checks pass in
normal and no-GC modes. The benchmark tools pass 177 Python checks. The RGB cache passes 19 focused
checks in normal, no-GC, preallocated and diagnostic modes. Two real Mach-O
loader checks verify bundled-library selection and reject a missing fallback.
The newest pinned browser passes headless startup, all 11 screenshot smoke
cases and all eight SVG mutation cases. These checks do not establish full
BBC rendering or scripting parity.

The remaining work is to reduce the full launch/capture workload sufficiently
to pass the conservative Brave gate while preserving content and references.
The direct-read scan passes five focused checks in normal, no-GC and preallocated
modes, with the copy-based control also checked in each mode. Its production
bundle passes headless startup, the complete smoke set and all eight SVG cases
with stable private library identities. An initial test-wrapper attempt failed
before screenshot launches because its copied capture script lacked execute
permission; that failure is retained and the corrected wrapper passes.
Retaining unchanged ordinary flow items inside grid/flex parents passes all 20
focused flow checks in normal, no-GC and preallocated modes, with the disabled
control also checked in each mode. An initial preallocated failure exposed
unleased old paint scenes in test setup; the corrected checks retain the old
scene while asserting its unchanged dump. Both attempts remain recorded.
Fresh candidate/control diagnostics prove the path executes only when enabled,
match the original Vox reference exactly, and record JavaScriptCore execution
(2,023 and 2,083 evaluations). A separate sampled profile also matches exactly
and receives no instruction credit. The unprofiled matched control median is
45,640,904,010 versus candidate 44,521,001,422, a 2.4537% point reduction. Its
conservative ratio is 1.3286517869182544, so no accepted gain is claimed. All
21 content/pixel/exit checks pass; both Brave outliers remain included. The
integer Brave gate fails: 571,440,242,190 > 139,715,843,940.

Selected-face display/failure invalidation passes all 26 focused font checks
in normal, no-GC and preallocated modes with enabled and disabled paths. Tests
cover selected weights, fallback visibility across block/swap/failure periods,
root metrics, pseudo/shadow styles and unknown-face family-wide fallback. The
first test attempt accidentally initiated fixture network requests and applied
an equality helper which deliberately rejects pending cascades; its results
are retained, and the corrected fixtures hold pending requests explicitly.
The original screenshot and SVG checks remain unchanged and pass. The broader
397-case run again passes 396 in each GC mode, retaining the baseline failure.
The shared build had stable font implementation inputs; moving the added tests
into their self-contained existing test file changed only test inputs. A pin
wrapper failed when sorting fingerprint dictionaries after copying the app;
the corrected metadata comparison verified source and private identities.

Fresh BBC diagnostics expire 2 and 9 selected font cascades while retaining
15 and 8 others; disabled controls have no such trace. Both original Vox
references match exactly, with 2,008/2,475 JavaScriptCore evaluations. The
separate sampled profile also matches exactly and earns no instruction credit.
The unprofiled cohort has control median 45,601,371,313 versus candidate
46,582,465,131: a **2.1515% median regression**, with conservative control
ratio 1.185424334779776. No improvement is credited. All 21 observations pass
content, reference pixels and exits; Brave pairs 1 and 4 exceed 30 billion and
remain included. The integer Brave gate fails:
521,875,603,630 > 139,204,977,327. A preceding command failed argument validation
before launching any browser and remains recorded separately.

Separate CSS diagnostics use a private build from captured production C and
pinned native objects, with only diagnostic counter bodies enabled. The
production candidate keeps those counter bodies empty. Both builds retain
complete compiler commands, source hashes and memory-guard receipts. The
first private compile used a relative C path from the wrong working directory;
that failure and the corrected successful compile remain recorded.

The final cumulative diagnostic scopes report 10,835,972,177 instructions in
rule collection and 9,517,382,464 in computed-property construction. The latter
includes 7,653,319,585 in 6,709 longhand loops. These are instrumented
**per-process, overlapping inclusive scopes**, with counter overhead; they are
not coalition acceptance counts and cannot be added or credited as savings.
All diagnostic captures match the original Vox reference exactly.

A separate cache-capacity probe compares the existing 256-entry limit with a
4,096-entry diagnostic limit. Both peak at 204 entries with zero capacity
rejections, so the production limit remains unchanged. Another probe counts
2,556 first ineligible declarations: numeric aspect ratios account for 1,031,
explicit font styles for 382, and transition durations for 98. These probes
receive no instruction credit.

Commit `0cf79695` adds typed snapshots and hashes for numeric ratios, font
styles without an angle and time values. Calculated ratios and angled font
styles retain their ordinary computation path. Font snapshots also preserve
angle presence, unit and numeric payload: `normal` and `oblique 0deg` serialize
identically, so text alone cannot guard mutations. All 27 cache checks pass in
normal, no-GC and preallocated modes, with enabled and disabled controls. The
first compile failed on an invalid concrete-type name accessor; corrected
checks and all attempts are retained. The broader run enters all 397 cases in
both GC modes, with the same sole input-baseline failure. The benchmark tools
pass 177 checks. The production candidate passes headless startup, all 11
smoke cases and all eight SVG cases with stable executable/library identities.

Fresh BBC diagnostics observe a restored ratio only on the enabled path, with
2,013/2,427 JavaScriptCore evaluations in candidate/control. Both captures
retain complete content audits and match the original Vox reference exactly.
The site catalog must wait for a qualifying cohort. Startup counts establish
neither isolated rendering time nor scrolling FPS.

The unprofiled constant-longhand cohort uses the same executable for control
and candidate, with only `VOX_DISABLE_CONSTANT_LONGHAND_REUSE` set in controls.
Control median 44,338,719,862 versus candidate 44,005,434,509 is a 0.7517%
point reduction; pairs 3 and 7 regress. The conservative matched-control ratio
is 1.1304975685237806, so no accepted improvement is credited. All 21 semantic
audits and native exits pass, and all 14 Vox/control pixel checks are exact.
Brave pair 4 differs in 304,064 photo pixels (maximum channel error 18) and
remains included with its failed audit exit. No Brave trial exceeded 30 billion
instructions in this cohort. The integer target fails:
465,554,457,010 > 137,924,619,498. The guard adopts 69 process identities,
reports no adoption error and peaks at 1,478,508,544 bytes over 130.48 seconds.
The initial production build attempt found the shared guard busy; after that
separate C-capture job completed without an installed candidate, the required
production build completed in 255.44 seconds, peaking at 8,791,277,568 bytes.
Its cache implementation inputs were stable throughout the build. A separate
layout-counter diagnostic supplies no acceptance or engine instruction credit.

The first layout probe records overlapping recursive intervals, some exceeding
the entire process count. A second probe separates outermost selected intervals
and counts cache activity. It observes 402,520 intrinsic-cache hits, 14,009 empty
slots, 6,914 font-epoch expirations and 19,609 resets. Its 20,318 minimum and
20,292 maximum width probes motivate investigating font-epoch reuse. Both
captures retain complete content and match the original Vox reference exactly.
The second private compile overlaps an edit to `native_graphite_dawn_darwin.mm`;
the receipt verifies that this source was neither a direct compiler input nor
included in the generated C. The diagnostic instead links pinned native objects.

Counter overhead is material. Three separate calibrations of the same Darwin
process-counter helper each retain 10,000 consecutive-read intervals, with
medians of 6,534, 6,559 and 6,559 instructions. Nested scope totals therefore
cannot establish uninstrumented CSS or layout costs. No calibration value is
subtracted from acceptance counts or claimed as engine savings. Refined sampled
stack analysis also remains diagnostic wall-clock evidence.

The next seven-pair comparison reuses a completed shared production build
(`f73d60545c98f002b96ad3be1340d288f695593c4a8c72f24dc37e5458d8ad9f`)
with the shared O3 compiler setting. All 14 observations pass content, original
pixels and exits. Its integer gate still fails:
487,128,908,650 > 140,933,054,682. Brave's first launch exceeds 31 billion
instructions and remains included. Concurrent engine changes prevent attributing
the difference from earlier cohorts to O3 alone.

Commit `77ed7129` records a cascade's creation generation and retains intrinsic
dimensions across later unrelated font completions only when every subtree and
ancestor cascade is still original and live. Pending, unknown or replaced
cascades, changed rendering policies and containing blocks outside the parent
chain retain recomputation. Normal style/tree invalidation still resets caches.
All 11 CSS and 13 layout checks pass in normal, no-GC and preallocated modes,
including disabled layout controls. Both broad modes enter all 402 cases and
pass 401, with the same sole input-baseline failure. The matched benchmark
control in `1badee84` passes the 179-check instruction-tool suite.

The first build attempt finds the production guard busy. The completed shared
build includes an earlier version without the final containing-block guard,
as witnessed in captured compiler input, so it cannot validate that guard.
The required final build completes in 397.00 seconds, peaking at 7,088,160,768
bytes with all six implementation/test inputs stable. Its executable SHA256 is
`664599f14e25df9e0bdbdafb5f81e58e7386dd6d54bfb60511814b8d6a96801a`.
Captured C confirms the final guard and inactive CSS instruction scopes.
Startup, 11 smoke cases and eight SVG cases pass with stable identities.
The first screenshot jobs stop before browser launch because the prepared
capture helper lacks executable permission; corrected checks and both failed
attempts remain retained.

Separate BBC diagnostics observe the new path only when enabled, with one
JavaScriptCore context/group and 2,508/2,451 evaluations in candidate/control.
Both captures match the original reference exactly. The uninstrumented cohort
uses one executable, changing only `VOX_DISABLE_INTRINSIC_FONT_REUSE` in controls.
Its control median is 43,222,471,464 versus enabled 43,359,803,356, a **0.3177%
median regression**. Pairs 4 and 5 regress, and the conservative control ratio
is 1.2555710949355419. No instruction improvement is credited.

All 21 content audits and native kernel exits pass, but control pair 5 differs
in 545,271 pixels and Brave pairs 4/7 differ in 64,177/304,064 photo pixels.
The control image visibly has an underlined central headline and faded photo,
consistent with a hover effect; it remains a failed observation. All seven
enabled Vox captures match exactly. Brave pairs 1 and 2 exceed 31 billion and
remain included. The integer Brave gate fails:
526,191,905,120 > 140,577,031,557. The guard adopts 71 identities without error,
peaking at 1,468,874,752 bytes over 174.31 seconds. BBC remains outside the
optimized-site catalog.

A subsequent count-only diagnostic keeps hardware-counter scopes inactive and
matches the original Vox pixels and content. It observes 13,224 longhand-cache
hits and 1,230 lookup misses, plus first unsupported declarations led by
`background-position-x` (375), `grid-template-columns` (329), `grid-column-start`
(247) and `border-top-left-radius` (192). Of 2,084 intrinsic font-epoch checks,
471 retain the cache; 1,613 first reject pending fonts. That first-rejection
classification does not establish whether those pending cascades are still
live, so it cannot justify relaxing the guard. Concurrent edits to included
`native_capture_darwin.m` and the separately pinned Skia implementation remain
disclosed; this private build supplies diagnostic leads, not isolated
performance evidence. A follow-up probe saves its preprocessed compiler input
and distinguishes original/live pending cascades from expired or newer ones.

The follow-up count-only capture also matches the original pixels, complete
content and native exit. It observes 5,023 epoch checks: 781 retained caches and
4,242 pending rejections. All 4,242 pending cascades are original and live;
none is expired or newer than the cached geometry. This identifies a candidate
for investigation, without instruction credit. Saved preprocessed compiler
input pins included native sources despite concurrent edits. The compile
passes, but initial signing rejects compiler bitcode saved inside the bundle.
Moving only those intermediate artifacts into the adjacent evidence directory
and signing the same executable fixes the diagnostic packaging; both attempts
and artifact hashes are retained.

Commit `b8074e59` extends intrinsic reuse to original, live pending cascades.
Selected-face completion, failure and display-period changes still expire the
cascade; an already-refreshed replacement cannot validate earlier geometry.
The same proof also serves resolved CSS geometry. Unknown inputs, changed
styles and external containing blocks retain their earlier guards. All 16 CSS
and 14 layout checks pass in normal, no-GC and preallocated modes, including
disabled controls. Both broad modes enter all 403 cases and pass 402, with the
same sole input-baseline failure. Matched-control tooling `9719b766` passes all
180 instruction-tool checks.

The required production build finishes in 470.54 seconds, peaking at
6,503,596,032 bytes with its own implementation/test inputs stable. Its pinned
executable SHA256 is
`f9ae4f7c5745ab3cde140485e99f2fca41a98bd98255d27ebfbaed9b55880738`.
Captured compiler input witnesses the original/live pending guard. Startup,
11 smoke and eight SVG cases pass with stable binary identities. Separate BBC
diagnostics match the original pixels and content, observe the new path only
when enabled, and witness 2,424/2,447 JavaScriptCore evaluations in
candidate/control.

The uninstrumented pending-font cohort changes only
`VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE` between identical executables.
Control median 41,645,708,065 versus enabled 40,329,352,824 is a 3.1608% point
reduction, with pair 5 regressing. The conservative control ratio
1.1059377404151833 fails, so no accepted engine saving is credited. All 21
observations pass content, original references and native exits. First launches
and Brave trials above 31 billion remain included. The integer Brave gate
fails: 439,854,987,830 > 140,973,663,474. The guard adopts 65 identities without
error, peaks at 1,478,033,408 bytes and completes in 144.66 seconds. The requested
10% advantage remains open.

Commit `0cdb8d6c` retains inline text chunks and intrinsic shape owners across
unrelated font epochs only when style identity/revision and the original live
pending cascade are unchanged. Selected completions, changed matching inputs,
expired cascades and style changes retain recomputation. All 16 focused checks
pass in normal, no-GC and preallocated modes, with disabled controls. Two prior
attempts expose test assumptions: an unused face has no font-display timeline
to transition, and completion can synchronously run layout through
FontFaceSet.ready. The final check changes the selected Unicode range and
allows a fresh cache after synchronous layout. Both failed attempts remain
retained. Matched-control tooling `809068ef` passes 181 instruction-tool checks.

Both broad modes enter all 408 cases and pass 407, with the same sole baseline
failure. Disk exhaustion interrupts the first no-GC compile; the unchanged
composed test source subsequently compiles and enters all cases in 82 fresh
batches. Compression receipts retain logical SHA256 values and exact contents
for generated sources and completed standalone test executables. Historical
Vox copies have lossless archives with file metadata, links and attributes.
An attempted browser-copy archival consumes space instead of recovering it;
verified Brave clones are restored, and only redundant or incomplete archives
are removed. The failed compression jobs and recovery receipts remain retained.
Current candidates, page archives and PNG references are unchanged.

The production build completes in 323.35 seconds, peaking at 7,346,438,144 bytes.
Its text-cache implementation stays unchanged; only the test fixture changes
during the build. Captured compiler input witnesses the final implementation,
and the final fixture passes separately. Executable SHA256 is
`5e5a95dcbc9be81238f6b529fb55e157a0556db77dbc1f5609c39e546b11cdd7`.
Startup, all 11 smoke and eight SVG cases pass with stable identities. BBC
diagnostics match the original pixels and full content, observe the path only
when enabled, and witness 1,971/2,431 JavaScriptCore evaluations in
candidate/control.

The uninstrumented text-cache cohort changes only
`VOX_DISABLE_LIVE_PENDING_TEXT_REUSE`. Control median 41,889,164,118 versus
candidate 40,577,716,115 is a 3.1308% point reduction. Pairs 1, 2 and 7 regress;
the conservative control ratio 1.0304606563820868 fails, so no accepted saving
is credited. All 21 content, original-reference and native exit checks pass.
The Brave gate fails: 414,081,075,020 > 141,533,838,414. The guard adopts 68
identities without error and peaks at 1,438,023,680 bytes over 131.69 seconds.
BBC remains outside the optimized-site catalog.

A later outer-scope diagnostic is invalid: it treated the partial CSS candidate
bucket interval and its containing interval as two independent exits. The
counter nesting became unbalanced, and the capture counter JSON was truncated.
No numerical attribution or instruction saving is taken from that attempt.
Its raw run and `outer-scope-diagnostic-assessment.json` remain retained.
Historical Brave copies with identical complete file-content manifests now
share one immutable historical application tree through their original paths;
the current candidate and measurement copies were excluded. The manifest and
replacement receipt preserve each original path and file hash.

## Original pending-font snapshots during refresh

Commit `c0a2176e` lets a font-only style refresh preserve geometry when its
original pending cascade remains live and root/line metrics stay unchanged.
The style retains the original refresh snapshot even when a synchronous query
has already materialized a new cascade. Selected completion, failure and
block-to-swap changes still invalidate geometry. The initial broad attempt
caught a selected descriptor-change regression; its logs remain retained.
The corrected implementation passes all 18 focused compile/runtime/control
jobs in normal, no-GC and preallocation modes. Both broad modes enter 408
cases and pass 407, with only the unchanged 13.5-versus-13 control baseline.

The production build completes in 206.0163 seconds, sampled peak RSS
8,790,589,440 bytes, with the feature's source inputs stable. Its executable
SHA256 is `e5d16ddcacfe7ae6e57964b97c8bc31a1a2d64759edeb38ff0f26267709edd6b`;
the preserved generated C is
`022ee0d1ecb2ae0ba4ce2e999e1bc14a508bc6b84d0a2f7d430987694db02664`.
Startup, all 11 smoke and eight SVG mutation comparisons pass against this
private bundle. An earlier validation launcher lacked executable permission;
that attempt and the corrected launcher's receipts are retained.
Separate BBC diagnostics pass the complete audit and original pixels, observe
the new branch once enabled and zero times disabled, and prove 1,949/1,947
JavaScriptCore evaluations with one context/group in each run.

`live-pending-refresh-cohort` alternates seven control/Vox/Brave triples using
the same executable, differing only in `VOX_DISABLE_LIVE_PENDING_FONT_REFRESH`.
The conservative control ratio is 1.2910009286517528. The Brave integer gate is
`493793945720 > 139856517810`, so it fails independently of Brave trial 6's
pixel mismatch. The guard adopts 66 processes without an adoption error,
completes in 121.3829 seconds at 1,367,490,560 bytes sampled peak RSS, and exits
1 for the failed gate. Every native browser exits 0. The cohort earns no
instruction credit.

The corrected outer-scope diagnostic ignores the partial interval that reuses
the selector-collection start. It reports zero nesting imbalance, 122,784 CSS
counter reads and 1,322 DOM counter reads, with original pixels unchanged.
Its layout/style intervals overlap and include diagnostic overhead; they are
leads, not production instruction shares. A preceding launch rejected ambient
`NO_PROXY` before measurement; that failure remains retained.
A separate script-disabled diagnostic observes 21,568,974,999 instructions but
changes 443,486 reference pixels. Its author-script policy differs and runtime
initialization was not independently probed, so it supplies no optimization
credit. This suggests investigating the additional layout/resource work
triggered by scripting while preserving author behavior in acceptance runs.
Completed cache payloads now share immutable bytes by SHA256 through their
original paths: 22,639 files, 1,379,255,411 logical bytes and 82 unique payloads.
The full metadata manifest and verification receipt remain under the evidence
root; no measured result or browser application was changed by this storage work.


### Positioned image replacement diagnostic

Commit `693b1206` can repaint an absolutely positioned image when its specified
width is definite, its natural aspect ratio is unchanged, and its min/max
constraints cannot introduce an intrinsic-size dependency. Ratio changes,
in-flow images, intrinsic constraints, missing dimensions and SVG documents
retain ordinary layout. Attribute-selector changes still run style and layout.
The retained paint data receives the new URL, bitmap and intrinsic dimensions;
previously published commands keep their original image data.

All 18 focused compile/runtime/control jobs pass across normal, no-GC and
preallocation modes. The broader checks enter 415 cases in each of normal and
no-GC modes: 414 pass, with only the existing 13.5-versus-13 text-control
baseline failure. The production build completes in 357.4893 seconds, sampled
peak RSS 8,797,224,960 bytes, with these engine sources stable. Its executable
SHA256 is `047cf60c6eedaa84ea9b7be91faf81e3d5bbe866c6a9739a979e74fec936c1fe`;
the preserved generated C is
`f5afeb551c9081445ca0a2d19b410e8e8d81415593dbb282df1789d80def0a3f`.
Headless startup, all 11 smoke comparisons and eight SVG mutation comparisons
pass with exact pixels. The BBC control tooling passes 160 browser-instruction
checks and is committed separately as `415c2718`.

The original BBC fixture passes its complete content audit and fixed pixel
reference in both enabled and disabled diagnostics, with 2,404/2,408
JavaScriptCore evaluations and one context/group in each. Neither run observes
the successful image-reuse trace. This optimization therefore earns **no BBC
instruction credit**, and no acceptance cohort is justified by this inactive
path. The instrumented observations are 51,945,881,058 and 50,732,497,985
instructions; their difference is not a production saving. The raw attempts,
checks, build witness and inactive-path assessment are retained under
`positioned-image-ratio-*` in the evidence root. The target remains open and
BBC remains absent from `OPTIMIZED_SITES.md`.


### Full style passes and conditional rule insertion

Separate O2 diagnostics built from the pinned positioned-image production C
identify 12 actual layout passes and six full-document style passes. A guarded
outer-layout probe performs 690 counter reads with balanced nesting; its
reason totals overlap other work and receive no production instruction credit.
The full-style trace attributes subsequent document-wide invalidations to
`CSSStyleSheet.insert_rule`. Its 14 style passes include 15,466 element
recomputations caused by full passes. The only missing-style query is the
initial connected `html` root: the general selective missing-style bootstrap
in `c9e8680a` does not execute on this BBC workload and earns no BBC credit.
Its nine focused normal/no-GC/preallocation compile/runtime/control jobs pass;
the two broad modes each enter 415 tests, with only the known text-control
baseline failure.

Commit `becf4f52` extends the existing selector-subject invalidation plan to
inserted `@media` and `@supports` trees containing only style rules and those
conditional groups. Global registrations and unknown rule kinds retain full
invalidation. Changed existing media-query matches also retain the full path;
inactive conditions are conservatively included in the selector union. This
change passes nine focused jobs and both 415-case broad modes with the same
single preexisting baseline failure. The completed production build takes
221.3809 seconds, peak sampled RSS 8,977,956,864 bytes. Its executable SHA256 is
`aa1a84e71452debb6d14861c02e9033d972f6bb00184a19a82d22e6b12c984d9`;
the generated-C witness is
`97261941be9118b14a917588e78c3fd8bbcc9f9b7c742ec2322102033da6cf9f`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons pass
with exact pixels. The separately committed control tooling (`59f37d09`)
passes 161 browser-instruction tests.

Enabled and disabled BBC diagnostics both pass content, native exit and the
original pixel reference, with 2,009/1,943 actual JavaScriptCore evaluations.
The conditional invalidation trace occurs only in the enabled run. The
subsequent uninstrumented seven alternating control/Vox/Brave triples produce
the latest results above. All 21 observations are retained and valid. The
memory guard adopts 71 processes without errors, observes peak RSS
1,385,938,944 bytes, and completes in 126.0775 seconds with controller exit 1
because the instruction gate fails. The separate sampled profile also matches
the fixed reference and earns no instruction credit. Its artifact prefix is
`conditional-sheet-*`; earlier full-style/layout reason probes and unsuccessful
test attempts remain in the evidence root. BBC remains outside the site catalog.


### Filtering helper signing

The separate production `VoxAdblockWorker` lacked the main browser's JIT
entitlement. Commit `9ae714ed` signs it with the existing entitlement plist.
A private candidate re-signs the helper and containing app only; every
file-backed Mach-O section in both executables and all other bundle files
remain identical to the conditional-sheet production build. The source and
candidate helper SHA256 values are
`fe28615b27bd0dceb41c5d52c52aaa24c717d027b8038af5f98e0aedead135b5` and
`4d37c67692ec3bbb2dff263dad68a92a35db4ffb8c5f25c6be3306177e35a679`.
The re-signed main executable is
`840e7d39c615af6259e8bec1cb30e28f61941274a8d524901a094738bb9c2454`.

Separate helper-process samples positively observe JSC JIT/DFG compilation
only with the entitlement. Both sampled BBC captures match the unchanged
reference and pass content/native exits. Both helpers pass actual full-engine
network/cosmetic checks and release their isolated worker normally. Headless
startup, all 11 smoke comparisons and eight SVG mutation comparisons also
pass with exact pixels. Signing and sampling evidence is under `worker-jit-*`.

The uninstrumented seven-pair cohort retains every first-launch outlier and
passes all 21 content, pixel and native-exit checks. Vox median 37,990,584,359
**regresses 0.9765%** against control 37,623,209,920; the conservative control
ratio is 1.2748969881501748. Brave lower median is 15,546,241,164. The integer
gate `464835422110 > 138205489167` fails (worst ratio 3.0270279597468543).
The guard adopts 66 processes without errors, peak RSS 1,361,756,160 bytes,
and finishes in 115.1980 seconds with exit 1 for the failed instruction gate.
This change earns no BBC performance credit.


### Inactive inserted conditional rules

The inserted-rule diagnostic preserves the fixed BBC pixels and records 695
insertions: 378 style rules, 315 media rules and two keyframe rules. Its only
new transition from clean style to a full cascade is a media rule below 599px,
which cannot match the benchmark's 1024px viewport. This diagnostic has four
full style passes and 12 partial passes; instrumentation and O2 compilation
earn no instruction credit.

Commit `0a195fac` omits currently inactive media/supports branches from a
style-only insertion's invalidation union after evaluating media matches.
Changed existing matches still fall back to full invalidation. The ordinary
media-change path makes previously skipped rules effective after a resize.
Twelve focused compile/runtime/control jobs pass across normal, no-GC and
preallocated modes, including resize in both directions with nested media and
supports groups. The first test attempt expected a universal rule to override
a class rule; the corrected fixture gives the new target rule equal
specificity. That failed attempt remains retained. Both broader modes enter
415 cases; only the unchanged 13.5-versus-13 text-control baseline fails.

The production build completes in 188.1680 seconds, peak sampled RSS
8,904,687,616 bytes, with these engine sources stable. Its executable SHA256
is `8dbdebed953798880953a47e3aa3b77b4532361efadeba2e629733ecb24611a1`;
the preserved generated C is
`81c731ae23d58b7106a942876f3d70d14fd9cd745ab6776bae1aefcf84f3e2a2`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons pass
with exact pixels. Control tooling `21f768e2` passes 162 browser-instruction
tests. Enabled and disabled BBC diagnostics pass content, original pixels and
native exits, with 1,911/2,040 JavaScriptCore evaluations respectively. Only
the enabled diagnostic logs the inactive-group skip. Evidence uses the prefix
`inactive-sheet-*`.


The uninstrumented seven alternating triples preserve all counts and outliers:
control median 37,698,968,829, candidate 37,396,821,455 (0.8015% point
reduction), Brave lower median 15,731,322,435. The conservative control ratio
1.1054906544208132 fails. The Brave integer gate and pixel invalidity are
reported above; the first Brave image mismatch remains retained. The guard
adopts 70 processes without errors, peak RSS 1,351,057,408 bytes, and completes
in 110.6187 seconds with controller exit 1 for failed acceptance.

A further separate O2 diagnostic wraps six workflow scopes with 30,980 process
counter reads, ending at depth zero with no counter errors. Its final inclusive
CSS-update total is 7,074,836,504 instructions across 16 calls. Layout has six
calls, inclusive 4,782,319,728 and 3,525,312,075 after subtracting instrumented
nested scopes. JS function calls have 12,310 calls, inclusive 13,033,608,146
and 9,422,956,992 after that subtraction. Stylesheet insertion and font
synchronization have inclusive totals 586,764,304 and 108,166,379. These are
**diagnostic process counts**, including background work and probe/logging
overhead, with nested scope overlap. They are not production percentages or
optimization credit. The original pixels, full content and native exit pass;
`workflow-scope-*` retains the exact inputs, compiler receipts, logs and values.


### Classic-script import scan

A separate O2 diagnostic categorizes JavaScript API calls by cached function
source prefixes. It records 130 labels with no metadata errors or overflow,
passes the original BBC pixels, complete content and native exit, and observes
actual JavaScriptCore execution. Function string conversion, extra GC roots,
logging and process-wide counters can alter behavior and timing; this probe
earns no instruction credit. React's scheduler callback has inclusive total
8,807,093,258 and 6,137,354,555 after subtracting instrumented nested scopes;
another React callback has 1,679,173,598 after that subtraction. The import
rewriter has 35 calls and 803,233,728 diagnostic instructions. All categories
and compiled inputs remain under `js-target-*`.

An offline inventory of the 75 archived JavaScript resources finds 35 with
`import` substrings, but only six with a possible standalone word. The other
29 contain 1,419,281 bytes. Commit `309aa5f5` rejects classic-script sources
whose matches all adjoin ASCII identifier characters, such as `important` or
`importer`. Other boundaries, Unicode, comments and escapes remain conservative
lexer candidates. Module scripts retain their existing transformation path.

The nine focused compile/runtime/control checks pass across normal, no-GC and
preallocated modes, including actual dynamic imports and HTTPS/proxy loading.
Both broader modes enter all 415 cases with only the known text-control
baseline failure. The first composition attempt accidentally treated a raw
JavaScript import as a V import; the next compile exposed the current V
optional return from `index_after`. Both failures are retained. A subsequent
CLI continuation interrupted a build and the unfinished test modes, leaving
empty guard receipts and unknown exits. Those attempts are retained explicitly;
completed default-mode tests were reused and only unfinished modes rerun.

The completed production build takes 199.4478 seconds, peak sampled RSS
8,801,058,816 bytes. Its executable is
`46196ed8f47f6fdff9f8564daba9b90eca87933804f41144e07281a714b3721d`;
the preserved generated C is
`c7f879b27b7b8dfbba330a4660425b1beb19fc94585b1c34ceda91f30174ca2a`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons pass
with exact pixels. Control tooling `9010cb3b` passes 163 browser-instruction
checks. Separate enabled/disabled BBC diagnostics preserve content, native
exits and original pixels with 1,985/1,995 JavaScriptCore evaluations. Only the
enabled run logs the successful import-scan bypass.

The following uninstrumented seven alternating triples produce the latest
results above. All 21 captures pass every content, pixel and native-exit check,
but both instruction gates fail and the median regresses against its control.
The guard adopts 66 processes without errors, peak RSS 1,352,007,680 bytes,
and completes in 109.8753 seconds with controller exit 1 for failed acceptance.
The raw prefix is `classic-import-*`. BBC remains outside the site catalog.


### Viewport, grid placement and radius longhand reuse

Commit `2ad3e906` allows the existing computed-longhand cache to accept
viewport-relative `vw`/`vh`/`vmin`/`vmax` lengths, simple grid auto-flow and
integer line/span placement, and scalar border radii. Snapshots preserve typed
values, optional names, component arrays and flags; retained-input mutations
still reject reuse. Font/container-relative and calculated inputs remain on
the ordinary path. Viewport changes invalidate the key, and restored properties
retain their viewport-dependency flags.

Nine focused compile/runtime/control jobs pass in normal, no-GC and
preallocated modes. A failed compile exposed unsupported negative smart-cast
narrowing in generated C; explicit guarded casts correct it. The next failed
check used a fresh oracle with a different viewport; matching that input
preserves the full-property oracle and verifies that resize rejects the old
entry and resolves 50vw to 320px at 640px. Both failures remain retained.
The broad checks enter 415 cases per mode, with only the known text-control
baseline failure. A CLI continuation interrupted the last 13 no-GC batches;
recovery uses the completed compile with a pinned, unchanged executable and
runs all 65 remaining cases successfully. The incomplete attempt remains.
Control tooling `e0cc71db` passes 164 browser-instruction tests.

The production build takes 182.1466 seconds, peak sampled RSS 8,928,722,944
bytes, with the feature sources stable. Its executable is
`8fbb7b69e680520603f17cce866ab30ab0beafae41a49378cc504dd7c20ca9e6`.
A post-build generated-C snapshot was unavailable; source-input hashes,
actual executable symbols and positive runtime-path traces are retained in
`longhand-shape-executable-witness/`. Headless startup, 11 smoke comparisons
and eight SVG mutation comparisons pass with exact pixels. Both BBC
diagnostics pass original pixels, content and native exits with 1,945/2,085
JavaScriptCore evaluations; only the enabled run reports a successful restore.

All 21 uninstrumented cohort observations pass content, pixel and native-exit
checks. The candidate median 37,314,150,142 regresses 3.4473% against control
36,070,672,871; the conservative control ratio is 1.1054633006230532. Brave
lower median is 15,652,929,710 and the integer gate
`391358005840 > 140292275157` fails. The guard adopts 67 processes without
errors, peak RSS 1,374,060,544 bytes, and completes in 110.1369 seconds with
controller exit 1 for failed acceptance. No BBC improvement is credited.
Evidence uses `longhand-shape-*` and the retained broad-recovery directory.

### Longhand eligibility ordering

Commit `cb190e09` checks an element's own declarations before hashing inherited
values. Rejected declarations can skip that inherited walk. Eligible own-value
hash contributions are XOR-combined after the unchanged parent hash, preserving
the previous key exactly. The control retains the prior ordering. Nine focused
jobs pass across the three memory modes, and both 415-case broader modes retain
only the existing baseline failure. The first extraction compile had an
unrenamed local count; it remains retained. Separately committed control
tooling `fae61ca7` passes 165 browser-instruction tests.

The production build takes 179.8584 seconds, peak sampled RSS 8,970,797,056
bytes, with feature sources stable. Executable SHA256 is
`2226008c70cb493c9decd4092b9dd0e695854300ba39c488c703ce91520f45d6`;
the captured generated C is
`33a528bd857f51d680cae27e816199d86b255443d03ed5e5d387feac5b203419`.
Headless startup, 11 smoke comparisons and eight SVG mutation comparisons
pass with exact pixels. Enabled/disabled BBC diagnostics preserve original
pixels, content and native exits, with 1,985/1,989 JavaScriptCore evaluations.
Only the enabled run reports rejection before inherited hashing.

The uninstrumented cohort produces the latest results above, including its
Brave trial 6 image mismatch. The guard adopts 72 processes without errors,
peak RSS 1,344,749,568 bytes, and completes in 109.6054 seconds with controller
exit 1. Every count and invalid observation remains retained. Neither the
point estimate nor conservative gate supplies improvement credit. Evidence uses
`longhand-eligibility-*`; the requested 10% advantage remains open.


### Indexed JavaScript value protections

Commit `49832905` replaces linear root scans and shifting removal with a
handle index and swap removal. Separate protections for duplicate handles
remain balanced against the actual JavaScriptCore GC API. A reverse position
updates a moved entry without scanning other protections of the same handle.
Unknown and already released handles remain harmless, and closing the owning
runtime releases every remaining protection before destroying its context.

Nine compile/runtime/control jobs pass across normal, no-GC and preallocated
modes. Focused checks cover interleaved duplicates, moved positions, actual JSC
collection and context teardown. The broad checks enter all 415 cases in each
mode and retain only the known 13.5-versus-13 text-control baseline failure.
Control tooling `31a8e9fe` passes 166 browser-instruction tests.

The production build completes in 199.2511 seconds, peak sampled RSS
8,968,568,832 bytes, with feature sources stable. Executable SHA256 is
`97018325d23294c8087a15a0cf03dfd8172178a04ab3f31ad6d8ef58a9b7f71d`;
the generated C is
`64efb7fb0370a28692cc491355b7f18aea5a0a704cc5b6a5ae160ca6f5ddaefc`.
Headless startup, all 11 smoke comparisons at their unchanged tolerances, and
eight pixel-exact SVG mutation comparisons pass. The first screenshot-wrapper
attempt lacked executable permission on its capture helper and never launched
those checks. That attempt remains retained; corrected wrappers use a new
validation directory. Enabled/disabled BBC diagnostics both preserve original
pixels, content and native exits. They confirm one JSC context and 1,932/1,991
evaluations; only the indexed run reports swap removal, 2,436 times.

The uninstrumented seven alternating triples produce the latest results above.
All observations pass content, fixed pixels and exits; both instruction gates
fail and the median regresses. The guard adopts 69 processes without errors,
peak RSS 1,357,119,488 bytes, and completes in 111.4603 seconds with controller
exit 1 for failed acceptance. Measurement scripts are pinned in a separate
15-file snapshot. Evidence uses `protected-value-index-*`. No BBC gain is
credited and the catalog remains unchanged.

### Further diagnostic attribution

Separate O2 process-counter probes and an external sampled production profile
retain their original BBC content, pixels and native exits. They cannot supply
unprofiled performance credit. Exclusive scope counts subtract only explicitly
instrumented nested scopes; background work and observer overhead remain.
The complete-workflow probe records 10,687 eligible longhand restores, 9,707
hits and 980 insertions. Disabling the whole cache is not supported by this
91% observed hit rate.

The grid probe records 16,062 successful auto-height seeds and 23,295
rejections involving an already definite item height. Of those, 14,605 reject
only on that initial predicate. Later CSS constraints were not evaluated for
these early rejections, so those counts do not establish that all rejected
items are safely reusable. No layout change is credited from this lead.

The deeper layout-workflow probe records 12 layout callbacks with inclusive
cost 10,128,412,117; viewport layout accounts for 7,466,729,355 inclusive.
There are 1,904 intrinsic-height measurements (2,173,393,130 inclusive) and
24,461 intrinsic-width measurements (17,368,746,850 inclusive, including nested
measurements). These inclusive totals overlap and must not be added.
The earlier roughly 11-billion “document update exclusive” value included
uninstrumented layout callbacks: the deeper probe attributes just 65,293,443
to that outer scope after subtracting its instrumented children. A separate
sample attributes most large copies to restoring the stationary raster, rather
than command scanning; it supplies no evidence that TLS dominates. Raw prefixes
are `macro-workflow-*`, `complete-workflow-*`, `grid-seed-*`,
`layout-workflow-*` and `current-workload-*`.

The engine-call v2 probe separates captured intrinsic identities without
converting function objects to strings or adding GC roots. Its ordinary call
intrinsic accounts for 5,969,821,954 exclusive instructions across 13,595
calls; function metadata setup accounts for just 6,072,946 across 358 calls.
That supports inspecting callback work rather than metadata initialization.
These are overlapping, instrumented process scopes, not accepted browser gains.
An initial probe crashed in headless startup because its C patch resized
unrelated array-index expressions as well as the counter arrays. No BBC launch
was attempted. The retained corrected probe restricts all three changes to
unique instrumentation statements; headless, content, original pixels and
native exit pass with balanced depth and no counter errors. Prefixes are
`engine-call-*` and `engine-call-v2-*`; production code was unaffected.


### Shared compact-element geometry accessors

Commit `ae931997` shares geometry getter/setter functions and descriptor records
across element wrappers. Each wrapper keeps its own properties and existing
flags. Native reads stay live; scroll setters check the receiver before numeric
conversion; the owner-bound `offsetParent` accessor stays separate. Nine
compile/runtime/control jobs pass in normal, no-GC and preallocated modes,
including native scrolling and mutation-version parent checks. Broad checks
enter all 830 selected cases and retain only the known text-control baseline.
Control tooling `55820e1d` passes 168 browser-instruction tests.

The first production build completes in 200.1532 seconds at peak sampled RSS
8,883,847,168 bytes. Its feature sources are stable, executable SHA256
`ef408c0f92b9fe3bf88ba7ac18290c004c931ef7e79eb2c9d149956795d6dc75`;
generated C is
`66944da1eafb295419cd9457f8a76076aaaba5e6d2bc9279d973ce2ab903343c`.
Headless, smoke and SVG checks pass. Its BBC captures, however, omit photos
with accessors enabled or disabled. All nine isolation attempts remain
recorded. Removing observation, disabling image-layout reuse, and swapping
either or both native libraries do not restore photos. The previous completed
production still matches the original PNG exactly. The generated function diff
identifies a temporary scripted-capture font-wait experiment captured during
compilation; that experiment is already absent from canonical source. Disabling
that captured experiment restores the original PNG bytes. The rejected build
supplies no performance cohort or optimization credit.

The next completed shared production already contains the accessor code and
the original scripted initial-layout branch. Its executable is
`aeffd1020b69961c0d9e906a452bbfdf76d264cc0f64a1289eafd18a94b8924c`.
It is reused without another production build. Its completed guard, source
hashes and identities are pinned in `shared-element-geometry-shared-recovery/`;
feature and initial-layout sources match before/after snapshots and current
source. That shared build reports three other changed native-test/cache inputs;
the actual executable and native-library identities are pinned independently.
Fresh headless, 11 smoke comparisons at unchanged tolerances and eight
pixel-exact SVG mutation comparisons pass. Enabled/disabled BBC diagnostics
preserve original pixels, content and native exits, with one JSC context and
1,961/2,011 evaluations. The separate probe observes shared getter identity only
in the enabled run. No interposer is loaded in the measured cohort.

The seven alternating triples produce the latest results above. Every trial
passes content, fixed pixels and exits. The median point reduction is 3.2035%;
the conservative control comparison and requested Brave gate still fail. The
guard adopts 67 processes without errors, peak RSS 1,358,364,672 bytes, and
completes in 110.0661 seconds with controller exit 1 for failed acceptance.
Prefixes are `shared-element-geometry-*`; the measured cohort is explicitly
`shared-element-geometry-v2-cohort`. BBC remains outside the catalog.


### Shared compact Node properties

Commit `ffd830ef` reuses accessor and method functions for native text, comment
and fragment wrappers. Per-wrapper metadata and the original own-property order
and flags remain. Descriptor initialization waits until the other Node bindings
exist. Receiver checks, live native reads, string conversion, Unicode edits,
fragments, cloning, adoption and equality are covered by eight focused cases.
Nine compile/runtime/control jobs pass across the three memory modes. All 830
broad cases execute with only the known text-control baseline failure. Control
tooling `dff36e9a` passes 169 browser-instruction tests.

The production build completes in 224.5673 seconds, peak sampled RSS
8,983,019,520 bytes. Feature and initial-layout sources stay stable, and the
compiled witness excludes the rejected scripted-font-wait experiment. Executable
SHA256 is
`303db5470a34705f1ae423319efab2be3e315ced5a65b57f382d91f461d1d1d3`;
generated C is
`c7059ede50e480d53440cbc32fec2f4280884108a4258c24a5f6f95d429d1ef3`.
Fresh headless startup, 11 smoke comparisons at unchanged tolerances and eight
pixel-exact SVG mutation comparisons pass. Enabled/disabled BBC diagnostics
preserve original pixels, content and native exits, confirming one JSC context
and 1,978/1,999 evaluations. The separate observer reads a diagnostic counter
without evaluating additional JavaScript: 385 shared wrapper constructions in
the enabled run, zero in the disabled run, with 1,598/1,609 valid observations.
The counter and interposer are absent from acceptance. Probe source/library
hashes are retained separately.

Every observation in the seven alternating triples passes content, fixed
pixels and native exits. The candidate median regresses 0.4307% and both gates
fail, so no BBC gain is credited. The guard adopts 66 processes without errors,
peak RSS 1,367,080,960 bytes, and completes in 112.7993 seconds with controller
exit 1 for failed acceptance. Evidence uses `shared-node-properties-*`.


### Font-refresh guard diagnostic

A separate O2 diagnostic counts rejections of the existing font-only style
refresh guard. It records just seven rejections: four for an unsafe stored
font context and three for changed inherited values. None has a stored raw
cascaded font-size prefix. Relaxing those guards is unsupported as a major
BBC optimization. Original content, pixels and native exit pass, with one JSC
context and 2,045 evaluations. Counters report through process exit, including
possible audit/teardown work; they are diagnostic counts, not acceptance costs.
The first diagnostic compile placed its helper after a caller and failed C
declaration checks. That attempt is retained; the corrected v2 declares the
helper before first use and passes. Production code is unchanged. Prefixes are
`font-guard-*` and `font-guard-v2-*`.


The following coarse CSS probe keeps ten nested process-counter scopes and
reports once at exit, avoiding per-event log output. It passes original pixels,
content and native exit, with 219,344 reads, balanced depth and zero counter
errors. Its largest selected exclusive scope is matching-rule construction:
19,940 calls and 3,288,325,303 instructions. Longhand key construction and restore
account for 549,695,997 and 446,435,895; the remaining property computation is
1,184,476,986 exclusive. Font-input refresh is 74,743,037 exclusive. These O2
instrumented counts include observer/background work and possible audit/teardown;
inclusive values overlap and cannot be added. They support investigating rule
matching rather than removing font safety guards or the whole longhand cache.
Raw prefix: `css-coarse-*`.


### Required attribute buckets before tag buckets

The sampled matching diagnostic records 2,458,037 selector checks, but sorting
only 52,782 matched rules: 79,768 sorts, maximum size ten and 31,361 comparisons.
Its 583,644 hardware reads add substantial overhead. Partial sampled intervals
are not full function costs and receive no optimization credit. A second probe
uses event counts without per-match hardware reads. Its 2,461,469 checks show
cosmetic-filter selectors such as `div[id^="…"]` reaching every `div`. Both
probes preserve the original pixels, content and native exits, with one JSC
context and 1,985/2,019 evaluations. Evidence prefixes are `css-matching-*` and
`css-selector-events-*`.

Commit `2a9d410e` prefers a required unprefixed attribute bucket over a tag
bucket, retaining the class/ID choices and namespace-dependent fallback. Full
selector matching still checks values, tags, namespaces and pseudo-elements.
Fourteen focused cases across six files pass in nine compile/runtime/control
jobs in normal, no-GC and preallocated modes. The first run retained an error
in the new pseudo-element test oracle; the corrected oracle also checks the
queried pseudo target. All 830 broad cases execute, with only the unchanged
13.5-versus-13 text-control baseline failure. Tooling commit `d66a1d56` passes
37 BBC driver tests.

Production build exit is zero, duration 197.0384 seconds and peak sampled RSS
9,047,392,256 bytes. Feature sources remain stable. Executable SHA256 is
`d52e041b57a4f08b9674ae33f49222587155e6c61a759f8ca1b56e9b43b76395`;
generated C is
`22e3ba5150c648cb5dc670406f4ab9f1940ee2c02cbaacb69c4b38883f4245cc`.
Fresh headless startup, eleven smoke comparisons at unchanged tolerances and
eight exact SVG mutation comparisons pass. Separate BBC diagnostics preserve
original pixels, content and native exits, with one JSC context and 2,032/2,031
evaluations. The enabled diagnostic logs 6,976 attribute-first rule placements;
the disabled control logs zero. These logs are absent from acceptance.

Every trial in seven alternating control/Vox/Brave triples passes the content,
pixel and native-exit checks. Vox/control medians are 36,673,262,472 and
37,003,319,838, a 0.8920% observed reduction. The conservative control ratio
1.080487412955897 fails. Brave lower median is 16,116,361,443 and the target
gate also fails: `381236402140 > 143008957638`. The guard adopts 67 processes
without errors, peaks at 1,387,708,416 bytes and completes in 113.5228 seconds;
controller exit 1 records failed acceptance. No BBC improvement is credited.
Evidence prefix: `attribute-tag-buckets-*`.

A subsequent event-only diagnostic records 10,140 recomputations caused by a
full style update, 3,216 directly dirty elements, 1,178 successful font-input
refreshes and eight guard fallbacks. Counters are cumulative snapshots and must
not be summed across log lines. Original pixels/content/native exit pass. This
supports tracing the transitions into full style updates before changing font
safety or stylesheet invalidation. Prefix: `style-causes-*`.

A follow-up false-to-true transition trace of full-style invalidation used the
same candidate's generated source in a separate O2 diagnostic executable. The
archived BBC capture retained exact original pixels, its semantic audit passed,
the native process exited zero, and JavaScriptCore recorded one context and
2,023 evaluations. Sixteen balanced style callbacks included four full updates
on the active document. The traced transitions identify the initial document
font policy, a CSSOM insertion, replacement of the adblock user stylesheet, and
a CSSOM deletion. The preload discovery document was marked dirty but did not
enter these style callbacks. This narrows the next investigation to stylesheet
change invalidation; it does not establish redundant or removable work, and
receives no unprofiled instruction credit. Raw stacks, generated-source and
build identities, guard receipts, and the fixed-reference comparison are in
`full-pass-trace-probe-build/` and
`full-pass-trace-diagnostic-validation.json` under the evidence root.

## Ordinary inline style-rule deletion (cohort 29)

Commit `682d53b9` projects an ordinary inline rule's selector invalidation before
CSSOM removal clears its parent stylesheet and namespace context. It rebuilds
the owning rule cache and marks the projected subjects, preserving broad paths
for constructed sheets, other owners, nested/global rules and unbounded
selectors. Independent media-match changes retain pre-deletion shadow effects
when falling back. Tooling commit `9502e54c` selects the old path with
`--control-disable-deleted-style-rule-invalidation` in the same binary.

The corrected focused selection passes 55 cases in four files, in default,
no-GC and preallocated modes, with both enabled and disabled paths: all nine
compile/runtime jobs exit zero. It exercises inheritance, generated pseudos,
namespaces, CSSOM errors, host/slot inheritance and media-change fallback.
The initial test helper's compile failure and the earlier focused success before
the media fallback review are retained. An obsolete production compilation was
explicitly stopped during that correction: guard exit 125, shell exit -15,
79.534449 seconds. It supplies no browser validation.

The corrected production build exits zero in 193.029545042 seconds, sampled
peak 9,020,604,416 bytes. Its executable SHA256 is
`9b8757b08c36857d0515dd1bf78c07bbdef68bcd3f31bfa853e571f31f0f1cf8`;
generated C is `80f2eb62651673b3b4d259722c7e627009530b8c95bc8a5096f21722480786ea`.
The three owned sources remain stable through compilation. Fresh headless
startup, eleven screenshot smoke cases with their unchanged tolerances, and
eight exact SVG mutation checks pass. The first screenshot wrapper attempts
failed before browser launch because the copied capture script lacked execute
permission; those exits are retained, and only the failed checks were rerun
after correcting the script mode.

Separate archived BBC diagnostics match the original document pixels exactly,
pass content/native exits and record one JavaScriptCore context with 1,965
candidate and 2,029 control evaluations. Thirteen candidate deletions take the
new path, versus zero control traces. They include broad reset selectors as
well as consent-overlay rules; eligibility alone does not establish savings.
All fourteen Vox captures in the cohort match the original reference. Brave
pair 7 differs in a photo region by 304,064 pixels (maximum channel error 18);
all other captures match. Every raw result is retained. The candidate/control
medians regress as reported above, so no broad-suite cadence credit or reset
is taken. The memory guard adopts 70 processes without adoption error, records
1,403,207,680 peak sampled bytes over 114.093986 seconds, and returns the
benchmark's failing exit 1. Browser kernel exits are all zero.

Receipts are `deleted-style-rule-cohort/`,
`deleted-style-rule-cohort-derived.json`, `deleted-style-rule-checks*/`,
`deleted-style-rule-build*/`, `deleted-style-rule-compiled-witness-v2/`,
`deleted-style-rule-validation/` and the enabled/disabled diagnostic validations
under the retained evidence root. This attempt adds no BBC catalog entry.

## Plain user stylesheet replacement (cohort 30)

Commit `ac71982f` projects both old and new subjects when replacing plain user
style rules. It preserves document-wide invalidation for global registrations,
nested rules, unbounded selector plans and pending full updates. Shadow roots
retain full subtree updates, including assigned-node inheritance. The parsed
replacement is retained for the ensuing rule-cache rebuild. The initial focused
run exposed stale inherited shadow-slot color; its failure is retained, and the
corrected focused selection passes 16 cases in three files, in default, no-GC
and preallocated modes with both paths: nine compile/runtime jobs exit zero.
Tooling commit `6cbe2dce` adds the isolated
`--control-disable-targeted-user-style-changes` switch; all 39 driver tests pass.

Production build exit zero: 196.156516458 seconds, sampled peak 8,992,915,456
bytes, owned source inputs unchanged. The executable is
`f246dcfdaee0b27a5d41ee380323d0021eb411a07a0a43b5d030dc88f0530f1c`;
generated C is `5a3ba293b3bdcdfdcc5cdfd9a7915619180ccd67925770d2779ef543389c4a1a`.
Fresh headless startup, eleven screenshot smoke comparisons with unchanged
bounds and eight exact SVG mutation comparisons pass. Separate BBC diagnostics
execute the new path once, retain exact original pixels/content/native exits,
and record one JavaScriptCore context with 1,979 candidate and 1,929 control
evaluations. Cumulative style-cause snapshots show 7,592 full-pass computations
and 5,693 directly dirty computations for the candidate, versus 10,140 and
3,216 for the control. Thus moving work out of a full pass mostly moves it into
coarse subject invalidation; it does not demonstrate meaningful saved work.

All seven triples pass the fixed references, semantic audits and native exits.
The raw medians, failing integer gate and control regression appear above; no
observation is omitted or retried. The guard adopts 69 processes without error,
records 1,406,107,648 peak sampled bytes over 110.135043792 seconds, and returns
the benchmark's expected failing exit 1. No positive marginal median, broad
cadence reset or catalog entry is claimed. Receipts are
`user-style-change-cohort/`, `user-style-change-cohort-derived.json`,
`user-style-change-build/`, `user-style-change-compiled-witness/`,
`user-style-change-validation/`, `user-style-change-checks*/` and the two
`user-style-change*-diagnostic-validation.json` files under the evidence root.
