# Input picker activation and origin ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLInputElement.cpp:421–437,494–524`,
`HTML/Window.cpp:842–864`, and
`HTML/Scripting/WindowEnvironmentSettingsObject.cpp`.
Feature commit: `d97ccccc`.

The input model retained independently supplied activation and same-origin
booleans. Actual trusted input changed the native Window, while the picker
checked that separate control snapshot and consumed only its own boolean.
Adoption or other permission-consuming controls could therefore disagree with
the picker's stored permission.

Both fields and their synthetic setter are removed. `show_picker()` checks
source mutability first, then compares the element's actual relevant settings
origin with its settings top-level origin. File and color inputs retain their
source historical cross-origin exemption. The activation gate reads the actual
Window global owned by those settings. Showing an applicable picker consumes
that native Window's source logical navigable tree before checking picker
support, so even a successful unsupported-type call consumes activation.
The existing actual owning-Page request path and legacy embedding hook remain.

Four cases in `html/input_picker_owner_test.v` use navigation-created Documents,
actual parser-created controls, genuine Windows/settings, and actual Page
clients to verify trusted mousedown activation, shared consumption across
controls, source error order and origin exemptions, unsupported-type
consumption, adoption to another global/Page, and logical top/child Window
consumption across independently cached BrowsingContexts. Existing input and
CSS picker-state fixtures now create genuine Window settings and update their
actual native activation timestamp instead of supplying per-model flags.

Default GC passed all four focused cases in
`Build/audit-fixes/source-input-picker-owner-complete-default.log`.
The GC-none batch passed 3/3 files, including those cases, the full existing
HTMLInputElement file, and form-state selector tests:
`source-input-picker-owner-complete-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, adding `-gc none` for
that batch. The actual Page still permits one non-blocking dialog at a time;
the multi-control fixtures close its file dialog before requesting color.

The shared picker owner helper reads genuine translated global/settings
records. A bare DOM-only fixture without a relevant global is not promoted to
a fabricated Window. Complete JavaScript `showPicker` generated binding
exposure, platform dialog completion, and WebDriver BiDi file-dialog handling
remain separate native/embedding boundaries. The separate
[select picker owner slice](SELECT_PICKER_GLOBAL_OWNERSHIP.md) removes its
corresponding permission snapshot.
