# WebGL module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebGL`

Audited: 2026-09-12

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
| `WebGL/` | 42 | 7,846 | 6,205 | 1,470 | Portable state and remote transport audited; native backend pending |

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

## Platform boundaries

- EGL/OpenGL ES, ANGLE, Skia, IOSurface, Vulkan image, DMA-BUF, and native
  painting-surface work stays behind `OpenGLContext`. The V implementation
  records ordered typed dispatches and owns the Web-observable state around it.
- Native GLSL compilation/reflection and GPU pixel conversion remain backend
  operations. Source retention, attachment/link eligibility, program/location
  identity, WebIDL slices, format enablement, error precedence, and resource
  lifetime are implemented before dispatch.
- WebIDL typed arrays are represented by owned V byte/numeric slices. Offset and
  length checks use borrowed slices like upstream `Span`, avoiding generated
  full-slice copies. Overlap-safe buffer copies and detached/foreign-object
  failure behavior are deterministic and tested. Vertex attribute pointer
  state and program/shader/buffer parameter switches retain distinct GL state
  instead of returning one fabricated value for every `pname`.
- The standalone `OpenGLContext` does not claim EGL/ANGLE parity. It records
  native calls only when the test/debug hook is explicitly enabled, avoiding an
  unbounded allocation and argument clone on every draw call in normal use.
  Framebuffer status, GLSL compilation/reflection, attribute/uniform locations,
  readback, and real painting surfaces still require the native backend.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test webgl
Summary for all V _test.v files: 21 passed, 21 total.

$ python3 tools/libweb_translation_audit.py
WebGL: 520 implementation symbols, 0 unmatched.

$ python3 tools/upstream_function_delta.py --base 1d025620e3344e3cc9aee26fe815d8675e4f9810 --head 963d46a829f3e1b79f44dba9d02afb70654300fa
WebGL: 0 unmatched changed symbols.

$ git diff --check -- webgl
(no output; exit status 0)
```
