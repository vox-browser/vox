# Native Document and Window readiness events

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/HTMLParser.cpp:784–800,842–870`, `DOM/EventTarget.cpp`, and
`HTML/Window.cpp:518–521`.

The compact browser now binds its existing Document facade to the actual owning
Document EventTarget and its actual JavaScriptCore global to the owning Window.
Public add/remove/dispatch methods use the translated native listener records.
Source callback conversion, receiver identity, once/removal behavior, cancellation,
owner execution gates, original exceptions, and Event identity reach those records.
Window handler accessors and parser-created body handlers use the same map.

Readiness dispatch creates actual trusted Event records with the owning settings'
high-resolution clock. DOMContentLoaded bubbles from Document through Window;
load dispatches at Window, retaining the pinned source's Document target override.
The compact browser checks source settings before each readiness dispatch, and
individual native callbacks recheck their own actual settings.

Five focused native cases pass without GC in
`Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/source-handler-attribute-native-gc-none.log`,
alongside Window accessor and raw-compiler neighbors (3/3 files). They cover
trusted event fields and targets, real body-onload raw compilation, listener
flags and cancellation, per-callback gates, and original owner exception identity.
The earlier native body-handler failure exposed the missing DOM attribute hook;
that prerequisite is separately fixed in `5a4d63b3`.

The compact loader retains its existing post-script readiness phase. Full source
parser end-state task scheduling, timing-field updates, and parser-blocking script
execution are not completed by this binding slice. The JavaScriptCore Window
and Document remain host facades; their complete prototype/WindowProxy graph,
element/form raw-handler environments, and LibJS browser execution remain separate
audit work. Static pages with raw Window handlers are covered by the separate
[static handler startup slice](STATIC_WINDOW_HANDLER_STARTUP.md).
