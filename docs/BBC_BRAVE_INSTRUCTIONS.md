# BBC homepage instruction comparison

**The requested 10% advantage remains open. BBC does not qualify for
`OPTIMIZED_SITES.md`.** The latest complete seven-pair cohort has a Vox median
of **75,303,556,310** retired instructions and a Brave lower-bound median of
**15,575,369,841**. Its conservative ratio is **5.409313292632096**, above the
required 0.9. One Brave capture also differs from its fixed reference.

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

For acceptance, at least seven alternating complete pairs must pass content,
pixels, identities and exits, and integer arithmetic must satisfy
`10 * max(Vox upper) <= 9 * min(Brave lower)`. No recorded cohort meets this.

## Rendering and execution limits

Every Vox image in the last three cohorts matches its original reference
exactly. The recurring Brave difference affects 64,177 pixels within one photo,
with unchanged image bytes, source URL, intrinsic dimensions and geometry.
Awaiting visible `img.decode()` did not remove it. Its cause remains unresolved;
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

The stationary browser executable is SHA256
`cba09e35ddf82cc12a5ccc4de0e55e5beb01b50f7444b97c18342b6000d2ad60`;
native-library identities and actual generated-C witnesses are in the evidence.
A failed preceding build encountered a concurrent unresolved SVG symbol. The
next successful shared production build was reused and copied with verified
identity. Source snapshots disclose concurrent edits.

## Verification and remaining work

Focused grid, CSSOM, initial-value cache and native raster checks pass in their
recorded GC modes. The pinned production browser passes `--headless-smoke`,
all 11 default screenshot cases (eight exact, three under existing bounds),
and all eight required SVG mutation cases exactly. All 100 upstream LibJS AST
fixtures match exactly.

The broader 394-case layout run retains an input baseline mismatch: Vox returns
13.5 where the unchanged test and an independent Brave content-box oracle
require 13. Splitting no-GC checks into fresh five-case processes avoids their
combined retained-memory growth, but a font-cache fingerprint still exceeded
12 GiB in one case. Commit `df20e4d2` replaces recursive decoded-font formatting
with exact retained-font identity; its four focused cases pass in both modes.
The interrupted broad attempt and its missing guard receipt remain recorded;
the guard cleanup fix has eight passing tests. Broad completion and the input
baseline regression remain open.

Client-geometry indexing and a tracked-arena allocation shortcut are being
checked. They have no claimed BBC instruction credit in this report. The site
catalog must wait for a complete qualifying cohort; startup counts establish
neither isolated rendering time nor scrolling FPS.
