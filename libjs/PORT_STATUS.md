# LibJS V translation status

Audited: 2026-10-01.

The frontend baseline comes from `medvednikov/libjs_v` commit
`9824cc3fad0910215f0f4de43fb108bb7575f6c7` (2026-02-24). The upstream reference is
`~/code/3rd/ladybird/Libraries/LibJS` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11): its Rust parser, lexer,
AST, and scope collector for the frontend, and its C++ `Runtime/VM.{h,cpp}`,
`Interpreter/Interpreter.cpp` VM members, and runtime records for the VM slice.
The execution slice additionally follows `Rust/src/bytecode/{operand,generator,codegen}.rs`,
`Interpreter/{interpreter.flap,SlowPaths.cpp}`, `Script.cpp`,
`Runtime/{Value,GlobalObject,BigInt,NativeFunction,FunctionObject,BoundFunction,FunctionPrototype,BooleanObject,BooleanPrototype,BooleanConstructor,SymbolObject,SymbolPrototype,SymbolConstructor,StringObject,Iterator,StringIterator,StringIteratorPrototype,ArrayIterator,ArrayIteratorPrototype,ByteLength,ArrayBuffer,ArrayBufferConstructor,ArrayBufferPrototype,DataView,Intrinsics,Array,ArrayPrototype,IndexedProperties,PropertyKey,Object,PrimitiveString,Accessor,PropertyDescriptor,AbstractOperations}`
source bodies, numeric/URI/Annex B global functions from `Runtime/GlobalObject.cpp`,
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
| `value_indices.v`, `array_like.v`, `instanceof.v` | ToIntegerOrInfinity/ToLength/ToIndex, LengthOfArrayLike/CreateListFromArrayLike, OrdinaryHasInstance and InstanceofOperator |
| `native_function.v` | Capturing/raw native callable objects, function metadata, native table dispatch and callee execution contexts |
| `construct.v`, `constructor_prototype.v` | Native construction contexts, IsConstructor, GetFunctionRealm, and GetPrototypeFromConstructor |
| `bound_function.v`, `function_prototype.v`, `restricted_function_properties.v` | Bound callable records and argument forwarding, Function prototype methods, the shared %ThrowTypeError% and restricted caller/arguments accessors |
| `array_object.v`, `array_sort.v` | Array exotic records and length/property operations, CreateArrayFromList, indexed-value collection, stable merge sorting, and CompareArrayElements |
| `boolean_object.v`, `boolean_prototype.v`, `boolean_constructor.v` | Boolean internal slots, prototype methods, calls and construction, intrinsic links, and primitive references |
| `symbol_object.v`, `symbol_prototype.v`, `symbol_constructor.v` | Symbol wrappers, prototype methods and description accessor, unique/global symbol creation, registry methods, static well-known symbols, and primitive references |
| `string_object.v` | StringCreate, virtual UTF-16 character descriptors, definition compatibility, and exotic own-key ordering |
| `iterator.v`, `iterator_values.v` | Synchronous iterator acquisition for object receivers, IteratorNext/Step/StepValue, completion-preserving close/close-all, result records, list/callback collection, and SetterThatIgnoresPrototypeProperties |
| `string_iterator.v`, `string_iterator_prototype.v`, `array_iterator.v`, `array_iterator_prototype.v` | String code-point iteration, ordinary array-like key/value/entry iteration, and branded native next methods with explicit intrinsic dependencies |
| `byte_length.v`, `data_block.v`, `array_buffer_object.v` | Tagged numeric/auto/detached lengths, owned and fixed-length host byte storage, copy/move/resize, ArrayBuffer records and detach ownership |
| `species_constructor.v`, `array_buffer_operations.v`, `array_buffer_constructor.v`, `array_buffer_prototype.v` | SpeciesConstructor, ArrayBuffer allocation/cloning/transfer and maximum options, constructor/intrinsic links, branded accessors, resize and slice |
| `data_view.v` | Retained DataView records, cached buffer-length witnesses, out-of-bounds checks and fixed/tracking view lengths |
| `global_numeric_functions.v`, `global_uri_functions.v`, `global_legacy_functions.v` | isFinite/isNaN/parseInt/parseFloat, URI encoding/decoding, and Annex B escape/unescape global functions |
| `operand.v`, `instruction.v`, `interpreter.v` | Operand encoding, checked instruction/value layouts, V dispatch loop, bindings, branches, exception dispatch and instruction budgets |
| `bytecode_generator.v`, `script_evaluation.v` | Supported expression/statement code generation, cached executables, global declaration instantiation and ScriptEvaluation |

The 85 implementation files contain **23,384 physical V LOC**. The 92 test
files contain **10,070 physical V LOC** and **340 test functions**. Physical LOC
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
extraction follow the upstream dependency bodies. This does not translate the
BigInt constructor/prototype, LibCrypto as a whole, or external-memory accounting.

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
without converting its argument; this behavior is preserved. Number/BigInt
wrappers and prototypes, String's constructor/prototype, and the Object prototype
graph remain pending.

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
String/Array methods, TypedArray iteration, Iterator helpers, and async iteration
remain pending.

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
is preserved. DataView constructors, prototype accessors and numeric methods
are not installed yet.

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
and copying. ArrayBuffer.isView recognizes translated DataView records; its
TypedArray branch remains untranslated until those records exist.

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
# 92 passed, 92 total

v -old-compiler -enable-globals -gc none test libjs
# 92 passed, 92 total

v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all
# LibJS AST corpus: 100 passed, 0 failed, 100 total

v -old-compiler -enable-globals test browserjs
# 8 passed, 8 total

v -old-compiler -enable-globals -gc none test browserjs
# 8 passed, 8 total

v -old-compiler -enable-globals test main_test.v
# 1 passed, 1 total

v -old-compiler -enable-globals test .
# 754 passed, 754 total

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
this package; the 92 libjs files are verified separately in both GC modes.
There are now 754 repository test files.

The complete 754-file repository suite passes, including the native bridge,
eight browser integration files and all 92 LibJS files. The dedicated LibJS and
browser suites also pass in no-GC mode, exercising the retained storage and
buffer ownership independently of the collector.

Browser integration checks pass the eight `browserjs` test files in both GC modes,
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
Invalid engine flags return exit status 2. The standalone runner passes
expression and file-input checks, rejects unsupported programs with exit status
1, and its linked libraries contain ICU and libSystem without JavaScriptCore.

The earlier 25 screenshot comparisons passed the 11 default smoke cases, the
same-size SVG image source switch, and 13 SVG paint-server mutation cases; all
14 SVG comparisons were pixel-exact. After the function/array translation, the rebuilt
bundle passes all 11 default comparisons and the pixel-exact same-size SVG source
switch again. The screenshot tools use `V_BIN` with a temporary wrapper that
selects this checkout's old compiler frontend for their pixel-diff helper.
The primitive-object, construction, iterator and buffer refresh passes `inline-node`
within its documented tolerance and the same-size SVG source switch with zero
differing pixels.

## Deviations from upstream

- `Value` keeps an explicit tag next to its payload instead of NaN-boxing.
  BigInt uses V arbitrary-precision storage; accessor cells are V heap records.
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
- Iterator records and result variants use V heap records and explicit done
  flags. Intrinsic parents are supplied by callers; no Iterator/Object/Array
  prototype substitute is installed. Synchronous acquisition currently accepts
  object receivers. Async acquisition, primitive String method lookup, Iterator
  helpers, builtin-marker fast paths, and TypedArray witnesses remain pending.
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
  the ArrayBuffer constructor uses the realm graph. Object.prototype remains
  pending, so the installed ArrayBuffer prototype currently has a null parent.
  Source shared-memory ordering branches are themselves FIXME bodies; no
  concurrent SharedArrayBuffer/Atomics semantics are claimed here.
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
  builtin constructors and prototypes beyond Boolean, Symbol and ArrayBuffer,
  ECMAScript function objects, other intrinsic accessors, proxies, and BigInt
  constructor/prototype methods remain untranslated. String exotic records,
  synchronous iterator operations, and
  String/ordinary-Array iterator next prototypes exist with explicit intrinsic
  dependencies. Array sorting helpers and exotic records exist, but Array/String
  constructors/prototypes, iterator-producing methods, Iterator helpers, async
  iteration, TypedArray iteration, and array-literal generation remain pending.
  DataView records and witnesses exist, but its constructor, prototype accessors
  and numeric methods, TypedArray records, SharedArrayBuffer builtins, buffer
  element conversions, Atomics and caged storage remain untranslated.
  Realms expose four standard value properties, eight numeric/URI functions,
  Boolean/Symbol/ArrayBuffer constructors, and two legacy functions on an ordinary
  global object. Default native globals inherit the translated Function prototype,
  whose Object prototype and Function constructor linkage remain pending.
- CyclicModule graph loading, linking, evaluation, promise reactions, JSON
  modules, the debugger, and the LibWeb host bindings remain necessary before
  making LibJS the default browser backend or claiming LibJS parity.
  JavaScriptCore remains available through its command-line selection.

The AST corpus, focused syntax cases, and VM record tests validate the completed
slices above; they are not an ECMAScript runtime conformance suite.
The LibWeb symbol audit excludes this separate package (`db4e4fc`), so matching
LibJS runtime names cannot satisfy LibWeb coverage or alter its review queues.
All 46 translation-tool Python tests pass, including that scope regression.
