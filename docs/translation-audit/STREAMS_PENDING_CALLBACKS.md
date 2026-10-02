# WA-09: source Streams pending callback reactions

Rechecked on 2026-10-02 against the read-only Ladybird checkout at
`~/code/3rd/ladybird`, revision
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The omitted pending underlying-callback Promise algorithms are translated for
the canonical native V Streams records. They also connect to actual HTML
settings, realms, and Window/Worker event loops. This is a partial runtime
remediation: complete browser JavaScript Stream bindings remain open.

| Upstream source contract | V implementation and focused verification |
| --- | --- |
| `ReadableStreamOperations.cpp`: default/byte controller setup, start-result adoption, pull fulfillment/rejection, cancel-result adoption | `streams/promise_callbacks.v`, `readable_controller_operations.v`, `readable_operations.v`; `readable_pending_callbacks_test.v`, `readable_webidl_callbacks_test.v` |
| `WritableStreamOperations.cpp`: pending start, in-flight write/close, rejection/erroring, abort completion | `streams/promise_callbacks.v`, `writable.v`, `writable_operations.v`; `writable_pending_callbacks_test.v`, `writable_webidl_callbacks_test.v` |
| `ReadableStreamPipeTo.cpp`: retained read/write, queued chunk write, wait for last write, asynchronous shutdown actions, original/action rejection ordering, finalize and lock release | `streams/readable_pipe_operations.v`, `operation_realms.v`, `pipe_tee_transfer.v`; `pipe_pending_callbacks_test.v` |
| `ReadableStreamTee.cpp` and tee operations: queued default/byte/BYOB chunks, current-reader closed reaction, shared cancellation capability and later source cancellation settlement | `streams/readable_tee_promise_operations.v`, `pipe_tee_transfer.v`; `tee_pending_callbacks_test.v` |
| `TransformStream.cpp` and `TransformStreamOperations.cpp`: one shared start Promise, pending backpressure wait, actual transform Promise, shared flush/cancel finish Promise | `streams/transform.v`, `transform_operations.v`, `transform_promise_operations.v`; `transform_pending_callbacks_test.v`, `transform_webidl_callbacks_test.v` |
| `BindingsGlue.h`, source callback adapters, `UnderlyingSource.idl`, `UnderlyingSink.idl`, `Transformer.idl`: exact callback receiver and arguments, real controller wrapper identity, start returns any, other callbacks return Promise | `streams/webidl_callbacks.v`, `bindings_glue.v`, source/sink/transformer records; readable/writable/transform WebIDL callback tests |
| `WebIDL/Promise.cpp`, `WebIDL/AbstractOperations.cpp`, native Promise branch of `LibJS/Runtime/Promise.cpp`: capability resolution adopts actual pending Promise values, callback Promise conversion, returned reaction Promise adoption, self-resolution and handled state | `webidl/promise.v`, `abstract_operations.v`, `value.v`; `webidl/promise_adoption_test.v`, `promise_host_jobs_test.v` |
| Relevant-realm constructor selection and `Bindings/MainThreadVM.cpp` HostEnqueuePromiseJob: owner realm, queued microtask, captured script/implied document, prepare and clean up script/callback context | `html/stream_operations.v`; `html/stream_operations_test.v` |

`VoidPromise` is a typed facade over one retained native WebIDL Promise. Public
heap records constructed without a factory lazily allocate the backend, so
they preserve existing native callers without dereferencing a nil pointer.
Readable/writable controllers retain their source flags and requests until
actual fulfillment/rejection reactions run. Pipe actions wait for retained
writes and asynchronous abort/cancel/close results. Tee branches share their
internal cancellation capability, while outward cancel calls retain separate
adopted result Promises. Transform readable/writable controllers share one
pending startup capability, and write/flush/cancel retains source backpressure
and finish records. Promise and replaced-reader identity checks compare actual
addresses; equal pending record fields cannot become self-resolution.

Source-style dictionary callbacks receive the actual supplied WebIDL receiver
and controller address tagged with its actual platform interface. Callback
results pass through `invoke_callback` or `invoke_promise_callback`, including
native pending Promise values. Tests invoke the actual controller through that
address to enqueue data and respond to a real byte-stream BYOB request. Native
synchronous callback fields remain explicit lift adapters to resolved/rejected
WebIDL Promises, preserving working native producers.

HTML settings factories use the actual `ScriptingRealm` address and responsible
event loop. Promise reaction and adoption jobs queue as real HTML microtasks;
Window and Worker queues remain independent. The host bridge captures the
currently active classic script at scheduling time, attaches its responsible
document when present, and prepares/cleans up the existing translated script
and callback contexts during execution. It restores the compact realm record's
previous active-script slot after the job. Standalone `StreamRealm.create()`
without a host scheduler retains the existing direct job adapter and does not
provide browser microtask timing.

## Actual JavaScript values and Promise capabilities

The compact host now carries real JSC `JSValueRef` and owning-context references
through `webidl.RuntimeValue` and `streams.Value`. Chunks retain actual cyclic
object/function/symbol identity and an actual engine GC root. Explicit string
conversion invokes the owning engine and preserves its thrown value; ordinary
queueing, errors, and rejection propagation do not coerce arbitrary reasons.
Readable/default/BYOB consumer capabilities and writable/transform operations
retain the original reason, including pending start/pull/write/close/cancel/
abort/transform/flush reactions. Transform rethrow uses a thrown-value
completion carrier; an empty string cache cannot make an errored controller
enqueue again.

`browserjs/webidl_binding_darwin.c.v` calls actual Promise-returning stream
callbacks with the supplied receiver and arguments. It adopts their returned
Promise/thenable using JSC's real Promise Resolve and captured engine `then`
intrinsic, including a throwing `then` getter. The native capability settles
through its existing owner-job scheduler. Wrapping one native WebIDL capability
returns the same real JSC Promise; different native addresses remain distinct.
Synchronous scalar callback conversion continues to call the engine directly.
This bridge is a constructor prerequisite, not installed Stream globals.

Lifetime remains an explicit boundary. A settled native-to-JSC bridge releases
its resolve/reject roots and keeps the Promise root and bridge record until
`Runtime.close()`. Callback observation releases its temporary capability and
reaction roots on settlement/error. Native chunks/reasons and callable host
records likewise remain retained until the runtime closes; source wrapper
finalization and full GC edge tracing/reclamation are not implemented. A closed
runtime rejects new conversions and queued completion jobs avoid the released
engine context.

## Native compact ReadableStream binding

`browserjs/readable_stream_host{,_darwin.c}.v` and the native browser now expose
the source constructor, `locked`, `cancel`, default `getReader`, the default
reader constructor and `closed/read/cancel/releaseLock`, plus default controller
operations. Actual JSC platform objects carry owning native record pointers;
interface brand checks do not rely on author-controlled prototypes. Dictionary
getters and scalar callback conversions execute the actual engine. Source
callbacks prepare the relevant realm and stored incumbent callback context,
then clean up the callback before script cleanup. Read result dictionaries
contain the original engine chunk and wrap the same native Promise capability.

Browser attachment follows `Bindings/MainThreadVM.cpp` realm initialization
ownership: the actual initialization context is popped into settings ownership,
and script setup/cleanup pushes/pops that same record. Author frames are popped
before cleanup drains the owning HTML microtasks. Nested realms, reentrant jobs,
and actual outer VM contexts retain the source ordering. The compact host has
one translated embedding VM per Runtime; shared loops register each actual VM
without replacing their primary source VM. Checkpoints wait for all attached
outer contexts and advance each distinct VM's execution generation once.
This remains a compact JSC embedding boundary, not a shared complete LibJS agent.

## Native compact WritableStream binding

`browserjs/writable_stream_host{,_darwin.c}.v` exposes actual owning native
WritableStream/default writer/controller records. Pending startup, writes,
backpressure, close and abort execute the existing source algorithms. Writer
`closed`/`ready` wrap the same native Promise capabilities; source backpressure
replacement changes the ready capability at the source transition. Actual
cyclic object and Symbol chunks retain identity, and callback/size/thenable
abrupt completions preserve their original values.

Generated constructor conversion visits the strategy before converting the
underlying sink dictionary. The reserved any-valued `type` key stays an actual
WebIDL value and is rejected without string coercion. Engine numeric conversion
uses actual ECMAScript ToNumber, including BigInt/Symbol rejection. The writer
getter distinguishes a released writer's TypeError from an errored stream's
null desired size and a closed stream's zero size. Constructor subclasses keep
their actual prototype while native receiver brands remain independent of it.

The controller's `signal` wraps the same source DOM AbortSignal and EventTarget.
Abort while a write is in flight dispatches the source trusted abort event
immediately, waits for that write and the actual sink abort Promise, and retains
the original or later rejection according to source ordering. Native wrappers
and settled Promise roots retain the previously documented Runtime.close GC
boundary. The transform source now accepts actual reserved any keys and an
owning wrapper-preparation hook before `start`; its public engine factory is
now installed as described below.

## Native compact TransformStream binding

`browserjs/transform_stream_host{,_darwin.c}.v` exposes the source factory,
actual readable/writable components, and the default controller. The owning
binding calls the source wrapper-preparation hook immediately after component
initialization and before `start`. Both component engine wrappers retain the
same native records and remain identical on subsequent getters. Startup,
backpressure, transform, flush, cancel, error and termination delegate to the
existing source model and actual owner Promise jobs. Constructor conversion
preserves writable/readable strategy order, transformer member order, actual
reserved any values, native receiver brands and constructor subclasses.

Actual size callbacks now return the original WebIDL value through source
readable/writable/transform controllers. Queue insertion checks the genuine
engine number brand and rejects other values without ToNumber or valueOf.
Writable writes recheck the original writer stream after the callback before
state checks and queue insertion. Legacy scalar `SizeAlgorithm !f64` callers
remain explicit adapters. Generic WebIDL invocation follows source
prepare/call/cleanup without an extra can-run-script gate; EventTarget retains
its distinct source caller gate.

Queue RangeErrors retain the typed native `SimpleException` descriptor and one
actual engine Error through synchronous throws, stored errors and later
read/write/closed rejections. Captured engine constructors preserve the source
exception type after author replacement. Descriptor/wrapper records and roots
remain retained until Runtime.close, with full wrapper GC reclamation pending.

## Public native pipes and generated constructor ordering

`browserjs/readable_stream_pipe_darwin.c.v` exposes public `pipeTo` and
`pipeThrough` through the actual native source/destination records. Destination
and pair conversion, alphabetic pipe-option reads, engine ToBoolean and actual
DOM AbortSignal conversion retain original getter exceptions. `pipeTo` returns
the same native-capability/engine Promise; `pipeThrough` returns the exact
transform readable, permits that returned readable to be locked, and marks the
internal pipe capability handled even when it rejects immediately. Default
abort retains one real AbortError object across signal, cancel, abort and pipe
rejection.

Readable/default-reader, Writable/writer and Transform factories use captured
engine construct traps to perform the source new-target prototype Get exactly
once before argument/dictionary conversion. Constructor subclasses and thrown
prototype getters retain actual engine identity. Readable conversion validates
the source before the strategy, then reads strategy members before underlying
source members, matching the pinned generated constructor.

Default tee chunk steps now clone before either branch receives its chunk.
Clone failure errors both controllers with the original completion and resolves
the shared cancellation capability with the real pending source cancellation.
One-shot Resolve begins immediately; a later close or reentrant clone/cancel
attempt cannot overtake pending adoption. Cancellation of the second branch
skips its clone. The owning-realm clone provider supplies the actual serialize/
deserialize boundary; standalone typed arrays recursively clone, and unsupported
opaque values throw a retained DataCloneError. The compact JSC opaque-object
codec and public tee remain unbound.

## Native queuing strategy factories and interface tags

`browserjs/queuing_strategy_host{,_darwin.c}.v` installs actual
CountQueuingStrategy and ByteLengthQueuingStrategy factories before author
scripts. Constructors create their native `streams` records, store unrestricted
high-water marks without ExtractHighWaterMark validation, preserve generated
required-dictionary/member and prototype conversion order, and support actual
constructor subclasses. Source strategy size getters return the relevant
Window/Worker global's cached WebIDL callback through the native global record;
`html/queuing_strategy_size_functions.v` also supplies the UniversalGlobalScope
contract. Its engine creator is an explicit boundary for constructing actual
builtin functions, not a fabricated standalone function value.

The count function returns one, has source name `size` and length zero, and is
shared by every count strategy in the global. The byte function has length one
and performs actual engine GetV(chunk, "byteLength"), returning the original
value or thrown completion without numeric coercion. Both functions are callable
without a constructor or prototype. Existing standalone scalar helpers remain
explicit compatibility adapters. Native stream queues consume these actual
callbacks and retain genuine-number queue validation.

`browserjs/native_stream_wrapper_darwin.c.v` wraps the existing source records
in actual ordinary engine objects with a private Runtime table keyed by exact
JSObjectRef identity. This replaces JSC custom-class wrappers, whose engine
class tags masked the source interface prototype tags. InterfaceObject.cpp's
inherited Symbol.toStringTag values, author changes and original tag getter
exceptions are now observed; copied or forged prototypes still fail native
record brand checks. Runtime.close clears the table and releases protected
engine roots. These records and roots remain retained until that close boundary;
full source wrapper worlds and GC reclamation remain open.

## Actual DOM abort reasons and owning timeout delivery

`dom.JSValue` now carries the actual WebIDL/engine value for arbitrary reasons.
Object, symbol and scalar reasons keep identity; `throwIfAborted()` throws the
original value. Undefined chooses a retained native `DOMException` record.
`streams.AbortSignal` delegates to the actual `dom.AbortSignal`: source ordered
abort algorithms, dependencies, trusted abort events, registration removal and
writable reentrant abort state checks execute on that native record. PipeTo
shutdown retains the original arbitrary reason while pending abort/cancel/write
operations settle; a later shutdown action rejection replaces it in the source
order. Native default/byte tee branch errors, reader-closed reactions and pending
shared source cancellation also retain arbitrary original values. Actual-engine
tee tests preserve object and Symbol identity without invoking string conversion.
The public compact tee method and opaque chunk-cloning boundary remain unbound.

`html.Timer` now delegates to the actual native timer host, preserving the source
constructor, fractional deadline, class and restart semantics. Global-scope
clock completion queues the actual owner's TimerTask and document with its
source nesting level and temporary execution context. Repeating timers reuse
the same clock; cancellation also prevents already queued handlers. Visibility,
audio and intensive-grace changes rearm actual native registrations. The old
`process_timers()` entry is an explicit deterministic clock adapter, not the
production scheduler.

`html.abort_signal_timeout()` supplies the real Window/Worker scope to
`dom.AbortSignal.timeout_in_context()`. Clock expiry removes the source timer
before queuing the owning TimerTask; that task creates the retained TimeoutError
and runs native abort steps. Abort events use the caller-global relative clock
for the source and each dependent signal. Standalone DOM `timeout()` retains an
explicit realm-less native-clock compatibility adapter. The public JSC
`AbortController` and `AbortSignal.abort/any/timeout` factories now wrap these
same native records. Native EventTarget/Event bindings supply listeners,
handler attributes, authentic trusted events and source dependent-signal
ordering; factory iteration and thrown conversions execute the actual engine.
AbortController performs one new-target prototype lookup before creating its
native record. Illegal AbortSignal construction rejects before that lookup,
as InterfaceConstructor.cpp does when no construct operation exists. Abort
wrappers use the same private exact-object record table as Streams, inherit
source interface tags, reject forged prototypes and retain native EventTarget
identity; their table/engine roots share the Runtime.close boundary.

`browserjs/timer_host{,_darwin.c}.v` installs real public
`setTimeout/setInterval/clearTimeout/clearInterval` methods after the compact
document bootstrap and before author sources. The native owner performs source
timer initialization, nesting, throttling, task queuing, repeat and cancellation.
Callbacks receive the actual owning global and original arguments, retain stored
incumbent settings and prepare/clean up the source realm. Their return value is
ignored without Promise Resolve or then access. Engine ToString/ToNumber and
WebIDL signed-long conversion preserve original conversion exceptions.

String tasks check the current source CSP policy, create the actual ClassicScript
with the initiating script's base URL, and report the original engine completion
before source context cleanup. The engine adapter creates a real captured
intrinsic EvalError for CSP refusal. The native fallback retains the caught
completion before optional converter selection, avoiding V's optional-branch
error shadowing. Closing a runtime cancels its public handles without cancelling
other native owner timers such as `AbortSignal.timeout`.

The pinned upstream still retains its TrustedScript sink conversion and
initiating fetch-options, fully-active/worker suspension elapsed-time,
ordering-identifier and additional-wait FIXMEs. Full source timer/host GC
finalization and generated compact Window error-handler exposure remain open.

The following boundaries are still open and are not counted as full parity:

- The readable binding does not expose public tee/from/iterator operations,
  BYOB reader constructors/read operations, byte-controller enqueue/BYOBRequest
  or full generated wrapper worlds. Public pipes and constructor subclass
  prototype selection are implemented on actual engine/native records.
- Generic JavaScript iterator acquisition and structured cloning of opaque
  chunks (including a public tee's cloning branch) remain unbound. Typed byte
  conversion does not provide JSC BYOB ArrayBuffer transfer/detachment or shared
  native view ownership. Native tee and PipeTo original-value propagation is
  completed; public compact pipe methods are bound, while public tee is unbound.
- Actual DOM signals and timeout tasks are connected to native Streams records.
  Public JSC AbortSignal/AbortController/EventTarget bindings use those same
  actual native records; complete generated wrapper worlds remain separate.
- Native readable wrappers/prototypes retain actual model identity. Source GC
  tracing and wrapper reclamation still require integration; native wrappers,
  callback records, chunks and settled Promise roots live until Runtime.close.
- The HTML compact realm captures classic scripts. Full LibJS module
  script-or-module execution-context capture and VM Promise builtins remain
  part of the existing LibJS runtime work. No builtin engine parity is claimed.
- Streams transfer serialization and MessagePort ownership remain their
  existing separate typed translations; this pending-callback slice does not
  establish cross-process JavaScript/GC parity.

Verification completed for the pending core and callback dictionaries:

```text
v -old-compiler -enable-globals test webidl streams compression encoding
34 passed, 34 total

v -old-compiler -enable-globals test html/stream_operations_test.v
1 passed, 1 total (three Window/Worker owner cases)

v -old-compiler -enable-globals test html/environments_test.v html/scripting_runtime_test.v html/event_loop_test.v
3 passed, 3 total
```

Additional actual-engine verification:

```text
browserjs/webidl_value_test.v: actual chunks/callback identity, engine ToString,
  thrown conversion identity, context ownership, GC roots, closed-owner guard.
browserjs/readable_rejection_values_test.v: three actual object/symbol cases.
browserjs/writable_rejection_values_test.v: four pending operation/race cases.
browserjs/webidl_exception_values_test.v + webidl: 8/8 passed.
browserjs/webidl_binding_test.v + host_value_function_test.v: 2/2 passed;
  final focused bridge file rerun passed (three callback/capability cases).
browserjs/transform_rejection_values_test.v + streams compression encoding:
  29/29 passed, including four actual-engine transform reason cases.
tools/native_js_values_smoke.v: ordinary -prod executable passed.
html/script_cleanup_checkpoint_test.v + browserjs/script_environment_binding_test.v:
  actual realm/script frame ordering, nested cleanup, reentrancy, shared-loop
  outer contexts, per-Runtime detach, and once-per-VM generations passed.
browserjs/readable_stream_host_test.v: three actual native default-reader,
  pending callback, dictionary/size conversion, original reason and brand cases.
main_test.v, focused native readable startup: source read reached actual DOM
  replay and readiness ordering; passed.
```

Actual DOM/pipe and native clock verification:

```text
browserjs/dom_abort_signal_values_test.v: actual object/scalar/default reason,
  trusted native abort/dependencies, original throw and engine conversion cases.
streams/dom_abort_signal_test.v: actual DOM source algorithms, reentrant writable
  abort, pipe registration removal and public-record compatibility cases.
browserjs/pipe_rejection_values_test.v: three actual object/symbol original or
  later rejection cases, pending shutdown actions, lock and algorithm removal.
html/native_timer_test.v + timer_test.v: actual clock lifecycle, changed interval,
  source constructor and fractional deadline; passed.
html/global_scope_native_timeout_test.v + window_or_worker_global_scope_test.v
  + event_loop_test.v: owner task/cancellation/nesting/repeating/source clock
  and legacy adapter neighbors; passed.
html/abort_signal_timeout_test.v + dom/abort_signal_test.v: Window/Worker owning
  TimerTask, actual TimeoutError identity, source/dependent event clock and
  standalone native-clock compatibility cases; passed.
html/native_event_loop_scheduling_test.v + script_cleanup_checkpoint_test.v
  + streams/dom_abort_signal_test.v: final neighboring source checks 3/3 passed.
streams/callback_abrupt_values_test.v + bindings_callback_abrupt_test.v:
  native start/pull/cancel/write/close/abort/size and transform/flush abrupt
  completions retain the actual WebIDL value and retained DOMException record.
streams/tee_reason_values_test.v + browserjs/tee_rejection_values_test.v:
  default/byte native branch errors and shared pending cancellation retain
  original object/Symbol reasons; actual engine cases passed with -gc none.
browserjs/abort_signal_host_test.v: four actual native factory/dependency,
  EventTarget/handler, original conversion/throw, timeout and closed-owner cases
  passed with -gc none; focused main native signal DOM replay also passed.
html/classic_script_abrupt_value_test.v: actual owner reporting before context
  cleanup and original rethrow identity passed with scripting runtime neighbor.
html/timer_source_task_test.v: source callback receiver/args/throw, initiating
  script URL and current enforce/report-only CSP completion cases passed.
browserjs/timer_host_test.v: five actual timer task/context/arguments,
  queued cancellation/repeat, engine conversion/string-script, original throw/
  current CSP, and close/AbortSignal.timeout cases passed with -gc none.
main_test.v, focused native timer startup: asynchronous owner task changes reach
  actual BrowserApp.poll_javascript_tasks DOM replay; passed with -gc none.
streams/writable_writer_desired_size_test.v + writable_test.v: released getter
  TypeError versus errored nullable and closed zero desired size; 2/2 passed.
streams/writable_sink_reserved_type_test.v + writable_webidl_callbacks_test.v:
  actual any-valued reserved key rejection before source start; 2/2 passed.
browserjs/writable_stream_host_test.v: four actual pending operation/backpressure,
  owner context/Promise identity, in-flight abort/signal/later reason, original
  callback/size/thenable reason and generated-conversion/brand/subclass cases
  passed with -gc none; focused main source sink DOM replay also passed.
streams/transform_reserved_type_test.v + transform_wrapper_preparation_test.v:
  actual reserved any keys and initialized component wrapper preparation before
  start passed; transform and typed callback neighbors passed.
browserjs/readable_stream_host_test.v: original three readable cases plus actual
  readable/writable native component wrapping identity passed with -gc none.
browserjs/transform_stream_host_test.v: four actual source component/startup/
  transform/flush, identity/backpressure/controller error, pending rejection/
  cancellation and generated-conversion/brand/subclass/termination cases passed
  with -gc none; focused main transformed chunk DOM replay also passed.
webidl/number_primitive_test.v + browserjs/webidl_value_test.v: genuine number
  brand projection, actual references and no coercion of objects/BigInt/Symbol;
  passed, native -gc none.
webidl/simple_exception_value_test.v + browserjs/simple_exception_value_test.v:
  retained typed descriptor, one actual engine Error, distinct record identity,
  captured source exception constructors and closed-owner checks passed.
streams/size_value_order_test.v + queue/callback-abrupt/transform neighbors:
  raw size completion, reentrant writer lock/state order, source component
  propagation and one stored RangeError value; 4/4 passed.
browserjs/stream_size_value_order_test.v + transform_stream_host_test.v: actual
  numeric and rejected non-number results without coercion, original abrupt
  values, owner callback contexts, writer reentrancy and exact RangeError identity
  across synchronous throws and later read/write/closed reactions; 2/2 -gc none.
browserjs/webidl_callback_order_test.v: generic callback and actual stream size
  call preserve source invocation/context when caller realm can_run is false.
streams/pipe_through_entry_test.v + pipe/tee/pending neighbors: source/writable
  lock ordering, allowed locked returned readable, handled internal rejection
  and returned actual stream identity; 3/3 passed.
```

Focused follow-up verification (all native checks use `-gc none`):

```text
browserjs/readable_stream_pipe_test.v: actual pending pipe writes/close,
  source/destination brands and dictionary order, exact pipeThrough return,
  original arbitrary abort and default native AbortError identity; passed.
browserjs/readable_constructor_conversion_test.v + readable/pipe neighbors: source
  constructor conversion, genuine ToNumber and one prototype lookup; passed.
browserjs/writable_constructor_prototype_test.v + writable host: writer/stream
  prototype lookup before argument and dictionary conversion; passed.
browserjs/transform_constructor_prototype_test.v + transform host: prototype
  lookup before component strategies and transformer conversion; passed.
webidl/promise_iterator_test.v + simple exception neighbor: source
  rejected-promise helpers retain the typed native descriptor; passed.
streams/void_promise_adoption_test.v + tee pending/pipe neighbors: actual
  one-shot pending adoption, source owner jobs, rejection identity and lazy
  public heap-record construction; passed.
streams/tee_clone_order_test.v + tee/pending/pipe neighbors: clone before either
  read fulfillment, original abrupt value, pending cancellation adoption,
  cancelled-branch skip, nested opaque boundary rejection and reentrant clone
  cancellation preserving the first Resolve call; passed.
```

Queuing strategy and wrapper verification:

```text
html/queuing_strategy_size_functions_test.v + universal_global_scope_test.v:
  lazy owner-global cache creation, same callback identity, separate globals
  and creator ownership passed with -gc none.
streams/strategy_size_callback_test.v + queue_strategies_test.v: source global
  getter delegation without callback invocation and scalar adapter neighbors;
  2/2 passed with -gc none.
browserjs/queuing_strategy_host_test.v: four actual native-record/high-water-
  mark, shared callable builtin identity, original GetV values/throws, brands,
  prototype/IDL/ToNumber/subclass and real queue cases passed with -gc none.
browserjs/stream_interface_tag_test.v + existing readable/writable/transform
  host files: source inherited/changed tags, original getter throws, forged
  prototype rejection, actual record identity and close cleanup; 4/4 passed.
main_test.v, focused native queuing-strategy startup: source queue operations
  and actual chunk identity reach live DOM replay; passed with -gc none.
```

```text
browserjs/abort_constructor_prototype_test.v + abort_signal_host_test.v +
  readable_stream_pipe_test.v: source controller prototype Get once/original
  throw before record creation, illegal signal constructor ordering, actual
  tags/brand/event identity, native owner timeout and public pipe neighbors;
  3/3 passed with -gc none.
```

Generated Stream and strategy constructor metadata now follows
`Bindings/InterfaceObject.cpp`: constructor `prototype` properties have no
attribute flags, and controller interfaces without IDL constructors reject
construction before reading `newTarget.prototype`. The bridge retains actual
native records and engine subclass prototypes.

```text
browserjs/stream_constructor_metadata_test.v + readable conversion/writable
  prototype/transform prototype neighbors: eleven readonly constructor
  prototypes, four illegal-controller lookup-order checks and native
  subclass behavior; 4/4 files passed with -gc none.
```

Cached queuing-strategy size functions now use actual JavaScriptCore native
functions for the source `CreateBuiltinFunction` surface. Their `name` and
`length` descriptors, Function prototype, lack of construction/prototype and
native source text follow the source callback contract. The byte-size callback
performs actual engine GetV, preserving primitive getter receivers and original
values/errors without numeric coercion. The exact function-reference registry
retains its owning Runtime's callback record and is cleared on Runtime close;
it does not claim source wrapper GC reclamation before that boundary.

```text
browserjs/native_value_host_function_test.v + queuing_strategy_builtin_test.v
  + queuing_strategy_host_test.v: native function metadata, actual owner
  identity, per-owner cleanup, stable global cache, primitive GetV receivers,
  original getter completions and queue/factory neighbors; 3/3 with -gc none.
```
