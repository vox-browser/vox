# Frozen native policy/UTF16/program verification

Exact canonical snapshot `9a749e4ad6c29ef73ce1c83901eb89726df4abcf`,
upstream `963d46a829f3e1b79f44dba9d02afb70654300fa`.
All 4,612 tracked paths/contents, HEAD and clean tracked status remained
unchanged throughout production build, headless startup and captures.
The native binary also stayed identical across both comparison runs.

`V_BIN=/Users/alex/code/v/v ./build_ladybird.sh` passes in 331.5s; the bundle
executable's `--headless-smoke` passes in 1.2s. Nine targeted SVG/selection
comparisons are pixel-exact across the initial five and separate remaining
four-case invocation. The initial invocation exited 1: after five passing
comparisons, both browser launch attempts for the next screenshot reported
Trace/BPT trap5. Its stderr included a Fontconfig warning; no crash cause is
inferred from that warning. The initial log and manifest are retained.
The four remaining cases, including the affected gradient-stop-move-before
reftest, then passed in 57.1s against the unchanged binary. This is passing
evidence across runs, not a relabeled clean original nine-case invocation.

| Targeted comparison | Result |
| --- | --- |
| svg-image-source-switch-same-size | Exact, initial run |
| svg-gradient-in-defs-removed-repaint | Exact, initial run |
| selection-insert-between-boundaries | Exact, initial run |
| paint-server-id-collision | Exact, initial run |
| paint-server-html-id-collision | Exact, initial run |
| gradient-stop-move-before | Exact, remaining-case run |
| gradient-stop-added | Exact, remaining-case run |
| gradient-stop-color-animation | Exact, remaining-case run |
| pattern-transform-update | Exact, remaining-case run |

The configured screenshot smoke set passes 11/11 in 137.3s, with eight
pixel-exact cases. The three existing tolerance residuals are unchanged:

| Case | Differing pixels | Maximum channel error | MAE | RMSE |
| --- | ---: | ---: | ---: | ---: |
| inline-node | 13 | 1 | 0.0000 | 0.0026 |
| text-decorations | 1,341 | 2 | 0.0013 | 0.0419 |
| canvas-text | 1,994 | 8 | 0.0038 | 0.0928 |

All artifacts are under `Build/audit-fixes/`, with prefix
`source-native-policy-utf16-program`: snapshot, initial/final manifests,
build/headless/targeted/targeted-rest/smoke logs, and the corresponding PNG
directories. The initial runner exits 1; the separate finish runner exits 0.

| Artifact | SHA-256 |
| --- | --- |
| Final native manifest | `5ee32368ebad719a52bade2d1daffdf6597548b1c3a1ebccef055be1fb3bde1a` |
| Whole sorted tracked manifest | `d6a4fd05d1eedf1c528153f62cb3f537b38c9d8fb3774506eae22e2bb84cefe3` |
| Native executable | `db4c73beb2c9a139b9031563851aa95c26ac5e9e0a1e1200d23f10231ef250b0` |
| Build log | `9228c92545047d6850b97260a2f36d4ee71f1621b87669002dcd959efdc461a7` |
| Headless log | `c0969a29380548754e94e6fcc3bdc1816e8537bc7ea920434027ccf2a3436baf` |
| Initial comparison log | `f87a5c8e859a1d2900e2ad23b264c36ee20f4d66a408ee28a0c8f24e44dca722` |
| Remaining comparison log | `1c2a1cf0e394ebdfa86765518b1e3ae7447fa924cb264a784be42eef1eb3f6b5` |
| Smoke log | `979f241afb523aac4e275be14571b2da05ac6ef8f1bd5672951b42f4f262669a` |

This snapshot includes current Window/Worker policy routing, own-Document
referrer/snapshot/CSP initialization, supplemental Meta current-settings
proof, actual UTF16 TextDecoder destination and raw UTF8 methods, program
owner/robust/lost-output fixes, and fixed Wasm raw temporaries.
Later outer UTF8/Common consumers, referrer header/redirect repairs, shader
command-loss fixes and SIMD lane stores are outside this native proof.
The same exact revision passes the full 101-file Wasm package in both GC
modes; [its frozen package proof](WASM_SCALAR_VERIFICATION.md) records hashes.
Selected captures and helper tests do not establish whole-browser or
complete LibJS/Wasm runtime parity.
