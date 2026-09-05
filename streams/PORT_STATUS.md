# Streams module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Streams`

Translation workspace: `~/code/libweb_v/streams`
Audited: 2026-09-04

All 25 upstream Streams `.cpp` implementation units have audited V mappings.
The 28 headers and 17 WebIDL definitions were cross-audited as well; their
observable types, dictionaries, mixins, state machines, controller operations,
reader/writer operations, and transfer algorithms are represented by the typed
V package.

| Upstream implementation units | V implementation |
| --- | --- |
| `AbstractOperations.cpp` | `queue.v`, `types.v`, `cross_realm_transform_operations.v` |
| `ByteLengthQueuingStrategy.cpp`, `CountQueuingStrategy.cpp` | `strategies.v` |
| `GenericTransformStream.cpp` | `transform.v` |
| `ReadableByteStreamController.cpp` | `readable_byte.v` |
| `ReadableStream.cpp` | `readable.v`, `pipe_tee_transfer.v` |
| `ReadableStreamAsyncIterator.cpp` | `readable.v` |
| `ReadableStreamBYOBReader.cpp`, `ReadableStreamBYOBRequest.cpp` | `readable_byte.v` |
| `ReadableStreamDefaultController.cpp`, `ReadableStreamDefaultReader.cpp`, `ReadableStreamGenericReader.cpp` | `readable.v` |
| `ReadableStreamOperations.cpp` | `readable_operations.v`, `readable_controller_operations.v`, `readable.v`, `readable_byte.v`, `queue.v` |
| `ReadableStreamPipeTo.cpp`, `ReadableStreamTee.cpp` | `pipe_tee_transfer.v` |
| `TransformStream.cpp`, `TransformStreamDefaultController.cpp`, `TransformStreamOperations.cpp`, `Transformer.cpp` | `transform.v`, `transform_operations.v` |
| `UnderlyingSink.cpp` | `writable.v`, `writable_operations.v` |
| `UnderlyingSource.cpp` | `readable.v`, `readable_operations.v` |
| `WritableStream.cpp`, `WritableStreamDefaultController.cpp`, `WritableStreamDefaultWriter.cpp`, `WritableStreamOperations.cpp` | `writable.v`, `writable_operations.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Streams/` | 25 | 8,784 | 5,645 | 1,649 | Parity-audited; runtime boundary isolated |

The associated declarations comprise 28 headers / 2,139 LOC and 17 IDL files /
219 LOC. Mapping completeness is 25/25 implementation units, 28/28 headers, and
17/17 IDL definitions audited.

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

The public surface covers all 17 IDL definitions: `ReadableStream`, both reader
types and their generic-reader mixin, both readable controllers, BYOB requests,
`WritableStream`, its writer and controller, `TransformStream`, its controller
and generic-transform mixin, both queuing-strategy classes, and the strategy,
source/sink/transformer, reader, iterator, pipe, and pair dictionaries used by
those interfaces.

## Boundary

Ladybird represents stream chunks as arbitrary LibJS values and schedules real
WebIDL promise reactions on the JavaScript job queue. The standalone V package
uses a recursively cloneable typed `Value` and observable synchronous promise
records; callbacks run synchronously, while pending read, pipe, close, error,
abort, and BYOB settlement is retained. Generated bindings, realms/GC tracing,
JavaScript iterator acquisition, and HTML `MessagePort` event dispatch remain
owned by the bindings, LibJS, and HTML translations. The package models the
Streams-specific algorithms and transfer endpoints without claiming those
runtime integration layers.

No Streams implementation remains in an `upstream_*_entry_points.v` quarantine
file. The strict symbol audit reports 0 unmatched Streams bodies: private C++
pipe, tee, and read-request callback classes are explicitly mapped to the
reviewed V pumps that consolidate them, and `Transformer`, `UnderlyingSource`,
and `UnderlyingSink` JavaScript-object conversion is classified as a typed
bindings boundary. The suspicious-trivial queue contains only verified value
constructors, controller release/no-op algorithms, and default sink callbacks.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test streams
Summary for all V _test.v files: 7 passed, 7 total.

$ /Users/alex/code/v/v fmt -verify streams
(no output; exit status 0)
```
