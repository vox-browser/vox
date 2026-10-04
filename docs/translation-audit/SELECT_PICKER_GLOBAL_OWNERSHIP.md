# Select picker activation and origin ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLSelectElement.cpp:520–543,596–630`, and
`HTML/Window.cpp:842–864`, and
`HTML/Scripting/Environments.cpp:445–447,493–507`.
Feature commit: `f889d57e`.

The select model kept supplied activation and same-origin flags, then consumed
only its private activation boolean. It could miss actual trusted Window
activation, retain permission after another control consumed it, or use a stale
control snapshot after adoption.

The flags and synthetic setter are removed. The public picker method preserves
source mutability, actual relevant-settings origin/top-level-origin comparison,
and actual relevant Window transient activation in source error order. The
private picker path consumes that native Window's source logical navigable tree
before option collection and the existing embedding UI hook. Source activation
behavior continues to invoke the picker path only for trusted events.
The pinned `relevant_settings_object(DOM::Node const&)` overload reads the
node's current Document settings; both relevant-Realm/global Node overloads
flow through it. This is the select call path, rather than the `JS::Object`
overload's creation-Realm owner. The [input overload review](INPUT_PICKER_GLOBAL_OWNERSHIP.md)
records the distinction and its adoption/notification regressions.

Four cases in `html/select_picker_owner_test.v` verify actual trusted mousedown
activation and consumption before the existing UI hook; current origin and
error ordering; adoption to another actual global (including switching from the original
settings' SecurityError gate to the current settings' activation gate);
trusted versus untrusted
activation behavior; shared input/select permission; and actual logical
top/child consumption across independently cached BrowsingContexts. The tests
use navigation-created Documents/Pages/Windows/settings and parser-created
controls. Existing options/picker and CSS state fixtures now use genuine Window
settings and native activation instead of supplied control flags.

All four focused cases passed default GC in
`Build/audit-fixes/source-select-picker-owner-default.log`.
The GC-none batch passed 4/4 files: these cases, existing select/options, form
state selectors, and actual input-owner regressions:
`source-select-picker-owner-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, adding `-gc none` for
the corresponding batch.

The pinned source marks the non-rendered `showPicker()` rejection as FIXME. The
disconnected/unpainted regression intentionally preserves that source behavior
instead of adding a new NotSupportedError gate. The PageClient dropdown
request, actual bounding rectangle/page position/minimum width, complete
JavaScript generated binding, and native UI completion remain separate
downstream boundaries. The existing select UI hook is retained for this owner
slice; these tests do not certify full dropdown geometry or PageClient parity.

The strengthened adoption and notification checks passed 3/3 files with both
default GC and GC-none in `source-adopted-picker-node-overload-default.log`
and `source-adopted-picker-node-overload-gc-none.log`. The select adoption case
uses a real trusted mousedown on the adopted element to activate the current
Document Window before its trusted picker activation path.
