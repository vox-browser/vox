# Windows WebGL without ANGLE

Windows now uses native Mesa WGL/GLES3 for WebGL1 and WebGL2 and retains D3D11 for
its GG/Sokol window. Both WebGL versions share the bounded GLES adapter used
on Linux. There are no ANGLE headers, import libraries or vendor entry points.
Compatibility extension names in the shared ABI map to core GLES operations.

The adapter validates transfer/query capacity and PBO offsets, initializes new
buffer/texture/renderbuffer storage, checks active vertex/index streams, and
validates ESSL version and loop restrictions in V before unchanged driver compilation.
Each Windows service call rebinds the selected GLES context after a host release.
D3D11 window state is independent of that context. The WGL loader comes from
the directory of the loaded Mesa Gallium DLL. Context creation verifies both
the Mesa GLES version string and `GL_CONTEXT_ROBUST_ACCESS_KHR`; an ordinary
context or an old ANGLE deployment cannot silently supply the backend.

The first Windows execution exposed a limitation in
[Mesa's EGL/WGL frontend](https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-26.2.6/src/egl/drivers/wgl/egl_wgl.c):
it creates ordinary GLES contexts but does not expose robust ES context creation.
Both robustness attribute forms failed with `EGL_BAD_ATTRIBUTE`. The adapter
now uses the [native WGL context path](https://gitlab.freedesktop.org/mesa/mesa/-/blob/mesa-26.2.6/src/gallium/frontends/wgl/stw_context.c),
which passes the robust-buffer-access flag to the same Gallium/GLES implementation.
The required robustness check remains enabled.

`tools/windows_mesa.json` pins matching Mesa 26.2.6 development and x64 MinGW
runtime archives by SHA-256. The build helper prepares a separate pkg-config
entry and verifies the runtime contains EGL, GLES, Gallium and the WGL loader. MSYS2's stock
[Mesa build disables EGL/GLES](https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-mesa/PKGBUILD);
the runtime comes from the [Mesa Windows distribution](https://github.com/pal1000/mesa-dist-win/releases/tag/26.2.6).

## Completed checks

The Windows x86-64 C-backend cross-build passed with the checked current V
frontend, production resource embedding, MinGW and GC disabled. This diagnostic
browser enables console output. Compiler and
12 GiB process-tree memory guard exited 0, with peak aggregate RSS
9,359,949,824 bytes. Recorded repository source and compiler hashes remained
unchanged during the build. This build includes the shared V shader frontend.

Verified browser in the guest: `C:\vox-runtime-current\vox-current.exe`.
SHA-256: `b0e596c34356b8f4c2f797f45b7c3cd5d62d2414fc25664b2667be503e931420`.
The final function-pointer cast clarification rebuilt to the exact same native
object SHA-256 used by this executable:
`ad3305a8f069c73ac11a97f08ad0742774d9ced67d3c3067675678a9891e858f`.

The GG staging adapter previously wrapped the portable `path_math.h` helper in
a `.m` include. That selected Objective-C for the Windows program and suppressed
MinGW's `BOOL` typedef. The adapter now wraps only Darwin helpers. Its staging
regression test and all three build-tool test files pass. Earlier failed browser
builds and their guard receipts are retained locally. The unpatched shared V
compiler also emitted references to missing streaming-string helpers; the checked
frontend avoids that separate toolchain failure.

The shared native GLES tests passed all six Linux runtime cases: optimized and
ASan/UBSan builds of headless GLES, GLX-only control and GLX/GLES interoperation.
They retained CPU canaries, exact shader pixels, initialized storage, error and
context isolation checks, and the existing narrow Mesa GLX leak suppression.
Input hashes remained unchanged. The final rerun used Ubuntu 24.04.5 ARM64,
llvmpipe/LLVM 20.1.2 and its V 0.5.2 `4460fc9` fixture compiler. The initial
sanitizer attempt could not link until Clang 18's runtime package was installed;
that failed attempt is retained.

The Windows native GLES suite now passes both WebGL versions, including robust
contexts, exact shader pixels, initialized storage, transfer/query canaries,
PBO bounds, context isolation, rebind after a host release, and the loaded Mesa
Gallium/WGL audit. Its driver is explicitly a console executable so V cannot
redirect test diagnostics to `NUL`. The DLL audit uses the wide Windows APIs,
including under V's Unicode build flags. Earlier context-creation and audit
failures are retained locally.

The fresh Windows guest passed that native suite under Mesa llvmpipe/LLVM
23.1.4, with a 3 GiB job-object limit and peak committed memory of 141,410,304
bytes. The full browser's `--headless-smoke` also exited 0, checking JavaScript
DOM mutation and click handling, native wheel routing and ordinary element
wheel listeners. Its peak committed memory was 382,009,344 bytes. Both guard
receipts report no timeout.

The first interactive run reached the correct startup title with a live child
process but failed foreground activation. The driver now creates its input
queue, joins both window input threads, and falls back to a real address-field
click when Windows rejects programmatic activation. The corrected driver passed
startup pixels, native click/JavaScript mutation, resize/redraw at 960x720,
Ctrl+L/Enter navigation with an escaped space, query and fragment, both WebGL
versions' shader readback, all 8,192 displayed canvas pixels, the Mesa module
audit and clean browser exit. Its job guard exited 0 without timeout, with
peak committed memory of 790,990,848 bytes. The pixel expectations were unchanged.

All six assertion-enabled V test executables passed: shader equivalence, native
draws, parameter queries, JavaScript canvas host, texture storage/source ownership
and base draw/source ownership. These cover 13 test functions, including the
shared 40-case shader corpus and eight exact texture-pixel cases. Each executable
and its 3 GiB job guard exited 0 without timeout; the highest unit-test peak was
556,285,952 committed bytes. Runtime files and 131 data fixtures matched their
SHA-256 pins before and after the final suite. The current Mesa PowerShell
bootstrap also parsed successfully on Windows.

The initial public-binding unit runs stopped before assertions because the
non-production executables needed V's external Brotli dictionary. Installing
that pinned fixture let the unchanged binaries pass. A monitoring file-sharing
race also interrupted an earlier final identity check; the final monitor uses
a shared reader. Earlier failures remain local. Fresh-profile `os.file_size()`
diagnostics remain in the successful browser's stderr.

The build-tool tests also passed rejection of corrupt cached Mesa
archives. The Windows native GLES test, job-object guard and interactive browser
driver cross-compile with warnings treated as errors. The interactive driver
accepts the unchanged shared WebGL smoke fixture and checks all 8,192 displayed
canvas pixels after its startup, click, resize and keyboard navigation checks.
The Windows CI job adds actual native Mesa execution with a 3 GiB job limit.

## Fresh Windows installation

The old `v-win11-vm/v-windows.qcow2` overlay cannot boot because its backing disk
was deleted. It has been retained. Windows is now installed independently at
`~/.local/share/vox-windows-webgl/windows11.qcow2`; its 80 GiB virtual disk has
no backing file and boots with the installation media detached. The new VM
uses four virtual CPUs, 8 GiB RAM, private UEFI state, loopback-only SSH/VNC,
a local test account and key-only SSH authentication. Its private `launch.py`
starts QEMU through the canonical repository's 12 GiB memory guard.
The installed guest reports Windows version `10.0.26300.9457`.

The Windows 11 Enterprise 26H2 evaluation ISO came from Microsoft's Evaluation
Center. Its SHA-256 matched Microsoft's
[published verification value](https://support.microsoft.com/en-us/servicing/os/windows/docs/2026/09/verify-the-authenticity-of-a-windows-11-enterprise-evaluation-iso-file):
`bc3f24086ebadc94489066b5ad78089e2cf5c3491e90e790bb81a2b199c10e38`.
The download guard exited 0. The detached installation ISO was removed after
checking both the standalone disk chain and QEMU's attached media, recovering
host disk space. The download identity and removal audit remain local.

The original setup boot with QEMU's `max` CPU and multithreaded TCG crashed with
`SYSTEM_SERVICE_EXCEPTION` before Vox ran. The installed guest subsequently
booted with `Nehalem-v1` and single-threaded TCG. The original crash is retained;
its root cause has not been established. Host storage exhaustion also paused
QEMU with an I/O error during verification. Disposable task inputs were removed
and the VM resumed. The final file-based GUI checks and identity checks completed
with the VM network temporarily disconnected to halt background traffic; it was
reconnected to retrieve the results. Interrupted and failed attempts remain in
the local evidence. These runs provide functional assertions, not timing data.

After verification, the temporary Windows firewall rule was removed and Windows
shut down normally. QEMU and its 12 GiB host guard exited 0. An offline,
non-repairing `qemu-img check` found no errors; the backing chain still contains
only the installed disk. The VM is stopped. Its launcher now requires 5 GiB of
free host storage before another boot. A further reboot was not attempted on
the full host volume.

Local commands, hashes, failed attempts, guard receipts and captures are kept in
ignored `docs/performance/windows-angle-free-20261112/`. The VM's standalone
disk, credentials and operational metadata remain outside
`Build/`. Preserve the disk and its UEFI/SSH state for subsequent sessions.

This is focused WebGL and browser smoke coverage, not full WebGL conformance,
hardware GPU validation, all-site equivalence or Windows release packaging.
