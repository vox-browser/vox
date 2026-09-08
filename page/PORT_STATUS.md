# Page module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Page`

Translation workspace: `~/code/libweb_v/page`
Audited: 2026-09-08

All seven upstream implementation units and their headers are represented. The
translation keeps browser-process and painting integration behind typed records:
`InputTarget` supplies hit-test facts, `ClientEvent` records PageClient requests,
and platform-native backing attachments are owned by
`SharedBackingStore`. These boundaries make the algorithms testable without
inventing a graphics stack or IPC runtime.

| Upstream implementation | V implementation |
| --- | --- |
| `Page.cpp`, `Page.h`, `ViewportIsFullscreen.h` | `page.v`, `geometry.v` |
| `SharedBackingStore.cpp`, `SharedBackingStore.h` | `shared_backing_store.v` |
| `DragAndDropEventHandler.cpp`, `DragAndDropEventHandler.h` | `drag_and_drop.v` |
| `ElementResizeAction.cpp`, `ElementResizeAction.h` | `element_resize_action.v` |
| `InputEvent.cpp`, `InputEvent.h` | `input_event.v` |
| `AutoScrollHandler.cpp`, `AutoScrollHandler.h` | `auto_scroll.v` |
| `EventHandler.cpp`, `EventHandler.h`, `EventResult.h` | `event_handler.v`, `drag_and_drop.v` |
| public/inline Page and interaction entry points | `page_entry_points.v`, `event_entry_points.v` |
| `PageClient` default browser/embedder boundary | `page_client.v` |

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Page/` | 7 | 4,298 | 2,289 | 475 | Complete |

The symbol-level audit accounts for all 306 implementations: 285 direct V
owner/name matches, 10 namespace template specializations, 5 GC/binding
runtime hooks, and 6 constructors/destructors supplied by V construction.
There are no unmatched Page symbols.

The port covers device/CSS geometry conversion; input-event cloning and pinch
validation; pointer/mouse/keyboard/default-action ordering, including canceled
pointer compatibility-event suppression and unconditional mouseup cleanup;
chrome-widget hover transitions and captured-before-current-target dispatch,
including independent input-capture and DOM-default swallowing flags;
mouse-selection state; drag data-store modes, effect negotiation, target
changes, drop/end and reset; auto-scroll edge expansion, capped speed and fractional accumulation;
writing-mode-aware element resizing; top-level/focused navigable identity;
navigation, history and window observations; blocking and non-blocking dialog
state; clipboard request correlation; media/canvas registries and toggles; user
style invalidation; multi-document find-in-page navigation with fragment-excluding
document URL resets; fullscreen FIFO,
UI handshakes, promise settlement and error checks; and move-only backing-store
transfer.

The DOM-facing Page bridge now exposes the configured device-pixel scale and
forwards backing-store allocation IDs to PageClient. This lets the
Navigable-to-Painting manager boundary preserve Retina sizing and allocation
notification without coupling DOM to the concrete Page model.

Native paint-tree traversal, DOM range mutation, PageClient IPC transport,
platform cursor selection, SDL polling, and actual scrolling are host
integration boundaries. Chrome widgets cross that boundary through callbacks,
but `update_hovered_chrome_widget()` and
`dispatch_chrome_widget_pointer_event()` now own the exact C++ leave/enter,
capture, release, dispatch-order, and event-swallowing decisions rather than a
logging-only stand-in.

## Verification

```text
$ /Users/alex/code/v/v_old -enable-globals test page
Summary for all V _test.v files: 5 passed, 5 total.
```
