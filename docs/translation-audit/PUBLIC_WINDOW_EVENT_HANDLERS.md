# Public Window event handler accessors

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`HTML/GlobalEventHandlers.{h,cpp}`, `HTML/WindowEventHandlers.{h,cpp}`, and
`HTML/Window.h:314–318`.

Feature commit `b9e6b32d` exposes Window handler attributes through their actual
retained Source EventTarget/Callback records. The exact 118 attribute/event-name
pairs come from the two pinned header enumerations, including the case-sensitive
vendor event names. Getters invoke `event_handler_attribute`; setters invoke
`set_event_handler_attribute` through the existing native callback conversion.

Registration binds `JSContextGetGlobalObject` to the actual owning Window. It
does not fabricate a second Window wrapper or obtain identity from the mutable
author `globalThis` property. The same native EventTarget map used for callbacks
and platform-object clone rejection retains that actual identity. Installation
is tracked in a native per-runtime registry and removed at Runtime.close().
Per-accessor name validation uses a compiled source-name match without allocating
a temporary name vector on every getter/setter.

Seven focused cases verify all 118 accessors, callback identity, receiver brands,
source null/non-callable conversion, lazy raw compilation and disabled-state
retention, Window error/beforeunload arguments and return rules, vendor name case,
owner gates/original exceptions, and actual engine-global identity after author
`globalThis` reassignment. The latter case initializes the Event/EventTarget
interfaces before author code, as the owning realm setup requires.

Validation in `Build/audit-fixes/worktrees/06-canvas-animation/Build/audit-fixes/`:

- `source-public-window-handlers-final-default.log` and
  `source-public-window-handlers-final-gc-none.log`: seven cases passed before
  the separately corrected Source Window dispatch override.
- `source-window-dispatch-public-default.log`: the seven updated accessor cases
  passed with the source Document target.
- `source-window-dispatch-public-gc-none.log`: 4/4 files passed, including the
  updated accessor cases, corrected DOM override, raw compiler, and native
  handler invocation neighbors.

The JavaScriptCore global is still an explicit host facade. The complete Source
Window/WindowProxy prototype and cross-realm wrapper graph, actual LibJS VM
ownership, complete callback argument wrappers, and element/form/document
handler environments remain separate audit work. Event/EventTarget interface
bootstrap is an initialization operation before author code; it does not yet
offer arbitrary safe reinstallation after author replacement of its globals.
The native compact browser's public listener/readiness integration follows as
a separate feature, rather than treating these accessors alone as full binding
parity.
