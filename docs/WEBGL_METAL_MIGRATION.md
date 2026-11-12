# Direct Metal WebGL migration

On macOS, WebGL now uses the V Metal service by default. There is no ANGLE,
EGL, GLES or desktop OpenGL execution path or fallback on that platform.
`webgl/native_service.c.v` selects `native_metal_boundary.h` and the
`service*_darwin.v` implementation. Linux and Windows retain their GLES service;
Metal is an Apple API. Standard JavaScript extension names such as
`ANGLE_instanced_arrays` remain API compatibility names.

The macOS ANGLE dispatch loader, generator, native loader test and obsolete
PR #63 CGL prototype/comparison harness have been removed. Homebrew setup now
requires `glslang spirv-cross` instead of ANGLE. Shared service ABI names retain
the historical `vox_egl_*` prefix; those names do not load or call EGL on macOS.

## Implementation

V owns context validation, error flags, resource namespaces, lifetime and draw
assembly. Small native graphics bridges allocate Metal resources and encode
GPU operations. All 198 shared service entry points have Metal implementations;
there are no unsupported-entry stubs or ANGLE fallbacks.

- Initialized drawing buffers, buffers and textures; context loss/restoration,
  resizing, deferred deletion and painting-surface publication.
- ESSL 1.00/3.00 validation/linking with glslang, SPIR-V generation and
  SPIRV-Cross MSL translation into actual Metal functions. Original source
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

The shader compiler libraries load at the first shader submission, rather than
browser startup. Native cold-loading tests check this boundary and assert that
no ANGLE image loads. Apple shader compilation may indirectly load system
OpenGL framework images; the implementation calls no OpenGL API.

## Verification

The default macOS configuration passes **314 test functions from 178 WebGL
files**, compiled together with the C backend, in default GC and `-gc none`.
The public JavaScriptCore bindings pass **150 functions from 132 files** using
single-unit FastC in both GC modes. Both execute real native contexts and GPU
results; compile-only audits receive no runtime credit.

Before removing ANGLE dispatch, the shared shader corpus passed both services:
40 acceptance/error/source-query cases and eight exact 8×8 pixel fixtures, in
both GC modes. Boolean/structured uniforms, ESSL100 MRT, float filtering and
RGB alpha checks also passed both services. The earlier full ANGLE native
reference suite passed 161 files in both GC modes. Later Metal-only resource
cases are not described as ANGLE comparisons.

The native resource suite covers nine fixtures in ARC, manual reference
counting and ASan/UBSan modes (27 fixture/mode runs). Its V tests exercise exact
pixels, bounds, ownership and GPU resource lifetime in both GC modes. Run from
the canonical checkout, with current V:

```sh
python3 tools/test_webgl_metal.py --v-bin ~/code/v/v --output Build/metal-resources-UNIQUE
python3 tools/test_webgl_metal_service.py --output Build/metal-service-UNIQUE --batch webgl/*_test.v
python3 tools/test_webgl_metal_service.py --backend fastc --output Build/metal-public-UNIQUE --batch browserjs/canvas_webgl*_test.v
```

The runners pin inputs and apply the repository compilation/runtime memory
guards. FastC aggregation stays temporarily beside the canonical tests, groups
conflicting import aliases separately and uses `VJOBS=1` so native state has
one definition. No sources or browser bundles are copied into job directories.

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
