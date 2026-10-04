# Frozen unchecked ASCII LibJS verification

Recorded 2026-10-04 against read-only Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The entire tracked checkout in the separate private
`Build/audit-fixes/worktrees/07-utf16-ascii-verification` worktree remained clean
at `f25db8a4ee368ff03692f76c55371f0d752600ca` throughout all three checks.
Before/after individual SHA256 values match for all **4027 tracked files**;
HEAD and tracked status are unchanged. That includes the exact AST driver and
package dependencies. Other assignment 7 features continued in the original
`07-fetch-xhr` worktree, without touching this verification checkout.

Whole tracked-file manifest SHA256:
`0f622a41e0c88ab0fac720ce4c1b69877e099a2a8882e43beb989c519a1748d8`.
The **487 non-Markdown LibJS implementation/test/asset files** match canonical
`8108258c9f45986b6739c7dea04d456fa2f5a00d` exactly after the sweeps; their
manifest SHA256 is
`ddace45d03a453dbd886b26822a8786d1ed2a24e5b731b1dab38710b8690e972`.
The final ignored JSON manifest contains individual tracked/package hashes,
exact heads and commands, clean before/after evidence, Source pin, results and
log hashes. Its path is
`07-utf16-ascii-verification/Build/audit-fixes/source-utf16-ascii-frozen-snapshot.json`
and its SHA256 is
`e5d24e525b75bdfc26143cc1fd5be30fbf955cc9c2b3e3d21e0b7ddcb84172a2`.

| Required command | Final result | Frozen worktree log |
| --- | --- | --- |
| `VJOBS=2 /Users/alex/code/v/v -old-compiler -enable-globals test libjs` | 233/233 PASS, exit 0 | `source-utf16-ascii-frozen-full-default.log` |
| Same command with `-gc none` | 233/233 PASS, exit 0 | `source-utf16-ascii-frozen-full-gc-none.log` |
| `/Users/alex/code/v/v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all` | exact 100/100 PASS, exit 0 | `source-utf16-ascii-frozen-ast-all.log` |

Log SHA256 values, in table order:

- `8c8e504a74ac31c06c32e4fb7d0cb4a5510935adfce15bfac2ec83e54c15fa7d`
- `b6a11477047c636185562e9512fcf6e074684b9bfcbb247ccee967f759caf191`
- `eda95d64d3917455d1950c36c328d9d706886beeb114f87f70976f34f747e96e`

Logs are under the frozen worktree's ignored `Build/audit-fixes/` directory.
The earlier original-worktree sweeps also passed 233/233 in each GC mode and
100/100 AST cases with identical LibJS/driver bytes, but tracked files elsewhere
changed during those runs. Those logs and
`07-fetch-xhr/Build/audit-fixes/source-utf16-ascii-libjs-snapshot.json` are
retained as supplemental byte-frozen package evidence; the table above is the
final whole-checkout proof.

These finite results cover this exact implementation snapshot, including the
[unchecked ASCII Source ownership feature](UTF16_UNCHECKED_ASCII_SOURCE.md).
Later LibJS features need their own checks. They do not establish complete
ECMAScript or LibJS runtime parity; browser execution still uses JavaScriptCore,
and existing parser/runtime/regex/builtin/module boundaries remain explicit.
Native bundle/headless/capture validation remains root-owned.
