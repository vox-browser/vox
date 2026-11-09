Vox-owned UI is declared in shared V/UI2 components under the
[UI implementation rule](../../AGENTS.md#ui-implementation). The
[migration audit](../../docs/UI2_MIGRATION_AUDIT.md) maps the former Cocoa and GG
owners to their replacements and explains the retained native boundaries.

`browserapp/browser_chrome.v`, `browserapp/browser_tabs_ui.v`, `bookmarkui/`,
`browserapp/browser_settings.v`, and `browserui/` supply controls, layout, styling,
actions, accessibility labels, popup state and shortcut decisions. Enter submits
the address. Typing opens the address suggestions of `browserui/address_suggestions.v`,
ranked from history and bookmarks: text typed at the start of a visited host is
completed inline, Up/Down show rows in the field, Escape returns from a moved
selection to the typed text, and Enter or a click opens the selected row. The
adapter's `select_embedded_text_range` selects the completion in AppKit's field
editor or the custom renderer's editor. Cmd+L focuses/selects the address.
Cmd+Shift+D toggles diagnostics;
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

The vector, icon, native/custom embedding and input APIs live in
[upstream UI2](https://github.com/vlang/ui2/blob/master/docs/embedding.md).
Vox records its reviewed revision, Git tree and embedding API generation in
[`dependency.json`](dependency.json). CI and local builds use that same lock.
From the Vox checkout, create a separate dependency checkout so an existing UI2
development branch and its local edits are preserved:

```sh
ui2_revision=$(python3 tools/prepare_ui2.py --print-revision)
git clone --no-checkout https://github.com/vlang/ui2.git ../vox-ui2
git -C ../vox-ui2 fetch --depth 1 origin "$ui2_revision"
git -C ../vox-ui2 checkout --detach "$ui2_revision"
export UI2_SOURCE_DIR="$(cd ../vox-ui2 && pwd)"
```

`tools/prepare_ui2.py` stages the locked Git contents without modifying UI2's
sources. Each content-identified snapshot contains real files, so later checkout
edits and other preparation calls cannot change an active build's UI2 inputs.
The script prints a V module search path containing the UI2 snapshot followed by
the separate compiler compatibility modules. Keep that path ahead of other
shared module caches. UI2 APIs are consumed directly, without private source
rewrites. Stable UI2 IDs are exposed as native view identifiers for
accessibility/testing tools.

Preparation rejects unsupported revisions, modified or untracked checkout
files, and unsupported embedding API generations. Ignored build artifacts are
excluded. Each snapshot under `Build/<platform>/ui2-snapshots/<digest>` has a
`manifest.json` recording the revision, tree, API generation and every file's
SHA-256 and Git mode. Reuse verifies those files; a damaged snapshot fails
instead of being rewritten under active consumers. Remove an obsolete or
damaged snapshot only after builds using it have finished.

To update UI2, review its embedding API and behavior, update `dependency.json`,
and run the preparation and UI tests below before committing the new lock.
The preparation script never checks out, resets or discards work in the selected
dependency checkout.

Check dependency staging and the Linux module-search contract without compiling
the browser:

```sh
python3 tools/prepare_ui2_test.py
python3 tools/build_linux_browser_test.py
```

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

Small component checks avoid compiling the document engine. Use the preparation
script's complete printed search path in `-path`:

```sh
ui2_modules=$(python3 tools/prepare_ui2.py)
v -enable-globals -memory-limit 10G -cc clang \
  -path "$ui2_modules|.|@vmodules|@vlib" test browserui
v -enable-globals -memory-limit 10G -cc clang -d vox_ui2 \
  -path "$ui2_modules|.|@vmodules|@vlib" browserui/mounted_darwin_test.v
v -enable-globals -memory-limit 10G -cc clang -d ui2_custom_rendering \
  -path "$ui2_modules|.|@vmodules|@vlib" browserui/custom_test.v
```

The mounted test drives real UI2 controls through AppKit. The custom test uses a
CPU command recorder, verifying read-only focus and mutation handling. Native
host-only checks are the [`browserwindow`](../../browserwindow) module tests
(`v test browserwindow/`); application policy is tested in V.
Linux window validation uses `tools/test_linux_browser.py` on Linux.
