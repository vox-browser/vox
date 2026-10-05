# Frozen Blob URL continuation at f273f1ef

Canonical snapshot `f273f1efa22bc7ea8d9ea6e1077199fbb020dd6c` against
Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` completes the package,
production, startup and screenshot verification below. All three manifests
preserve identical before/after HEAD, clean tracked status and SHA256 hashes
for all **4,812 tracked files**. Compiler wrapper/fallback hashes and the
upstream pin/status also stayed unchanged.

This snapshot includes actual Blob URL settings/store snapshots (`6756a0cf`),
partition and revoke (`02226729`), owned DOM URL records (`d1531756`), actual
Fetch environments (`08d65915`), MediaSource document attachment (`a0f60763`),
isomorphic Content-Type encoding (`242a95de`), and compatibility-cache copy
ownership (`f273f1ef`). The independently verified
[DOMURL constructor copy](DOMURL_CONSTRUCTOR_COPY_OWNER.md) (`c1e5845d`) was
integrated after this freeze and is outside the bundle/package snapshot.

## Package verification

Both commands use `VJOBS=2 /Users/alex/code/v/v -old-compiler -enable-globals
test encoding http domurl`; the GC-none run adds `-gc none` before `test`.
These are **37 Encoding, 8 HTTP and 2 DOMURL files**, including the new
isomorphic helper and header tests. The constructor file is a later addition.

| Check | Result | Seconds | Log SHA256 |
| --- | --- | ---: | --- |
| packages-default | 47/47 default GC | 711.185 | `3c557a06159930144f5834b3e0a6563cdb0ff0bb5d8b6c8ddf5585a9fdf6a7d6` |
| packages-gc-none | 47/47 GC-none | 551.773 | `42bd9e70911d16c0edf71f97216a04bc0798f1fbbf7fe7cc6b661211c28c7945` |

The preceding cache integration also passes **3/3 default and 5/5 GC-none**
scoped files, including actual Blob DOM parsing, header encoding, MediaSource
attachment and the 66-case main regression. [Cache owner evidence](DOM_URL_CACHE_COPY_OWNER.md)
distinguishes those unchanged seven-file inputs from this later whole freeze.
Wasm and StorageAPI were unchanged by these slices; their last full-package
results remain the [earlier frozen 6f1df913 run](FROZEN_6F1DF913_CONTINUATION.md).

## Native production browser

`V_BIN=/Users/alex/code/v/v ./build_ladybird.sh` builds the ad-hoc signed
`Build/v/Ladybird.app` with `-old-compiler -enable-globals -prod -gc none`.
The bundle passes `codesign --verify --deep --strict` and its executable's
`--headless-smoke` check. Exact screenshot argv and output directories are
retained in the manifests.

| Check | Result | Seconds | Log SHA256 |
| --- | --- | ---: | --- |
| build | PASS | 1725.480 | `a70e0fd2f4e358d3b65661a34e4eed6a498f2ea68c316e7dbfce2f7691a6fc75` |
| codesign | PASS | 0.025 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| headless | PASS | 2.263 | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| targeted | 9/9 pixel-exact | 101.457 | `4a1a0c14bec6e1d0439ed0bd553da69f80d3bf61df15b7a390bb3a4c9a68f9e8` |
| smoke | 1 comparison passes; capture aborts | 35.225 | `f5d0aec18e6ffad7b580d6b4ffe2f4ab0571c8db28d7e8450f2e71b3af4aef8a` |
| full smoke retry | 11/11 within configured tolerances | 196.183 | `56e6ecc35b89a9cddb0f93992f0605ecde1622a9cc7e962238c5cc9b3a380212` |

The initial smoke run captures and passes `inline-node`, then `ordered-list`
hits two Trace/BPT browser-launch traps and the capture script aborts. That
log and its PNGs remain intact. The complete eleven-case retry uses a fresh
output directory and the same binary; its manifest proves unchanged tracked
inputs and binary SHA256. This verifies rendering outcomes while retaining
the intermittent launch failure; it is not a browser-stability fix.

All nine targeted SVG image/paint-server mutation and live-selection cases
are pixel-exact. Eight smoke cases are pixel-exact; the other three preserve
the previous bundle's exact residual metrics and existing tolerances:

| Case | Differing pixels | Maximum channel error | MAE | RMSE |
| --- | ---: | ---: | ---: | ---: |
| inline-node | 13 (0.0027%) | 1 | 0.0000 | 0.0026 |
| text-decorations | 1341 (0.2794%) | 2 | 0.0013 | 0.0419 |
| canvas-text | 1994 (0.4154%) | 8 | 0.0038 | 0.0928 |

## Recorded artifacts and scope

All files below are under `Build/audit-fixes/`; logs, original/retry PNGs and
amplified difference images are retained with the same prefix. Every recorded
log and PNG SHA256 was checked after completion.

- Whole tracked-file record: `source-native-blob-cache-f273f1ef-before.json`, SHA256 `b7fdeb63768eda9eefb6b61ab13fbe45b841ec1161b996222c7cd9f2975546d6`.
- Package manifest: `source-native-blob-cache-f273f1ef-packages-manifest.json`, SHA256 `262d51c7108bc072fbbaffb178997f3a7fe6a173cf378934a4849b80bd5ef45f`.
- Initial native manifest, including capture failure: `source-native-blob-cache-f273f1ef-native-manifest.json`, SHA256 `dd38a78b9572280926cccbe090d7bdcd62477e07e55cafaf6b80011d2b3deb2b`.
- Full smoke retry manifest: `source-native-blob-cache-f273f1ef-smoke-retry-manifest.json`, SHA256 `4594467573cd12c7c8da3a06686f60318fdaeb91b268beca0d8142d770cc1e97`.
- Final bundle executable SHA256: `3306af980d1313c8d8296b3d77a29813f2ba1d02bf17bba401f816d7e75e59fa`.

This is complete verification of the stated snapshot and scopes. It does not
freeze every external backend/toolchain dependency or establish native public
URL WebIDL, complete UTF16/encoding-aware parsing, remote IPC, physical
allocator/collector, LibJS execution/builtins, or Wasm execution/native compiler
parity. The browser continues to use JavaScriptCore. The audit ledger remains
**32 fixed / 25 partial / 9 open**.
