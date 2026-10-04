# Window current-event identity

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.h:149–151,335`, `HTML/Window.cpp:1617–1624`,
and `DOM/EventDispatcher.cpp:79–115`. Feature commit: `2adbc0d1`.

The `html.WindowModel` previously held a second `current_event_` field alongside
its embedded `dom.Window`. Its typed setters and getters used that second field,
while the actual DOM dispatcher updated the embedded native Window. Consequently
`WindowModel.event()` could not see an event during an actual listener callback.

The duplicate field is removed. `WindowModel.set_current_event()` and
`current_event()` now delegate to the embedded Window's existing methods, so
`WindowModel.event()` reads the same record that dispatch saves, updates, and
restores. The source dispatcher remains unchanged: it sets the listener's
associated Window current event, preserves a previous outer event for nested
dispatch, reports listener exceptions, restores the previous event afterward,
and does not replace the current event for an invocation target in a shadow tree.

`html/window_current_event_identity_test.v` has three focused regressions:

- Typed and native setters/getters share one actual Window slot in both
  directions and clear it together.
- Nested native listeners observe the original inner and outer event identities,
  preserve the source callback order, report an inner listener exception, and
  restore the outer event before finally clearing the slot.
- A real shadow-tree target sees no current event when no outer event exists and
  preserves an outer event during nested shadow dispatch.

All three cases passed with default GC and `-gc none` using
`v -old-compiler -enable-globals`. Final logs are
`Build/audit-fixes/source-window-current-event-final-default.log` and
`Build/audit-fixes/source-window-current-event-final-gc-none.log`.
The existing `dom/event_handler_invocation_test.v` and `dom/ui_events_test.v`
also passed with `-gc none` in the initial neighboring batch; that batch's first
version of the new test had fixture compilation errors, which were corrected
before both final focused runs.

This feature unifies the actual typed/native state. Native JavaScript exposure
of the legacy Replaceable `Window.event` attribute is a separate binding slice.
