# Initial BrowsingContext completion

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/BrowsingContext.cpp:288–302`.

The real typed BrowsingContext factory already creates its owning Page,
Window/global/settings and initial about:blank Document, but stopped after
populating html/head/body. Its initial Document remained unready for post-load
tasks and incompletely loaded, its actual settings retained an execution-unready
flag, and top-level creation missed Source's supported color-scheme defaults.

The missing Source tail now marks the Document ready for post-load tasks before
population, assigns light/dark support only when no embedder was supplied,
makes the actual Document active, and completely finishes loading it. Calls use
the existing Document operations and actual native WindowProxy/settings owner.
No synthetic script source or substitute Window is constructed.

Two cases in `html/initial_browsing_context_completion_test.v` use actual Page
owners and initial context factories. They prove initial about:blank identity,
completed HTML structure, post-load readiness and complete loading, the actual
settings execution-ready flag, native proxy/Window/Document identity and Page
ownership. The embedded case uses a real parser-owner Document and inserted
iframe, retains its creator origin, and confirms that top-level color-scheme
defaults are not imposed on an embedded initial Document.

The original default batch retained a fixture compile failure: its new case
mistakenly called `Document.url()` instead of reading the V `url` field; the
existing Page ownership file passed. The fixture now reads the field, without
changing implementation behavior. That evidence remains in
`Build/audit-fixes/source-initial-browsing-context-completion-default.log`.
The clean focused default file passed in 13.1 seconds in
`Build/audit-fixes/source-initial-browsing-context-completion-focused-default.log`.
GC-none passed 5/5 files in 66.6 seconds, adding actual Page ownership, active
context ownership and its production identity invariant regression, the full
Window/context suite and the navigation-document registry. Its log is
`Build/audit-fixes/source-initial-browsing-context-completion-gc-none.log`.

This is the Source completion tail, not complete BrowsingContext construction.
The factory's current extra group parameter/append adaptation is corrected by
the separate group-construction work. Creator policy/opener/base copying,
ancestor-origin setup, full realm/wrapper-world construction and logical
navigable construction remain separate boundaries. The existing Document
post-load readiness setter still lacks Source's native navigation-load-guard
cancellation; these newly created initial contexts have no such guard, and
this commit does not claim to translate that setter body.
