# Frozen scalar WebAssembly verification

## Latest frozen branch-helper snapshot: 99 files

Detached canonical `b7e1b970429055e97046e221e182e93714549cb2`, in
`Build/audit-fixes/worktrees/root-wasm99-final`, passes **99/99 files in each
GC mode**, default in 645.3s and GC-none in 630.2s. Commands are
`/Users/alex/code/v/v -old-compiler -enable-globals test webassembly` and the
same with `-gc none`, each with `VJOBS=2`; both exit 0.

All 4,528 tracked path/content entries, HEAD and clean tracked status remain
identical before/after. Its 215 non-Markdown Wasm files and 490 non-Markdown
LibJS files match canonical at recording. This includes the complete Source
branch-to-label helper and prior throw-handler/cache/memory slices. Other
dependencies are the files of this exact snapshot; subsequent changes remain
outside the frozen whole-checkout proof.

Artifacts under that snapshot's `Build/audit-fixes/` are:

| Artifact | SHA-256 |
| --- | --- |
| `source-branch-to-label-wasm99-manifest.json` | `37be3fe3fdbdd1d9cec28a43589fb8ee0c80b0881c3de5e7adea6f399dba3d7c` |
| Whole sorted tracked path/content manifest | `7394fe9b22ee7b90116140220b1ad1a71bf11c62a3b0cb8c79b5a02b608660e2` |
| WebAssembly package manifest | `9adf12039ae6d2a6736f5c01aaf9b5586cb1ebd0aed7d3533e804930d6a7aa4e` |
| LibJS package manifest | `d55fd6a720b1bc274039393b94776fb27f7e946d61d51adfb0ce0c229bfef4c9` |
| `source-branch-to-label-wasm99-default.log` | `9b38ac98ffc3f77702e6ba8f24bdd4564864fdc60c1a283061c23d791fec1435` |
| `source-branch-to-label-wasm99-gc-none.log` | `3552c58c6bf15b2015dda90821c04ecdde29dddd3624acc4a52dfc6ae1c8ff98` |

The initial copied runner stopped at its previous snapshot's HEAD guard before
any tests. That diagnostic remains `source-branch-to-label-wasm99-original-head-guard.log`;
the corrected exact-HEAD runner produced this complete clean proof. Upstream
remained `963d46a829f3e1b79f44dba9d02afb70654300fa`. Actual opcode/compiled
execution, cross-frame re-dispatch, full instantiation and collector/realm
ownership remain unfinished.

## Historical frozen exception-unwind snapshot: 98 files

Detached canonical snapshot `221fe60c3b1f6220a23488774f8a0626c3d9d3ad`, in
`Build/audit-fixes/worktrees/root-wasm98-final`, passes **98/98 test files in
each GC mode**, default in 328.4 seconds and GC-none in 326.2 seconds. Both
commands exit 0: `/Users/alex/code/v/v -old-compiler -enable-globals test
webassembly` and the same with `-gc none`, with `VJOBS=2` per run.

All 4,496 tracked paths/contents, HEAD and clean tracked status remained
identical throughout both full runs. The 213-file non-Markdown Wasm manifest
and 490-file non-Markdown LibJS manifest match canonical at recording. This
includes the complete current-frame throw-handler unwind helper and its
focused exception/tag/branch tests, alongside the earlier checked-memory and
optional extern-cache slices. Dependencies outside these packages are the
files of this exact snapshot; later shader, Encoding and DOM changes are
outside this frozen whole-checkout proof.

Artifacts under the detached snapshot's `Build/audit-fixes/` are:

| Artifact | SHA-256 |
| --- | --- |
| `source-exception-unwind-wasm98-manifest.json` | `086263d58becf279f5d0ac65dfdb84eea83bd4b14baec909ed272e11cd32dfdd` |
| Whole sorted tracked path/content manifest | `b854df761fb30ab59590e6022868318e845d923a4fd1bcd9d457a960af1b3125` |
| WebAssembly package manifest | `f134740f8318dc1473d6a815f39509f912105e094879e9f22a96d1d646b072a8` |
| LibJS package manifest | `d55fd6a720b1bc274039393b94776fb27f7e946d61d51adfb0ce0c229bfef4c9` |
| `source-exception-unwind-wasm98-default.log` | `6f6cec16e5c3c5d651bf1a7a9df01267926fefe0258c1ae487b0aa52cd91174a` |
| `source-exception-unwind-wasm98-gc-none.log` | `66fb818f2d7e420d722fbb8f1f66a4651fede7b19eddcc42b34877cb047d28b0` |

Upstream remained `963d46a829f3e1b79f44dba9d02afb70654300fa`. The proof retains
both complete before/after manifests and exact commands/results. Actual opcode
and cross-frame unwind callers, typed stores/loads, SIMD execution, full
instantiation, native compilation and collector/realm ownership remain
unfinished. Passing the helper package does not establish browser runtime
parity.

## Historical frozen checked-memory/cache snapshot: 97 files

Detached canonical snapshot `b6a80afd0288b09d9fa6db393dd6243a8cb5f626`, in
`Build/audit-fixes/worktrees/root-wasm97-final`, passes **97/97 test files in
each GC mode**, default in 151.6 seconds and GC-none in 150.3 seconds. Both
commands exit 0: `/Users/alex/code/v/v -old-compiler -enable-globals test
webassembly` and the same with `-gc none`, with `VJOBS=2` per run.

All 4,479 tracked paths/contents, HEAD and clean tracked status remained
identical throughout both full runs. The 211-file non-Markdown Wasm manifest
and 490-file non-Markdown LibJS manifest also match canonical at recording.
This includes the checked raw-byte store helper, corrected optional extern
lookup, production allocation/import annotations and test map guards. The
later GLsync proxy-pointer slice and subsequent changes outside the package
are not part of this frozen whole-checkout proof.

Artifacts under the detached snapshot's `Build/audit-fixes/` are:

| Artifact | SHA-256 |
| --- | --- |
| `source-checked-memory-wasm97-manifest.json` | `ccfb27f356231014888033fece18187d809351fc0fae38130481a64f4bdcad04` |
| Whole sorted tracked path/content manifest | `b3b13925c1b00cc707271c0377e6d6f734328e3b3c78646783c7a051d4602ed7` |
| WebAssembly package manifest | `6c508f06202f3f64aa1fb64d635ecc8310a2e6817bdf8b5c994c118ee4e20fa9` |
| LibJS package manifest | `d55fd6a720b1bc274039393b94776fb27f7e946d61d51adfb0ce0c229bfef4c9` |
| `source-checked-memory-wasm97-default.log` | `757ee76ecf0f43f2b761e255c7975471f0566a6da76ce132e6a769d781b8405f` |
| `source-checked-memory-wasm97-gc-none.log` | `55e26c368b7c4119f57df128c386e3f302cef78caee04a91d612900a16a9847f` |

Upstream remained `963d46a829f3e1b79f44dba9d02afb70654300fa`. The proof records
both complete before/after manifests and exact commands/results. Source typed
stores/loads, opcode/SIMD execution, full instantiation, native compilation and
collector/realm ownership remain unfinished.

## Historical frozen dependency refresh: 96 files

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
