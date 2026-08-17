# EventTiming module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/EventTiming`

Translation workspace: `~/code/libweb_v/eventtiming`
Audited: 2026-08-16

The sole upstream EventTiming `.cpp` implementation unit has an audited V
implementation mapping. Its header and inherited Web IDL attributes are
represented by typed V records, registry enums, constructors, and getters.

| Upstream implementation unit | V implementation |
| --- | --- |
| `PerformanceEventTiming.cpp` | `performance_event_timing.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `EventTiming/` | 1 | 131 | 170 | 93 | Complete |

The port covers construction and capture of the inherited PerformanceEntry
data, event timestamp and cancelability, entry type, timeline availability,
maximum buffer size, first-input admission, the default IDL JSON surface, and
the current event admission behavior. PerformanceTimeline itself is not yet
translated, so its narrow inherited surface is represented locally.

Ladybird's upstream C++ still marks processing start/end, target, interaction
ID, duration-threshold admission, and several interaction algorithms as
`FIXME`. Their currently observable zero/null results are deliberately
preserved rather than replaced with speculative behavior, and are covered by
the focused tests. The upstream `VERIFY` guarding the event entry type is also
preserved as a fatal invariant.

## Verification

```text
$ /Users/alex/code/v/v test eventtiming
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v fmt -verify eventtiming
(no output; exit status 0)
```
