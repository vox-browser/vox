# Document beforeunload decision and actual Window dispatch

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/DOM/Document.cpp:10660–10714`,
`HTML/Window.cpp:518–521`, `HTML/BeforeUnloadEvent.cpp:15–25`,
`HTML/SandboxingFlagSet.h:32`, and `WebDriver/UserPrompt.cpp:122–153`.

The V `Document.steps_to_fire_beforeunload()` ignored the entire prompt decision
after dispatch. It also invoked the base dispatcher with no legacy target
override, and created the event with a shared-clock timestamp. A real
beforeunload handler therefore could not cancel a close or navigation through
the translated Document algorithm.

The method now dispatches through the actual relevant Window's translated
virtual method. The trusted, cancelable BeforeUnloadEvent receives that Window's
current high-resolution clock. Source Window dispatch keeps Window as the
current target and its current associated Document as the event target. The
existing factory still supplies its default timestamp for other callers; this
algorithm installs Source's explicit timestamp before dispatch.

Step 6 now checks the existing prompt-shown state, the document being unloaded's
sandboxed-modals bit, the actual relevant Window's sticky activation, and the
dispatch result or the event's retained returnValue. An eligible prompt sets
prompt-shown and consults the existing translated WebDriver prompt handler for
beforeUnload. Exactly as pinned Source does, only Dismiss cancels unloading;
Accept and Ignore leave it uncanceled. DOM imports that existing WebDriver
owner directly; no substitute prompt hook or settings snapshot is introduced.
The unload counter and actual HTML event loop termination nesting retain
Source's dispatch and cleanup order.

Four cases in `html/document_beforeunload_owner_test.v` use actual
navigation-created Documents, Pages, Windows, listeners/IDL handlers, activation
dispatch and WebDriver policy. They verify trusted event identity and virtual
target/currentTarget behavior, document-relative timestamps, callback-time
unload/nesting counters and restoration, sticky activation after transient
consumption, modal sandboxing, an already shown prompt, uncanceled empty events,
preventDefault, nonempty returnValue without event cancellation, exact
beforeUnload/default/fallbackDefault policy precedence, and temporary Window
Document reassociation. The latter proves that Window dispatch/clock use its
current associated Document while Step 6 uses the document being unloaded's
sandbox flags.

Default GC passed all four focused cases in
`Build/audit-fixes/source-document-beforeunload-owner-complete-default.log`.
The GC-none neighbor batch passed 8/8 files in
`source-document-beforeunload-owner-gc-none.log`, covering traversable history,
Window current-event identity and activation, DOM event/unload dispatch, and
the actual WebDriver policy algorithm. Commands use
`v -old-compiler -enable-globals test`, with `-gc none` for that batch. The
initial test-only Option propagation compile errors remain recorded in
`source-document-beforeunload-owner-default.log`.

Pinned Source itself leaves the annoyance/deception check, interactive unload
confirmation/wait, and WebDriver BiDi prompt-opened/closed notifications as
FIXMEs; this translation retains those boundaries. DOM-only Documents without a
Window retain the existing no-event/no-prompt adapter path. This prerequisite
does not certify traversable canceled-close recovery, close-step deduplication,
forced-close mode, Page history-executor completion or UI-process close tasks.
It also does not claim native JavaScriptCore BeforeUnloadEvent bindings or the
full Window.close incumbent/sandbox/task algorithm.
