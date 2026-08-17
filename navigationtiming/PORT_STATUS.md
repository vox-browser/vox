# NavigationTiming translation status

Upstream: `Libraries/LibWeb/NavigationTiming`

| Upstream unit | V implementation |
| --- | --- |
| `EntryNames.cpp` | `navigation_timing.v` |
| `PerformanceNavigation.cpp` | `navigation_timing.v` |
| `PerformanceTiming.cpp` | `navigation_timing.v` |

- Upstream: 3 `.cpp` files, 104 physical LOC.
- V implementation: 264 LOC.
- V tests: 42 LOC in 1 file.
- Status: complete.

`DocumentLoadTimingInfo` and the estimated monotonic epoch are injected typed
boundaries for the upstream Window/Document and clock dependencies. The
Performance partial-interface holder preserves `[SameObject]` identity.

Verification: `v test navigationtiming`, `v fmt -verify navigationtiming`, and
scoped `git diff --check` pass.
