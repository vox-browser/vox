# WebAssembly port status

Audit snapshot: Ladybird `Libraries/LibWeb/WebAssembly` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` on 2026-09-11.

## Historical audit inventory

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
host-function value adaptation, ES module adapter records, streaming MIME validation,
and response-body buffer extraction.

LibWasm validation, compilation, instruction execution, store addresses,
JS realm/promise integration are the explicit native boundary. The V decoder
parses every core binary section and all pinned instruction operands. It also
checks defined-function/body and data-segment counts, but does not replace
LibWasm's full instruction validator. `MemoryBuffer` models
realm identity, detachment, and resizable refreshes over backing-store snapshots;
native ArrayBuffer detach keys and shared DataBlock ownership remain embedding
responsibilities. Streaming accepts a completed response body rather than
driving Fetch and its promise/event-loop machinery.

## Completed binary-parser slices

At the same pinned upstream revision, `binary_types.v` translates LibWasm
`Parser/Parser.cpp` value/storage/reference/heap types, signed 33-bit heap
indices, function/struct/array composite types, subtype prefixes, and recursive
type groups. Module compilation now consumes the type section instead of
skipping it, retains all fields and group spans, and reconstructs them during
module deserialization. Malformed type tags, immediates, vector contents and
trailing section bytes are rejected.

`binary_import_types.v` translates TableType/GlobalType parsing. Imported
functions retain their type index; table/global imports retain full reference
operands, limits and mutability instead of dropping their descriptions.
Numeric table elements, packed global types, invalid mutability and truncated
reference immediates fail compilation. Memory section/limits and actual memory
instantiation remain the earlier completed slices.

Focused parser tests and all eight WebAssembly test files pass with
`v -old-compiler -enable-globals test webassembly`. This does not complete
recursive type canonicalization/subtyping, the instruction decoder/validator,
function execution, or table/global instantiation. Other core sections remain
explicit pending translation work; `validate()` still does not establish full
LibWasm module validity.

The additional function/start/data-count/tag slices translate their pinned
`Parser/Parser.cpp` records and preserve them through module serialization.
The function section retains defined-function type indices separately from
imports; a zero start index remains distinct from no start. Data-count retains
the source EOF read-error branch. Tag flags/type indices/imports/exports are
retained, while `LibWeb/WebAssembly/Module.cpp` still logs and omits tags from
its current JS reflection API. All 12 package test files pass. Start-function
invocation, tag store/exception execution, function/code-count checks and full
module validation remain pending with the other machine work.

The instruction and expression slices now cover all 499 pinned
`Instruction::parse` case labels. The checked-in opcode constants and
no-immediate case inventory are copied from that source by
`tools/generate_wasm_opcodes.py`; decoding algorithms are direct translations.
Typed structured/catch/index/memory/GC/SIMD arguments, raw float bits, source
local-index storage and synthetic expression endings are retained. Expression
parsing patches actual nested end/else instruction positions. Source parser
acceptance that is rejected by the later validator is preserved at the parser
boundary.

Global definitions and table definitions retain their real initializer
expressions; implicit table initializers use the source nullable `ref.null`.
Code bodies use declared-size constrained decoding, source local groups and
the 42,069 per-group local limit. Data segments retain all three source modes
and owned initialization bytes; element segments retain all eight source tags,
reference types, active offsets and synthetic function-index expressions.
The source byte-vector 500 MiB limit and UTF-8 name check are enforced. Every
core section is parsed; there is no skip fallback.

`binary_module_counts.v` translates the function/code count check and the
optional data-count/segment check from `AbstractMachine/Validator.cpp`.
Parser range fixtures use direct section decoders when their indices/counts
cannot describe a valid module; serialization fixtures retain matching counts.
All **21 WebAssembly test files pass** in the canonical checkout. Recursive
canonicalization/subtyping, expression stack and constant validation, the
remaining module checks and actual compilation/execution remain open. No full
`WebAssembly.validate()` conformance claim is made.
