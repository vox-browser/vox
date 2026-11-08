# Large-source audit: LibJS and its browser execution boundary

Audited 2026-10-02 against Ladybird commit
`963d46a829f3e1b79f44dba9d02afb70654300fa`. Upstream paths below are relative
to `/Users/alex/code/3rd/ladybird`; V paths are relative to this repository.

## Result

The 17 current LibJS C++ files with at least 1,000 physical lines do **not**
have complete V translations. Several useful native-method slices exist, but
the production realm, instruction set, object kinds, and frontend/runtime
integration do not supply the rest of these source units. JavaScriptCore is
the browser's default execution engine (`browserjs/runtime.v:63`). Passing
browser tests through that engine cannot establish LibJS translation parity.

This is a source-body and integration audit with selected execution probes.
It is not an exhaustive equivalence proof for the methods that are present.
Searches excluded tests when deciding whether a production implementation
exists. Comments and `PORT_STATUS.md` were orientation aids, not evidence of
correctness. The findings concern observable omissions and replacements;
they do not establish who originally wrote a piece of code.

## Per-source coverage

Every row received responsibility/body inspection and a search for actual
production counterparts. “Sampled” means the listed algorithms were compared,
not that every branch in the entire file was validated.

| Current upstream source under `Libraries/LibJS/` | Lines | V counterpart / inspected boundary | Comparison and disposition |
| --- | ---: | --- | --- |
| `Interpreter/SlowPaths.cpp` | 3,317 | `libjs/interpreter.v`, `instruction.v`, `bytecode_generator.v`, `reference.v` | Sampled computed get/put/delete and NewArray/NewFunction/Await/Yield handlers. Ordinary property handlers exist; object/array/function creation and suspension handlers are missing from the V instruction set. JS-01. |
| `Runtime/Value.cpp` | 2,570 | `libjs/value*.v`, `instanceof.v`, `array_object.v`, `reference.v` | Sampled ToPrimitive, ToObject, ToPropertyKey, IsArray and primitive references. Scalar translation exists; production primitive boxing and Proxy IsArray are incomplete. JS-04/05. |
| `Runtime/Object.cpp` | 2,402 | `libjs/object.v`, `object_accessors.v`, `object_property_definitions.v`, `property_descriptor.v` | Sampled OrdinaryToPrimitive, descriptor dispatch, internal get/set and private-element storage. Ordinary properties/accessors are represented; private-element algorithms are absent. Flat property storage replaces shapes/indexed tiers; semantic parity of that storage was not certified. JS-05. |
| `Runtime/TypedArrayPrototype.cpp` | 2,290 | `libjs/typed_array_prototype.v` and `typed_array_*.v` | Sampled initializer metadata/aliases, at/includes, reverse/sort, reduce and same-type slice paths. Substantial source-derived methods and focused tests exist. Realm installation and dependent intrinsic graph remain incomplete. JS-02. No additional method-body defect established in these samples. |
| `Runtime/ArrayPrototype.cpp` | 2,191 | `libjs/array_sort.v`, `array_to_string.v`, `array_iterator*.v`, `array_object.v` | Compared merge-sort helper, toString fallback and upstream initializer. These helpers do not supply push/map/splice/flat/species or the ArrayPrototype record/initializer. JS-02. |
| `Runtime/Temporal/Calendar.cpp` | 2,032 | No Temporal runtime record/algorithm counterpart found | Read calendar_date_add and non-ISO calendar branches; searched runtime types and calendar entry points. Entire component absent from the production realm. JS-06. |
| `Runtime/AbstractOperations.cpp` | 2,029 | `libjs/array_like.v`, `iterator.v`, `species_constructor.v`, `constructor_prototype.v`, environment modules, `string_substitution.v`, `vm.v` | Sampled Call/Construct dependencies, GetFunctionRealm, GetPrototypeFromConstructor, PerformEval and disposable-resource algorithms. Multiple helpers exist; Proxy realm branch, eval and resource-disposal algorithms do not. JS-05. |
| `RustIntegration.cpp` | 1,991 | `libjs/frontend.v`, parser/AST files, `bytecode_generator.v`, `executable.v`, `script.v` | Sampled parse bridge, shared-function materialization and bytecode-cache serialization/decode/materialization. Current C++ delegates to Rust; V implements a limited retained frontend/bytecode model and no corresponding persistent cache materialization. JS-01/08. |
| `Runtime/Temporal/AbstractOperations.cpp` | 1,752 | No Temporal counterpart found | Read ParseISODateTime annotations/allowed-productions path and ISO date helpers; searched equivalent records and algorithms. JS-06. |
| `Runtime/StringPrototype.cpp` | 1,748 | `libjs/string_*.v`, `string_constructor.v`, `string_object.v` | Sampled initializer, character/search/replace/split dispatch, match/matchAll and localeCompare. Many native bodies exist; complete prototype initializer, regex methods and Intl paths do not. JS-03. |
| `Runtime/Temporal/Duration.cpp` | 1,611 | No Temporal Duration counterpart found | Read Duration field normalization and duration conversion responsibilities; no runtime slots, constructor or production algorithm counterpart found. JS-06. |
| `Runtime/RegExpPrototype.cpp` | 1,605 | `libjs/regexp_{flags,pattern,source}.v`, `regex_*.v` | Sampled compilation/cache, builtin exec result/capture/indices construction and native prototype responsibility. Preparatory helpers and low-level regex slices exist, but no RegExpObject/prototype/general execution graph. JS-03. |
| `Runtime/JSONObject.cpp` | 1,429 | No LibJS JSONObject record or native bodies found; host `x.json2` is a different API | Read initializer, parse/reviver snapshot and stringify state/cycle handling. No production JS JSON object or source-equivalent native method pipeline. JS-06. |
| `Runtime/Temporal/ISO8601.cpp` | 1,356 | No Temporal parser counterpart found | Read production dispatch, complete-input checks and UTC-offset parser. LibWeb date/control parsers do not provide this grammar/API. JS-06. |
| `Runtime/DatePrototype.cpp` | 1,314 | No LibJS Date record/prototype counterpart found | Sampled initializer, local/UTC getters, setters and serialization. No Date internal slot or production prototype. LibWeb timing utilities are not JS Date implementations. JS-06. |
| `Runtime/MathObject.cpp` | 1,233 | V `math` imports supply host numeric helpers, not a JS Math object | Read initializer and native numeric/coercion responsibilities. No source-equivalent JS object, metadata or native dispatch is installed. JS-06. |
| `Print.cpp` | 1,072 | `libjs/value.v:275`, `tools/libjs_run.v`; `ast_dump.v` serves a different responsibility | Compared object/array printing and recursive seen-object tracking to Value.str(). V prints a class label, not upstream's inspected values. AST dumping does not translate Print.cpp. JS-07. |

## Confirmed findings

### JS-01 — Missing creation/suspension instructions and ECMAScript function execution

**Category:** untranslated logic; high confidence.

Upstream `Libraries/LibJS/Interpreter/SlowPaths.cpp:1994` creates arrays,
`:2923` creates ECMAScript functions, `:2798` implements Await and `:3007`
implements Yield. The V `OpCode` enum (`libjs/instruction.v:6`) has none of
these handlers. `libjs/bytecode_generator.v:534` and `:748` reject unhandled
AST kinds, and `libjs/interpreter.v:313` rejects inline calls. Native and bound
callables are real translated slices; they do not implement ECMAScript closures.

The execution probes below confirm array/function literals fail before
execution. Translate the missing upstream instruction/codegen paths and
function records with focused execution tests; do not replace them with host
evaluation. Current codegen algorithms also live in upstream Rust, so a
C++-only audit cannot establish the complete frontend's origin or parity.

### JS-02 — Native slices are not connected to the complete production intrinsic graph

**Category:** missing integration and untranslated builtin logic; high confidence.

`libjs/realm.v:106` creates Function, Boolean, Symbol, ArrayBuffer, DataView and
SharedArrayBuffer prototype records with missing Object prototype ancestry;
`:197` installs only the translated subset of constructors. The runner reports
Array, Object, String, Number, RegExp and Uint8Array as undefined. This matters
even where host-driven tests explicitly construct a complete method dependency.

For `ArrayPrototype.cpp`, upstream initialization
(`Libraries/LibJS/Runtime/ArrayPrototype.cpp:44`) installs methods including
push, map, flat, splice, species behavior and unscopables. Production searches
find merge sorting, Array toString and iterators, but no ArrayPrototype record
or those method bodies. TypedArray's substantial initializer
(`libjs/typed_array_prototype.v:21`) accepts explicit prototype/constructor
callbacks; it is not called by production `initialize_host_defined_realm`.

Translate the remaining builtin records, initialize them in upstream order,
and exercise the ordinary realm rather than only injecting test prototypes.

### JS-03 — RegExp and remaining String prototype responsibilities are absent

**Category:** untranslated logic; high confidence.

`Libraries/LibJS/Runtime/RegExpPrototype.cpp:101` compiles/caches a general
pattern; `:353` constructs the hasIndices result. The V object record
(`libjs/object.v:134`) has no RegExp payload, the realm has no RegExp intrinsic,
and the compiler cannot produce a regex literal. `regexp_flags.v`,
`regexp_pattern.v` and `regex_*.v` are useful preparation/VM slices; they do not
implement that object/prototype pipeline.

Upstream `StringPrototype.cpp:149` initializes the full prototype; `:619`
implements match and `:649` matchAll. Production V has no StringPrototype
record or those native bodies. LocaleCompare (`:581`) and locale casing also
depend on an untranslated Intl graph. Existing replace and split correctly
retain generic symbol dispatch (`libjs/string_replace.v:5`,
`libjs/string_split.v:6`); their missing RegExp dependency is not proof that those
generic dispatch bodies themselves are stubs. Complete the dependency graph
and translate the missing native paths.

### JS-04 — Production numeric/string primitive references stop at an InternalError

**Category:** missing integration; high confidence, reproduced.

Upstream ToObject (`Libraries/LibJS/Runtime/Value.cpp:578`) handles Number,
String and BigInt using realm intrinsics. V helper
`libjs/value_boxing.v:14` can box them only with explicit external prototype
getters. The actual Reference path (`libjs/reference.v:129`) handles objects,
Boolean and Symbol, then returns an InternalError for the other primitives
at `:148`. The interpreter's special string-own-property path
(`libjs/interpreter.v:73`) makes `'x'.length` succeed but does not supply the
missing prototype path. `(1).toString()` fails in the ordinary translated VM.

Wire the translated wrappers to the real Number/String/BigInt intrinsics,
preserving the original primitive receiver for property access.

### JS-05 — Object private elements, Proxy branches, eval and disposal are not translated

**Category:** untranslated logic; high confidence.

Upstream `Object.cpp:741` onward stores and accesses private elements. V
`libjs/object.v:134` has no corresponding private-element storage;
`libjs/bytecode_generator.v:133` explicitly rejects private access. V's
ordinary and Array/String/TypedArray dispatch should not be mistaken for
complete exotic-object dispatch.

`Value.cpp:278` validates/re-enters Proxy targets for IsArray; V
`libjs/array_object.v:121` checks only its Array payload. Upstream
`AbstractOperations.cpp:276` does the analogous Proxy validation for
GetFunctionRealm; V `libjs/constructor_prototype.v:6` has no Proxy path.
The Proxy record itself is absent, rather than a represented proxy silently
taking an incorrect ordinary path.

`AbstractOperations.cpp:610` implements PerformEval and `:1499` onward adds
disposable resources. No production V implementations of those algorithms
were found. `eval('1 + 2')` produces a ReferenceError. Translate these source
algorithms and their object/environment dependencies as separate slices.
Flat property arrays instead of C++ shapes are a representation change, not
by themselves evidence of a semantic bug or invented provenance.

### JS-06 — Math, JSON, Date and Temporal source units have no runtime counterparts

**Category:** untranslated components; high confidence, installation absence reproduced.

This covers seven large source units, not merely seven missing filenames.
Upstream JSONObject initialization (`JSONObject.cpp:150`) exposes parse,
stringify, rawJSON and isRawJSON; parse (`:637`) retains reviver source snapshots.
MathObject initialization (`MathObject.cpp:29`) installs ECMAScript constants
and native functions. DatePrototype (`DatePrototype.cpp:40`) installs Date
methods using a Date time-value internal slot. Those records and native
algorithm pipelines are absent from V's production object kinds and realm.

Temporal omissions cover Calendar date addition (`Temporal/Calendar.cpp:559`),
ISO parsing/annotations (`Temporal/AbstractOperations.cpp:1121`), Duration
field normalization (`Temporal/Duration.cpp:34`) and grammar dispatch/end
checks (`Temporal/ISO8601.cpp:1317`). Repository-wide production searches found
no corresponding Temporal runtime records/entry points. Ordinary host
`math`, `time` or `x.json2` calls elsewhere do not expose those ECMAScript
algorithms. The ordinary VM reports Math/JSON/Date/Temporal as undefined.

Translate each upstream component and then its intrinsic/global installation;
do not count platform libraries or JavaScriptCore's builtins as its V port.

### JS-07 — Value.str() substitutes a class label for upstream recursive value inspection

**Category:** reduced diagnostic implementation; high confidence.

Upstream `Libraries/LibJS/Print.cpp:182` prints Array contents and `:210`
prints properties while tracking already-seen objects. V
`libjs/value.v:305` returns `[object <class_name>]`; `tools/libjs_run.v`
prints that string. No PrintContext/recursive value inspector counterpart
was found. `libjs/ast_dump.v` serializes syntax, not runtime objects.

Translate Print.cpp separately if complete diagnostic parity is required.
This finding concerns inspection output, not ECMAScript ToString semantics.

### JS-08 — Persistent bytecode-cache materialization is missing

**Category:** untranslated source responsibilities; high confidence.

Upstream `Libraries/LibJS/RustIntegration.cpp:605` serializes compiled cache
data, `:639` decodes it and `:735` materializes cached scripts. Shared-function
construction (`:1524`) retains source ranges, parsing insights and compiled
function metadata. V `libjs/script.v` retains a cached Executable pointer and
`libjs/bytecode_generator.v:754` reuses it in process. That is not a translation
of cache blobs, validation, shared-function materialization or lazy compilation.
Production searches found no equivalent persistent cache pipeline.

Translate the corresponding current Rust/C++ responsibilities together;
retain in-process executable reuse as an independently useful behavior.

## Execution evidence

Built the existing runner successfully (compiler emitted notices):

```sh
v -old-compiler -enable-globals -o /tmp/vox2-audit-libjs tools/libjs_run.v
/tmp/vox2-audit-libjs -e '1 + 2'
```

Each probe below ran through this runner, without JavaScriptCore or injected
intrinsic prototypes. These are observations, not new regression tests.

| Source | Exit | Observed result |
| --- | ---: | --- |
| `1 + 2` | 0 | `3` |
| `typeof Array/Object/String/Number/RegExp/Date/JSON/Math/Temporal` (separate typeof expressions joined with `\|`) | 0 | Nine `undefined` values |
| `[1, 2]` | 1 | `array_expr is not translated yet` |
| `(function () { return 1; })()` | 1 | `function_expr is not translated yet` |
| `'x'.length` | 0 | `1` |
| `(1).toString()` | 1 | `InternalError: Property references on primitive values require the object model translation` |
| `eval('1 + 2')` | 1 | `ReferenceError: 'eval' is not defined` |
| `typeof Uint8Array` | 0 | `undefined` |
| `typeof Boolean/Symbol/ArrayBuffer` (separate typeof expressions joined with `\|`) | 0 | Three `function` values |

No full LibJS suite, heap-ownership suite, AST corpus, or upstream executable
differential suite was run for this documentation-only audit. The existing
focused tests remain useful but cannot certify the missing production paths.
