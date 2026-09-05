# WebGL module V translation — parity audit

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/WebGL`

Audited: 2026-09-04

All 39 upstream `.cpp` implementation units, 40 headers, and 36 WebIDL files
were audited. The package implements the renderer-independent WebGL 1/2 model:
context attributes and loss, drawing-buffer lifecycle, first-error retention,
context-bound resource ownership, buffer target compatibility and byte ranges,
shader/program/link state, uniform ownership, extension filtering/caching,
compressed formats, WebGL2 queries/samplers/sync/transform-feedback/VAOs,
instanced drawing, checked offsets, and ordered native command dispatch.
The complete 53-entry upstream extension registry is retained, including
experimental entries whose factories are not implemented; those names are
filtered by version/native support and correctly remain non-instantiable.

| Upstream area | `.cpp` files | Upstream `.cpp` LOC | V implementation LOC | V test LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `WebGL/` | 39 | 7,163 | 3,649 | 328 | Portable state audited; native backend pending |

The associated declarations comprise 40 headers / 1,834 LOC and 36 IDL files /
1,485 LOC. Mapping completeness is 39/39 implementation units, 40/40 headers,
and 36/36 IDL definitions audited.

## Implementation-unit mapping

| Upstream implementation | V implementation |
| --- | --- |
| `EventNames.cpp`, `WebGLContextAttributes.cpp`, `WebGLContextEvent.cpp`, `WebGLActiveInfo.cpp`, `WebGLShaderPrecisionFormat.cpp` | `types.v` |
| `OpenGLContext.cpp` | `native_context.v`, `native_context_operations.v` |
| `WebGLObject.cpp`, `WebGLBuffer.cpp`, `WebGLFramebuffer.cpp`, `WebGLProgram.cpp`, `WebGLQuery.cpp`, `WebGLRenderbuffer.cpp`, `WebGLSampler.cpp`, `WebGLShader.cpp`, `WebGLSync.cpp`, `WebGLTexture.cpp`, `WebGLTransformFeedback.cpp`, `WebGLUniformLocation.cpp`, `WebGLVertexArrayObject.cpp` | `objects.v`, `object_factories.v`, owning context file |
| `WebGLRenderingContext.cpp`, `WebGLRenderingContextBase.cpp`, `WebGLRenderingContextImpl.cpp`, `WebGLRenderingContextOverloads.cpp` | `context.v`, `context_operations.v`, `extensions.v`, `native_context.v`, `overload_operations.v` |
| `WebGL2RenderingContext.cpp`, `WebGL2RenderingContextImpl.cpp`, `WebGL2RenderingContextOverloads.cpp` | `context2.v`, `context.v`, `context_operations.v`, `native_context.v`, `overload_operations.v` |
| `Extensions/ANGLEInstancedArrays.cpp`, `EXTBlendMinMax.cpp`, `EXTColorBufferFloat.cpp`, `EXTRenderSnorm.cpp`, `EXTTextureFilterAnisotropic.cpp`, `EXTTextureNorm16.cpp`, `OESElementIndexUint.cpp`, `OESStandardDerivatives.cpp`, `OESVertexArrayObject.cpp`, `WebGLCompressedTextureS3tc.cpp`, `WebGLCompressedTextureS3tcSrgb.cpp`, `WebGLDrawBuffers.cpp`, `WebGLVertexArrayObjectOES.cpp` | `extensions.v`, `context2.v`, `objects.v` |

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
Summary for all V _test.v files: 5 passed, 5 total.

$ python3 tools/libweb_translation_audit.py
WebGL: 446 implementation symbols, 0 unmatched.

$ git diff --check -- webgl
(no output; exit status 0)
```
