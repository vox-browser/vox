# Remaining UI2 migrations

Source audit on 2026-11-01, following the bookmark migration in `67692b22`.
The [repository UI rule](../AGENTS.md#ui-implementation) requires Vox-owned UI
in V/UI2. The entries below are remaining work, not completed rewrites or runtime
validation results.

The inventory contains 17 tracked production `.m`/`.mm` files, excluding test
and measurement tools. Many `.m` files contain only an include; the actual
Objective-C widgets and behavior live in their corresponding headers. The audit
also inspected those headers, the V callers, the existing portable controls,
and the current UI2 declarations and embedding adapters.

## Closest matches to the former Cocoa bookmark bar

| Order | Surface and source | What still belongs in V/UI2 | Migration boundary |
| --- | --- | --- | --- |
| 1 | Tabs and window buttons: [native_browser_tabs_darwin.m](../native_browser_tabs_darwin.m), [native_browser_tabs_darwin.h](../native_browser_tabs_darwin.h) | `VoxBrowserTabStrip`, `VoxTabButton`, `VoxCloseTabButton`, and `VoxBrowserWindowButton` construct and paint controls. `trackTab:event:` owns drag thresholds, slot selection, reorder/detach decisions, and a nested event loop. | Declare tab/close/new/window buttons and their appearance in shared V/UI2. Move drag state and decisions into V, preserving process-tab behavior. Retain generic OS window close/minimize/zoom/drag operations behind the backend. Existing V tab ownership/actions in [main_browser_tabs.v](../main_browser_tabs.v) remain the owner; replace the presentation adapter in [main_browser_tabs_darwin.v](../main_browser_tabs_darwin.v). |
| 2 | Toolbar skin: [native_browser_chrome_style_darwin.m](../native_browser_chrome_style_darwin.m), [native_browser_chrome_style_darwin.h](../native_browser_chrome_style_darwin.h) | `VoxBrowserToolbarBackground.drawRect:` paints the toolbar, address outline, information icon, and divider with hard-coded geometry. `vox_chrome_navigation_image` paints navigation icons; the style functions overwrite UI2 control appearance with AppKit properties. | Extend [main_browser_chrome.v](../main_browser_chrome.v) with shared UI2 styles and icons. Keep `native_browser_chrome_prepare_window`/`restore_window` responsibilities that only configure the native host window. UI2 already creates the navigation and address controls; this is a presentation migration. |
| 3 | Link context menu: [native_link_context_menu_darwin.m](../native_link_context_menu_darwin.m), [native_link_context_menu_darwin.h](../native_link_context_menu_darwin.h) | `VoxLinkContextMenu` declares menu labels/actions, chooses the tab action, and performs the copy-URL action in Objective-C. [main_link_context_menu.v](../main_link_context_menu.v) only presents it on macOS. | Declare the menu and actions in shared V/UI2; use a generic clipboard backend for the OS operation. Preserve the captured destination across hover changes, dismissal, and navigation. |
| 4 | HTML select popup: [native_select_picker_darwin.m](../native_select_picker_darwin.m), [native_select_picker_darwin.h](../native_select_picker_darwin.h) | `VoxSelectPicker` parses the V row JSON and constructs an `NSMenu` with groups, separators, selection marks, disabled rows, indentation, and IDs. Presentation in [main_select_picker.v](../main_select_picker.v) is macOS-only. | Present the V select model through UI2. Extend the UI2 popup/list API where needed rather than flattening away row semantics. Keep DOM eligibility, document/node revalidation, and ordered `input`/`change` dispatch with the existing V owner. Website layout and painting stay in LibWeb. |

## UI that is already partly in V/UI2

| Surface and source | Remaining ownership to move | Native integration to retain |
| --- | --- | --- |
| Settings: [native_browser_settings_darwin.m](../native_browser_settings_darwin.m), [native_browser_settings_darwin.h](../native_browser_settings_darwin.h) | The controls and save/validation actions already use UI2 in [main_browser_settings_darwin.v](../main_browser_settings_darwin.v). Cocoa still inserts the Settings menu item, chooses control colors, sets enabled/editable state and tooltips, installs Apply/Cancel key behavior, and handles window editing shortcuts. Make the V component available across platforms; express those UI properties and actions through UI2. [main_browser_settings.v](../main_browser_settings.v) currently shows settings only with `vox_ui2`. | Generic window hosting, screen placement, first-responder/editor operations, and native key translation may need UI2 backend support. Do not replace the existing UI2 form with another widget implementation. |
| Browser shortcuts: [native_address_bar_darwin.m](../native_address_bar_darwin.m), [native_address_bar_darwin.h](../native_address_bar_darwin.h) | `native_address_bar_filter_key` hard-codes browser shortcut combinations, action numbers, repeat handling, and editing policy. Consolidate application shortcut decisions with the V owners, using UI2 key events. | Native event delivery, modifier/key normalization, and field-editor clipboard/undo operations can remain generic backend services. Preserve selection, IME behavior, and consumption before document dispatch. The address widget itself already belongs to UI2. |
| RAM/status readout: [native_browser_chrome_darwin.m](../native_browser_chrome_darwin.m), [native_browser_chrome_darwin.h](../native_browser_chrome_darwin.h); legacy [native_memory_status_darwin.m](../native_memory_status_darwin.m) | The active UI2 path updates a UI2-created label directly with native formatting. The compatibility path separately owns a `VoxStaticMemoryStatusLayer`, font, colors, width, placement, formatting, and CoreText painting. Share the presentation and formatting in V/UI2, using the V memory snapshot/label support in [main_memory_status.v](../main_memory_status.v) and [processmetrics](../processmetrics). | OS memory counters and timer delivery are backend services. Preserve the idle optimization: label refreshes must not repaint the document, wake the whole painter every frame, or lose worker-memory accounting. The two presentation paths are not both the default UI2 chrome. |

## Mixed state and platform adapters

These files need a narrower ownership split rather than a wholesale widget rewrite.

- [native_history_swipe_darwin.m](../native_history_swipe_darwin.m) includes
  [native_history_swipe_darwin.h](../native_history_swipe_darwin.h). Its gesture
  classifier, capture/momentum state, direction threshold, and completion
  decisions are application interaction policy to share in V. Native gesture
  phases, event monitors, and AppKit's swipe tracker remain platform operations.
- [native_browser_window_state_darwin.m](../native_browser_window_state_darwin.m)
  includes [native_browser_window_state_darwin.h](../native_browser_window_state_darwin.h).
  Saved-state validation, geometry clamping, transition state, and serialization
  policy are candidates for shared V ownership. The OS window/frame/fullscreen
  calls and notification plumbing remain backend integration.
- [native_browser_tab_detach_darwin.m](../native_browser_tab_detach_darwin.m) and
  [native_browser_tab_process_darwin.m](../native_browser_tab_process_darwin.m)
  mostly wrap process launch, pointer/screen coordinates, window visibility,
  activation, and native lifetime behavior. Their included headers contain no
  replacement tab widgets. Move application placement/lifetime decisions into
  the V tab owner as needed; retain the OS operations and preserve background
  process-tab lifetime.

## Other existing UI debt

The separate GG controls in
[main_browser_chrome_portable.v](../main_browser_chrome_portable.v),
[main_browser_tabs_portable.v](../main_browser_tabs_portable.v), and the macOS
compatibility branch of
[main_browser_bookmarks_portable.v](../main_browser_bookmarks_portable.v) are
also covered by the UI2 rule. Being written in V does not make these UI2.
Linux bookmarks already use the shared `bookmarkui` declaration and custom UI2
renderer; Linux navigation/tabs still use the separate GG path. Migrate them
with the corresponding native surfaces, without creating another layout.

## Native code outside this widget migration

[native_capture_darwin.m](../native_capture_darwin.m),
[native_graphite_darwin.mm](../native_graphite_darwin.mm),
[native_graphite_dawn_darwin.mm](../native_graphite_dawn_darwin.mm), and their
rendering helpers handle document graphics, capture, presentation, and OS host
integration. They are not interchangeable with browser widgets.
[native_navigation_work_darwin.m](../native_navigation_work_darwin.m) supplies a
native event-loop/presentation bridge, and
[browserjs/module_loader_darwin.m](../browserjs/module_loader_darwin.m) bridges
the JavaScript runtime. AVFoundation playback in
[native_media_darwin.h](../native_media_darwin.h) is an engine service.
Their language or use of an `NSView` alone does not make them UI2 rewrite targets.
Any application UI discovered inside those services still follows the UI rule.

Native test and measurement helpers may inspect AppKit controls or synthesize OS
input. Keep that test instrumentation distinct from production UI ownership.
