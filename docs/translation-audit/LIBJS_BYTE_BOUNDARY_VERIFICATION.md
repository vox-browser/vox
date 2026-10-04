# Source byte-boundary LibJS verification

Recorded 2026-10-04. Source is read-only Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

The frozen private snapshot was `a933857009912fa4a946b130bfcecda9e48219b2`,
after adding the Source raw byte/ASCII helper and integrating canonical Source
stack-address and primitive-string Reference prerequisites. It matched
canonical `a96b438e1f56acd1c02f3434d1e7efdbe263e024` across all **485**
non-Markdown LibJS implementation, test and asset files. File/DataTransfer
feature work continued outside LibJS while these sweeps ran; the code manifest
matched private and canonical again after all three commands completed.

Implementation manifest SHA256:
`a18247a180537e61f9328a20767159ad83a808e0a2391d87ef3e0704d6da6504`.
Final ignored JSON manifest:
`Build/audit-fixes/source-utf16-libjs-snapshot.json`, SHA256
`3b4bb14a5e4a9baa4f11a3708c944d1dc230194b4320ce08b59a0944fda715b4`.
The manifest includes individual source hashes, exact heads/commands, unchanged
before/after evidence, exit status, summaries and log hashes.

| Required command | Result | Private log |
| --- | --- | --- |
| `VJOBS=2 /Users/alex/code/v/v -old-compiler -enable-globals test libjs` | 232/232 PASS, exit 0 | `source-utf16-libjs-full-default.log` |
| Same command with `-gc none` | 232/232 PASS, exit 0 | `source-utf16-libjs-full-gc-none.log` |
| `/Users/alex/code/v/v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all` | exact 100/100 PASS, exit 0 | `source-utf16-libjs-ast-all.log` |

Log SHA256 values, in the table order:

- `655f7e6798fcf8790c04b29eb44a836cff8a61435a768a748dc29c7ef48a2ae7`
- `4ceeeaf2901b389ba934ce7b23f3883b69a902c5b4f4ec09443bda615b7f1cce`
- `90008fd7d16b28fc47bd3f959d11521bcebc37a9638f6fc292642aa22383daad`

Logs and JSON are in assignment 7's private worktree under
`Build/audit-fixes/worktrees/07-fetch-xhr/Build/audit-fixes/`. The separate
`tools/source_drag_wtf8_probe.py` also passed native -O0 and -O2 with the actual
Source AK header helpers for lone/null/supplementary names, invalid leading and
continuation bytes, truncated inputs, retained overlong code points,
out-of-range consumption, and raw ASCII lowercase. That bounded native probe
runs decoder/ASCII helpers, not a complete C++ File/LibWeb executable.

These finite results validate this unchanged code snapshot. The browser still
uses JavaScriptCore; the existing LibJS parser recursion cap and pending regex,
bytecode/interpreter, builtin and module-linking coverage do not become full
LibJS parity. Native bundle/headless/capture verification remains root-owned.
