The production macOS chrome mounts its navigation buttons, single-line address
editor, and diagnostic, link/console and RAM labels with UI2. AppKit drawing
supplies the classic gray tab strip, flat arrow/reload icons, thin address border,
and compact red/yellow/green window buttons. The window uses a full-size content
view with its native title hidden, so window buttons and tabs share one row.
The custom window buttons invoke the window's close, minimize and zoom actions;
the empty tab-strip background supports dragging and double-click zoom.

Enter submits the address; there is no Go button. The diagnostic row (HTTP
status, response bytes, paint count and document dimensions) is hidden by
default. Cmd+D on macOS or Ctrl+D on Windows/Linux toggles it, including during
address editing. The combined tab strip and toolbar is 60px high normally and 92px with diagnostics;
the document viewport and pointer coordinates follow that height. Cached
full-window images are keyed by visibility and discarded on a toggle, so a
debug image cannot reintroduce diagnostics into normal browsing.

UI2 mounts two keyed view subtrees in the existing GG content view. No overlay
covers the document. Vox owns the window, document renderer, navigation and
toolbar shortcuts and chrome drawing; UI2 owns text editing, selection and input
methods. Reconciliation retains the address field and its selection on resize
and status updates. A native timer updates the UI2 RAM label without waking the
document painter or allocating in the V heap, and stops on unmount/window close.

`build-prod-browser.sh` stages UI2 under `Build/v/modules` with this adapter, then
enables it with `-d vox_ui2`. It reads `UI2_SOURCE_DIR`, defaulting to
`~/.vmodules/ui2`. The dependency checkout is never modified. The stage uses the
current compiler checkout's `macos` bridge, makes three floating-point calls
explicit for the browser's compatibility frontend, and keeps native label text
access on the actual `NSTextField` when AppKit adds private drawing subviews.
Linux and ordinary builds without that define retain the portable GG chrome;
the embedding adapter currently uses AppKit.

To exercise native navigation-button actions and enabled states, field editing,
Enter navigation, Cmd+L, clipboard operations, Unicode deletion, Escape,
resizing, diagnostic shortcuts, viewport sizing, status refresh, committed-URL
synchronization and cleanup:

```sh
sh tools/test_address_bar.sh
```

Tab ownership, native tab actions, keyboard routing and modified link clicks:

```sh
sh tools/test_browser_tabs.sh
sh tools/test_browser_tabs.sh -gc none
```

The integrated title row, real window-button selectors, top-row hit testing,
content-size preservation and restoration also have a standalone AppKit check:

```sh
clang -fobjc-arc -framework Cocoa tools/native_browser_chrome_test.m -o /tmp/vox-browser-chrome-test
/tmp/vox-browser-chrome-test
```

These tests exercise the actual mounted controls through AppKit commands.
They also check that the document remains available for hit testing and that
unmount removes both controls and RAM sampling. They do not require Accessibility
or Screen Recording permission, and restore the clipboard after testing.

Earlier compact-toolbar validation, before the integrated title row (2026-10-18): all thirteen focused cases and all five portable address
cases pass. The signed production build passes `--headless-smoke`, and the
`inline-node` document screenshot comparison passes with maximum channel error 1
(13 differing pixels). A full content-view capture confirms the compact toolbar
without Go or diagnostics. The shortcut case checks diagnostic visibility from
both address and page focus while preserving edits and selection. All 57 focused
capture/measurement tool tests pass, and a 320×1300 document capture stitches two
strips into one uniform image without including browser chrome.
