# WebAssembly port status

Audit snapshot: Ladybird `Libraries/LibWeb/WebAssembly` on 2026-08-17.

## Inventory

- Upstream: 6 `.cpp` files, 2,157 implementation LOC; 6 headers; 6 IDLs.
- V: 5 implementation files, 740 LOC; 4 test files, 245 LOC, 9 tests.

## Source mapping

| Upstream source | LOC | V translation |
| --- | ---: | --- |
| `Global.cpp`, `Global.h`, `Global.idl` | 179 | `value_global.v` |
| `Instance.cpp`, `Instance.h`, `Instance.idl` | 106 | `module_instance.v` |
| `Memory.cpp`, `Memory.h`, `Memory.idl` | 363 | `memory.v` |
| `Module.cpp`, `Module.h`, `Module.idl` | 146 | `module_instance.v` |
| `Table.cpp`, `Table.h`, `Table.idl` | 150 | `table.v` |
| `WebAssembly.cpp`, `WebAssembly.h`, `WebAssembly.idl` | 1,213 | `namespace.v`, `value_global.v`, `module_instance.v` |

All current `.cpp`, header and IDL files are accounted for.

## Coverage and boundaries

Portable behavior includes descriptor/range validation, i64 BigInt conversion,
externref/anyfunc defaults, global mutability, table operations, memory growth,
module framing and section ordering (including tag and data-count ordering),
custom/import/export section reflection, import linking, and streaming MIME
validation.

LibWasm validation, compilation, instruction execution, store addresses,
function wrapping and JS realm/promise integration are the explicit native
boundary. The V decoder validates the binary envelope and the sections needed
by the JS API facade; it does not replace LibWasm's full instruction validator.
`MemoryBuffer` is a backing-store snapshot with a generation marker, so exact
ArrayBuffer identity, detach keys and shared/resizable live-view behavior remain
an embedding responsibility. Streaming accepts a completed response body
rather than driving Fetch and its promise/event-loop machinery.
