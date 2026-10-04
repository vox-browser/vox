# Frozen Math entropy LibJS verification

Recorded 2026-10-04 against Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The complete tracked checkout in
`Build/audit-fixes/worktrees/10-math-source-entropy` stayed clean and byte-identical
at `1226f3e4d85354c8f4f55c1804951d76b5d42ce3` throughout all three checks.
Individual SHA256 values match before/after for all **4417 tracked files**,
including the AST driver and dependencies. The whole-file manifest SHA256 is
`90af9349ca47370feddc25692479fc42af9d03568ddea265301c0c7469855e60`.

All **490 non-Markdown LibJS implementation/test/asset files** match canonical
`6af10bd545ce272b821f15d3c59a69cde9302c4b` exactly at recording. Their manifest
SHA256 is `d55fd6a720b1bc274039393b94776fb27f7e946d61d51adfb0ce0c229bfef4c9`.
Dependencies outside that package remain those of the private revision.
Manifest hashes use sorted compact JSON mappings of paths to individual hashes.

| Required command | Result | Seconds | Log |
| --- | --- | ---: | --- |
| `VJOBS=2 /Users/alex/code/v/v -old-compiler -enable-globals test libjs` | 234/234 PASS, exit 0 | 655.3 | `source-math-frozen-default.log` |
| Same command with `-gc none` | 234/234 PASS, exit 0 | 653.2 | `source-math-frozen-gc-none.log` |
| `/Users/alex/code/v/v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all` | exact 100/100 PASS, exit 0 | 4.9 | `source-math-frozen-ast-all.log` |

Logs and the complete before/after proof are under that worktree's ignored
`Build/audit-fixes/` directory. Proof file `source-math-frozen-manifest.json`
has SHA256 `c14c9d49e1ae069901106747755dac195c5fce92fed11ee54f13468696c1b8d7`.
Log SHA256 values in table order:

- `d8686624be224f4b3b26463fe46d01ade133033492e1154d95a8e4131b23ec56`
- `1a834dfe34449acd5ea6206eec404600f771e155c845198989310b389b3cc798`
- `b01a89a905d3bcc361bf93de48129ab5897ca26b73f3914b779e265936e935e8`

This snapshot includes the unchecked ASCII owner and
[Math Source entropy constructor](MATH_RANDOM_SOURCE_ENTROPY.md), following the
earlier [233-file proof](LIBJS_UNCHECKED_ASCII_VERIFICATION.md). It establishes
these finite regression results, not complete LibJS execution, intrinsic,
regex, module, synchronization or heap parity. Browser execution still uses
JavaScriptCore. Native bundle and rendering verification remains separately
scoped to its frozen revision.
