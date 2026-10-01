# LibJS V translation status

Audited: 2026-10-02.

The frontend baseline comes from `medvednikov/libjs_v` commit
`9824cc3fad0910215f0f4de43fb108bb7575f6c7` (2026-02-24). The upstream reference is
`~/code/3rd/ladybird/Libraries/LibJS` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11): its Rust parser, lexer,
AST, and scope collector for the frontend, and its C++ `Runtime/VM.{h,cpp}`,
`Interpreter/Interpreter.cpp` VM members, and runtime records for the VM slice.
The execution slice additionally follows `Rust/src/bytecode/{operand,generator,codegen}.rs`,
`Interpreter/{interpreter.flap,SlowPaths.cpp}`, `Script.cpp`,
`Runtime/{Value,GlobalObject,BigInt,BigIntConstructor,BigIntPrototype,NativeFunction,FunctionObject,BoundFunction,FunctionPrototype,BooleanObject,BooleanPrototype,BooleanConstructor,SymbolObject,SymbolPrototype,SymbolConstructor,StringObject,NumberObject,BigIntObject,Iterator,StringIterator,StringIteratorPrototype,ArrayIterator,ArrayIteratorPrototype,ByteLength,ArrayBuffer,ArrayBufferConstructor,ArrayBufferPrototype,DataView,DataViewConstructor,DataViewPrototype,SharedArrayBufferConstructor,SharedArrayBufferPrototype,CanonicalIndex,TypedArray,TypedArrayPrototype,Intrinsics,Array,ArrayPrototype,IndexedProperties,PropertyKey,Object,ObjectPrototype,ReflectObject,PrimitiveString,Accessor,PropertyDescriptor,AbstractOperations}`
source bodies and `Runtime/ValueInlines.h`, numeric/URI/Annex B global functions
from `Runtime/GlobalObject.cpp`,
`AK/StringConversions.cpp` and fast_float decimal-prefix parsing, and the BigInt
operations delegated to LibCrypto/LibTomMath.
All refreshed V code and tests live here; the upstream checkout and the original
`libjs_v` checkout are references. The upstream BSD-2-Clause notice is retained
in [`LICENSE`](LICENSE).

## Implemented boundary

`parse_source(source, .script)` and `parse_source(source, .module)` retain a
heap-owned program and function table, return positioned syntax diagnostics,
and expose strict-mode and top-level-await state. `dump_ast()` serializes a
successfully parsed and scope-analyzed source. Error-bearing programs cannot
be dumped through this API. `reached_recursion_limit` distinguishes the V
frontend's stack budget from grammar errors, and `utf16()` exposes the same
code-unit conversion to the embedding backend.

`VM.create()` builds the agent-level VM record: pre-allocated strings and
well-known symbols, the execution context stack with inline-frame walking, the
interpreter stack, saved stacks, the type-error realm override, throw
completions carrying `Error` objects with tracebacks, promise and
finalization-registry job queues, host hooks with upstream defaults, the native
function table, binding resolution through environment records, and the
file-backed default `HostLoadImportedModule`. `initialize_host_defined_realm()`
creates a realm with a global environment and pushes its execution context.

| V implementation | Upstream responsibility |
| --- | --- |
| `lexer.v`, `token.v`, `unicode_properties.c.v` | UTF-16 lexing, token classification, ICU identifier properties |
| `parser.v`, `expressions.v`, `declarations.v`, `statements.v` | Script/module grammar and parser early errors |
| `scope_collector.v` | Binding resolution, local indices, captures, eval poisoning, declaration metadata |
| `ast.v`, `ast_dump.v`, `utf16_utils.v` | Retained syntax trees, function ownership, UTF-16 identity, AST serialization |
| `frontend.v` | Public source parsing and diagnostic boundary |
| `vm.v` | `Runtime/VM.{h,cpp}`: VM record, execution context stack, throw completions, jobs, host hooks, native function table, module loader bookkeeping; `Interpreter.cpp` exception unwinding and identifier lookup |
| `execution_context.v`, `interpreter_stack.v`, `stack_info.v`, `stack_info_{darwin,linux}.c.v` | Execution context records and value layout, the 8 MiB interpreter stack allocator, native stack bounds |
| `environment.v`, `declarative_environment.v`, `function_environment.v`, `object_environment.v`, `global_environment.v`, `private_environment.v`, `reference.v` | Environment records, GetThisEnvironment, private names, Reference records with GetValue/PutValue/delete |
| `value.v`, `completion.v`, `primitive_string.v`, `symbol.v`, `object.v` | Tagged values, completion records, VM string caches, symbols, ordinary objects with data/accessor properties and `PropertyName` keys |
| `accessor.v`, `property_descriptor.v`, `object_accessors.v`, `object_property_definitions.v` | Accessor cells, descriptor completion/conversion/validation, native and cached accessors, engine-private property storage, bulk definitions after ToObject |
| `error_object.v`, `error_types.v` | Error objects with `[[ErrorData]]` tracebacks and stack strings; the 226-entry `ErrorType` message table |
| `realm.v`, `script.v`, `module_records.v`, `promise.v`, `function_object.v`, `executable.v` | Realm and Script records, standard global value properties, `Module` records and loading payloads, promise state, job callbacks, executable metadata (handler ranges, source map, identifier table) |
| `value_operations.v`, `value_coercion.v`, `big_int.v` | Numeric operations, BigInt cells and conversions, signed bitwise operations, exact mixed numeric comparisons, UTF-16 concatenation, ToPrimitive/OrdinaryToPrimitive and property-key conversion |
| `bigint_width.v`, `bigint_constructor.v` | BigInt constructor record, number-hint call/throwing construction, asIntN/asUintN and translated width arithmetic helpers |
| `bigint_prototype_methods.v`, `bigint_locale.v`, `bigint_prototype.v` | BigInt brand/radix/valueOf bodies, locale-call plumbing with explicit Intl dependencies, and complete prototype initialization |
| `value_indices.v`, `array_like.v`, `instanceof.v` | ToIntegerOrInfinity/ToLength/ToIndex, LengthOfArrayLike/CreateListFromArrayLike, OrdinaryHasInstance and InstanceofOperator |
| `object_coercible.v`, `immutable_prototype.v`, `object_prototype_methods.v`, `object_prototype_accessors.v`, `object_prototype_proto.v` | RequireObjectCoercible, SetImmutablePrototype and eleven ObjectPrototype native bodies with explicit primitive dependencies; ObjectPrototype initialization and toString remain pending |
| `reflect_properties.v`, `reflect_prototypes.v`, `reflect_calls.v`, `reflect_own_keys.v`, `reflect_object.v` | All thirteen Reflect native bodies and complete initialization, PropertyKey-to-Value conversion, explicit Object/Array intrinsic dependencies |
| `value_integer_conversions.v` | ToInt8/ToUint8/ToInt16/ToUint16 and ties-to-even ToUint8Clamp |
| `native_function.v` | Capturing/raw native callable objects, function metadata, native table dispatch and callee execution contexts |
| `construct.v`, `constructor_prototype.v` | Native construction contexts, IsConstructor, GetFunctionRealm, and GetPrototypeFromConstructor |
| `bound_function.v`, `function_prototype.v`, `restricted_function_properties.v` | Bound callable records and argument forwarding, Function prototype methods, the shared %ThrowTypeError% and restricted caller/arguments accessors |
| `array_object.v`, `array_sort.v` | Array exotic records and length/property operations, CreateArrayFromList, indexed-value collection, stable merge sorting, and CompareArrayElements |
| `boolean_object.v`, `boolean_prototype.v`, `boolean_constructor.v` | Boolean internal slots, prototype methods, calls and construction, intrinsic links, and primitive references |
| `symbol_object.v`, `symbol_prototype.v`, `symbol_constructor.v` | Symbol wrappers, prototype methods and description accessor, unique/global symbol creation, registry methods, static well-known symbols, and primitive references |
| `string_object.v` | StringCreate, virtual UTF-16 character descriptors, definition compatibility, and exotic own-key ordering |
| `number_object.v`, `bigint_object.v`, `value_boxing.v` | NumberData/BigIntData wrapper records and all primitive ToObject cases with explicit Number/BigInt/String prototype dependencies |
| `value_property_access.v` | GetV's direct primitive-prototype lookup, GetMethod's nullish/callable checks and Invoke with the original primitive receiver and explicit intrinsic dependencies |
| `iterator.v`, `iterator_values.v` | Synchronous iterator acquisition for object receivers, IteratorNext/Step/StepValue, completion-preserving close/close-all, result records, list/callback collection, and SetterThatIgnoresPrototypeProperties |
| `string_iterator.v`, `string_iterator_prototype.v`, `array_iterator.v`, `array_iterator_prototype.v` | String code-point iteration, ordinary array-like and TypedArray key/value/entry iteration, and branded native next methods with explicit intrinsic dependencies |
| `byte_length.v`, `data_block.v`, `array_buffer_object.v` | Tagged numeric/auto/detached lengths, owned and fixed-length host byte storage, copy/move/resize, ArrayBuffer records and detach ownership |
| `species_constructor.v`, `array_buffer_operations.v`, `array_buffer_constructor.v`, `array_buffer_prototype.v` | SpeciesConstructor, ArrayBuffer allocation/cloning/transfer and maximum options, constructor/intrinsic links, branded accessors, resize and slice |
| `buffer_numeric.v`, `float16.c.v`, `float16.h` | Raw/numeric element conversion, buffer get/set/modify operations, byte order and the native binary16 representation boundary |
| `data_view.v`, `data_view_constructor.v`, `data_view_prototype.v` | Retained DataView records and witnesses, fixed/tracking lengths, construction, three property accessors and all 22 numeric methods |
| `shared_data_block.v`, `shared_array_buffer_operations.v` | CreateSharedByteDataBlock and AllocateSharedArrayBuffer, reserved maximum capacity and current length |
| `shared_array_buffer_constructor.v`, `shared_array_buffer_prototype.v` | SharedArrayBuffer construction, species, three accessors, host growth dispatch, byte-preserving growth and species-aware slicing |
| `canonical_index.v` | CanonicalIndex records, checked double conversion and CanonicalNumericIndexString with both round-trip modes |
| `typed_array.v`, `typed_array_initialization.v` | All twelve concrete element records, buffer witnesses, integer-indexed exotic methods, numeric get/set/modify dispatch, validation, allocation and buffer/TypedArray/list/array-like initialization |
| `typed_array_construction.v`, `typed_array_create.v`, `typed_array_compare.v` | Concrete constructor behavior with explicit intrinsic dependencies, TypedArrayCreate result validation and CompareTypedArrayElements |
| `typed_array_receiver.v`, `typed_array_access.v`, `typed_array_search.v`, `typed_array_order.v` | TypedArray receiver conversion, four branded accessors, at, @@toStringTag, includes/indexOf/lastIndexOf, reverse and sort with explicit primitive dependencies |
| `typed_array_callbacks.v`, `typed_array_find.v`, `typed_array_reduce.v`, `typed_array_iterators.v` | every/some/forEach, FindViaPredicate and four predicate searches, reduce/reduceRight and entries/keys/values with explicit iterator dependencies |
| `typed_array_copy_within.v`, `typed_array_fill.v`, `typed_array_join.v` | Bit-preserving overlapping copies, numeric fill with chunked integer writes, and UTF-16 join with live element reads |
| `typed_array_same_type.v`, `typed_array_copying.v` | TypedArrayCreateSameType with explicit intrinsic lookup, toReversed/toSorted/with and independent result storage |
| `typed_array_species.v` | Concrete default allocation/view factories and TypedArraySpeciesCreate's default-constructor fast path |
| `typed_array_transform.v`, `typed_array_slice.v`, `typed_array_subarray.v` | Species-aware filter/map, bit-preserving slice and fixed/tracking subarray views |
| `typed_array_set.v`, `typed_array_locale.v` | TypedArray/array-like set paths, encoding dispatch, and toLocaleString iteration with explicit Number/BigInt locale dependencies |
| `typed_array_constructor.v` | Abstract TypedArray constructor, from/of/species and exact constructor metadata with explicit prototype dependencies |
| `array_to_string.v`, `typed_array_prototype.v` | Shared Array/TypedArray toString body and full TypedArray prototype initialization, function metadata and values/@@iterator alias |
| `options_object.v` | GetOptionsObject's fresh null-prototype defaults, unchanged object receivers and primitive rejection |
| `uint8_array_bytes.v`, `uint8_array_hex.v`, `uint8_array_base64.v`, `base64_codec.v` | Uint8Array brand/byte operations, all six hex/base64 native bodies and the pinned simdutf codec control flow |
| `concrete_typed_array.v`, `uint8_array_helpers.v` | All twelve concrete constructor/prototype records, BYTES_PER_ELEMENT, inherited shared statics and Uint8Array helper initialization |
| `string_length.v` | Upstream maximum string length and checked sum/product operations |
| `global_numeric_functions.v`, `global_uri_functions.v`, `global_legacy_functions.v` | isFinite/isNaN/parseInt/parseFloat, URI encoding/decoding, and Annex B escape/unescape global functions |
| `operand.v`, `instruction.v`, `interpreter.v` | Operand encoding, checked instruction/value layouts, V dispatch loop, bindings, branches, exception dispatch and instruction budgets |
| `bytecode_generator.v`, `script_evaluation.v` | Supported expression/statement code generation, cached executables, global declaration instantiation and ScriptEvaluation |

The 149 implementation files contain **27,563 physical V LOC**. The 155 test
files contain **20,251 physical V LOC** and **563 test functions**. Physical LOC
includes comments and blank lines. This package is counted separately from the
78-package LibWeb inventory.

## Completed refresh slices

### Frontend

- Validate duplicates against the complete parameter list, reject duplicate
  method parameters, and validate inherited strict-mode destructured bindings
  (`77bf4206544`, `8a64784d467`).
- Reject unconditional reserved-word labels and correctly recognize HTML close
  comments after whitespace crossing a newline (`72876d8b934`, `bac7b46688c`).
- Guard expression, statement, and binding-pattern recursion, unwind the depth
  counter, and isolate legacy-octal tracking to each directive prologue
  (`b997605bdb6`, `6ee59d8bcbd`).
- Preserve supplementary characters, UTF-16 offsets, and distinct internal
  string identities; use the upstream ICU identifier predicates instead of
  Unicode-block approximations. Function-scope metadata decodes names back to
  UTF-16 rather than treating UTF-8 bytes as code units.
- Retain heap-owned AST children and stable function-table entries. Tagged
  template chains snapshot their tag instead of creating a self-reference.
- Use natural token positions for property keys, members, and destructured
  names, including lexer restarts during assignment-pattern refinement
  (`30394ece8d3`).
- Allocate local indices in first-reference order, preserve declaration kinds
  on destructured bindings and their uses, and consume literal property keys
  without suppressing `arguments`/`eval` checks inside computed expressions
  (`cec0be6f3dd`).
- Serialize shortest numeric digits with ECMAScript decimal/exponent thresholds,
  including oversized integer literals, nonfinite values, and subnormals.
- Reject grouped nested assignment patterns and retain grouping metadata on
  assignment targets for later named evaluation (`c23b9443403`, `62ac3040998`).
- Preserve no-In grammar in yield operands and concise arrow bodies, reject
  generator expressions named `yield`, and keep sloppy generator declarations
  working (`b42aa88189f`, `e0ee0990cf9`).
- Isolate await grammar at class function and field boundaries, reject ungrouped
  arrows in class heritage, and apply unary-expression exponentiation errors
  to await (`99596d68ab6`, `a598e09f223`, `45bd4087c4d`).
- Accept grouped dynamic imports as `new` callees; require `of` in for-await
  heads and apply the contextual `async` exclusion only to ordinary for-of
  (`8b64f0079b2`, `6c7e642b675`, `99d3b27b17c`).
- Allow sloppy labelled normal functions, reject their lexical conflicts,
  include them in declaration initialization metadata with the last duplicate
  winning, and mark labelled block functions for Annex B hoisting
  (`6c2487cc9c3`, `eeda29d9ed6`).
- Inherit `new.target` validity through arrows while ordinary functions and
  methods establish their own boundary; isolate `super` permissions in nested
  ordinary functions (`66dbb355fe9`, `04b27429de2`).

### VM record

- Execution context stack: base pushes record the previous running context so
  the top-to-bottom walk interleaves inline `caller_frame` chains with base
  pushes exactly as upstream; `previous_execution_context()`,
  `last_execution_context_matching()`, `get_active_script_or_module()`, and
  save/clear/restore of whole stacks (including the type-error realm override)
  follow `VM.cpp`.
- Execution contexts keep the `[registers | locals | constants | arguments]`
  layout, reserved-register initialization, size-class tail rounding, `copy()`
  semantics for uninitialized frames, and root reporting that distinguishes
  frames before and after `Enter`. The interpreter stack is a bump allocator
  with frame ids, marks, and the upstream 8 MiB budget.
- `push_execution_context_checked()` enforces the 32 KiB native stack reserve
  through `StackInfo`, which mirrors `AK/StackInfo.cpp` on macOS (main-thread
  size from `getrlimit`) and Linux (`pthread_getattr_np`).
- Throw completions create `Error` objects in the current realm, or in the
  `TypeErrorRealmScope` override only at the stack depth the scope was created
  at, and capture the execution-context traceback used by
  `ErrorData::stack_string()` including compact repetition folding.
- `resolve_binding()`/`get_identifier_reference()` return Reference records with
  environment coordinates (suppressed in eval-poisoned environments),
  `resolve_this_binding()`, `get_new_target()`, `get_global_object()`, and the
  memoized `get_import_meta()` with host property hooks.
- Declarative, function, object, global, and private environments implement the
  spec algorithms, including `with` unscopables, strict-mode ReferenceErrors,
  const assignment TypeErrors, restricted global properties, and eval poisoning
  that stops at function and global boundaries.
- Promise jobs run FIFO with ignored results; finalization-registry cleanup runs
  LIFO and re-queues a failed registry that still has empty cells; promise
  rejection reaches `on_promise_unhandled_rejection` /
  `on_promise_rejection_handled`; the native function table deduplicates by
  pointer and type.
- `handle_exception()` installs handler offsets, unwinds inline frames off the
  interpreter stack while retrying with the caller's call-site PC, and stores the
  exception register on exit; `unwind_inline_frame_for_exception()` matches.
- The default `HostLoadImportedModule` gates dynamic imports, reads the `type`
  attribute, resolves specifiers relative to the referrer (or the active script
  for realm referrers) with `LexicalPath` semantics and `.js`/`.mjs`/`.json` and
  `index.*` probing, reuses stored modules, reports missing files and syntax
  errors as `SyntaxError` completions, parses source text modules through the
  translated frontend, and records `[[LoadedModules]]` entries with
  `ModuleRequestsEqual`. `link_and_eval_module()` registers the entry module
  before loading, propagates rejected load promises and link/evaluate failures,
  and drains the promise job queue.
- The 226-entry `ErrorType` table is generated from `Runtime/ErrorTypes.h` with
  upstream names, templates, and ordered `{}` substitution.

## Executable runtime slice

`Script.parse()` retains its frontend tree and original source. `Script.compile()`
generates and caches an `Executable`; `VM.run()` executes it through the V loop,
with no JavaScriptCore dependency. `VM.run_with_limits()` and `run_executable()`
accept an optional instruction budget (zero is unlimited). Browser execution and
the standalone runner use a one-million-instruction limit.

Supported programs include primitive and BigInt literals, identifiers, `this`, numeric and
bitwise operators, comparisons, primitive string concatenation, unary operators,
`typeof` (including unknown names and lexical TDZ checks), conditional and sequence
expressions, short-circuiting logical operators and assignments, identifier
assignments/updates, ordinary data/accessor-property reads/writes/updates, `delete`, `in`, `instanceof`,
native function and method calls and `new` expressions
without spread arguments, string own `length`/character properties, `var`/`let`/`const`,
blocks, `if`, `while`, `do`/`while`, `for`, unlabelled `break`/`continue`, and `throw`. Bindings persist across scripts in one
realm. Global declaration conflicts are checked before creating any bindings;
block declarations are created before executing their initializers. The global
object supplies `undefined`, `NaN`, `Infinity`, and `globalThis` with upstream
property attributes. It also installs the translated `isFinite`, `isNaN`,
`parseInt`, `parseFloat`, `encodeURI`, `encodeURIComponent`, `decodeURI`, and
`decodeURIComponent`, `escape`, and `unescape` functions with their upstream names,
lengths, and descriptors. Global property installation retains upstream
numeric/URI-function-before-value order, then Boolean/Symbol constructor entries,
then legacy functions.

The entire program is compiled before declaration instantiation or execution.
An unsupported construct, even inside an untaken branch, rejects the program
without running its preceding statements or creating its bindings. ECMAScript
functions, spread calls/construction, object/array literals,
destructuring, classes, exceptions with `try`/`catch`/`finally`, labels, iterators,
templates, regex, async, and modules are still pending. Handwritten bytecode tests exercise exception
handler dispatch and `Catch`; this does not imply AST-level catch support.
Ordinary objects supplied by a host can coerce through `@@toPrimitive`, `valueOf`,
and `toString`, with upstream hint order and abrupt-completion propagation.
Objects without a usable coercion method throw the upstream `TypeError`.
Boolean and Symbol primitive references box through their translated wrappers
while preserving the original primitive receiver for inherited methods and
accessors. Other primitive property access beyond virtual string own properties
still requires untranslated wrapper prototypes and reports the explicit runtime error.

BigInt numeric operations follow `Runtime/Value.cpp`: arithmetic, truncating
division/remainder, signed bitwise operations, arithmetic shifts (including
negative counts), exponentiation, unary operators, equality, string conversion,
ToBigInt/NumberToBigInt, and modulo-64-bit conversions. Mixed Number/BigInt
operators, division by zero, negative exponents, and counts wider than the
upstream 32-bit size guard produce the upstream errors. Integer-versus-double
comparison extracts IEEE-754 words without rounding the BigInt through Number.
Literal readers preserve radix prefixes and numeric separators; updates retain
BigInt type. V `math.big` supplies storage and basic arithmetic instead of
LibCrypto's LibTomMath substrate. The signed bitwise conversion loops and double
extraction follow the upstream dependency bodies. LibCrypto as a whole and
external-memory accounting remain untranslated.

BigInt constructor/prototype records now retain source initialization order,
metadata and constructor back-reference. The constructor applies ToPrimitive
with the number hint once, accepts integral Numbers through NumberToBigInt,
and otherwise uses ToBigInt. Its pinned IsConstructor result is true while
[[Construct]] immediately throws, without coercion or newTarget.prototype reads.
asIntN/asUintN coerce the width before the integer, retain signed-boundary and
huge-width fast paths, and expose the source InternalError for width overflow.
The prototype is an ordinary object without BigIntData. toString and valueOf
accept only BigInt primitives or real wrappers; radix conversion follows the
brand check and formatting emits lowercase digits without a literal suffix.
The locale native body forwards both original arguments to the retained current-
realm NumberFormat constructor and the exact BigInt cell to FormatNumeric.
Object and Intl dependencies are explicit: no replacement locale formatter or
production BigInt global is installed, and Intl formatting remains untranslated.

`NativeFunction.create()` retains a capturing V callback; `create_raw()` uses the
VM's typed native function table. Both install `name`/`length` metadata and enter
an allocated callee context with the supplied realm, receiver, arguments, and
inherited caller environments. Success and failure restore the caller and stack
mark. Native calls share the job-callback interface. Creation takes an explicit
realm/prototype; default native globals inherit the realm's translated Function
prototype. Hosts can install additional callable globals with an explicit prototype.
Compiled calls retain the callee/receiver before argument evaluation and resolve
an environment binding's `with` receiver through `with_base_object()`.

The Function prototype is callable and returns undefined. Its `apply`, `bind`,
`call`, `toString`, and `@@hasInstance` methods retain upstream metadata and
receiver validation. `apply` gathers an ordinary array-like object's length
once and reads its indexed properties in order, including inherited entries and
holes; getters and value-check callbacks stop on their first abrupt completion.
ToLength clamps to the upstream safe-integer/host-size limit, and ToIndex rejects
negative or clamped indices. The V list allocation has a narrower capacity guard
described below.

Bound callables retain their target, receiver, and argument prefix, inherit the
target's prototype, and forward nested bindings in order. Binding reads an own
numeric target length before reading its name; infinite, fractional, missing,
inherited, and nonnumeric lengths follow the upstream algorithm. Native
`toString` uses the initial name despite changes to the public name property;
other callables display the upstream anonymous native representation. The
source-text slot is retained for the pending ECMAScript function record.
Ordinary instance checks follow the prototype chain; custom `@@hasInstance`
methods use their receiver and ToBoolean result, and bound checks delegate to
their targets. The pinned upstream's no-handler operand order is preserved as
described below.

Each initialized realm owns its Function prototype and a shared, nonextensible
`%ThrowTypeError%` with fixed name/length descriptors. The Function prototype's
configurable, nonenumerable `caller` and `arguments` accessors share that thrower
for reads and writes. Default globals inherit these restrictions through the
same prototype. The Object prototype, Function constructor and constructor
back-reference, and remaining intrinsic graph are pending.

Native constructors translate `NativeFunction::internal_construct`: arguments,
callee realm, inherited lexical/variable environments, uninitialized this value,
and restoration on both normal and abrupt completion. `GetPrototypeFromConstructor`
performs the observable prototype read before using `GetFunctionRealm` for a
non-object fallback; bound targets are followed without changing the running realm.
Bound construction concatenates captured arguments, ignores the bound receiver,
and substitutes the target only for an identical `newTarget`. Compiled `new`
expressions retain the callee and each argument before later expressions can
mutate them, evaluate arguments before constructor validation, and reject spread
arguments before any execution.

Each realm also owns distinct Boolean and Symbol constructors and prototypes,
including constructor back-references. Boolean.prototype retains a false-valued
[[BooleanData]] slot; its toString/valueOf methods accept primitives and branded
wrappers without conversion hooks. Boolean calls use ToBoolean; construction
creates a branded wrapper with the new target's chosen prototype. Constructor
property insertion order follows subclass initialization and subsequent intrinsic
name installation, including Symbol's fixed well-known properties before length/name.
Symbol.prototype has no [[SymbolData]] slot. Its methods, description getter,
@@toPrimitive, and @@toStringTag follow the upstream descriptors and brand checks.
Description distinguishes undefined from empty and preserves every UTF-16 unit.
Symbol calls create unique identities; Symbol.for/keyFor use the VM-wide registry
shared by realms, and all 16 pinned well-known symbols have fixed static descriptors.
The pinned source gives Symbol a constructor internal method that always throws
without converting its argument; this behavior is preserved. Number and String
constructor/prototype records and the Object prototype graph remain pending.
Number/BigInt wrappers are translated; BigInt constructor/prototype records now
exist with explicit Object/Intl dependencies rather than production globals.

StringObject translates StringCreate and the string exotic property methods
(`c17ed07`). Each character descriptor contains exactly one UTF-16 code unit,
including a surrogate half or NUL, with fixed value, writable/configurable false,
and enumerable true. The fixed ordinary length is not enumerable. Definitions
of virtual characters check descriptor compatibility without allocating stored
properties, including on nonextensible objects. Own-key order places virtual
indices first, then additional sorted indices, ordinary strings in creation order,
and public symbols. GetOwnProperty checks ordinary storage before virtual
characters, while diagnostics continue to inspect ordinary storage only.
Compiled reads, writes, delete, `in`, and Function.apply reach these exotic
methods when a host supplies a String object with an explicit prototype.

Runtime property keys canonicalize decimal indices below 2^32-1, while leading
zeros and 2^32-1 remain strings. Ordinary own keys enumerate indices first in
numeric order, then strings and public symbols in their creation orders.
SameValue/SameValueZero compare string and BigInt contents, retain symbol/object
identity, and apply the upstream Number rules for NaN and signed zero.

Member assignments retain the base and computed key value before RHS evaluation.
Read and write each invoke ToPropertyKey as upstream; compound and logical
assignments retain their old value, and short-circuiting skips both RHS and store.
Prefix/postfix updates preserve Number/BigInt type. Delete resolves bindings
without reading them, checks property configurability, and preserves computed-key
coercion before nullish ToObject errors. The `in` operator rejects a non-object
right operand before key coercion and walks the ordinary prototype chain.

Ordinary prototype replacement checks identity before extensibility and rejects
cycles. PreventExtensions, SetIntegrityLevel, and TestIntegrityLevel implement
sealing/freezing for data and accessor descriptors. Freezing preserves accessor
setters. Private symbols are excluded
from ordinary own-key enumeration and therefore from these public integrity
operations. Proxy hooks remain pending.

Accessor cells retain their getter/setter objects and optional private cache key.
Ordinary Get/Set preserve inherited receivers, missing-getter/setter behavior,
and abrupt completions through compiled property operations, coercion, and
environment lookup. ValidateAndApplyPropertyDescriptor handles generic,
data, and accessor descriptors, including kind transitions and non-configurable
function-identity checks. CompletePropertyDescriptor preserves absent versus
explicitly undefined callbacks; ToPropertyDescriptor reads inherited fields in
upstream order and rejects non-callable or mixed descriptors. FromPropertyDescriptor
uses a caller-supplied Object prototype until Intrinsics exists.

Native accessor helpers retain upstream getter/setter names, lengths, and partial
callback updates. Cached accessor values live in engine-private properties on
the holder and are shared only with that holder and its direct children.
Getter exceptions do not cache results; deletion/replacement during a getter
prevents its old Accessor cell from publishing a stale value. Diagnostic property
inspection follows the prototype chain without invoking accessors.
ObjectDefineProperties accepts an already-converted property object, gathers
every enumerable descriptor before writing, and then applies them in own-key
order. Conversion failure leaves the target untouched; a later definition failure
retains earlier successful writes. Other primitive boxing and the Object constructor's
JavaScript-facing methods remain pending.

Array records supplied by a host implement ArrayCreate, CreateArrayFromList,
and the exotic property methods. Sparse arrays retain a separate, nonconfigurable
length descriptor without allocating holes; successful index definitions grow
that length, while deletion leaves it intact. Length assignment performs
ToUint32 and ToNumber separately before validating the descriptor. Failed
truncation retains the highest nonconfigurable index and applies a requested
readonly length even on failure. Enumeration places the ephemeral length key
after numeric indices and before other strings. Compiled assignments, updates,
delete, `in`, and Function.apply reach this dispatch; property definitions now
accept the VM and propagate abrupt completions. Array creation requires an
explicit prototype until the Array intrinsic graph is translated. Array
literals, the constructor/prototype methods, and Proxy IsArray handling remain
pending.

SortIndexedProperties collects values before comparing them, distinguishes
skip-holes from read-through-holes, and includes inherited indexed entries.
The merge-sort helper follows upstream left-before-right recursion and stable
ties. CompareArrayElements puts undefined last without invoking a comparator,
converts comparator results once with NaN mapped to positive zero, and compares
default strings by UTF-16 code units. Getter, comparator, and coercion exceptions
stop later work. These helpers do not yet expose JavaScript Array.prototype.sort
or Array.prototype.toSorted; their surrounding prototype methods remain untranslated.

The synchronous Iterator.cpp slices translate cached next-method acquisition,
IteratorNext/Complete/Value/Step/StepValue, IteratorClose/CloseAll, result records,
IteratorToList, callback-driven collection, and the setter that ignores inherited
properties (`9e66501`, `5204b68`). Object receivers support @@iterator acquisition;
GetIteratorFromMethod can receive any value with an explicitly supplied method.
Next-call failures, non-object results, and done-getter failures mark the record
done. IteratorStep retains a value-getter error as a completion; StepValue marks
done when consuming that error. Closing observes the return getter/call even when
an original throw must win, and close-all walks records in reverse order.
Callback completions close the iterator; next/step errors return directly.

StringIterator and its prototype (`7196f2d`) yield complete surrogate pairs and
preserve unpaired surrogates, following AK's UTF-16 code-point iterator. The
ordinary-array-like ArrayIterator path and its prototype (`481e0fa`) support
keys, values, and entry-pair Array objects, inherited sparse entries, live length
changes, and permanent exhaustion that releases the target. The index advances
after LengthOfArrayLike and before an indexed getter; reentrant length access
preserves the pinned source's saved-index/current-slot increment behavior.
Both prototypes expose branded native next methods and configurable tags with
upstream metadata. Their Iterator parent, result Object parent, and entry-pair
Array parent are explicit dependencies. These records are callable from compiled
scripts when supplied by a host; realm intrinsic installation, iterator-producing
String/Array methods, Iterator helpers and async iteration remain pending.
TypedArray iterator-producing bodies are translated below with explicit dependencies.

ByteLength (`4732c43`) distinguishes numeric zero, automatic lengths, and detached
buffers. DataBlock (`3d6ed51`) translates owned and fixed-length host storage:
zeroed creation, byte copies, overlap-safe moves, resize and capacity growth.
ArrayBuffer records (`777b419`) retain their shared flag, optional maximum and
detach key, expose the VM's existing HostResizeArrayBuffer contract, and preserve
SameValue key checks before detaching or taking the backing block. Host-backed
records share bytes and keep their captured size; detaching one record does not
detach another record that references the same host buffer.

SpeciesConstructor (`39e1cc2`) reads the constructor and @@species in order,
uses the default for undefined/null species, and accepts native or bound
constructors. DataView records and witnesses (`c928179`) cache numeric or detached
buffer lengths, distinguish empty attached views from detached buffers, and
derive automatic lengths from that snapshot. Shrinking and regrowing resizable
buffers updates later witnesses; the pinned source's u32 length/offset narrowing
is preserved.

ArrayBuffer construction and all four prototype accessors and four methods
(`ff7010e`) are installed in each realm with standard metadata and constructor
links. Length conversion precedes maximum-option access and new-target prototype
lookup; only length-conversion RangeErrors are rewritten as invalid ArrayBuffer
length errors. Allocation and cloning use the translated constructor/prototype
selection. Resize supports both the VM's default in-place host hook and the
unhandled allocate/copy path, preserving bytes and zeroing newly exposed bytes.
Slice follows species lookup and validates the returned buffer before rechecking
the original; a species constructor can shrink or detach the source without an
out-of-bounds copy. Transfer ignores species, optionally preserves the maximum,
zeroes extension bytes, and detaches the source only after successful allocation
and copying. ArrayBuffer.isView recognizes translated DataView and TypedArray
internal slots.

Narrow integer conversions (`8f4b151`) follow ToInt8/ToUint8/ToInt16/ToUint16,
including finite checks, truncation and normalized modulo. ToUint8Clamp retains
the source's ties-to-even rounding. Buffer element conversion and get/set/modify
operations (`f827284`) cover signed and unsigned integers, BigInt modulo 2^64,
clamped bytes, Float16/Float32/Float64, byte order, signed zero and canonical NaN.
Float16 uses the same native `_Float16` type as upstream, through two primitive
representation helpers; the buffer algorithms are V. Tests cover every binary16
representation and direct double-to-half rounding without an intermediate float.

DataView construction and prototypes (`59dc603`) are installed in each realm.
All three property getters and 22 numeric methods retain upstream metadata,
branding and coercion order. Construction rechecks detachment and bounds after
new-target prototype access. Setters convert the index and value before reading
the current bounds witness; coercion can shrink or detach the buffer. Fixed and
tracking views recover after regrowth, and the buffer getter preserves identity
even when the view is detached or out of bounds. The pinned source's ByteLength
u32 narrowing occurs before constructor length checks and is explicitly tested.

Shared byte data blocks (`56befbf`) follow CreateSharedByteDataBlock's active
owned-storage body with the shared flag retained, including attached zero-length
blocks, capacity reservation, zero-filled growth and allocation errors. Shared
buffer allocation, construction and prototypes (`0ed8038`) expose the upstream
species getter, three property getters, grow and slice methods in every realm.
The constructor converts the initial length before maximum options and prototype
lookup, rewrites only initial length RangeErrors, and reserves the maximum while
exposing the current length. Growth checks the buffer slots before coercion, then
calls HostGrowSharedArrayBuffer before even equality and limit checks. Unhandled
growth uses the current length after reentrant coercions and preserves existing
bytes while zeroing extensions. Slice snapshots the source length before start
and end conversion, performs species construction and result validation in source
order, and copies into the species result; the default result is fixed. Tests
include source growth during coercion and construction, host-handled and abrupt
paths, live fixed/tracking DataViews and the pinned source's object-identity check
for species results.
The source's concurrent byte-length/event-record branches and cross-agent shared
backing storage remain pending; this translates its active standalone behavior.

CanonicalIndex and CanonicalNumericIndexString (`87f4121`) retain the pinned
source's u32 index representation and numeric/undefined tags, including its zero
payload for numeric strings that round-trip. TypedArray records (`88072d4`)
dispatch all twelve element types through the translated buffer conversions.
Their witnesses preserve cached lengths, partial trailing elements, zero-length
views, fixed versus tracking bounds, detachment and recovery after regrowth.
All eight integer-indexed
exotic methods are dispatched by Object, including numeric-key prototype
suppression, receiver identity, descriptor restrictions, key order and the
resizable-buffer restriction on preventing extensions. ArrayBuffer.isView also
recognizes these internal slots after detachment.
Element writes convert Number/BigInt before checking current bounds, including
invalid indices; descriptor definitions validate the initial index and flags
before conversion. InitializeTypedArrayFromArrayBuffer (`4ef9b57`) preserves
alignment, offset/length coercion order, checked arithmetic and the upstream
allocation limit. ArrayIterator.next (`0184891`) uses a fresh TypedArray witness,
ignores a shadowed length property and retains its target/index after a bounds
error.

AllocateTypedArrayBuffer and the TypedArray/list/array-like initializers
(`0431e34`) preserve allocation limits, detached/out-of-bounds rejection, source
length snapshots and observable allocation/coercion order. Same-element-type
copies clone raw bytes, preserving NaN payloads and signed zero; other types
convert Number or BigInt elements into independent fixed buffers. Shared source
buffers produce ordinary copies. List and array-like initialization allocate
before element conversions, retain partial writes after errors and read inherited
or missing elements through ordinary Get/Set.
Concrete constructor call/construct bodies (`107ed40`) dispatch all twelve kinds
through those initializers. Object inputs create their initial record before
iterator or offset access; iterables are exhausted before element conversion,
while scalar inputs use ToIndex and the upstream length-RangeError rewrite.
New-target prototype lookup preserves foreign-realm fallback through an explicit
IntrinsicPrototypeGetter dependency. The concrete constructor/prototype records
and Uint8Array encoding methods are now translated below; their remaining
intrinsic dependencies and production global installation are still pending.
TypedArrayCreate (`749413c`) retains a sole numeric minimum before arbitrary
construction and validates result brand, bounds and length in source order.
CompareTypedArrayElements (`e8daaeb`) orders NaNs last and negative zero before
positive zero, compares BigInts exactly and applies callback/ToNumber before
its default rules.

NumberObject and BigIntObject (`aab4abb`) preserve their exact numeric payload or
primitive cell and ordinary object identity. ToObject (`f559831`) now covers all
five primitive types, returns object inputs unchanged and preserves nullish
TypeErrors. Number, BigInt and String prototype getters remain explicit
embedding dependencies. GetV and Invoke (`a21fead`) preserve the active primitive
prototype optimization, accessor receivers and call arguments through those
dependencies. Number/String constructor/prototype records and primitive Reference
integration remain pending; BigInt records exist with explicit Object/Intl dependencies.
GetMethod (`9bfb266`) now follows that same primitive boundary, preserving
getter receivers, nullish missing methods, callable native/bound identities and
NotAFunction errors. String iteration still needs its builtin prototype and
iterator method; explicitly supplied methods can use translated StringIterator.

TypedArray receiver conversion, its four branded accessors, at and @@toStringTag
(`ad194b8`) follow TypedArrayPrototype.cpp through that boxing boundary. Detached
or out-of-bounds views report zero length/byte length/offset, while the buffer
and name remain accessible. at snapshots length before index conversion and
reads current storage afterward. Non-TypedArray receivers retain ToObject's
nullish error or the subsequent brand error.

The search methods (`230e882`) retain snapshot length, omitted-versus-explicit
fromIndex, infinity and large-index checks, exact BigInt comparisons and the
includes SameValueZero versus indexOf/lastIndexOf strict-equality distinction.
After reentrant resize or detachment, includes reads undefined at invalid
indices while indexOf/lastIndexOf skip them through HasProperty.

reverse and sort (`d1e4382`) preserve receiver identity and numeric element
semantics. sort checks callback callability before receiver conversion, snapshots
all elements before comparisons and writes the stable numeric result through
live integer-indexed Set operations. Callback errors leave the sorted snapshot
unwritten; callback-induced shrinking or detachment limits the subsequent writes.

every/some/forEach (`7213d9e`), FindViaPredicate and find/findIndex/findLast/findLastIndex
(`7b39d87`), and reduce/reduceRight (`d67fc25`) validate the receiver and capture
length before callback validation. Missing callbacks retain the method-specific
error; explicit non-callable values retain NotAFunction. Traversals read live
values without skipping indices that become invalid during callbacks. Growing a
buffer does not extend the captured index range; shrinking or detaching it yields
undefined for remaining invalid indices. Predicate truthiness uses ToBoolean
without object conversion, and searches return the value captured before the
matching predicate runs. Reductions distinguish omitted from explicit undefined
initial values and preserve arbitrary accumulator values without coercion.

entries/keys/values (`9dc2893`) validate the view before creating an ArrayIterator
with the corresponding iteration kind. Its translated next body retains live
lengths, recoverable out-of-bounds errors, exact BigInt elements, real entry-pair
Array records and permanent exhaustion. The ArrayIterator prototype dependency
is explicit; the values/@@iterator alias is now retained by the translated
TypedArray prototype initializer described below.

copyWithin (`e74332a`) retains ordered index conversion, the original relative
index basis and a fresh witness before a nonempty copy. Shrinking limits the
copy to its longest live prefix; an empty copy skips revalidation. Non-shared
storage uses DataBlock move_data through the translated ArrayBuffer forwarding
method, while shared storage preserves the source's forward/backward byte loop.
Both paths preserve NaN payloads and all other source bits.

fill (`d877f4e`) converts its numeric value before start and end, then revalidates
even an empty range. Its integer fast path retains 256-byte ordinary-buffer
chunks and per-element shared-buffer writes; other kinds retain numeric indexed
Set. Fractional clamping, BigInt conversion, signed zero, inverted ranges and
resizing keep their upstream behavior.

join (`475271a`) converts its separator even for empty views, retains the initial
length and reads live elements after conversion. Invalid indices become empty
fields without a second validation. UTF-16 assembly preserves unpaired separator
surrogates and exact BigInt text. Checked string length arithmetic (`d61447e`)
uses the upstream unsigned-32-bit maximum and size_t overflow errors; the join
builder additionally checks V's signed-int storage capacity as described below.

TypedArrayCreateSameType (`abf80bf`) selects the current realm's concrete intrinsic
from the exemplar's kind through an explicit constructor getter, then delegates
result validation to TypedArrayCreate. It does not read constructor or species
properties. toReversed/toSorted/with (`046c2c1`) retain numeric Get/Set copies into
independent fixed storage. toSorted allocates before reading/comparing the input
and writes its stable numeric snapshot only after comparison succeeds. with
converts index and value before live-index validation, then copies the captured
length. A value conversion that grows the view may validate an index beyond
that captured length, leaving the result without a replacement, as in upstream.

TypedArraySpeciesCreate and concrete default factories (`72d3141`) select the
current realm's intrinsic constructor before observable constructor/species
lookup. Default-constructor identity uses direct allocation or view creation,
bypassing Construct and its throwaway buffer. Custom construction retains
TypedArrayCreate validation before the content-type check.

filter/map (`85ae10f`) retain captured traversal lengths and live reads. filter
collects pre-callback values and creates its species result after all callbacks;
map creates it before the first callback and performs each converting write
immediately. Custom same-content species may change the concrete numeric kind
or return aliased source storage; subsequent map reads observe those writes.

slice (`a3d3766`) converts both bounds and creates the species result before
revalidating a nonempty source. Tracking-view shrinkage clips the copied prefix
while preserving the originally requested result size and its zero-filled tail.
Same-kind and Uint8/Uint8Clamped copies preserve raw bits; aliased/shared storage
retains the forward byte loop instead of a snapshot or overlapping move.
Different kinds retain numeric Get/Set copying. Empty ranges skip the second
source validation but still perform species creation.

subarray (`97e9907`) uses zero source length for an initially out-of-bounds view,
then converts bounds before species creation. A tracking source with undefined
end passes only buffer and offset, preserving tracking in the default view;
other cases include the computed length. Default initialization checks the
original buffer, while a custom species may return independent valid storage.

set (`391b7de`) retains offset conversion before bounds checks, target/source
validation before range and content-type checks, encoding-equivalent raw copies,
and cloned ordinary/shared aliases. Its different-encoding path preserves the
pinned source's original-view read after cloning, described below. Array-like
input captures length once and reads/converts each element even after a getter
shrinks or detaches the target; abrupt conversion leaves earlier writes intact.

toLocaleString (`8b40840`) invokes each live numeric primitive's locale method
with both locales and options, converts its result to UTF-16 and checks each
append. Invalid indices become empty fields after reentrant shrink/detachment.
Number/BigInt locale formatting remains an explicit untranslated intrinsic
dependency; the completed native body does not substitute Intl behavior.

The abstract TypedArray constructor (`fecc443`) preserves its call to Construct
and abstract-class TypeError, from/of/species, source property
order, method lengths, name and prototype back-reference. from validates the
constructor and optional mapper before iterator lookup, exhausts iterable input
before allocation/mapping, and interleaves live array-like reads with mapping
and converting writes after allocation. Iterator errors do not close the
iterator, matching the active collection body. of captures argument count and
retains argument values across nested construction/conversion frames. Both
paths validate an arbitrary constructor result before their first element write;
abrupt conversion preserves earlier writes.

Array.prototype.toString (`fab8c38`) supplies the exact shared body: ToObject,
observable join lookup, callable join or the retained Object toString intrinsic,
and a call with the boxed object receiver and no forwarded arguments. The Object
intrinsic function remains an explicit dependency; no Object tag implementation
is substituted and a mutable Object.prototype.toString property is not read.

TypedArrayPrototype initialization (`1389c86`) installs all 35 native bodies,
their source metadata and descriptors, in source order. Its toString property
retains the supplied Array prototype function identity, and @@iterator retains
the original values function even after later values replacement. The Object,
Array, iterator, primitive and concrete TypedArray intrinsic dependencies remain
explicit. Concrete records and Uint8Array helpers are translated below; production
builtin installation and cached caged views remain separate untranslated work.

GetOptionsObject (`2f2343b`) creates a fresh empty null-prototype object for
undefined, preserves object identity without reading properties, and rejects
every other primitive without boxing or coercion.

Uint8Array hex operations (`9cf836b`) translate ValidateUint8Array, byte reads
and writes, FromHex, fromHex/setFromHex/toHex. Decoder records carry their partial
bytes alongside an optional throw completion. Odd UTF-16 lengths fail before
destination capacity is considered, while even input is only validated through
the consumed prefix. setFromHex writes valid prefix bytes at the view's byte
offset before propagating a later SyntaxError. Static fromHex ignores its native
receiver and uses the current realm's explicit Uint8Array prototype dependency.
Hex output uses lowercase digits, live fixed/tracking lengths and shared storage;
other TypedArray kinds, inherited slots and detached/out-of-bounds views retain
the source's validation order.

Base64 operations (`a7f0fa3`) translate fromBase64/setFromBase64/toBase64, option
getter order, exact option validation, padding and all three last-chunk modes.
Options can resize, detach or restore a view before the fresh buffer witness;
partial decoded bytes are written before a SyntaxError is propagated. ToBoolean
of omitPadding does not invoke coercion hooks. AK's simdutf 7.4.0 dependency is
translated from its scalar codec, safe dispatch wrapper and ARM64 block decoder
control flow; vector loads/tables use scalar code-unit operations in V. The
64-code-unit blocks, 576-code flush, padding checks, bad-character retry and
tail backtracking are retained, including the pinned block path's observable
trailing-whitespace read count. All **16,470** generated UTF-16 comparisons match
the installed upstream library's output bytes, decoder status and consumed-input
count exactly, with no case overrides. The MIT notice is retained under
`licenses/`. Rebuild those fixtures with `python3 tools/libjs_base64_corpus.py`
(`41c7df5`), using `--simdutf-prefix` for another installed 7.4.0 dependency.
Fixtures are checked in; runtime builds and ordinary tests need no simdutf
library or upstream checkout.

All twelve concrete constructor/prototype records (`8b5ed80`) now follow
TypedArray.cpp's class macro and Intrinsics constructor finalization. They retain
BYTES_PER_ELEMENT, length/name descriptors, source property order, shared
constructor/prototype inheritance and the prototype constructor back-reference.
Uint8Array's two static and four prototype encoding functions use their source
metadata and descriptors. Dependencies remain explicit; these records are not
installed in the production realm or exposed as builtin globals.

ObjectPrototype common methods (`075d278`) translate hasOwnProperty,
propertyIsEnumerable, isPrototypeOf, valueOf and toLocaleString directly.
Membership converts the property key before boxing the receiver and reads only
own descriptors, including String virtual characters and symbol keys. Prototype
membership short-circuits nonobject arguments before receiver coercion, then
walks by identity. valueOf preserves objects and creates current-realm primitive
wrappers; toLocaleString invokes the live toString property with the original
receiver and no forwarded arguments.

RequireObjectCoercible (`0291ad9`) rejects nullish values using the source error
and otherwise returns its argument unchanged. SetImmutablePrototype (`a8a54c4`)
compares prototype identity without mutation or an extensibility check; Object's
immutable-prototype dispatch flag represents ObjectPrototype's virtual override.
The actual ObjectPrototype intrinsic record and initialization remain pending.

Annex B accessor bodies (`d8016f4`) preserve ToObject, callability and key-conversion
order during definitions. Definitions preserve an existing opposite callback,
set enumerable/configurable, and propagate failed definitions. Lookup walks own
descriptors without invoking callbacks, stopping at data properties or an
accessor with an undefined callback. The __proto__ getter/setter (`6730833`)
retain primitive boxing for reads, coercibility-first validation for writes,
ignored invalid prototype arguments, unboxed primitive no-ops, and TypeError
on cycles or rejected prototype changes. These eleven native bodies retain
explicit Number/BigInt/String prototype dependencies. Object toString's complete
IsArray/Proxy, mapped-arguments, Date and RegExp dependency chain is untranslated;
no replacement tag implementation or partial production Object intrinsic is added.

BigInt width methods and their numeric helpers (`ebdcf2f`) follow the native
asIntN/asUintN bodies, LibCrypto modulo/complement control flow and LibTomMath
1.3.0's magnitude-digit truncation. Tests cover byte/word boundaries, upstream
large integer fixtures, zero-width conversion, source fast-path cell identity,
16,384-bit negative conversion and huge-width OOM behavior. The invalid-string
conversion error now preserves upstream unquoted contents (`056b036`).

BigInt prototype brand/radix/valueOf bodies (`4f8ecb8`) accept primitive cells
and real BigIntObject payloads without inherited branding or receiver coercion.
Brand validation precedes radix conversion, all 35 supported radices retain
lowercase digits, and valueOf ignores arguments and preserves cell identity.
The constructor record (`6b61e57`) retains metadata, both static methods, the
non-writable prototype and constructor back-reference. Its call converts once
with the number hint; construction rejects before coercion or prototype reads.

The locale-call body (`0d07d1a`) retains explicit NumberFormat constructor and
FormatNumeric dependencies, forwarding locales/options unchanged and preserving
the original BigInt cell and returned UTF-16. Tests exercise only that plumbing;
Intl NumberFormat and locale formatting remain untranslated. Full prototype
initialization (`24f70bd`) preserves source method order and @@toStringTag, with
no BigIntData slot on the prototype itself. Object/Intl dependencies remain
explicit and the records are not installed in the production global graph.
The wrapper, constructor and prototype preserve the upstream GC_CELL diagnostic
class names (`5d37b0c`), including errors when a noncallable prototype is invoked.

Reflect property bodies (`5f4813e`) translate defineProperty/deleteProperty/get,
getOwnPropertyDescriptor/has/set. Target-object validation precedes key conversion;
defineProperty converts the descriptor only after the key. Rejected definitions,
deletions and writes return booleans, while observable conversion/accessor errors
propagate. Explicit undefined/null/primitive receivers remain distinct from an
omitted receiver. getOwnPropertyDescriptor creates a fresh ordinary descriptor
object using the explicit current-realm Object prototype dependency.

Reflect prototype/extensibility methods (`cb51775`) validate targets without
boxing and preserve null prototypes, cycles, immutable-prototype identity checks
and nonextensibility. Rejected prototype changes return false; wrong prototype
types throw the source TypeError. preventExtensions retains TypedArray refusal
for tracking and resizable-buffer views through the existing exotic internal method.

Reflect apply/construct (`e873aaa`) retain callable/constructor validation before
array-like argument reads, live length/index getter order, bound call/construction
forwarding and abrupt completion cleanup. An omitted newTarget defaults to target;
explicit undefined is rejected before arguments-list reads. Native callee realm,
receiver, argument values and explicit new-target identity survive nested frames.

Reflect ownKeys and PropertyKey::to_value (`2f441e2`) retain ordered string/symbol
keys, numeric string caching, exact UTF-16 and private-key exclusion. Results are
fresh translated Array exotic records with the supplied current-realm Array
prototype. Array length, String virtual indices and live TypedArray keys use the
existing exotic key operations, including resize and detach transitions.

The complete ReflectObject record (`f7e9d80`) follows source initialization order
for all thirteen methods and @@toStringTag. It is noncallable and nonconstructible;
method attributes, lengths, names and Function prototype inheritance are retained.
Object/Array prototypes remain explicit dependencies, so production Reflect global
installation is deferred until that intrinsic graph is translated. Proxy internal
methods and ECMAScript function execution remain separate untranslated dependencies.

Numeric globals follow the upstream coercion order and errors. parseInt preserves
radix validation, hexadecimal-prefix stripping, prefix termination, per-digit
double accumulation, and signed zero. parseFloat preserves the Number fast path,
left trimming, the decimal-prefix reader, incomplete-exponent rollback, Infinity
matching, and string negative zero. Its decimal-prefix grammar follows the
fast_float dependency; binary conversion uses V strconv instead of fast_float.
URI functions retain UTF-16 code units, uppercase encoding, original spelling of
preserved reserved escapes, and upstream URIError handling for unpaired encoding
surrogates and invalid percent-encoded UTF-8. Strict UTF-8 validation uses V
stdlib in place of AK Utf8View's simdutf dependency.
The legacy `escape` and `unescape` functions follow the upstream Annex B bodies
directly. Escaping uses uppercase two-digit byte escapes and four-digit UTF-16
escapes; decoding preserves malformed sequences and expands each escape once.
Lone surrogates are preserved, and byte escapes are not interpreted as UTF-8.

A standalone runner makes this boundary usable outside the browser:

```sh
v -old-compiler -enable-globals run tools/libjs_run.v -e 'var sum=0; for(let i=0;i<7;i++) sum+=i; sum*2;'
# 42
v -old-compiler -enable-globals run tools/libjs_run.v program.js
```

The runner prints the completion value with `Value.str()` and reports failures
on stderr with a nonzero exit code. It links ICU for the frontend, with no
JavaScriptCore linkage.

## Browser integration

`browserjs.Runtime` now owns a translated VM and initialized realm. Its
`prepare_script()` boundary retains the LibJS parse and scope analysis alongside
the source URL, starting line, and script/module parse goal. `evaluate()` uses
that boundary, while `evaluate_prepared()` reuses an existing parse. Classic
program execution pushes a translated Script execution context with its realm
and global environment, then removes it on both success and failure. Closing
the runtime releases JavaScriptCore and clears the embedding context stack.

Both the native browser in `main.v` and the inline-document layout bridge use
this path for page scripts. Bootstrap, document readiness dispatch, and DOM
snapshot code use `evaluate_host()`. Each page script executes as a separate
global program, preserving lexical bindings for later scripts and draining
JavaScriptCore promise jobs between programs. Parse and runtime failures are
logged per script; later scripts and readiness events still run. Discarded
completion values are not coerced to strings. The backend receives the full
UTF-16 source, including embedded NULs, plus the source URL and starting line.
Runtime error messages retain their stack traces, including source locations;
an exception from a thrown value's `stack` getter does not replace that value's
reported error.

In the default JavaScriptCore mode, JavaScriptCore remains responsible for
execution, JavaScript call frames, global bindings, objects, and promise reactions.
The translated VM contexts describe the embedding boundary, not JavaScriptCore's internal frames. Input
that reaches the frontend's 32-call guard is validated by JavaScriptCore;
RegExp patterns also receive its syntax validation. Module sources use LibJS's
module parse goal, but the compact browser reports that module execution is
pending instead of running a module as a classic script.

The native command line selects the backend explicitly:

```sh
Build/v/Ladybird.app/Contents/MacOS/Ladybird --js-engine=javascriptcore page.html
Build/v/Ladybird.app/Contents/MacOS/Ladybird --js-engine=libjs page.html
# The separate form --js-engine libjs is also accepted.
```

JavaScriptCore remains the default until the LibJS DOM and builtin bindings are
ready. `Runtime.create_with_engine(.libjs)` creates no JavaScriptCore context,
runs supported programs through the translated VM, and never falls back to
JavaScriptCore. Parse-budget exhaustion and unsupported code are reported
explicitly. Source URLs and starting lines reach bytecode diagnostics and runtime
tracebacks. Per-script failures leave later scripts runnable.

LibJS mode establishes the native browsing context and renders the document, but
skips the current JavaScriptCore-based DOM bootstrap and event dispatch. It logs
that DOM bindings are pending; unsupported DOM scripts produce diagnostics.
`--headless-smoke --js-engine=libjs` tests bytecode execution and identifies the
pending DOM bindings. The JavaScriptCore smoke still checks DOM mutation and click
handlers.

## Verification

The repository's current V checkout requires its old compiler frontend:

```sh
v -old-compiler -enable-globals test libjs
# 155 passed, 155 total

v -old-compiler -enable-globals -gc none test libjs
# 155 passed, 155 total

v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all
# LibJS AST corpus: 100 passed, 0 failed, 100 total

v -old-compiler -enable-globals test browserjs
# 16 passed, 16 total

v -old-compiler -enable-globals -gc none test browserjs
# 16 passed, 16 total

v -old-compiler -enable-globals test main_test.v
# 1 passed, 1 total

v -old-compiler -enable-globals test .
# 825 passed, 825 total

./build_ladybird.sh
Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke --js-engine=javascriptcore
# DOM mutation and click-event checks pass
Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke --js-engine=libjs
# LibJS bytecode execution passes; DOM bindings are pending
```

All 100 checked-in upstream AST fixtures compare directly and exactly, including
scope flags and source positions. Only trailing CR/LF characters are ignored;
there are no case overrides. Actual dumps are written to `Build/libjs-ast/`.
Pass fixture stems to select cases, `--upstream PATH` to choose a checkout, or
set `LADYBIRD_SOURCE_DIR`. ICU headers and `libicucore` on macOS or `libicuuc` on
Linux are required for the identifier predicates.

The VM tests exercise the runtime records directly and through compiled scripts.
Translated native functions cover call frames, arguments, receiver/realm state,
coercion, metadata, and failure cleanup. VM host-hook tests use controlled
`FunctionObject`, `Module`, `FinalizationRegistry`, `Agent`, and `ArrayBuffer`
fixtures; separate tests exercise translated NativeFunction and ArrayBufferObject
records. Module-loading tests write temporary module files. The preceding LibWeb
work passed its complete 656-file
suite, native headless smoke, and all 11 default screenshot comparisons before
this package; the 155 libjs files are verified separately in both GC modes.
There are now 825 repository test files.

The complete 825-file repository suite passes, including the native bridge,
sixteen browser integration files and all 155 LibJS files. The dedicated LibJS and
browser suites also pass in no-GC mode, exercising the retained storage and
buffer ownership independently of the collector.

Browser integration checks pass the sixteen `browserjs` test files in both GC modes,
the native `main_test.v` bridge and flag tests, the production bundle build,
JavaScriptCore DOM-mutation/click smoke, and LibJS bytecode smoke. Native
LibJS fixtures also verify bound calls/construction, Boolean and Symbol methods,
registry-backed property keys, primitive instance checks, and legacy escaping.
Host-supplied String/Array iterator records are also exercised through compiled
browser scripts, including Unicode, readonly string characters, live array
length changes, entry-pair arrays, errors, and later-script recovery.
ArrayBuffer browser checks (`8d7272b`) execute construction, resize, slice and both
transfers through compiled references, inspect the resulting backing bytes,
recognize host-created DataViews, and preserve per-script errors and recovery.
The standalone runner executes a buffer-transfer fixture that returns 42 and a
negative-length fixture that reports RangeError. The native LibJS layout fixture
executes the same buffer checks without script errors.
DataView browser checks (`a028263`) execute all 22 numeric methods, construction,
bound construction, resizing, detachment and per-script recovery in the translated
VM. A standalone fixture returns 42 after checking byte order, BigInt, Float16,
tracking lengths and transfer; an invalid-offset fixture reports RangeError and
exits with status 1. The rebuilt native LibJS layout fixture runs the same checks
without script errors. The standalone runner also passes all 18 unchanged
numeric assertions extracted from the upstream DataView test fixtures.
SharedArrayBuffer browser checks (`db66bd5`) execute construction, growth, slicing,
BigInt DataView reads/writes, bound construction and later-script recovery in the
translated VM. Fixed and tracking views remain distinct after growth. A standalone
fixture returns 42 after the same checks, while a shrinking-growth fixture reports
RangeError and exits with status 1. The rebuilt native document fixture runs
without script errors; both native engine smoke checks pass.
TypedArray browser checks (`7596418`) install real host-created records and run
compiled index reads/writes, delete/in, ArrayBuffer.isView and iterator next
calls. They cover DataView storage aliasing, partial-element resizes, fixed/tracking
recovery, BigInt coercion errors, per-script recovery, shared-buffer views and
detachment. Tests use explicit prototypes while the TypedArray intrinsic graph
remains pending.
TypedArray constructor integration checks (`b6b3a9d`) supply test-only host
constructors and prototypes, then execute scalar lengths, array-like input,
record copies, bound construction, tracking buffer views and shared BigInt copies
through the compiled browser VM. They verify independent backing storage,
per-script failures and later-script recovery with no JavaScriptCore context.
These fixtures do not install or claim the pending TypedArray builtin graph.
TypedArray prototype integration checks (`f55bea6`) attach the completed native
bodies to test-only host prototypes and execute branded accessors, relative
indexing, NaN/signed-zero searches, reverse, default numeric and BigInt sorting,
bound native comparators, resizing, detachment and per-script recovery. Primitive
Number and nullish receiver errors go through the translated ToObject boundary.
No JavaScriptCore context is created by these fixtures.
The callback/iterator integration checks (`230effb`) use bound native predicates,
exact BigInt reductions, shrinking callbacks, abrupt completions and later-script
recovery. Compiled entries/keys/values calls exercise branded next, entry-pair
Arrays, live growth, bounds-error recovery and permanent exhaustion. ECMAScript
function bytecode and the builtin TypedArray graph remain pending.
The filling/copying integration checks (`5116a3e`) execute fill, copyWithin, join,
toReversed, toSorted and with through test-only host prototypes and same-type
constructor dependencies. They verify independent results, exact BigInt sorting
and replacement, bound comparators, separator-induced shrinkage, coercion errors
and recovery without creating a JavaScriptCore context.
The species integration checks (`9582b26`) execute set, slice, subarray, filter
and map through compiled calls, including bound callbacks, overlapping copies,
tracking growth and a Float64 species result. toLocaleString uses an explicit
host callback to verify primitive receivers and locale/options forwarding;
the fixture does not claim Number/BigInt Intl formatting. These checks create
no JavaScriptCore context.
The constructor/prototype checks (`27b3fff`) replace the test fixture's hand-wired
method table with the translated TypedArrayPrototype and abstract constructor
records. Host concrete constructors inherit from that abstract constructor and
their prototypes inherit from the shared prototype. Compiled scripts exercise
inherited from/of/species, primitive-string mapping, iterable TypedArray copies,
bound construction, shared toString identity, the values/@@iterator alias and
later-script recovery after abstract-constructor errors. Concrete test records
and Object/Number/BigInt/String dependencies stay explicitly host-supplied;
this fixture does not install incomplete builtin globals in production.
The concrete-record checks (`126b4fb`) now replace those host-written concrete
constructors/prototypes with translated records, retaining explicit host names
and Object/Array/Number/BigInt/String intrinsic dependencies. Compiled scripts
exercise hex/base64 round trips, URL alphabets, omitted padding, capacity limits,
partial writes before errors, BYTES_PER_ELEMENT, tracking growth, byte offsets,
detachment and recovery in later scripts without creating a JavaScriptCore context.
Object native-body integration (`c0f46fb`) uses an explicit test host, retaining
an immutable root and live ordinary child prototypes. Compiled browser scripts
exercise own/enumerable membership, primitive boxing, toLocaleString argument
suppression, symbol accessors, inherited getter/setter preservation, descriptor
lookup, prototype mutation, cycle/immutable-root errors and later-script recovery.
These checks create no JavaScriptCore context and do not install ObjectPrototype
or supply a replacement Object toString implementation in the production realm.
Reflect browser integration (`17706b9`) supplies the translated record under the
test-only HostReflect name with explicit Object/Array prototypes. Compiled scripts
exercise all thirteen methods: symbol/data/accessor descriptors, inherited lookup,
explicit receivers, key-array ordering, prototype changes, extensibility, bound
apply and native construct. Boolean failure results and per-script TypeErrors leave
later scripts runnable. No JavaScriptCore context is created, and no incomplete
Reflect global is installed in the production realm.
BigInt browser integration (`ab034e7`) supplies the actual translated constructor
and prototype under test-only host names, with an explicit Object parent and a
clearly marked Intl plumbing fixture. Compiled calls exercise constructor
coercion, both width methods, boxed toString/valueOf, bound natives, metadata,
large exact integers and recovery from constructor, radix, brand and OOM errors.
The fixture creates no JavaScriptCore context and does not claim Intl formatting
or install an incomplete production BigInt global.
The rebuilt native bundle passes both engine smoke checks and a buffer-regression
document covering shared BigInt storage, growth, slicing and transferred Float16
bytes without script errors.
Invalid engine flags return exit status 2. The standalone runner passes
expression and file-input checks, rejects unsupported programs with exit status
1, and its linked libraries contain ICU and libSystem without JavaScriptCore.

The earlier 25 screenshot comparisons passed the 11 default smoke cases, the
same-size SVG image source switch, and 13 SVG paint-server mutation cases; all
14 SVG comparisons were pixel-exact. After the function/array translation, the rebuilt
bundle passes all 11 default comparisons and the pixel-exact same-size SVG source
switch again. The screenshot tools use `V_BIN` with a temporary wrapper that
selects this checkout's old compiler frontend for their pixel-diff helper.
The primitive-object, construction, iterator, buffer, DataView, SharedArrayBuffer
and TypedArray record/construction/prototype refresh passes `inline-node` with 13
differing pixels (maximum channel error 1, within its documented tolerance) and
the same-size SVG source switch with zero differing pixels.

## Deviations from upstream

- `Value` keeps an explicit tag next to its payload instead of NaN-boxing.
  BigInt uses V arbitrary-precision storage; accessor cells are V heap records.
- BigInt width helpers retain the pinned arm64 LibTomMath 60-bit used-digit
  fast-path bound, while modulo digit clearing uses 8-bit magnitude bytes and
  complement/radix operations use the existing V arithmetic substrate. Widths
  above INT_MAX follow LibCrypto's ENOMEM branch and the preallocated VM error;
  ordinary substrate allocations still use V's nonrecoverable allocator behavior.
  Radix formatting retains LibCrypto's zero and lowercase UTF-16 output paths.
  The constructor/prototype records require an explicit Object parent and
  retained NumberFormat/FormatNumeric operations; no host formatter replaces
  untranslated Intl logic in the production realm. Utf16String's record type is
  public for those operation signatures while its storage remains private.
- There is no process-wide `VM::the()` singleton or one-VM-per-process guard;
  every record that needs the VM receives it explicitly, and private environment
  ids are handed out by the VM instead of a static counter.
- GC cells are V heap records. Environments, function objects, modules, and
  finalization registries are interfaces; `gather_roots()` reports their
  identities into `HeapRoots` for inspection rather than driving a collector.
- `TypeErrorRealmScope` has no destructor; callers must call `restore()`.
- `Object` supports ordinary data and accessor properties, including native
  holder-value caching, without shapes, inline property-cache metadata, proxies,
  or the remaining intrinsic prototypes. Function, Boolean, and Symbol prototypes
  are initialized separately with null Object prototypes until that graph exists.
  Boolean/Symbol constructor entries are eager data properties in place of the
  upstream engine-private lazy intrinsic accessor map. Property descriptors omit Shape slot offsets;
  FromPropertyDescriptor takes an explicit prototype, and ObjectDefineProperties
  starts after ToObject. The runtime property key is named
  `PropertyName` because the parser owns `PropertyKey`, and the runtime source
  range is `SourceCodeRange` because the AST owns `SourceRange`.
- `Promise` implements state transitions and rejection tracking without
  reactions; `PromiseCapability` resolve/reject functions are optional until
  promise resolving functions exist.
- `DeclarativeEnvironment` uses one binding list without the environment-shape
  cache; disposable binding hints throw an `InternalError` until explicit
  resource management is translated.
- `SourceTextModule` parses through the frontend but `link()`, `evaluate()`, and
  `load_requested_modules()` report an `InternalError`; `ImportedModulePayload`
  carries an `on_finished` continuation where upstream enters
  `ContinueModuleLoading`/`ContinueDynamicImport`. JSON modules go through the
  `parse_json_module` hook, whose default reports an `InternalError`.
- The operand tag encoding matches upstream, but instructions are typed V records
  with instruction-index offsets, not packed byte offsets. No upstream bytecode
  cache ABI is claimed. Register allocation is monotonic, bindings use named
  environment lookup, and block environment operations use the frame's current
  environment instead of environment-valued operands.
- Script compilation precedes global declaration instantiation, and the script
  context is pushed before instantiation, so unsupported programs cannot mutate
  globals and declaration failures retain a script traceback. Upstream arranges
  instantiation before allocating/pushing the script frame.
- Native callable objects are translated, but ECMAScript functions and
  per-iteration environments observable through JavaScript closures remain
  pending; function syntax is rejected before execution. The existing
  `FunctionObject` interface receives arguments directly, so the native
  `internal_call()` and `internal_construct()` own frame allocation that upstream
  `call_impl()` and `construct_impl()` perform.
  Native records use their supplied name for call-stack display, combine raw and
  capturing variants in one record, and take an explicit prototype. Default
  native globals receive the realm's Function prototype; its own prototype is
  null until the Object intrinsic exists. Shapes, builtin optimizations,
  NativeJavaScriptBackedFunction, direct
  binding getters, and ECMAScript construction remain separate work.
- Bound calls and construction concatenate V argument arrays before forwarding to the target,
  rather than shifting arguments in one preallocated callee frame as upstream
  does. Upstream external-memory accounting remains pending.
- CreateListFromArrayLike uses a V array in place of GC::RootVector. Lengths
  beyond V's signed-int capacity (2^31-1 elements) throw the existing allocation
  RangeError before indexed reads, even on 64-bit hosts where upstream size_t
  can represent a larger list.
- Array indexed entries use the ordinary V property list instead of packed,
  holey, and dictionary storage tiers. Sparse truncation follows upstream's
  GenericIndexedPropertyStorage body, and length remains an ephemeral descriptor.
  Creation takes an explicit prototype because %Array.prototype% is pending.
  Shape/prototype guards and packed-storage fast paths remain untranslated;
  the ordinary property algorithms supply the available array semantics.
- String characters use flat one-unit PrimitiveString cells instead of upstream
  substring cells. The VM-less descriptor API bypasses the VM's creation cache;
  string SameValue still compares the exact UTF-16 contents. StringCreate requires
  an explicit prototype while the String intrinsic graph remains pending.
- Checked string length sum/product retain upstream's 2^32-1 code-unit maximum.
  TypedArray join and toLocaleString assemble flat V UTF-16 arrays instead of
  AK's builder and throw the same string-size RangeError above V's 2^31-1 array
  capacity before an append can overflow that representation.
- Iterator records and result variants use V heap records and explicit done
  flags. Intrinsic parents are supplied by callers; no Iterator/Object/Array
  prototype substitute is installed. Synchronous acquisition currently accepts
  object receivers. Primitive GetMethod exists with explicit prototype inputs;
  String's builtin iterator method, async acquisition, Iterator helpers and
  builtin-marker fast paths remain pending. Array iterator next uses
  the translated TypedArray witness path as well as ordinary array-like lengths.
  String iteration uses code-unit offsets over the retained flat string rather
  than AK iterator pointers. Array key/entry indices preserve the pinned source's
  i32 conversion, including its wraparound for indices at or above 2^31.
- DataBlock uses flat V byte arrays, heap-owned storage records and the non-caged
  copy/move algorithms in place of GC::PrimitiveStorage handles. Array lengths
  and capacities are limited to 2^31-1; larger requests report the upstream
  allocation RangeError before narrowing. Capacity reservation is eager, and
  small allocation failures still follow V's allocator failure behavior rather
  than a recoverable C++ ErrorOr. ExternalPrimitiveStorage, cage offsets, GC
  external-memory accounting and cached TypedArray offset invalidation remain
  untranslated. Explicit prototypes select host-created buffer/view records;
  the ArrayBuffer, DataView and SharedArrayBuffer constructors use the realm graph.
  Object.prototype remains pending, so all three installed prototypes currently
  have a null parent.
  Explicit enum dispatch replaces C++ element templates, and shifts/masks replace
  native integer memcpy while preserving the specified byte order. V has no
  binary16 scalar: `float16.h` uses upstream's `_Float16` cast and memcpy for two
  primitive representation operations. The buffer and DataView algorithms
  remain in V.
  Source shared-memory ordering branches are themselves FIXME bodies; no
  concurrent SharedArrayBuffer/Atomics semantics are claimed here.
  SharedArrayBuffer slice compares result object identity, as the pinned source
  does, rather than testing backing-store identity from its spec comment. Distinct
  host buffer records with the same backing store therefore pass that source check.
- TypedArray concrete C++ templates use BufferElementType dispatch in V. Object's
  descriptor API has no VM argument, so numeric reads use the existing standalone
  BigInt representation without a VM cache. The pinned source's u32 byte offsets
  and arithmetic are retained. Cached caged addresses and their registration are
  omitted until PrimitiveStorage is translated; reads and writes use retained
  buffer storage. Canonical numeric strings retain the upstream Numeric tag and
  zero payload instead of reconstructing a floating-point index.
  Numeric round trips use the existing V string/number conversions rather than
  AK's floating-point parser. Concrete construction receives an explicit
  IntrinsicPrototypeGetter in place of the C++ pointer to an Intrinsics member;
  it does not install a partial intrinsic graph. Buffer copies, list/array-like
  initialization, TypedArrayCreate and element comparison retain the active
  upstream bodies through the existing allocation, numeric and native-call paths.
  ToObject receives explicit Number/BigInt/String IntrinsicPrototypeGetter
  dependencies; Boolean and Symbol use installed current-realm records. This
  retains real primitive wrappers without synthesizing incomplete prototypes.
  TypedArray native behavior functions carry those same boxing dependencies;
  no partial TypedArray builtin prototype is installed in the production realm.
  Species creation also receives explicit concrete intrinsic constructor and
  prototype getters, including the default allocation/view factories.
  The pinned set conversion path clones aliased storage and resets its source
  byte index to zero, but then reads through the original source view rather
  than the clone. The translation preserves and tests this active-body flaw;
  aliased different-encoding copies can therefore read the wrong offset or
  observe earlier writes. This is source fidelity, not an ECMAScript parity claim.
  GetV, GetMethod and Invoke expose the translated primitive-prototype lookup
  with explicit Number/BigInt/String dependencies; primitive Reference
  integration is pending.
  Number toLocaleString and Intl formatting remain untranslated; BigInt's locale
  native body retains explicit NumberFormat/FormatNumeric dependencies.
  The abstract and all twelve concrete TypedArray constructors/prototypes are
  complete records with explicit dependencies. Their creation follows the subclass
  initializer and Intrinsics constructor-name/back-reference steps, without
  installing unfinished concrete globals. Array toString takes an explicit
  retained Object toString intrinsic function, whose tag/IsArray/Proxy dependency
  chain is untranslated. Browser fixtures supply a clearly named host callback.
- ObjectPrototype native bodies use explicit Number/BigInt/String prototype
  dependencies in place of unfinished Intrinsics members. Ordinary and already
  translated Array/String/TypedArray exotic property paths use existing
  descriptor operations; Proxy internal methods remain pending. The
  immutable-prototype dispatch flag replaces the C++ ObjectPrototype virtual
  override. Its eleven translated bodies do not install a partial ObjectPrototype
  record; initialization and the toString type-record/IsArray chain remain pending.
- ReflectObject's thirteen native bodies and initialization are complete with
  explicit Object/Array prototype dependencies. ownKeys maps the V runtime's
  PropertyName key list through the translated PropertyKey-to-Value conversion
  before the existing CreateArrayFromList path; upstream internal key lists carry
  Values directly. Descriptor/prototype/extensibility APIs remain the current
  ordinary and translated Array/String/TypedArray dispatch paths. Proxy internal
  methods and production Reflect global installation are still pending.
- Uint8Array's hex/base64 behavior and helper initialization are translated.
  GetUint8ArrayBytes and encoding use a copied flat byte snapshot instead of a
  caged readonly span; concurrent shared-memory semantics remain pending.
  The base64 backend translates the simdutf 7.4.0 paths used by the pinned
  macOS upstream build, with scalar operations replacing SIMD/table dispatch.
  Its output/read/status comparisons are exact against that dependency, rather
  than a claim of SIMD performance or arbitrary simdutf-version equivalence.
- `Runtime/Value.cpp` at the pinned upstream revision passes `(target, value)`
  in InstanceofOperator's final no-`@@hasInstance` fallback, although its
  OrdinaryHasInstance helper expects `(value, constructor)`. The translation
  preserves and tests that body. Normal default functions inherit the Function
  prototype handler and use the correctly ordered handler path. Its builtin
  shortcut and packed-array apply optimization remain untranslated.
- Debugger hooks inside `handle_exception()` and the interpreter dispatch-table
  selection are not translated; `enable_debugging()` only tracks the record.

## Remaining translation work

The frontend and supported VM execution slice are integrated into the browser;
JavaScriptCore continues to execute scripts in the default mode. This is not a
complete LibJS runtime migration.

- RegExp flag checks exist, but `compile_regex_pattern()` still has no backend.
  Pattern syntax validation and compilation require the LibRegex boundary;
  passing the AST corpus does not establish RegExp syntax conformance.
- The parser recursion guard is **32 guarded calls**, rather than upstream's
  2,000. V's flattened expression and statement records produce much larger
  stack frames. The guard reports a positioned syntax error instead of a stack
  overflow; increasing it requires a compact AST representation and stack
  validation first.
- Remaining expression/statement generation, ECMAScript calls and inline frames
  (`push_inline_frame`), functions, generators, async execution, property caches,
  and packed interpreter bytecode remain pending. The current instruction loop
  and declaration-instantiation path cover only the supported slice above.
- The remaining Intrinsics prototype graph, global entries (including eval),
  ECMAScript function objects, Number/String/Array and most other builtin
  constructor/prototype records, other intrinsic accessors and proxies remain
  untranslated. Production builtin installation currently includes Boolean,
  Symbol, ArrayBuffer, DataView and SharedArrayBuffer. BigInt constructor/prototype
  records and all native bodies exist with explicit Object/Intl dependencies;
  production installation and Intl formatting remain pending.
  String exotic records, synchronous iterator operations, and
  String/Array iterator next prototypes exist with explicit intrinsic
  dependencies. Array sorting helpers and exotic records exist, but Array/String
  constructors/prototypes, iterator-producing methods, Iterator helpers, async
  iteration, and array-literal generation remain pending.
  DataView records, construction, witnesses, property accessors, numeric methods
  and buffer element conversions exist, as do SharedArrayBuffer construction,
  accessors, growth and slicing. TypedArray records, buffer witnesses, integer-indexed
  exotic methods, all four initialization paths, concrete constructor behavior,
  TypedArrayCreate, numeric comparison and iterator next exist with explicit
  prototype dependencies. Number/BigInt wrapper records and primitive ToObject
  exist with explicit Number/BigInt/String prototype dependencies; their primitive
  Reference integration remains pending; Number/String constructors/prototypes
  are untranslated and BigInt global installation awaits its Object/Intl graph;
  GetV, GetMethod and Invoke exist with explicit intrinsic dependencies.
  TypedArray's four accessors, at, @@toStringTag, three indexed search methods,
  reverse, sort, every/some/forEach, four predicate searches, reduce/reduceRight,
  entries/keys/values, copyWithin, fill, join, toReversed/toSorted/with and
  TypedArrayCreateSameType, species/default factories, filter/map/set/slice/subarray
  and toLocaleString also exist with explicit intrinsic dependencies. The
  abstract TypedArray constructor, from/of/species, shared Array toString body
  and shared TypedArray prototype including values/@@iterator exist with
  explicit dependencies, as do all twelve concrete constructor/prototype records
  and Uint8Array's six hex/base64 methods. Production builtin installation, its
  complete intrinsic graph, ObjectPrototype initialization and toString/IsArray,
  and Number locale builtins/Intl formatting remain untranslated, as do concurrent
  shared backing stores, Atomics and caged storage. ReflectObject's complete record and
  all thirteen native bodies exist with explicit Object/Array dependencies;
  production global installation and Proxy internal methods remain pending.
  Realms expose four standard value properties, eight numeric/URI functions,
  Boolean/Symbol/ArrayBuffer/DataView/SharedArrayBuffer constructors, and two legacy
  functions on an ordinary global object. Default native globals inherit the
  translated Function prototype, whose Object prototype and Function constructor
  linkage remain pending.
- CyclicModule graph loading, linking, evaluation, promise reactions, JSON
  modules, the debugger, and the LibWeb host bindings remain necessary before
  making LibJS the default browser backend or claiming LibJS parity.
  JavaScriptCore remains available through its command-line selection.

The AST corpus, focused syntax cases, and VM record tests validate the completed
slices above; they are not an ECMAScript runtime conformance suite.
The LibWeb symbol audit excludes this separate package (`db4e4fc`), so matching
LibJS runtime names cannot satisfy LibWeb coverage or alter its review queues.
All 46 translation-tool Python tests pass, including that scope regression.
