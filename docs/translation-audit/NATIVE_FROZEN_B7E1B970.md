# Frozen native regression at b7e1b970

Canonical `b7e1b970429055e97046e221e182e93714549cb2` stayed unchanged through
the production build, headless startup and screenshots on 2026-10-04. All
4,528 tracked file contents, HEAD and clean tracked status match before/after.
Upstream remained `963d46a829f3e1b79f44dba9d02afb70654300fa`.

`V_BIN=/Users/alex/code/v/v ./build_ladybird.sh` passes with production
compilation and GC disabled (743.5s). The executable passes `--headless-smoke`
(1.2s), including the JavaScript click event.

All nine targeted inputs have zero differing pixels: image source replacement,
gradient removal, insertion-boundary selection, paint-server ID collision,
HTML/SVG ID collision, gradient stop move/add/animation and pattern transform.
The initial command passed the first three, then stopped because the coordinator
passed relative `svg/` names that the script treats as literal paths. No browser
failure occurred for that missing input. The remaining six passed unchanged
using verified absolute upstream paths (62.4s). The initial log and manifest
remain retained; no clean single nine-case invocation is claimed.

The configured smoke passes **11/11** within existing tolerances (102.4s).
Eight are pixel-exact. `inline-node` retains 13 differing pixels and maximum
error 1; `text-decorations` retains 1,341 and maximum error 2. `canvas-text`
retains 1,994/480,000 differing pixels, maximum error 8, MAE 0.0038 and
RMSE 0.0928. These three are not pixel-exact.

Artifacts use `source-native-meta-utf8-shader-` under `Build/audit-fixes/`.
`snapshot.json` and `manifest.json` retain complete before/after contents,
commands/results, log hashes, binary hash and per-case metrics. PNG directories
are `targeted/`, `targeted-rest/` and `smoke/`.

| Artifact | SHA-256 |
| --- | --- |
| `manifest.json` | `d6f6a6fc39e2a762034bf11ad5ce7995d6c24cce38a082c62a44009fcf8e40e0` |
| Whole sorted tracked path/content manifest | `7394fe9b22ee7b90116140220b1ad1a71bf11c62a3b0cb8c79b5a02b608660e2` |
| Native executable | `d1b88cbc726fe765f7b060d7cbb77998d39718c5ae756e5bc981ce3f071ebd1a` |
| `build.log` | `d1d3834f46b100724c614b3db1bf16acffa32f0e6d54fbb0c5aecd236581c6e7` |
| `headless.log` | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| Original path-error `targeted.log` | `17049476fb387c256648284cd1938edb93d3e893ea9ed98623a8afb5938f9ee4` |
| `targeted-rest.log` | `91a7fe608ef0d0e3264fbd2ec23e681688a279de4d15d33926fb4e4e0b0b26b6` |
| `smoke.log` | `760ed7f335b09b267e22374ddb8733890b87d29dcef94825df047109471dc53c` |

This bundle includes real Meta lifecycle/language/CSP append, typed CSP-origin
copying, UTF8 retained raw/outer/Common ownership and decoder flush reset,
Source shader/sync owner and robust/lost query corrections, and the Wasm
throw/branch helper slices. Later UTF16 destination, Document policy ownership
and isShader followups retain separate scope and do not inherit this build.
Complete LibJS/Wasm execution, remaining codec variants, remote transport and
collector/wrapper-world ownership remain unfinished.
