# WebSockets module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebSockets`

Translation workspace: `~/code/libweb_v/websockets`
Audited: 2026-08-17

The upstream implementation unit, header, and WebIDL definition are represented
by `web_socket.v`. The port covers URL parsing and HTTP(S)-to-WebSocket scheme
conversion, subprotocol validation, ready-state transitions, close validation,
text/blob/buffer sending, open/error/close/message feedback, binary modes,
make-disappear/finalization behavior, and event-listener GC liveness.

| Upstream source | V implementation |
| --- | --- |
| `WebSocket.cpp` | `web_socket.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `WebSockets/` | 1 | 429 | 285 | 100 | Complete |

Associated declarations: 1 header / 86 LOC and 1 IDL file / 33 LOC. Mapping
completeness is 1/1 implementation unit, 1/1 header, and 1/1 IDL definition.

`net.urllib` is the explicit URL-parser boundary. The Requests/WebSocket
transport and task queue are represented by `establish`, the sent-frame record,
and typed protocol feedback callbacks. Upstream's `[FIXME] bufferedAmount`
attribute remains explicitly unimplemented.

Verification: `v test websockets` passes 1/1; formatting and scoped diff checks
pass.
