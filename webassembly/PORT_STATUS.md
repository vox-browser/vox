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

The V decoder parses every core binary section and all pinned instruction
operands. Source recursive type canonicalization/matching, type-section checks,
module indices, tag/start signatures, section counts and expression validation
now run in the module path. All 500 pinned instruction-validation specializations
have translated handlers and complete dispatch. Native compilation, instruction
execution, complete Store integration and JS realm/promise integration remain open.
`Memory` wrappers now use actual indexed Store instances and primitive-storage
handles. Realm-specific buffers share live storage instead of copied byte
snapshots, retain fixed or dynamic lengths, and follow the source refresh and
detachment branches. Native JS ArrayBuffer objects, detach keys and the full
GC owner graph remain embedding responsibilities. Streaming accepts a completed response body rather than
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

At the initial type/import-parser stage, all eight WebAssembly test files passed with
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
its current JS reflection API. At that parser stage, all 12 package test files passed. Start-function
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
At the complete section/count-parser stage, all **21 WebAssembly test files passed** in the canonical checkout. Recursive
canonicalization/subtyping, expression stack and constant validation, the
remaining module checks and actual compilation/execution remain open. No full
`WebAssembly.validate()` conformance claim is made.

## Completed type system and validator slices

`type_registry.v` and `type_matching.v` translate all of pinned
`AbstractMachine/TypeSystem.cpp`: synchronized process-wide canonical type
interning, recursive-group closure and relocation, supertype ancestry, heap and
value subtyping, storage/field matching, function parameter contravariance,
result covariance, structs/arrays and cross-context table/global/tag matching.
Canonical type records retain actual identity and remain rooted under both GC
modes. Source `canonicalize_type()`'s singleton-group limitation is preserved:
closed references outside its singleton group fail the pinned source assertion.
It is not silently replaced with a different canonicalization algorithm.

`type_validation.v` and `module_indices.v` enforce source final-supertype,
ordering and composite-subtyping checks, valid type uses, import/export indices,
duplicate export names, exception-tag signatures and `start: [] -> []`. The
module context retains the source declared `ref.func` set, including references
from exports, element items and global/table initializers.

`validation_stack.v` translates polymorphic stack entries, frame baselines,
maximum stack usage and definite-local initialization undo logs.
`fixed_stack_validation.v` contains **355 complete instruction bodies** copied
from pinned `Validator.cpp` by a strict source-statement translator. Numeric
and SIMD types/effects are copied from the complete C++ bodies; no opcode-name
inference supplies omitted logic. Context-dependent bodies are excluded.
`reference_variable_validation.v` translates references, both selects and local/
global access. `control_validation.v` translates blocks, loops, if/else/end,
branches, returns, `try_table` catches and throws, retaining source metadata and
local-initialization rollback. Real parsed-expression tests exercise constant
flags, SIMD scalar/vector operand order, unreachable polymorphism, implicit
else validation, loop labels and outer catch-label scope.

At the control-handler stage, all **29 WebAssembly test files passed** in the
canonical checkout; those handlers were not yet wired to expressions.

The remaining call, table, memory, SIMD lane/memory and GC reference/aggregate
families now translate every pinned validator specialization. The strict
`tools/generate_wasm_validation_dispatch.py` inventory rejects missing, duplicate
and non-source routes before emitting `instruction_validation.v`. Its 500 routes
connect those actual bodies without inferring effects from opcode names.

`expression_validation.v` executes each handler even after a nonconstant
instruction, retains branch/structured metadata in the original instructions,
checks and re-appends required result types, releases the function frame and
stores the peak stack hint. Module validation now checks active data/table
offsets against the selected address kind, element initializers, ordered global
initializers, table initializers with only imported globals visible, and all
function bodies. Functions retain signature parameters and expanded local types,
initialize defaultable locals and roll back nonnullable-local initialization at
the source control boundaries. Surplus result values are checked by each section
caller, rather than discarded by the expression pass.

Source behavior is retained even where it differs from newer specifications:
tail indirect calls take an i32 table address; several SIMD memory handlers take
i32 addresses for memory64; passive numeric element types receive the pinned
ValueType check; and singleton canonicalization keeps the source assertion.
Parser fixtures containing invalid module indices or initializer types are
tested directly at the parser boundary. Valid modules regenerate validator
metadata and stack hints during serialization round trips.

The complete expression/module stage passed **42/42 files** with default GC.
The additional source-order regression passed with its count/limits neighbors,
and the current package passes **43/43 files with `-gc none`**. The module driver
keeps the source order for data, elements, globals, memories, tables, code and
tags instead of pre-validating defined memory/global/table types. Pinned
`try_compile_instructions`, Cranelift eligibility/compilation, compiled call-record
allocation and actual machine execution remain untranslated. These tests are
focused source regressions, not a full WebAssembly conformance corpus.

## Completed machine value and ownership foundations

`machine_value.v` translates `AbstractMachine.h`'s reference variants and
two-word, 16-byte untyped value representation. It preserves signed numeric
extension, float bit patterns, actual defining-module pointers, null reference
families, i31 masking and the internal/external GC wrapper tags.

`machine_value_stack.v` translates all of `ValueStack.{h,cpp}`. It uses a real
64 MiB virtual-memory reservation with stable base/top pointers, source stack
operations, actual member ABI offsets, eight-value conservative scan slack and
the source four-region LIFO pool per native thread. The native header supplies
only OS mapping calls and a thread-local slot; V owns the pool and stack logic.
The intentionally leaked thread pools and explicit owner destructor boundary
preserve source reuse without clearing the whole mapping.

`machine_result.v` translates trap/result variants and linking/instantiation
error records. External trap payloads retain the source 64-byte raw storage;
the generic unsafe access boundary requires a trivially copyable, destructible
type, with its size asserted in V. Result accessors expose the actual selected
variant, including mutable result vectors and uncaught-exception identity.

`machine_global.v` translates `GlobalInstance` and the global allocation/getter
slice of `Store`. Addresses are actual vector indices, and owned global records
remain at stable addresses when the pointer vector grows. Mutability checks and
the compiled-code value offset use the real value storage. Other Store families,
active configurations and the source Heap/RootsProvider are still pending.

`machine_segments.v` and `machine_exceptions.v` translate data, element, tag and
exception records and their Store allocation/getter families. Data and element
drop operations replace the actual owned vectors. Tags retain their canonical
type pointer and exceptions retain their actual tag address and untyped values.
These Store vectors contain values, as upstream does; getters must be queried
again after vector growth.

`machine_memory_buffer.v` translates the complete source buffer operations
through actual [LibGC primitive storage](../libgc/PORT_STATUS.md). Handles,
move ownership, capacity, storage offsets, cage-boundary chunking, zero fill,
bulk copy and overlapping move operations use the source algorithms.

`machine_memory.v` translates MemoryInstance creation and growth. Memory32
reserves its full supported capacity plus the source 8 GiB + 64 KiB guarded
span, keeping its base stable. Memory64 uses the source dynamic reservation
growth and retains the pinned 65,536-page implementation cap. Checked page
sizes, limits, initialization growth, callback inhibition and the callback
before type-minimum update follow source order. ABI offsets describe actual V
record members. `machine_memory_store.v` retains stable owned instance pointers
at vector-index addresses and retries failed creation only after collection
through its installed Heap interface. The LibGC collector implementation is
still pending; the interface has no substitute collector.

The machine-foundation stage passed **52/52 files with default GC and 52/52 with
`-gc none`**. Explicit `destroy()` operations release native storage; complete
automatic owner lifetime, roots and active configurations remain open. These
foundations are not yet wired to instruction execution. The WebIDL memory
facade now uses them as described below; its synthetic function/global/table
exports remain open under WA-12.

## Actual memory wrapper storage

`memory.v` and `cache.v` bind each memory to its owning machine Store and actual
vector-index address. Constructor validation preserves the source maximum,
shared-limit and allocation-error order. Memory32 and Memory64 allocations use
the real MemoryInstance, including its declared limits and source growth modes.
Public growth inhibits the native hook and refreshes once; machine growth
refreshes through that hook before updating the type minimum.

Buffer caches key the actual Memory object, so identical addresses in different
Stores cannot alias. Each buffer retains that owner and its PrimitiveStorage
handle. `bytes()` exposes a live size_t span; fixed shared buffers retain their
captured length, and dynamic buffers follow reallocation through the handle.
Nonshared detached buffers expose no bytes. The pinned shared
`toFixedLengthBuffer()` branch returns the existing canonical buffer, including
when it is resizable. Frozen state and detach keys are retained as typed metadata;
they are not yet native JS object operations.

Imported memory exports retain the actual supplied wrapper instead of installing
a foreign Store address into the importing cache. This preserves the existing
typed cross-realm import adapter; full machine linking, active initialization and
the source JS/GC realm graph remain pending. Current memory identity, import,
growth and source-validation checks pass in the complete **53/53-file package
with default GC and 53/53 with `-gc none`**.

## Actual module owner tables and machine tables

`machine_module_instance.v` (`b03dc960`) translates the source ModuleInstance
constructors, owned vectors, ExportInstance address variants and compiled-entry
fields. `resolved_memories()` and `resolved_globals()` cache actual Store-owned
instance pointers in source order; they retain those identities when the Store
pointer vectors grow. A small V record exposes the actual mutable vector headers
because V cannot return a pointer to an array header. The compiled-function-table
population body, source weak/ref-counted module lifetimes and function Store
family remain pending; the compiled-entry record supplies no execution result.

`machine_table.v` (`e925b6cd`) translates TableInstance and the Store table family.
Actual reference vectors retain a defining ModuleInstance anchor per element.
Replacement, clearing, typed-null initialization, the source 1 MiB initial-size
cap, indexed allocation and growth follow `AbstractMachine.{h,cpp}`. The Store
owns table values, so callers re-query after its vector grows. Zero growth returns
before limit checks; successful growth increments the declared minimum and fills
new references and anchors. V vectors use signed-int lengths: unrepresentable
requests fail before narrowing, while other V allocation failures still panic
instead of returning source `try_resize()` failure. The existing WebIDL Table
facade is not yet connected to these records; its reference conversion and
synthetic table exports remain open under WA-12.

These additions pass a clean **55/55-file package suite with default GC and
55/55 with `-gc none`**. The subsequent Table32 binding correction (`17100b35`)
uses the source unsigned-long EnforceRange operation: primitive ToNumber and
fraction truncation precede bounds checks, and output conversion casts to u32.
Its two focused/neighbor files pass in both GC modes. Actual VM ToPrimitive and
the full-width unsigned i64 BigInt binding remain pending.
