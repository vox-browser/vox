Vox-owned UI is declared in shared V/UI2 components under the
[UI implementation rule](../../AGENTS.md#ui-implementation). The
[migration audit](../../docs/UI2_MIGRATION_AUDIT.md) maps the former Cocoa and GG
owners to their replacements and explains the retained native boundaries.

`browserapp/browser_chrome.v`, `browserapp/browser_tabs_ui.v`, `bookmarkui/`,
`browserapp/browser_settings.v`, and `browserui/` supply controls, layout, styling,
actions, accessibility labels, popup state and shortcut decisions. Enter submits
the address. Cmd+L focuses/selects it. Cmd+Shift+D toggles diagnostics;
Cmd+Shift+B toggles bookmarks; Cmd+D saves the committed page. Windows/Linux use
Ctrl for those commands. Cmd+Option+I or F12 (Ctrl+Shift+I) toggles the docked
[developer tools](../../devtools/README.md), Cmd+Shift+C (Ctrl+Shift+C) picks
an element in the page and Cmd+Option+J (Ctrl+Shift+J) opens the console. Browser settings use Cmd+, on macOS and Ctrl+, elsewhere.
Native field editing, selection, clipboard and IME stay with UI2's backend.

Tabs retain the classic sloped shoulders, overlapping edges, thin outline and
active-tab seam into the toolbar. Their contour and stacking are declared in
`browserui/tabs.v`, including the small slanted new-tab button. UI2's embedding
adapter supplies a generic `VectorPath` decoration for native and custom
renderers; it contains no tab-specific drawing code. Packed UI2 colors use sRGB
on both backends.

The combined tab strip and toolbar is 60px normally and 92px with diagnostics.
The bookmarks bar adds 28px. The document viewport follows that height. UI2
reconciles keyed controls, preserving editing state across resize/status updates.
A V timer samples browser-plus-worker memory once a second and updates only the
UI2 RAM label; it stops on unmount. It does not invalidate the document painter.

`build-prod-browser.sh` stages UI2 under `Build/v/modules` using
`tools/prepare_ui2.py`, enabling `-d vox_ui2` on macOS. `UI2_SOURCE_DIR` defaults
to `~/.vmodules/ui2`; the dependency checkout is never modified. The adapter adds
mount/reconciliation cleanup, generic normalized keyboard/wheel delivery,
clipboard and host-window actions, and auxiliary panel hosting. Browser shortcut
and form policy stay outside the backend. Stable UI2 IDs are exposed as native
view identifiers for accessibility/testing tools.

Linux uses the same element tree through UI2's custom renderer in the existing
GG pass. `embedded_elements_custom.c.v` handles event delivery and text editing;
`embedded_host_linux` forwards generic window operations to X11. There is no
separate browser-owned GG control implementation. The custom renderer does not
establish Linux graphics or window parity when tested on macOS.

Run expensive compilation through `tools/run_memory_bounded.py` with unique lock
and report paths, then execute focused binaries with `--limit-gib 3`. Supply
`-memory-limit 10G` to V. For example:

```sh
python3 tools/run_memory_bounded.py --lock Build/ui2-address-build.lock \
  --report Build/ui2-address-build.json -- \
  sh tools/test_address_bar.sh -memory-limit 10G -skip-running -o Build/ui2-address-test
python3 tools/run_memory_bounded.py --limit-gib 3 --lock Build/ui2-address-run.lock \
  --report Build/ui2-address-run.json -- env VOX_TEST_WINDOW=1 Build/ui2-address-test
```

The same runner accepts `VOX_CHROME_TEST_FILE` for
`browserapp/browser_tabs_test.v`, `browserapp/browser_tab_favicon_test.v`,
`browserapp/browser_tabs_portable_test.v`, `browserapp/browser_bookmarks_test.v`,
`browserapp/browser_settings_test.v`, `browserapp/link_context_menu_test.v`,
`browserapp/select_picker_test.v`, `memorymgmt/memory_status_test.v`,
`browserapp/browser_window_state_test.v`, and `browserapp/history_swipe_test.v`.
Sources are linked from the canonical checkout, including for the settings test.

Small component checks avoid compiling the document engine. Stage UI2 first with
`python3 tools/prepare_ui2.py`; use its printed directory in `-path`:

```sh
v -enable-globals -memory-limit 10G -cc clang \
  -path 'Build/v/modules|.|@vmodules|@vlib' test browserui
v -enable-globals -memory-limit 10G -cc clang -d vox_ui2 \
  -path 'Build/v/modules|.|@vmodules|@vlib' browserui/mounted_darwin_test.v
v -enable-globals -memory-limit 10G -cc clang -d ui2_custom_rendering \
  -path 'Build/v/modules|.|@vmodules|@vlib' browserui/custom_test.v
```

The mounted test drives real UI2 controls through AppKit. The custom test uses a
CPU command recorder, verifying read-only focus and mutation handling. Native
host-only checks are the [`browserwindow`](../../browserwindow) module tests
(`v test browserwindow/`); application policy is tested in V.
Linux window validation uses `tools/test_linux_browser.py` on Linux.
