# Hacker News 3.2B instruction target

The requested **3,200,000,000 instruction target remains open**. The criterion,
chosen before the new cohort, is at least seven complete default production
trials with both median and highest upper count at or below that ceiling.
The earlier [additional 15% result](HACKER_NEWS_VOX_REDUCTION.md) remains a
separate historical result. [Exact progress counts](performance/hn-3200-progress-20261102.json)
retain the new baseline, matched experiment and production diagnostic.

The workload retains fresh browser/resource-coalition creation through encoded
document PNG availability, including window startup, original scripts, layout,
paint and PNG encoding. It uses the archived Hacker News bytes over loopback HTTP
with all five resources, fresh profiles/caches, 1024×768 CSS pixels, 2× capture,
two-second settling, unchanged pixel reference, owned-service/helper audits and
the shared PID registry for memory-guard adoption. OS filesystem/shader caches
remain retained. This is a frozen-page startup/capture result, not isolated
rendering time, scrolling fps or a new Brave comparison. GPU and outside-service
work remains excluded. Every measured pair is retained.

## SVG transfer optimization

Commit `11ae14fdf` retains the full GPU target dimensions, SVG transforms, clips
and MSAA while transferring only the affected backdrop region. Clipped SVGs use
the existing picture-region backdrop API; direct SVGs use a new bounded region
API. Failed regional work retains the existing complete-tile fallback.

Seven alternating matched pairs share executable SHA256
`208875f192d26570965f87aa88c6f5b31a57f3204793380697a15bf608bd3a96`
and the same two explicitly selected native libraries. The control disables only
the regional path. Control median is **4,015,404,093**, candidate median
**3,982,504,263**: a **32,899,830** reduction between medians. Every pair improves;
all fourteen captures have exact pixels/content and successful ownership/exit
checks. A separate diagnostic verifies the actual two regional calls and loaded
library paths. Diagnostic logging supplies no performance credit.

An earlier completed production executable
`c8993aa08e74513dacc5fda3f384b9cd6eb2835eddc8f98cf315b4c39bd9c324`
contains this change and subsequent shared work. Two default diagnostic captures
retire 3,963,916,709 and 3,970,081,883 instructions with exact content/pixels.
This incomplete diagnostic cohort does not meet the seven-trial acceptance
criterion or the 3.2B ceiling.

## Verification and retained failures

The native change passes 512 direct region comparisons, 128 parent/MSAA
comparisons and AddressSanitizer/UndefinedBehaviorSanitizer checks. Twenty-one
screenshot comparisons pass with the candidate libraries, including all eight
required SVG mutation guards and two turbulence cases. A fresh live HTTPS load
has 30 stories, completed readiness, the requested viewport and no script/native
errors. Live validation is functional, with no paired live performance claim.

A concurrent shared-checkout reset/rebase interrupted validation. The patch was
preserved and restored after the external rebase; this session did not rewrite
history. A missing runtime icon first caused capture failures. The recovered
broad run then passed all 21 visual cases but failed signing/helper startup
because the app plist and adblock snapshot had also been overwritten. Both
resources were restored byte-for-byte to their pinned successful-build hashes;
a separate capped run then passed signing, real startup, helper and live checks.
The failed guards remain failures; their successful visual checks and the
subsequent resource-recovery checks are reported separately.

Raw commands, pins, every attempt, PNGs, counters and audits remain in
`Build/hn-3200-20261102/`, especially `matched-regions/`,
`broad-regions-recovered/`, `recovery-checks/` and `current-production/`.
`repository-disruption.json`, `repository-recovery.json` and
`bundle-resource-recovery.json` retain the external disruption and exact repair.

Other experiments remain diagnostic: an empty CoreText collection crashed and
was rejected; direct file-face loading saved instructions in a microbenchmark
but has no retained implementation. Apple compression and PNG Sub/RLE variants
were slower. The later libdeflate integration and JIT warm-up cohort are
documented below; their earlier exploratory trials remain separate evidence.
The first JIT attempt failed argument validation and the second
rejected ambient proxies before launch; both are retained. Those exploratory
runs supplied no 3.2B acceptance or justification for changing pixel tolerances.

## Aligned borders and small opaque SVG polygons

Commit `8dad2e2ef` resolves aligned opaque rectangular borders before native
backend lookup and postpones unused backend entry-point resolution. Seven
matched pairs have medians 4,013,033,048 (disabled) and 4,006,807,272 (enabled),
a modest 6,225,776 difference. One pair regresses. All captures pass unchanged
pixels, content, ownership and exit checks. The path executes twice per capture;
1,280 independent GPU comparisons, 768 alignment fallbacks, sanitizers, the
21 visual cases and a live load pass.

Commit `b01e5243f` resolves small opaque non-convex straight-sided SVG batches at
the verified four Metal sample positions. It requires integer rectangular clips
and matching full-precision/subpixel-grid coverage, stages the entire result,
and retains GPU fallback for curves, analytic convex geometry, partial alpha,
rounded/fractional clips, unsupported transforms and ambiguous samples. Separate
diagnostics verify two actual polygon resolves per capture, selected library
identity and absence of the Dawn library. Scripts and capture boundaries remain
unchanged.

The final seven alternating pairs have control median **4,013,545,860** and
candidate median **3,890,638,654**, a **122,907,206** difference. Candidate maximum
is **3,919,559,433**. All pairs improve; all fourteen exact pixel/content,
ownership and exit checks pass. This uses executable SHA256
`0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`
with the explicitly selected `solid-polygons-v3` native library, rather than a
claim that the default production bundle already contains that native code.
The initial seven-pair polygon cohort (median 3,910,202,430) is also retained.
Focused checks compare 282 accepted batches exactly with Dawn, retain 742
transactional boundary fallbacks and cover malformed/unsupported input.
AddressSanitizer/UndefinedBehaviorSanitizer and all 128 parent/MSAA ellipse
comparisons pass. The measured candidate passes all 21 screenshot cases; final
library startup, helper, signing and live HTTPS functionality pass separately.
Earlier test-harness reference-serialization/assertion failures remain in their
original logs.

The same default production executable, without the selected new library, also
has two retained diagnostic counts of 4,058,785,591 and 4,389,144,582 under
`current-production-v2/`. Their variance/regression is not removed from the
record. Neither this two-trial diagnostic nor the native-override cohorts meet
the default-production 3.2B acceptance criterion.

Root-picture deferral and a Dawn shape-backend prototype are rejected: their
two-pair medians regress by 190,693,982.5 and 44,445,225.5 instructions respectively.
The root changes were removed and preserved as `rejected-root-picture.patch`;
the Dawn prototype never changed production source. PNG parameter/RGB and font
manager microbenchmarks supply no full-browser optimization credit. Raw evidence
is under `uniform-border-matched/`, `solid-polygons-final-matched/`,
`solid-polygons-v3-path/`, `broad-solid-polygons/`,
`solid-polygons-final-checks/`, `root-forced-matched/` and `dawn-shapes-matched/`.

## Font stream manager

Commit `36b77a15b` keeps Skia's CoreText stream loading and original font bytes,
but supplies a private one-family collection instead of enumerating every
installed family. System-family matching and layout-test font loading retain
the full manager. Diagnostics verify one family on the actual workload. Seven
alternating pairs have control median **3,919,511,678**, candidate median
**3,888,059,902** and candidate maximum **3,910,564,468**; every pair improves.
The median difference is **31,451,776** instructions. All fourteen exact
pixel/content, ownership and exit checks pass with the selected
`file-font-manager-v1` library and the same `0bb14e2f…` executable.

Twenty stream/glyph/metrics/raster comparisons cover five system font files,
TTC index failure behavior, complete BMP glyph mappings, fractional font sizes,
invalid data and backend/opt-out fallback. The checks also pass sanitizers.
All 21 screenshots and separate signing, real startup, helper and live HTTPS
checks pass. A first test compile lacking the metrics header is retained as a
failed attempt. Evidence is under `file-font-manager-matched/`,
`file-font-manager-path/`, `broad-file-font-manager/` and
`file-font-manager-checks/`. The shared production build remains pending;
these are native-library override results and do not meet the 3.2B criterion.

## Earlier background requests

Commit `ec593de8a` starts unresolved root background-image requests while
preparing the existing display list. It uses the existing asynchronous loader,
cache and pending-request deduplication. Resolved SVG snapshots, nested-document
commands, empty bounds and non-HTTP URLs retain their existing paths. It does
not wait for resources or extend the capture settle period.

The focused preparation tests and existing background-refresh tests pass with
current V, including cached/pending request ownership and SVG snapshot refresh.
A generated-C diagnostic prototype reduces native document paints from two to
one while retaining exact pixels/content. Its O0, initially unsigned executable
does not establish production performance: no instruction reduction is credited
to this change until a completed production build exercises the actual V code.
Evidence includes `early-paint-{control,candidate}-{1,2}/` and the
`hn-3200-paint-resource-{tests,refresh}-{build,run}` guard receipts in `Build/`.

## JavaScript warm-up

Commit `7558c41c5` sets the macOS JSC baseline warm-up threshold to 5,000 before
the first VM, preserving any explicit caller value. Baseline, DFG and other JIT
tiers remain enabled. The signed focused test creates a real JavaScript context,
executes a loop and verifies caller-option preservation. Separate runtime-option
diagnostics verify `useJIT=true`, `useBaselineJIT=true`, `useDFGJIT=true` and the
selected threshold; original page scripts still execute without errors.

Seven alternating matched pairs, with the completed `0bb14e2f…` executable and
the selected font-manager library, compare explicit thresholds 500 and 5,000.
Median instructions fall from **3,900,319,813** to **3,766,921,053**, a
**133,398,760** difference. Candidate maximum is **3,791,935,156**. Every pair
improves, and all fourteen captures pass exact pixels/content, ownership and
exit checks. All 21 rendering regressions and a fresh live HTTPS load pass with
the same option. The first seven-pair attempt ended after six pairs when a
pinned input changed; it remains invalid and retained, without sample exclusion.

This tuning prioritizes startup work. Signed arithmetic/call/JSON/RegExp/typed
array diagnostics retain small cold-execution regressions: for example, the
two-run arithmetic median rises about 3.5 million instructions (10.75%). These
component trials have only two repetitions and no host-load record, so they
cannot support a general JavaScript speed claim. An earlier unsigned diagnostic
had JIT disabled by macOS and is explicitly excluded from tuning evidence.
Neither disabling JIT tiers nor changing author-script policy is shipped.

The matched explicit-option cohort is not default acceptance of the new V
startup setter. Its production validation remains pending. Raw evidence is in
`jit-warmup-final/`, `jit-warmup-matched/`, `jit-warmup-proof/`,
`broad-jit-warmup/`, `jit-warmup-live/`, the signed workload JSON files and the
`hn-3200-javascript-startup-{build,run}` guards.

## Lossless PNG work

Commits `1f71b0018` and `4713441fa` build pinned libdeflate 1.24 and expose a
bounded level-one zlib service from the native renderer. The existing PNG
encoder uses it when available and retains its original zlib fallback on any
failure. RGBA scanlines, PNG color type, profile, density and Exif metadata are
unchanged. The archive/source hashes and dependency build receipt are checked;
the MIT license is included in the app, and libdeflate symbols remain private.

ARC and non-ARC tests pass 270 exact pixel/profile/density/metadata comparisons,
including zlib and Cocoa fallbacks. They also pass AddressSanitizer and
UndefinedBehaviorSanitizer. A separate absent-library run passes. Four fresh
encodings of the real 2048×1536 capture reduce the encoding-only median from
**266,215,203** to **209,984,816**, a **56,230,387** difference. All four decoded
scanline streams and non-IDAT chunks are identical; output shrinks from 464,118
to 370,199 bytes. This component result is not full-browser credit.

Commit `2f57c8631` checks opaque alpha in bounded sixteen-pixel blocks with
unaligned-safe loads and a scalar tail. Every alpha position at widths 1–65,
three heights, eight alignments and eight padded strides is tested, including
overflow/invalid inputs and sanitizer runs. Any translucent pixel retains the
ordinary encoder. The component scan falls from about 18.9M to 3.0M instructions.
Four complete encodings with identical PNG bytes reduce the median by another
**16,224,876.5** instructions. This also awaits full-browser validation.

Evidence includes `snapshot-deflate-{asan,absent}/`, `large-snapshot-results/`,
`block-opacity-{asan,fallback}/` and `large-block-opacity-v3/`. The initial opacity
measurement failed dependency resolution before sampling; its log is retained.
An intermediate successful component run pinned fewer dependency paths and is
retained separately from the final run with upstream library identities.

An RGBA glyph-scratch experiment changed reference pixels and was removed;
`rejected-rgba-glyph.patch` and its failed captures remain. Redundant native
window, Cocoa-host and font-registration prototypes supplied insufficient gains
and have no retained production implementation. No pixel tolerance was changed.

The shared publisher still has no completed production bundle newer than
`0bb14e2f…`: source changes repeatedly supersede successful compilations, with
additional retained shell-read failures before the separate build-script fix.
The available older bundle supplies the explicit-option/native-library evidence
above but cannot validate the new prefetch, startup setter or PNG consumer.
No duplicate production build is queued by this session. The **3.2B target
remains open**; component savings are not added to fabricate a production count.
