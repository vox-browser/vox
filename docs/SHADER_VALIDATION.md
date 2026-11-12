# Native WebGL shader validation

The desktop shader adapter validates original ESSL with glslang before changing
its spelling for the OpenGL driver. This retains ESSL version and precision
checks and the WebGL1 statically bounded loop/index subset. The validator uses
the current driver's uniform, varying, attribute and texture-unit limits.

Install `glslang` with Homebrew on macOS, `glslang-dev` on Ubuntu/Debian, or
`mingw-w64-x86_64-glslang` in the Windows MSYS2 environment. The C interface and
default-resource-limits library are required; SPIR-V generation is not used.
The normal macOS packaging dependency closure includes the validator libraries.
macOS loads the validator on the first shader submission, keeping its libraries
out of startup for pages that do not compile WebGL shaders.

ESSL100 texture calls use private wrapper functions declared before user globals.
This preserves legal sampler names such as `texture`, `textureProj` and
`textureLod`, including macros, function overloads, projected lookups and biases.
Public shader-source queries retain the original source bytes. Invalid ESSL
still reports failure through `compileShader` and its info log.

The 40 acceptance cases and eight exact-pixel fixtures now also run through
both V WebGL services, including the experimental direct Metal implementation:

```sh
python3 tools/test_webgl_metal_service.py --output Build/shaders-metal-UNIQUE webgl/native_essl_equivalence_test.v
python3 tools/test_webgl_metal_service.py --service angle --output Build/shaders-angle-UNIQUE webgl/native_essl_equivalence_test.v
```

Both services pass all 48 fixtures in default GC and `-gc none`. Metal submits
the translated shaders to actual MTLFunctions. The earlier CGL comparison below
is retained as historical PR #63 evidence.

Run the native shader comparison from the canonical checkout:

```sh
python3 webgl/shader_equivalence_test.py --candidate-ref PR_HEAD --output Build/shader-check-UNIQUE
```

The runner checks the exact PR native service headers with the current canonical
shader adapter, using a compiler virtual filesystem overlay. It compares fresh
ANGLE and Apple OpenGL contexts for shader acceptance, original source queries
and exact drawing-buffer pixels. It pins its inputs and runs compilation and
execution under the repository memory guard. This is a focused backend check;
it does not establish complete WebGL conformance or whole-site equivalence.

On 2026-11-12, all 40 shader cases and eight 8×8 RGBA rendering cases match
ANGLE exactly, including source queries and GL errors. Eight focused V cases
also pass in each of Boehm and no-GC mode: ESSL validation, existing ANGLE
shader behavior and transform feedback. The native service is exercised by the
separate C comparison. The [local evidence](performance/pr63-shader-equivalence-20261112.json)
retains source pins, commands, actual exits and earlier failed diagnostics.
