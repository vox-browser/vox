# ResourceTiming translation status

Upstream: `Libraries/LibWeb/ResourceTiming`

| Upstream unit | V implementation |
| --- | --- |
| `PerformanceResourceTiming.cpp` | `performance_resource_timing.v` |

- Upstream: 1 `.cpp` file, 340 physical LOC.
- V implementation: 317 LOC.
- V tests: 71 LOC in 1 file.
- Status: complete.

The typed context supplies the relevant global's time origin, isolation flag,
PerformanceTimeline buffer, and Fetch timing record. All observable timing,
cache-size, protocol, response, delivery, and render-blocking branches are
implemented.

Verification: `v test resourcetiming`, `v fmt -verify resourcetiming`, and
scoped `git diff --check` pass.
