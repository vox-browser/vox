# Native legacy Window.event

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.idl:64`, `HTML/Window.cpp:1617–1624`,
`DOM/EventDispatcher.cpp:79–115`, and the pinned generated-binding inputs
`Meta/Generators/libweb_bindings/{attributes,global_mixins,interfaces}.py`.
Feature commit: `4b5bc596`. The shared typed/native current-event record was
completed separately in `2adbc0d1` and is described in
[WINDOW_CURRENT_EVENT_IDENTITY.md](WINDOW_CURRENT_EVENT_IDENTITY.md).

The compact native browser now installs the Source legacy Replaceable
`Window.event` attribute on its actual engine global. The getter validates the
receiver, calls the actual owning `WindowModel.event()`, and returns the existing
native Event wrapper or JavaScript undefined. It reuses the native Event wrapper
cache, preserving the exact object supplied to an ordinary listener, readiness
listener, or parser-created raw body handler. Author replacement of `globalThis`
does not change registration or ownership.

The setter follows the pinned generator's Replaceable branch: validate the
Window receiver, then create a writable, enumerable, configurable data property
with the supplied JavaScript value. It performs no event-value conversion and
does not change the native Window current-event record. Failure to create that
property throws the actual TypeError. Getter/setter names, zero/one arities,
nonconstructibility, and the enumerable/configurable accessor descriptor match
the Source binding shape.

## Source property placement

`global_mixins.py:110–121` defines regular Window attributes and operations on
the actual global. `interfaces.py:488–506` returns early for the Global
WindowPrototype after its tag/base initialization, before defining regular
attributes. Therefore the pinned source does not put an `event` accessor on
WindowPrototype. This slice preserves that placement and does not introduce a
prototype fallback or mutate the engine global's prototype.

After replacement and deletion, the global has no `event` accessor. A previously
captured getter still reads the actual Window's current event. The tests use
documents without a conflicting named property; complete Window named-property
lookup, the WindowPrototype parent/constructor graph, and WindowProxy remain
separate work.

## Verification

Six cases in `browserjs/window_current_event_binding_test.v` cover:

- Source accessor metadata, receiver validation, nullish receiver default,
  undefined outside dispatch, Replaceable descriptors, deletion, and idempotent
  installation.
- Exact original Event identity across nested native dispatch, outer-event
  restoration, and reporting the original thrown JavaScript object.
- Replacement and deletion leaving the native current event intact, verified
  with a captured getter during and after dispatch.
- Real shadow-tree invocation preserving an outer event or absent current event
  according to the Source dispatcher rule.
- Genuine global registration after author replacement of `globalThis`.
- A Symbol replacement followed by a nonconfigurable property, where attempting
  another Replaceable assignment throws without converting the supplied value
  or replacing the original data property.

Two cases in `main_window_current_event_test.v` exercise native trusted
DOMContentLoaded/load and raw body handlers, including a real parser-created
body `onload` on a static document with no script sources. Each checks native
event identity while the callback runs and undefined after dispatch.

All focused cases passed with default GC and `-gc none` using
`v -old-compiler -enable-globals`. Final six-case browser binding logs are
`Build/audit-fixes/source-native-window-current-event-complete-default.log` and
`Build/audit-fixes/source-native-window-current-event-complete-gc-none.log`.
The native main cases passed in
`source-native-window-current-event-final-default.log` (2/2 files) and
`source-native-window-current-event-final-gc-none.log` (3/3 files, including the
seven Window event-handler accessor neighbors). Full `main_test.v` also passed
with GC none in `source-native-window-current-event-full-main-gc-none.log`.

The compact browser still uses JavaScriptCore and a captured JavaScript accessor
around the native host transport. This slice does not translate LibJS's complete
built-in-function records, full Window/WindowProxy graph, cross-realm wrappers,
or the parser's complete readiness task scheduling.
