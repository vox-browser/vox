# Frozen scalar WebAssembly verification

## Latest frozen dependency refresh: 96 files

Canonical revision `e93aaa7b72e56a90f71636efb2be6c3c58113b56` passes
**96/96 WebAssembly test files in each GC mode**, default in 130.6 seconds and
GC-none in 128.5 seconds. Commands are `/Users/alex/code/v/v -old-compiler
-enable-globals test webassembly` and the same with `-gc none`, using `VJOBS=2`.
Both exit 0. All 4,444 tracked paths and contents, HEAD and clean tracked status
stayed unchanged before and after both runs. Upstream remained pinned at
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The 209 non-Markdown WebAssembly files are unchanged from the previous 96-file
proof. This refresh verifies them with the newer 490-file non-Markdown LibJS
dependency snapshot, including owned raw ASCII strings and Source Math entropy.
It adds no Wasm implementation or execution-parity claim.

Artifacts are under canonical `Build/audit-fixes/`:

| Artifact | SHA-256 |
| --- | --- |
| `source-current-dependency-wasm96-manifest.json` | `6b434dbc722e35fcde7c30d63e742203f44e5ed997b9efbc8524d2a96014e171` |
| Whole sorted tracked path/content manifest | `abdcc05ab7164b1974bdf90416fdf8d05a59b16d082a625e9d546206841d5808` |
| WebAssembly package manifest | `52b93b2bd838f29a6c4a07a54c43af5794e5944743c4118070d0bd399e530da4` |
| LibJS package manifest | `d55fd6a720b1bc274039393b94776fb27f7e946d61d51adfb0ce0c229bfef4c9` |
| `source-current-dependency-wasm96-default.log` | `1a927512b604498c0c7e89aa835949e631e7815b801d93552448a713b0750d8d` |
| `source-current-dependency-wasm96-gc-none.log` | `dfbc9783eaf41f8bfa65c3e50374ae112f9a520180b1ebdc2a61db97aa79b36e` |

Manifest entries retain exact commands, before/after file digests and results.
Later Base/CSP, expanded single-byte codecs and shader-gate changes are outside
this frozen whole-checkout proof. Production opcode/SIMD execution, complete
instantiation and collector/realm ownership remain unfinished.

## Historical frozen 96-file snapshot

Snapshot: `a7e4319a7eb3fca6f47d55ff24d47398164b1351`, an isolated checkout of
that exact canonical commit in `Build/audit-fixes/worktrees/09-compiled-records`.
Both full runs pass **96/96 test files**, with two jobs per run:

| GC mode | Result | Elapsed | Log SHA-256 |
| --- | --- | ---: | --- |
| Default | PASS, exit 0 | 177.9s | `1e5cf216393b4204a3a9238d440ab9d12ce8f25ee320302e9571112fa65e031c` |
| None | PASS, exit 0 | 176.2s | `3cf1a668e0880035feec032b5c7a536a2cddcf9c2dae6724b47bf75aaa5f4408` |

Commands were `/Users/alex/code/v/v -old-compiler -enable-globals test webassembly`
and the same command with `-gc none`, with `VJOBS=2`. Logs use
`source-scalar-wasm96-full-{default,gc-none}.log` under the snapshot's
`Build/audit-fixes/`. This includes both checked and saturating truncation.

The manifest `source-scalar-wasm96-manifest.json` records commands/results and
before/after digests for **209 non-Markdown WebAssembly files and 485
non-Markdown LibJS files**. Its SHA-256 is
`c796ede331a201b575c57845e614db2ab63ea340620208494e7bf60d1ca7041e`.
Both sets stayed byte-identical, the tracked checkout stayed clean at the exact
revision, and both sets matched canonical at recording. Dependencies outside
those packages remain the files of this exact snapshot; subsequent code and
LibJS dependency changes are outside this proof. Production opcode dispatch,
remaining scalar/SIMD operations, complete execution/instantiation and native
collector/realm ownership remain unfinished.

## Historical frozen 94-file snapshot

Snapshot: `e86c54a7b3749a8bbaa6e31a6b10ba0f8d0c7f77`, an isolated checkout of that exact canonical
commit in `Build/audit-fixes/worktrees/09-compiled-records`.
Upstream: `963d46a829f3e1b79f44dba9d02afb70654300fa`.

Both full runs pass **94/94 test files**, with three jobs per run:

| GC mode | Result | Elapsed | Log SHA-256 |
| --- | --- | ---: | --- |
| Default | PASS, exit 0 | 307.0s | `6dbdb2d04a8d5b2cc9eae6a337ce0e7917718bde66b315c86603a20175386564` |
| None | PASS, exit 0 | 303.7s | `2e341c14c3d1cdb1add958ae4ae1338f11fe26d978671675ea99e0443efb4ba0` |

Commands were `/Users/alex/code/v/v -old-compiler -enable-globals test webassembly`
and the same command with `-gc none`, with `VJOBS=3`. Logs use
`source-scalar-wasm94-full-{default,gc-none}.log` under the snapshot's
`Build/audit-fixes/`.

The manifest `source-scalar-wasm94-manifest.json` records all commands, results
and before/after SHA-256 digests for all 202 non-Markdown
WebAssembly files and 485 non-Markdown LibJS files. Its SHA-256 is
`e461541e742ad59ec62a3e0504b7084993033102aadfcec62ad57b91ccef3a38`. Both sets stayed byte-identical throughout both sweeps,
the worktree stayed clean, and they match canonical at recording. Dependencies
outside those packages remain the files of this exact snapshot; subsequent
FileReader/fixed-view/HTML changes are not included in the sweep. The subsequent
95th checked-truncation file is also outside this frozen package manifest.

This snapshot includes Source floating unary, float/integer widths, scalar
reinterpret and integer-to-floating conversions, their exact pinned C++
fixtures and actual numeric-helper tests. It validates the translated package
scope. Production opcode dispatch, constant expressions, complete instantiation,
remaining scalar/SIMD operations, native compilation and full collector/realm
roots remain unfinished. No complete browser WebAssembly runtime parity is
inferred from these tests. The separate historical LibJS 232-file/100-AST proof
retains its own earlier snapshot and dependency scope.
