# Window length and indexed child ownership

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.cpp:1313–1317`,
`HTML/WindowProxy.cpp:76–108,233–281`,
`HTML/LocalNavigable.cpp:1476–1492`, and `LibJS/Runtime/Value.h:505–511`.

The V Window length and indexed WindowProxy getter used the cached
BrowsingContext child vector. That vector can disagree with the associated
Document's actual child navigables after logical ownership changes, DOM
container moves/removal, or temporary associated-Document changes.

The actual native Window now exposes the Source length getter over its
associated Document's `document_tree_child_navigables()`. WindowModel delegates
to that record. The indexed WindowProxy getter uses the same source child list,
whose existing Document algorithm supplies actual container tree order. Each
in-range value comes from the child Navigable's native active WindowProxy and
resolves the already-existing actual HTML proxy record by identity. No bare
native proxy is cast to a larger HTML record and no new proxy is fabricated.

Source indexed descriptors remain non-writable, enumerable, and configurable.
Missing same-origin indices return no descriptor; missing cross-origin indices
throw SecurityError. A child without an active WindowProxy still has an
in-range descriptor whose value is null, matching Source's nullable-pointer
JS::Value conversion. Existing indexed own-key enumeration and deletion now
observe the correct length/descriptor range.

Four cases in `html/window_child_tree_owner_test.v` use actual navigation
Documents/Pages/Windows and connected iframe containers to verify tree order
independent of registration order, live reordering/removal, same-/cross-origin
access and descriptors, stable native proxy identity after native Window
retargeting, a null child active-document value, temporary Document swap and
restoration, and the Source no-navigable empty child list despite cached
context children. The legacy indexed access fixture now initializes actual
Documents and connects an actual iframe container instead of assuming that a
context-only child belongs to the Document tree.

The final default batch passed 2/2 files in
`Build/audit-fixes/source-window-child-tree-owner-complete-default.log`.
An earlier batch exposed test-only insert-before signature and uninitialized
legacy Document errors; its diagnostics remain in
`source-window-child-tree-owner-default.log`.
The GC-none batch passed 5/5 files, adding actual proxy identity, Navigable
hierarchy, and Window/Document identity neighbors:
`source-window-child-tree-owner-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, with `-gc none` for
that batch.

This slice translates the native/model child ownership reads. Full native
JavaScriptCore WindowProxy/global wrapper graphs, ordinary property descriptor
handling, named-child algorithms, actual remote-process proxy transport, and
the broader cached WindowModel BrowsingContext accessor remain separate
translation boundaries. The existing identity registry bridge resolves actual
local proxies only and fails explicitly for a native proxy without a translated
HTML model; it does not synthesize an author-visible replacement.
