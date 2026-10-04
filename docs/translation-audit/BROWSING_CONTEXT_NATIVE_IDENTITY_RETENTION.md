# Retaining the actual native BrowsingContext across Document construction

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/BrowsingContext.cpp:134–184,233,306–323`,
`Libraries/LibWeb/DOM/Document.cpp:327–451`.

Source creates a BrowsingContext independently of its Documents. Initial and
navigation Documents are associated with that supplied context, while
replacement Windows share its existing WindowProxy. The V typed/native bridge
retained its actual typed identity only on the native record. If a new
Document had no context slot, Window construction and two navigation-population
branches could allocate another native context for the same typed owner.

The typed context now retains its actual native identity alongside the
existing native-to-typed handle. Document association reuses that retained
context when the per-Document slot is absent. Window construction and both
new/preexisting history-document population branches perform this association
before registering identity or changing the typed active Document. Only the
existing explicit first-construction adapter allocates the native record for
an uninitialized typed context. A different existing native owner continues to
fail the unconditional wrapper identity invariant; the valid missing-slot path
reuses its owner.
Typed group append also uses the retained native owner before consulting an
active Document, so destruction of that Document cannot demote an initialized
member into the explicit pre-native pending list.

Three cases in `html/browsing_context_native_retention_test.v` use actual Pages,
Windows and Documents. They cover navigation replacement followed by repeated
Window construction with one context and proxy; reusing that owner after real
Document destruction clears the context slot; and both population branches
for new and already-existing history Documents.

The initial auxiliary-feature batch exposed the new reverse invariant before
the valid navigation branches reused the existing owner. The existing
declarative-refresh case panicked in navigation population. The same batch
also retained an unrelated new fixture compile error from passing `none` to
V's nonoptional context setter. Both original diagnostics remain in
`Build/audit-fixes/source-auxiliary-context-owner-default.log`; the fixture uses
the setter's nil pointer, and the valid construction paths now reuse Source's
actual owner.

The first production batch also retained a compile failure caused by the
population branch's now-unused mutable local; it remains in
`Build/audit-fixes/source-context-retention-prod-gc-none.log`. The local was
removed without changing the Source association behavior.

The clean default combined batch passed 3/3 files in 78.0 seconds in
`Build/audit-fixes/source-context-retention-auxiliary-focused-default.log`.
After adding the retained group-append case, the focused default file passed
in 49.5 seconds in `Build/audit-fixes/source-context-retention-default.log`.
The final `-gc none` batch passed 10/10 files in 302.4 seconds in
`Build/audit-fixes/source-context-retention-auxiliary-gc-none.log`, including
both focused files, the full Window/navigation/traversable suites, actual
group and active-context ownership, navigation registration, DOM group-switch
neighbors and execution-time unload ownership. Clean `-prod -gc none`
verification passed 2/2 files in 417.1 seconds, including the new retained-owner
cases and existing active-context identity regressions, in
`Build/audit-fixes/source-context-retention-clean-prod-gc-none.log`.

This is actual BrowsingContext identity retention and Document association at
the existing typed/native construction boundary. It does not claim complete
Document creation/population, full realm/wrapper-world parity, Native
Navigable construction, creator metadata, Source active-document setter
side effects, automatic Source GC lifetime or complete teardown. The separate
auxiliary feature supplies Source's logical owner lookup and native metadata.
