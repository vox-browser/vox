# IntersectionObserver module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/IntersectionObserver`

Translation workspace: `~/code/libweb_v/intersectionobserver`
Audited: 2026-08-16

Both upstream `.cpp` units, all three headers, and both Web IDL interfaces are
mapped. The port covers margin parsing and shorthand expansion, threshold
validation/sorting, visibility delay clamping, target registration lifecycle,
queued-record transfer, root rectangle margin inflation, registrations, and
fully typed read-only entry rectangles.

| Upstream implementation unit | V implementation |
| --- | --- |
| `IntersectionObserver.cpp` | `intersection_observer.v` |
| `IntersectionObserverEntry.cpp` | `intersection_observer_entry.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `IntersectionObserver/` | 2 | 445 | 376 | 186 | Complete |

## Verification

```text
$ /Users/alex/code/v/v test intersectionobserver
Summary for all V _test.v files: 2 passed, 2 total.

$ /Users/alex/code/v/v fmt -verify intersectionobserver
(no output; exit status 0)
```
