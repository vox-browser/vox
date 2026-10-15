# Test window placement

Screenshot launches (`--screenshot`, including `capture_screenshot.sh` and
`compare_screenshots.sh`) place Vox in the top-right corner of the display away
from the pointer when separate displays are connected. The display is selected
immediately before window startup. With one display, the window keeps its
top-right placement. Mirrored displays count as one workspace.

For other windowed tests and visual checks, launch with `VOX_TEST_WINDOW=1`:

```sh
VOX_TEST_WINDOW=1 Build/v/Vox.app/Contents/MacOS/Vox ./page.html
```

Test startup preserves the foreground application. The requested document
viewport is unchanged, and screenshots still capture the native content view.
Interactive launches use their ordinary window behavior.

Run the focused native placement and background-capture check with:

```sh
sh tools/test_window_placement.sh
```
