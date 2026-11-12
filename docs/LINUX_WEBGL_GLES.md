# Linux WebGL without ANGLE

The Linux service uses distribution EGL/GLES3 (Mesa), not ANGLE. Both WebGL
versions use robust surfaceless GLES3 contexts. Windows retains its ANGLE service;
macOS uses the separate Metal service.

`webgl/gles_adapter_linux.h` implements bounded queries and transfers, per-context
errors, checked PBO offsets, and core GLES equivalents of the shared extension
ABI. New buffer, texture, immutable mip/layer and renderbuffer storage is
initialized. Draw validation checks active vertex/index streams before Mesa's
robust fetch behavior can silently mask an out-of-range WebGL draw. The shared V frontend
validates WebGL version and bounded-loop restrictions; the driver compiles unchanged
ESSL, and source queries retain the original text after validation failures.

The portable window uses desktop GLX. Every native WebGL service call temporarily
selects its GLES context and restores the caller's GLX context. GLX dispatch uses
opaque ABI types to avoid Sokol's incompatible GLX typedefs. Compatibility macros
end at the service header boundary, so GG/Sokol desktop shaders and GL state do
not enter WebGL validation. Dispatch initialization retries if libGL was absent
before the window opened.

The portable document painter also uploads retained canvas surfaces to streaming
GG images, preserving the source pixels while converting premultiplied RGBA for
the portable blend pipeline. It reuses image slots across frames and retires
slots when canvases disappear. Previously `draw_canvas` only painted on macOS.

## Focused verification, 2026-11-12

The existing Debian 13 ARM64 VM used Mesa 25.0.7 / llvmpipe (LLVM 19.1.7),
JavaScriptCoreGTK 4.1, and the current checked C frontend prepared from V
`31dd26c`. Sources were mounted from the canonical checkout; there was no source
copy or feature worktree.

| Check | Result |
| --- | --- |
| Native driver, GLX-only control, GLX/WebGL interoperation | Optimized and ASan/UBSan: six passing runtime cases |
| Shader acceptance and rejection | 40 cases; original source retained |
| Shader texture overloads and sampler names | Eight exact-pixel cases |
| Native draw, query, bitmap, storage, layers, RGB, compression, renderbuffer and pixel-store cases | 10 files / 19 functions with Boehm |
| Native draw, shader, query, bitmap, texture-copy and VAO cases | Six files / 13 functions with GC disabled |
| Public JavaScript shader/draw/readback/resize, storage and owner validation | Three files / five functions with Boehm |
| Final draw, shader, query and public shader/draw/readback/resize cases | Four files / 11 functions with poisoned prealloc arenas |
| Canvas upload alpha and source preservation | One function, Boehm / GC disabled / poisoned prealloc |
| Smoke-harness failure controls | 16 Python tests |
| Linux entrypoint checks | 22 Python tests |
| Shared browser fixture on the earlier completed macOS build | Two fresh launches, zero differing pixels; fixture compatibility only |

The GLX-only control reproduced a Mesa visual/config cache leak without any
WebGL calls: 108,124 bytes in 481 allocations. GLX sanitizer cases use the narrow
`libGLX_mesa.so` suppression in `tools/native_gles_glx.lsan-suppressions`.
Headless native cases retain unsuppressed leak checking.

The raw VM compiler exceeded the 12 GiB process-tree guard while compiling the
public JavaScript tests. Those tests passed with the production checked compiler,
peaking below 4.5 GB. Runtime guards remained 3 GiB; compiler guards remained
12 GiB and V retained `-memory-limit 10G`.

## Browser verification

The supervisor published `Build/linux/vox` from receipt
`20261112-165233-de761f08`, using the C backend, Clang `-O2`, Boehm and one C
unit (`v_prod=false`). Build and headless-smoke receipts both report exit 0,
and the production input digest matched before and after compilation.

Executable SHA-256:
`f1f6333900003f12b32f6f9d305590c68cd5e3b2c802c3eb3857b8390174f588`.

A fresh candidate capture and a fresh published-executable capture used that
same hash. Both reported llvmpipe for WebGL1 and WebGL2 and passed exact shader
readback and all 8,192 displayed canvas pixels. No ANGLE library appeared in
`ldd`; the native driver test also audited `/proc/self/maps`.

The complete published-browser suite passed startup JavaScript/DOM/events/wheel
routing, local scripted HTML, trusted HTTPS and certificate rejection, redirects,
800×600 X11 painting, Ctrl+L/Enter navigation, 960×720 resize/redraw, process-tab
startup/switching/retained paint, successful child retirement, and complete
process-group shutdown. The browser suite and its 3 GiB guard both exited 0;
peak aggregate RSS was 918,032,384 bytes. Executable, linked-library, fixture,
harness and relevant graphics-source hashes remained unchanged under a shared
publication lease.

One older bootstrap shell reported exit 127 *after* successful publication,
when it resumed reading a concurrently edited `run_v_tool.sh`. Its supervised
compile, smoke and publication receipts are successful; the subsequent complete
browser run used the published executable and exited 0. Earlier superseded and
failed build receipts remain in the local evidence.

## Scope and evidence

This establishes focused Linux behavior, not full WebGL conformance, hardware
GPU coverage, Wayland-native hosting, or pixel equivalence with the macOS
painter. Portable canvas replay follows the existing rectangular image clip and
transform path; Cocoa-only effects remain outside this check. GLES3 robustness
support is required. Transfer/error corner cases and
unsupported driver extensions still require broader conformance work.

Local receipts, commands, failed attempts, source hashes and captures are kept in
ignored `docs/performance/linux-angle-free-20261112/`. Failed attempts include
WebGL loop/draw validation, upload error precedence, the GLX/Sokol header clash,
compatibility macros reaching desktop shaders, missing portable canvas upload,
a remaining Xvfb child at the guard endpoint, and the raw compiler memory
rejection. These were retained;
references and pixel tolerances were not changed. The shared fixture checks
exact shader readback and exact displayed canvas pixels for both WebGL versions.
