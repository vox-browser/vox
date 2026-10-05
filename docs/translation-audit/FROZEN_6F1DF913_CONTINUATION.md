# Frozen resumed batch at 6f1df913

Canonical snapshot `6f1df913da94d2b294fdeadcd29dc7a8cd7f6868` against Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa` passed all checks below. Both manifests retain identical before/after HEAD, clean tracked status and SHA256 hashes for all 4,789 tracked files. The two runs used the same whole-file manifest.

The batch includes the Source UTF8 whole Off owner and selected BOM caller, reviewed actual-origin StorageKey/hostless adapter correction (`c25970c8`), retained getParameter driver selection (`c97ca4fb`), and WebGL2 zero timeout (`477ea688`). Earlier Shift_JIS, CSP/origin, lost uniform-location and production memory-guard commits are also in this snapshot. Implementation/tests were committed separately for each completed slice; the resumed storage feature incorporates its reviewed hostless correction together.

## Package and caller checks

All commands use `/Users/alex/code/v/v -old-compiler -enable-globals` and `VJOBS=2`. GC-none rows add `-gc none`. The manifests preserve complete argv and per-log hashes.

| Scope | Result | Seconds | Log SHA256 |
| --- | --- | ---: | --- |
| webassembly-default | 114/114 default GC | 828.388 | `4e07973a770dfc4f58cc3c08631d91f0aad7363d2c927e9769a82e70351dbe92` |
| webassembly-gc-none | 114/114 GC-none | 806.985 | `5fd0c0de45627062150003bc6641714ba5c4ff071178431e470a5235451107ca` |
| encoding-default | 36/36 default GC | 280.402 | `ffced78d5750ecbeba8756058cb3a495fcae65e2757afda74301648bdffaa399` |
| encoding-gc-none | 36/36 GC-none | 274.713 | `0f1e0f48b2b2a2e977cdc2f56d750ffbf9155a0837cca50141edd046a1270818` |
| storageapi-default | 4/4 default GC | 7.328 | `e3ad5394763fb4aed5f3175b689d30976c2e77fd806163d8b218a74af5ab66fd` |
| storageapi-gc-none | 4/4 GC-none | 7.907 | `622482a8c7257f42f2481f51327a1c24c6eed561c1a0e18f8d10a6824745a3f8` |
| actual-callers-gc-none | 4/4 GC-none | 266.049 | `41816018985b440e51ad9793fff84794b127acb24b9f655e48bfae83a5fc687d` |

The caller batch is `html/storage_key_actual_settings_owner_test.v`, `html/indexed_db_global_binding_test.v`, `browserjs/file_reader_sync_text_test.v`, and `main_test.v` (66 test functions). The earlier canonical six-file StorageKey and four-/two-file WebGL checks are recorded in [storage ownership evidence](STORAGE_BOTTLE_HOSTLESS_OWNER.md), [parameter driver evidence](WEBGL_GET_PARAMETER_DRIVER_SELECTION.md), and [timeout evidence](WEBGL_MAX_CLIENT_WAIT_TIMEOUT.md). These focused WebGL checks preceded the freeze; this is not a new full WebGL package sweep.

## Native production browser

The canonical `./build_ladybird.sh` uses `V_BIN=/Users/alex/code/v/v`, `-old-compiler -enable-globals -prod -gc none`, and produces the ad-hoc signed `Build/v/Ladybird.app`. Headless startup runs its executable with `--headless-smoke`. The manifest retains exact screenshot inputs and commands.

| Check | Result | Seconds | Log SHA256 |
| --- | --- | ---: | --- |
| build | PASS | 1174.334 | `e2fbbc071882d4a0088bee74c71485da5d1f231fc07d446152696e2a107cb597` |
| headless | PASS | 1.660 | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| targeted | 9/9 pixel-exact | 110.473 | `02ffffa6855e54b09998aadd66d0a2c6f59093524edab6926efb555379fcc0ff` |
| smoke | 11/11 within configured tolerances | 95.408 | `870dd75727db9733882b1b67482692694fa4ad4b90a24f42075eeda8459f29f8` |

Targeted cases are SVG same-size image replacement, gradient removal, live selection insertion, the SVG/HTML paint-server ID collisions, gradient-stop move/add/animation, and pattern transform update. All nine are pixel-exact. Eight smoke cases are pixel-exact; three retain the same residuals as the earlier frozen `a85c3b92` bundle:

| Case | Differing pixels | Maximum channel error | MAE | RMSE |
| --- | ---: | ---: | ---: | ---: |
| inline-node | 13 (0.0027%) | 1 | 0.0000 | 0.0026 |
| text-decorations | 1341 (0.2794%) | 2 | 0.0013 | 0.0419 |
| canvas-text | 1994 (0.4154%) | 8 | 0.0038 | 0.0928 |

## Reproducible evidence and boundaries

- Whole tracked-file manifest SHA256: `0b180f3a369a8a48d80c04424f5a18d8681d9a11d88b97032051397d2f6383ca`.
- Package manifest: `Build/audit-fixes/continuation-frozen-packages-manifest.json`, SHA256 `0d14ac6ffb71e24096387ee34b2df1b8d8f30d598cd5d22941503aff6684745f`.
- Native manifest: `Build/audit-fixes/continuation-native-memory-storage-utf8-manifest.json`, SHA256 `bae020fce4d25e2d9a65a25b319c85341284670c5f87bf16ef4ee98b9b6e5b80`.
- Final native binary SHA256: `c774e5d8da5b794e0ed01dc5d49fcaf8f329ec7fc51c4cd7c5a3b87878e66b80`.
- Native actual/diff PNG directories share the `continuation-native-memory-storage-utf8-{targeted,smoke}` prefix.

The refreshed 78-owner inventory records 431,819 implementation V LOC and 152,385 test V LOC; physical counts and structural mappings do not measure parity. Its source artifact is `Build/audit-fixes/source-current-module-loc-b7d34ca4.json`, SHA256 `bf0d0bd1fa5d48602eeb7be05b33230d06aaebe9c89c3146c0fbdf83823f8e56`. Root/browser support remains excluded from those package totals.

The audit ledger remains **32 fixed, 25 partial, 9 open**. Source proxy string caching and genuine Blob-store partition/settings ownership remain subsequent slices. Native StorageAPI Environment/Page/IPC ownership, allocator/collector equivalence, Wasm instantiation/interpreter/native compilation, and full LibJS execution/builtins remain unfinished. The browser continues to use JavaScriptCore. This record verifies the stated scopes and immutable repository contents; it does not certify full source parity or freeze every external toolchain/backend dependency.
