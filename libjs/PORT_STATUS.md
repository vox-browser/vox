# LibJS V translation status

Audited: 2026-10-02.

## Ordinary ECMAScript calls — 2026-11-14

The bytecode runtime now executes ordinary function declarations and expressions,
closures, recursive calls, returns, constructors and lexical arrow `this`.
Each call owns a checked interpreter frame and a function environment. Nested
calls share the outer instruction budget. Function bodies compile on first
call; uncalled bodies retain their parsed source. Unsupported body syntax fails
when that function is called, without switching to JavaScriptCore.

Focused function, script, native-call and interpreter checks pass with current V;
the new function cases also pass with GC disabled. Non-simple parameters,
async/generator functions, block/conditional function declarations and full
arguments-object semantics remain open. This is runtime groundwork for the
opt-in browser backend; it does not establish site compatibility.

## Pure V Unicode backend — 2026-11-12

Unicode processing now lives in `../vunicode/`: Unicode 17.0.0 general
categories, binary properties, scripts/extensions and emoji sequences; full
casing and simple folding; case closures; lossless UTF-16 normalization;
UAX #9 paragraph levels/reordering; UAX #14 line breaks with CSS CJK tailoring;
and UAX #29 word boundaries for titlecase. The URL package uses the same
normalizer/data for nontransitional UTS #46, ContextJ and bidi validation, with
V's `encoding.punycode` codec. C/C++ bridges, native ICU symbols and ICU package
requirements have been removed.

Default JavaScript String casing now uses Unicode root mappings, independent
of the process locale; CSS casing still honors explicit language tags,
including Turkish/Azeri, Lithuanian, Dutch IJ and Greek uppercase tailoring.
Unpaired UTF-16 surrogates remain intact through casing and normalization.
Line breaking implements the Unicode default rules and the existing CSS CJK
modes; it does not ship ICU's dictionary segmentation for Southeast Asian
languages. This change does not replace the browser's JavaScriptCore engine
or remove dependencies internal to system frameworks and third-party libraries.

`tools/generate_unicode.py UCD_DIRECTORY` regenerates the bundled data without
ICU or third-party Python packages. Use the Unicode 17 UCD, IDNA and Emoji
text files; `vunicode/data/SOURCES` records their hashes, and `data/LICENSE`
contains the Unicode license. Runtime lookup uses immutable embedded tables;
no system Unicode files, native Unicode calls or network access are needed.
`tools/check_unicode_dependency.py [EXECUTABLE]` audits source and direct binary
imports. `tools/unicode_smoke.v` exercises the services in a standalone program.

The checked-in Unicode 17 normalization, line-break, word-break and
bidirectional-character conformance files pass, including visual ordering for
explicit paragraph directions. All 6,391 IDNA corpus rows pass in both strict
and nonstrict modes. Existing property/case/regex corpus references are retained.
The C backend also passes the 250-file LibJS suite with `-gc none`; default-GC
coverage consists of 248 files in the initial full run and the two remaining
corpus files after removing obsolete ICU locale setup. The unchanged matching,
class and property corpus references pass. The exact AST corpus passes 100/100.
The browser type-check passes with its production module paths, and the
standalone Unicode smoke executes under `-prod -gc none` while importing only
libSystem on macOS, with no ICU symbols. Bidi shaping and CSS CJK segmenter
regressions pass. Full first-letter layout validation remains pending: its
compilation exceeded the 12 GiB aggregate guard even with serial code generation.
No windowed production validation is claimed for the new backend; the managed
post-commit rebuild supplies the next browser bundle.

Older ICU-based validation records below describe historical implementations.

## November 1 upstream correctness ports — 2026-11-10

Five commits from Ladybird's November 1 landing set are translated here:
array iterator indices retain their Number value beyond `INT32_MAX`;
typed-array find visits indices lazily; `reduceRight` and `lastIndexOf` retain
unsigned indices; copying a typed array checks the target element-size limit;
and the canonical string key `4294967295` is an integer index. The separate
4-GiB buffer and `size_t` representation migration is deferred, so existing
allocation limits and storage representations remain in effect. The browser
still defaults to JavaScriptCore. See the [complete audit and validation](../docs/upstream-sync/2026-11-01.md).

The frontend baseline comes from `medvednikov/libjs_v` commit
`9824cc3fad0910215f0f4de43fb108bb7575f6c7` (2026-02-24). The upstream reference is
`~/code/3rd/ladybird/Libraries/LibJS` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11): its Rust parser, lexer,
AST, and scope collector for the frontend, and its C++ `Runtime/VM.{h,cpp}`,
`Interpreter/Interpreter.cpp` VM members, and runtime records for the VM slice.
The execution slice additionally follows `Rust/src/bytecode/{operand,generator,codegen}.rs`,
`Interpreter/{interpreter.flap,SlowPaths.cpp}`, `Script.cpp`,
`Runtime/{Value,GlobalObject,BigInt,BigIntConstructor,BigIntPrototype,NativeFunction,FunctionObject,BoundFunction,FunctionPrototype,BooleanObject,BooleanPrototype,BooleanConstructor,SymbolObject,SymbolPrototype,SymbolConstructor,StringObject,StringConstructor,StringPrototype,RegExpObject,NumberObject,NumberConstructor,NumberPrototype,BigIntObject,Iterator,StringIterator,StringIteratorPrototype,ArrayIterator,ArrayIteratorPrototype,ByteLength,ArrayBuffer,ArrayBufferConstructor,ArrayBufferPrototype,DataView,DataViewConstructor,DataViewPrototype,SharedArrayBufferConstructor,SharedArrayBufferPrototype,CanonicalIndex,TypedArray,TypedArrayPrototype,Intrinsics,Array,ArrayPrototype,IndexedProperties,PropertyKey,Object,ObjectPrototype,ReflectObject,PrimitiveString,Accessor,PropertyDescriptor,AbstractOperations}`
source bodies and `Runtime/ValueInlines.h`, numeric/URI/Annex B global functions
from `Runtime/GlobalObject.cpp`,
`AK/StringConversions.cpp` and fast_float decimal-prefix parsing, and the BigInt
operations delegated to LibCrypto/LibTomMath.
Number conversion also follows LibCrypto's signed/unsigned double-rounding bodies;
Number's scientific helpers retain AK's fmt/Dragonbox decimal backend as an
explicit untranslated dependency.
String UTF-16 helpers also follow `AK/{UnicodeUtils.h,Utf16View.cpp,Utf16String.cpp}`
and simdutf 7.4.0's scalar `utf16.h` validation and repair bodies. Unicode casing
and normalization follow `LibUnicode/{Utf16String.cpp,Normalize.{h,cpp},ICU.{h,cpp}}`
and now use the shared pure V Unicode backend.
Regex records, input primitives, pattern analysis, literal prefilters and VM
storage, repetition, traversal, literal/backreference and character-class matching,
simple-match predicates, candidate filters, simple-scan execution, fast greedy
consumption, loop suffix measurements, saved-state backtracking and shared
failure/assertion handlers follow
`LibRegex/Rust/src/{ast,bytecode,vm}.rs`
at the same upstream revision. Property-kind and resolved-property records,
Unicode property queries, resolution/validation, scalar predicates and
string-property packing follow `LibUnicode/Rust/src/character_types.rs` and
`LibUnicode/CharacterTypes.cpp`. Regex execution remains pending.
Regex canonicalization and UnicodeSet closure/range operations additionally follow
`LibUnicode/{CharacterTypes,String}.cpp`, with full uppercase, simple Unicode
folding and case closures supplied by the shared V backend.
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
| `lexer.v`, `token.v`, `unicode_properties.v` | UTF-16 lexing, token classification, ICU identifier properties |
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
| `number_predicates.v`, `bigint_double.v`, `number_constructor.v` | Number/integral/finite/NaN predicates, LibCrypto signed/unsigned double rounding, complete Number constructor initialization, calls and construction |
| `number_string.v`, `number_fixed.v`, `number_scientific.v`, `number_locale.v`, `number_prototype.v` | Number branding/radix/valueOf, exact binary fixed/scientific rounding, locale plumbing and full prototype initialization with explicit Object/decimal/Intl dependencies |
| `value_indices.v`, `array_like.v`, `instanceof.v` | ToIntegerOrInfinity/ToLength/ToIndex, LengthOfArrayLike/CreateListFromArrayLike, OrdinaryHasInstance and InstanceofOperator |
| `object_coercible.v`, `immutable_prototype.v`, `object_prototype_methods.v`, `object_prototype_accessors.v`, `object_prototype_proto.v`, `object_prototype.v` | RequireObjectCoercible, SetImmutablePrototype, ObjectPrototype allocation/initialization and native methods, including supported-slot toString tag dispatch with explicit primitive dependencies |
| `reflect_properties.v`, `reflect_prototypes.v`, `reflect_calls.v`, `reflect_own_keys.v`, `reflect_object.v` | All thirteen Reflect native bodies and complete initialization, PropertyKey-to-Value conversion, explicit Object/Array intrinsic dependencies |
| `value_integer_conversions.v` | ToInt8/ToUint8/ToInt16/ToUint16 and ties-to-even ToUint8Clamp |
| `native_function.v` | Capturing/raw native callable objects, function metadata, native table dispatch and callee execution contexts |
| `construct.v`, `constructor_prototype.v` | Native construction contexts, IsConstructor, GetFunctionRealm, and GetPrototypeFromConstructor |
| `bound_function.v`, `function_prototype.v`, `restricted_function_properties.v` | Bound callable records and argument forwarding, Function prototype methods, the shared %ThrowTypeError% and restricted caller/arguments accessors |
| `array_object.v`, `array_sort.v` | Array exotic records and length/property operations, CreateArrayFromList, indexed-value collection, stable merge sorting, and CompareArrayElements |
| `boolean_object.v`, `boolean_prototype.v`, `boolean_constructor.v` | Boolean internal slots, prototype methods, calls and construction, intrinsic links, and primitive references |
| `symbol_object.v`, `symbol_prototype.v`, `symbol_constructor.v` | Symbol wrappers, prototype methods and description accessor, unique/global symbol creation, registry methods, static well-known symbols, and primitive references |
| `string_object.v` | StringCreate, virtual UTF-16 character descriptors, definition compatibility, and exotic own-key ordering |
| `string_constructor.v`, `string_code_units.v`, `string_raw.v` | Complete String constructor initialization, call/construct, fromCharCode/fromCodePoint and raw with explicit prototype/boxing dependencies |
| `string_character_access.v`, `string_slicing.v`, `string_search.v`, `string_concat.v` | String branding/value extraction, CodePointAt, at/charAt/charCodeAt/codePointAt, slice/substring/substr, indexOf/lastIndexOf and concatenation |
| `string_trim.v`, `string_well_formed.v`, `string_prototype_iterator.v` | Exact upstream whitespace trimming, simdutf UTF-16 validation/repair and String @@iterator creation; remaining prototype bodies and initialization pending |
| `string_repeat.v`, `string_padding.v`, `string_html.v` | Ordered repeat validation and checked UTF-16 assembly, StringPad early returns and filler truncation, and all thirteen Annex B HTML wrappers with exact attribute-quote replacement |
| `string_case.v`, `unicode_transform.v` | Generic toLowerCase/toUpperCase conversion, ASCII shortcut and locale-independent V UTF-16 casing |
| `string_normalize.v`, `unicode_normalize.v` | normalize form validation and conversion order, all four UTF-16 normalization forms through the shared V backend |
| `string_substitution.v` | GetSubstitution dollar tokens, one/two-digit capture selection and fallback, live named-group lookup and capture conversion |
| `string_replace.v`, `string_split.v` | String replace/split symbol dispatch and complete string paths, native replacement callbacks, Uint32 split limits and real Array results with an explicit prototype dependency |
| `regexp_flags.v` | `RegExpObject::Flags`, strict initialization flag validation, permissive constructor bit mapping and exact UTF-16 SyntaxError diagnostics |
| `regexp_pattern.v` | ParsePattern preparation, named-group surrogate/origin validation and non-ASCII escape normalization; regex grammar compilation pending |
| `regexp_source.v` | RegExp source escaping over UTF-16 code points, character-class/backslash state and line terminators, with the stored pattern passed explicitly |
| `regex_ast.v` | Complete LibRegex AST records, all atom/class/set variants, flags, quantifier factories, builtin-class complements and recursive value cloning |
| `regex_bytecode.v` | All 29 regex instructions and seven simple-matcher variants, program records/emission/jump patching, owned matcher cloning, WTF-16 append and Unicode property metadata |
| `regex_input.v` | ASCII/WTF-16 input views, search/comparison operations, code-point decoding/width, clipped capture copying, search advancement, character predicates and VM result/limit metadata; execution pending |
| `regex_hint_analysis.v` | Complete PatternHints analysis: control-flow successors and linear tails, first-character/first-filter metadata, leading anchors, alternative start hints, trailing/required literals and all simple-scan variants |
| `regex_literal_search.v` | Exact and ASCII-insensitive literal searches, trailing/required-literal rejection and one/two-code-unit start-position scans; regex matching pending |
| `regex_vm_state.v` | VM/scratch records, construction/reset, flat register snapshots, all saved-choice variants and modifier-stack transitions |
| `regex_vm_repeat.v` | Repeat-start/check handlers with greedy/lazy counter snapshots and checked same-matcher loop suffix minima |
| `regex_vm_traversal.v` | Forward/backward code-point boundaries, pair-aware character movement and checked multi-character position arithmetic |
| `regex_case_folding.v` | Legacy full-uppercase and Unicode simple-fold canonicalization, ASCII shortcuts, equality, word/digit predicates and all six builtin character classes through the V Unicode tables |
| `regex_vm_character.v` | Modifier-aware literal matching and adjacent-code-unit word-boundary checks |
| `regex_vm_backreference.v` | Numbered/named references, Unicode code-point comparison in both directions, and first-participating duplicate capture priority |
| `regex_unicode_set.v` | Ordered bounded case closures, case-insensitive range expansion and inverse-range matching in V |
| `regex_character_class.v` | Inclusive small/large range membership and complete legacy, Unicode and UnicodeSets case-insensitive character-class matching |
| `regex_simple_scan.v` | Complete simple-scan membership predicate |
| `regex_unicode_property_names.v`, `regex_unicode_properties.v` | Exact category/binary/script aliases, aggregate categories, script extensions, case closures, property resolution/validation and scalar predicates |
| `regex_unicode_string_properties.v` | V string-property enumeration in preserved UTF-16 sort order, complete code-point packing and query/short-buffer/Rust wrapper boundaries |
| `regex_vm_property.v`, `regex_simple_match.v` | VM property forwarding, raw/modifier-only/VM simple-match predicates, unions and the Unicode/UnicodeSets negated-property case distinction |
| `regex_candidate_start.v` | First-character/first-filter membership and complete next-candidate selection, preserving anchors, empty patterns and surrogate boundaries |
| `regex_scan_execution.v` | Complete single-match, greedy and find-all simple scan execution with UTF-16 positions and source capture-buffer boundaries |
| `regex_greedy_consume.v` | Complete legacy forward greedy consumption, preserving matcher-specific comparison and maximum-count rules |
| `regex_loop_suffix.v` | Directional same-matcher availability and checked suffix-deficit measurement without changing VM state |
| `regex_vm_backtrack.v` | Complete normal/greedy/lazy saved-choice execution, register/modifier restoration, literal skipping, suffix deficits and floor enforcement |
| `regex_vm_assertion.v` | Shared current-path failure, start/end assertions and word-boundary assertions with saved-choice continuation |
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

The 210 implementation files contain **33,663 physical V LOC**. The 222 test
files contain **29,492 physical V LOC** and **755 test functions**. Physical LOC
includes comments and blank lines. This package is counted separately from the
78-package LibWeb inventory.

## Completed refresh slices

### Frontend

- Preserve mapped-arguments scope metadata when a non-arrow function declares
  `var arguments` before using its arguments object
  ([Ladybird `159e288ee23a`](https://github.com/LadybirdBrowser/ladybird/commit/159e288ee23a9575252a16e0102c0ffaef3ff17c),
  2026-11-09). Function declarations retain their own shadowing flag, while
  lexical declarations, parameters and arrow-function vars remain shadows.
  `arguments_scope_test.v` covers ordinary functions, methods, generators,
  async functions, nested/block declarations and true shadows. The regression
  fails before the fix and passes after it; this is frontend metadata coverage,
  not execution coverage for untranslated function bytecode. The separate
  upstream Date parser, JIT and function-codegen fixes have no corresponding
  implementation in the current V runtime; browser execution uses JavaScriptCore.
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
  `09de70ed` translates `AK/StackInfo.h::size_free` as the exact unsigned
  subtraction of the retained base from `__builtin_frame_address(0)`, removing
  the invented top/base clamp and approximate alloca marker. A genuine other-thread
  stack snapshot and existing recursive VM context cases pass both GC modes.
  The isolated Source StackInfo snapshot passes **230/230 files in each GC mode**
  and **100/100 exact AST fixtures**; logs are
  `Build/audit-fixes/worktrees/09-compiled-records/Build/audit-fixes/source-stack-info-libjs-full-{default,gc-none}.log`
  and `source-stack-info-libjs-ast.log` in the same directory. Canonical LibJS
  additionally exposes the unchanged `to_well_formed` body publicly, a preceding
  change with clean canonical 229-file and exact 100-fixture evidence. Focused
  merged StackInfo/context checks pass canonically with GC disabled. Other
  platform and full musl constructor paths remain translation boundaries.
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

Number constructor/prototype records retain source order, metadata, immutable
constants, parse-function alias identity, and constructor linkage. Calls distinguish
an omitted argument (+0) from explicit undefined (NaN), apply ToNumeric once, and
round BigInts directly from their binary magnitude with ties to even. Construction
converts before newTarget.prototype lookup, with foreign-realm fallback and bound
construction. Static predicates inspect numeric tags without coercion. The prototype
is a NumberObject carrying +0; inherited slots and conversion hooks cannot brand
other receivers. All six native bodies are translated, including exact binary
fixed-digit scaling and scientific candidate selection. Radix output retains the
upstream implementation-defined floating-point division and fractional precision.
Scientific helpers require AK's still-untranslated fmt/Dragonbox decimal-form
operation; locale calls require the retained Intl NumberFormat/FormatNumeric
operations and preserve the numeric payload, including -0. These are explicit
dependencies with fixture-only inputs in tests. Production Number installation,
its Object/Intl/decimal dependency graph, and primitive Reference integration
remain pending.

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
same prototype. The Function constructor and constructor back-reference,
and the remaining intrinsic graph are pending.

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
without converting its argument; this behavior is preserved. String's full
prototype record and the Object prototype graph remain pending; its constructor
and thirty-nine prototype native bodies are translated below.
Number/BigInt wrappers and constructor/prototype records are translated with
explicit Object/Intl dependencies, plus Number's decimal backend and parse-function
intrinsics, rather than production globals.

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
Array methods, Iterator helpers and async iteration remain pending. String's
@@iterator native body is now translated with an explicit prototype getter.
TypedArray iterator-producing bodies are translated below with explicit dependencies.

ByteLength (`4732c43`) distinguishes numeric zero, automatic lengths, and detached
buffers. DataBlock (`3d6ed51`) translates owned and fixed-length host storage:
zeroed creation, byte copies, overlap-safe moves, resize and capacity growth.
ArrayBuffer records (`777b419`) retain their shared flag, optional maximum and
detach key, expose the VM's existing HostResizeArrayBuffer contract, and preserve
SameValue key checks before detaching or taking the backing block. Host-backed
records share bytes and keep their captured size; detaching one record does not
detach another record that references the same host buffer.

`primitive_backing_store.v` (`5865d48a`) directly translates the source
`DataBlock::OwnedBackingStore` through the actual LibGC PrimitiveStorage
allocator. Zeroed/uninitialized/capacity constructors, move ownership,
size/capacity/offset/handle access, resizing and capacity reservation use the
source storage operations. Focused tests pass with default GC and `-gc none`,
including slab reuse, released/stale handles, byte-preserving reallocation and
zero-filled growth. Native storage lifetime currently ends through explicit
`destroy()` calls. `data_block.v` (`c679a29d`) now uses this owner for actual
ArrayBuffer and SharedArrayBuffer allocations, and translates external
primitive storage with actual owner addresses and fixed or dynamic lengths.
Cage-masked addresses, chunked copies, both overlapping move directions and
readonly-byte callbacks follow `ArrayBuffer.h`. Reservations retain size_t
capacity, including values beyond V's signed vector limit, without committing
the reserved bytes. Detachment frees owned storage; taking a block transfers its
owner, and external/borrowed blocks leave their owner's storage intact.
Five focused files pass with default GC and `-gc none`; the actual storage
regression also passes `-prod -gc none`. The current 229-file package has passing
evidence in both GC modes: full sweeps passed 226 and 227 files respectively;
three default-GC and two GC-disabled compilation failures reported disk-space
exhaustion, and all affected files passed exact reruns after space became
available. This is combined sweep/rerun evidence, not a clean single 229-file
run. A later clean canonical snapshot passes **229/229 files in each GC mode**
after `a9c7b67b` exposes the existing source `Utf16String::to_well_formed` body
for raw WebIDL/CryptoKey string conversion. Exact upstream AST comparison also
passes **100/100**. Logs are `source-utf16-projection-libjs-{default,gc-none}.log`
and `source-utf16-projection-libjs-ast.log` under `Build/audit-fixes/`. VM collection, automatic cell destruction,
external-memory accounting and cached TypedArray offset invalidation remain
pending. Source GC::Ref<Cell> is an actual owner pointer at that unfinished cell
boundary. V's by-value DataBlock accessors provide borrowed aliases; only the
owning block may destroy storage. See
[LibGC storage status](../libgc/PORT_STATUS.md).

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
dependencies. StringPrototype initialization and Number/BigInt/String primitive
Reference integration remain pending; Number/BigInt records and String's constructor
now exist with explicit intrinsic dependencies.
`bfc616a2` adds Reference.cpp's preceding PrimitiveString virtual-property
fast path. Actual parsed VM execution reads string length and UTF-16 indices,
including astral halves, without a wrapper; raw-unit tests retain lone
surrogates and NUL and ignore the supplied receiver for those own properties.
StringPrototype fallback and primitive private-reference boxing remain pending.
The new file and existing Boolean/string-cell neighbors pass 3/3 canonically
with GC disabled. Frozen assignment-9 `32b8d45e` passes **231/231 LibJS files
in each GC mode** and **100/100 exact AST fixtures**. Its LibJS implementation
and tests match canonical integration; dependencies outside LibJS are that
private snapshot. See [Source mapping and exact evidence](../docs/translation-audit/STRING_REFERENCE_SOURCE_PROPERTIES.md).
GetMethod (`9bfb266`) now follows that same primitive boundary, preserving
getter receivers, nullish missing methods, callable native/bound identities and
NotAFunction errors. String iteration still needs production builtin installation;
the translated @@iterator body creates StringIterator with an explicit prototype.

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
of omitPadding does not invoke coercion hooks. The codec backend follows the
installed native build's simdutf 7.4.0 scalar codec, safe dispatch wrapper and
ARM64 block decoder control flow; vector loads/tables use scalar code-unit
operations in V. The current source manifest pins 9.1.0; parity with that version
remains pending. The 64-code-unit blocks, 576-code flush, padding checks,
bad-character retry and
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
The ObjectPrototype record and initialization are now installed; complete
primitive prototype and remaining type-record dependencies still require work.

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

Number predicates (`6e2f0f7`) translate the finite/integral/NaN Value helpers and
four static native bodies without argument coercion. Signed and unsigned
BigInt-to-double paths (`f83c1b6`) retain ties-to-even and toward-zero rounding,
including mantissa carry, signed boundaries and finite-to-infinity overflow.
The complete constructor record (`f2d5786`) retains constants and attributes,
intrinsic parse-function identity, source initialization order, call coercion and
conversion-before-prototype construction. NumberObject's diagnostic name follows
its pinned GC_CELL record rather than supplying a partial Object toString.

Number radix/valueOf bodies (`c0dce41`) brand before radix conversion and retain
the pinned floating-point digit algorithm. Tests include the exact 70 small/large
fixtures from upstream Number.prototype.toString.js across every supported radix,
both signs, real wrappers and inherited-brand rejection. Fixed-digit formatting
(`d43c9fc`) translates IEEE decomposition, integer scaling, division and half-up
rounding, with range validation before the nonfinite fast path. Tests cover exact
50/100-digit output, min subnormals, decimal rounding boundaries and negative zero.

Scientific bodies and their exact precision helper (`6b908cb`) retain binary
scaling and rounding, exponent correction, decimal-power candidate comparison,
shortest exponential output and the precision formatting thresholds. AK's pinned
decimal-form operation delegates to fmt/Dragonbox, which is not translated;
the operation is an explicit callback and tests supply source-shaped decimal-form
fixtures. No replacement formatter is installed. Upstream precision/exponential
fixtures, both signs, alternate candidates below decimal powers, 100-digit output,
subnormals and nonfinite conversion/range order pass in both GC modes.

The locale native body (`90e6030`) preserves NumberFormat construction, both
original arguments, exact numeric payloads (including -0/NaN/infinities), and
UTF-16 forwarding through explicit Intl dependencies. Prototype initialization
(`39e02e2`) includes all six methods in source order, their lengths/attributes,
an own NumberData = +0 slot and no own @@toStringTag. Tests cover boxing,
bound calls/construction, foreign new-target fallback and callee-realm Intl lookup.

String character constructors (`d81481c`) preserve UTF-16 units, surrogate pairs,
ordered numeric conversion and abrupt completion. The pinned `fromCodePoint`
body converts an integral Number through ToInt32 before validating its range;
wide integral values can therefore wrap. Tests retain this source behavior,
including 2^32 becoming NUL, without claiming standards conformance for it.
`String.raw` (`5b68266`) retains template/raw boxing, a single length snapshot,
live literal reads and interleaved substitution conversion. Extra substitutions
are not converted, and later literals observe mutations caused by earlier ones.
The complete constructor record (`64857a0`) retains source property order,
metadata, constructor back-reference, the call-only primitive Symbol special
case and conversion before newTarget.prototype lookup during construction.
Prototype and primitive-boxing dependencies remain explicit. StringObject's
diagnostic class name now follows its source GC_CELL record (`9d0c7e6`).

Thirty-nine StringPrototype native bodies are translated, without installing a
partial prototype record. Branding and character access (`381ecb8`) retain own
StringData checks, generic receiver coercion, code-unit indices and CodePointAt's
paired/unpaired surrogate distinction. Slicing (`0451d1d`) preserves the separate
slice, substring and Annex B substr boundary rules; searching (`ca5ec8b`) uses
exact UTF-16 units and source coercion order even when a match is impossible.
Concatenation (`ace29e7`) completes each conversion before visiting the next
argument and preserves empty-operand cell identity. Trimming (`e27b8db`) uses
all 25 pinned whitespace units, retaining non-whitespace and unpaired surrogates.
UTF-16 well-formed validation and repair (`9411c8a`) translate simdutf 7.4.0's
scalar control flow and AK's already-valid fast path. All 2,388 corpus cases
compare exactly against the pinned native backend; the regeneration tool
(`5bc7fae`) reproduces the checked-in corpus byte for byte. The @@iterator body
(`342d7f8`) creates fresh StringIterator records using an explicit current-realm
prototype dependency.

Repetition (`f334976`) retains receiver/count conversion, the negative/finite
error distinction, empty-result shortcuts before large-count validation and
the checked source string-length product. UTF-16 assembly follows AK's repeated
append loop. Padding (`bbdef03`) translates StringPad and both native wrappers:
ToLength precedes the no-padding identity return, filler conversion is skipped
on that path, an empty converted filler also returns the original primitive,
and filler repetition truncates at a code-unit boundary, including surrogate
halves. The existing V storage limit is checked after these observable steps.
All thirteen Annex B HTML wrappers (`e221011`) translate CreateHTML with its
receiver-before-attribute conversion and unused-argument behavior. Quotation
replacement follows AK's UTF-16 replace-all body; only attribute U+0022 units
become `&quot;`. Text content, ampersands, angle brackets, apostrophes, NUL and
unpaired surrogates remain verbatim.

Unicode casing (`64008dc`) translates toLowerCase/toUpperCase receiver conversion
and the LibUnicode UTF-16 helpers. The ASCII path follows AK directly; non-ASCII
input uses ICU, preserving expanding mappings, contextual Greek sigma,
supplementary characters, NUL and unpaired surrogates. The pinned source bypasses
ICU for ASCII strings but uses ICU's process default locale for non-ASCII input.
A Turkish-default-locale test preserves this distinction and restores the locale.
ICU's failed/bogus casing result remains empty, following the pinned dependency's
`UnicodeString::caseMap` body.

Normalization (`eb50321`) translates all four forms: NFC, NFD, NFKC and NFKD.
Receiver conversion precedes form conversion; undefined selects NFC, while invalid
forms throw even for an empty receiver. UTF-16 passes directly to ICU without
repairing lone surrogates or truncating at NUL. LibUnicode's original-input
fallback is retained when the native normalizer reports failure. Tests cover
canonical/compatibility composition and decomposition, Hangul, conversion order,
abrupt completion, empty input and invalid forms.

GetSubstitution (`03592d4`) translates the complete replacement-template body:
`$$`, matched text, prefix/suffix tokens, one/two-digit capture selection with
fallback, and named-group tokens. Capture conversions and named-property reads
remain live and follow template order; undefined captures become empty, invalid
references remain literal, and getter/conversion errors propagate. UTF-16 slices
retain NUL and lone surrogates. Tests also preserve the source's clamped tail
when a custom exec reports a match extending beyond the input.

String replacement (`7e94d87`) performs RequireObjectCoercible before object
`@@replace` lookup, then passes the original receiver and replacement to that
hook without coercion. The string path converts receiver, search and a noncallable
replacement before testing for a match. Only the first match is replaced; no
match retains the original primitive cell. Callable replacements receive the
matched string, UTF-16 position and original source with undefined this, and
their converted result remains literal. Noncallable templates use GetSubstitution.

String splitting (`717b2b2`) retains object `@@split` dispatch before receiver or
limit conversion and returns the hook result without coercion. The string path
creates a real Array record, converts the Uint32 limit and separator before a
zero-limit return, preserves empty fields, and splits an empty separator into
individual UTF-16 units. Undefined separators and empty input retain their source
branches. The current realm's Array prototype remains an explicit dependency.
RegExp builtin replace/split shortcuts, their concrete symbol methods, and regex
execution remain pending; translated hooks use ordinary GetMethod and Call.

StringPrototype initialization, the remaining 10 native bodies (`endsWith`,
`includes`, `localeCompare`, `match`, `matchAll`, `replaceAll`, `search`,
`startsWith`, `toLocaleLowerCase`, `toLocaleUpperCase`), trimLeft/trimRight aliases,
bytecode builtin optimization metadata, production String installation and
primitive Reference integration remain pending.

RegExp flag preparation (`aacfa8d`) translates the source bit order, strict
initialization validation and the constructor's separate permissive bit mapping.
Bad characters and repeats are reported in scan order before the final incompatible
u/v check. Diagnostics preserve every offending UTF-16 unit, including NUL and
lone surrogates, following AK's char16_t formatting path. The VM boundary creates
a SyntaxError without losing those units.

ParsePattern preparation (`85171dc`) translates the named-capture discovery and
named-backreference scans, including escaped delimiters, character classes and
lookbehind exclusion. Named-group validation tracks literal, fixed-escape and
braced-escape origins: literal pairs and two fixed surrogate escapes are accepted,
mixed origins and braced surrogate pairs are rejected. Legacy identity `\k`
escapes remain unchecked when no named capture exists. Non-ASCII units become
legacy fixed escapes or Unicode braced escapes, combining literal surrogate pairs
in u/v mode and preserving preceding-backslash parity. This preparation is not
regex grammar compilation: ASCII grammar errors, empty/invalid identifiers and
truncated groups remain for the pending ECMAScriptRegex backend. Its direct VM
boundary reports the original SyntaxError text; RegExpInitialize's separate
compile-error wrapper remains pending.

RegExp source escaping (`51cb1f4`) translates the stored-pattern helper with the
pattern passed explicitly. Empty input becomes `(?:)`, slash escaping follows
character-class state, and all four line terminators are escaped with or without
a preceding backslash. Code-point iteration retains supplementary pairs and lone
surrogates. The source's pending u/v-specific escaping and omission of a dangling
terminal backslash are preserved; no new grammar or matcher is substituted.
RegExp records, allocation/initialization, constructor/prototype methods, symbol
methods, bytecode shortcuts and production installation remain pending.

LibRegex AST records (`d1a52c38`) translate the complete current `ast.rs` model:
disjunctions, alternatives, terms, flags, captures, all eleven atoms, all
character-class range and set-expression operands, lookarounds, backreferences
and modifier groups. Quantifier factories and builtin-class complements retain
the source values. Recursive cloning copies every mutable array, including
nested class strings and grouped bodies; focused tests cover every variant and
mutate clones independently of their originals.

LibRegex bytecode records (`70ac96e2`) translate the complete current
`bytecode.rs` model, all 29 instructions and seven simple-matcher variants.
Program initialization reserves the two group-zero registers; emission and
current-offset methods retain instruction indices. Jump patching retains
unresolved-split priority, repeated sentinel patches and all three invalid-patch
panic boundaries. Program/matcher clones own independent arrays and recursive
union boxes. WTF-16 encoding preserves lone surrogates and rejects values above
U+10FFFF without changing output. Unicode property-kind decoding and resolved
metadata are translated; property lookup is pending.

LibRegex input primitives (`70973e69`) translate both source `Input` slice
implementations, their inherited operations, Unicode/WTF-16 decoding and
code-point widths. Capture copying clips to both buffers and the declared slot
count. Empty-match search advancement retains the source's one-code-unit step.
Whitespace and line-terminator predicates, the tri-state VM result and the
10,000,000-step limit are retained. The UTF-16 override's comparison of two
invalid ranges remains true; ASCII searches/needles reject non-ASCII values,
while raw code-unit reads and range comparisons retain byte values. These
records and helpers do not execute regex bytecode. Parser/compiler translation
and full VM instruction execution remain pending.

LibRegex pattern analysis (`0f50cf23`) translates the complete current
`PatternHints`/`analyze_pattern` path. Control-flow successors preserve order and
duplicate edges, and literal suffixes require a single linear predecessor chain.
Capture/modifier bookkeeping is skipped exactly as upstream before WTF-16 suffix
assembly. Analysis retains first-character and class/greedy-loop filters, leading
anchors through positive lookahead, one/two-literal alternative start hints,
trailing and required literals, all four simple-scan variants and the supplied
empty-match flag. Filters and scans own independently cloned arrays/union boxes.
The optional AST required literal is copied where Rust moves its vector.
Common-first-character analysis compares code points only and keeps the preferred
branch's case flag. The broad `Save(1), Match` required-literal arm also wins
before the later end-anchor arm: an intervening `AssertEnd` blocks bytecode
required-literal extraction even when a trailing hint is available. Both source
behaviors are preserved and tested.

LibRegex literal prefilters (`464daa72`) translate exact substring search,
ASCII-only insensitive search/comparison, the complete UTF-16 ASCII folding
helper, optional trailing/required-literal rejection, and start-position scans.
Empty substring needles succeed even beyond input length; direct comparisons
still require a valid position. Start hints give input position zero priority,
then search one or two units. The one-unit ASCII path rejects a non-ASCII needle,
while the two-unit path compares raw input units. These are candidate rejection
helpers; candidate selection and simple-scan execution are translated below.
The regex VM instruction loops remain pending.

LibRegex VM storage (`46a2cbf9`) translates `SavedState`, `ActiveModifiers`,
`VmScratch` and the VM record, construction/reset, flat register snapshots, all
four saved-choice creation methods and modifier push/pop. A VM retains a stable
program and scratch owner, resets every source scalar and vector, and preserves
allocated storage across resets. Modified choices update their copied register
only; live registers remain unchanged. Restoring a snapshot validates the whole
slice before any write, including empty register sets. Focused tests cover owner
identity, retained capacities, independent snapshots, all choice metadata,
nested modifier overrides including explicit false, and three invalid-snapshot
panic conditions in child processes. Saved-choice execution is translated in
the backtracking slice below.

LibRegex repetition (`3e68014b`) translates repeat-start/check and same-matcher
loop suffix minima. Minimum counts take priority over maximum counts. Greedy
checks retain the old counter in the exit choice before incrementing the live
counter; lazy checks increment only the deferred body choice. Counter arithmetic
matches optimized Rust release-mode wrapping at the signed/unsigned boundaries.
Suffix minima scan only consecutive greedy/lazy loops with equal matcher values,
stop at a different instruction or matcher, reject u32 overflow and return no
value for an all-zero suffix.

LibRegex character traversal (`0f3db694`) translates current-code-point reads,
directional advancement, one-character movement and multi-character movement.
Unicode reads reject an interior boundary between surrogate halves in either
direction; complete pairs decode together and lone surrogates remain code points.
Raw byte views retain non-ASCII bytes. Unicode multi-character movement stops
when it cannot advance; non-Unicode movement uses checked position arithmetic
without clamping the result to input length. These helpers do not perform
character matching, Unicode property resolution or case folding.

LibRegex case folding and builtin classes (`9db85440`) translate the VM's
ASCII shortcuts, folding equality and word/digit/builtin predicates, plus
LibUnicode's canonicalization body. Unicode mode calls ICU's simple folding;
legacy mode calls its full UTF-8 uppercase map, retains multi-code-point
expansions unchanged and prevents a non-ASCII input from canonicalizing to ASCII.
WTF-8 lone surrogates retain the upstream result. Equal operands return before
folding, including invalid legacy code points. The source invalid-code-point
assertion becomes a V panic. ICU remains the native algorithm/data dependency.
Property resolution, case closure and inverse-range matching are translated
separately below.

LibRegex VM character matching (`4c2e5efa`) translates literal matching with
active case modifiers, advancing only after success in the current direction.
Unicode reads retain the pair-interior rejection from character traversal.
Word boundaries inspect the adjacent raw code units regardless of direction;
the Unicode word extension requires both Unicode mode and active ignore-case.

LibRegex backreferences (`44a111e6`) translate the complete numbered, Unicode
and named comparison bodies. Missing/unmatched groups succeed without consuming
input. Legacy references compare code units; Unicode references compare code
points and walk backwards by the captured code-point count before comparing
forwards. Failed comparisons leave the VM position unchanged; successful ones
commit their final position. Duplicate names select the first participating
capture in program order, even when it is empty or subsequently fails to match;
they do not retry another participating duplicate. The decoder retains the
source's handling of capture boundaries that cut a surrogate pair. Register
and input ownership stay with the retained VM scratch/program/input records;
these comparison bodies do not execute the backreference opcodes yet.

LibUnicode case closures and inverse-range matching (`2d1d983e`) translate
`expand_range_case_insensitive`, `for_each_case_folded_code_point`, the bounded
`unicode_get_case_closure`/Rust wrapper and `code_point_matches_range_ignoring_case`.
Closures iterate sorted code-point ranges, exclude full-fold string items and
stop at the supplied buffer length without changing unused output. Expansion
returns independent sorted ranges. Inverse matching preserves the direct-hit
shortcut and canonicalizes every retained candidate, including the legacy
non-ASCII-to-ASCII and expanding-uppercase exclusions. Native ICU endpoint
clamping and signed UChar32 conversion are preserved.

LibRegex character classes (`57ff997b`) translate `char_in_ranges` and the
complete `match_char_class` body. Small arrays use inclusive linear membership;
arrays larger than eight use Rust's base/size binary-search path. Ignore-case
UnicodeSets matching uses the source's 16-code-point closure buffer. Other
ignore-case modes check the original character, its canonical form and inverse
range membership without folding range endpoints. The UnicodeSets branch
retains upstream's independence from the supplied Unicode-mode flag.

LibRegex simple-scan membership (`cbf8f91c`) translates the complete private
`match_simple_scan` predicate: raw class membership with negation, all builtin
classes in legacy mode and exact literals. The greedy-quantifier variant returns
false because upstream handles it in the separate execution caller, translated
below. This predicate adds no substitute execution.

Unicode property lookup and matching (`7771d968`) translate the exact ICU alias
tables, aggregate category masks, binary and synthetic properties, script and
script-extension membership, cached frozen case-closed sets, name/value
resolution, direct resolved-ID queries and ECMAScript property validation.
Alias comparisons retain source spelling and lookup priority instead of ICU's
loose name matching. Missing and explicitly empty values remain distinct;
literal script names can resolve for queries while remaining invalid as lone
ECMAScript property escapes. Any/all case-equivalent queries preserve their
opposite short-circuit conditions. Space-separator and identifier predicates
retain the Rust ASCII shortcuts and native scalar behavior. Cached sets are
retained for the process lifetime, as in upstream's NeverDestroyed maps.

Unicode string properties (`a02a44f6`) translate all seven ECMAScript string
properties, enumeration order and the complete packed count/length/code-point
format. Single-point entries are excluded from the packed multi-point list.
Null/zero-capacity queries and undersized buffers report the required size without
writing; successful writes preserve the unused tail. The Rust wrapper queries,
allocates, validates the returned size and truncates its independent result.
ICU's frozen property sets remain library-owned and are never closed or modified.

LibRegex simple-match predicates (`834c7847`) translate all three current bodies
and the four VM Unicode property forwarders. Raw matching compares both stored
`CharNoCase` operands; modifier-only matching folds its first operand in legacy
mode, while VM matching uses the program's Unicode mode. Literal/class/dot
queries retain active modifier overrides; builtin classes and property paths
keep each helper's distinct source rules. Resolved property IDs take priority
over names except in the VM's ignore-case Unicode closure path. Negated `u`
properties complement the all-case-equivalents query, while `v` properties
complement the any-case query. Nested unions preserve short-circuit recursion.
These predicates leave VM positions, instructions and step counts unchanged.

LibRegex candidate filtering (`83d8ea59`) translates `first_char_matches`,
`first_filter_matches` and `next_candidate_start`. First characters use the
hint's explicit case flag. First filters preserve raw range/property/literal
membership, the builtin Unicode-ignore-case rule and the dot payload flag.
Candidate scans skip surrogate interiors only for nonempty Unicode patterns,
then apply previous-code-unit anchor checks and both optional filters in source
order. Filtered end positions fail, while an unfiltered empty candidate can
retain the end or a requested surrogate interior. Unused hint fields do not
affect this helper; leading non-multiline anchor enforcement belongs to the
still-pending outer VM execution caller.

LibRegex simple scan execution (`24380ffd`) translates single-match, greedy
and find-all fast paths over supplied scan records. Unicode decoding advances
by code points while captures retain code-unit positions, including an explicit
starting position inside a surrogate pair. Greedy scans count code points,
enforce their bounds and skip insufficient runs. Failures leave caller output
untouched; successes write one pair and preserve unused slots. Find-all returns
`-1` on capacity exhaustion after retaining earlier complete pairs, and advances
one code unit after a zero-width result. Zero minimums retain upstream's
requirement to find a matching point and do not add an empty end-of-input match.
These helpers do not supply pattern parsing, compilation or general VM dispatch.

LibRegex fast greedy consumption (`ab80abb7`) translates all seven matcher
branches of `Vm::greedy_consume_fast`. Dot-all consumption clips directly to
the remaining code units and maximum count. Literal payloads narrow to u16
before comparison, while CharNoCase retains its first full code point. Classes,
builtin classes, resolved properties and unions retain their distinct legacy
case rules. V returns the count and updated position together because mutable
scalar arguments are unsupported; callers retain the source precondition that
the starting position does not exceed the input length.

LibRegex loop suffix measurement (`ff70c5dd`) translates directional
same-matcher availability and `same_matcher_loop_suffix_deficit`. Its explicit
measurement direction is independent of the VM's current direction. Unicode
reads advance or retreat by character boundaries, preserve active modifier
rules, and leave positions, instruction counters and step counts unchanged.
Only consecutive equal-matcher loops contribute their checked minimum sum;
zero or already-satisfied deficits produce no value.

LibRegex saved-choice execution (`7462eeae`) translates the complete
`Vm::backtrack` body. Normal choices restore their position, instruction and
register/modifier snapshots. Greedy choices restore snapshots before measuring
suffix deficits, preserve minimum consumption, skip directly to BMP or
supplementary literal candidates when allowed, and requeue only when more
characters can be returned. Their saved direction remains independent of the
VM's current direction. Lazy choices restore state before checking their
maximum, consume one matching code point, then requeue with the source count.
Failed choices recursively resume earlier choices without crossing the
backtrack floor. The instruction loops and lookaround callers remain pending.

LibRegex shared failure/assertion handlers (`bcaad7fc`) translate
`fail_current_path`, `handle_assert_start`, `handle_assert_end` and
`handle_word_boundary_assert`. Successful assertions advance only the instruction;
failures resume a saved choice or return NoMatch after exhausting the permitted
stack. Both the opcode's multiline flag and active scope enable line-terminator
checks. End assertions retain the fast caller's supplied input length, and word
boundaries retain adjacent-code-unit membership and Unicode-ignore-case rules.
No-value results mean execution can continue, including after a restored choice.

Default global intrinsic properties (`9a8cfb7a`) retain the order of the
available entries in `GlobalObject.cpp`: ArrayBuffer, Boolean, DataView,
SharedArrayBuffer and Symbol, then Math and the Annex B functions. Pending
intrinsics remain omitted. The exact own-key-order test includes the newly
installed Math property rather than silently filtering it out.

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

`browserjs.Runtime` owns a translated VM and initialized realm. Its explicit
`prepare_script()` boundary retains the LibJS parse and scope analysis alongside
the source URL, starting line, and script/module parse goal;
`evaluate_prepared()` reuses that parse. `evaluate()` and document scripts use
the selected backend's preparation. JavaScriptCore parses and validates their
full source directly. Their translated Script records retain the actual
`external_source_text`, realm, URL, starting line, host identity, and strictness
from the directive prologue. These records have no translated AST, and LibJS
bytecode compilation rejects them explicitly. LibJS execution still prepares
the complete translated AST. Classic execution pushes a Script context with
its realm and global environment, then removes it on success and failure.
Closing the runtime releases JavaScriptCore and clears the embedding stack.

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
The translated VM contexts describe the embedding boundary; JavaScriptCore
owns its internal frames and all syntax validation, including RegExp patterns
and programs beyond the translated frontend's 32-call guard. The explicit
frontend API retains LibJS's module parse goal. Browser execution rejects
modules before preparation because module execution remains pending.

The native command line selects the backend explicitly:

```sh
Build/v/Vox.app/Contents/MacOS/Vox --js-engine=javascriptcore page.html
Build/v/Vox.app/Contents/MacOS/Vox --js-engine=libjs page.html
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
# 221 passed, 221 total; the subsequently added print_test.v also passes

v -old-compiler -enable-globals -gc none test libjs
# 222 passed, 222 total

v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all
# LibJS AST corpus: 100 passed, 0 failed, 100 total

v -old-compiler -enable-globals test browserjs
# 18 passed, 18 total

v -old-compiler -enable-globals -gc none test browserjs
# 18 passed, 18 total

v -old-compiler -enable-globals test main_test.v
# 1 passed, 1 total

v -old-compiler -enable-globals test .
# Recursive enumeration also finds temporary worktree copies under Build/.
# Explicit canonical paths: 896 passed; 14 newly added files also passed.
# Six later files also pass; 916 canonical files verified.

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
set `LADYBIRD_SOURCE_DIR`. The frontend and regex Unicode helpers use the
bundled Unicode 17 V implementation; no ICU headers or libraries are required.


The VM tests exercise the runtime records directly and through compiled scripts.
Translated native functions cover call frames, arguments, receiver/realm state,
coercion, metadata, and failure cleanup. VM host-hook tests use controlled
`FunctionObject`, `Module`, `FinalizationRegistry`, `Agent`, and `ArrayBuffer`
fixtures; separate tests exercise translated NativeFunction and ArrayBufferObject
records. Module-loading tests write temporary module files. The preceding LibWeb
work passed its complete 656-file
suite, native headless smoke, and all 11 default screenshot comparisons before
this package; the 222 libjs files are verified separately in both GC modes.
The verified inventory contains 916 canonical repository test files.

All 916 canonical repository test files in the checked inventory are verified, including the native bridge,
eighteen browser integration files and all 222 LibJS files. The dedicated LibJS and
browser suites also pass in no-GC mode, exercising the retained storage and
buffer ownership independently of the collector.
The recursive root command was stopped after it discovered 3,554 files,
including temporary worktree copies under `Build/audit-fixes/worktrees/`.
The canonical list was selected with `git ls-files -co --exclude-standard`,
retaining `_test.v` paths outside `testdata`; all 896 selected files passed in
one eight-job command. Fourteen files added during that run passed in a fresh
two-job command; six later binary-limits, memory-instantiation, media-seek,
cSHAKE, animation-cancel and element-geometry files also passed. No test case was
filtered by its result. The earlier sixteen-job run's eleven code-9 exits were
already verified by a fresh two-job run, as recorded in `692d54bc`.
The first LibJS batch found the stale global-order expectation after Math was
installed; `9a8cfb7a` corrects source order and the expectation. A fresh complete
221-file GC run passes, and the later print test passes separately. The fresh
no-GC run covers all 222 files.

String validation and repair tests additionally compare 2,388 UTF-16 inputs,
validity flags and repaired outputs exactly against simdutf 7.4.0. Regenerating
with `python3 tools/libjs_utf16_corpus.py --output /tmp/string-well-formed.tsv`
and comparing that output with `libjs/testdata/string-well-formed.tsv` is
byte-exact. `--simdutf-prefix` selects the pinned native dependency installation.

RegExp preparation additionally matches 9,202 exact native LibJS/AK cases in
both GC modes (`f3cde61`). The fixture compares flags, UTF-16 diagnostics, named
group validation, preprocessing and source escaping without case overrides.
Regenerate it with
`python3 tools/libjs_regexp_preparation_corpus.py --output /tmp/regexp-preparation.tsv`
and compare with
`libjs/testdata/regexp-preparation.tsv`. The driver extracts the current pinned
upstream C++ bodies and compiles AK and ErrorTypes afresh in a temporary directory;
only the member-helper signature and its Flags declaration carrier are adapted.
It uses ASan and the manifest's simdutf 9.1.0 dependency, selectable with
`--simdutf-prefix` (the default is Homebrew's simdutf). The stale native Ladybird
build still has simdutf 7.4.0; the earlier scalar validation/repair and codec
fixtures above validate that older dependency's paths, not full 9.1.0 parity.
`--upstream`, `--build-dir` and `--dependency-prefix` select source/generated-header
and fmt locations. Checked-in fixtures keep ordinary V builds independent of the
native oracle. Regeneration is byte-exact.

The ten Rust-based regex oracle drivers named in the following paragraphs
(`tools/libjs_regex_*_corpus.py`) were retired when Rust was removed from the
repository; see [the reference-corpus guide](../tools/REFERENCE_CORPORA.md).
Their checked-in fixtures are frozen independent records, verified by
`tools/check_translation_corpora.v --suite regex`. The regeneration commands
below record how the fixtures were produced and can no longer be run.

LibRegex core helpers additionally match 36,166 native Rust cases exactly in
both GC modes (`0586dcb0`). The fixture covers quantifiers, builtin-class
complements, property-kind decoding, WTF-16 encoding, program offsets and jump
patching, capture copying, search advancement, predicates and both input views.
The driver also checks the source's three invalid-patch panic conditions; focused
V tests exercise them in child processes. Regenerate with
`python3 tools/libjs_regex_core_corpus.py --output /tmp/regex-core.tsv`
and compare with `libjs/testdata/regex-core.tsv`. The oracle imports the pinned
AST, bytecode and Unicode record modules unchanged, copies the complete VM
module unchanged, and appends access wrappers for three private helpers. It
requires Rust edition 2024 (`RUSTC` selects the compiler), but no Cargo build or
native Unicode libraries: parser, compiler, matcher and Unicode FFI functions
are never invoked. There are no case overrides, and regeneration is byte-exact.

Pattern analysis and literal prefilters match another 112,458 exact native Rust
cases in both GC modes (`e22e2738`), including 19,208 complete hint records,
control-flow/suffix checks and all 65,536 UTF-16 units for ASCII folding.
`tools/libjs_regex_hints_corpus.py` imports the same unchanged record modules and
complete VM source, adding access/serialization wrappers for private metadata
and helpers. It never invokes parser/compiler, VM execution or Unicode FFI.
Regenerate with
`python3 tools/libjs_regex_hints_corpus.py --output /tmp/regex-hints.tsv`
and compare both `/tmp/regex-hints.tsv` and `/tmp/regex-hints-fold.tsv` with
their counterparts under `libjs/testdata/`. Folding cases are a separate asset
to keep each V embedded fixture below 5 MB. Every output field compares exactly,
there are no case overrides, and both regenerated files are byte-exact.

VM state and character traversal match another 14,942 exact native Rust cases
in both GC modes (`cd941a12`): 1,400 state transcripts compare construction,
reset, snapshots, saved choices, modifiers and repetition after every transition;
12,830 cases compare directional traversal, 24 cover checked position arithmetic
at usize boundaries, and 688 cover same-matcher suffix minima. The oracle also
checks three invalid-snapshot panic conditions, exercised by V child-process
tests. It imports the unchanged AST, bytecode and Unicode record modules and
complete VM source, appending only construction/access/serialization wrappers.
Optimized Rust arithmetic is the reference. Matcher dispatch, backtracking
execution and Unicode FFI are never invoked. Regenerate with
`python3 tools/libjs_regex_state_corpus.py --output /tmp/regex-state.tsv`
and compare with `libjs/testdata/regex-state.tsv`. Every state and helper output
compares exactly without case overrides; regeneration is byte-exact.

Case folding and VM matching helpers match another 113,204 exact native cases
in both GC modes (`e643533c`). The 67,118 folding cases include every BMP code
point, the complete Deseret case ranges and selected supplementary points;
each compares legacy/Unicode results, word predicates and all six builtin
classes. The remaining cases compare 27,704 literal matches, 9,344 word
boundaries, 6,561 numbered references, 1,595 named references and 882 folding
equalities, including both input views, modifiers, directions, clipped pair
boundaries and missing/partial captures. The native invalid-code-point assertion
is also checked; a focused V test exercises its panic in a child process.
`tools/libjs_regex_matching_corpus.py` imports unchanged Rust records and the
complete VM module with access wrappers. It extracts unchanged canonicalization
and UTF-8 uppercase C++ bodies and compiles AK afresh with ASan and simdutf 9.1.0;
it uses pinned ICU 78.2 for the oracle and the system ICU 78.1 for the V checks.
Both run with the explicit `en_US_POSIX` locale. No parser, compiler, matcher
dispatch or backtracking execution is invoked. Regenerate with
`python3 tools/libjs_regex_matching_corpus.py --output /tmp/regex-matching.tsv`
and compare `/tmp/regex-matching.tsv` and `/tmp/regex-matching-fold.tsv` with
their counterparts under `libjs/testdata/`. The split keeps each embedded asset
below 5 MB. All fields compare exactly without overrides, and regeneration is
byte-exact. Source/build/dependency/compiler options select alternate native
locations; the ordinary V tests use checked-in fixtures.

UnicodeSet, character-class and simple-scan membership helpers (`edeafbcb`) match
another 255,240 exact native records in both GC modes: 66,759 bounded closures, 38 range
expansions, 3,990 inverse-range checks, 19,935 range-membership checks, 152,143
class checks and 12,375 scan predicates. Each class record compares all eight
ignore-case/Unicode/UnicodeSets flag combinations; each inverse record compares
both canonicalization modes. These cover every BMP point, selected supplementary
points, lone surrogates, empty/reversed intervals, the eight-range search
threshold, zero/truncated/unused closure buffers and invalid ICU endpoints.
The corpus uses 87 shared range arrays to keep each embedded asset below 5 MB.
`tools/libjs_regex_class_corpus.py` imports unchanged Rust modules and extracts
the exact C++ UnicodeSet and closure FFI bodies. It shares the fresh ASan AK/ICU
build with the matching oracle (`c01a8cb1`); that refactor preserves every existing
matching fixture byte for byte. The same explicit locale and ICU versions apply.
Regenerate with `python3 tools/libjs_regex_class_corpus.py --output /tmp/regex-class.tsv`
and compare all four `regex-class*.tsv` files with `libjs/testdata/`.
All output fields compare exactly without overrides, and regeneration is byte-exact.
No parser, compiler, Unicode property resolution, scan execution, backtracking
dispatcher or VM execution is invoked.

Unicode property helpers (`839a1091`) compare 129,233 native records exactly in
both GC modes: 996 alias records, 61,938 low-level membership checks, 66,244
named-property/scalar records and 55 complete string-property records. Alias
records cover all category/binary/script IDs, all three native name choices,
eight spelling/whitespace/NUL variants and named-value forms. Each named record
compares sixteen queries through raw, any-case, all-case and resolved paths,
plus all three Rust scalar predicates. These include every BMP point, selected
supplementary points, invalid scalar boundaries and Apple's legacy private-use
range. Low-level checks compare both cached case-sensitivity modes, aggregate
categories and script extensions. String records compare complete packed vectors,
query/short/exact/oversized buffers and untouched sentinel tails.
`tools/libjs_regex_property_corpus.py` imports unchanged Rust wrappers and the VM
module, extracts the C++ CharacterTypes property bodies and ICU UTF-16 conversion
helpers, and uses the existing fresh ASan AK build. The native oracle uses ICU
78.2; dedicated macOS V tests bind standard ICU 78.3, both with Unicode 17.0.0.
No fixture is overridden to compensate for Apple's tailored libicucore data.
Regenerate with `python3 tools/libjs_regex_property_corpus.py --output /tmp/regex-properties.tsv`
and compare all three `regex-properties*.tsv` files with `libjs/testdata/`.
Each embedded asset is below 5 MB; every output is exact and regeneration is
byte-exact. Parser/compiler, matcher dispatch, backtracking and VM execution
are not invoked.

Simple-match predicates and candidate filters (`602a2b96`) compare 389,048
native records exactly in both GC modes: 151,248 simple-match bit vectors,
52,200 candidate positions and 185,600 first-character results. Each bit vector
compares raw matching, four active-modifier combinations and sixteen VM/first-
filter program combinations. The 37 supplied matchers cover all variants,
nested unions, conflicting `CharNoCase` operands, raw/resolved properties,
invalid names and the negated `u`/`v` distinction. Negated uppercase classes and
lowercase properties cover every BMP code point plus supplementary samples.
Candidate/first-character cases cover both input types, every supplied start,
empty inputs, surrogate interiors, anchors, combined filters and ignored hints.
`tools/libjs_regex_predicate_corpus.py` uses unchanged Rust helper bodies and
the same fresh ASan native property backend; no VM execution loop is invoked.
Regenerate with `python3 tools/libjs_regex_predicate_corpus.py --output /tmp/regex-predicates.tsv`
and compare all six `regex-predicates*.tsv` files. Regeneration is byte-exact,
and every split embedded asset remains below 5 MB.

Simple scan execution (`1d3dcb52`) compares 32,481 native records exactly in both
GC modes. The 27 supplied scans cover all variants, greedy minimum/maximum and
zero bounds, unions, raw properties, supplementary points, failed runs and
requested surrogate-interior starts. Each record compares the complete
single-match buffer and eight find-all capacities, including zero, odd-sized,
exact and oversized buffers. Greedy records also compare the direct helper
against its scan dispatcher. Partial successful pairs and untouched sentinel
tails are exact. `tools/libjs_regex_scan_corpus.py` reuses the native property
oracle and imports unchanged scan bodies; parser/compiler, backtracking and
general VM execution are not invoked. Regenerate with
`python3 tools/libjs_regex_scan_corpus.py --output /tmp/regex-scans.tsv` and
compare all three `regex-scans*.tsv` assets. Regeneration is byte-exact, with
each split asset below 5 MB.

Loop consumption and saved-choice execution (`8d33d8bd`) compare 356,554 native
records exactly in both GC modes: 73,632 fast-consumption cases, 165,672
directional availability cases, 110,448 suffix-deficit cases and 6,802 complete
backtracking traces. Traces include the initial state and four subsequent
calls, comparing the success flag, position, instruction, steps, direction,
floor, registers, snapshot pool, modifier scopes and every remaining saved
choice. Fixtures cover all seven matcher variants, legacy/Unicode/UnicodeSets
case differences, surrogate interiors, both saved greedy directions,
literal skipping, checked suffix overflow, finite/unbounded lazy maxima and
recursive fallback. `tools/libjs_regex_backtrack_corpus.py` imports unchanged
Rust bodies and freshly builds native LibUnicode/AK with ASan. Regenerate with
`python3 tools/libjs_regex_backtrack_corpus.py --output /tmp/regex-backtracking.tsv`
and compare all six `regex-backtracking*.tsv` assets; regeneration is byte-exact
and each embedded file is below 5 MB. The oracle supplies fixture programs and
saved choices; no parser, compiler, VM instruction loop or lookaround body runs.

Shared failure/assertion handlers (`333afb69`) compare another 9,119 complete
native state traces exactly in both GC modes: 2,290 current-path failures,
2,280 start assertions, 2,278 end assertions and 2,271 word-boundary assertions.
Each trace includes four handler calls, supplied opcode flags and end-length
bounds, active modifiers, no-choice/floor-exhausted failures, and normal/greedy/
lazy alternatives. The assertion result and every VM, register, snapshot,
scope and saved-choice field are exact. Regenerate with
`python3 tools/libjs_regex_assertion_corpus.py --output /tmp/regex-assertions.tsv`
and compare with `libjs/testdata/regex-assertions.tsv`; regeneration is byte-exact
and the embedded file remains below 5 MB. The driver reuses the freshly built
native oracle and does not invoke regex grammar, instruction-loop or lookaround
execution.

Browser integration checks pass the eighteen `browserjs` test files in both GC modes,
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
These checks create no JavaScriptCore context. Their explicit HostObject fixture
remains separate from the installed ObjectPrototype record.
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
Number browser integration (`c06582e`) likewise supplies the translated complete
records under a test host name. Compiled scripts exercise constants, parse aliases,
noncoercing predicates, ties-to-even BigInt conversion, wrappers, bound calls and
construction, fixed/scientific/radix methods, locale plumbing and recovery from
brand/range/conversion failures. AK decimal forms and the Intl marker are test-only
dependencies; no JavaScriptCore context or partial production Number global is used.
String browser integration (`e84decb`, `74c9839`, `9c8a27d`, `24549b2`) supplies
the complete constructor under HostString and attaches the thirty-nine translated
prototype bodies to a test-only
String exotic record. Compiled scripts exercise static character/raw creation,
UTF-16 wrappers, slicing/search, branding, concatenation, trimming, well-formed
repair, iterator exhaustion, bound calls/construction and recovery after seven
conversion/brand/range errors. The fixture does not implement StringPrototype
initialization or install a production String global; no JavaScriptCore context
is created.
The expanded browser checks (`74c9839`) also exercise repetition, bound repeat
calls, padding through surrogate halves, filler/empty-receiver shortcuts, all
thirteen HTML wrappers and recovery after five additional count/attribute errors.
Unicode checks (`9c8a27d`) exercise casing expansions, contextual sigma, all four
normalization forms, raw UTF-16/NUL preservation, bound methods, zero-length
metadata and recovery after five form/receiver errors through browser bytecode.
Replacement/splitting checks (`24549b2`) execute template substitution, literal
native callback results, bound methods, actual Array results, Uint32 wrapping,
surrogate-half splitting, raw symbol-hook dispatch and recovery after five
conversion/receiver errors. Native callbacks, hook objects and the Array prototype
are explicit test fixtures; ECMAScript functions and Array intrinsics remain pending.
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
- Number constructor/prototype records retain explicit Object and parse-function
  intrinsics rather than installing an incomplete production global. The pinned
  AK decimal-form helper uses fmt/Dragonbox; it remains an explicit untranslated
  callback. Tests supply decimal-form fixtures, without adding a host conversion
  implementation. Exact fixed/scientific integer rounding uses the existing V
  `math.big` substrate instead of LibCrypto storage; decimal digit counts/strings
  use that substrate's decimal output. Ordinary decimal NumberToString continues
  to use the previously documented V shortest-digit backend. Nondecimal output
  preserves the upstream fixed fractional precision and floating-point division.
  Intl NumberFormat/FormatNumeric dependencies likewise stay explicit; their
  tests assert argument/realm/numeric/UTF-16 forwarding only.
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
- String constructor/prototype native bodies use flat UTF-16 arrays in place of
  AK builders, substring views, ropes and short-flat concatenation branches.
  Empty concatenation retains primitive-cell identity; other results preserve
  exact code units. V's signed-int array length remains narrower than upstream
  size_t; allocation failures retain the existing V storage boundary. Search
  and simdutf validation/repair use scalar loops without native SIMD dispatch.
  The 2,388-case oracle verifies validation and repair output, not native speed.
  String's prototype/boxing dependencies and @@iterator prototype getter are
  explicit until the complete intrinsic graph exists. fromCodePoint retains
  the pinned body's ToInt32-before-range-check wraparound. StringFromCharCode,
  StringCharAt and StringCharCodeAt bytecode builtin shortcuts remain pending.
- repeat retains source checked-product RangeErrors and reports the same overflow
  error above V's 2^31-1 code-unit capacity. StringPad has no corresponding source
  length RangeError; the V body uses the existing string-size RangeError when a
  nonempty padded result would exceed that capacity. This storage deviation is
  checked after length/filler conversion and the source early returns, so huge
  lengths with an empty filler still preserve identity and filler errors still
  win. Allocations within the representable range retain V's allocation behavior.
- Unicode casing and normalization retain the native ICU algorithm/data backend.
  V implements the source receiver/form control flow, ASCII casing and failure
  policy; UTF-16 C API capacity preflight replaces C++ UnicodeString allocation.
  The native header supplies ABI declarations only. The verified macOS system
  library is ICU 78.1.0 and upstream's pinned dependency is ICU 78.2.0; both report
  Unicode 17.0.0. This version check and the focused output tests do not establish
  full ICU backend/data parity. Linux uses its installed libicuuc and data.
  Flat V string lengths and allocation remain the existing storage boundary;
  upstream's storage tiers and its ICU C++ buffer management are not translated.
  Intl locale canonicalization/matching and collation remain pending.
- String replacement, splitting and GetSubstitution use flat UTF-16 views and
  arrays instead of AK builders and shared substring cells. They retain V's signed
  array-length/allocation boundary. split receives the current realm's Array
  prototype explicitly. RegExp's tagged builtin replace/split shortcuts and native
  symbol methods remain untranslated; ordinary symbol hooks use the existing
  GetMethod/Call path without a replacement regex implementation. Native callbacks
  work, while ECMAScript function objects remain pending.
- RegExp preparation uses flat V UTF-16 arrays instead of AK builders/views and
  retains V's signed array-length/allocation boundary. Source escaping receives
  the original pattern explicitly until the real RegExp record exists. Named-group
  surrogate validation does not validate identifiers or complete regex grammar;
  the exact native corpus covers helper behavior only. Upstream's pending u/v
  source-escaping logic and trailing-backslash omission remain visible.
- LibRegex tuple/unit variants use named V sum payload records; flat arrays
  replace Rust vectors and boxed slices, and Unicode property payloads are
  stored by value. Recursive simple-matcher unions use heap-owned boxes, with
  value equality and independent clone storage. Immutable UTF-8 strings share
  backing storage when cloned. Class-string `[]rune` values represent Rust
  `Vec<char>`; the V grammar parser enforces Unicode scalar validity for its
  character input, class strings and group names, while escaped literal `u32`
  values preserve WTF-16 lone surrogates.
- Regex input records expose read-only views of caller-owned arrays; callers
  must retain stable backing storage without Rust's borrow checker. Positions
  use `usize`, while V arrays retain their signed capacity boundary. Bounds
  checks avoid overflowing position-plus-length arithmetic on invalid callers;
  byte-view range comparisons therefore return false for such arguments instead
  of entering the source trait's unchecked arithmetic/indexing path. Jump-patch
  panics retain the source conditions but use V record dumps instead of Rust's
  Debug text. The native corpus validates helper values and does not establish
  parser, compiler, Unicode-property or matcher conformance.
- Pattern-hint tuple and enum payloads use named V records. Supplied AST
  required literals are cloned instead of moved, because V callers can retain
  their argument after analysis. Source bytecode filters/simple scans likewise
  retain independent mutable storage. Literal search uses the same
  subtraction-based bounds adaptation as the input primitives for overflowing
  invalid caller positions. Split-chain analysis retains upstream's expectation
  of compiler-generated acyclic leading alternatives; recursive anchor/first
  probes advance through the supplied instruction vector. No parser or matcher
  implementation is substituted for these prefilters.
- Regex VM programs and scratch owners use stable heap records; one scratch
  reference replaces Rust's four exclusive vector borrows. Callers retain the
  program, input and scratch and use one active VM per scratch without a Rust
  borrow checker. V array resizing preserves storage when capacity permits,
  but allocator and capacity-growth behavior are not Rust Vec parity. Register
  counts above V's signed array capacity are rejected before narrowing. Snapshot
  bounds use subtraction-based validation and V panic text; overflowing invalid
  caller indices are guarded rather than following unchecked release arithmetic.
  Repeat counters preserve optimized Rust's wrapping arithmetic; Rust debug-mode
  overflow panics are not claimed. Character traversal preserves the source's
  surrogate-interior rejection and unclamped non-Unicode checked arithmetic.
- Regex legacy canonicalization uses flat WTF-8 arrays and ICU's C full-uppercase
  API instead of AK's short-string/builder storage and ICU's C++ CaseMap API.
  Preflight replaces builder growth; failed native maps retain the original
  code point, and the complete BMP native comparison includes lone surrogates
  and expanding uppercase maps. Invalid legacy code points use V panic text
  instead of AK assertion text. Unicode folding retains the native scalar ICU
  ABI, while ASCII shortcuts and the non-ASCII-to-ASCII exclusion follow source
  control flow. The native oracle uses ICU 78.2 and the macOS V runtime uses
  ICU 78.1, both with Unicode 17.0.0; the compared helpers do not establish full
  ICU/data parity. Linux uses its installed ICU. Backreference methods retain
  upstream's expectation of valid capture ranges and VM positions; they share
  the existing V input-view bounds behavior and signed array capacity limit.
- Regex UnicodeSet operations use ICU's C USet ABI instead of the source's C++
  UnicodeSet objects. Every transient set is closed on all returns, independent
  of V GC. A null native allocation becomes a V panic; native allocation-failure
  behavior is not claimed. Range enumeration excludes string items exactly as
  the source does; output arrays retain V's signed capacity bound. Large range
  membership follows the current Rust slice base/size binary search and the
  source expectation of sorted compiler-generated ranges. The native corpus
  also compares supplied reversed/unsorted arrays without adding a fallback.
- Unicode property alias tables and NeverDestroyed maps use module-owned V
  arrays/maps. Native alias strings remain ICU-owned, and frozen case-closed
  sets intentionally live for the process lifetime. Initialization assumes the
  current single-agent runtime; C++ local-static initialization guards are not
  reproduced. General-category IDs retain the source's valid-ID precondition;
  undefined invalid-category shifts are not claimed. Allocation failures use V
  panic text and V's signed array bound instead of native allocator behavior.
  On macOS, private bindings select the standard ICU 78 ABI for property data;
  its opaque sets have a distinct V type and never enter libicucore's set API.
  Case-equivalent property queries retain ordered V range arrays instead of the
  source's callback frame. String enumeration decodes ICU UTF-16 items directly
  to code-point arrays instead of passing through AK UTF-8 Strings; range items,
  string order, filtering and complete packed output compare exactly.
- Simple-match and candidate helpers expose source-private predicates as V
  package functions; union boxes use the existing stable V ownership model.
  First-filter callers must provide an in-bounds position, matching the source
  caller's precondition. Single-match scan callers provide at least two capture
  slots, and greedy bounds retain the compiler's `min <= max` precondition.
  Invalid generated bounds are not repaired with an alternate scan algorithm.
  V arrays replace Rust slices and the local two-slot find-all array; successful
  pairs, partial capacity-exhaustion output and unused tails compare exactly.
  These fast paths are exposed over supplied bytecode records while production
  RegExp parsing, compilation and general VM dispatch remain untranslated.
- Checked string length sum/product retain upstream's 2^32-1 code-unit maximum.
  TypedArray join and toLocaleString assemble flat V UTF-16 arrays instead of
  AK's builder and throw the same string-size RangeError above V's 2^31-1 array
  capacity before an append can overflow that representation.
- Iterator records and result variants use V heap records and explicit done
  flags. Intrinsic parents are supplied by callers; no Iterator/Object/Array
  prototype substitute is installed. Synchronous acquisition currently accepts
  object receivers. Primitive GetMethod exists with explicit prototype inputs;
  String iterator intrinsic installation, async acquisition, Iterator helpers and
  builtin-marker fast paths remain pending. Array iterator next uses
  the translated TypedArray witness path as well as ordinary array-like lengths.
  String iteration uses code-unit offsets over the retained flat string rather
  than AK iterator pointers. Array key/entry indices preserve the pinned source's
  i32 conversion, including its wraparound for indices at or above 2^31.
- Owned DataBlock allocation and external storage use actual PrimitiveStorage
  handles, size_t lengths/capacities, cage offsets and source chunked copy/move
  operations. Native storage errors reach the allocation RangeError. Borrowed
  ByteBufferStorage and byte-vector copy results retain V's signed-int length
  limit and allocation-panic boundary; readonly callbacks can consume the actual
  native span without a vector copy. External owners retain actual pointers,
  while source GC cell visitation, automatic owner destruction, external-memory
  accounting and cached TypedArray offset invalidation remain untranslated.
  Explicit prototypes select host-created buffer/view records;
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
  Number/BigInt locale native bodies retain explicit NumberFormat/FormatNumeric
  dependencies; Intl formatting remains untranslated.
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
  override. The ObjectPrototype record is allocated before Function.prototype
  and initialized afterward. Its toString body handles supported internal slots
  and observable @@toStringTag reads; Arguments, Date, RegExp and Proxy records,
  the Object constructor link and the complete primitive prototype graph remain
  pending.
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

The standalone ECMAScript regex grammar is translated in `regex_parser.v`,
`regex_parser_escape.v` and `regex_parser_class.v`. `parse_regex_ast()` and
`parse_regex_ast_chars()` produce the existing concrete AST, and
`parse_regex_ast_flags()` preserves the source flag errors. The grammar covers
Annex B numeric/control/identity escapes, forward and named backreferences,
duplicate-name alternative scopes, capture numbering, quantifiers, modifiers,
lookarounds, Unicode properties, nested Unicode sets and class strings. It has
an explicit 128-level combined group/class nesting limit for V stack safety;
this is distinct from the JavaScript parser's 32-call limit below.

The immutable `testdata/regex-parser.tsv` corpus records 3,018 complete ASTs or
original error messages from the byte-verified pinned Rust parser at
`963d46a829f3e1b79f44dba9d02afb70654300fa`. The temporary oracle used unchanged
Rust AST/parser/Unicode wrapper sources and the same translated Unicode exports
as the existing production Rust backend. Both GC modes pass the corpus,
deep-nesting and independent-owner tests. Separate tests cover all 256 flag
subsets, duplicates, invalid flags and the raw character-input scalar invariant.
Future fixture tests require no Rust compiler. Initial test-compilation failures
in sum narrowing and optional-name handling were corrected in the test
serializer; no failed attempt receives execution credit. Checks use current V,
`-enable-globals -memory-limit 10G -b c -cc clang`, with separate 3 GiB guards.
The bytecode compiler, fast/general VM dispatch, lookarounds, bounded
required-literal analysis and high-level `RegexEngine` are now translated too.
The frozen full-engine corpus compares 26,544 complete source results and
capture/output buffers in both GC modes. Ninety repeated-empty-class-string
UnicodeSets cases exhausted the source oracle's 3 GiB guard; separate V
regressions fix zero-progress repetition and compare captures with Node
v26.8.1. See [LibRegex status](../libregex/PORT_STATUS.md) for ownership,
limits and source-oracle boundaries. HTML input patterns use this V engine;
regex no longer builds or links a Rust archive.

The current broad check passes 241/243 files in each GC mode. The existing
regex folding and String casing fixtures fail on this host's ICU default-locale
Greek conversion; expectations were retained. All 100 current upstream AST
fixtures match exactly. [The migration report](../docs/translation-audit/RUST_TO_V_PROGRESS.md)
records the executed commands, boundaries and remaining Rust JPEG XL dependency.

The frontend and supported VM execution slice are integrated into the browser;
JavaScriptCore continues to execute scripts in the default mode. This is not a
complete LibJS runtime migration.

- RegExp flags, named-group surrogate checks, ParsePattern preprocessing,
  source escaping and the standalone matching engine are translated. The
  frontend `compile_regex_pattern()` hook still has no backend, and the RegExp
  object, allocation/initialization and constructor/prototype integration remain
  pending. The independent grammar and full-engine corpora establish their
  recorded cases, rather than full ECMAScript matching conformance. The browser
  continues to execute author scripts through JavaScriptCore by default.
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
  ECMAScript function objects, Array, the remaining String prototype and most
  other builtin constructor/prototype records, intrinsic accessors and proxies remain
  untranslated. Production builtin installation currently includes Math, Boolean,
  Symbol, ArrayBuffer, DataView and SharedArrayBuffer. BigInt constructor/prototype
  records and all native bodies exist with explicit Object/Intl dependencies;
  production installation and Intl formatting remain pending. Number constructor/
  prototype records and all native bodies likewise exist with explicit Object,
  retained parse-function, decimal-form and Intl dependencies; AK/fmt Dragonbox,
  production Number installation and primitive Reference integration remain pending.
  String's complete constructor and thirty-nine prototype native bodies exist with
  explicit dependencies; its remaining 10 native bodies, full prototype
  initialization, aliases and production installation remain pending.
  String exotic records, synchronous iterator operations, and
  String/Array iterator next prototypes exist with explicit intrinsic
  dependencies. String's @@iterator body also exists with an explicit prototype.
  Array sorting helpers and exotic records exist, but Array constructors/prototypes,
  iterator-producing Array methods, Iterator helpers, async
  iteration, and array-literal generation remain pending.
  DataView records, construction, witnesses, property accessors, numeric methods
  and buffer element conversions exist, as do SharedArrayBuffer construction,
  accessors, growth and slicing. TypedArray records, buffer witnesses, integer-indexed
  exotic methods, all four initialization paths, concrete constructor behavior,
  TypedArrayCreate, numeric comparison and iterator next exist with explicit
  prototype dependencies. Number/BigInt wrapper records and primitive ToObject
  exist with explicit Number/BigInt/String prototype dependencies; their primitive
  Reference integration remains pending; String's remaining prototype work and
  Number/BigInt/String global installation await their dependency graphs;
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
  complete intrinsic graph and remaining ObjectPrototype type-record dependencies,
  AK's Number decimal backend and Intl formatting remain untranslated, as do concurrent
  shared backing stores, Atomics and caged storage. ReflectObject's complete record and
  all thirteen native bodies exist with explicit Object/Array dependencies;
  production global installation and Proxy internal methods remain pending.
  Realms expose four standard value properties, eight numeric/URI functions,
  Boolean/Symbol/ArrayBuffer/DataView/SharedArrayBuffer constructors, Math, and two legacy
  functions on an ordinary global object. Default native globals inherit the
  translated Function prototype linked to the installed Object prototype;
  the Function constructor linkage remains pending.
- CyclicModule graph loading, linking, evaluation, promise reactions, JSON
  modules, the debugger, and the LibWeb host bindings remain necessary before
  making LibJS the default browser backend or claiming LibJS parity.
  JavaScriptCore remains available through its command-line selection.

The AST corpus, focused syntax cases, and VM record tests validate the completed
slices above; they are not an ECMAScript runtime conformance suite.
The LibWeb symbol audit excludes this separate package (`db4e4fc`), so matching
LibJS runtime names cannot satisfy LibWeb coverage or alter its review queues.
All 46 translation-tool Python tests pass, including that scope regression.

## Production operation preservation

The audit corrections `c68c8bf2`, `2110fc6c`, `61c817f4`, `fbcccad2`, and
`172482b3` move source-required operations outside V assertions: ArrayCreate
length/list initialization, String split result properties, FromPropertyDescriptor
field creation, Uint8Array decoder metadata, and ICU string-property extraction.
FromPropertyDescriptor now invokes the source CreateDataPropertyOrThrow operation.
Their ordinary-statement focused checks run with `-prod -gc none`, so production
assertion elimination cannot erase the checks themselves. The complete package
passes 227 test files with default GC and with `-gc none`. These supporting
corrections do not install missing intrinsic records or complete regex execution.


The explicit byte boundary `utf16_string_from_utf8_without_validation` follows
pinned `AK/Utf16String{,Data}` and `AK/Utf8View.h` rather than V's Unicode scalar
iterator. It retains Source WTF8 surrogate and overlong code points, advances
truncated or structurally invalid input one byte, and replaces an out-of-range
point while consuming its structurally valid byte length. It retains the
Source ASCII versus UTF16 storage choice. `Utf16String.to_ascii_lowercase`
translates `AK/Utf16View.cpp` over raw code units. Existing generic `utf16()`
behavior stays unchanged; callers must choose the explicit Source byte helper.

The new helper and existing Unicode fixture pass **2/2** with default GC and
GC-none (`source-utf16-byte-boundary-{default,gc-none}.log`). The separate
`tools/source_drag_wtf8_probe.py` compiles actual pinned AK Utf8View,
UnicodeUtils and CharacterTypes header algorithms at native -O0 and -O2. Its
WTF8, malformed/truncated, overlong and raw ASCII results match the V fixtures.
It probes those actual decoder helpers, not a complete C++ File/LibWeb object.
The frozen integrated helper snapshot passes the required full **232/232**
LibJS files with default GC and with GC-none, and exact **100/100** upstream
AST comparisons. All 485 non-Markdown LibJS implementation/test/assets remained
byte-identical to canonical before and after the sweeps. Manifest/hash/log
evidence is in
[`LIBJS_BYTE_BOUNDARY_VERIFICATION.md`](../docs/translation-audit/LIBJS_BYTE_BOUNDARY_VERIFICATION.md).

The explicit `utf16_string_from_ascii_without_validation` owner now translates
AK's unchecked ASCII byte allocation and native plain-char unit projection.
It preserves raw bytes independently of the code-unit projection and retains
short/long storage metadata, with copied input/access ownership and stale-slot
rejection. The actual pinned AK constructor/header probe passes at -O0/-O2;
three focused files pass in both GC modes. Source mappings and exact native
probe limits are in
[`UTF16_UNCHECKED_ASCII_SOURCE.md`](../docs/translation-audit/UTF16_UNCHECKED_ASCII_SOURCE.md).

The complete unchecked-ASCII snapshot passes **233/233** LibJS files with
default GC and GC-none and **100/100 exact --all AST cases** in a separate
entirely frozen clean checkout. All 4027 tracked files remained unchanged and
all 487 non-Markdown LibJS files matched canonical after the sweeps. Exact
heads, manifests, log hashes and supplemental-run limits are recorded in
[`LIBJS_UNCHECKED_ASCII_VERIFICATION.md`](../docs/translation-audit/LIBJS_UNCHECKED_ASCII_VERIFICATION.md).

Math.random now obtains its two constructor seeds from the Source operating-system CSPRNG rather than the default V PRNG (`ce231a42`). Existing splitmix/xorshift and 53-bit projection remain Source translations. The unchanged pinned native bodies match 48 exact outputs and the native two-draw ABI at both optimization levels; focused default and production GC-none Math checks pass. Platform execution and static-initialization limits are recorded in [Math Source entropy](../docs/translation-audit/MATH_RANDOM_SOURCE_ENTROPY.md).

Frozen Math entropy revision `1226f3e4` passes **234/234 LibJS files in both GC modes and all 100 exact AST cases**. The entire 4417-file tracked checkout remained byte-identical; all 490 non-Markdown LibJS files matched canonical at recording. Exact manifest/revision/log evidence and remaining runtime limits are in [verification](../docs/translation-audit/LIBJS_MATH_ENTROPY_VERIFICATION.md).

## Audit fix: Object private elements

`object_private.v` translates `Runtime/Object.cpp`'s PrivateElementFind,
PrivateFieldAdd, PrivateMethodOrAccessorAdd, PrivateGet and PrivateSet bodies.
Private storage retains identity by PrivateName, stays separate from ordinary
properties, calls the existing VM host hook before duplicate validation, and
passes the owning object and setter argument through native Call. Reference
now represents the private-name alternative, MakePrivateReference resolves the
running context's private environment, and GetValue/PutValue dispatch to the
private storage. Focused tests cover duplicate and missing names, distinct
environments, frozen receivers, inaccessible inherited fields, accessor
receivers, missing callbacks, abrupt completion and host-hook ordering.

Class/function execution, private-expression bytecode generation, DefineField,
InitializeInstanceElements, Proxy, eval and disposable-resource algorithms
remain pending; this slice does not close the whole JS-05 finding.

## UTF-16 encoding performance maintenance

`b92a8c9f1` copies ASCII prefixes directly and returns immediately for empty
input, preserving the scalar Unicode/WTF-8 tail and unchecked ASCII storage.
Sixty-four focused executions pass across normal, no-GC, sanitizer and
preallocation variants; all 100 upstream AST fixtures match in both GC modes.
Both full current-V selections finish at 235/237 files passing: the two Greek
case-mapping failures reproduce with both encoding paths and independent
system-ICU probes. Their references remain unchanged, and no full-suite pass
or additional VM/runtime parity is claimed. See the
[encoding evidence](../docs/performance/chatgpt-utf16-prefix-20261104.json)
for exact counts, retained failures and production-validation limits.
