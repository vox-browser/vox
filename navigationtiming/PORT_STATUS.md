# NavigationTiming translation status

Upstream: `Libraries/LibWeb/NavigationTiming`

| Upstream unit | V implementation |
| --- | --- |
| `EntryNames.cpp` | `navigation_timing.v` |
| `PerformanceNavigation.cpp` | `navigation_timing.v` |
| `PerformanceNavigationTiming.cpp` | `navigation_timing.v` |
| `PerformanceTiming.cpp` | `navigation_timing.v` |

- Upstream: 4 `.cpp` files, 497 physical LOC.
- V implementation: 637 LOC.
- V tests: 130 LOC in 1 file.
- Status: complete.

`NavigationTimingContext`, document timing records, and the estimated monotonic
epoch are injected typed boundaries for the upstream Window/Document, fetch,
and clock dependencies. Navigation resource entries are buffered on the shared
performance timeline, while the legacy partial-interface holder preserves
`[SameObject]` identity.

Verification: `v test navigationtiming`, `v fmt -verify navigationtiming`, and
scoped `git diff --check` pass.
