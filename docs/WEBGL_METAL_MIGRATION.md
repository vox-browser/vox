# Direct Metal WebGL migration

The target is a macOS WebGL implementation that submits directly to Metal,
without ANGLE or desktop OpenGL. The migration starts with an independently
usable V resource backend in `webgl.metal`; it is not yet a replacement for
`WebGLRenderingContext` and is not selected by the browser.

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

## Validation

On 2026-11-12, native GPU tests passed with ARC, manual reference counting and
address/undefined-behavior sanitizers. They cover zero initialization, exact
clears, asymmetric row uploads/readbacks, destination guards, short transfers,
rejected resize, separate contexts and repeated create/destroy. Three focused
V cases pass with default GC and `-gc none`.

```sh
python3 tools/test_webgl_metal.py --output Build/metal-test-UNIQUE
```

Run focused V tests with current V's C backend, `-memory-limit 10G` and the
repository memory guard. The [local evidence](performance/metal-webgl-start-20261112.json)
retains commands, input hashes, actual exits and the initial fixture correction.

## Next implementation slices

1. Define V backend dispatch/capability records and connect these resources to
   the existing canvas owner and painting-surface lifecycle.
2. Add initialized buffers/textures and framebuffer/depth/stencil ownership.
3. Translate validated ESSL into MSL without ANGLE, then implement reflection,
   vertex layouts, uniform bindings and cached Metal render pipelines.
4. Implement indexed/instanced drawing, raster/blend/depth/stencil state,
   queries, synchronization and WebGL2 resource operations.
5. Run typed/public WebGL regression suites and matched browser/site checks.
   Switch the macOS default only after the replacement covers those contracts;
   then remove ANGLE loading, dependencies and obsolete service code.

The current production browser continues to use ANGLE's Metal backend during
these slices. PR #63's CGL backend is a separate OpenGL prototype and is not the
implementation of this direct Metal migration.
