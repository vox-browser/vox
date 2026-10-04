# Source primitive-string Reference properties

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Implementation and tests: `bfc616a2`.

`Libraries/LibJS/Runtime/Reference.cpp:115–126` first asks the actual
PrimitiveString for a virtual own property, before selecting StringPrototype
for ordinary lookup. `libjs/reference.v` now calls the already translated
`PrimitiveString.get_own_property` for that first step. Private references
still take the preceding Source ToObject/PrivateGet branch.

Virtual `length` and canonical index reads therefore use the actual string
cell without allocating a wrapper or consulting a supplied receiver. They
retain UTF-16 code-unit semantics, including astral halves, lone surrogates
and embedded NUL. The focused tests execute parsed scripts through the
translated VM and also inspect raw string cells, context restoration and
the interpreter stack.

The new file passes default GC privately. It and Boolean-reference/string-cell
neighbors pass **3/3** privately and **3/3** canonically with GC disabled
(`Build/audit-fixes/source-string-reference-canonical-gc-none.log`).
The subsequent frozen assignment-9 `32b8d45e` snapshot passes **231/231 LibJS
files in each GC mode** and **100/100 exact upstream AST fixtures**. Its
LibJS implementation and tests match canonical integration byte-for-byte;
dependencies outside that package remain those of the private snapshot.
Logs, exact manifest and snapshot hash are in
`Build/audit-fixes/worktrees/09-compiled-records/Build/audit-fixes/`, using
`source-string-reference-libjs-full-{default,gc-none}.log`,
`source-string-reference-libjs-ast.log`,
`source-string-reference-libjs-manifest.txt` and
`source-string-reference-libjs-snapshot.txt`.

This completes only the Source virtual-property fast path. The fallback
StringPrototype lookup, primitive ToObject/private-string behavior, numeric
Reference integration and complete production intrinsic graph remain open
under JS-04/JS-02. These suite results do not establish a complete LibJS
bytecode backend, builtin graph or browser replacement for JavaScriptCore.
