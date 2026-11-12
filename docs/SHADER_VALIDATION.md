# V shader compilation

The default macOS WebGL service compiles ESSL 100/300 directly to Metal through
`webgl/shader`. Preprocessing, interface linking, uniform layout, resource
reflection and transform-feedback layout run in V. The native bridge only owns
Metal objects, compiles the generated MSL with Apple's Metal compiler, and
submits GPU work. There is no glslang, SPIR-V or SPIRV-Cross translation path,
dynamic compiler loader, or compiler-library dependency.

`compileShader` translates and compiles the individual stage with Metal;
`linkProgram` links the original interfaces and builds the two Metal functions.
Errors reach the existing status and info-log APIs. Source queries retain the
original ESSL bytes. The C conformance fixtures call the same V compiler through
an exported ABI, rather than a separate native translator.

Linux and Windows use the shared V preprocessor and WebGL version/loop checks,
then submit unchanged ESSL to their native GLES driver for syntax and type
checking. Metal remains the macOS graphics backend. None of these paths requires
the former glslang package.

## Covered behavior

- Bounded preprocessing with object/function macros, hide-set rescanning,
  conditional directives, integer expressions and known extension gates.
- ESSL 100/300 entry points, attributes and explicit locations, matrix varyings,
  flat integer interpolation, fragment builtins, depth, discard and MRT.
- Scalar/vector/matrix uniforms, literal arrays, nested named structures and
  anonymous std140 blocks, with V-generated offsets and 32-bit boolean storage.
- 2D/cube/3D/array textures, integer 2D textures, legacy and modern sample,
  projection, LOD, gradient, fetch and size wrappers.
- GPU transform feedback with tight scalar-word records, matrix columns,
  original clip position and guarded output capacity.
- Local literal-size arrays and ESSL300 array constructors.
- Conservative pruning of unused attribute, plain-uniform and sampler roots.

The original shared corpus keeps all 40 acceptance/error cases and eight exact
8×8 texture fixtures. Additional tests exercise exact GPU pixels, uniform/block
writes, capture canaries, texture layers, MRT, depth and disabled extensions.
Native ARC, manual-retain and ASan/UBSan fixtures check the exported ABI and
verify that compiler libraries and ANGLE remain unloaded after shader submission.

## Limits

This is a supported ESSL subset, not complete WebGL shader conformance. Metal
checks emitted expression syntax and types; its type rules do not establish
complete ESSL semantic equivalence. Appendix A indexing/loop mutation validation,
scoped call-graph liveness, sampler arrays and comparison samplers, named block
instances, general constant-expression array lengths, some builtins/control
flow and complete preprocessing remain pending. Unsupported constructs report
errors; they do not fall back to the removed compiler libraries.

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
