# Direct Metal WebGL migration

On macOS, WebGL now uses the V Metal service by default. There is no ANGLE,
EGL, GLES or desktop OpenGL execution path or fallback on that platform.
`webgl/native_service.c.v` selects `native_metal_boundary.h` and the
`service*_darwin.v` implementation. Linux and Windows retain their GLES service;
Metal is an Apple API. Standard JavaScript extension names such as
`ANGLE_instanced_arrays` remain API compatibility names.

The macOS ANGLE dispatch loader, generator, native loader test and obsolete
PR #63 CGL prototype/comparison harness have been removed. The shader pipeline now runs in pure V and requires neither glslang nor
SPIRV-Cross. Shared service ABI names retain
the historical `vox_egl_*` prefix; those names do not load or call EGL on macOS.

## Implementation

V owns context validation, error flags, resource namespaces, lifetime and draw
assembly. Small native graphics bridges allocate Metal resources and encode
GPU operations. All 198 shared service entry points have Metal implementations;
there are no unsupported-entry stubs or ANGLE fallbacks.

- Initialized drawing buffers, buffers and textures; context loss/restoration,
  resizing, deferred deletion and painting-surface publication.
- Direct V ESSL 1.00/3.00 preprocessing, linking, layout and MSL generation
  into actual Metal functions. Original source
  queries, attribute locations, active resources, nested structured uniforms,
  boolean types, matrices, arrays and uniform-buffer ranges are preserved.
- Array/indexed/instanced draws, expanded line loops/triangle fans, packed and
  overlapping vertex inputs, integer/normalized/constant attributes, raster,
  viewport/scissor, blending, culling, depth and separate stencil faces.
- 2D/cube/array/3D textures, mipmaps, samplers, typed and packed pixel transfers,
  pixel buffers, S3TC BC1/2/3 decoding, framebuffer layers, multiple color
  targets, depth/stencil attachments, multisample storage/resolves and blits.
- Native visibility queries, synchronous completed fences and actual GPU vertex
  output capture for transform feedback, including packing, ownership,
  pause/resume and primitive queries.

Physical native signed integers use V `i32`; public `[]int` inputs are packed
at the boundary. RGB storage preserves implicit alpha one through allocation,
clears and drawing. Float filtering is advertised from actual Metal device
support. Invalid multisample blit destinations are rejected according to the
GLES contract rather than extending it with a per-sample copy operation.

The default shader path and native fixture ABI both use `webgl/shader`.
Shader submission does not load glslang or SPIRV-Cross. Apple shader compilation
may indirectly load system OpenGL framework images; the implementation calls no
OpenGL API. The [shader report](SHADER_VALIDATION.md) lists the supported subset
and remaining conformance limits.

## Verification

The vector-swizzle follow-up passes 316 WebGL, 73 compiler and 52 Metal test
functions (441 total) in both GC modes. It adds real GPU coverage for `.stpq`
reads and writes, rejects mixed/out-of-range selectors and duplicate writable
components, and preserves structure fields whose names resemble selectors.
All compiler/runtime and guard exits were zero; the combined run peaked at
1,057,832,960 sampled RSS bytes under a 3 GiB guard.

The language-limit follow-up passes **316 WebGL functions from 179 files,
71 compiler functions from 16 files, and 52 Metal functions from 13 files**
with current V's C backend in default GC and `-gc none`. This includes scoped
loop/output protection, overload liveness, constant bounds, struct member types,
parameter copies, vector/matrix equality, numeric builtins, named/row-major
block arrays, sampler arrays, shadow mip/gradient sampling, projected offsets
and invariant positions. All 27 native ARC/MRC/ASan+UBSan fixture runs also pass;
their pinned inputs stayed unchanged. Compilation, runtime and memory-guard
exits were zero. The combined V run peaked at 1,036,238,848 sampled RSS bytes
under its 3 GiB guard.

The Windows native fixture cross-compiles for `-os windows -arch amd64 -gc none`
without shader-compiler DLL imports. Linux and Windows driver runtime checks
remain platform validation work. The latest completed production browser's
headless engine/DOM/input smoke passes with executable SHA-256
`5fb3eb909ae426b7cfcb1b0e8a67ab494177d13b0a0f693d5ae5d1e737561576`.
That bundle predates these language changes; their browser-level smoke awaits
the managed rebuild requested by the feature commits. The GPU/service tests
above execute the current source directly. See
[shader validation coverage](SHADER_VALIDATION.md) for the conformance boundary.

The initial dependency-removal check (2026-11-13) with current V's C backend
passed 314 functions from all 178 shared WebGL test files in default GC and
`-gc none`. The focused compiler module passes 51 functions from 14 files and
the Metal module passes 45 functions from 13 files in both modes. All 27 native
fixture/mode combinations pass under ARC, MRC and ASan/UBSan, including the
exported V ABI, GPU capture, uniforms and unloaded-compiler-library checks.
Compile, test and memory-guard exits were zero; pinned native inputs stayed
unchanged. The Windows native GLES fixture cross-compiles with `-gc none`
without glslang/SPIRV-Cross imports; its runtime and the updated Linux GLES
runner were not executed on this macOS host. The managed production rebuild
is queued; these focused results do not validate the older installed bundle.

Before the V compiler switch, the macOS configuration passed **314 test functions from 178 WebGL
files**, compiled together with both the C backend and FastC, in default GC
and `-gc none`. The public JavaScriptCore bindings pass **151 functions from 132 files** using
single-unit FastC in both GC modes. Both execute real native contexts and GPU
results; compile-only audits receive no runtime credit.

Before removing ANGLE dispatch, the shared shader corpus passed both services:
40 acceptance/error/source-query cases and eight exact 8×8 pixel fixtures, in
both GC modes. Boolean/structured uniforms, ESSL100 MRT, float filtering and
RGB alpha checks also passed both services. The earlier full ANGLE native
reference suite passed 161 files in both GC modes. Later Metal-only resource
cases are not described as ANGLE comparisons.

The native resource suite covers nine fixtures in ARC, manual reference
counting and ASan/UBSan modes (27 fixture/mode runs). Its 45 V tests across 13
files exercise exact pixels, bounds, ownership and GPU resource lifetime in
both GC modes. Run from
the canonical checkout, with current V:

```sh
python3 tools/test_webgl_metal.py --v-bin ~/code/v/v --output Build/metal-resources-UNIQUE
python3 tools/test_webgl_metal_service.py --output Build/metal-service-UNIQUE --batch webgl/*_test.v
python3 tools/test_webgl_metal_service.py --backend fastc --output Build/metal-public-UNIQUE --batch browserjs/canvas_webgl*_test.v
python3 tools/test_webgl_metal_browser.py --output Build/metal-browser-UNIQUE
```

The runners pin inputs and apply the repository compilation/runtime memory
guards. FastC aggregation stays temporarily beside the canonical tests, groups
conflicting import aliases separately and uses `VJOBS=1` so native state has
one definition. No sources or browser bundles are copied into job directories.

The broader FastC run exposed additional shared-wrapper/compiler boundaries.
Sampler, sync and vertex-array deletion now borrow nullable handles, preserving
heap-object mutation without passing a raw object as an optional-argument
pointer. Error-path tests require failure explicitly, avoiding FastC's invalid
read of an unused error result. Native string termination uses a bounded byte
scan instead of the miscompiled generic `array.index(0)`. Metal vertex arrays
initialize every attribute's default size/type explicitly; constant attributes
also initialize their floating-point kind. Existing ownership/state tests and
new string/default-state assertions pass with both compiler backends.

The production browser passes headless startup and two fresh windowed WebGL
checks. The fixture executes ESSL100/WebGL1 and ESSL300/WebGL2 programs through
JavaScriptCore, checks preserved source, uniforms, scissor orientation, every
readback pixel and normal error state. Both contexts report `Vox direct Metal`;
full 400×240 document PNGs match independently generated expected pixels
exactly. Dyld logs contain no ANGLE/EGL/GLES library. Executable/native-library
hashes remain fixed under a bundle reader lease and every browser/guard exits 0.

The [local migration evidence](performance/metal-webgl-migration-20261112.json)
retains commands, input/executable hashes, actual exits, guard reports and failed
attempts, including the earlier partial implementation checkpoints. Their old
experimental flags and ANGLE-reference runner options describe those historical
inputs; they are no longer current build options.

## Limits and retained failures

This replaces the macOS backend; it is not complete WebGL conformance or a
performance claim. Submission currently waits for GPU completion and pipelines
are created at draw time. Broader shader/conformance edge cases remain subject
to testing. The browser still uses JavaScriptCore; unfinished LibJS and remote
transport/wrapper boundaries are unchanged.

The installed ANGLE reference agrees on unsigned packed, signed normalized,
normalized i32 and overlapping float vertex inputs. For signed **unnormalized**
2:10:10:10 input with negative two-bit alpha, it produces alpha 255 where Metal
produces 0. Metal retains the GLES 3.0.6 section 2.9.2 signed-field semantics;
the failing reference receipts remain local. This is a disclosed discrepancy,
not a full pixel-equivalence claim.

The combined browser-binding test compilation using the C backend reached the
12 GiB guard and supplied no runtime result; the complete public suite instead
passes FastC. Production browser compilation is verified separately. Standalone
MutationObserver FastC execution also remains a failed diagnostic; its ordering
checks pass the C backend and are not part of the WebGL parity claim.

Optimized-site acceptance is tracked separately in
[the site pixel audit](OPTIMIZED_SITES_PIXELS_2026_11_12.md). Existing CNN,
vlang.io and GitHub differences and the missing account-bearing Reddit fixture
prevent an all-site parity claim. Unchanged shader-free site pixels alone
cannot validate this WebGL backend; actual shader execution is required.

## Optimized-site capture follow-up

The first completed Metal production executable is
`05ae545a3d814fdbc65fed7a94c7c1701a28809bfaf403d6e7d4d790a8012391`,
receipt `20261112-151621-60deec8f`. Its requested head precedes the final switch,
but the verified parsed-source manifest hashes match the default Metal service,
macOS source selector, framebuffer checks and render-state adapter. The old
macOS ANGLE loader/gated service files are absent from the parsed closure.
The shader browser fixture and headless smoke above ran this executable.

Two fresh captures of each available frozen catalog workload give:

| Site | Differing RGBA pixels against retained Brave reference, each capture |
| --- | ---: |
| Hacker News | 0 / 3,145,728 |
| Lobsters | 0 / 786,432 |
| Wikipedia | 0 / 786,432 |
| CNN | 175,866 / 786,432 |
| vlang.io | 5,756 / 786,432 |
| GitHub /vlang/v | 38,654 / 786,432 |
| Old Reddit | Unverified: historical account-bearing fixture absent |

Captures retain original-origin sealed responses, fresh private profiles/caches,
1024×768 document viewports, scale 2 for HN and scale 1 otherwise, two seconds
of settling for HN and five otherwise. Author scripts are disabled for Wikipedia
and vlang.io as in their references; other pages retain normal scripting.
Readiness, URL, body content, title/row checks and resource/executable identities
pass, with normal browser/guard exits. No reference or tolerance changed.

HN, Lobsters and Wikipedia also match their retained ANGLE-era Vox images
exactly. CNN, vlang.io and GitHub differ from those older Vox images at 1,861,
1,372 and 15 pixels respectively, with improvements against the Brave reference.
Concurrent document-renderer changes are included in this production build;
these differences are not isolated Metal effects or backend-equivalence credit.
The all-site equality gate remains open. These are frozen viewport checks, not
live-site, interaction, Retina-wide, scrolling or instruction-performance claims.

## Final committed-source production check

The completed production executable
`303a768fe0f94a3b22c129a1cc3f471e0c7dad8c932527fed35d79831efe5511`
(receipt `20261112-154007-d64f9163`, requested head `f0dd5a1fd`) contains all
final WebGL fixes. All 92 WebGL inputs present in its parsed/native source
manifest match the current implementation hashes. It uses the C backend,
literal V `-prod`, one C unit and the prepared preallocated runtime.
The headless smoke and two new WebGL1/WebGL2 shader/readback/presentation
trials pass with normal exits and no ANGLE/EGL/GLES library loaded.

All 314 native/Source tests pass in C and FastC, and all 151 public binding
tests pass in FastC, each in default GC and no-GC mode. The final native
compiler-compatibility executable also compiles and runs through the production
C frontend. No guard was bypassed: the `153721-4412c760` production attempt
rejected a concurrent PNG-header change; the managed retry above succeeded.
An earlier successful but unpublished build was superseded while a bundle
reader lease was held. Both attempts remain in local evidence.

Two fresh captures per available catalog site under this final executable give:

| Site | Differing RGBA pixels against unchanged Brave reference, each capture |
| --- | ---: |
| Hacker News | 0 / 3,145,728 |
| Lobsters | 0 / 786,432 |
| Wikipedia | 0 / 786,432 |
| CNN | 175,866 / 786,432 |
| vlang.io | 4,144 / 786,432 |
| GitHub /vlang/v | 38,404 / 786,432 |
| Old Reddit | Unverified: historical account-bearing fixture absent |

The same fixture/script/viewport/scale/settle policies and document audits above
pass. HN, Lobsters and Wikipedia remain identical to their ANGLE-era Vox images.
CNN, vlang.io and GitHub differ from those older Vox images at 1,861, 2,143 and
419 pixels. Concurrent PNG sampling changes improve vlang.io and GitHub against
the retained Brave references; they do not supply isolated Metal credit.
No all-site equality or live-site/performance acceptance is claimed.
