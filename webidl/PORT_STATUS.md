# WebIDL port status

Audit snapshot: Ladybird `Libraries/LibWeb/WebIDL` on 2026-08-17.

## Inventory

- Upstream: 10 `.cpp` files, 2,110 implementation LOC; 13 headers; 3 IDLs.
- V: 8 implementation files, 1,139 LOC; 4 test files, 279 LOC, 13 tests.

## Source mapping

| Upstream source | LOC | V translation |
| --- | ---: | --- |
| `AbstractOperations.cpp`, `AbstractOperations.h`, `Types.h` | 573 | `value.v` |
| `AsyncIterator.cpp`, `AsyncIterator.h` | 217 | `async_iterator.v` |
| `Buffers.cpp`, `Buffers.h` | 156 | `buffers.v` |
| `CachedAttribute.h` | — | `async_iterator.v` |
| `CallbackType.cpp`, `CallbackType.h`, `Function.idl` | 45 | `promise.v` |
| `DOMException.cpp`, `DOMException.h`, `DOMException.idl` | 77 | `exceptions.v` |
| `ExceptionOr.h` | — | V result/error types and `exceptions.v` |
| `ObservableArray.cpp`, `ObservableArray.h` | 78 | `observable_array.v` |
| `OverloadResolution.cpp`, `OverloadResolution.h` | 465 | `overload_resolution.v` |
| `Promise.cpp`, `Promise.h` | 336 | `promise.v` |
| `QuotaExceededError.cpp`, `QuotaExceededError.h`, `QuotaExceededError.idl` | 109 | `exceptions.v` |
| `Tracing.cpp`, `Tracing.h` | 54 | `tracing.v` |

All current `.cpp`, header and IDL files are accounted for.

## Coverage and boundaries

Portable behavior includes DOM exception legacy codes and serialization, quota
validation, buffer/view bounds and alignment, observable-array mutation hooks,
distinguishing-overload precedence, promise reactions and pending `wait_for_all`,
async iteration, callback invocation, cached attributes and trace formatting.

`webidl.Value` is the explicit boundary for LibJS values, realms, prototypes,
property access and GC roots. It deliberately implements only the conversions
needed by translated packages; host-object/proxy side effects and the complete
Web IDL conversion matrix remain with the embedding JavaScript engine. Promise
reactions settle deterministically when V promises settle rather than through a
browser event-loop microtask queue. Tracing records lines instead of writing to
Ladybird's debug stream.
