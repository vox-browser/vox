# Vox on macOS

The normal production build uses the native V tool in
[`tools/voxbuild`](../tools/voxbuild), bootstrapped by
[`tools/vox-build.sh`](../tools/vox-build.sh). It stages compiler modules, compiles
Vox and its native bridges, enforces the memory budgets, runs the headless smoke
test, and publishes `Build/v/Vox.app` without invoking Python.

Prepare the upstream graphics dependencies separately. Skia and Dawn's own
generators still require Python during that explicit setup; the normal Vox build
consumes their prepared libraries and generated headers. It does not run their
GN or CMake generators or silently rebuild a missing graphics cache.

## Requirements

Use an Apple Silicon or Intel Mac with Xcode's command-line tools and a macOS SDK
that supports the minimum version declared in
[`packaging/Info.plist`](../packaging/Info.plist). The build also uses Git, curl,
tar, and CMake. CMake builds the pinned libdeflate snapshot helper without Python.
The optional JPEG XL helper requires Cargo and Rust 1.89 or newer.

You need a current [V](https://github.com/vlang/v) compiler and the current
[UI2](https://github.com/vlang/ui2) checkout. From the Vox checkout, a fresh setup
can use:

```sh
git clone --depth 1 https://github.com/vlang/v.git ../v
make -C ../v VFLAGS='-memory-limit 10G'
git clone --depth 1 https://github.com/vlang/ui2.git ../ui2
export V_BIN="$(cd ../v && pwd)/v"
export UI2_SOURCE_DIR="$(cd ../ui2 && pwd)"
```

For existing installations, the build uses `V_BIN` when set, then `v` on `PATH`,
then `~/code/v/v`. UI2 defaults to `$VMODULES/ui2` or `~/.vmodules/ui2`; set
`UI2_SOURCE_DIR` to use another live checkout. The production build requires a
regular Git checkout on `master` and never falls back to V's 0.5.2 compatibility
compiler.

## Prepare graphics dependencies explicitly

First prepare the Ladybird/vcpkg SDK used by this checkout. Its default location
is `../3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic` on Apple
Silicon or the corresponding `x64-osx-dynamic` directory on Intel. Set
`LADYBIRD_SOURCE_DIR` and `LADYBIRD_VCPKG_TRIPLET` to select another installation.
The SDK supplies the shared Skia text/service library and headers; the isolated
Graphite libraries described below use their own pinned Skia sources.

The following commands select the same SDK directory as the production script:

```sh
vox_triplet=${LADYBIRD_VCPKG_TRIPLET:-}
if [ -z "$vox_triplet" ]; then
    case "$(uname -m)" in
        arm64|aarch64) vox_triplet=arm64-osx-dynamic ;;
        x86_64|amd64) vox_triplet=x64-osx-dynamic ;;
        *) echo 'Unsupported macOS architecture' >&2; exit 1 ;;
    esac
fi
vox_upstream=${LADYBIRD_SOURCE_DIR:-"$PWD/../3rd/ladybird"}
vox_skia_root="$vox_upstream/Build/release/vcpkg_installed/$vox_triplet"
test -f "$vox_skia_root/lib/libskia.dylib"
test -d "$vox_skia_root/include/skia/include"
```

This one-time dependency setup additionally needs Python 3, GN, Ninja, and CMake.
The legacy bootstrap scripts remain available specifically for this purpose:

```sh
sh tools/vox-build.sh memory \
    --lock Build/mac-graphite-setup.lock --report Build/mac-graphite-setup.json \
    --timeout 7200 -- \
    python3 tools/build_mac_graphite.py --skia-root "$vox_skia_root" \
    --output Build/deps/graphics-bootstrap/libVoxGraphite.dylib

sh tools/vox-build.sh memory \
    --lock Build/mac-dawn-setup.lock --report Build/mac-dawn-setup.json \
    --timeout 7200 -- \
    python3 tools/build_mac_graphite_dawn.py --skia-root "$vox_skia_root" \
    --output Build/deps/graphics-bootstrap/libVoxGraphiteDawn.dylib
```

Run the Metal bootstrap before Dawn: Dawn shares the authenticated Skia archive
downloaded by the first command. GN can be on `PATH` or at
`$vox_skia_root/tools/gn/gn`; `GN` and `NINJA` override those tools. `JOBS` controls
parallel compilation and defaults to 8 in these bootstrap scripts. Dawn creates
a private Python environment under its dependency directory and installs its
pinned Jinja2 and MarkupSafe generator dependencies there.

Keep the complete prepared source trees and archives under `Build/deps`, not
only the bootstrap dylibs. The normal build checks the pinned archive checksum,
source revision, patch hashes, and Dawn dependency revisions before compiling
the Vox bridges. Its required outputs include:

| Backend | Prepared inputs |
| --- | --- |
| Metal Graphite | `Build/deps/skia-brave/source/out/Release/libskia.a` and `libskcms.a` |
| Dawn Graphite | `Build/deps/skia-brave-dawn/source/out/Release/libskia.a` and `libskcms.a` |
| Dawn native library | `Build/deps/skia-brave-dawn/dawn-build/src/dawn/native/libwebgpu_dawn.a` |
| Dawn generated headers | `Build/deps/skia-brave-dawn/dawn-build/gen/include/` |

Rerun the explicit setup when the pinned sources or patches change, or when a
dependency output is missing. If validation reports an unexpected source revision
or local modification, resolve that cache mismatch before rebuilding; the normal
build deliberately leaves upstream source trees untouched.

## Build and run Vox

After dependency setup, build through the production supervisor:

```sh
sh build-prod-browser.sh
open Build/v/Vox.app
Build/v/Vox.app/Contents/MacOS/Vox https://example.com
Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke
```

The launcher compiles the build tool with `-memory-limit 10G -gc none` and caches
immutable executables under `Build/tools/`. Production builds use the native
12 GiB process-tree guard; the headless smoke has a 3 GiB guard. The supervisor
publishes the ad-hoc-signed bundle only after smoke succeeds and preserves build,
smoke, and input receipts under `Build/production-build/receipts/`.

macOS defaults to `LADYBIRD_V_GC=prealloc`, which builds the browser with
`-prealloc -gc none` and the staged bounded-realloc/closure runtime. The tool's
own `-gc none` setting does not change that selection. Parallel C compilation is
the default when supported by V; `sh build-prod-browser.sh --no-parallel-cc`
requests the slower single-unit compilation path.

The production script forwards the deployment target from `Info.plist` to the
native bridges. For a focused bridge rebuild, both native commands require an
SDK path and output path and consume the caches above without generating upstream
code:

```sh
sh tools/vox-build.sh memory \
    --lock Build/mac-bridge-check.lock --report Build/mac-bridge-check.json -- \
    sh tools/vox-build.sh build-graphite --skia-root "$vox_skia_root" \
    --output Build/deps/graphics-bootstrap/libVoxGraphite.dylib

sh tools/vox-build.sh memory \
    --lock Build/mac-dawn-bridge-check.lock --report Build/mac-dawn-bridge-check.json -- \
    sh tools/vox-build.sh build-graphite-dawn --skia-root "$vox_skia_root" \
    --output Build/deps/graphics-bootstrap/libVoxGraphiteDawn.dylib
```

When called directly, those commands use `MACOSX_DEPLOYMENT_TARGET` if set and
otherwise read `Info.plist`. Python-based regression and benchmark scripts remain
optional developer tools; they are outside the production build path.

The diagnostic `VOX_PRIVATE_GRAPHITE_HELPER` override executes the supplied
program directly with `--repo`, `--skia-root`, and `--output`. A custom script
must be executable and declare its interpreter in its shebang.
