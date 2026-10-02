# WebGL module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebGL`

Reference audit: 2026-09-12
Latest native focused verification: 2026-10-02

All 42 upstream `.cpp` implementation units, 46 headers, and 37 WebIDL files
were audited. The package implements the renderer-independent WebGL 1/2 model:
context attributes and loss, drawing-buffer lifecycle, first-error retention,
context-bound resource ownership, buffer target compatibility and byte ranges,
shader/program/link state, uniform ownership, extension filtering/caching,
compressed formats, WebGL2 queries/samplers/sync/transform-feedback/VAOs,
instanced drawing, checked BufferSource offsets, timestamped context events,
framebuffer attachments, remote-context restoration, aligned command encoding,
shared-buffer batching, bitmap uploads, readback, and synchronous proxy queries.
The complete 53-entry upstream extension registry is retained, including
experimental entries whose factories are not implemented; those names are
filtered by version/native support and correctly remain non-instantiable.

| Upstream area | `.cpp` files | Upstream `.cpp` LOC | V implementation LOC | V test LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `WebGL/` | 42 | 7,846 | 6,205 | 1,470 | Source mapping retained; native direct backend connected; remote transport open |

The associated declarations comprise 46 headers / 2,473 LOC and 37 IDL files /
1,403 LOC. Mapping completeness is 42/42 implementation units, 46/46 headers,
and 37/37 IDL definitions audited.

## Implementation-unit mapping

| Upstream implementation | V implementation |
| --- | --- |
| `EventNames.cpp`, `WebGLContextAttributes.cpp`, `WebGLContextEvent.cpp`, `WebGLActiveInfo.cpp`, `WebGLShaderPrecisionFormat.cpp` | `types.v` |
| `WebGLObject.cpp`, `WebGLBuffer.cpp`, `WebGLFramebuffer.cpp`, `WebGLProgram.cpp`, `WebGLQuery.cpp`, `WebGLRenderbuffer.cpp`, `WebGLSampler.cpp`, `WebGLShader.cpp`, `WebGLSync.cpp`, `WebGLTexture.cpp`, `WebGLTransformFeedback.cpp`, `WebGLUniformLocation.cpp`, `WebGLVertexArrayObject.cpp` | `objects.v`, `object_factories.v`, owning context file |
| `TextureUpload.cpp` | `texture_upload.v` |
| `WebGLCommandList.cpp` | `command_list.v` |
| `WebGLContextProxyBase.cpp` | `context_proxy.v`, `shared_command_buffer.v` |
| `WebGLRenderingContext.cpp`, `WebGLRenderingContextBase.cpp`, `WebGLRenderingContextImpl.cpp`, `WebGLRenderingContextOverloads.cpp` | `buffer_source.v`, `context.v`, `context_operations.v`, `extensions.v`, `native_context.v`, `overload_operations.v`, `remote_context.v`, `texture_image_source.v` |
| `WebGL2RenderingContext.cpp`, `WebGL2RenderingContextImpl.cpp`, `WebGL2RenderingContextOverloads.cpp` | `context2.v`, `context.v`, `context_operations.v`, `native_context.v`, `overload_operations.v` |
| `Extensions/ANGLEInstancedArrays.cpp`, `EXTBlendMinMax.cpp`, `EXTColorBufferFloat.cpp`, `EXTRenderSnorm.cpp`, `EXTTextureFilterAnisotropic.cpp`, `EXTTextureNorm16.cpp`, `OESElementIndexUint.cpp`, `OESStandardDerivatives.cpp`, `OESVertexArrayObject.cpp`, `WebGLCompressedTextureS3tc.cpp`, `WebGLCompressedTextureS3tcSrgb.cpp`, `WebGLDebugRendererInfo.cpp`, `WebGLDrawBuffers.cpp`, `WebGLVertexArrayObjectOES.cpp` | `extensions.v`, `context2.v`, `objects.v` |

## Native backend and remaining work

`native_egl.h`/`native_egl.c.v` create real EGL/ANGLE contexts using the Metal
backend on macOS and the source compositor configuration. `pkg-config egl
glesv2` resolves those libraries. Context loss destroys the native namespace;
restoration creates a fresh context.

The direct backend executes the translated buffer/vertex commands, indexed and
instanced draws, raster state, shader compilation/linking/reflection, typed
uniforms, GPU queries, samplers, sync, vertex arrays, transform feedback,
uniform blocks, internal-format queries, 2D/3D/compressed textures, framebuffer
attachments, multisample allocation/blits, read/draw buffers, invalidation,
and robust readback. Object names, limits, extension support, framebuffer
completeness, compile/link status, and query results come from the driver.

`HTMLCanvasElement` creates that real context, preserves its identity, resizes
its drawing buffer, and presents native pixels through the retained canvas
surface registry. The JavaScriptCore host binding reaches those same objects
and native commands, including the ANGLE instancing, WEBGL draw-buffers, and OES
vertex-array extensions. Script-created canvases retain the same DOM owner
when inserted. Public bindings retain actual BufferSource brands, generated
fixed-length/shared backing-store restrictions, late detached witnesses,
element-count spans, destination views, and pixel-pack-buffer offsets before
actual execution. TexImageSource uploads use live canvas/image/video frames or
ImageData and translate the source Skia export, including flip, scaling,
color-space, and alpha conversion. ImageBitmap and OffscreenCanvas objects
still require complete script object bindings. The upstream OffscreenCanvas
WebGL getter itself remains explicitly unimplemented.

Material platform adaptations are explicit: painting uses CPU readback into the
retained bitmap instead of upstream IOSurface/Vulkan shared-image handoff;
ANGLE builds lacking compressed robust entry points use the matching GLES call
with its exact payload size; unsupported source Skia RGBA5551 export returns an
error instead of the upstream surface assertion; WebGL1 null texture allocation
above the V-array/GLsizei capacity reports OUT_OF_MEMORY instead of the upstream
MUST allocation failure. These do not establish remote compositor parity.

`context_proxy.v` still records transmitted batches in memory and consumes
fixture-supplied synchronous replies/readback. It has no real remote WebGL
transport/command processor. Its wait-success and next-reply fields therefore
remain audit gaps independently of the production direct native path.

Source TODOs remain visible. Upstream `get_uniform` returns zero with a FIXME;
its V cached-value model does not establish a translated native getter. Upstream
WebGL2 declarations below are explicitly `[FIXME]` at pinned commit
`963d46a829f3e1b79f44dba9d02afb70654300fa`, with no matching operation bodies in
`WebGL2RenderingContextImpl.{h,cpp}` or `WebGL2RenderingContextOverloads.{h,cpp}`.
They are upstream unavailable operations, distinct from remaining translation
work on implemented source bodies.

| Upstream unavailable operation | Source declaration under `Libraries/LibWeb/WebGL/` |
| --- | --- |
| Numeric PBO texImage2D / texSubImage2D | `WebGL2RenderingContextOverloads.idl:24`, `:31` |
| Numeric PBO compressedTexImage2D / compressedTexSubImage2D | `WebGL2RenderingContextOverloads.idl:37`, `:40` |
| Numeric PBO texImage3D / texSubImage3D | `WebGL2RenderingContextBase.idl:296`, `:304` |
| Numeric PBO compressedTexImage3D / compressedTexSubImage3D | `WebGL2RenderingContextBase.idl:313`, `:316` |
| copyTexSubImage3D / getFragDataLocation | `WebGL2RenderingContextBase.idl:311`, `:320` |
| isQuery / isSampler / isSync / isTransformFeedback | `WebGL2RenderingContextBase.idl:366`, `:375`, `:383`, `:392` |
| getSamplerParameter / getTransformFeedbackVarying / getIndexedParameter | `WebGL2RenderingContextBase.idl:379`, `:397`, `:404` |

The pinned binding generator excludes `[FIXME]` declarations from operation
overload sets (`Meta/Generators/libweb_bindings/overload_resolution.py:542-549`).
Wholly unimplemented operation names receive only the source unimplemented
property marker (`operations.py:185-203`); some V internal native getter helpers
do not imply completed public source operation bindings. Numeric pixel-unpack
texture overloads must not be confused with the implemented numeric pixel-pack
readPixels overload. Source reset_to_default_state bodies are empty in both
context classes and remain empty in the translation.

The compact public binding now applies that source `[FIXME]` exclusion before
overload resolution. Unsupported numeric unpack calls raise TypeError without
issuing an empty-byte native upload. Failed ambiguous resolution retains the
source "Overload resolution failed" diagnostic, while the supported numeric
bufferData overload still converts ordinary objects through ToNumber. Both
focused effective-overload cases and all three adjacent public host, nullable
texture, and source-span files pass with `-gc none`.

Uniform reflection now preserves the implemented source result distinctions
(`WebGL2RenderingContextImpl.cpp:1121-1193`): getUniformIndices returns null for
an invalid program, getActiveUniforms returns undefined for an invalid program,
and an empty uniform-index vector returns an empty Array after the native
query even when pname is unsupported. Native and local errors retain separate
source getError precedence. The old typed nonnullable index getter remains a
convenience adapter; public bindings use the new source nullable getter. New
native/public result-shape cases and the existing native uniform-block file
pass with `-gc none`.

Actual WebGL buffer/view and exact typed-list argument conversion now uses
captured engine internal-slot getters, ignoring author-shadowed buffer,
byteOffset, byteLength, BYTES_PER_ELEMENT, values, and iterator properties.
Buffer and typed-list snapshots happen after all argument conversions; ordinary
sequence snapshots remain eager. Destination writeback uses those same real
slots. The pinned generator disallows resizable backing stores without
AllowResizable and shared buffers without AllowShared
(`Meta/Generators/libweb_bindings/to_idl_value.py:1329-1445`): WebGL view
arguments are AllowShared, ordinary BufferSource and exact Float32/Int32/Uint32
list members are not, and no WebGL buffer argument is AllowResizable. Earlier
public RAB acceptance was therefore a translation error; typed witness helpers
retain the source operation-body rules independently of public IDL restrictions.

All three new slot/timing cases plus the six adjacent source-span, public host,
effective-overload, texture-source, pixel-pack, and nullable-texture files pass
with `-gc none`. They exercise mutation/detachment by later argument getters,
native buffer and rendered uniform results, view-property tampering, actual
DataView/typed destination writes, raw-buffer versus view brands, and optional
engine RAB/SAB exposure. This interop adaptation does not establish complete
LibJS builtin/prototype/WrapperWorld parity.

Float16Array views retain their two-byte element size, as declared by the
pinned `Libraries/LibWeb/WebIDL/Buffers.h:20-33` variant. The focused native host
test passed with Float16Array exposed by JavaScriptCore, checking offset/length
upload bytes and destination offsets without reading an author-shadowed
BYTES_PER_ELEMENT property.

Effective overload selection distinguishes raw ArrayBuffer from ArrayBufferView
using actual engine brands, matching `WebIDL/OverloadResolution.cpp:203-253`.
An ambiguous texImage2D call with a raw buffer now raises the source overload
resolution error before reading earlier numeric argument getters. The focused
effective-overload file passed with `-gc none`, including supported numeric
buffer allocation and nullable/typed-view texture uploads.

The browser continues to use JavaScriptCore. Compact wrappers and typed V
WebIDL values do not provide the unfinished LibJS VM's Promise/builtin object
graph or full WebIDL brand/prototype parity.

## Verification

All 44 current WebGL test files passed using direct
`v -old-compiler -enable-globals -path 'WORKTREE|@vlib|@vmodules' FILE_test.v`
invocations on 2026-10-02. Native tests use actual ANGLE/Metal results, including
compiled draws, framebuffer/layer/compressed texture pixels, synchronization,
query/reflection values, destination/PBO offsets, and nullable uploads. Focused
JavaScriptCore host tests also pass for typed span/resize/detach rules,
TexImageSource conversion, PBO readback, nullable textures, instanced extension
draws, separate draw-buffer attachment pixels, and owner identity. The counts
include existing state/proxy fixture tests and do not claim remote execution or
complete source/VM parity.
