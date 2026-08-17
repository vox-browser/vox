# Geolocation translation status

Status: **Complete** (2026-08-17)

## Upstream inventory and mapping

The current `Libraries/LibWeb/Geolocation` source inventory is 12 files and
750 physical lines: 4 `.cpp` files / 511 lines, 4 adjacent `.h` files / 178
lines, and 4 `.idl` files / 61 lines. Every implementation unit and its
adjacent declaration/IDL surface is represented below.

| Upstream implementation | C++ LOC | V translation |
| --- | ---: | --- |
| `Geolocation.cpp` | 401 | `geolocation.v` |
| `GeolocationCoordinates.cpp` | 32 | `geolocation_position.v` |
| `GeolocationPosition.cpp` | 36 | `geolocation_position.v` |
| `GeolocationPositionError.cpp` | 42 | `geolocation_position.v` |
| **Total** | **511** | **391 implementation LOC** |

The V implementation covers the IDL entry points and records, lifecycle and
secure-context checks, watch registration/cancellation, feature-policy denial,
hidden-document waiting and its five-second expiry, emulated results, cache
age/accuracy matching, queued callback delivery, error objects, and default
JSON conversion.

## Explicit host boundaries

`GeolocationHost` is the typed boundary for state owned outside this module:
the associated document, secure-context and feature-policy decisions, page
visibility, wall clock, emulated coordinates, and the platform position
provider. Callback execution is deliberately exposed through the geolocation
task queue (`run_next_task`/`drain_tasks`) rather than hidden behind a V thread.
Ladybird's own current device acquisition and permission-request branches are
still marked FIXME; the provider boundary preserves the observable success or
failure without fabricating a platform service.

## Tests and physical LOC

- Implementation: **391 LOC** (`geolocation.v` 248 +
  `geolocation_position.v` 143).
- Tests: **174 LOC**, **10 focused tests**
  (`geolocation_position_test.v`).
- Implementation and test totals are disjoint physical line counts; this file
  is excluded.
- Focused verification: `v test geolocation`.
