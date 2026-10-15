The production macOS address bar embeds UI2's native single-line `text_input` in
the GG content view. UI2 owns text editing, selection and input methods; Vox owns
the window, renderer, navigation and toolbar shortcuts.

`build-prod-browser.sh` stages UI2 under `Build/v/modules` with this adapter, then
enables it with `-d vox_ui2`. It reads `UI2_SOURCE_DIR`, defaulting to
`~/.vmodules/ui2`. The dependency checkout is never modified. The stage uses the
current compiler checkout's `macos` bridge and makes three floating-point calls
explicit for the browser's compatibility frontend. Ordinary builds without that
define retain the portable GG address editor.

To exercise native field editing, Enter/Go navigation, Cmd+L, selection,
Unicode deletion, Escape, resizing and committed-URL synchronization:

```sh
sh tools/test_address_bar.sh
```

These tests send software AppKit editing commands to the actual mounted UI2
field. They do not require Accessibility or Screen Recording permission.

Validation on 2026-10-15: all six focused cases (35 assertions) passed, including
clipboard replacement, copy and cut, with the original clipboard restored after
the test. The native window capture shows the embedded field in its toolbar.
The final signed production build passed `--headless-smoke` and the focused
`inline-node` screenshot comparison within its existing tolerance (maximum
channel error 1).
This address-bar change contributes one completed browser UI fix to the next
ten-fix broad verification batch.
