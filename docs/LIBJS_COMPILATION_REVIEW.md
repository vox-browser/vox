# LibJS compilation coverage review

Reviewed: 2026-11-26  
Source revision: [3170240316e66be0b8d97c4c6e5a56d1f299a61c](https://github.com/vox-browser/vox/commit/3170240316e66be0b8d97c4c6e5a56d1f299a61c)

## Goal and scope

Compile and correctly execute as much real JavaScript as possible. The first
priority is increasing the number of supported programs and function bodies
that actually reach compiled execution. Optimization should then reduce the
measured cost of their most frequent operations.

This is a source review of the frontend, bytecode compiler, execution machinery,
native tier, persistent cache, browser scheduling, and relevant regression
sources. It is not a measured compatibility percentage. No V compiler was
available in the review environment, so the LibJS tests, LibJS reproductions,
native builds, and browser scenarios below were not executed here. Selected
JavaScript examples were checked in Node only for reference behavior. Existing
tests are evidence of intended behavior, not newly observed passing results.
Findings are pinned to the revision above and must be rechecked after changes.

The historical entries in [PORT_STATUS.md](../libjs/PORT_STATUS.md) describe
different stages of the port. Several early statements, including the former
AGENTS.md claim that bytecode generation, interpretation, regex, and module
linking were pending, no longer describe the implementation.

## What already exists

| Stage | Current implementation | What it establishes |
| --- | --- | --- |
| Frontend | Lexer, parser, scope analysis, function table, structured diagnostics | Syntax and early-error acceptance, subject to frontend gaps and resource limits |
| Bytecode | Script/module/function compilation, local slots, exceptions, closures, classes, ordinary async functions, synchronous generators | Executable VM instructions for supported constructs |
| Runtime | Interpreter, native regex implementation, builtin graph, synchronous module linking/evaluation, dynamic imports, DOM host | Observable execution for implemented language and host behavior |
| Native tier | Bytecode-to-C generation, Clang invocation, dynamic library loading, runtime guards, VM helper calls | A baseline compiled entry that can mix inline operations with generic semantics |
| Persistent cache | Source-bound identities by default; optional exact-generated-C identity; ABI/library validation | Reuse in subsequent VMs/processes when identity and validation agree |
| Browser integration | Explicit LibJS backend and document cache; optional JSC-first site warmup | Engine selection and compilation policy, separate from language support |

Sources: [frontend](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/frontend.v),
[bytecode generation](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/bytecode_generator.v),
[native source generation](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_tier.v#L315-L380),
[document cache](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/native_code_cache.v#L8-L25),
[site backend selection](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/site_native_warmup.v#L63-L77).

JavaScriptCore remains the default engine. Explicit LibJS execution does not
need to send unsupported constructs to JSC to preserve this architecture.
Correct shared runtime helpers are a useful coverage mechanism within LibJS:
keep them available while more operations receive native fast paths.

## Priority findings

Priority describes impact on this goal, not a measured prevalence across the
web. Items 1–4 remove loss of compilation opportunity without requiring a new
optimizing compiler.

### 1. Regular author callbacks can postpone compilation indefinitely

**Priority: high. Confirmed control flow; browser reproducer not run.**

Every script/callback cleanup schedules the document cache. Before a background
batch starts, scheduling restarts a one-shot timer for 1,000 ms. A callback every
100 ms can keep moving that deadline forward. When the timer does fire,
outstanding module scripts or LibJS fetches cause another 1,000 ms delay.
A continuously active page or long-lived pending fetch can therefore keep
eligible executables in the interpreter despite an available compiler.

Sources: [cleanup](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/runtime.v#L256-L261),
[timer restart](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/native_code_cache.v#L68-L98),
[network gate](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/native_code_cache.v#L109-L138).

**Change:** retain the initial hydration debounce, but give pending compilation
a maximum wait. Schedule bounded work fairly after that deadline and compile
already available bodies without requiring the entire network to become idle.
Do not move compilation into the JavaScript hot loop. Keep origin-thread
snapshot/installation and worker-owned C compilation.

**Acceptance:** with an empty cache, run a periodic callback faster than one
second and a separate case with a deliberately pending fetch. Require compiler
progress, correct callbacks, and a bounded event-loop delay while activity
continues. The current quiet-load regression covers eventual quiet and
responsiveness once a compiler has started; it does not establish fairness
under continuous author callbacks.

### 2. Site warmup stops after 128 function templates and still marks the site ready

**Priority: high. Confirmed enumeration bug.**

The explicit site-warmup path calls
`prepare_native_source_templates(..., 0, 128)` once and discards the returned
`next_index`, `done`, unsupported count, and diagnostics. The helper only visits
the requested range. `compile_native_site_cache` subsequently writes a ready
marker whose keys describe top-level programs.

A source containing more than 128 function-table entries can therefore be
reported ready even though later uncalled bodies were never prepared. This is
specific to detached site warmup: the ordinary browser module-template queue
does retain pagination state.

Sources: [one-shot preparation](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_site_warmup.v#L80-L106),
[range/result contract](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/module_native_templates.v#L85-L115),
[ready marker](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_site_warmup.v#L26-L43),
[correctly paginated module queue](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/native_module_templates.v#L41-L66).

**Change:** continue until `done`, retaining partial failures and diagnostics.
Track program compilation, complete template traversal, unsupported bodies,
and runtime compatibility as distinct statuses. A cache-ready marker must not
imply semantic compatibility with APIs or code that were not exercised.

**Acceptance:** generate 129, 256, and more than 256 uncalled functions, plus
class field/static-block initializers. Warm them without executing author code;
then invoke the last bodies in a fresh VM with the compiler disabled. The
existing site-warmup test uses exactly 128 functions and misses this boundary
([test](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_site_warmup_test.v#L17-L31)).

### 3. Warmup collection and worker contention discard useful work

**Priority: high for the JSC-first warmup path. Confirmed policy.**

The browser collector clears all collected sources and seals the job when it
would exceed 128 sources or 4 MiB. `start_after_load` also seals the job before
attempting the single-worker channel; if that worker is occupied, it returns
and clears the sources without queueing a retry. The worker suppresses the
compilation error with `or {}`.

Sources: [collection cap](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/site_native_warmup.v#L102-L120),
[worker submission](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/site_native_warmup.v#L122-L167).

**Change:** stream or spool bounded source batches, retain completed work, and
represent incomplete preparation explicitly. Queue/retry a busy worker fairly
instead of permanently dropping that visit's preparation. Expose failure and
defer reasons in diagnostics. Keep a bounded queue and cancellation policy.

**Acceptance:** cover a 129-resource page, a source set over 4 MiB, and two
overlapping warmups. Supported bodies should make progress without unbounded
memory or false readiness.

### 4. One failed native batch can stop all later compilation in a document

**Priority: high. Confirmed failure propagation.**

Pending executables are sorted by key and compiled as one batch. Failure leaves
them pending. The browser handles a compile/load/publish error by setting
`libjs_native_cache_failed_`, which disables future scheduling and flushing for
that document. A single problematic body or transient failure can stop unrelated
supported bodies from reaching native code. A retrying standalone embedder can
select the same failing prefix again.

Sources: [batch selection and failure](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_code_cache.v#L364-L400),
[background error propagation](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_cache_background.v#L115-L133),
[document-wide disable](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/native_code_cache.v#L144-L149).

**Change:** distinguish unavailable compiler/system-wide failure, transient
publication failure, invalid cache entry, and body-specific code-generation
failure. Bisect failed batches when appropriate, quarantine a failing body for
the current ABI, preserve successful entries, and continue independent work.
Retry transient failures with a bound; avoid endlessly retrying a missing tool.

The batch size limit is also soft for the first executable:
`selected.len > 0` guards the 32,768-instruction check. One oversized function
can exceed it, and `NativeLibraryBuild.compile` calls `os.exec` without an
explicit timeout
([source](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_library_build.v#L53-L74)).
Add cancellation, time/resource accounting, generated-C size limits, and a
defined oversized-function policy such as chunking or a deferred baseline path.

**Acceptance:** inject one failing body among independent supported bodies,
a transient write failure, a missing compiler, a hung compiler, and a very large
function. Verify continuing useful work where possible, bounded retries, clear
terminal reasons, and preserved JavaScript behavior.

### 5. Async module and iterator constructs remain explicit language blockers

**Priority: high language coverage. Confirmed guards/rejections.**

| Construct | Current barrier | Required implementation |
| --- | --- | --- |
| Top-level `await` | `compile_module` rejects a module whose parsed source has top-level await | Async module evaluation, dependency scheduling, cycles, rejection propagation, and cached resume |
| `for await...of` | The loop generator only dispatches synchronous `for_of` and `for_in` | Async iterator acquisition, async-from-sync adaptation, await/resume, and abrupt-completion iterator cleanup |
| Async generator execution | Function creation exists, but calling an async generator returns an unsupported error | Request queue, next/throw/return, await/yield transitions, delegation, and finally cleanup |

Sources: [top-level await](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/module_execution.v#L40-L46),
[loop dispatch](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/for_in_execution.v#L6-L9),
[async generator call](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/ecmascript_function.v#L186-L189).

Minimal cases for the future regression corpus:

```js
// Module.
export const value = await Promise.resolve(42);

// Script.
async function sum(xs) {
  let total = 0;
  for await (const x of xs) total += x;
  return total;
}
sum([1, 2]);

async function* values() { yield await Promise.resolve(1); }
values().next();
```

Ordinary async functions, synchronous generators, and dynamic imports already
exist. Build on their shared suspension, Promise, exception, and budget machinery
rather than treating all async syntax as missing. Rank the three additions using
failure frequencies from a pinned corpus, not assumptions about which sites use
them most.

### 6. Dynamic compilation needs complete eval and constructor semantics

**Priority: high compatibility; larger semantic implementation.**

The ordinary `Function` constructor is implemented and uses the translated
frontend/cache. The global intrinsic setup does not install `eval`, and the
call emitter has no direct-eval case. Implementing eval requires distinguishing
direct calls from indirect calls, caller lexical/variable environments, strict
mode, declaration instantiation, host string-compilation policy, and caches that
do not bake in a previous invocation's environment.

The async-function prototype and generator-function prototypes also inherit
`Function.prototype` without installing their own dynamic constructor. The
source therefore predicts that `(async function() {}).constructor` resolves to
ordinary `Function`, and constructing `"return 1"` yields an ordinary function
instead of an async function. This is a source-derived semantic finding, not a
LibJS execution result.

Sources: [default global installation](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/realm.v#L324-L394),
[realm intrinsics](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/realm.v#L202-L213),
[generator prototypes](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/generator_creation_intrinsics.v#L14-L28),
[ordinary dynamic functions](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/function_constructor.v),
[call emission](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/bytecode_generator.v#L461-L479).

**Acceptance:** direct eval reading a caller lexical binding; indirect eval
seeing the global scope; strict/sloppy declaration behavior; shadowed eval;
policy rejection; AsyncFunction/GeneratorFunction/AsyncGeneratorFunction
constructor identity, grammar, and returned object type. Compile generated
bodies through the same accounting and cache path as static bodies.

### 7. Parser and emitter depth limits reject otherwise valid programs

**Priority: medium-to-high; quantify against bundles. Confirmed limits.**

The standalone parser defaults to 32 guarded calls, browser classic/module
preparation requests 256, and options cap the value at 1024. An independent
512 KiB native-stack reserve remains. The ordinary dynamic `Function`
constructor calls `Script.parse`, so generated source takes the standalone
default even when the surrounding browser source used 256.

Separately, a long left-associative AST can parse with shallow parser recursion
but overflow the bytecode emitter's allowed native-stack budget. The existing
test intentionally expects rejection for `1 + 1 + ...` with 5,000 additions.

Sources: [parse options](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/frontend.v#L41-L49),
[stack reserve](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/parser.v#L379-L385),
[browser depth](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/libjs_frontend_cache.v#L126-L132),
[Function parse path](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/function_constructor.v#L31-L34),
[deep-spine regression](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/bytecode_stack_guard_test.v).

**Change:** carry an explicit embedding parse policy through generated-source
entry points. Replace recursion on common long expression/statement spines with
an explicit work stack. Preserve evaluation order, source positions, finite
memory limits, and a clear resource-limit diagnostic. Simply deleting the
guards trades an explicit limit for crashes.

**Acceptance:** parse and compile long minified binary/conditional/sequence
chains and deeply nested generated functions in both static and dynamic entry
paths, while adversarial inputs still fail cleanly without damaging the VM.

### 8. Regex early-error validation is still disconnected from the real regex parser

**Priority: high correctness; required for trustworthy coverage counts.**

The runtime regex implementation exists, but the JavaScript parser's
`compile_regex_pattern` is still a no-op stub. Its flag validator checks
individual valid flags and duplicates but not the mutually exclusive `u` and
`v` combination. Literal parsing calls those routines and then constructs the
AST; later bytecode compilation performs regex preparation.

This means malformed literals in lazily compiled, uncalled functions can escape
the required source-level early error. A higher parse-success count obtained this
way is not increased JavaScript compatibility.

Sources: [stub and flag validation](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/parser.v#L446-L471),
[literal parsing](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/expressions.v#L480-L501).

**Change:** use the existing native regex parser for syntax validation at parse
time, independently of whether a function executes. Retain lazy executable
preparation if useful. Apply the correct Unicode mode and early-error rules.

**Acceptance:** both examples must reject the whole source before any author
side effects, even though `neverCalled` is unused:

```js
function neverCalled() { return /(/; }
function neverCalled() { return /x/uv; }
```

Also check dead branches, class initializers, valid lookarounds/Unicode classes,
and correct source locations.

### 9. Directive recognition incorrectly turns valid sloppy code into strict code

**Priority: high correctness and valid-source acceptance. Confirmed control
flow; reference examples checked in Node, not LibJS.**

`parse_directive` remembers the first string token's raw text, parses the whole
statement, and then checks that original token for `"use strict"`. It does not
require the finished statement to be a standalone string literal, and it
continues the prologue after a non-directive expression that starts with a
string. This source consequently predicts false strict-mode errors for valid
sloppy scripts:

```js
"use strict" + "";
with ({ x: 42 }) { x; }
```

The same parser routine is used for function bodies. This is valid, but the
current path classifies its first expression as a strict directive and rejects
the non-simple parameter list:

```js
function f(a = 1) {
  "use strict" + "";
  return a;
}
```

Sources: [directive parser](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/parser.v#L877-L895),
[function-body strict handling](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/declarations.v#L1044-L1051).

**Change:** recognize directives from completed, unparenthesized string-literal
expression statements, retain the raw-spelling check for an actual strict
directive, and stop the directive prologue at the first other statement.

**Acceptance:** test scripts and function bodies with concatenation, comma
expressions, calls/member access after a literal, parentheses, ASI, escaped
spellings, and a real `"use strict";` directive. Also cover a non-directive
expression followed by `"use strict";`: the latter must not restart a terminated
prologue. This is a focused frontend fix that should precede larger optimizer
work.

## Measure useful coverage, not only successful compilation

The existing audit already exposes cache statistics, pending executables,
template preparation, function bytecode activity, and optional native activity.
Extend that machinery rather than adding a competing reporting path.

Source: [compiled cache audit](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/browserjs/compiled_cache_audit.v),
[native activity](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_tier.v#L34-L89).

Track these separately for each pinned source set:

| Measure | Numerator and denominator |
| --- | --- |
| Valid-source acceptance | Valid sources accepted / valid sources attempted; invalid-source rejection reported separately |
| Bytecode coverage | Function bodies successfully emitted / all discovered bodies, including uncalled templates |
| Native preparation coverage | Native bodies compiled or validly reused / eligible discovered bodies |
| Native execution coverage | Work executed through native entries / all executed VM work |
| Direct lowering coverage | Inline native operation steps / all executed operations, with helper/specialized/interpreter categories reconciled |
| Warm reuse | Requested bodies reused without compiler calls / requested bodies, including later interactions |
| Failure and cost | Counts by phase/reason, timeouts, deferred age, compile time, generated-C bytes, retained memory, and cache size |

A native entry can execute many helper calls. `native_source` emits a fallback
for each instruction, and `native_slow_step` routes either to selected direct
helpers or `execute_instruction`. Keep these distinctions in diagnostics:
`compiled_executables` counts bodies, `fast_instructions` counts emitted fast
paths, and `fast_steps` counts successful fast-path executions. Those last two
also include specialized nonthrowing V helpers for binding, length, and index
reads; they do not exclusively count operations executed inline in generated C.
Reconcile those helper subsets before reporting direct lowering coverage. None
of these counters alone measures end-to-end coverage or speed
([dispatch](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_tier.v#L247-L278)).

Examples of helper-backed fast paths:
[binding reads](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_binding_read.v#L32-L40),
[length reads](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_property_length.v#L24-L34),
[index reads](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_property_index.v#L24-L33).
Count compiler attempts and failures separately: the current
`compiler_invocations` increment occurs when a successful batch is installed,
so it is not a complete compiler-attempt counter
([installation statistics](https://github.com/vox-browser/vox/blob/3170240316e66be0b8d97c4c6e5a56d1f299a61c/libjs/native_code_cache.v#L415-L420)).

Give every discovered body a terminal or pending status with a stable reason:
parsed, emitted, cache-hit, queued, compiling, compiled, unsupported, failed,
or deferred. Record source identity, function range, phase, and error reason.
Do not erase unsupported bodies from the denominator or execute uncalled
functions to obtain a profile.

The default cache binds to source identity. The optional generated-code mode
already hashes exact generated C and can retain reuse across some source/URL
changes. Evaluate that existing mode with changed constants, closures, layouts,
exceptions, URLs, and genuine code edits before considering a default change;
do not normalize JavaScript text in a way that merges different semantics.
See [generated cache design and historical evidence](LIBJS_NATIVE_GENERATED_CACHE.md).

## Implementation order and completion gates

1. **Make progress observable and reliable.** Add reason counters and source
   denominators; fix warmup pagination, collection/worker drops, scheduling
   starvation, and per-body failure isolation. Keep source correctness checks
   alongside scheduler work.
2. **Expand language support from measured failures.** Add async iteration,
   async-generator execution, top-level await, eval, and dynamic constructor
   semantics. Fix directive recognition and regex early errors, and replace
   recursive emitter hot spots.
   Use the corpus to choose the order within this group.
3. **Broaden discovery.** Unify bounded template traversal for classic scripts,
   modules, lazy factories, and generated functions. The ordinary module queue
   already paginates; extend that design without executing author code. Ensure
   partial-cache revisits can discover previously uncalled bodies.
4. **Increase direct lowering where it pays.** Rank helper calls by executed
   frequency and cost. Extend property/call/binding/numeric fast paths using
   runtime guards while retaining correct fallback, exceptions, budgets, and
   garbage-collection ownership. Do not reject an otherwise executable function
   merely because an operation needs a helper.
5. **Improve cache reuse and compilation cost.** Assess exact-generated-code
   identity, bounded C generation, job cancellation, and large-function handling
   after useful coverage can be measured.

For each implementation slice, require focused semantics and failure tests plus
these distinct execution modes:

- Bytecode/interpreter baseline with native compilation disabled.
- Cold cache with compilation enabled.
- The same VM after compiled entries have been installed.
- A fresh process/VM with the compiler disabled, followed by later callbacks,
  lazy imports, generated functions, and relevant DOM interactions.

Check observable values, exceptions, side effects, evaluation order, and
suspension/resumption, not just exit status or cache counts. Exercise default GC
and GC-disabled ownership, plus production/preallocation when changing native
lifetimes. Follow the repository memory guard and compiler limit. Honor explicit
user restrictions on tests and state exactly which checks were not run.

Retain exact upstream AST comparisons, but add a pinned Test262 language runner
and real-source compilation corpus. Report accepted, rejected, unsupported,
skipped, crashed, and timed-out cases independently. Browser API or rendering
failures belong to their own phase; they should not be misreported as parser
failures. Existing HN/Reddit/GitHub results are useful workloads and historical
evidence, not a substitute for a current conformance denominator.

## Status of this guidance update

This update changes documentation only. It does not implement the fixes above,
change engine defaults, remove resource guards, or establish a new test pass.
The source links identify the exact reviewed implementation so subsequent work
can close findings with focused changes and recorded evidence.
