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
