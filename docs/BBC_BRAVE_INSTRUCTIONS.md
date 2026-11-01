# BBC homepage instruction comparison

**The requested 10% advantage remains open. BBC does not qualify for
`OPTIMIZED_SITES.md`.** The latest complete seven-pair cohort has a Vox median
of **46,582,465,131** retired instructions and a Brave lower-bound median of
**15,619,372,290**. Its conservative ratio is **3.3740750674717432**, above the
required 0.9. All Vox/control observations pass content, pixels and browser exits.
All 21 observations pass their original per-engine pixel references. The instruction
gate fails. Brave pairs 1 and 4 exceed 30 billion instructions and remain included.

The machine-readable [evidence](benchmark-results/bbc-brave-instructions-2026-11-01.json)
retains exact counts for every recorded attempt, including failures and first
launches, ownership audits, commands and artifact hashes. Raw archives, logs,
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
normal and no-GC modes. The benchmark tools pass 176 Python checks. The RGB cache passes 19 focused
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

The next investigation uses separate CSS instruction diagnostics to locate the
remaining costs. The first diagnostic build attempt encountered the shared
production lock and did not queue another build. The site catalog must
wait for a qualifying cohort. Startup counts establish neither isolated
rendering time nor scrolling FPS.
