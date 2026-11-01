# Optimized-site instruction audit, 2026-11-01

This audit precedes a subsequent [Old Reddit /r/programming/ measurement](OLD_REDDIT_PROGRAMMING_INSTRUCTIONS.md).
That new cached workload passes seven fresh pairs with a 46.43% observed median
lead and exact cross-browser pixels. The missing historical home-page fixture
and receipts discussed below remain unavailable; that older cohort is not
retroactively verified.

Wikipedia and vlang.io retain their observed startup-through-capture leads in
fresh seven-pair checks using the same pinned binaries and fixtures as their
original reports. Their primary counters include startup in both engines;
neither repeats Hacker News's asymmetric navigation-boundary error. Old Reddit's
documented arithmetic is consistent, but its private fixture and raw process
receipts are unavailable, so its result is now listed as historical pending
verification.

| Workload | Fresh pairs | Statistic | Vox observed instructions | Brave observed instructions | Reduction | Highest Vox / lowest Brave |
| --- | ---: | --- | ---: | ---: | ---: | ---: |
| Wikipedia | 7 | Median | 6,686,475,010 | 9,702,898,348 | 31.09% | 0.701887425 |
| vlang.io, CLI protocol | 7 | Mean | 8,630,402,362.71 | 10,500,268,115.57 | 17.81% | 0.848998276 |

Both fresh cohorts pass the 10% gate on observed counts with every attempt
retained. All 28 browser exits, both benchmark exits and both memory-guard exits
are zero. This audit changes measurement tooling and documentation; it earns
no engine optimization credit and requires no production build. The broader
runtime verification ledger does not advance.

## Counter and boundary audit

Both harnesses use `proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions` through
`tools/measure_browser_instructions.py`. The primary total equals the sum of
the recorded processes' cumulative instruction readings. Brave's separate
`navigation_to_screenshot` delta is retained as supplementary data and is
smaller than the primary total in every checked observation. The primary call
uses `counter.report(snapshot=endpoint_snapshot)` without a baseline subtraction.
Vox includes the root's final zombie reading after capture and teardown.

Brave's endpoint is the last completed sampler pass before its first PNG CDP
response. Its later content audit and shutdown are excluded. Vox's additional
audit/teardown work is included where enabled. These are documented capture
workflows, rather than equivalent internal rendering endpoints. Both aggregate
process-tree totals are polling lower bounds: an entire short-lived child can
be missed. The highest-observed-Vox/lowest-observed-Brave gate is conservative
among recorded observations; it is not a mathematical bound on unobserved Vox
work. GPU execution, external system services, replay and observer work are
excluded.

The old shared Brave path did not record the actual browser exit and could
immediately signal a still-closing browser during cleanup. The repaired path
waits for `Browser.close`, records the real exit and preserves frozen counters
in a failure receipt for a crash or forced shutdown. It never adds shutdown
instructions to the capture total. Both site gates now reject missing,
abnormal or forced exits. A regression test supplies distinct startup and
navigation totals and verifies that the primary result retains startup; the
threshold gate now uses exact integer arithmetic.

## Wikipedia

The same 15-response archive, 1024×768 CSS viewport, 1× scale, JavaScript-disabled
policy, fresh profiles/caches and sealed loopback replay are retained. Both
observed Vox tasks have final readings in all seven trials. Brave's missing
final-sample counts are 1, 1, 2, 2, 2, 1, 1; no counter reads are denied.
All 14 captures match their unchanged engine references. The known **seven-pixel
cross-browser difference** remains, so this establishes rendering stability
with an observed instruction lead, while exact cross-browser parity stays open.

The original medians, 6,600,176,026 and 9,661,801,676, correctly give 31.69%.
The fresh cohort gives 31.09%; its highest observed Vox count is 29.81% below
the lowest observed Brave count. Both cohorts remain retained. See the
[Wikipedia report](WIKIPEDIA_BRAVE_INSTRUCTIONS.md).

## vlang.io

The same script-free initialized snapshot, archived fonts/assets, fixed poster,
disabled animations, 1024×768 viewport, 1× scale and pinned candidate are
retained. Both engines start with fresh profiles; native phase/capture-audit
instrumentation stays disabled for the unprofiled comparison. Runtime pins now
cover transitive native dependencies, the helper/snapshot, Brave's dlopened
framework and the measurement sources. Every observation passes actual exit,
runtime-identity and counter checks.

All 14 fresh captures match their unchanged historical engine references.
The cross-browser comparison differs at **112,005 of 786,432 pixels (14.24%)**,
with **maximum channel error 3** and no channels exceeding 3. Both captures
were inspected. Matching each engine's reference does not imply equal rendered
pixels between engines; no reference or tolerance was changed.

The fresh mean uses unrounded totals: 8,630,402,362.714285 versus
10,500,268,115.571428, giving 17.8077905%. The catalog rounds the display to
8.630/10.500 billion and 17.81%. Its highest-Vox/lowest-Brave observed reduction
is 15.10%. The original 16-wave CLI mean reduction of 16.54% also recomputes
correctly. The separate background cohort gives 0.41% and fails the 10% gate;
its mean Brave root count is about 3.873 billion, versus 5.676 billion in the
original CLI cohort. The cause of this launch-context dependence remains
unresolved. No background observations are dropped or pooled into the CLI
claim. See the [vlang.io report](VLANG_RENDERING_INSTRUCTIONS.md).

## Old Reddit

The seven documented rows give median counts of 6,289,762,769 and 8,208,707,273:
**23.38%** by the ratio of medians. The **23.44% median paired reduction** is a
different, correctly labeled statistic. The documented highest-Vox/lowest-Brave
ratio is 0.786111236, an observed reduction of 21.39%.

The current harness includes startup through capture, but its legacy environment
did not enforce a fresh private Vox profile. That isolation is now explicit for
future runs; ambient controls are sanitized for both engines, and runtime pins
include Brave's framework and Vox's transitive dependencies. Raw reports are
saved before validation. These repairs cannot retroactively establish the old
cohort's environment or counter coverage. The private `Build/reddit-parity/`
directory, frozen input, reference and accepted summary are absent, so there is
no new Reddit acceptance run. The [historical report](OLD_REDDIT_INSTRUCTIONS.md)
and its numbers remain available outside the freshly verified catalog table.

## Retained evidence and checks

Raw commands, counters, PNGs, complete reports, source/runtime pins and guard
receipts are under `Build/optimized-sites-audit-20261101/`. The durable
[machine-readable audit](benchmark-results/optimized-sites-audit-2026-11-01.json)
retains every fresh count, both historical vlang.io cohorts, the documented
Reddit arithmetic, per-process coverage and artifact hashes. Host loads and
timestamps remain attached to each observation; elapsed time earns no credit.
The fresh checks reuse completed pinned bundles to audit the published claims,
without attributing unrelated shared production changes to the results.

All **71 focused checks** pass for the shared observer, process counters,
Wikipedia and Reddit drivers and the dependent CNN driver. They exercise clean/abnormal/forced exits,
retained failure receipts, distinct startup/navigation totals, exact large-count
gates, private profiles, environment restoration and runtime dependency pins.
The initial new pinning test failed on macOS's `/var` versus `/private/var`
aliases. Its failed receipt remains retained; the corrected assertion compares
resolved paths. The shutdown fix is `01a98319`, profile/runtime isolation is
`bbadd820`, and the test correction is `413775e6`.
