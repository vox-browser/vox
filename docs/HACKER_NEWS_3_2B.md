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
were slower. A libdeflate microbenchmark is not integrated. JIT-option trials
are separate configurations, have only two pairs, and do not change production
settings. The first JIT attempt failed argument validation and the second
rejected ambient proxies before launch; both are retained. No 3.2B acceptance,
new rendering-reference tolerance or engine-policy change is claimed.

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
