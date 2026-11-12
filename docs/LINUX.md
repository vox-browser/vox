# Vox on Linux

The Linux executable uses the translated V engine, JavaScriptCoreGTK, GLib event
sources, Fontconfig/HarfBuzz, the V `cpuraster` rasterizer, and GG/Sokol's OpenGL
window. It does not depend on Skia.
JavaScriptCore's C API is supplied by the `javascriptcoregtk-4.1` pkg-config
package on Linux.
The desktop path is X11, including XWayland. Headless modes need no display.

## Build

On Ubuntu 24.04 or newer, install the following packages:

```sh
sudo apt-get update
sudo apt-get install build-essential clang ninja-build generate-ninja pkg-config \
    python3 git curl ca-certificates libjavascriptcoregtk-4.1-dev libglib2.0-dev \
    libharfbuzz-dev libicu-dev glslang-dev libwoff-dev libbrotli-dev libcurl4-openssl-dev \
    libssl-dev libegl1-mesa-dev libgl1-mesa-dev libxi-dev \
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
Use the latest UI2: run `v up ui2` for an installed module, or
`git -C "$UI2_SOURCE_DIR" pull --ff-only` for a separate checkout. The build links
that live checkout directly without copying or pinning it. CI fetches upstream
HEAD on every run and records the resolved V and UI2 commit IDs in its receipt
artifacts. See the [UI2 adapter guide](../tools/ui2/README.md) for focused checks.
Regex and JPEG XL decoding are implemented in V; the build requires no Rust
compiler or Cargo.
On Linux, `V_BIN` accepts a command on `PATH` (for example, `V_BIN=v`), an
absolute executable path, or a path relative to the directory from which you
invoke the build script. The build resolves that path before changing directories.

Optional `libavif-dev` enables the static sRGB AVIF helper when its pkg-config
entry is available. The helper supports image elements, CSS backgrounds and
local files; animation, embedded ICC profiles and image transformations remain
unsupported. The initial decoder checks ran on macOS; Linux runtime conformance
for this path remains unverified.

```sh
sh build-prod-browser.sh
Build/linux/vox https://example.com
```

The build selects Linux or macOS automatically. `build-linux-browser.sh` can
also be called directly. Both builds use the current V compiler without falling
back to the compatibility compiler. The shell entrypoint prepares the native
archives and stages the compiler modules
needed by the browser. Linux defaults to the distribution's threaded Boehm
collector. `LADYBIRD_V_GC=prealloc sh build-prod-browser.sh` builds the full browser
with the production arena allocator and no collector, using the same staged
bounded-realloc and closure runtime as macOS. `LADYBIRD_V_GC=none` remains
available for ownership diagnostics, but does not enable those arenas. Native
bridges and image-codec archives stay under `Build/linux/native`, separate from macOS
objects. The browser embeds its adblock assets and needs no Ladybird checkout.
Run the production entrypoint from a regular Git checkout on `master`, as
required by the shared build supervisor. It runs `--headless-smoke` before
publishing the executable and records compiler and smoke logs under
`Build/linux/production-build/receipts/`.
The default build optimizes with `-O2`; use `VOX_LINUX_CFLAGS=-O0` for a faster
diagnostic build. Allow at least 8 GB of RAM or additional swap for the large
single-file C compilation.

Clang is the default C compiler. Set `CC=gcc` to build with GCC instead:

```sh
CC=gcc sh build-prod-browser.sh
```

Canvas 2D drawing and portable shadows use the V `cpuraster` module. Its exact
Skia ports are compared against a pinned Linux Skia only by the external
differential suite (`tools/raster_tests.py`); `tools/build_linux_skia.py` builds
that oracle and is not needed to build or run the browser.

## Run and check

The [Linux build workflow](../.github/workflows/linux-build.yml) installs the
system dependencies on Ubuntu 24.04 and builds pinned V sources with
current upstream UI2 on pushes to `master` and on pull requests. Independent
Boehm and prealloc jobs each build the full browser through the normal
supervisor, run its headless smoke, and exercise its actual X11 window under Xvfb.
The prealloc job uses
`-prealloc -gc none` and `VOX_ARENA_POISON=1`, so arena retirement is checked
without a collector keeping stale payloads alive. The existing `build` check
requires both allocation jobs and the macOS native lifecycle job to pass; one
failing configuration does not cancel the others.

Focused suites run once native dependencies have built successfully, even when
the FastC production build, window smoke, or an earlier suite fails. The window
smoke still requires the newly built production binary, and any failure still
fails the aggregate gate. Parser script lifecycle and `document.write()` cases
run with both Boehm and prealloc. This keeps an application compiler error from
hiding parser, DOM, recording, and document-owner regressions. A separate fast
preflight compiles the actual tab metadata codec with FastC in both allocation
modes before the native dependencies and the full browser build; it does not substitute the C
backend for the production compiler.

The V revision is pinned to `339affce1891514d11aeb7111f579845d966a138`,
which supports the enum-attribute reflection and dynamic-array type matching
used by JSON2. The earlier pin failed first when compiling `TabColor`, then
rejected record arrays at runtime when the enum path was isolated. The preflight
round-trips the production typed metadata, including colors, record arrays,
older defaults and invalid input; the stored version-1 JSON schema is unchanged.

The workflow also runs the Linux entrypoint and smoke-harness regressions,
which can be checked without a V compiler or native development packages:

```sh
python3 tools/build_linux_browser_test.py
python3 tools/test_linux_browser_test.py
```

```sh
Build/linux/vox ./page.html
Build/linux/vox '<h1>Hello from Linux</h1>'
Build/linux/vox --headless-smoke
Build/linux/vox --headless=layout-tree ./page.html

sudo apt-get install xvfb xauth xdotool scrot
python3 tools/run_memory_bounded.py \
    --lock Build/linux-window-smoke.lock --report Build/linux-window-smoke.json \
    --limit-gib 3 --timeout 600 -- \
    python3 tools/test_linux_browser.py
```

Ctrl+L edits the address and Enter navigates. Back/forward, reload, page input,
and scrolling use the portable shell. JavaScriptCore remains the default engine.
The explicit `--js-engine=libjs` option keeps its existing documented limits.

The smoke test exercises startup, JavaScript DOM/events, local documents, HTTPS
with trusted and untrusted certificates, HTTP redirects, and an actual X11
window under Xvfb. It drives Ctrl+L/Enter navigation, resizes the window and
checks repainted pixels, creates and switches process tabs, closes a child tab,
and requires that child's recorded exit status to be zero. It then closes the
main window while a sibling is alive and verifies the main process exits normally
and the whole process group retires. The interactive
launch uses a private profile and ordinary window mode because screenshot mode
does not start process tabs. Missing Xvfb/input/capture tools fail the test.
It writes `Build/linux/browser-smoke/smoke.png` and the interactive logs and
captures alongside it. CI preserves these with the build receipts and
focused-test logs in separate allocator-specific artifacts, including on failure.
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

The normal gate also runs document replacement, BFCache suspension/restoration,
retained-frame release, child-document cleanup, tab-owner retirement, and pending
resource cancellation against both allocation models. These are the focused
application boundary checks:

```sh
VOX_ARENA_POISON=1 python3 tools/run_memory_bounded.py \
    --lock Build/linux-session-tests.lock --report Build/linux-session-tests.json -- \
    python3 tools/test_linux_native.py --gc prealloc \
    document/session_test.v document/child_storage_test.v \
    navigation/controller_test.v navigation/back_forward_cache_test.v \
    navigation/preload_cancellation_test.v browserapp/browser_tabs_test.v
```

The child-storage cases close a real hosted document, keep its commands readable
through the parent's retained frame, and require both arenas to release when the
last reader retires. Session cases cover blocked response producers and stale
completion rejection. The window smoke complements those ownership assertions
with actual process-tab and UI teardown. Linux prealloc coverage exercises the
shared ownership model and Linux backend.

The independent macOS job compiles the production Cocoa and IOSurface headers
through the existing native tests. It checks browser-view replacement and
redraw, retained frame buffers, asynchronous publication and retirement, and
preparation wake ownership. The suites exercise ARC and manual retain/release;
the publication suite also runs AddressSanitizer and UndefinedBehaviorSanitizer.
Each suite has a 3 GiB process-tree guard and a five-minute deadline, and all
failures remain required. The job preserves its logs and guard receipts even
when a suite fails.

This native-header gate does not build the full macOS browser, exercise its
process-tab lifecycle, or validate Metal pixel presentation. Those still require
a production macOS bundle and a suitable display/GPU host. The existing
`tools/test_native_browser_resize.py`, `tools/test_native_browser_keyboard.py`,
`tools/test_native_browser_tab_processes.py`, and
`tools/test_native_layer_surface.py` provide those separate checks; Linux or
Cocoa-header success must not be reported as their acceptance.

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

Linux uses the existing portable painter, with retained shaped text and V
(`cpuraster`) shadows. Advanced effects implemented solely in the Cocoa painter, including
some SVG paint servers, masks and filters, remain unported. Cocoa input-method
integration and the macOS video-frame decoder also remain platform-specific.
WebGL uses the system EGL/OpenGL 4.3 core driver, including Mesa, with an
offscreen context. No ANGLE installation or ANGLE-specific extensions are required.
Context creation requires EGL 1.5 or EGL 1.4 with `EGL_KHR_create_context`.
Context creation reports WebGL unavailable if the native driver cannot provide
the requested context.
System OpenSSL 3.0 supports ordinary crypto operations; newer algorithms require
their provider versions (Argon2: 3.2+, ML-KEM/ML-DSA: 3.5+). Unsupported operations
return errors, including signature contexts an older provider cannot honor.
Linux rendering is not pixel-equivalent to the macOS screenshot suite, and
JavaScriptCoreGTK can differ in version from Apple's JavaScriptCore. Translated
code alone does not establish complete Ladybird or LibJS parity.
