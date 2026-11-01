# Optimized sites

Recorded workloads where Vox uses fewer CPU instructions than Brave. These
macOS comparisons cover browser startup through a completed document capture;
fewer instructions measure CPU work, rather than elapsed rendering time.
Results apply to the frozen page and pinned build in each linked report.

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | --- |
| Hacker News homepage | 2026-11-01 | 7 | Median | 4,877,590,820 | 8,554,149,229 | **42.98%** | [Comparison](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md) |
| Wikipedia homepage | 2026-11-01 | 7 | Median | 6,600,176,026 | 9,661,801,676 | **31.69%** | [Comparison](docs/WIKIPEDIA_BRAVE_INSTRUCTIONS.md) |
| Old Reddit | 2026-10-17 | 7 | Median | 6,289,762,769 | 8,208,707,273 | **23.38%** | [Comparison](docs/OLD_REDDIT_INSTRUCTIONS.md) |
| vlang.io | 2026-10-31 | 16 | Mean | 8.701 billion | 10.425 billion | **16.54%** | [Comparison](docs/VLANG_RENDERING_INSTRUCTIONS.md) |

Percentages compare the two browser summaries in the same row. Means and
medians are labeled separately; the vlang.io means are rounded. All workloads
use a 1024×768 CSS-pixel viewport. Hacker News uses native capture scale 2;
the other workloads use scale 1. Wikipedia, Old Reddit and
vlang.io use process-tree counters: Vox includes capture and teardown, while
Brave ends before shutdown and its observed counts are polling lower bounds.
Hacker News uses exclusive resource-coalition counters through PNG availability,
including exited helpers and explicitly allowed coalition-owned system services;
Vox ends before the PNG file write and Brave includes CDP screenshot delivery.
GPU execution and services outside the recorded ownership scope are excluded.
The reports retain exact endpoints, identities and counter limits.

## Workload and rendering scope

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
  highest Vox count is **30.41% below the lowest Brave count**. A separate live
  navigation using the measured capture path matches the frozen Vox pixels.
  The existing production build already met the target; this comparison
  required no runtime optimization.
- **Old Reddit:** a frozen authenticated page with executable author scripts
  removed and normal scripting policy retained for `noscript` behavior. Every
  capture matches the same Brave reference exactly. The conservative
  highest-Vox/lowest-Brave comparison shows **21.39% fewer instructions**;
  the table's 23.38% compares the medians. Live scripting, interactions and
  authentication parity are outside this result.
- **vlang.io:** an initialized DOM snapshot with archived assets, author scripts
  removed, animations/transitions disabled and a fixed video poster; JavaScript
  policy remains enabled. The original CLI launch protocol yields all 16 Vox
  captures below their paired Brave counts, with exact native baseline pixels.
  A separate background-job launch protocol yields only a **0.41% mean lead**,
  with nine wins and seven losses and an uncertainty interval crossing zero.
  The 16.54% result is specific to the original CLI protocol. Live author-script
  behavior is checked separately from these instruction measurements.

## Comparisons still open

[Pikabu](docs/PIKABU_INSTRUCTIONS.md) has a small, variable observed median lead
that does not establish a repeatable advantage. [CNN](docs/CNN_INSTRUCTIONS.md) and
[Stack Overflow on macOS](docs/STACKOVERFLOW_MACOS_PR_COMPARISON.md) have not
established lower instruction counts than Brave. Stack Overflow's
[Linux optimization](docs/STACKOVERFLOW_LINUX_PERFORMANCE.md) compares two Vox
versions using Cachegrind instruction references, rather than Vox against Brave.
