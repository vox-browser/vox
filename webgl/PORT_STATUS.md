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
| `WebGL/` | 42 | 7,846 | 6,205 | 1,470 | Source mapping retained; native backend partially connected |

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

Native operation slices now include GPU fences, waits, sync parameters,
GLSL compilation, linking, logs, active attribute/uniform reflection,
locations, precision queries, typed scalar/vector/matrix uniform uploads,
framebuffers/renderbuffers/textures, framebuffer completeness, robust 2D
texture uploads, drawing-buffer allocation, clear/masks/scissor/viewport, and
robust readPixels. Logical WebGL object identities remain separate from real
native object names. Focused tests exercise actual compiler failures, varying
link failures, active/unused declarations, precise integer uniforms, array
locations, fractional framebuffer pixels, live texture subimages, framebuffer
incompleteness, resizing, and GPU sync validation/results.

Other dispatch paths, buffer/vertex draw execution, WebGL2 query/reflection
families, and painting-surface presentation still need native connection and
source review. The old state-only dispatches and source-symbol inventories do
not establish semantic parity. Native compilation/framebuffer success does not
close the remaining WebGL translation audit findings. Native calls are recorded
only when explicitly requested for tests/debugging.

The typed WebIDL boundary uses V byte/numeric slices. Browser runtime objects,
remote command consumption, and native compositor handoff require independent
end-to-end validation as their owning subsystems are connected.

## Verification

All 25 WebGL test files passed using direct
`v -old-compiler -enable-globals -path 'WORKTREE|@vlib|@vmodules' FILE_test.v`
invocations. Native shader, uniform, sync, and framebuffer tests use actual
ANGLE/Metal results. This test count describes completed focused slices and
existing state tests, not complete WebGL execution parity.
