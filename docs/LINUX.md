# Vox on Linux

The Linux executable uses the translated V engine, JavaScriptCoreGTK, GLib event
sources, Fontconfig/HarfBuzz, Skia CPU services, and GG/Sokol's OpenGL window.
The desktop path is X11, including XWayland. Headless modes need no display.

## Build

On Ubuntu 24.04 or newer, install the following packages:

```sh
sudo apt-get update
sudo apt-get install build-essential clang ninja-build generate-ninja pkg-config \
    python3 curl ca-certificates libjavascriptcoregtk-4.1-dev libglib2.0-dev \
    libharfbuzz-dev libicu-dev libwoff-dev libbrotli-dev libcurl4-openssl-dev \
    libssl-dev libegl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dev libxi-dev \
    libxcursor-dev libxrandr-dev libx11-dev libasound2-dev libgc-dev \
    libfreetype-dev libfontconfig-dev libwebp-dev libpng-dev libjpeg-dev \
    fonts-liberation2 fonts-dejavu-core
```

You also need a current V checkout, a Rust compiler with edition 2024 support,
and Python 3.12 or newer. Set `V_BIN` if V is outside
`PATH` and `~/code/v/v`.

```sh
# Builds pinned Skia 144 under Build/deps; subsequent runs reuse it.
python3 tools/build_linux_skia.py
sh build-prod-browser.sh
Build/linux/vox https://example.com
```

The build selects Linux or macOS automatically. `build-linux-browser.sh` can
also be called directly. Both builds use the current V compiler without falling
back to the compatibility compiler. Linux uses the distribution's threaded Boehm
collector; `LADYBIRD_V_GC=none` remains available for ownership diagnostics. Native
bridges and image-codec archives stay under `Build/linux/native`, separate from macOS
objects. The browser embeds its adblock assets and needs no Ladybird checkout.
The default build optimizes with `-O2`; use `VOX_LINUX_CFLAGS=-O0` for a faster
diagnostic build. Allow at least 8 GB of RAM or additional swap for the large
single-file C compilation.
The Skia bootstrap verifies its archive checksum and uses system codec/font
libraries. A compatible system `skia.pc` can be supplied through `PKG_CONFIG_PATH`
instead. Skia's [build documentation](https://skia.org/docs/user/build/) describes
its GN/Ninja build and dependency options.

## Run and check

```sh
Build/linux/vox ./page.html
Build/linux/vox '<h1>Hello from Linux</h1>'
Build/linux/vox --headless-smoke
Build/linux/vox --headless=layout-tree ./page.html

sudo apt-get install xvfb xauth xdotool
python3 tools/test_linux_browser.py
```

Ctrl+L edits the address and Enter navigates. Back/forward, reload, page input,
and scrolling use the portable shell. JavaScriptCore remains the default engine.
The explicit `--js-engine=libjs` option keeps its existing documented limits.

The smoke test exercises startup, JavaScript DOM/events, local documents, HTTPS
with trusted and untrusted certificates, HTTP redirects, an actual X11 window
under Xvfb, and Ctrl+L/Enter navigation with
xdotool. It writes `Build/linux/smoke.png`.
`--screenshot=PATH` also captures Linux windows, including browser chrome, and
exits after settling. `--screenshot-viewport-height=N` sets the document layout
viewport independently of the window height. The Cocoa-based
`capture_screenshot.sh` remains macOS-specific.

For focused V tests after building native dependencies:

```sh
python3 tools/test_linux_native.py
python3 tools/test_linux_native.py --gc none
```

The port was checked on Ubuntu 24.04 ARM64: fourteen focused files passed with
Boehm, with the timer, deferred-delivery, font-discovery, JavaScriptCore and
OpenSSL compatibility files also checked without GC. The browser smoke covers
real X11 painting and keyboard navigation, in addition to HTTP/HTTPS, JavaScript,
DOM events and scrolling. Focused macOS JavaScript, native-window, address-bar,
canvas and shadow checks passed as well.

## Current platform boundary

Linux uses the existing portable painter, with retained shaped text and Skia
shadows. Advanced effects implemented solely in the Cocoa painter, including
some SVG paint servers, masks and filters, remain unported. Cocoa input-method
integration and the macOS video-frame decoder also remain platform-specific.
WebGL requires an ANGLE EGL/GLES installation; distribution Mesa alone reports
it unavailable. The native adapter preserves ANGLE's robust-buffer interface.
System OpenSSL 3.0 supports ordinary crypto operations; newer algorithms require
their provider versions (Argon2: 3.2+, ML-KEM/ML-DSA: 3.5+). Unsupported operations
return errors, including signature contexts an older provider cannot honor.
Linux rendering is not pixel-equivalent to the macOS screenshot suite, and
JavaScriptCoreGTK can differ in version from Apple's JavaScriptCore. Translated
code alone does not establish complete Ladybird or LibJS parity.
