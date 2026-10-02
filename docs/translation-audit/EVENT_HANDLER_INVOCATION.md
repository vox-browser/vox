# Event-handler invocation source slice

Compared against Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`, without modifying the upstream checkout.

This slice fixes invocation of actual owning JavaScriptCore callbacks registered through `Runtime.set_javascript_event_handler()` on retained native DOM records. It does not close DN-01's raw inline-handler compilation finding.

| Upstream source | Translation |
| --- | --- |
| `DOM/EventTarget.cpp`, `Bindings::invoke_event_handler()` | `browserjs/event_target_binding_darwin.c.v` passes the message, filename, line, column and original error value for an actual `ErrorEvent` named `error` whose current target is the translated Window. Ordinary handlers and listeners receive one actual Event wrapper. The receiver remains the actual current-target wrapper. |
| `DOM/EventTarget.cpp`, `event_handler_listener_realm()` and `activate_event_handler()` | `dom/events.v` retains the initially selected callback Window and exception reporter on the activation listener. Replacing a handler keeps that listener and its original realm. |
| `DOM/EventDispatcher.cpp`, `inner_invoke()` | The original abrupt completion reaches the activation listener and is reported once through its callback realm. Dispatch then continues with the legacy exception flag set. Native invocation no longer reports eagerly before propagation. |
| `DOM/EventTarget.cpp`, `process_event_handler_for_event()` | A non-nullish actual BeforeUnloadEvent result sets cancellation before throwing ToString conversion. Conversion runs only while the existing return value is empty. An original conversion exception propagates without overwriting the empty value or clearing cancellation. The strict boolean checks for ordinary handlers and special error handlers remain intact. |
| `HTML/BeforeUnloadEvent.idl` and `BeforeUnloadEvent.h` | Actual native BeforeUnloadEvent wrappers have their own DOMString `returnValue`, its source brand check and throwing conversion, the Event prototype chain, and the interface's non-constructible constructor. Setting this string attribute does not itself cancel an event. |

Native callback preparation, stored incumbent settings, script gates, cleanup and actual author exception values reuse the existing owning-runtime bridge. Arbitrary error objects remain rooted original engine values; native DOMException records use their existing same-object wrappers. No callback or reason is serialized.

Validation: five native invocation cases pass with default GC and with `-gc none`. A separate DOM test verifies original activation-listener realm identity, exception reporting and the legacy exception flag after replacing the handler. The five existing native EventTarget cases and thirteen DOM UI-event cases also pass with `-gc none`.

## Remaining DN-01 boundaries

- `compile_raw_event_handler()` still synthesizes a source string and returns an inert callback. It does not compile the source, preserve syntax failures through the engine, install the source document/form/element ObjectEnvironment chain, or set the compiled function's ScriptOrModule to null.
- The compact document/element/global Window handler accessors and native click adapter still require integration with these actual owning callback records. Calling the native setter in these focused tests does not establish that public compact `window.onerror`, `onbeforeunload` or attribute-created handlers already use this path.
- The raw-handler compiler's disabled-script and syntax-failure state transitions require their own source correction. Existing attribute CSP checks were inspected and preserved; this slice adds no compilation fallback or substitute scope algorithm.
- The special-error predicate currently supports the translated native Window. Full Worker global wrappers and their WindowOrWorkerGlobalScope classification remain separate work.
- Full LibJS execution and VM/wrapper GC are not implied by this JavaScriptCore adapter.
