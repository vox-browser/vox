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
population body and source weak/ref-counted module lifetimes remain pending;
the later function Store foundation below supplies actual records and addresses,
while the compiled-entry record supplies no execution result.

`machine_table.v` (`e925b6cd`) translates TableInstance and the Store table family.
Actual reference vectors retain a defining ModuleInstance anchor per element.
Replacement, clearing, typed-null initialization, the source 1 MiB initial-size
cap, indexed allocation and growth follow `AbstractMachine.{h,cpp}`. The Store
owns table values, so callers re-query after its vector grows. Zero growth returns
before limit checks; successful growth increments the declared minimum and fills
new references and anchors. V vectors use signed-int lengths: unrepresentable
requests fail before narrowing, while other V allocation failures still panic
instead of returning source `try_resize()` failure. The later WebIDL Table Store slice connects its facade to these records;
synthetic Instance exports, actual function reference branding and full unsigned
address conversion remain separate boundaries under WA-12.

These additions pass a clean **55/55-file package suite with default GC and
55/55 with `-gc none`**. The subsequent Table32 binding correction (`17100b35`)
uses the source unsigned-long EnforceRange operation: primitive ToNumber and
fraction truncation precede bounds checks, and output conversion casts to u32.
Its two focused/neighbor files pass in both GC modes. Actual VM ToPrimitive and
the full-width unsigned i64 BigInt binding remained pending at that slice.

`value_global.v` (`d17cceac`) now follows the source numeric conversion branches:
i32 performs ToNumber and wrapping ToInt32, while f32/f64 perform ToNumber before
narrowing. Primitive strings/booleans/null, fractions, nonfinite values, signed
wrapping and float rounding retain source behavior in globals and host-result
adapters. `webidl.RuntimeValue.number_conversion` (`80fc58b9`) carries actual
owning-engine ToNumber, including the number-hint primitive hook and original
thrown values, independently of the non-coercing number-brand projection used
by Streams. Native BigInt/Symbol rejection, replaced author Number constructors
and closed-owner checks pass. This supplies the native JSC value boundary; it
does not complete LibJS realm/value integration or source function reference
branding. Full-width Table64 conversion is completed in the later slice below. The current complete package
passes a clean **57/57 files in each GC mode**.

## Source i64 binding conversion

`8289f13d` replaces the i64-only brand check with source ToBigInt followed by
the signed low-64-bit projection. Typed booleans and arbitrary-width string
integers share the existing LibJS parser and SignedBigInteger conversion;
invalid strings retain SyntaxError and Number/null/undefined retain TypeError.
Globals and host results use the same operation. Native RuntimeValue retains
an owning-engine conversion, implemented with captured `BigInt.asIntN(64, value)`
so number-hint primitive hooks, original throws, Number/Symbol rejection and
large signed values survive without rounding through Number or author globals.
The primitive string parser is the pinned LibJS translation; the native engine
parser remains JavaScriptCore, so this adapter is not source parser or full
LibJS realm parity. Full unsigned Table64 conversion remained open at that
slice; actual function reference branding remains open. The current complete package passes a clean
**58/58 files in each GC mode**.

## Full unsigned Table64 BigInt binding

`5a3b3e5b` retains the actual arbitrary-precision `libjs.BigInt` record at the
WebIDL primitive boundary and adds full `ToBigInt` independently of the signed
i64 wrapping operation. Typed strings use the source LibJS parser. The compact
engine hook follows source `ToPrimitive(number)` once, preserves original
getters and thrown values, rejects Number, then converts the remaining primitive
cases using the captured JavaScriptCore BigInt intrinsic. Author replacements of
BigInt, Reflect and iterator methods do not change these internal conversions.
The decimal arithmetic ABI projects an actual BigInt primitive in both
directions; it does not substitute a JavaScript string or Number for the result.

`Table.cpp::AddressValueToU64` now checks the complete converted integer's sign
and decimal unsigned-64-bit bound before narrowing. Values through `2^64-1`
are accepted; `2^64` and arbitrarily larger values reject instead of wrapping.
`table_limit_to_js_value` creates a positive arbitrary-precision BigInt record
from u64, preserving the upper unsigned half. The source store binding methods
use these conversions before indexed reads, writes and growth.

Focused full-width typed/native conversion and existing signed-i64 tests pass
**3/3 files with `-gc none`**. Table64 typed/native bounds, existing Table32,
actual store bindings and runtime neighbors pass **5/5 files with `-gc none`**.
Native tests cover actual BigInt output, original exception identity,
number-hint coercion exactly once, and overflow before modulo conversion.
This completes the numeric Table64 boundary; the browser still uses JSC,
and full LibJS realm execution and public native WebAssembly interface exposure
remain separate work.

## Actual Global Store bindings and extern identity

`Global` now retains only its actual owning cache and vector-index Store
address. Construction allocates the source `GlobalInstance`; wrapping an
existing address preserves its type, mutability and value. Machine writes and
binding writes reach the same retained record after Store growth. Type/read
lookup, missing-instance RangeError, V128 checks, const checks and conversion
ordering follow `Global.cpp`. Omitted V128 initialization differs from explicit
undefined as in the source binding. Source raw machine getters/setters remain
separate from the JS value conversion adapter.

Extern conversion uses the owning cache, preserving distinct platform records,
object identity across property changes, actual Promise records and owning
runtime references. Numeric keys distinguish signed zero and canonicalize NaN;
hashing never coerces author objects. A typed dictionary without an actual
opaque object record has no invented identity key: it remains a separate
retained entry. This standalone DTO boundary does not complete LibJS Value cell
hashing, wrapper GC, or native primitive-value interning.

The complete package passes **60/60 files with default GC and 60/60 with
`-gc none`**. Actual non-null exported function branding, function Store/module
lookup, synthetic Instance global/table exports, native WebAssembly wrappers,
instruction execution and the full VM/GC ownership graph remain open. The
later function Store foundation below completes allocation/lookup records,
but not actual exported-function branding. A typed
callback marker is not accepted as a genuine exported function.


## Actual Table Store and Instance address wrapping

`e6ed6d2d` replaces Table's copied value array and pointer-derived address with
its owning Store and vector-index address. Source allocation/fill, actual type
and limits, lookup errors, exnref-before-bounds checks and reference conversion
ordering now reach `TableInstance`. Typed JS binding adapters convert addresses
before references and Store operations. The pinned `Table::grow(u64)` to
`TableInstance::grow(u32)` narrowing is preserved, including a 2^32 delta
becoming zero. Wrappers re-query source value records after Store vector growth.
A clean **61/61-file suite passes with default GC and with `-gc none`**.

`4711dfa7` translates Instance's cache-miss wrapping of an existing Global,
Memory or Table Store address. It no longer allocates a default i32 Global or
empty externref Table under a different address, and a real uncached Memory
gets its source non-shared wrapper and growth hook. Focused Store-address,
invalid-address and memory-detachment regressions pass with their module and
memory neighbors: **3/3 default-GC files**, **2/2 GC-disabled files**.
The legacy Instance instantiation path still fabricates global/table/function
exports rather than executing source module initialization. The completed
wrapper lookup does not close WA-12; function Store/branding and native
WebAssembly/LibJS wrappers remain open. Full unsigned Table64 conversion is
completed above; the current complete package passes **63/63 files with default
GC and 63/63 with `-gc none`**.

## Actual function Store foundation

`74a1e9c5` translates `WasmFunction`, `HostFunction`, their actual Store
variant vector, both allocation branches, checked/unchecked lookup and module
lookup from `AbstractMachine.{h,cpp}`. Wasm records retain the actual code
section entry, module instance, module and canonical type. Host allocation
interns its source function type only when no defined type is supplied. Store
addresses are vector indices; getters must be queried again after vector growth.
The source name helper uses the host import index or the first matching index
in the module's function vector, including imported functions, rather than an
export label or Store address.

The new source-record cases plus module/global ownership neighbors pass
**3/3 files with default GC and 3/3 with `-gc none`**. The host callable now takes the actual mutable Configuration described below.
The Store foundation still does not supply instruction execution. V currently retains module/code pointer aliases rather than
the source weak/ref-counted lifetime graph, so weak expiration and strong module
promotion remain open. The legacy Instance initialization and exported-function
facades are not yet connected to these actual function records; this foundation
does not establish Wasm execution or close WA-12.

## Source label and frame records

`42417969` translates the complete `Label` and `Frame` classes from
`AbstractMachine.h:887–966`. Labels retain source arity, continuation, stack
height and the actual optional try-table instruction pointer. Frames retain
the actual module instance, locals pointer, expression, result arity, label
index, owns-locals flag and compiled-function-vector header pointer. The source
move constructor copies those fields without clearing the moved-from frame or
freeing locals. A small V owner record supplies the source vector-header pointer
that V arrays cannot expose directly; growing its entries preserves that owner.

Source alias and control-flow tests plus the function/module owner neighbors
pass **3/3 files with default GC and 3/3 with `-gc none`**. The borrowed locals
pointer follows the source contract: Configuration must rederive it when its
own locals storage moves. V does not enforce the C++ deleted copy operations.
The Configuration ownership and call-record allocation foundations are now
translated below. Compiled-function-table construction and interpreter execution
remain open; the frame records do not supply an executor.

## Source import records and linker

`2e24843c` retains the complete source `ImportSection::Import::ImportDesc`
variant and one original-order machine import list alongside the public API's
separate tag-omitting list. Interleaved tags retain their actual position and
function/table/memory/global/tag descriptors. `9f8f43bd` restores those records
when deserializing a Module's actual source bytes. The parser case passes with
both GC modes; restored-module and existing Module neighbors also pass in both.

`9c15159a` translates every `Linker` method from pinned
`AbstractMachine.cpp:1209–1292` and its `Name` traits. Module linking ignores
the qualifier and chooses the first matching export. Qualified linking uses
module/name equality and deliberately ignores the description, as source does.
The final vector follows original import order, including duplicate names and
tags, and preserves actual typed Store addresses. A V string-key adapter encodes
the module byte length to preserve both ByteStrings without ambiguous boundaries
or embedded-NUL collisions; it does not add type checking to the source linker.

Five source cases pass in each GC mode, including an actual binary module and
real Memory/Tag/HostFunction Store allocations, first-export selection, empty
linking, repeated linking and independent returned error copies. The pinned
source appends missing names again on repeated failed `finish()` and retains the
error after imports are later resolved; those behaviors are preserved. The
complete current package passes **67/67 files with default GC and 67/67 with
`-gc none`**, recorded in `source-linker-full-wasm-{default,gc-none}.log` under
`Build/audit-fixes/`.

This source linker resolves existing addresses. The legacy browser Instance
initialization is not yet routed through source `AbstractMachine::instantiate`;
Configuration and compiled-instruction records are now translated below.
Constant-expression execution, native compilation, interpreter invocation and
the full lifetime/root graph remain open. No fabricated machine execution or export result is supplied by this slice.


## Instruction storage and optional expression hints

`681b49d4` translates Source InstructionStorage's actual stable chunk slots,
empty-opcode sentinel, indexed access, allocation sequence and move behavior.
`e92e01ed` preserves the optional expression stack hint: absent metadata stays
distinct from a validated zero, parser allocation hints retain their source
width, successful validation publishes the peak, and failure leaves the prior
optional value. The complete optional-hint snapshot passes **69/69 files in each
GC mode**. See [storage mapping](../docs/translation-audit/WASM_INSTRUCTION_STORAGE.md).

## Actual compiled records and Configuration foundations

`2c0fbf21` translates CompiledInstructions fields and native unions, register
markers, actual Instruction pointers, trap records, owned auxiliary storage,
code entry metadata and source atomic acquire/release publication. A native
reader checks publication of real metadata; it does not execute a fabricated
compiled function. See [record mapping](../docs/translation-audit/WASM_COMPILED_INSTRUCTIONS.md).

`eb880f08` constructs the actual Configuration with its two existing native
ValueStacks, registers, frame/label/locals/freelist vectors and owning Store.
The exact pointer is registered and explicitly unregistered on destruction.
Source operand modes borrow actual register/call-record/stack slots; taking a
stack operand pops one value. Call records allocate from the actual second
stack. Reset preserves source capacity, scan slack, instruction-count limit and
Store registration while clearing the source-owned state. HostFunction callbacks
receive this actual mutable record. The seven field-offset methods describe
the V record consumed by future native compilation paths.

Four focused cases cover owner identity/destruction/region reuse, all operand
modes and mutable aliases, reset behavior, and real field-offset consumers.
The complete Configuration snapshot passes **71/71 files with GC disabled** in
its isolated worktree and **71/71 files with default GC** in the canonical
checkout (`source-configuration-full-canonical-default-recheck.log`).

Frame installation, argument-allocation reuse, unwind/CallFrameHandle,
prepare/call/execute functions, module compilation coordination, compiled-function
tables and complete collector roots were open at this Configuration snapshot;
the subsequent completed records are listed below. Explicit V destruction and
heap-vector storage are documented adaptations; C++ automatic ownership,
noncopyability and inline-vector layout are not implied. No complete Wasm
execution, source instantiation or browser realm parity is claimed.

## Compilation coordination, compiled tables and call preparation

`c22bd999` translates Module compilation coordination with a construction-owned
state and native mutex/condition adapter. `34fd14b4` retains CodeSection::Func's
constructor-cached total local count, including source-width sums. `f6e43133`
builds the actual ModuleInstance compiled-function table from Store records,
retains publication metadata and rebuilds until all source Modules have
attempted native compilation. The canonical snapshot passes **74/74 files in
each GC mode**.

`48b3ce4a` translates actual inline argument ownership and source freelist reuse.
`3f686bf8` installs owned and lightweight frames, resolves actual module/Store
tables, preserves label and call-record ordering, restores relocated caller
locals and translates the call handle's unwind. `6353f74d` prepares actual
HostFunction/Wasm Store records, source-typed zero locals and inlined locals,
including tail replacement and the source no-wait compilation policy. Invalid
addresses retain an actual Trap. The completed snapshot passes **77/77 files
in each GC mode** in its isolated worktree; four merged canonical argument,
frame, preparation and Configuration files pass with GC disabled in the
22-file integration batch.

See [source mapping and validation](../docs/translation-audit/WASM_COMPILATION_AND_FRAMES.md)
for explicit V destruction, vector layout, system-allocator capacity and native
synchronization boundaries. Constant-expression execution, native instruction
compilation, complete AbstractMachine instantiation and the
collector/ref-counted root graph remain unfinished. The browser's legacy
Instance facade is still not routed through that complete machine pipeline.

## Source host calls, interpreter invocation and bytecode state

`d513a2d3` passes the actual writable argument span to retained HostFunction
callbacks. It removes the copied-array adapter and invokes the stored callable
directly, preserving captured owners across repeated calls in both GC modes.
`1abb2982` translates the Source Interpreter interface and Configuration
call/execute/compiled-call branches: preparation traps, host versus Wasm routing,
instruction-pointer reset, actual result copying/reversal and label cleanup.
Focused recording interpreters are explicit test doubles; they supply no
production opcode implementation.

`09de70ed` restores AK/StackInfo's exact unsigned frame-address subtraction.
`9ec83ed2` translates BytecodeInterpreter's owned trap variant, actual external
resource visitation and native-stack guard using that retained StackInfo owner.
The visitor receives and can mutate the actual stored external payload; the
guard retains the Source two-MiB default and `STACK-EXHAUSTION` reason.

The integrated bytecode-state snapshot passes **80/80 canonical files in each GC mode**:
`Build/audit-fixes/source-bytecode-state-full-{canonical-default,canonical-gc-none}.log`.
See [host calls and invocation](../docs/translation-audit/WASM_HOST_CALL_AND_EXECUTION.md)
and [bytecode state and stack calculation](../docs/translation-audit/WASM_BYTECODE_STATE_AND_STACK.md).
BytecodeInterpreter still has no production `interpret()` method. Full opcode
dispatch, constant-expression execution, native compilation/fault recovery,
complete machine instantiation and collector roots remain open.

## Source scalar integer operators

`b5ae85be` translates Source Divide/Modulo integer specializations and unsigned
rotations at both scalar widths. Concrete V functions preserve AK::Checked's
signed-minimum/minus-one and zero-divisor gates, the exact error reason,
Modulo's deliberate signed-minus-one zero, and Source rotation masks/shifts.
The focused test checks **3,264 exact C++ results** generated by `62552980`
from the four verbatim pinned Source operator records and actual AK headers.
It passes both GC modes privately and canonical default GC; canonical
integration proof is recorded in the audit ledger. The earlier 80-file full
sweep predates the new integer test and subsequent numeric-helper test. Other
scalar/SIMD operators and complete opcode dispatch remain untranslated.
See [source mapping and oracle boundaries](../docs/translation-audit/WASM_INTEGER_OPERATORS.md).


## Source numeric operand and trap helpers

`9a9aaf30` translates Source `binary_numeric_operation` and `unary_operation`.
They use actual compiled operand mappings and Configuration slots: consume
RHS before borrowing LHS, preserve LHS on errors, write successful results to
the actual input slot, and retain Source trap reasons and return values.
Concrete Value callbacks adapt C++ operator/type templates; no instruction
execution loop is added. Four source-order regressions pass privately in
both GC modes, and the helper plus 3,264-case integer oracle pass **2/2**
canonically with GC disabled. That numeric-helper snapshot has **82** test files; the
preceding clean full 80-file sweeps predate these two new files. Enabled
Source operator-name tracing, remaining operators, opcode dispatch and the
production machine/collector boundaries above remain open.
See [numeric helper source mapping](../docs/translation-audit/WASM_NUMERIC_OPERATIONS.md).


## Source unary integer operators

`7d0af709` translates EqualsZero, CountLeadingZeros, CountTrailingZeros and
PopCount with exact unsigned conversion, zero guards, result widths and
AK builtin-selection branches. All ten scalar specializations match **1,656
exact pinned C++ cases** produced by the separate `bd231130` tooling update.
Actual unary helper tests verify i64 count and i32 predicate Value writes.
Default and GC-disabled private checks pass; canonical unary/helper/native
Blob-global checks pass **3/3** with GC disabled. The package now has **83**
test files; the earlier full 80-file sweeps predate these added slices.
Remaining scalar/SIMD coverage and the production opcode/instantiation/root
boundaries remain open. See [unary source mapping](../docs/translation-audit/WASM_UNARY_INTEGER_OPERATORS.md).


The frozen assignment-9 `f28d34eb` snapshot passes a clean **83/83 files with
default GC and 83/83 with GC disabled**. Logs are
`Build/audit-fixes/source-numeric-operators-full-private-{default,gc-none}.log`
in that private worktree, alongside its exact manifest and snapshot hash.
Canonical WebAssembly implementation and tests match that snapshot byte-for-byte;
At integration, canonical LibJS additionally exposed the unchanged
`to_well_formed` function. Later canonical LibJS adds the Source string
Reference fast path (`bfc616a2`); the frozen Wasm sweep predates that change.
These are private full-suite results and canonical focused integration results,
not a claimed canonical full-suite run or complete interpreter/runtime parity.

## Source scalar shifts

`1897fa01` translates the six i32/i64 scalar BitShiftLeft/BitShiftRight
specializations with Source argument types and unsigned count promotion.
All six match **5,760 exact native C++ cases** from `0e4a83df`, including
negative signed counts, every bit position and wrap boundaries. Actual
Configuration writes retain Source i32/i64 PushType results and clear high
bits. The new file passes default GC privately; operator/helper neighbors
pass **3/3** privately and canonically with GC disabled. The package has
84 test files at that shift snapshot; the preceding clean 83-file private sweep predates this file.
Production dispatch and remaining scalar/SIMD execution are still pending.
See [Source shift mapping](../docs/translation-audit/WASM_SCALAR_SHIFTS.md).

## Source integer comparisons

`38052bee` translates twenty scalar comparison specializations from the six
Source binary macro records. All match **2,880 exact native C++ cases** from
`eae0d685`, preserving signed/unsigned PopType and i32 PushType behavior.
Actual Configuration regressions verify signedness, cleared result high bits
and retained trap/source/destination state. The file passes default GC
privately and canonically; comparison/shift/helper files pass **3/3** privately
and canonically with GC disabled. That comparison snapshot has 85 test files; no full
85-file sweep is claimed. The later floating comparison slice is recorded
below; SIMD comparisons and production dispatch remain untranslated.
See [Source mapping](../docs/translation-audit/WASM_INTEGER_COMPARISONS.md).

## Source wrapping arithmetic and bitwise operators

`54308045` translates twelve concrete scalar Add/Subtract/Multiply and
BitAnd/BitOr/BitXor functions using Source unsigned arithmetic and signed
bitwise operand types. All match **1,728 exact native C++ cases** from
`8eca94c1`; actual numeric-helper regressions verify signed PushType writes,
wrapping and cleared high bits. The new file passes default GC privately;
arithmetic/comparison/helper files pass **3/3** privately and canonically
with GC disabled. That arithmetic snapshot has 86 test files, without a full
86-file sweep claim. Production dispatch and remaining floating/SIMD operations
remain pending.
See [Source arithmetic mapping](../docs/translation-audit/WASM_INTEGER_ARITHMETIC.md).

## Source scalar floating comparisons

`a1cf813d` translates twelve float/double comparison specializations from the
six Source macro records. All match **3,072 exact native C++ cases** from
`606791b9`, retaining NaN, signed-zero, infinity and subnormal behavior.
Actual numeric-helper regressions write Source i32 results and preserve
operand/trap state. Default GC passes privately; floating/integer comparison
and helper files pass **3/3** privately and canonically with GC disabled.
The package now has 87 test files, without a full 87-file sweep claim.
Remaining scalar/SIMD operators, production opcode dispatch, instantiation and
collector/realm ownership remain open.
See [Source comparison mapping](../docs/translation-audit/WASM_FLOAT_COMPARISONS.md).

## Source scalar floating arithmetic

`aa474918` translates eight float/double Add/Subtract/Multiply/Divide
specializations, matching **2,048 exact native C++ result-bit cases** from
`5ab129c2`. Actual Configuration/helper checks preserve floating zero-divisor
behavior, result widths and slot/trap ordering. Default GC passes privately;
arithmetic/comparison/helper files pass **3/3** privately and canonically with
GC disabled. This arithmetic snapshot has 88 test files.
See [Source arithmetic mapping](../docs/translation-audit/WASM_FLOAT_ARITHMETIC.md).

## Source scalar floating extrema and sign copying

`b10f59ce` translates six float/double Minimum/Maximum/CopySign specializations,
matching **1,536 exact native C++ result-bit cases** from `ebe9af38`. Source
canonical NaN, signed-zero branches and width-specific libm calls retain their
exact bits. Default GC passes privately; extrema/arithmetic/helper files pass
**3/3** privately and canonically with GC disabled. The package now has 89 test
files. The frozen full-suite evidence below is scoped to that private snapshot;
remaining scalar/SIMD operators, production opcode dispatch, instantiation and
collector/realm ownership remain open.
See [Source extrema mapping](../docs/translation-audit/WASM_FLOAT_EXTREMA.md).


The frozen assignment-9 `e1f41d8e` snapshot passes a fresh clean **89/89 files
in each GC mode**. Logs, exact manifest, snapshot hash and exit codes use
`source-floating-extrema-full-private-` under its private `Build/audit-fixes/`.
Canonical WebAssembly implementation/tests match byte-for-byte; dependencies
outside that package remain the private snapshot. This sweep predates the
new explicit LibJS UTF8 byte-boundary helper (`68deba04`). Canonical focused
arithmetic/extrema/helper checks pass separately. These results do not supply
an opcode interpreter, instantiation or complete collector/realm graph.

## Source scalar floating unary operators

`ab928857` translates fourteen float/double Absolute/Negate/Ceil/Floor/Truncate/NearbyIntegral/SquareRoot specializations, matching **1,568 exact pinned C++ result-bit cases across four native rounding modes** from `32893ab4`. Source NaN branches, compiler fabs builtins, original operand widths and native math calls are retained. Real unary-helper checks preserve selected slot writes, Source float-bit sign extension, destination/stack and earlier trap state. Focused default GC passes privately; the canonical unary/extrema/helper and FileReader BOM integration batch passes **6/6 with GC disabled**. See [Source unary mapping](../docs/translation-audit/WASM_FLOAT_UNARY.md).

The frozen isolated checkout of canonical `bbb7d72944f17772af8f1096bcb3225f4b3d8f88` passes a fresh clean **90/90 WebAssembly files in each GC mode**, with no tracked changes during either sweep. It includes the explicit Source LibJS byte helper. Exact manifest/commands/result and log hashes are in `Build/audit-fixes/worktrees/09-compiled-records/Build/audit-fixes/source-unary-wasm90-manifest.json`; logs use `source-unary-wasm90-full-{default,gc-none}.log`. Package/LibJS implementations and tests matched at recording. The subsequent float/integer width files and later changes outside those packages remain outside this snapshot. Remaining numeric/SIMD operators, production opcode dispatch, execution/instantiation and full collector/realm roots remain open.


`b191a456` adds the exact Source Promote/Demote bodies with 272 pinned C++ result-bit cases across all four native rounding modes. `cd93fa2f` adds eight Wrap/Extend/SignExtend scalar forms with 3,216 exact pinned C++ result-bit cases. Their focused canonical integration and the actual numeric helpers pass **3/3 with GC disabled** (`source-integer-floating-width-canonical-gc-none.log`). Each new file also passes default GC privately; integer-width tooling reproduces its fixture byte-for-byte. See [float width](../docs/translation-audit/WASM_FLOAT_WIDTH.md) and [integer width](../docs/translation-audit/WASM_INTEGER_WIDTH.md). These two new test files are outside the historical 90-file sweep; no complete production opcode/instantiation/root parity is inferred.


`2a00c71d` translates four Source scalar reinterpret forms with 576 exact native bit patterns; `e2f5d37c` translates eight integer-to-float forms with 8,512 exact native cases across all four rounding modes. Their actual helper regressions preserve original interpretation, result representation and selected slots without changing destination/stack/prior traps. Both new files pass default GC privately and canonical GC-disabled integration in the eight-file pixel/destroyed/bitcast/cast batch. See [reinterpret](../docs/translation-audit/WASM_SCALAR_REINTERPRET.md) and [casts](../docs/translation-audit/WASM_INTEGER_FLOAT_CONVERT.md). A fresh isolated canonical `e86c54a7` snapshot passes **94/94 in each GC mode**; package/LibJS files stay byte-identical and match canonical at recording. Outside dependencies and later changes are scoped to that snapshot. See [manifest/log evidence](../docs/translation-audit/WASM_SCALAR_VERIFICATION.md).
