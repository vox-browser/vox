# Streams module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Streams`

Translation workspace: `~/code/vox2/streams`
Audited: 2026-09-12
Pending callback re-audit: 2026-10-02

All 22 upstream Streams `.cpp` implementation units have audited V mappings.
The 25 headers and 20 WebIDL definitions were cross-audited as well; their
types, dictionaries, mixins, state machines, controller operations,
reader/writer operations, and transfer algorithms have typed V mappings.
These mappings do not establish complete browser or JavaScript runtime parity.
The pending-callback re-audit and remaining boundaries are recorded in
[`STREAMS_PENDING_CALLBACKS.md`](../docs/translation-audit/STREAMS_PENDING_CALLBACKS.md).

| Upstream implementation units | V implementation |
| --- | --- |
| `AbstractOperations.cpp` | `queue.v`, `types.v`, `bindings_glue.v`, `cross_realm_transform_operations.v` |
| `ByteLengthQueuingStrategy.cpp`, `CountQueuingStrategy.cpp` | `strategies.v` |
| `GenericTransformStream.cpp` | `transform.v` |
| `ReadableByteStreamController.cpp` | `readable_byte.v` |
| `ReadableStream.cpp` | `readable.v`, `pipe_tee_transfer.v`, `transfer_bindings.v` |
| `ReadableStreamAsyncIterator.cpp` | `readable.v` |
| `ReadableStreamBYOBReader.cpp`, `ReadableStreamBYOBRequest.cpp` | `readable_byte.v` |
| `ReadableStreamDefaultController.cpp`, `ReadableStreamDefaultReader.cpp`, `ReadableStreamGenericReader.cpp` | `readable.v` |
| `ReadableStreamOperations.cpp` | `readable_operations.v`, `readable_controller_operations.v`, `readable.v`, `readable_byte.v`, `queue.v` |
| `ReadableStreamPipeTo.cpp`, `ReadableStreamTee.cpp` | `pipe_tee_transfer.v`, `operation_realms.v` |
| `TransformStream.cpp`, `TransformStreamDefaultController.cpp`, `TransformStreamOperations.cpp`, `Transformer.cpp` | `transform.v`, `transform_operations.v` |
| `UnderlyingSink.cpp` | `writable.v`, `writable_operations.v` |
| `UnderlyingSource.cpp` | `readable.v`, `readable_operations.v` |
| `WritableStream.cpp`, `WritableStreamDefaultController.cpp`, `WritableStreamDefaultWriter.cpp`, `WritableStreamOperations.cpp` | `writable.v`, `writable_operations.v`, `transfer_bindings.v` |

The 2026-10-02 pending-callback translation additionally maps source Promise
reactions to `promise_callbacks.v`, `webidl_callbacks.v`,
`readable_pipe_operations.v`, `readable_tee_promise_operations.v`, and
`transform_promise_operations.v`; owning HTML constructors and job dispatch are
in `html/stream_operations.v`. The following size metrics are the original
2026-09-12 audit snapshot.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Streams/` | 22 | 8,789 | 6,290 | 1,972 | Parity-audited; runtime boundary isolated |

The associated declarations comprise 25 headers / 2,066 LOC and 20 IDL files /
229 LOC. Mapping completeness is 22/22 implementation units, 25/25 headers, and
20/20 IDL definitions audited.

The translation implements queue-with-size FIFO operations and numeric
validation; count and byte-length strategies; readable/default-reader lifecycle;
pending reads; desired-size and close/error propagation; byte queues, multiple
pull-into descriptors, BYOB readers and requests, minimum-fill validation,
partial views, remainder preservation, and auto-allocation; writer request and
in-flight lists, close sentinels, close/abort/error transitions, controller
abort signals, backpressure records, and underlying sink algorithms; identity
and custom transform/flush/cancel algorithms; ordered pipe shutdown and
prevention flags; live abort signals; demand-driven default and byte tee
branches with composite cancellation; lazy iterable streams; async iteration;
structured cloning; moving ArrayBuffer transfer and view validation; message
packing and pull handshakes; and readable/writable transferred proxies built
through the cross-realm transforms.

The 2026-09-12 upstream refresh adds realm-aware stream factories and promise
records, distinct readable result realms, reader/writer/pipe/tee operation realm
accessors, callback binding adapters, stable wrapper slot mappings, native and
already-transferred byte enqueue paths, and separated stream transfer encoding
and receiving steps. Transfer receivers now replay pull messages which arrived
before the receiving endpoint was installed.

The 2026-09-04 cross-audit replaced locally invented eager queue draining,
one-request BYOB shortcuts, eager tee/from/transfer copies, direct writable sink
dispatch, and direct transfer proxies with the corresponding upstream state
machines. It additionally verifies reusable transform finish promises,
release-time rejection of pending default and BYOB reads, BYOB view invalidation
and partial-byte preservation, writer `ready` transitions, branch-ordered tee
cancellation and settlement, source/destination pipe failures and replacement
reasons, cross-realm cancellation in both directions, controller
size-algorithm ordering, and the transform readable-side default high-water
mark.

The final controller review also replaced copied temporary stream/controller
graphs with setup on the destination object; translated default and byte tee
now use the source reader mode selected by branch demand, including the
requesting branch's BYOB view; pipe-to acquires and releases real reader/writer
objects; transform writes remain pending behind the upstream backpressure
change promise; and synchronous readable, writable, and transformer `start`
exceptions propagate from construction instead of manufacturing errored
streams. Writable close and in-flight state now comes from its canonical
request slots rather than three parallel booleans.

The queue-shape re-audit also translated Ladybird's retained
`SinglyLinkedList` slots instead of using front-deleted V arrays. Default
controller queues, the readable byte queue, pending BYOB pull-into descriptors,
default-reader read requests, and writable write requests now append and remove
their heads in O(1). Long FIFO regressions cover 4,096 queued chunks, reads, and
writes; partial byte-queue consumption advances the source offset without
cloning every remainder.

The public surface covers all 20 IDL definitions: `ReadableStream`, both reader
types and their generic-reader mixin, both readable controllers, BYOB requests,
`WritableStream`, its writer and controller, `TransformStream`, its controller
and generic-transform mixin, both queuing-strategy classes, and the strategy,
source/sink/transformer, reader, iterator, pipe, and pair dictionaries used by
those interfaces.

## Boundary

Ladybird represents chunks as arbitrary LibJS values. The V package now also
carries real owning JSC value references through its WebIDL/Streams boundary;
actual cyclic object/function/symbol chunks and readable/writable/transform
rejection values preserve identity. Wrapper worlds, GC tracing/reclamation,
JavaScript iterator acquisition, opaque structured cloning, JSC BYOB view
transfer/detachment, actual DOM AbortSignal ownership, and compact writable and
transform factories remain open runtime boundaries. The native browser exposes
an owning-record default-readable constructor/reader/controller subset; public
pipe/tee/from/iterator, byte enqueue, BYOB JS operations and complete generated
constructor/wrapper behavior remain unbound.

Underlying source, sink, and transformer dictionaries now retain native
WebIDL `CallbackType` values, the actual receiver, and the actual controller
address. The source start callback may return a pending Promise value; pull,
write, close, abort, cancel, transform, and flush use WebIDL Promise callback
conversion. `VoidPromise` retains an actual native WebIDL Promise backend.
Read/BYOB read capabilities likewise retain their native Promise backend.
The controller flags, in-flight requests, backpressure, pipe shutdown, tee
cancel/delivery, and shared transform startup remain pending until the source
fulfillment/rejection jobs run.

`EnvironmentSettingsObject` Stream factories attach that backend to their
actual Window/Worker loop and realm. Promise jobs capture the active classic
script and implied document, prepare the source script/callback context, and
clean it up after execution. Native standalone callers without a scheduler
keep the explicit direct job adapter. This adapter is not a browser Promise
job queue. The compact JSC prerequisite now adopts real callback Promises and
thenables using actual engine Resolve; one native capability wraps into one
stable real JSC Promise. Settled bridges release resolver roots, but retain
their Promise root and bridge record until Runtime.close. Browser script cleanup
drains the actual owning loop after popping author/realm VM contexts. Shared
loops track all actual per-Runtime embedding VMs without replacing the primary
source VM; this does not establish a shared complete LibJS browser agent.
Module execution-
context capture, complete generated Stream bindings, pipe/tee arbitrary reason
values, and source host-object GC reclamation remain open. See
[`STREAMS_PENDING_CALLBACKS.md`](../docs/translation-audit/STREAMS_PENDING_CALLBACKS.md).

The original symbol audit found no Streams bodies in an
`upstream_*_entry_points.v` quarantine file. Symbol coverage did not detect the
omitted pending underlying-callback Promise semantics reported as WA-09.
The source reactions and retained callback operation records above replace
those omissions; JavaScript object conversion remains a typed boundary.

## Verification

```text
$ /Users/alex/code/v/v -old-compiler -enable-globals test streams compression encoding
Summary for all V _test.v files: 27 passed, 27 total.

$ /Users/alex/code/v/v -old-compiler -enable-globals test html/stream_operations_test.v
Summary for all V _test.v files: 1 passed, 1 total.
```
