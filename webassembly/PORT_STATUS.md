# WebAssembly port status

Audit snapshot: Ladybird `Libraries/LibWeb/WebAssembly` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` on 2026-09-11.

## Inventory

- Upstream: 7 `.cpp` files, 3,441 implementation LOC; 8 headers; 6 IDLs.
- V: 7 implementation files, 2,065 LOC; 4 test files, 702 LOC, 29 tests.

## Source mapping

| Upstream source | LOC | V translation |
| --- | ---: | --- |
| `BindingsGlue.h` | 67 | `namespace.v`, `value_global.v`, `module_instance.v`, `table.v` |
| `Global.cpp`, `Global.h`, `Global.idl` | 296 | `value_global.v` |
| `Instance.cpp`, `Instance.h`, `Instance.idl` | 302 | `module_instance.v` |
| `Memory.cpp`, `Memory.h`, `Memory.idl` | 565 | `memory.v` |
| `Module.cpp`, `Module.h`, `Module.idl` | 266 | `module_instance.v` |
| `Table.cpp`, `Table.h`, `Table.idl` | 396 | `table.v` |
| `WebAssembly.cpp`, `WebAssembly.h`, `WebAssembly.idl` | 1,683 | `cache.v`, `namespace.v`, `value_global.v`, `module_instance.v` |
| `WebAssemblyModule.cpp`, `WebAssemblyModule.h` | 579 | `webassembly_module.v` |

All current `.cpp`, header and IDL files are accounted for.

## Coverage and boundaries

Portable behavior includes descriptor/range validation, i64 BigInt conversion,
externref/anyfunc defaults, global mutability, table operations, memory growth,
module framing and section ordering (including tag and data-count ordering),
custom/import/export section reflection, structured module serialization,
realm-owned wrapper caches, per-realm memory buffers and instance exports,
host-function value adaptation, ES module linking, streaming MIME validation,
and response-body buffer extraction.

LibWasm validation, compilation, instruction execution, store addresses,
JS realm/promise integration are the explicit native boundary. The V decoder
validates the binary envelope and the sections needed by the JS API facade; it
does not replace LibWasm's full instruction validator. `MemoryBuffer` models
realm identity, detachment, and resizable refreshes over backing-store snapshots;
native ArrayBuffer detach keys and shared DataBlock ownership remain embedding
responsibilities. Streaming accepts a completed response body rather than
driving Fetch and its promise/event-loop machinery.
