# Frozen native batch at a85c3b92

Frozen canonical `a85c3b9224641a439e14b1d6131e9f8b80855a9f` against Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` passes production build, headless startup, nine targeted pixel-exact comparisons and all eleven configured smoke comparisons. All 4,671 tracked file contents, tracked status and HEAD stay identical throughout; the binary is hashed again after comparison.

| Check | Result | Seconds | Log SHA256 |
| --- | --- | ---: | --- |
| build | PASS | 766.114 | `e2fbbc071882d4a0088bee74c71485da5d1f231fc07d446152696e2a107cb597` |
| headless | PASS | 0.812 | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| targeted | 9/9 PASS | 82.207 | `4cc04fc721ce9101867034a4a69448a1d4f556b0b786da6b68741056221fe65f` |
| smoke | 11/11 PASS | 87.028 | `da5a20eadeb87c48da4dc2e599547f63ff161c4d1767089fd3b36c70458643b2` |

Commands and absolute input paths are retained verbatim in `Build/audit-fixes/source-native-referrer-simd-shader-manifest.json`; the build uses `V_BIN=/Users/alex/code/v/v`. Logs, snapshot JSON and actual/diff PNG directories use the same prefix. All nine targeted runs complete in a single invocation.

- Manifest SHA256: `8f24c6fcc561912e6c70d2d82e5287fb01c57c874cc028f1b1b4200dc90aa371`.
- Whole tracked manifest SHA256: `c100657ceffbb1c27cf3127d6831b4747a1d830d2b71c4f35e1bbe5ddc10bb14`.
- Final native binary SHA256: `e4fbfbae6c58f2428d04913d8227399328a7ee21e97af342b0d5cf25c0b18349`.

Eight smoke cases are pixel-exact. The other three retain previous repository tolerance residuals:

| Case | Differing pixels | Max channel error | MAE | RMSE |
| --- | ---: | ---: | ---: | ---: |
| inline-node | 13 (0.0027%) | 1 | 0.0000 | 0.0026 |
| text-decorations | 1341 (0.2794%) | 2 | 0.0013 | 0.0419 |
| canvas-text | 1994 (0.4154%) | 8 | 0.0038 | 0.0928 |

This bundle includes UTF16 actual UTF8 outer/Common/whole/BOM consumers, actual referrer HeaderList and redirect handling, CSP ASCII and byte-input parsing, exact JIS data prerequisites, SIMD lane store/load and Source shader/program CPU/loss slices through linking. It predates queued Shift_JIS raw/outer/Common callers, actual CSP response/factory owners, program validation/use changes and the later zero-load/MemoryBuffer production guards. These later features do not inherit this whole-batch verification. The browser continues to use JavaScriptCore; no full LibJS/Wasm execution or native GC/realm/world parity is claimed.
