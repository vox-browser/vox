# Direct Metal WebGL migration

The target is a macOS WebGL implementation that submits directly to Metal,
without ANGLE or desktop OpenGL. The migration starts with an independently
usable V resource backend in `webgl.metal`. An experimental V service now
connects part of `WebGLRenderingContext` through `-d vox_direct_metal` on macOS.
The production browser still selects ANGLE until the replacement is complete.

## Completed: drawing-buffer resources

`metal.DrawingBuffer.create(width, height)` owns a Metal device, command queue
and private RGBA8 render-target texture. The V object controls dimensions,
clear-color normalization, upload lengths and lifetime. Its native bridge only
allocates resources, encodes GPU operations and transfers completed pixels.

- Creation and changed-size allocations clear the entire texture to transparent
  black before making it observable. Same-size resize preserves its pixels.
- Failed resize preserves the old texture and dimensions.
- Clears use a Metal render pass. Upload and readback use blit encoders and
  shared staging buffers, with checked capacities and aligned row pitches.
- Transfers expose tightly packed, top-row-first, straight-alpha RGBA8.
  The future WebGL adapter must handle WebGL coordinates, masks/scissors and
  painting-surface alpha conversion in V.
- Operations wait for GPU completion and report submission failures. This first
  slice is synchronous and provides no scrolling or throughput claim.
- `close()` is idempotent. A drawing buffer is confined to its owning thread;
  callers must not access it concurrently or copy its native handle.

The package imports no EGL/GLES service and links only Metal and system
frameworks. Its native checks verify that ANGLE libraries remain unloaded.

## Completed: shader compilation and reflection

`metal.ShaderProgram.compile` validates and links the original ESSL pair with
glslang, lowers it to SPIR-V, translates it to MSL with SPIRV-Cross, and creates
actual Metal vertex/fragment functions. This path supports ESSL 1.00 and 3.00;
it preserves original shader link errors and public resource names even when
MSL requires renamed identifiers. Plain uniforms use separate stage blocks;
reflection includes their offsets, array/matrix strides, types and Metal slots.
Shader lowering requests GL depth and Y-coordinate conversion. Pixel tests must
establish those conventions before browser dispatch is changed.

On macOS this package requires `brew install glslang spirv-cross`. The generated
MSL uses safe math and initialized locals. The native ARC/MRC/sanitizer suite
compiles real Metal functions and checks uniform/matrix/sampler reflection;
three V cases pass with default GC and `-gc none`. No ANGLE library is loaded.
Apple's shader compiler can indirectly load system OpenGL framework images;
this package calls no OpenGL API and has no direct OpenGL dependency.

## Completed: buffers and array/instanced drawing

`metal.GPUBuffer` allocates zeroed shared GPU storage and bounds every CPU
read/write. `DrawingBuffer.draw` validates stream ownership, locations, strides,
divisors and complete vertex/instance ranges before native encoding. It builds
Metal vertex descriptors and render pipelines, uploads reflected float/vector/
matrix/array uniforms with their actual padding, and submits array/instanced
primitives. Missing resource bindings and out-of-range draws fail explicitly.

Native ARC/MRC/sanitizer checks and three focused V cases in both GC modes pass.
Exact 8x8 pixels cover matrix/color uniforms and instanced streams; an asymmetric
`gl_FragCoord.y` test establishes raw WebGL row orientation. This slice is
synchronous and compiles a pipeline per draw. Textures, render state and browser
dispatch are still pending; these tests do not establish complete WebGL parity.

## Completed: RGBA8 textures, samplers and color targets

Private 2D textures are initialized before use, accept exact bounded RGBA8
uploads, and support nearest/linear filtering plus clamp/repeat/mirror wrapping.
Draw bindings use preserved ESSL sampler names and the reflected stage/Metal
slots. A texture can be the offscreen color target, then be sampled in a later
draw. Closed/foreign bindings and read/write feedback loops fail before drawing.
These are base-level RGBA8 resources; mipmaps, other formats, cube/3D/array
textures, multiple attachments and depth/stencil remain migration work.

Three V cases pass in both GC modes, with exact quadrant/wrap, interpolated
center-sample, offscreen readback and feedback-loop checks. Native GPU sampling
also passes ARC, MRC and ASan/UBSan with no ANGLE image loaded.

## Completed: indexed draws and render state

Indexed drawing validates the complete index and referenced vertex ranges.
Byte indices expand to Metal's 16-bit format; WebGL1 non-restarting ushort
indices expand to 32-bit so index 65535 remains a vertex. Fixed restart markers
are preserved for WebGL2 strips. Non-restarting uint32 index `0xffffffff` is
explicitly unsupported by this low-level slice.

Viewport, clipped scissor, color masks, separate blending, culling, depth-range,
depth comparison/writes and separate front/back stencil state reach Metal.
Depth32Float/Stencil8 textures initialize to depth 1/stencil 0. Clip-Y conversion
also reverses Metal front-face winding, preserving culling, `gl_FrontFacing`
and the selected stencil face. Polygon depth bias is encoded; its cross-driver
numerical equivalence still needs coverage.

Six focused V cases pass in both GC modes. Exact pixels cover indexed quads,
ushort maximum indices, restart strips, viewport/scissor/masks/blending, depth
ordering/write masks, culling and independent stencil faces. Native ARC/MRC/
sanitizer checks exercise the index path and initialized depth/stencil state.
Browser dispatch, masked clears, additional texture formats/targets, queries,
transform feedback and complete WebGL2 coverage are still pending.

## Completed: typed and constant vertex fetch

Vertex streams now describe float/half, signed/unsigned byte/short/int formats,
byte/short normalization, integer shader inputs and constant attributes.
Aligned Metal buffer bases plus descriptor offsets preserve byte-aligned input
slices. Integer input signedness/type mismatches are rejected before drawing.
Normalized 32-bit integer conversion and packed 10:10:10:2 formats remain work.

Exact pixels verify normalized bytes at an unaligned base, constant float and
integer attributes, half vertices, and missing vec4 components defaulting to
zero/one. The complete standalone suite passes: six native fixtures in ARC,
MRC and ASan/UBSan modes, and 21 V cases across seven files in both GC modes.

## Completed: typed uniforms and uniform-buffer ranges

Uniform storage now supports signed/unsigned 32-bit values, boolean encoding,
tightly packed readback, padded arrays and non-square/small matrices. Raw block
updates use reflected offsets. Draws can override reflected blocks with external
GPU-buffer ranges, validating the owner, length, alignment and duplicate/unknown
slots. The low-level boolean setter accepts Vulkan's lowered uint storage;
original WebGL uniform API type validation belongs to browser dispatch.

Three more V cases pass in both GC modes: matrix/vec3-array roundtrips, signed/
unsigned/boolean rendering and external UBO/internal block writes. The complete
standalone run passes 24 V cases in both GC modes plus the six native fixtures
under ARC, MRC and sanitizers. This is backend coverage, not browser equivalence.

## Completed: attribute locations and active shader resources

Explicit attribute bindings now reserve complete matrix/array location spans;
automatic inputs avoid those slots. ESSL 3.00 `layout(location=...)` takes
precedence. Reflection excludes inactive inputs, samplers and synthetic plain
uniform members, while retaining declared block layout offsets. Original block
type names are preserved even when SPIR-V's block instance is unnamed.

Three focused cases verify inactive resources, explicit-location precedence,
collisions and a bound mat4 rendered through four constant vertex columns.
The complete standalone suite passes 27 V cases in both GC modes and all six
native fixtures in ARC/MRC/sanitizer modes. Full GLSL active-uniform array sizing
and structured-uniform reflection still require browser conformance coverage.

## Validation

Framebuffer blits now copy color through Metal and preserve depth/stencil
aspects through checked transfers. Four public-context cases pass in both GC
modes, covering multisample resolve, MRT, depth/stencil preservation, scaled
copies, scissor and rejection paths. Multisample draw destinations and changed
resolve bounds are rejected according to the [GLES 3 blit contract](https://github.com/KhronosGroup/OpenGL-Refpages/blob/main/es3.0/glBlitFramebuffer.xml).
The separate per-sample transfer experiment was tested and removed because that
operation is outside this WebGL contract; its evidence remains local.

WebGL texture bindings, pixel uploads/subimages, immutable storage, layer
selection, copies and mip generation now use the V service. Sampling assembles
complete GPU mip/cube/array images, validates sampler types and feedback, and
uses independent sampler objects. Color framebuffer/renderbuffer ownership,
MRT draws, indexed clears, typed readback and PBO packing are connected.
Ten focused public-context cases pass in both GC modes, including signed/
unsigned 32-bit clears/readback and unclamped float attachment values. The
standalone suite passes 34 V cases per mode and all 18 native fixture/mode runs;
native coverage now includes real MRT outputs and visibility buffers.
Depth/stencil user attachments, compressed uploads, blits, queries and transform
feedback remain unfinished in the service.

Metal sampler objects now preserve independent filtering, mip/LOD, wrap,
comparison and anisotropy state. One draw can bind a texture through different
samplers. The V service creates, binds, queries and deletes sampler records and
advertises its implemented anisotropy support. Four focused cases pass in both
GC modes, with exact mixed nearest/linear and clamped-mip pixels; all six native
fixtures also pass ARC/MRC/sanitizer checks.

The resource layer now allocates mipmapped 2D/cube/array/3D textures, normalized,
floating-point and integer formats, depth/stencil storage and supported
multisample color storage. Checked region transfers preserve physical values;
render attachments select a mip level, cube/array slice or 3D depth plane.
Four new V cases pass in both GC modes, including exact integer sampling,
volume/array/cube sampling, mip generation, isolated slice rendering and actual
depth/sample-count allocations. Native texture tests also exercise volume
attachments and depth allocation in ARC, MRC and ASan/UBSan modes; all six
native fixtures pass in all three modes. Combined depth/stencil CPU transfers
and multisample resolves still need service integration.

The direct service now implements sync fences and uniform-block dispatch.
Fences follow the synchronous command-completion boundary, preserve context
ownership and reject stale/deleted handles. Uniform indices, block names,
layout queries and stage references use Metal shader reflection. Indexed UBO
bindings track allocation changes, validate ranges at draw time and detach on
deletion. Device sample-count queries report Metal's supported counts.
The existing sync and uniform-block suites plus two new ownership/range cases
pass in both GC modes (six cases per mode), including exact GPU pixels from a
UBO bound at byte offset 256.

The experimental service passes 15 focused WebGL cases in each of default GC
and `-gc none`: six new context/buffer/draw/readback cases and the existing shader
(3), uniform (1), base-draw (2), integer-attribute (1), viewport/scissor (2) cases.
They compile with current V's C backend and run under the 3 GiB memory guard.
The new cases assert that no EGL/GLES/ANGLE library is loaded. Signed native
buffers use V `i32`; public `[]int` inputs are packed at the native boundary.

Five public JavaScript binding files also pass against the existing ANGLE
backend with single-unit FastC. Compile audits covered 107 WebGL and 92 public
binding files. These are separate results: the combined public runtime crashes
in the retained-query test, and the C backend's browser-binding compilation
hits the 12 GiB guard. FastC's multi-unit build also duplicates native dispatch
state; the focused passing runs used `VJOBS=1`. Neither compile audits nor these
focused results establish complete browser or optimized-site equivalence.

The [local migration evidence](performance/metal-webgl-migration-20261112.json)
retains commands, hashes, guard exits and failed diagnostics.

On 2026-11-12, native GPU tests passed with ARC, manual reference counting and
address/undefined-behavior sanitizers. They cover zero initialization, exact
clears, asymmetric row uploads/readbacks, destination guards, short transfers,
rejected resize, separate contexts and repeated create/destroy. Three focused
V cases pass with default GC and `-gc none`.

```sh
python3 tools/test_webgl_metal.py --v-bin ~/code/v/v --output Build/metal-test-UNIQUE
```

Run focused V tests with current V's C backend, `-memory-limit 10G` and the
repository memory guard. The [local evidence](performance/metal-webgl-start-20261112.json)
retains commands, input hashes, actual exits and the initial fixture correction.

Occlusion queries now use Metal visibility-result buffers. Visible draws return
true, while fragment discard, zero scissor and depth-occluded draws return
false. Query target ownership, availability, empty draws and invalid operations
pass the existing query suite and the focused visibility case with default GC
and `-gc none` under the memory guard. Transform-feedback primitive queries
share this lifecycle; their capture path is still pending.

S3TC compressed image/subimage entry points now decode BC1, BC2 and BC3 in V
and upload initialized RGBA8 Metal storage. They retain logical compressed
formats, enforce block alignment/byte counts and PBO bounds, and support 2D,
cube faces, array layers and immutable mip storage. Compressed textures remain
non-renderable. Two existing GPU sampling cases and two new format/validation
cases pass with default GC and `-gc none`; there is no ANGLE fallback.

The Metal resource backend now captures vertex outputs through a separate
non-rasterizing MSL function. Metal pipeline reflection supplies structure,
array and matrix offsets; no host-side shader simulation is used. Native
capture tests pass with ARC, MRC and ASan/UBSan, alongside the other six native
fixtures. The V capture case passes with default GC and `-gc none`, preserving
nonzero vertex IDs, instance order, matrices and unmodified clip coordinates.
Connecting this resource operation to the WebGL transform-feedback lifecycle
is the next slice.

## Next implementation slices

The experimental V service now owns context/resource records, the painting
surface, errors and state queries, initialized buffers, shader/program lifetime
and reflection, typed uniforms, vertex arrays and attributes. It submits array,
indexed and instanced draws with raster/blend/depth/stencil state and packed
RGBA8 readback. Line loops and triangle fans expand to equivalent index lists.
Unsupported entry points explicitly report `INVALID_OPERATION`; there is no
ANGLE fallback. This is an incomplete backend behind a compile-time flag.

1. Connect texture/sampler and user-framebuffer ownership, uploads and draws.
   Extend the resource backend beyond base-level RGBA8 2D textures.
2. Complete uniform blocks, shader type/reflection edge cases, packed vertex
   formats and overlapping strides; cache render pipelines.
3. Add queries, synchronization, transform feedback, multisampling, multiple
   draw buffers and remaining WebGL2 operations.
4. Resolve browser-suite compilation/runtime blockers and extend conformance.
5. Run typed/public WebGL regression suites and matched browser/site checks.
   Switch the macOS default only after the replacement covers those contracts;
   then remove ANGLE loading, dependencies and obsolete service code.

The current production browser continues to use ANGLE's Metal backend during
these slices. PR #63's CGL backend is a separate OpenGL prototype and is not the
implementation of this direct Metal migration.
