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

The latest completed production executable
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
