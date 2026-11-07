# Vox app icon

`Vox.png` is the 1024×1024 source artwork: a curled blue animal wrapped around
a globe on a dark purple rounded-square tile with transparent exterior corners.
It was supplied as a 1254×1254 PNG, recentred on its tile and resampled to
1024×1024 with ImageMagick:

```sh
magick source.png -background none -gravity NorthWest \
    -extent 1254x1254-14+7 +repage -filter Lanczos -resize 1024x1024 \
    -strip packaging/Vox.png
```

`Vox.icns` contains the standard macOS icon representations from 16×16 through
1024×1024.

After replacing the source artwork, regenerate the icon on macOS:

```sh
./tools/build_app_icon.sh
```

`./build-prod-browser.sh` copies `Vox.icns` into
`Build/v/Vox.app/Contents/Resources/` before signing the app. The bundle's
`CFBundleIconFile` references that resource.
