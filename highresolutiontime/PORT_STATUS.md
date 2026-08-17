# HighResolutionTime translation status

Status: **Complete** (2026-08-17)

## Upstream inventory and mapping

The current `Libraries/LibWeb/HighResolutionTime` inventory is 10 files and
698 physical lines: 2 `.cpp` files / 521 lines, 5 adjacent `.h` files / 135
lines, and 3 `.idl` files / 42 lines. All declarations and IDL surfaces were
audited, including the two timestamp typedefs and
`SupportedPerformanceTypes.h`.

| Upstream implementation | C++ LOC | V translation |
| --- | ---: | --- |
| `Performance.cpp` | 404 | `performance.v`; shared entry types in `performancetimeline/`, `usertiming/`, `resourcetiming/`, and `navigationtiming/` |
| `TimeOrigin.cpp` | 117 | `time_origin.v` |
| **Total** | **521** | **362 local implementation LOC** |

`performance.v` implements stable `timeOrigin`, `now()`, default JSON,
mark/measure creation and validation, legacy timing-name conversion, clear and
filter operations, resource-buffer sizing, the buffer-full handler, and the
shared performance-entry timeline. The legacy `timing` and `navigation` object
types are translated in `navigationtiming/` to avoid creating a V import cycle;
their values enter name conversion through `PerformanceHost`.

## Explicit host boundary

`TimeOriginContext` contains exactly the relevant environment-settings values
used by the time-origin algorithms. `PerformanceHost` additionally supplies
the Window-vs-Worker distinction and legacy navigation timing timestamps.
System wall and monotonic clocks use V's `time` primitives. No browser global
or platform clock is fabricated.

## Tests and physical LOC

- Implementation: **362 LOC** (`performance.v` 277 + `time_origin.v` 85).
- Tests: **181 LOC**, **16 focused tests** (`performance_test.v` 114 +
  `time_origin_test.v` 67).
- Implementation and test counts are disjoint physical LOC; this file and the
  shared-package implementations named above are excluded.
- Focused verification: `v test highresolutiontime`.
