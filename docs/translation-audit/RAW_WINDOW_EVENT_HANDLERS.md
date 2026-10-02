# Raw Window event-handler compilation

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`, `DOM/EventTarget.cpp:588–723` and `event_handler_listener_realm()` / `activate_event_handler()`. `HTML/EventHandler.{h,cpp}` owns the raw-or-callback value and activated listener; the compilation algorithm lives in `DOM/EventTarget.cpp`.

## DOM state and owner boundary

`dom/events.v` retains the raw handler and its activated listener when scripting is disabled. A genuine compiler is provided by the actual owning Document across the DOM/runtime module boundary. A missing compiler or unsupported environment leaves the raw value available; the generated inert callback has been removed.

Actual parse or early-error rejection sets the existing handler's value to null. It preserves the handler record and activated listener, and subsequent getters return null until the attribute is replaced. Existing attribute CSP checks still precede replacement and compilation. The activation listener retains its original relevant Document reporting boundary, including when a raw attribute predates installation of the native engine binding.

Five focused model cases pass with default GC and `-gc none`: disabled/later-enabled compilation, null-on-error with stable listener identity, CSP-before-replacement, unavailable compiler preservation, and original activation-owner reporting. The existing UI-event and handler-invocation neighbors pass with `-gc none`.

## Genuine owning Window functions

The native EventTarget binding installs `Runtime.install_window_event_handler_compiler()` for its actual owning Document. The compiler supports that Document's genuine Window target. Window raw handlers use the source global environment; they require no document/form/element object-environment chain.

`browserjs/window_event_handler_compiler_darwin.c.v` validates syntax and early errors with the owning engine, creates a genuine JavaScriptCore dynamic function with the source name and parameter list, and pushes/pops the actual retained realm execution-context record for creation. Compilation performs no HTML callback cleanup or microtask checkpoint. Ordinary handlers have one `event` parameter; actual Window `onerror` handlers have `event`, `source`, `lineno`, `colno`, and `error`.

The actual dynamic-function API creates the function in its owning global environment without an added factory or named-function-expression scope. Callback preparation stores the relevant settings realm. The callback/function identity is retained in the existing native binding map, and Event wrappers, strict-boolean cancellation, BeforeUnloadEvent conversion, original JavaScript exception values and original activation-owner reporting use the existing native invocation path.

The pinned source leaves syntax-error location/reporting as a FIXME. This implementation preserves that boundary: syntax failures become null handlers without fabricating console reports or author error events.

Six focused native cases pass with default GC and `-gc none`. They cover lazy compilation and actual callback identity, source global lookup without extra name/factory scope, realm-context and checkpoint ordering, syntax/early errors with stable activation, script gates and unsupported element scope, body-to-Window CSP ordering, five original error arguments, cancellation and original throw/BeforeUnload conversion reasons. Five existing native EventTarget cases and five handler-invocation cases pass with `-gc none`.

## Remaining DN-01 boundaries

- Element handlers still require the source `new_event_handler_object_environment()` chain over their actual Document, form owner and element wrappers. The compiler keeps these handlers raw. No default-global function or substitute lexical scope is installed for them.
- Public compact Window handler accessors, compact listener/click dispatch and general element handler accessors still need to enter these actual native records and Event wrappers. Typed/native Window compilation alone does not complete those public paths.
- Raw attribute text currently reaches this boundary through the DOM's UTF-8 compatibility string representation. Full UTF-16 source storage, source locations and source parser/function-data ownership remain separate work.
- JavaScriptCore owns the actual dynamic functions and global environment. The source LibJS function record, its explicit ScriptOrModule slot, complete execution and VM/wrapper GC remain separate translation work.
- The native dynamic-function API inserts a newline before the parameter-list closing parenthesis in `Function.prototype.toString()`. The source-synthesized text is retained separately on the callback; exact native source-text formatting remains a backend boundary. A named-function-expression replacement would introduce an incorrect lexical environment and is not used.
- General Worker globals and element/form named-property bindings remain outside the completed Window path.
