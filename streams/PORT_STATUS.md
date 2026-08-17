# Streams module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Streams`

Translation workspace: `~/code/libweb_v/streams`
Audited: 2026-08-17

All 25 upstream Streams `.cpp` implementation units have audited V mappings.
The 28 headers and 17 WebIDL definitions were cross-audited as well; their
observable types, dictionaries, mixins, state machines, controller operations,
reader/writer operations, and transfer algorithms are represented by the typed
V package.

| Upstream implementation units | V implementation |
| --- | --- |
| `AbstractOperations.cpp` | `queue.v`, `types.v`, `pipe_tee_transfer.v` |
| `ByteLengthQueuingStrategy.cpp`, `CountQueuingStrategy.cpp` | `strategies.v` |
| `GenericTransformStream.cpp` | `transform.v` |
| `ReadableByteStreamController.cpp` | `readable_byte.v` |
| `ReadableStream.cpp` | `readable.v`, `pipe_tee_transfer.v` |
| `ReadableStreamAsyncIterator.cpp` | `readable.v` |
| `ReadableStreamBYOBReader.cpp`, `ReadableStreamBYOBRequest.cpp` | `readable_byte.v` |
| `ReadableStreamDefaultController.cpp`, `ReadableStreamDefaultReader.cpp`, `ReadableStreamGenericReader.cpp` | `readable.v` |
| `ReadableStreamOperations.cpp` | `readable.v`, `readable_byte.v`, `queue.v` |
| `ReadableStreamPipeTo.cpp`, `ReadableStreamTee.cpp` | `pipe_tee_transfer.v` |
| `TransformStream.cpp`, `TransformStreamDefaultController.cpp`, `TransformStreamOperations.cpp`, `Transformer.cpp` | `transform.v` |
| `UnderlyingSink.cpp` | `writable.v` |
| `UnderlyingSource.cpp` | `readable.v` |
| `WritableStream.cpp`, `WritableStreamDefaultController.cpp`, `WritableStreamDefaultWriter.cpp`, `WritableStreamOperations.cpp` | `writable.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Streams/` | 25 | 8,784 | 2,640 | 822 | Complete |

The associated declarations comprise 28 headers / 2,139 LOC and 17 IDL files /
219 LOC. Mapping completeness is 25/25 implementation units, 28/28 headers, and
17/17 IDL definitions audited.

The translation implements queue-with-size FIFO operations and numeric
validation; count and byte-length strategies; readable/default-reader lifecycle;
pending reads; desired-size and close/error propagation; byte queues, pull-into
descriptors, BYOB readers and requests, minimum-fill validation, partial views,
and auto-allocation; writer locking, close/abort/error transitions, controller
abort signals, backpressure records, and underlying sink algorithms; identity
and custom transform/flush/cancel algorithms; pipe shutdown and prevention
flags; live abort signals; default and byte tee branches with composite
cancellation; async iteration; structured cloning; ArrayBuffer transfer and
view validation; message packing; and readable/writable transferred proxies.
The final cross-audit additionally verifies release-time rejection of pending
default and BYOB reads, BYOB view invalidation and partial-byte preservation,
writer `ready` promise transitions, branch-ordered tee cancellation and
settlement, direct source/destination pipe failures, controller size-algorithm
ordering, and the transform readable-side default high-water mark.

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

## Verification

```text
$ /Users/alex/code/v/v test streams
Summary for all V _test.v files: 6 passed, 6 total.

$ /Users/alex/code/v/v fmt -verify streams
(no output; exit status 0)
```
