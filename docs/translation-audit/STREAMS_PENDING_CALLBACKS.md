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

## Actual DOM abort reasons and owning timeout delivery

`dom.JSValue` now carries the actual WebIDL/engine value for arbitrary reasons.
Object, symbol and scalar reasons keep identity; `throwIfAborted()` throws the
original value. Undefined chooses a retained native `DOMException` record.
`streams.AbortSignal` delegates to the actual `dom.AbortSignal`: source ordered
abort algorithms, dependencies, trusted abort events, registration removal and
writable reentrant abort state checks execute on that native record. PipeTo
shutdown retains the original arbitrary reason while pending abort/cancel/write
operations settle; a later shutdown action rejection replaces it in the source
order. Public tee rejection propagation still needs a separate review.

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
AbortSignal/AbortController factories are still pending. Full timer string/CSP
binding and source GC finalization integration are not established by this
scheduler slice. The pinned upstream also retains its fully-active/worker
suspension elapsed-time, ordering-identifier and additional-wait FIXMEs.

The following boundaries are still open and are not counted as full parity:

- `WritableStream` and `TransformStream` JSC factories remain unbound. The
  readable binding does not expose public pipe/tee/from/iterator operations,
  BYOB reader constructors/read operations, byte-controller enqueue/BYOBRequest,
  subclass constructor prototype selection, or full generated wrapper worlds.
- Generic JavaScript iterator acquisition and structured cloning of opaque
  chunks (including a public tee's cloning branch) remain unbound. Typed byte
  conversion does not provide JSC BYOB ArrayBuffer transfer/detachment or shared
  native view ownership. Public tee arbitrary rejection-value propagation still
  needs its own source review; PipeTo original-value propagation is completed.
- Actual DOM signals and timeout tasks are connected to native Streams records.
  Public JSC AbortSignal/AbortController/EventTarget bindings remain pending.
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
```
