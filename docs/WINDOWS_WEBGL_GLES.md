# Windows WebGL without ANGLE

Windows now uses native Mesa WGL/GLES3 for WebGL1 and WebGL2 and retains D3D11 for
its GG/Sokol window. Both WebGL versions share the bounded GLES adapter used
on Linux. There are no ANGLE headers, import libraries or vendor entry points.
Compatibility extension names in the shared ABI map to core GLES operations.

The 2026-11-14 checks passed native GLES, all 8,192 browser canvas pixels and
live HTTPS, but the browser remained active after its window disappeared.
That shutdown hang keeps the full Windows runtime gate open; see the latest
[verification record](#cold-boot-and-https-trust-on-2026-11-14).

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
free host storage before another boot. That verification did not attempt a
further reboot on the full host volume; the later cold-boot check is recorded
below.

Local commands, hashes, failed attempts, guard receipts and captures are kept in
ignored `docs/performance/windows-angle-free-20261112/`. The VM's standalone
disk, credentials and operational metadata remain outside
`Build/`. Preserve the disk and its UEFI/SSH state for subsequent sessions.

This is focused WebGL and browser smoke coverage, not full WebGL conformance,
hardware GPU validation, all-site equivalence or Windows release packaging.

## Cold boot and HTTPS trust on 2026-11-14

The standalone installation booted again with no installation or seed CDROM
attached. The previously pinned browser passed native GLES, headless startup,
local click/resize/navigation and all 8,192 WebGL canvas pixels after that boot.
Its optional live navigation then failed with libcurl error 77: the portable
runtime lacked the compiled default `C:/etc/ssl/certs/ca-bundle.crt`. This failed
run remains in the local evidence.

Windows document/resource requests and native Fetch now share a trust setup
that selects Windows roots when no explicit CA bundle is supplied. It clears
libcurl's compiled CA file and directory paths while preserving peer and
hostname verification. Explicit CA bundles keep precedence. This follows
libcurl's [native CA option](https://curl.se/libcurl/c/CURLOPT_SSL_OPTIONS.html)
and [CA file semantics](https://curl.se/libcurl/c/CURLOPT_CAINFO.html).

The actual Windows transport passed public HTTPS using Windows roots, rejected
an untrusted private CA (60), accepted that CA only when explicitly supplied,
rejected a hostname mismatch (60), and rejected a missing explicit CA file
(77). Its 3 GiB job guard exited 0 without timeout. The runtime reports
libcurl 8.23.0 with OpenSSL 3.6.5. No CA file was installed into Windows' trust
store for these tests.

The rebuilt browser's SHA-256 is
`ae5286c576ad5e81691757179771ab2b5e0f7f964a9fffc3ace16505b0138cce`.
It cross-compiled from the shared canonical checkout with current V
`7d74206`, C `-prod -no-prod-options`, `-gc none` and MinGW GCC 16.2.0.
The 12 GiB build guard exited 0 with peak sampled RSS 9,427,468,288 bytes.
The shared checkout had unrelated concurrent edits; this executable and the
relevant transport/header hashes are pinned in the local evidence.

The macOS native RequestServer TLS test passed all five trust/hostname cases,
including a missing CA file and an untrusted default-root request. The three
cancellable-transport tests and system-libcurl lazy-loading check also passed
under 3 GiB runtime guards. The V tests used assertion-enabled `-gc none` builds
from the pinned compatible compiler `5909f83`. Current compiler attempts
exceeded the unchanged 12 GiB guard; those failed attempts remain local.
The first candidate suite passed TLS, title matching, headless startup and
all 8,192 browser canvas pixels, but failed its live two-minute title deadline.
Its four-minute native GLES job also timed out during WebGL2 shader checks.
The VM was briefly paused when host free storage fell below 5 GiB, and resumed
when it recovered to 18 GiB without deleting another session's files. That
attempt remains recorded as failed.

One 30-second HTTP-URL rejection invocation timed out in the emulated guest.
The unchanged driver returned the expected exit 2 without timeout under a
120-second limit; both receipts are retained. Windows CI is configured to run isolated
TLS fixtures and exact live-title matching tests without depending on an
external site. Live HTTPS/browser checks remain opt-in.

With the unchanged native GLES executable and a ten-minute job limit, the
suite subsequently passed with peak committed memory of 140,865,536 bytes.
Shader and OS caches were retained across attempts; these are functional
checks, not performance measurements.

The fresh browser retry also passed every local input/rendering check, all
8,192 canvas pixels, and the live HTTPS title. The opt-in live title deadline
was extended to ten minutes; local title checks kept their two-minute limit.
The browser then failed its clean-exit check: after `WM_CLOSE`, its window
disappeared but the child remained active beyond two minutes. The overall driver
exited 1, without hitting its job timeout, with peak committed memory of
1,882,779,648 bytes. All pinned inputs still matched after the run. The HTTPS
fix is committed as `23b40e16e`; the shutdown hang remains unresolved and the
full Windows runtime gate is open.

Host free storage later fell to 3 GiB, preventing a safe further browser build
or live shutdown probe. The VM was paused to protect its disk. A smaller
live-page-only probe with a minidump on a close timeout is prepared privately
but has not run. Continue that investigation after restoring sufficient host
storage; do not classify a forced process exit as a clean shutdown result.

Windows subsequently shut down normally. QEMU and its host guard exited 0;
an offline, non-repairing disk check also exited 0 with no errors. The backing
chain still contains one standalone image. The VM is stopped and preserved.

Cold-boot commands, input pins, failed attempts and guard receipts are local in
`docs/performance/windows-reboot-20261114/`. These checks do not establish
all-site pixel equivalence, full WebGL conformance or hardware acceleration.
