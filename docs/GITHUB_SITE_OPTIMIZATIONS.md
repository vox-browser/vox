# GitHub site policy, 2026-11-08

The requested 20% instruction reduction is **not established**. The site policy
and the `site_optimizations/` virtual module are implemented; this report does
not mark the performance target complete.

The policy replaces two exact reviewed `github.githubassets.com` chunk versions.
Only four collector factories change: click/impression observation, Hydro event
submission, analytics batching, and browser metrics/RUM submission. Every other
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
