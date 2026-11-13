# V shader compilation

The default macOS WebGL service compiles ESSL 100/300 directly to Metal through
`webgl/shader`. Preprocessing, interface linking, uniform layout, resource
reflection and transform-feedback layout run in V. The native bridge only owns
Metal objects, compiles the generated MSL with Apple's Metal compiler, and
submits GPU work. There is no glslang, SPIR-V or SPIRV-Cross translation path,
dynamic compiler loader, or compiler-library dependency.

`compileShader` translates and compiles the individual stage with Metal;
`linkProgram` links the original interfaces and builds the two Metal functions. Full-source validation also checks unreachable helpers before
resource pruning.
Errors reach the existing status and info-log APIs. Source queries retain the
original ESSL bytes. The C conformance fixtures call the same V compiler through
an exported ABI, rather than a separate native translator.

Linux and Windows use the shared V preprocessor, scope and expression checks,
then submit unchanged ESSL to their native GLES driver for syntax and type
checking. Metal remains the macOS graphics backend. None of these paths requires
the former glslang package.

## Covered behavior

- Bounded preprocessing with object/function macros, hide-set rescanning,
  conditional and ternary expressions, line/file macros, line directives,
  pragmas and known extension gates.
- ESSL 100/300 entry points, attributes and explicit locations, matrix varyings,
  flat integer interpolation, fragment builtins, depth, discard and MRT.
- Scalar/vector/matrix uniforms, constant-expression array bounds, nested
  structures and named/anonymous uniform blocks, including block arrays and
  row/column-major std140 matrices. V owns offsets and 32-bit boolean storage.
- 2D/cube/3D/array and integer texture types, sampler arrays, comparison
  samplers, projection, LOD, gradient, offset, fetch and size wrappers. Native
  Metal 2.4 compilation supports explicit shadow mip levels and derivatives.
- GPU transform feedback with tight scalar-word records, matrix columns,
  original clip position and guarded output capacity.
- Local constant-size arrays, array constructors/lengths, function value
  parameters and deferred output copies, and ES300 while/do/switch control flow.
- Scalar/vector expression checking, read-only variables, boolean conditions,
  overload resolution, recursive-call rejection and scoped Appendix A loop and
  index checks. Parenthesized output/write operands retain their protections.
- Reachable-function and overload analysis for attributes, plain uniforms and
  samplers, with a separate full-source Metal validation pass.
- GLSL vector/matrix equality and logical-XOR precedence, numeric/bit/packing
  builtins, matrix component multiplication, outer products, determinants and
  inverses. Invariant position declarations and pragmas reach Metal attributes.

The original shared corpus keeps all 40 acceptance/error cases and eight exact
8×8 texture fixtures. Additional tests exercise exact GPU pixels, uniform/block
writes, capture canaries, texture layers, MRT, depth and disabled extensions.
Native ARC, manual-retain and ASan/UBSan fixtures check the exported ABI and
verify that compiler libraries and ANGLE remain unloaded after shader submission.

## Validation coverage

The former missing language categories above now have focused V checks and GPU
fixtures. V validates source types and bindings before lowering constructs whose
ESSL semantics differ from Metal, including equality, parameter copies and
constant expressions. Metal validates the complete generated program, including
helpers removed from the executable path. Original source queries keep ESSL.

This does not establish exhaustive WebGL/ESSL conformance. Type inference keeps
unresolved cases conservative, and unsupported constructs still report errors.
The source, nesting, expansion and device-resource budgets remain intentional.
No removed compiler library is used as a fallback. The language references are
[Khronos ESSL 1.00](https://registry.khronos.org/OpenGL/specs/es/2.0/GLSL_ES_Specification_1.00.pdf)
and [ESSL 3.00](https://registry.khronos.org/OpenGL/specs/es/3.0/GLSL_ES_Specification_3.00.pdf).

## Running checks

```sh
python3 tools/test_webgl_metal.py --output Build/metal-UNIQUE
python3 tools/test_webgl_metal_service.py --batch --output Build/service-UNIQUE \
  webgl/native_essl_equivalence_test.v webgl/native_compressed_texture_test.v
python3 tools/test_webgl_gles.py --v-bin "$V_BIN" --output Build/gles-UNIQUE
```

The Metal runner includes every V Metal test in default GC and `-gc none`.
Run the portable `webgl/shader/*_test.v` tests with current V in both modes as
well. All runners retain compiler/runtime exits and memory-guard receipts;
remove per-job Build output when finished. See the
[migration report](WEBGL_METAL_MIGRATION.md) for historical backend comparisons.
