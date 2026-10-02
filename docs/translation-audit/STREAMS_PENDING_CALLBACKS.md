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

The following boundaries are still open and are not counted as full parity:

- The compact browser's JSC globals do not expose owning native
  `ReadableStream`, `WritableStream`, or `TransformStream` factories through
  this slice. JSC Promise objects are not native WebIDL Promise values.
- `streams.Value` represents primitives, recursive sequences, and bytes.
  Arbitrary JavaScript chunks, rejection reason object identity, JS getters,
  generic thenables, and JS iterator acquisition require the real object
  runtime. Byte conversion uses the existing typed BufferSource copy boundary.
- Controller platform values retain native identity, but generated JS
  prototypes/wrapper worlds, GC tracing and wrapper lifetime ownership still
  require bindings integration. The native tests do not claim those layers.
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
