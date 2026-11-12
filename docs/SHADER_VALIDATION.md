# Native WebGL shader validation

On macOS, the default V Metal service validates original ESSL with glslang,
links the pair, lowers through SPIR-V and SPIRV-Cross MSL, and compiles actual
Metal functions. It retains ESSL version/precision checks and the WebGL1
statically bounded loop/index subset. Invalid ESSL reports failure through
`compileShader` and its info log. Public shader-source queries preserve the
original bytes.

Install `glslang spirv-cross` with Homebrew. Shader compiler libraries load on
the first shader submission; they stay out of startup for pages that do not
compile WebGL shaders. The macOS browser does not load ANGLE/EGL/GLES. Other
platforms retain their GLES service.

ESSL100 texture calls use private wrapper functions before user globals. This
preserves legal sampler names such as `texture`, `textureProj` and `textureLod`,
including macros, overloads, projected lookups and biases. The supported
`GL_EXT_draw_buffers : require` directive is normalized for glslang's validator,
which recognizes the builtins without advertising the extension. Other required
extensions retain their normal validation; actual MRT pixels are tested.

The shared V corpus covers 40 acceptance/error/source-query cases and eight
exact 8×8 rendering fixtures. Before ANGLE removal, every case passed both the
ANGLE and direct Metal services in default GC and `-gc none`. Run the current
Metal corpus with:

```sh
python3 tools/test_webgl_metal_service.py --output Build/shaders-metal-UNIQUE webgl/native_essl_equivalence_test.v
```

The [migration report](WEBGL_METAL_MIGRATION.md) records additional boolean and
structured uniform, packed vertex, MRT, texture and transform-feedback checks.
The old PR #63 CGL adapter and its C comparison runner have been removed after
porting the full shader corpus to V. Their historical results remain in the
[local PR evidence](performance/pr63-shader-equivalence-20261112.json).
These focused checks do not establish complete WebGL conformance or whole-site
equivalence.
