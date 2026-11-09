# Vox on Linux

The Linux executable uses the translated V engine, JavaScriptCoreGTK, GLib event
sources, Fontconfig/HarfBuzz, Skia CPU services, and GG/Sokol's OpenGL window.
JavaScriptCore's C API is supplied by the `javascriptcoregtk-4.1` pkg-config
package on Linux.
The desktop path is X11, including XWayland. Headless modes need no display.

## Build

On Ubuntu 24.04 or newer, install the following packages:

```sh
sudo apt-get update
sudo apt-get install build-essential clang ninja-build generate-ninja pkg-config \
    python3 git curl ca-certificates libjavascriptcoregtk-4.1-dev libglib2.0-dev \
    libharfbuzz-dev libicu-dev libwoff-dev libbrotli-dev libcurl4-openssl-dev \
    libssl-dev libegl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dev libxi-dev \
    libxcursor-dev libxrandr-dev libx11-dev libasound2-dev libgc-dev \
    libfreetype-dev libfontconfig-dev libwebp-dev libpng-dev libjpeg-dev \
    fonts-liberation2 fonts-dejavu-core
```

You also need current [V](https://github.com/vlang/v) and
[UI2](https://github.com/vlang/ui2) checkouts and Python 3.12 or newer. For a fresh
setup, run these commands from the Vox checkout:

```sh
git clone --depth 1 https://github.com/vlang/v.git ../v
make -C ../v
git clone --depth 1 https://github.com/vlang/ui2.git ../ui2
export V_BIN="$(cd ../v && pwd)/v"
export UI2_SOURCE_DIR="$(cd ../ui2 && pwd)"
```

For existing checkouts, set `V_BIN` if V is outside `PATH` and `~/code/v/v`,
and set `UI2_SOURCE_DIR` if UI2 is outside `~/.vmodules/ui2` (or `$VMODULES/ui2`).
The build stages UI2 with Vox's embedding adapter without changing its checkout.
Regex is implemented in V and requires no Rust compiler. The optional JPEG XL
helper still requires Cargo and Rust 1.89 or newer, pending its V replacement;
when Cargo is available, the build compiles that helper from its lockfile.
On Linux, `V_BIN` accepts a command on `PATH` (for example, `V_BIN=v`), an
absolute executable path, or a path relative to the directory from which you
invoke the build script. The build resolves that path before changing directories.

Optional `libavif-dev` enables the static sRGB AVIF helper when its pkg-config
entry is available. The helper supports image elements, CSS backgrounds and
local files; animation, embedded ICC profiles and image transformations remain
unsupported. The initial decoder checks ran on macOS; Linux runtime conformance
for this path remains unverified.

```sh
# Builds pinned Skia 144 under Build/deps; subsequent runs reuse it.
python3 tools/build_linux_skia.py
sh build-prod-browser.sh
Build/linux/vox https://example.com
```

The build selects Linux or macOS automatically. `build-linux-browser.sh` can
also be called directly. Both builds use the current V compiler without falling
back to the compatibility compiler. The shell entrypoint prepares the native
archives, exports the local Skia package path, and stages the compiler modules
needed by the browser. Linux uses the distribution's threaded Boehm
collector; `LADYBIRD_V_GC=none` remains available for ownership diagnostics. Native
bridges and image-codec archives stay under `Build/linux/native`, separate from macOS
objects. The browser embeds its adblock assets and needs no Ladybird checkout.
Run the production entrypoint from a regular Git checkout on `master`, as
required by the shared build supervisor. It runs `--headless-smoke` before
publishing the executable and records compiler and smoke logs under
`Build/production-build/receipts/`.
The default build optimizes with `-O2`; use `VOX_LINUX_CFLAGS=-O0` for a faster
diagnostic build. Allow at least 8 GB of RAM or additional swap for the large
single-file C compilation.

Clang is the default C compiler. Set `CC=gcc` to build with GCC instead:

```sh
CC=gcc sh build-prod-browser.sh
```

The Skia bootstrap verifies its archive checksum and uses system codec/font
libraries. Rerun it after updating the checkout to refresh the generated
`skia.pc` link dependencies; unchanged compiled libraries are reused.
A compatible system `skia.pc` can be supplied through `PKG_CONFIG_PATH`
instead. Skia's [build documentation](https://skia.org/docs/user/build/) describes
its GN/Ninja build and dependency options.

## Run and check

The [Linux build workflow](../.github/workflows/linux-build.yml) installs the
system dependencies on Ubuntu 24.04, builds pinned V/UI2 and Skia sources, and
runs the normal supervised build and headless smoke test on pushes to `master`
and on pull requests. It also runs the Linux entrypoint regression tests, which
can be checked without a compiler or native development packages:

```sh
python3 tools/build_linux_browser_test.py
```

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

The production arena ownership checks use the same staged compiler runtime as
the production build, run without a collector, and poison released storage to
expose stale borrowed payloads:

```sh
VOX_ARENA_POISON=1 python3 tools/run_memory_bounded.py \
    --lock Build/linux-ownership-tests.lock --report Build/linux-ownership-tests.json -- \
    python3 tools/test_linux_native.py --gc prealloc \
    platform/closure_metadata_arena_test.v \
    platform/retained_arena_test.v platform/retained_arena_lifetime_test.v \
    dom/native_adoption_storage_test.v html/native_document_storage_test.v \
    layout/hosted_scene_storage_test.v layout/native_layout_retirement_test.v \
    layout/navigable_fallback_storage_test.v layout/svg_document_storage_test.v \
    layout/static_svg_scene_test.v
```

The native test runner also honors `CC`. To check the CSS color interpolation,
DOM range extraction, and WOFF2 font decoding regressions with GCC:

```sh
CC=gcc python3 tools/test_linux_native.py \
    css/color_interpolation_test.v dom/range_mutation_order_test.v gfxfont/woff_test.v
```

The runner enables V's strict C diagnostics and treats incompatible pointer
types, including callback signatures, as errors, so the compiler's normal
warning suppression cannot hide native output-parameter mismatches. Existing
const-discard diagnostics remain warnings. The JavaScriptCore and regex
boundary checks can be run separately:

```sh
python3 tools/test_linux_native.py \
    browserjs/linux_runtime_test.v browserjs/jsc_abi_test.v \
    libregex/compiled_regex_test.v libregex/ecmascript_regex_test.v
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
