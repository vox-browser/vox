# LibJS V frontend refresh

Audited: 2026-09-30.

The frontend baseline comes from `medvednikov/libjs_v` commit
`9824cc3fad0910215f0f4de43fb108bb7575f6c7` (2026-02-24). The upstream reference is
`~/code/3rd/ladybird/Libraries/LibJS` at
`963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11), primarily its Rust
parser, lexer, AST, and scope collector. All refreshed V code and tests live
here; the upstream checkout and the original `libjs_v` checkout are references.
The upstream BSD-2-Clause notice is retained in [`LICENSE`](LICENSE).

## Implemented boundary

`parse_source(source, .script)` and `parse_source(source, .module)` retain a
heap-owned program and function table, return positioned syntax diagnostics,
and expose strict-mode and top-level-await state. `dump_ast()` serializes a
successfully parsed and scope-analyzed source. Error-bearing programs cannot
be dumped through this API.

| V implementation | Upstream responsibility |
| --- | --- |
| `lexer.v`, `token.v`, `unicode_properties.c.v` | UTF-16 lexing, token classification, ICU identifier properties |
| `parser.v`, `expressions.v`, `declarations.v`, `statements.v` | Script/module grammar and parser early errors |
| `scope_collector.v` | Binding resolution, local indices, captures, eval poisoning, declaration metadata |
| `ast.v`, `ast_dump.v`, `utf16_utils.v` | Retained syntax trees, function ownership, UTF-16 identity, AST serialization |
| `frontend.v` | Public source parsing and diagnostic boundary |

The 12 implementation files contain **12,314 physical V LOC**. The 28 test
files contain **1,116 physical V LOC** and **82 test functions**. Physical LOC
includes comments and blank lines. This package is counted separately from the
78-package LibWeb inventory.

## Completed refresh slices

- Validate duplicates against the complete parameter list, reject duplicate
  method parameters, and validate inherited strict-mode destructured bindings
  (`77bf4206544`, `8a64784d467`).
- Reject unconditional reserved-word labels and correctly recognize HTML close
  comments after whitespace crossing a newline (`72876d8b934`, `bac7b46688c`).
- Guard expression, statement, and binding-pattern recursion, unwind the depth
  counter, and isolate legacy-octal tracking to each directive prologue
  (`b997605bdb6`, `6ee59d8bcbd`).
- Preserve supplementary characters, UTF-16 offsets, and distinct internal
  string identities; use the upstream ICU identifier predicates instead of
  Unicode-block approximations. Function-scope metadata decodes names back to
  UTF-16 rather than treating UTF-8 bytes as code units.
- Retain heap-owned AST children and stable function-table entries. Tagged
  template chains snapshot their tag instead of creating a self-reference.
- Use natural token positions for property keys, members, and destructured
  names, including lexer restarts during assignment-pattern refinement
  (`30394ece8d3`).
- Allocate local indices in first-reference order, preserve declaration kinds
  on destructured bindings and their uses, and consume literal property keys
  without suppressing `arguments`/`eval` checks inside computed expressions
  (`cec0be6f3dd`).
- Serialize shortest numeric digits with ECMAScript decimal/exponent thresholds,
  including oversized integer literals, nonfinite values, and subnormals.
- Reject grouped nested assignment patterns and retain grouping metadata on
  assignment targets for later named evaluation (`c23b9443403`, `62ac3040998`).
- Preserve no-In grammar in yield operands and concise arrow bodies, reject
  generator expressions named `yield`, and keep sloppy generator declarations
  working (`b42aa88189f`, `e0ee0990cf9`).
- Isolate await grammar at class function and field boundaries, reject ungrouped
  arrows in class heritage, and apply unary-expression exponentiation errors
  to await (`99596d68ab6`, `a598e09f223`, `45bd4087c4d`).
- Accept grouped dynamic imports as `new` callees; require `of` in for-await
  heads and apply the contextual `async` exclusion only to ordinary for-of
  (`8b64f0079b2`, `6c7e642b675`, `99d3b27b17c`).
- Allow sloppy labelled normal functions, reject their lexical conflicts,
  include them in declaration initialization metadata with the last duplicate
  winning, and mark labelled block functions for Annex B hoisting
  (`6c2487cc9c3`, `eeda29d9ed6`).
- Inherit `new.target` validity through arrows while ordinary functions and
  methods establish their own boundary; isolate `super` permissions in nested
  ordinary functions (`66dbb355fe9`, `04b27429de2`).

## Verification

The repository's current V checkout requires its old compiler frontend:

```sh
v -old-compiler -enable-globals test libjs
# 28 passed, 28 total

v -old-compiler -enable-globals -gc none test libjs
# 28 passed, 28 total

v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all
# LibJS AST corpus: 100 passed, 0 failed, 100 total
```

All 100 checked-in upstream AST fixtures compare directly and exactly, including
scope flags and source positions. Only trailing CR/LF characters are ignored;
there are no case overrides. Actual dumps are written to `Build/libjs-ast/`.
Pass fixture stems to select cases, `--upstream PATH` to choose a checkout, or
set `LADYBIRD_SOURCE_DIR`. ICU headers and `libicucore` on macOS or `libicuuc` on
Linux are required for the identifier predicates.

The preceding LibWeb work also passed its complete 656-file suite, native
headless smoke, and all 11 default screenshot comparisons. That full-suite run
preceded this package; the 28 frontend files were verified separately in both
GC modes. There are now 684 repository test files.

## Remaining translation work

This is a frontend refresh, not a complete LibJS runtime or VM migration.
The browser continues to execute scripts through JavaScriptCore. Neither the
old translation's bytecode/FFI runtime placeholders nor the current upstream
runtime were imported as working implementations.

- RegExp flag checks exist, but `compile_regex_pattern()` still has no backend.
  Pattern syntax validation and compilation require the LibRegex boundary;
  passing the AST corpus does not establish RegExp syntax conformance.
- The parser recursion guard is **32 guarded calls**, rather than upstream's
  2,000. V's flattened expression and statement records produce much larger
  stack frames. The guard reports a positioned syntax error instead of a stack
  overflow; increasing it requires a compact AST representation and stack
  validation first.
- Runtime-dependent eval private-name validation, debugger-frame parsing,
  dynamic-function instantiation, bytecode generation/validation, and cache
  serialization remain outside the public frontend boundary.
- Refreshing the VM, builtin objects, execution environments, GC integration,
  regex backend, and browser host bindings remains necessary before replacing
  JavaScriptCore or claiming full LibJS parity.

The AST corpus and focused syntax cases validate the completed slices above;
they are not a complete ECMAScript runtime conformance suite.
