# GitHub site policy, 2026-11-08

The requested 20% instruction reduction is **not established**. The site policy
and the `site_optimizations/` virtual module are implemented; this report does
not mark the performance target complete.

The policy replaces two exact reviewed `github.githubassets.com` chunk versions.
Six collector sites change: click/impression observation, Hydro event
submission, analytics batching, browser metrics/RUM submission, resource timing,
and selector-observer route metadata. Functional observer callbacks, fetch
nonces and defensive DOM setup remain intact. Every other
factory remains byte-identical. ES module exports, chunk registration, dependency
URLs, context serialization, current application identity, staff checks and
automation queries are preserved. Unknown asset versions use the site's code.

The [retained diagnostic](performance/github-site-optimizations-20261108.json)
records all attempts, pinned input identities, raw per-process observations,
content audits, decoded pixel hashes, commands and actual exits. In the final
unprofiled native comparison, the order was control/candidate/candidate/control:

| Observation | Observed process-tree instructions |
| --- | ---: |
| Control 1 | 39,520,043,668 |
| Candidate 1 | 37,097,666,879 |
| Candidate 2 | 37,298,590,300 |
| Control 2 | 37,878,331,277 |

The medians are 38,699,187,472.5 and 37,198,128,589.5 (ratio 0.9612).
The highest candidate over lowest control is 0.9847, far above the required 0.8.
These are sampled process-tree lower bounds, not complete browser instruction
totals. The boundary includes fresh process startup, native window setup, resource
loading, rendering, PNG capture, the semantic audit and teardown. It excludes GPU
and WindowServer work. The document viewport is 1024×768 with a 1× capture and a
two-second settle. Each observation uses a fresh private profile/cache and the
same original-origin offline replay; OS caches remain warm.

The four final captures differ by up to 164 pixels against the first control.
All retain 33 directory rows and 66 audited links, with no JavaScript diagnostics.
The host was busy with other sessions. Two pairs, changing pixels, variable
controls and the failed 20% gate prevent acceptance or optimization credit.
No references or pixel tolerances were changed. No 5M instruction broad-suite
checkpoint is credited or triggered.

Earlier retained diagnostics include the initial replay's five missing sheets
and a speculative Sponsor-heart animation rule. The replay was supplemented
from the original versioned stylesheet URLs for the final diagnostic. The
animation rule showed no reliable benefit and was removed. Those earlier runs
are not acceptance results. A final fresh live navigation completed without
JavaScript diagnostics and retained all 33 directory rows; it is a functional
sanity check, not a matched performance comparison or full interaction-parity
proof.

The installed executable and native libraries were pinned for the checks. New
policies were selected through `VOX_ADBLOCK_ENGINE_ASSETS`, which the installed
browser already supports. The V script-policy relocation changes no selection
behavior and passed its focused source compile and test through the repository
UI2 harness; the old bundle does not validate that relocation.

Validation: all 59 Node adblock tests, the focused V host-selection test,
headless startup and the fresh live capture pass. The retained report also
records the interrupted default V attempt and the rejected direct compile
before the successful repository-harness compile and actual test execution.

## Continuation: the 20% target remains open

The earlier 3.9% median was a diagnostic observation, not a verified improvement.
Continued profiling and 82 browser observations did not establish the requested
20% reduction. The [continuation evidence](performance/github-site-optimizations-continuation-20261108.json)
retains every cohort, actual process counters and exits, input hashes, host load,
semantic audits, pixel hashes, rejected candidates and focused-check receipts.

Two additional V policies are committed: image-completion layout batching
(`1316de9ce`) and exact small SVG raster reuse during GitHub painting
(`e7fde4219`, with byte-budget coverage in `ea422a171`). The latter avoids repeating
GPU rasterization/readback for identical small fills. Geometry, transform, paint,
opacity and backdrop must match; the service has 64-entry and 8 MiB limits and
releases its storage during graphics-memory cleanup. Site selection and draw
scope belong to `site_optimizations/`. The original GitHub app still starts normally.

The completed production receipt is `20261108-053350-f77c8445`, executable SHA256
`cd2b932437b2acf1ac113152c571af31c2bed0c8d8ffb7b9f4d1510c48d394d8`, using literal
V `-prod`, one C unit, GG adapters and JavaScriptCore. Its generated C contains
the policy hook, and its native library exports the cache service. A separate
diagnostic observed 53 cache hits on the frozen page; a fresh live navigation
observed 146. Neither diagnostic supplies instruction credit.

The final matched native diagnostic disables both new policies and the four
collector replacements in its controls:

| Observation | Observed process-tree instructions |
| --- | ---: |
| Control 1 | 37,660,118,324 |
| Candidate 1 | 35,154,825,013 |
| Candidate 2 | 37,881,537,304 |
| Control 2 | 35,187,866,653 |

Control and candidate medians are 36,423,992,488.5 and 36,518,181,158.5: the
candidate is 0.26% higher. The highest-candidate/lowest-control ratio is 1.0766,
so the integer 20% gate fails. There are only two pairs and substantial variation.
No measured saving or broad-verification reset is credited.

All four document PNGs are byte-identical in decoded pixels, SHA256
`2afab1d941d44d73e44e99b07cd76bba4e38c28aa1bd2cf2b706762cda817a41`.
They retain 33 directory rows, 53 commit links, the latest-commit content and the
complete README. Audits report zero native or JavaScript errors. These later
cohorts use document-only PNG capture and a controlled author wall clock; they
are separate from the earlier window-capture cohort. No gain is attributed to
the changed capture boundary or clock, and no reference/tolerance was changed.
Counts remain sampled process-tree lower bounds, excluding GPU/WindowServer work.

Rejected experiments include deferred code-view hydration (missing commit
metadata), a legacy-router switch (missing commit metadata), stylesheet/lazy-image
simulations, blanket motion suppression, observer deduplication, earlier data
fetching, alternative collector installation and JIT settings. The hydration
diagnostic found React recovery error 418; an experiment removed that error while
retaining metadata, but did not produce a useful instruction reduction. These
experimental policies are not shipped. The JIT-disabled probe's final control
inherited its override and is explicitly invalid.

Validation includes the actual three-case image-layout test in normal and
disabled modes, a V source check, three passing sanitizer executions of the SVG
cache test (including backdrop/padding/geometry changes and bounded eviction),
production build and fresh headless startup. A fresh live GitHub capture has
all 33 rows, 53 commit links, the latest commit and README, with zero reported
errors and stable executable/library hashes. It is a functional check, not a
live performance comparison or complete interaction-parity proof.

## Immediate startup and stylesheet reuse

The app continues to start immediately, including repository hydration and
commit metadata. No interaction-triggered script loading is added.

`1b08b634d` reuses four component entry stylesheets when Rspack requests their
identical short-name copies. Reviewed bodies differ only in source-map comments
and share the same URL directory. The original runtime executes unchanged from
its original CDN URL with a query suffix; the wrapper only supplies an already
loaded CSS filename. Missing, disabled, conditional, loading or unreadable sheets,
unknown chunk names and unknown runtime versions retain the original path.
`e008064e7` removes four repeated initial Primer links across the head and body,
keeping the last owner and the first layer declarations. The reviewed source
fixture pins the runtime and all CSS bytes.

`15b492f67` removes a fifth telemetry collector: the final asset-timing reporter
inside the core setup factory. Fetch nonce handling, request setup and defensive
DOM methods remain byte-identical. Tests execute the original CSS loader and
verify that all four existing sheets resolve without another insertion/fetch.
They also exercise the retained core setup, fetch nonce and DOM patches.

`acf9b796c` preserves the layout tree when asynchronous GitHub stylesheets finish.
Its focused tests cover synchronous geometry reads, changed display, generated
content and non-GitHub/initial-layout boundaries. The measured startup diagnostic
did not enter this path, so no startup saving is attributed to it.

The initial wakeup experiment in `8c9f8b53d` was superseded by
`462c891d2`: active effects keep normal display grants in every visibility state.
Only completed finite CSS effects and input-driven scroll timelines can stop
requesting animation-only display callbacks. `11519063e` also preserves the CSS
clock while declining redundant style invalidation for completed or unchanged
scroll effects. `64aff6e61` reads the document clock for JavaScript animation
reads and seeks between display callbacks. Animation events, ordinary rendering
opportunities, active transitions and relevant Web Animations retain their
existing engine paths. No offscreen-mask suppression is shipped.

Focused validation passes: 65 Node tests; four wakeup cases with GC disabled in
both normal and rollback modes; initial stylesheet and stylesheet-completion
cases; 111 CSS regressions in both GC modes; and all 100 LibJS AST fixtures.
The completed baseline bundle `843893a4` passes headless startup, all 11 default
screenshot checks and all eight SVG mutation checks. That baseline bundle does
not contain the wakeup policy and cannot validate it.

The [immediate-start evidence](performance/github-immediate-stylesheets-20261108.json)
retains the original-clock pilots, counters, exits, input identities and content
and pixel audits. Two-second captures had transient pixel differences; matched
five-second pilots are pixel-exact. No improvement is credited across the changed
settle boundary. Later pilots retain all 33 rows, 141 table links, 53 commit links,
latest-commit content and the full README. Offscreen sidebar fragments can still
load lazily, as the original app requests them; their image counts are retained.
None of these pilots establishes the conservative 20% target.

Later production builds execute the idle-clock policy. The 20% target still
requires a qualifying seven-pair cohort; source and memory guards remain active.

## Targeted stylesheet invalidation and paint-input reuse

`47c208fc2` removes selector-observer telemetry while retaining its registration,
callbacks and abort behavior. All 66 adblock tests pass. `c748d84a0` preserves
CSSOM's targeted stylesheet invalidation instead of forcing a whole-document
restyle after each lazy stylesheet completes. Six integration cases cover changed
geometry, generated content, broad layer invalidation, unaffected elements and
rules used by subsequently inserted content; enabled and rollback modes pass.

`8446f227c` adds optional capture readiness. The later comparison waits for the
Sponsor button to leave its SSR-disabled state before starting the existing
five-second settle. This gates capture only; scripts, painting and display grants
continue. Later audits also compare all present image and button entries.
Offscreen sidebar fragments remain lazy. A different image count invalidates a
cohort even when its viewport PNG is identical. This scope correction earns no
optimization credit over earlier cohorts.

The last complete four-observation pilot before raster-input reuse has controls
52,696,392,763 and 55,190,333,845 instructions, and candidates 48,737,897,708 and
50,343,294,792. Its median reduction is 8.16% and conservative reduction 4.47%;
all four viewport PNGs match, but offscreen DOM differences invalidate the
comparison. This is not an accepted improvement.

`0dfe78311` introduces a GitHub-only paint-input key for the existing stationary
raster cache. `3166ed4d5` includes the static shadow, rounded-border and replaced
image commands used by the page. Keys include supported paint values, path
coordinates, bitmap bytes and formats, response bytes and decode availability.
Live media, canvases, nested documents, complex SVG resources and unknown
commands keep the existing revision key. Owner, viewport, transform and native
independent-content guards remain active. Production eligibility and matched
instruction savings must be verified before attributing benefit.

The first raster pilot's last control crashed in retained inline validation, so
its completed observations cannot establish acceptance. `cd8ca2f97` retains image
snapshots and their source strings beyond geometry scratch. The preallocation
regression test fails on the original code and passes with the fix, together with
the four existing image cases. `b410d6579` supplies an explicit supervised
compiler-backend option so comparisons can retain the baseline's C mode while
the separate FastC configuration is under development. The build-tool suite
passes 76 tests with two platform skips.

The production build with SHA256
`a7fdb4c11ce886a952f4bc9b217eca0f57227ce4530509b3f4f0fbec620a7427`
passes fresh headless startup, all 11 default screenshot checks and all eight SVG
mutation checks. Its live GitHub capture received an HTTP 504 page, and a later
independent unproxied HTTP request also received 504. Neither is a successful
live-site validation. Later raster/ownership changes require their own checks.

The [raster continuation evidence](performance/github-raster-input-validation-20261108.json)
retains attempts, failures, source identities, counters, clock probes and check
receipts. The [earlier wakeup evidence](performance/github-wakeup-validation-20261108.json)
retains earlier production build proofs and the source-inventory changes. No
seven-pair 20% acceptance or live performance fix is claimed yet.
