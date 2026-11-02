# Hacker News: another 15% below current Vox

The requested additional 15% reduction is **not achieved**. The comparator is
Vox's measured starting build, following the user's clarification; the existing
Vox/Brave comparison is not this acceptance gate.

The original seven-trial median is **4,793,590,625** instructions. A 15%
median reduction requires at most **4,074,552,031** instructions. The
conservative gate additionally requires `20 * max(candidate upper) <=
17 * min(control lower)` over complete, alternating matched trials. The
original build can no longer supply interleaved controls after the shared
bundle was replaced; historical cohorts alone cannot isolate a source change.

## Retained implementation

Commit `3a6d15860670728d2b83ce26662f7cc58e871250` supplies
`MallocSpaceEfficient=1` through the app's LaunchServices environment. Previously,
the allocator constructor selected the same policy by executing the browser a
second time, after its native libraries had already loaded. The setting now
reaches libmalloc before the first load. Direct executable launches retain the
constructor fallback. Explicit caller settings, including `0` and the empty
string, still take precedence.

Six focused tests pass, including real LaunchServices launches checking the
selected policy, preserved explicit overrides and the fallback's single restart.
The PNG test fixture was repaired separately in `722ea5c8a`: headless `setColor:`
was failing to populate its bitmap, so it now writes varied RGB/alpha bytes and
padding directly. Its 45 cases pass in both ARC modes, comparing pixels,
profiles, density, metadata and chunk CRCs. Native capture-idle checks pass in
both ARC modes. The benchmark, coalition/process counter and memory-guard
workflow checks pass all 79 tests.

## Workload and observations

Both cohorts below use the sealed archived Hacker News homepage and its five
resources at `Tests/Browser/Brave/hn-home-instructions`. They retain author
scripts, all 30 story IDs, a 1024×768 CSS viewport at 2× scale, private profiles
and caches, and the two-second settle period. The existing pixel reference is
unchanged. Each cohort contains seven alternating Vox/Brave pairs; this does
not make the separate Vox build cohorts matched controls.

The scope is exclusive browser resource-coalition creation through completed
encoded document PNG availability, including startup, native window setup,
filtering, script initialization/execution, layout, paint and capture. Vox's
native endpoint precedes PNG file writing. The scope includes exited owned
helpers and explicitly audited owned system services. GPU execution and outside
services are excluded. OS filesystem and shader caches are retained. These
counts do not isolate rendering cost or scrolling performance.

| Trial | Original Vox | Installed diagnostic |
| --- | ---: | ---: |
| 1 | 4,790,319,809 | 4,566,185,403 |
| 2 | 4,778,040,604 | 4,524,030,062 |
| 3 | 4,862,329,540 | 4,542,802,836 |
| 4 | 4,813,725,682 | 4,489,012,411 |
| 5 | 4,799,324,150 | 4,505,579,895 |
| 6 | 4,793,590,625 | 4,513,035,599 |
| 7 | 4,757,734,898 | 4,462,135,647 |

The diagnostic median is **4,513,035,599**, 5.853% below the original median.
Its conservative ratio to the original cohort is 0.95974, failing 0.85.
All 28 browser observations exited successfully, matched the full unchanged
pixel reference and retained all 30 story IDs. Both memory guards adopted the
LaunchServices processes successfully; observed peaks were 942,555,136 and
937,230,336 bytes. The host has 18 logical CPUs; starting one-minute loads
were 7.48 and 9.84, with concurrent browser/compiler work present.

The original executable SHA-256 is
`f769e44dbef6c5c309654f532cadf36bc7d5288a4b99c9f4a03f40845649be49`.
The installed diagnostic is
`ca64e02972e15eb90fc597c6f4da56b35b7918ca285334ccf6f2344edfa55175`.
The latter was automatically built while a subsequently rejected PNG prototype
was present, alongside unrelated shared-checkout changes. Its measurements
cannot validate the final restored source or establish allocator-only savings.
The benchmark's passing 0.85 Vox/Brave result does not satisfy this request.

[Durable raw counts and provenance](performance/hn-vox-reduction-20261102.json)
retain exact counters, PIDs, timestamps, per-trial host loads and result hashes.
Full inputs, logs, audits, PNGs, commands and guard receipts remain in
`Build/hn-15-20261102-baseline/` and
`Build/hn-15-20261102/installed-observation/`.

## Rejected diagnostics and pending validation

The root-tile experiment preserved the reference pixels but increased total
instructions in the median of its two matched diagnostic pairs. The integer-list filter
snapshot variants and helper-link/JIT experiments supplied no qualifying
whole-page reduction. PNG filter/codec variants mostly regressed; uncompressed
PNG reduced encoder work by producing a roughly 27-fold larger file, and was
not retained. All these runtime prototypes were removed. Their patches, failed
attempts, raw counts and diagnostic outputs remain under
`Build/hn-15-20261102/`. They receive no final optimization credit.

The shared automatic build captured one PNG prototype before it was rejected.
The canonical source has been restored to the ordinary ImageIO encoder. New
production builds are already coalesced by the existing post-commit worker;
several builds have been superseded by concurrent input changes. Final-source
production pixel checks, live-site validation and the additional-15% acceptance
cohort remain pending a completed stable build. No duplicate production build
is queued by this report, no reference or tolerance was changed, and the
unvalidated diagnostic does not advance a completed broad-verification ledger.
