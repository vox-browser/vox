# UI2 migration audit

The 2026-11-01 audit began after the bookmark migration in `67692b22`.
Every application UI owner identified by that audit has now moved to shared
V/UI2. The original inventory is preserved in Git at `619cdd9f`.
The [repository UI rule](../AGENTS.md#ui-implementation) applies to future work.

| Audited surface | Shared owner now | Removed implementation |
| --- | --- | --- |
| Tabs, close/new buttons, window buttons, drag/reorder/detach preview | [browserui/tabs.v](../browserui/tabs.v), [browserapp/browser_tabs_ui.v](../browserapp/browser_tabs_ui.v), existing V tab controller | `native_browser_tabs_darwin.{m,h}`, separate GG tab painter |
| Toolbar skin, navigation controls, address field, status labels | [browserapp/browser_chrome.v](../browserapp/browser_chrome.v) | Cocoa toolbar background/icon painting and native styling overrides, separate GG toolbar |
| Link context menu | [browserapp/link_context_menu.v](../browserapp/link_context_menu.v), [browserui/popup.v](../browserui/popup.v) | `native_link_context_menu_darwin.{m,h}` |
| HTML select popup | [browserapp/select_picker.v](../browserapp/select_picker.v), shared UI2 popup | `native_select_picker_darwin.{m,h}` and its JSON-to-NSMenu layer |
| Settings, validation, enabled states, Apply/Cancel | [browserapp/browser_settings.v](../browserapp/browser_settings.v) | `native_browser_settings_darwin.{m,h}` and platform-only V form owner |
| Browser shortcut policy | [browserui/shortcuts.v](../browserui/shortcuts.v), [browserapp/browser_ui.v](../browserapp/browser_ui.v) | `native_address_bar_darwin.{m,h}` shortcut table |
| RAM formatting, sampling schedule, worker accounting and label updates | [memorymgmt/memory_status.v](../memorymgmt/memory_status.v), [processmetrics](../processmetrics) | `native_browser_chrome_darwin.{m,h}`, `native_memory_status_darwin.m` and its separate painted layer |
| History gesture classification, capture generations, cancellation and commit thresholds | [browserui/swipe.v](../browserui/swipe.v), [browserapp/history_swipe.v](../browserapp/history_swipe.v) | Native gesture policy fields and decisions |
| Saved-window schema, validation, display clamping and fullscreen transitions | [browserui/window.v](../browserui/window.v), [browserapp/browser_window_state.v](../browserapp/browser_window_state.v) | Native saved-state/geometry policy |
| Detached-window placement | [browserui/window.v](../browserui/window.v), [browserapp/browser_tab_detach_darwin.v](../browserapp/browser_tab_detach_darwin.v) | Native application placement calculations |
| Compatibility chrome/bookmarks | Shared UI2 tree with [custom embedding](https://github.com/vlang/ui2/blob/master/ui/embedded_elements_custom.c.v) | Handwritten GG controls and hit testing |

Popups are asynchronous UI2 lists. They retain groups, disabled options,
separators, indentation, selection marks, keyboard navigation and scrolling.
Each presentation has a distinct action token; stale actions cannot choose a
later popup. Select completion revalidates document identity, connection and
mutability. Navigation, tab switching, cancellation and outside clicks dismiss
popups. Link actions retain the clicked destination instead of consulting hover.

UI2's native backend supplies controls, accessibility and field-editor services.
The custom renderer draws the same declarations inside the existing GG pass.
Settings use a generic UI2 panel host on macOS and a scrollable UI2 overlay with
the custom backend. These APIs live in
[upstream UI2](https://github.com/vlang/ui2/blob/master/docs/embedding.md).
[prepare_ui2.py](../tools/prepare_ui2.py) selects the installed upstream checkout.

## Retained native boundaries

Four production `.m`/`.mm` wrappers remain. Their included headers were inspected
as well as their wrappers. They provide these engine operations:

- `native_capture_darwin.m`, `native_graphite_darwin.mm` and
  `native_graphite_dawn_darwin.mm`: document graphics, capture and presentation.
- `browserjs/module_loader_darwin.m`: JavaScript runtime bridge.

The host-window operations are V, in the [`browserwindow`](../browserwindow)
module, using the `macos` module's Objective-C runtime senders:

- `chrome_style_darwin.v`: configure and restore the title-bar-less UI2 host.
- `history_swipe_darwin.v`: normalize OS phases/modifiers/coordinates and invoke
  AppKit's asynchronous gesture tracker, forwarding policy to V.
- `window_state_darwin.v`: window snapshots, screen enumeration, notifications,
  frame/fullscreen operations and legacy plist conversion.
- `detach_darwin.v`: process launch, pointer/window coordinates and setting the
  window frame selected by V.
- `tab_window_darwin.v`: native visibility/activation and AppKit lifetime
  integration for hidden process-tab windows. Session membership, selection,
  close and replacement decisions remain in the V tab owner.
- `event_pump_darwin.v`: native event delivery during long document work; the
  presentation redraw state it reports stays in `native/include/native_layer_presentation_darwin.h`.

AVFoundation playback and other native rendering/media helpers remain engine
services. Their use of an NSView does not make them application widgets. Native
test/measurement helpers may inspect UI2 controls or synthesize OS input.

## Verification

Focused checks cover shared declarations, pointer/keyboard delivery through the
mounted macOS UI2 backend, custom-renderer read-only editing, tab ownership and
dragging, address editing, settings validation/cancellation, select DOM events,
link actions, memory lifecycle, window schema/geometry and gesture policy.
See [the adapter guide](../tools/ui2/README.md) for commands. Receipts for this
migration are under `Build/ui2-all-20261101/`, including failed attempts.
The completed production bundle also passed the process-tab probe: independent
PIDs, navigation/selection, retained documents, foreground/background crashes,
parent-process exit, last-tab replacement and window close. Its executable and
library identities are recorded in
`Build/ui2-all-20261101/process-tabs2/results.json`. That bundle predates the final
control-registry fix; the focused mounted and engine tests validate the fix.
Final production-bundle validation remains pending while the shared production
build guard is occupied.

Linux runtime behavior still requires the Linux window smoke check on a Linux
host; custom-backend tests on macOS do not establish X11 runtime parity.
