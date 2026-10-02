# WebIDL port status

Audit snapshot: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`
`Libraries/LibWeb/WebIDL` on 2026-09-12.

## Inventory

- Upstream: 10 `.cpp` files, 2,466 implementation LOC; 14 headers; 4 IDLs.
- V: 10 implementation files, 2,162 LOC; 5 test files, 613 LOC, 28 tests.
- The upstream delta from the 2026-03-24 baseline has no unmatched added
  WebIDL functions after this refresh.

## Source mapping

| Upstream source | LOC | V translation |
| --- | ---: | --- |
| `AbstractOperations.cpp`, `AbstractOperations.h`, `Types.h` | 702 | `abstract_operations.v`, `value.v` |
| `AsyncIterator.cpp`, `AsyncIterator.h` | 341 | `async_iterator.v` |
| `Buffers.cpp`, `Buffers.h`, `Buffers.idl` | 397 | `buffers.v` |
| `CachedAttribute.h` | 18 | `async_iterator.v` |
| `CallbackType.cpp`, `CallbackType.h`, `Function.idl` | 97 | `promise.v` |
| `DOMException.cpp`, `DOMException.h`, `DOMException.idl` | 328 | `exceptions.v` |
| `ExceptionOr.h`, `ExceptionOrUtils.h` | 300 | V result/error types and `exceptions.v` |
| `ObservableArray.cpp`, `ObservableArray.h` | 138 | `observable_array.v` |
| `OverloadResolution.cpp`, `OverloadResolution.h` | 511 | `overload_resolution.v` |
| `OverloadTypes.cpp`, `OverloadTypes.h` | 286 | `overload_types.v` |
| `Promise.cpp`, `Promise.h` | 539 | `promise.v` |
| `QuotaExceededError.cpp`, `QuotaExceededError.h`, `QuotaExceededError.idl` | 169 | `exceptions.v` |
| Removed upstream `Tracing.cpp`, `Tracing.h` | — | retained compatibility in `tracing.v` |

All current `.cpp`, header and IDL files are accounted for.

## Coverage and boundaries

Portable behavior includes DOM exception wrapper reporting, legacy codes and
serialization; quota validation; typed buffer/view bounds, validation records
and checked writes; indexed observable-array mutation hooks; recursive Web IDL
type/union classification and distinguishing-overload precedence; relevant-realm
promise helpers, reactions and pending `wait_for_all`; relevant-realm async
iteration; callback invocation; cached attributes; and trace formatting.

`webidl.Value` is the explicit boundary for LibJS values, realms, prototypes,
property access and GC roots. It deliberately implements only the conversions
needed by translated packages; host-object/proxy side effects and the complete
Web IDL conversion matrix remain with the embedding JavaScript engine. Promise
reactions settle deterministically when V promises settle rather than through a
browser event-loop microtask queue. Tracing records lines instead of writing to
Ladybird's debug stream.

Integer EnforceRange conversion now reports the pinned source's exact nonfinite
error and includes the truncated value plus concrete signed/unsigned target
bounds in range failures. The existing translated LibJS numeric formatter
retains AK's decimal/exponent thresholds. Focused tests cover all four target
widths, signed and unsigned bounds, truncation before checking, nonfinite values,
and large-number error text; the existing core conversion tests also pass.

Primitive numeric conversion now reuses the translated LibJS StringToNumber
and Number formatting paths. Radix literals, Unicode whitespace, infinities,
negative zero, malformed numeric strings, BigInt rejection, and decimal/exponent
thresholds follow the source. Focused primitive, EnforceRange, and core test
files pass. Arbitrary object ToPrimitive execution and Symbol values still
require the VM boundary; these changes do not manufacture their side effects.
Existing typed object-string convenience representations remain separate from
claims of complete ECMAScript object conversion.
