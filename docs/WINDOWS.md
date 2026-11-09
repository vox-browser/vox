# Windows build and runtime

Vox can be compiled for Windows x86-64 with current V and MinGW-w64. The build
uses the shared V/UI2 chrome, GG/Sokol window host, Skia raster services,
HarfBuzz, ICU, ANGLE, OpenSSL, libcurl and JavaScriptCore's C API. The Windows
window host uses Direct3D 11, with WARP software rendering when hardware device
creation fails. The fallback lives in Vox's graphics adapter; the shared V and
Sokol installations do not need changes.
The V graphics adapter also supplies shaders that consume GG's column-major
projection and texture matrices correctly in HLSL, including the font atlas.

The native `build_browser.vsh`/`x.imp` browser flow and portable ZIP packaging remain
release scaffolding. Use the dedicated helper below for this compilation path.
There is no Windows installer or update feed yet; the shared release version
remains in `packaging/version.txt`.

## Checkout limitation

The repository still has 46 `pixel_tests/` fixture paths containing `:` or `?`,
which Windows cannot check out. This compilation change does not rename those
fixtures. Cross-compiling the canonical checkout from macOS or Linux avoids
that filesystem restriction; a complete native Windows checkout remains
blocked until the fixture paths are made portable.

## Dependencies and native build

Install current V, Python 3, the latest upstream UI2 and the MinGW development
packages. Use `v install ui2` for a new installation and `v up ui2` to update it.
The [UI2 adapter guide](../tools/ui2/README.md) also covers separate checkouts.
In an MSYS2 MinGW64 shell, the native packages are:

```sh
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-pkgconf \
  mingw-w64-x86_64-python mingw-w64-x86_64-skia mingw-w64-x86_64-icu \
  mingw-w64-x86_64-harfbuzz mingw-w64-x86_64-freetype \
  mingw-w64-x86_64-woff2 mingw-w64-x86_64-openssl \
  mingw-w64-x86_64-angleproject mingw-w64-x86_64-curl
```

Provide a Windows `JavaScriptCore.dll` and its runtime dependencies. The
[Playwright WebKit distribution](https://github.com/microsoft/playwright/blob/main/packages/playwright-core/browsers.json)
contains a Windows WebKit build with this DLL. `prepare_windows_jsc.py` checks
the actual DLL's x86-64 export table against every C API declared by Vox before
creating its MinGW import library. It does not substitute a JavaScript engine.

From the repository, with MinGW Python and compiler tools on PATH:

```sh
python tools/build_windows_browser.py \
  --javascriptcore-dll C:/path/to/webkit/JavaScriptCore.dll \
  --output C:/path/to/output/Vox.exe
```

Set `V_BIN`, `UI2_SOURCE_DIR`, `CC`, `CXX`, `AR`, `OBJDUMP` or `DLLTOOL` to
override tool discovery. UI2 is linked directly from the current checkout.
UI2 and compiler compatibility modules need permission to create symlinks;
Windows Developer Mode supplies this for ordinary user accounts. Keep the native
dependency DLL directories on PATH, or install their
DLLs beside Vox.
JavaScriptCore's dependencies must come from its matching WebKit distribution.
The GCC runtime DLLs must match the compiler used for Vox's native bridges.
An older `libstdc++-6.dll` can load successfully itself while lacking an export
required by Vox, such as GCC 16's `__cxa_thread_atexit`. For a cross compiler,
locate its C++ and exception runtimes with:

```sh
x86_64-w64-mingw32-gcc -print-file-name=libstdc++-6.dll
x86_64-w64-mingw32-gcc -print-file-name=libgcc_s_seh-1.dll
```

Use that toolchain's `libwinpthread-1.dll` too, rather than mixing compiler
runtime versions from a different dependency distribution.

## Cross-compilation from macOS or Linux

Install the `x86_64-w64-mingw32` toolchain. Supply Windows development packages
in a sysroot containing `mingw64/include`, `mingw64/lib` and `mingw64/lib/pkgconfig`.
Use target libraries and headers throughout; host libraries cannot link into
a Windows executable. The cross compiler supplies its own C runtime headers.

The following builds inside the repository's memory guard:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/windows-build-UNIQUE.lock --report Build/windows-build-UNIQUE.json -- \
  python3 tools/build_windows_browser.py \
    --deps-root Build/deps/windows \
    --javascriptcore-dll /path/to/webkit/JavaScriptCore.dll \
    --output /tmp/Vox.exe
```

Remove the job's guard lock and report when it completes. Native archives and
the import library remain under `Build/deps/windows`. The helper prepares
native bridges and UI2, then runs the equivalent of:

```sh
ui2_modules=$(python3 tools/prepare_ui2.py)
v -memory-limit 10G -prod -no-prod-options -enable-globals -gc none \
  -os windows -arch amd64 -cc x86_64-w64-mingw32-gcc \
  -d ui2_custom_rendering -d sokol_d3d11 \
  -path "$PWD|$ui2_modules|@vmodules|@vlib" -o /tmp/Vox.exe .
```

`-prod` includes embedded resources in the executable. Without it, startup can
try to reopen files such as the public suffix list from the build machine's
source checkout. `-no-prod-options` retains the existing C optimization level.
Add `--console` to the helper when capturing startup diagnostics: V's GUI entry
point otherwise reopens stdout and stderr on a console or `NUL`.

The Windows build uses `-gc none`; scoped `-prealloc` remains unavailable.
Process tab grouping uses the existing in-process fallback. Dedicated script
worker processes, RequestServer socket event delivery and native video decoding
remain unavailable. Compiling an
executable does not establish Windows runtime or rendering conformance.

## Focused native checks

`tools/test_windows_native.c` exercises reservation, commitment, decommitment
and zero-filled recommitment, socket readiness and queued wakeups, Windows
argument quoting. Compile it with MinGW,
then run it on Windows:

```sh
gcc -std=gnu11 -Wall -Wextra -Wno-unused-function -Werror \
  -o windows-native-tests.exe tools/test_windows_native.c -lws2_32
./windows-native-tests.exe
```

The existing `libjs/stack_info_test.v`, `libgc/primitive_storage_test.v`,
`platform/native_timer_test.v`, `platform/native_deferred_test.v` and
`browsernet/websocket_test.v` cover the corresponding shared behavior. Run
compiled test binaries with the repository's 3 GiB runtime guard on hosts that
support it. Cross-compiling a test binary only verifies compilation.

For Windows itself, build the job-object guard and its integration checks:

```sh
gcc -municode -std=gnu11 -O2 -Wall -Wextra -Wno-unused-function -Werror \
  -o runtime-guard.exe tools/windows_runtime_guard.c
gcc -municode -std=gnu11 -O2 -Wall -Wextra -Werror \
  -o guard-tests.exe tools/test_windows_runtime_guard.c
runtime-guard.exe 60000 3072 guard-tests.out guard-tests.err \
  C:/path/to/guard-tests.exe C:/path/to/runtime-guard.exe
```

The guard sets a kernel job committed-memory limit before resuming the child,
kills remaining descendants on close and enforces a timeout. Its JSON receipt
records the child exit, timeout and job memory counters. This is a different
metric from the host Python guard's sampled process-tree RSS. The integration
checks exercise Unicode/quoted arguments, both output streams, exit propagation,
timeout termination and a rejected allocation above the job limit.

Run the graphics check on the interactive Windows desktop, also through the
3 GiB guard:

```sh
gcc -std=gnu11 -O2 -Wall -Wextra -Werror -o graphics-test.exe \
  tools/test_windows_graphics.c -ld3d11 -ldxgi -ldxguid -luser32
runtime-guard.exe 180000 3072 graphics.out graphics.err C:/path/to/graphics-test.exe
```

It creates the same Direct3D device/swap-chain adapter used by Sokol, clears a
render target and checks the pixels read back from it with both the default
driver and explicit WARP. Check GG's projection and font pipelines separately:

```sh
v -memory-limit 10G -prod -no-prod-options -enable-globals -gc none \
  -os windows -arch amd64 -cc gcc -d sokol_d3d11 -subsystem console \
  -file-list native/graphics_windows.c.v,native/paint.v \
  -o projection-smoke.exe tools/windows_graphics_smoke.v
runtime-guard.exe 180000 3072 projection.out projection.err \
  C:/path/to/projection-smoke.exe C:/path/to/projection.png
python tools/check_windows_graphics_smoke.py C:/path/to/projection.png
```

The PNG checker uses Pillow and can run on the host after copying the PNG out
of the VM. It checks rectangle positions, full areas, colors and text coverage.
The browser fixture
`Tests/Browser/Windows/smoke.html` separately checks page rendering, a script
mutation and a clickable DOM event target.

## Initial compilation checks on 2026-11-08

The macOS workspace cross-compiled the full browser with `-os windows -arch
amd64`, MinGW GCC 16.2.0 and the helper above. Compilation and its 12 GiB memory
guard both exited zero. The resulting file is a Windows x86-64 PE32+ GUI
executable, with SHA-256
`f6b084528bbb0d7eac12f0d5b397e63ad5ef71c422ac5adae11b8d253ad3501d`.

All five shared test files listed above and
`webgl/native_diagnostic_queries_test.v` compiled and executed successfully on
macOS with `-gc none` and guarded runtimes. The Windows native smoke program
compiled and linked with warnings treated as errors; its panic-handoff checks
also executed on macOS. The modified Skia bridges passed macOS C++ syntax
checks. Those initial checks did not execute the Windows binaries.

The build scaffolding's help is available with
`v run build_browser.vsh --help`. Regex now uses the translated V compiler and
VM; no Rust toolchain or regex archive is needed. Frozen source records can be
checked with [the V reference checker](../tools/REFERENCE_CORPORA.md). The native
smoke program was compiled and linked again after removing the obsolete Rust
panic handoff; this change has not been executed in Windows.

## Windows VM verification on 2026-11-08

The existing Windows 11 Enterprise Evaluation VM (10.0.26200.9711) executed
the full x86-64 GUI browser, with four virtual CPUs and 8 GiB RAM under QEMU
TCG. The final executable is installed at `C:\vox-runtime\Vox.exe`, with SHA-256
`8534d2c99448d24894f2f6449fa99e2c9b7b7d091ff2dd2bae0d56b50cfb80ce`.
Its hash was checked inside the guest before and after the browser runs.

Fresh processes passed `--headless-smoke` and a normal interactive launch.
The local fixture rendered correctly, displayed its script-updated
"JavaScript passed" text, and changed it to "Click passed" after an actual
mouse click. The normal window also loaded and saved its default bookmarks
successfully after the Windows atomic-replacement fix.

The native memory/socket tests, runtime-guard integration tests, default and
WARP Direct3D pixel readback, GG projection/color/text checks, and atomic
profile-replacement tests all executed successfully in Windows. The profile
tests also executed successfully on macOS. Browser and focused Windows test
processes ran under 3 GiB job limits; the VM and cross-compilers used the
host's 12 GiB RSS guard.

The [verification receipt](WINDOWS_VM_VERIFICATION_20261108.json) records the
executable and DLL identities, commands, exits, memory receipts and earlier
runtime failures. The [Windows desktop capture](windows/windows-vm-click-20261108.png)
shows the normal browser window after the click. These are functional smoke
checks of the pinned build; the platform limitations listed above still apply.
The VM shut down cleanly after the checks; the tested runtime remains installed.
