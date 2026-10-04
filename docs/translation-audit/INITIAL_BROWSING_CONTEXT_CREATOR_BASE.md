# Initial about:blank creator base URL snapshot

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/BrowsingContext.cpp:142–155,248–249`.

The V initial-context constructor inherited the supplied creator's origin
and referrer but omitted its document base URL. The resulting initial
about:blank resolved relative URLs against about:blank even when the actual
creator had a different URL or a frozen HTML base element.

The constructor now snapshots the creator origin and document base URL in
Source order, then assigns that optional base URL to the actual new Document
before tree population. No creator leaves the Source field null. The existing
Document fallback/base URL operations consume this stored value; no separate
URL-resolution algorithm or substitute owner is added.

Two focused cases in `html/initial_browsing_context_creator_base_test.v` use
actual Pages and the real context/document constructors. The creator case
parses a genuine HTML base and iframe into its navigation-created Document,
supplies a distinct actual child Page,
and proves the completed about:blank's stored base, inherited origin and real
Window/native context ownership. Relative resources and a later parsed child
base element resolve against the captured creator base. Parsing a replacement
creator base afterward does not change that snapshot. The no-creator case retains a
null stored base and about:blank fallback with actual Window/Page ownership.

The original default batch passed the existing document-element suite, but
the new fixture used the incorrect `Element.set_attribute` method name and
Result syntax. Its original compile diagnostic remains in
`Build/audit-fixes/source-initial-context-creator-base-default.log`. The fixture
now uses the actual `set_attribute_value` mutation surface; implementation
behavior was unchanged by that correction. The next focused run exposed a
separate existing generic-DOM Base lifecycle gap before reaching constructor
copying: raw insertion does not dispatch HTMLBaseElement's translated insertion
hook, so the creator still used its document URL. That runtime diagnostic
remains in `Build/audit-fixes/source-initial-context-creator-base-clean-default.log`.
The focused cases now use the existing real full-document parser/bootstrap,
which freezes parser-created bases after actual tree construction, for initial
creator and later replacement/child bases. No test-only manual lifecycle hook
is called.
The first parser-based replacement run retained the original first base
because the full-document parser was given the existing populated tree;
that assertion remains in
`Build/audit-fixes/source-initial-context-creator-base-parser-default.log`.
The replacement cases now use ordinary `Node.replace_all(none)` before the
full-document parser, preserving their actual Document/Window/context owners.

The final focused default run passed both cases in 38.65 seconds; its log is
`Build/audit-fixes/source-initial-context-creator-base-replacement-default.log`.
The clean GC-none batch passed all six files in 105.39 seconds, covering the
creator snapshot, initial-context completion, existing document elements,
Page ownership, navigation registry and auxiliary-context ownership. Its log
is `Build/audit-fixes/source-initial-context-creator-base-gc-none.log`.

This is the Source creator base URL snapshot and field assignment. Creator
virtual group ID copying, true top-level context owner construction, policy
and opener-policy cloning, ancestor-origin setup, full realm/wrapper-world
creation, native navigable construction, legacy Traversable adapters and
complete teardown remain separate boundaries.
Raw HTMLBaseElement insertion/removal/attribute lifecycle dispatch and its
remaining CSP gate are also open; this field-copy slice does not claim them.
