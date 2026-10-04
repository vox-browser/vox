# BrowsingContext and WindowProxy identity

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/BrowsingContext.cpp:373–432`,
`HTML/WindowProxy.h:58–64`, and `HTML/WindowProxy.cpp`.
Feature commit: `1602b895`.

The typed BrowsingContext retained an active Window separately from its
WindowProxy, and the typed WindowProxy retained a Window separately from its
actual native proxy's `[[Window]]` slot. The Document's native BrowsingContext
also lacked the typed context's actual proxy. Source LocalNavigable active-Window
lookup therefore reached an empty native proxy on real navigation documents,
while typed callers saw their cached Window.

Both duplicate typed Window fields are removed. The typed proxy reads the actual
native slot and resolves its genuine existing WindowModel identity from the
Window registry. BrowsingContext active-Window reads and writes now use that
proxy, matching the source. Existing typed proxy property operations obtain
their current Window through the same getter, including origin checks and
property mutations after native reassociation.

The source context/document bridge installs that existing proxy into the
Document's native BrowsingContext when its active document or proxy is assigned.
Window construction installs the proxy before assigning the active Window.
Real navigation already retains the native context and navigable; replacement
documents now also expose the retained actual proxy and its new Window slot.
No replacement proxy is fabricated for native access.

Three cases in `html/window_proxy_identity_test.v` verify actual construction,
native/typed/context reassociation, current property ownership and cross-origin
rejection, and real cross-origin document replacement retaining the same native
context, navigable, and proxy while updating the actual Window. The old
Document retains its own original native Window reference, whereas its retained
BrowsingContext correctly exposes the current proxy Window.

The focused proxy file passed default GC in
`Build/audit-fixes/source-window-proxy-consumption-final-default.log`.
That initial batch's consumption fixture failed when it attempted to insert
multiple document elements; its corrected final focused run is recorded in the
separate consumption report.
The final GC-none batch passed 5/5 files, covering proxy identity, activation
consumption, activation-owner identity, CloseWatcher, and existing context/proxy
property tests: `source-window-proxy-consumption-complete-gc-none.log`.
Commands used `v -old-compiler -enable-globals test`, adding `-gc none` for
the corresponding batch.

This feature fixes actual source ownership records and existing property
operations. The native JavaScript global remains the compact JavaScriptCore
bridge; it does not yet implement the complete generated WindowProxy/Window
wrapper-world graph, per-realm cross-origin wrapper cache, or full LibJS internal
property methods. The typed getter requires a genuine translated WindowModel
identity; it does not reinterpret an unrelated bare DOM Window allocation as
that larger model. Full BrowsingContext lifecycle/state translation remains
outside this proxy-owner slice.
