# PerformanceTimeline translation status

Upstream: `Libraries/LibWeb/PerformanceTimeline`

| Upstream unit | V implementation |
| --- | --- |
| `EntryTypes.cpp` | `entry.v` |
| `EventNames.cpp` | `entry.v` |
| `PerformanceEntry.cpp` | `entry.v` |
| `PerformanceObserver.cpp` | `observer.v` |
| `PerformanceObserverEntryList.cpp` | `entry_list.v` |

- Upstream: 5 `.cpp` files, 391 physical LOC.
- V implementation: 417 LOC.
- V tests: 130 LOC in 2 files.
- Status: complete.

The translated timeline context is the typed Window/Worker boundary: it owns
the supported-entry array, registered observers, entry buffers, dropped-entry
counts, and queued observer delivery. Callback invocation is synchronous when
the context's queued task is explicitly run.

Verification: `v test performancetimeline`, `v fmt -verify
performancetimeline`, and scoped `git diff --check` pass.
