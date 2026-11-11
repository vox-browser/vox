# Native WebGL graphics backend

Vox submits WebGL work directly to the operating system's OpenGL driver. It
does not load, link, install, or bundle ANGLE. The browser's existing V WebGL
objects, command owners, and CPU painting surfaces retain their service ABI.

## Platform requirements

| Platform | Context API | Required driver API | Build dependency |
| --- | --- | --- | --- |
| macOS | CGL | OpenGL 4.1 core | System OpenGL framework |
| Windows | WGL | OpenGL 4.3 core | System `opengl32`, GDI, and User32; MinGW OpenGL headers |
| Linux | EGL | Desktop OpenGL 4.3 core | System `egl` and `gl` pkg-config packages |

Linux requires EGL 1.5, or EGL 1.4 with `EGL_KHR_create_context`. It first tries
the driver's surfaceless platform and otherwise uses the default EGL display.
Each canvas has its own context and offscreen framebuffer. EGL display
references are balanced across canvases. Windows entry points are resolved
from the native WGL driver and `opengl32.dll` into a per-context table.

Context creation fails when the required API or entry points are unavailable;
there is no translation-library fallback. The Linux window renderer uses
GLX, so WebGL restores a borrowed window context at script, snapshot,
presentation, and browser-frame boundaries.

## WebGL compatibility

The shared adapter supplies behavior that is not implicit in desktop GL:

- It retains a private default framebuffer and vertex array and restores
  those objects when a bound user object is deleted.
- It checks client pixel-transfer bounds, index ranges, active vertex-array
  spans, and uniform-block buffer ranges before native access. Pixel-store
  offsets and row/image strides participate in the bounds calculation.
- It initializes new buffer, texture, and renderbuffer storage. Internal
  clears preserve the caller's clear values, masks, scissor, and rasterizer
  discard state. A failed internal texture initialization fails the context
  so partially initialized attachments cannot be accessed by later commands.
- It retains initialized attachments when receiving framebuffer-invalidation
  hints. Readback and texture copies clip source rectangles to framebuffer
  bounds rather than reading undefined native pixels.
- It supplies macOS's missing immutable texture-storage and internal-format
  sample-query operations. Immutable texture metadata is released with the
  owning texture or context.
- It maps WebGL1 instancing, vertex arrays, draw buffers, and other promoted
  capabilities to core driver entry points. `ANGLE_instanced_arrays` remains
  the web-standard JavaScript extension name; it does not require ANGLE.
- It uses desktop primitive restart only for WebGL2 indexed draws. WebGL1
  retains its valid maximum byte and short index values.

The desktop shader adapter translates the spelling of ESSL 1.00 and 3.00 into
GLSL 4.10. It handles stage interfaces, fragment outputs, texture function
names, precision declarations, and version macros while retaining original
ESSL for `getShaderSource()` and source-length queries. The native driver's
compiler performs parsing, type checking, and optimization.

This adapter is not a complete WebGL shader validator. Exhaustive ESSL
semantic restrictions, cross-stage ESSL version validation, and the complete
WebGL conformance contract still require further work. Removing ANGLE must
not be described as establishing WebGL conformance or equivalent shader
validation. Native macOS and Windows builds and runtime rendering also need
platform validation before release.

## Generated interfaces

After changing the native service entry points or their driver calls,
regenerate the checked-in interfaces:

```sh
python3 tools/generate_webgl_api.py
python3 tools/generate_native_gl_dispatch.py
```

The first generator keeps the Windows bridge separate from the window
renderer's GL declarations. The second emits only native core GL entry
points; EGL, GLX, WGL, and vendor extension entry points do not belong in
that table.

## API references

- [OpenGL 4.1 core specification](https://registry.khronos.org/OpenGL/specs/gl/glspec41.core.pdf)
- [GLSL 4.10 specification](https://registry.khronos.org/OpenGL/specs/gl/GLSLangSpec.4.10.pdf)
- [WebGL 1 specification](https://registry.khronos.org/webgl/specs/latest/1.0/)
- [WebGL 2 specification](https://registry.khronos.org/webgl/specs/latest/2.0/)
- [ARB texture storage](https://registry.khronos.org/OpenGL/extensions/ARB/ARB_texture_storage.txt)
