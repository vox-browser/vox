# Trusted EventTarget activation clock

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/DOM/EventTarget.cpp:997–1070`,
`HTML/Window.cpp:518–521`, and `HighResolutionTime/TimeOrigin.cpp:72–96`.
Feature commit: `10810224`.

Native EventTarget dispatch previously assigned the absolute monotonic event
construction clock to the Window's activation timestamp. Source activation
checks use a timestamp relative to the actual associated Document's time
origin, so trusted input could dispatch successfully while leaving the real
Window without transient activation.

The notification path now computes its timestamp through the existing native
high-resolution-time helper for the actual relevant Window. That helper uses
its current associated Document's navigation-start origin and the source
coarsening algorithm. Notification and CloseWatcher updates still run before
listeners. The source trusted-event/type filters and the Window virtual
dispatch bypass remain the existing translations.

Three cases in `html/window_activation_notification_test.v` verify:

- A real connected button, actual trusted mousedown, and a canceled listener
  that observes native/typed/UserActivation state and CloseWatcher notification
  before callback execution. The timestamp falls inside the real relative-clock
  interval and ignores a deliberately unrelated Event timestamp; settings and
  navigation snapshots see the resulting activation.
- Binding dispatch becoming untrusted, direct Window dispatch bypassing base
  activation, Escape, mouse pointerup, and touch pointerdown preserving the
  never-activated source sentinel; an actual non-Escape keydown activates the
  same native Window record.
- Native trusted touch pointerup and mouse pointerdown using the real Window's
  reassociated Document time origin, including a distinct 60-second origin.

All three cases passed default GC in
`Build/audit-fixes/source-window-activation-notification-default.log`.
The GC-none batch passed 5/5 files: these cases, activation-owner identity,
CloseWatcher, native UI events, and the Window virtual-dispatch override.
Its log is `source-window-activation-notification-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, adding `-gc none` for
that batch.

The pinned EventTarget source still marks full ancestor/descendant activation
notification as FIXME and performs its local relevant-Window notification;
this translation preserves that algorithm. General Event construction still
has a separate relevant-global timestamp boundary. The separate
[logical navigable consumption slice](WINDOW_ACTIVATION_CONSUMPTION.md) translates
that traversal. Picker-model activation ownership remains a distinct boundary,
as described in [Window activation identity](WINDOW_ACTIVATION_IDENTITY.md).
