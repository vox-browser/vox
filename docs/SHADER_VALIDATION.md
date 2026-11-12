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

## Direct V-to-Metal replacement in progress

`webgl/shader` is a dependency-free V source generator. The first slice lowers
ESSL 100/300 scalar/vector/matrix spellings, attributes, varyings, fragment
outputs, vertex/instance IDs and entry points directly to MSL. Its linker checks
varying names/types and matching ESSL versions. It generates the vertex Y and
depth conversions used by the Metal backend. Comments and numeric/operator
tokens are handled by a bounded lexer.

This is an experimental compiler slice, **not the production replacement yet**.
Unsupported declarations and directives fail with an error. Object and function
macros, undefinition, nested conditional branches, `defined`, integer conditions,
ESSL version selection and predefined ES/precision macros now run in V before
translation. Macro rescanning suppresses recursive expansion, with explicit
source, nesting, token and operation limits. Conditions short-circuit inactive
operands. Token pasting and stringification are rejected. Extension and line
directives, line-number builtins, ternary conditions and complete ESSL
preprocessor conformance remain pending. The compiler also still needs semantic
validation, textures, explicit interface locations, transform feedback, and the remaining
ESSL expressions/builtins and control flow. General expression syntax and type
checking currently depend on compiling the emitted MSL with Metal; successful
translation alone does not establish ESSL validity. The production service still
uses glslang and SPIRV-Cross until those paths and the existing WebGL corpus are
ported. Neither dependency has been removed.

Plain scalar, vector, square/non-square matrix and literal-length array uniforms
now have V-generated std140 offsets, matrix/array strides and storage type
reflection. Each stage uses buffer slot zero; generated MSL decodes individual
32-bit scalars and copies them into shader state. This preserves packed vec3
plus scalar fields, 32-bit boolean storage, and padded matrix/array elements
without depending on Metal structure packing. Shared stage uniforms must have
matching types and array shapes. Struct uniforms, uniform blocks, constant
expression array lengths, active-uniform analysis and uniform write restrictions
remain pending. Declared uniforms are currently reflected, including unused ones.

Validation for this slice: all four test files pass with the C backend in
default GC and `-gc none`. The macOS test compiles the V-generated vertex and fragment
sources (including macro/conditional and uniform variants) with Metal, links a render
pipeline, draws a full-target triangle, and
checks all sixteen RGBA pixels exactly. The uniform case binds both stage
buffers, poisons padding bytes, checks scalar/vector/matrix/array/boolean decoding,
and changes a consumed boolean to prove that the buffer influences the pixels. It also verifies that neither glslang
nor SPIRV-Cross is loaded in the test process. The Objective-C test endpoint only
submits generated MSL to Metal; all translation is V. Run under the memory guard
with `VJOBS=1 v -b c -memory-limit 10G test webgl/shader` (and `-gc none`).
