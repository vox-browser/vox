# Local Navigable active BrowsingContext, WindowProxy and Window ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/LocalNavigable.cpp:1476–1502`,
`HTML/BrowsingContext.cpp:134–184,306–323,379–431` and
`DOM/Document.h:431`.

Source selects a LocalNavigable's active BrowsingContext from its actual active
Document's browsing-context slot. The active WindowProxy comes from that
context, and its current Window comes from the proxy's native internal slot.
The V local model instead returned its cached creation context for all three
queries. Actual Document replacement, context reassociation or destruction
could therefore make its queries disagree with the existing native Navigable
and Traversable queries.

The actual native BrowsingContext now retains an acyclic identity handle to its
real typed HTML constructor object. Window construction installs that handle
before creating the local NavigableModel; the existing typed/native context
synchronization preserves the same association. The bridge resolves a native
context directly to that actual typed owner and requires a registered identity.
It does not cast a small native record to a larger HTML object or infer context
identity from a Window whose association may change temporarily.

`NavigableModel.active_browsing_context()` now reads the actual active Document
and its native context first. `active_window_proxy()` follows the existing
native Navigable's Source chain and resolves the registered real proxy; the
Window query then reads that proxy's actual current Window. A null current
Document or null browsing-context slot returns null. There is no creation-
context fallback for initialized owners. The logical native parent is not
changed by any getter or identity registration.

Five cases in `html/navigable_active_context_owner_test.v` prove actual native
constructor identity and navigation replacement retaining the same context and
proxy while selecting the new Window; reassociation through the real Document
browsing-context setter selecting another genuine context despite an old model
cache; temporary Window/Document and native proxy/Window changes leaving the
native BrowsingContext's own identity stable; null-current and null-context
queries without falling back to retained live Window/context records; and the
retained native context identity remaining available after local-model registry
removal. Fixtures construct actual Pages, Documents, Windows and native hosts.

The focused default batch passed 2/2 files in 62.2 seconds: the five new
owner cases and the existing real navigation-document registry suite. Its log
is `Build/audit-fixes/source-navigable-active-context-owner-default.log`.
GC-none passed 8/8 files in 160.9 seconds, adding the complete Navigable and
Window/context suites, actual proxy identity, current-history ownership, the UI
close task and the event loop. Its log is
`Build/audit-fixes/source-navigable-active-context-owner-gc-none.log`.

This is the local active-owner getter and identity prerequisite. Other uses of
the retained model context, the native/typed context's remaining split fields,
complete Source context construction and group/lifetime teardown, wrapper-world
WindowProxies, remote context transport and full Traversable destruction remain
separate work. Bare native contexts without an actual typed constructor are not
manufactured into initialized owners. The UI close task boundary is documented
in [`TRAVERSABLE_UI_CLOSE_TASK.md`](TRAVERSABLE_UI_CLOSE_TASK.md).
