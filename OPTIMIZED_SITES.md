# Optimized sites

Recorded workloads where Vox uses fewer CPU instructions than Brave. These
macOS comparisons cover browser startup through a completed document capture;
fewer instructions measure CPU work, rather than elapsed rendering time.
Results apply to the frozen page and pinned build in each linked report.

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | --- |
| Old Reddit /r/programming/ | 2026-11-01 | 7 | Median | 4,954,400,539 | 9,248,675,091 | **46.43%** | [Comparison](docs/OLD_REDDIT_PROGRAMMING_INSTRUCTIONS.md) |
| Hacker News homepage | 2026-11-01 | 7 | Median | 4,877,590,820 | 8,554,149,229 | **42.98%** | [Comparison](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md) |
| Wikipedia homepage | 2026-11-01 | 7 | Median | 6,686,475,010 | 9,702,898,348 | **31.09%** | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/WIKIPEDIA_BRAVE_INSTRUCTIONS.md) |
| vlang.io (CLI protocol) | 2026-11-01 | 7 | Mean | 8.630 billion | 10.500 billion | **17.81%** | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/VLANG_RENDERING_INSTRUCTIONS.md) |

Percentages compare the two browser summaries in the same row. Means and
medians are labeled separately; the vlang.io means are rounded. All workloads
use a 1024×768 CSS-pixel viewport. Hacker News uses native capture scale 2;
the other workloads use scale 1. Old Reddit, Wikipedia and vlang.io use process-tree counters:
Vox includes capture and teardown, while Brave ends before shutdown. Both sums
are observed lower bounds because short-lived unsampled children can be missed.
Hacker News uses exclusive resource-coalition counters through PNG availability,
including exited helpers and explicitly allowed coalition-owned system services;
Vox ends before the PNG file write and Brave includes CDP screenshot delivery.
GPU execution and services outside the recorded ownership scope are excluded.
The reports retain exact endpoints, identities and counter limits.

## Workload and rendering scope

- **Old Reddit /r/programming/:** cached account-bearing markup, 17 executable
  script elements removed, normal scripting policy retained, 120 sealed
  successful resource responses and fresh profiles/caches. All 14 captures
  match the same Brave reference exactly and preserve all 25 post IDs. The
  highest observed Vox count is **45.91% below the lowest Brave count**. Live
  access is blocked by HTTP 403; no live or current-authentication claim is
  made. This new workload does not reverify the historical home-page fixture.
  The selected Vox page-script runtime is unused on this script-free fixture;
  the [JSC/LibJS selector comparison](docs/OLD_REDDIT_ENGINE_COMPARISON.md) is
  a configuration comparison, not a JavaScript-execution benchmark.
- **Hacker News:** the frozen original homepage and five resources, with author
  scripts enabled, fresh empty profiles/caches and two seconds of settlement.
  All 14 captures match the unchanged Brave reference at every pixel and retain
  all 30 story IDs. The highest Vox count is **41.61% below the lowest Brave
  bound**, passing the 10% target. The earlier 3× headline excluded Brave's
  window setup while including Vox's; the corrected startup scope includes
  setup for both. The same pinned binaries were reused, so the accounting
  correction receives no engine optimization credit. OS caches are retained;
  the report preserves earlier startup outliers and makes no cold-system claim.
- **Wikipedia:** original archived responses, fresh empty profiles/caches,
  JavaScript disabled in both browsers, matching Vox's existing Wikipedia
  policy. All 14 captures match their respective engine baselines exactly;
  seven pixels at the search-box corners differ between engines. Even the
  highest observed Vox count is **29.81% below the lowest observed Brave count**
  in the fresh audit, which records successful browser exits. A separate live
  navigation using the measured capture path matches the frozen Vox pixels.
  The existing production build already met the target; this comparison
  required no runtime optimization.
- **vlang.io:** an initialized DOM snapshot with archived assets, author scripts
  removed, animations/transitions disabled and a fixed video poster; JavaScript
  policy remains enabled. The fresh CLI audit records clean exits and exact
  matches to unchanged engine references in all 14 captures. The highest Vox
  count is **15.10% below the lowest Brave bound**. Cross-browser equality is
  unmet: 112,005 pixels differ, with maximum channel error 3. The earlier CLI
  cohort's 16.54% mean lead and the background cohort's **0.41% mean lead** both
  remain in the report. Launch-context dependence is unresolved; the table
  applies to the stated CLI protocol. Live author-script behavior is checked
  separately from these instruction measurements.

## Historical result awaiting raw verification

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | --- |
| Old Reddit home | 2026-10-17 | 7 | Median | 6,289,762,769 | 8,208,707,273 | **23.38%** | [Historical comparison](docs/OLD_REDDIT_INSTRUCTIONS.md), [audit](docs/OPTIMIZED_SITES_AUDIT.md) |

The documented arithmetic and startup scope check out, but the private
`Build/reddit-parity/` fixture and per-process receipts are absent from this
checkout. This older home-page row is distinct from the newly measured
`/r/programming/` workload above and is not a freshly verified acceptance result. Its report
describes a frozen authenticated page with executable author scripts removed,
exact Brave-reference captures and a conservative 21.39% observed lead. Live
scripting, interactions and authentication parity are outside that record.

## Comparisons still open

[Pikabu](docs/PIKABU_INSTRUCTIONS.md) has a small, variable observed median lead
that does not establish a repeatable advantage. [CNN](docs/CNN_INSTRUCTIONS.md) and
[Stack Overflow on macOS](docs/STACKOVERFLOW_BRAVE_INSTRUCTIONS.md) have not
established lower instruction counts than Brave. The fresh seven-pair Stack
Overflow comparison records median observed counts of **27,723,596,574 for Vox**
and **10,379,419,729 for Brave**: Vox uses **2.67× as many instructions** on the
frozen questions page. All captures match their fixed per-engine references;
2,061 pixels differ across engines. The earlier
[PR diagnostic](docs/STACKOVERFLOW_MACOS_PR_COMPARISON.md) remains separate.
Stack Overflow's
[Linux optimization](docs/STACKOVERFLOW_LINUX_PERFORMANCE.md) compares two Vox
versions using Cachegrind instruction references, rather than Vox against Brave.
