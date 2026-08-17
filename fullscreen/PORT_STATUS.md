# Fullscreen module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Fullscreen`

Translation workspace: `~/code/libweb_v/fullscreen`
Audited: 2026-08-16

Fullscreen is an IDL-only upstream module. All three partial-interface files
are represented by the V binding facade, which delegates the state machine to
the existing translated DOM implementation.

| Upstream interface definition | V implementation |
| --- | --- |
| `DocumentExtensions.idl` | `fullscreen.v` |
| `DocumentOrShadowRootExtensions.idl` | `fullscreen.v` |
| `ElementExtensions.idl` | `fullscreen.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Fullscreen/` | 0 | 0 | 93 | 177 | Complete |

The facade covers the current and historical document attributes, legacy
lenient setters, the historical unscopable marker, document and shadow-root
fullscreen-element lookup, request/exit promises, and document/element event
handler attributes. Focused tests cover every IDL member, rejected-promise
results, actual event-handler dispatch, DOM state reflection, and document and
shadow-root retargeting across a shadow boundary.

LibJS promises and Page's asynchronous fullscreen-enter/exit queue are not yet
available in the V workspace. The existing DOM translation therefore exposes
an observable, idempotently settled `dom.Promise` and performs successful
embedder effects synchronously at that boundary. Rejection is settled before
returning and does not mutate fullscreen state.

## Verification

```text
$ /Users/alex/code/v/v test fullscreen
Summary for all V _test.v files: 1 passed, 1 total.
```
