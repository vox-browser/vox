# Windows compilation

Vox can be compiled for Windows x86-64 with current V and MinGW-w64. The build
uses the shared V/UI2 chrome, GG/Sokol window host, Skia raster services,
HarfBuzz, ICU, ANGLE, OpenSSL, libcurl and JavaScriptCore's C API.

The native `build.v`/`x.imp` browser flow and portable ZIP packaging remain
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

Install current V, UI2, Python 3, Rust and the MinGW development packages. In
an MSYS2 MinGW64 shell, the native packages are:

```sh
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-pkgconf \
  mingw-w64-x86_64-python mingw-w64-x86_64-skia mingw-w64-x86_64-icu \
  mingw-w64-x86_64-harfbuzz mingw-w64-x86_64-freetype \
  mingw-w64-x86_64-woff2 mingw-w64-x86_64-openssl \
  mingw-w64-x86_64-angleproject mingw-w64-x86_64-curl
rustup target add x86_64-pc-windows-gnu
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
override tool discovery. UI2 preparation needs permission to create symlinks;
Windows Developer Mode supplies this for ordinary user accounts. Keep the
native dependency DLL directories on PATH, or install their DLLs beside Vox.
JavaScriptCore's dependencies must come from its matching WebKit distribution.

## Cross-compilation from macOS or Linux

Install the `x86_64-w64-mingw32` toolchain and Rust's
`x86_64-pc-windows-gnu` target. Supply Windows development packages in a sysroot
containing `mingw64/include`, `mingw64/lib` and `mingw64/lib/pkgconfig`.
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
v -memory-limit 10G -enable-globals -gc none -os windows -arch amd64 \
  -cc x86_64-w64-mingw32-gcc -d ui2_custom_rendering \
  -path "$PWD|$PWD/Build/v/modules|@vmodules|@vlib" -o /tmp/Vox.exe .
```

The Windows build uses `-gc none`; scoped `-prealloc` remains unavailable.
Process tab grouping uses the existing in-process fallback. Dedicated script
worker processes, RequestServer socket event delivery and native video decoding
remain unavailable. Compiling an
executable does not establish Windows runtime or rendering conformance.

## Focused native checks

`tools/test_windows_native.c` exercises reservation, commitment, decommitment
and zero-filled recommitment, socket readiness and queued wakeups, Windows
argument quoting and bounded Rust panic diagnostics. Compile it with MinGW,
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

## Verification on 2026-11-08

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
checks. Windows execution and visual conformance were not tested.

The existing build scaffolding's help and the pinned Rust source audit remain
available with `v run build.v --help` and
`python3 tools/build_regex_backend.py --verify-only`.
