# Brave rendering fixtures

References were captured from Brave 155.1.97.57 on macOS at device scale 1.
`font-rasterization` covers Arial and Verdana at integer and fractional sizes,
automatic and antialiased smoothing, three foreground colors, and white and
colored backgrounds. Its explicit base URL selects the native compatibility
profile used for old Reddit.

```sh
./capture_screenshot.sh Tests/Browser/Brave/input/font-rasterization.html Build/font-rasterization.png 1024 768
python3 tools/check_pixel_equality.py Tests/Browser/Brave/expected/font-rasterization.png Build/font-rasterization.png Build/font-rasterization.diff.png
```

This comparison requires exact RGBA equality, with no excluded pixels or tolerance.
