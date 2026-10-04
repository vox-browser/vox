# Frozen scalar WebAssembly verification

## Latest frozen 96-file snapshot

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
