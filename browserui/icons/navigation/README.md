# Navigation icons

Back, forward and reload share round, two-unit strokes on a 24-unit canvas.
The matching SVGs and transparent 48-pixel PNGs are generated from the geometry
in `tools/generate_navigation_icons.v`:

```sh
v run tools/generate_navigation_icons.v
```

The PNGs include separate disabled colors and subpixel edge coverage. Vox embeds
them in the executable, publishes them to a content-addressed cache, and displays
them as 18-point UI2 images inside the existing 22-point buttons. Custom renderers
preload all six images before painting and retain their texture IDs across frames.
The native Win32 backend retains its existing glyphs while its image loader is
limited to BMP.

Focused tests are in `browserui/navigation_icons_test.v`; `-d vox_ui2` also checks
actual AppKit image rendering, action delivery, disabled controls and state changes.
Set `VOX_NAV_ICON_CAPTURE` to capture the enabled/disabled component preview.
