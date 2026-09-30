# LibJS V translation status

Audited: 2026-10-01.

The frontend baseline comes from `medvednikov/libjs_v` commit
`9824cc3fad0910215f0f4de43fb108bb7575f6c7` (2026-02-24). The upstream reference is
`~/code/3rd/ladybird/Libraries/LibJS` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11): its Rust parser, lexer,
AST, and scope collector for the frontend, and its C++ `Runtime/VM.{h,cpp}`,
`Interpreter/Interpreter.cpp` VM members, and runtime records for the VM slice.
The execution slice additionally follows `Rust/src/bytecode/{operand,generator,codegen}.rs`,
`Interpreter/interpreter.flap`, `Script.cpp`, and `Runtime/{Value,GlobalObject}.cpp`.
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
| `value.v`, `completion.v`, `primitive_string.v`, `symbol.v`, `object.v` | Tagged values, completion records, VM string caches, symbols, ordinary objects with data properties and `PropertyName` keys |
| `error_object.v`, `error_types.v` | Error objects with `[[ErrorData]]` tracebacks and stack strings; the 226-entry `ErrorType` message table |
| `realm.v`, `script.v`, `module_records.v`, `promise.v`, `function_object.v`, `executable.v` | Realm and Script records, standard global value properties, `Module` records and loading payloads, promise state, job callbacks, executable metadata (handler ranges, source map, identifier table) |
| `value_operations.v` | Primitive coercion, numeric arithmetic, UTF-16 concatenation, strict/loose equality and relational comparisons |
| `operand.v`, `instruction.v`, `interpreter.v` | Operand encoding, checked instruction/value layouts, V dispatch loop, bindings, branches, exception dispatch and instruction budgets |
| `bytecode_generator.v`, `script_evaluation.v` | Supported expression/statement code generation, cached executables, global declaration instantiation and ScriptEvaluation |

The 44 implementation files contain **19,317 physical V LOC**. The 40 test
files contain **3,350 physical V LOC** and **143 test functions**. Physical LOC
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

Supported programs include primitive literals, identifiers, `this`, numeric and
bitwise operators, comparisons, primitive string concatenation, unary operators,
`typeof` (including unknown names and lexical TDZ checks), conditional and sequence
expressions, short-circuiting logical operators and assignments, identifier
assignments/updates, `var`/`let`/`const`, blocks, `if`, `while`, `do`/`while`, `for`,
unlabelled `break`/`continue`, and `throw`. Bindings persist across scripts in one
realm. Global declaration conflicts are checked before creating any bindings;
block declarations are created before executing their initializers. The global
object supplies `undefined`, `NaN`, `Infinity`, and `globalThis` with upstream
property attributes.

The entire program is compiled before declaration instantiation or execution.
An unsupported construct, even inside an untaken branch, rejects the program
without running its preceding statements or creating its bindings. Functions,
calls, object/array creation, property access, destructuring, classes, exceptions
with `try`/`catch`/`finally`, labels, iterators, templates, regex, BigInt, async,
and modules are still pending. Handwritten bytecode tests exercise exception
handler dispatch and `Catch`; this does not imply AST-level catch support.
Object coercion reports an `InternalError` until callable objects exist.

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
# 40 passed, 40 total

v -old-compiler -enable-globals -gc none test libjs
# 40 passed, 40 total

v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all
# LibJS AST corpus: 100 passed, 0 failed, 100 total

v -old-compiler -enable-globals test browserjs
# 2 passed, 2 total

v -old-compiler -enable-globals -gc none test browserjs
# 2 passed, 2 total

v -old-compiler -enable-globals test main_test.v
# 1 passed, 1 total

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

The VM tests exercise the runtime records directly: fake `FunctionObject`,
`Module`, `FinalizationRegistry`, `Agent`, and `ArrayBuffer` implementations
stand in for the untranslated builtin objects, and module-loading tests write
temporary module files. The preceding LibWeb work passed its complete 656-file
suite, native headless smoke, and all 11 default screenshot comparisons before
this package; the 40 libjs files were verified separately in both GC modes.
There are now 696 repository test files.

Browser integration checks pass the two `browserjs` test files in both GC modes,
the native `main_test.v` bridge and flag tests, the production bundle build,
JavaScriptCore DOM-mutation/click smoke, and LibJS bytecode smoke. A native
LibJS fixture also verifies continuation after an unsupported DOM script.
Invalid engine flags return exit status 2. The standalone runner passes
expression and file-input checks, rejects unsupported programs with exit status
1, and its linked libraries contain ICU and libSystem without JavaScriptCore.

The 25 screenshot comparisons pass the 11 default smoke cases, the same-size SVG image source switch, and 13 SVG
paint-server mutation cases; all 14 SVG comparisons are pixel-exact.

## Deviations from upstream

- `Value` keeps an explicit tag next to its payload instead of NaN-boxing; BigInt
  and accessor cells have tags but no translated representation.
- There is no process-wide `VM::the()` singleton or one-VM-per-process guard;
  every record that needs the VM receives it explicitly, and private environment
  ids are handed out by the VM instead of a static counter.
- GC cells are V heap records. Environments, function objects, modules, and
  finalization registries are interfaces; `gather_roots()` reports their
  identities into `HeapRoots` for inspection rather than driving a collector.
- `TypeErrorRealmScope` has no destructor; callers must call `restore()`.
- `Object` supports ordinary data properties only (no accessors, shapes,
  proxies, or intrinsic prototypes). The runtime property key is named
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
- Callable objects are absent, so per-iteration environments observable through
  closures are pending; function syntax is rejected before execution.
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
- Remaining expression/statement generation, calls and inline frames
  (`push_inline_frame`), functions, generators, async execution, property caches,
  and packed interpreter bytecode remain pending. The current instruction loop
  and declaration-instantiation path cover only the supported slice above.
- Intrinsics, callable `SetDefaultGlobalBindings` entries, builtin constructors
  and prototypes, ECMAScript and native function objects, accessors, proxies,
  and BigInt values remain untranslated; realms expose an ordinary global object
  with the four standard value properties.
- CyclicModule graph loading, linking, evaluation, promise reactions, JSON
  modules, the debugger, and the LibWeb host bindings remain necessary before
  making LibJS the default browser backend or claiming LibJS parity.
  JavaScriptCore remains available through its command-line selection.

The AST corpus, focused syntax cases, and VM record tests validate the completed
slices above; they are not an ECMAScript runtime conformance suite.
