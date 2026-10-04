# Actual HTMLBaseElement lifecycle dispatch

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLBaseElement.cpp:26–110`,
`DOM/Node.cpp:943–950,1426–1452`, and `DOM/Element.cpp:1361–1363`.

The native element factory already allocates a concrete `dom.HTMLBaseElement`
for HTML-namespace `base` elements. Its frozen URL lives on that same native
object. However, ordinary insertion and removal dispatched only generic
`Element` lifecycle methods, and ordinary attribute mutations dispatched
only generic `Element.attribute_changed`. The separately translated HTML
Base functions were unreachable through these real mutations. This left
the Document's cached first base and frozen URL stale or absent.

| Source virtual operation | Actual translated call path |
| --- | --- |
| `HTMLBaseElement::inserted` | `Node.inserted` selects the native concrete Base, calls the existing Element parent, captures the old base URL, updates the Document's cached bases, and freezes this element only when it is first with `href`. |
| `HTMLBaseElement::removed_from` | `Node.removed_from_with_context` passes the actual subtree-root flag, old ancestor and old root to the concrete Base. Its parent runs once, then it captures the cached old first/base URL, refreshes the cache and freezes a changed non-null first Base. |
| `HTMLBaseElement::attribute_changed` | `Element.run_attribute_change_steps` selects the concrete Base before the existing style invalidation. The Base calls its existing parent once, retains the Source local-name test without an extra namespace gate, refreshes the Document's base cache for `href`, and freezes itself only when first. |

These Source bodies now live on `dom.HTMLBaseElement` in
`dom/html_base_element.v`, where the actual DOM dispatch can call them without
creating an HTML/DOM import cycle. Existing `html/document_elements.v` Base
entry points delegate to the same methods. The old two-argument removal
wrapper remains an explicit subtree-root compatibility entry point; actual
Node removal passes its full Source metadata directly. Native identity is
compared by pointer, preserving the object allocated by the real factory.
No observer or test-only lifecycle invocation is used to trigger Base logic.

The existing frozen-URL body moves with these methods. It continues parsing
against the Document's fallback base URL and encoding, returns that fallback
for parse failure, `data:` or `javascript:`, and invokes the existing actual
Document base-change response after a successful freeze. This dispatch
feature does not add the missing CSP branch.

Five cases in `dom/html_base_element_lifecycle_test.v` exercise real
Document/Element constructors and standard DOM mutations. They prove insertion
and insert-before tree order, a frozen URL across a Document URL change,
subsequent `href` updates, parent ID/event-handler steps, the Source namespace
behavior, subtree-descendant and direct removal with preserved context and new-first
freezing, adoption into the actual new Document, foreign-namespace exclusion,
and malformed/disallowed-scheme fallback. The existing production lifecycle seam only
records removal metadata; the test never manually calls a Base hook.

The unmodified implementation failed all five focused cases, including the
missing cached first-base identity and frozen URL. The diagnostic remains in
`Build/audit-fixes/source-base-lifecycle-original-default.log`. The clean
focused default run passed all five cases in 5.13 seconds:
`Build/audit-fixes/source-base-lifecycle-default.log`.
The HTML default neighbor batch passed both document-element and creator-base
files in 48.22 seconds (`source-base-lifecycle-html-default.log`). The clean
GC-none batch passed all eight files in 126.21 seconds, covering the new Base
cases, Node lifecycle metadata, raw attribute handlers, existing document
elements, creator base snapshots, initial-context completion, navigation
registry and real replacement fragments
(`source-base-lifecycle-gc-none.log`). The strengthened direct-removal metadata
and malformed-URL cases passed the final focused default file in 5.61 seconds
(`source-base-lifecycle-final-context-default.log`).
The final focused GC-none file also passed in 5.98 seconds
(`source-base-lifecycle-final-context-gc-none.log`).

Open boundaries remain explicit: Source CSP `is_base_allowed_for_document`
and its actual policy/violation owners, full generic HTMLElement parent parity,
the existing full-parser final Base refresh, and Document's compatibility
fallback for an uninitialized frozen URL. This feature translates the missing
concrete virtual dispatch and existing Base method bodies; it does not claim
complete HTMLBaseElement or parser parity.
