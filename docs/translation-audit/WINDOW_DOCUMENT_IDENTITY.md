# Window associated-document identity

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Window.h:127–129`, `HTML/Window.cpp:959–969`,
`HTML/Scripting/WindowEnvironmentSettingsObject.cpp:92–103,141–144`,
`DOM/EventDispatcher.cpp`, and `SVG/SVGDecodedImageData.cpp:44–78`.
Feature commit: `7d5be373`.

The HTML Window model previously retained its own `document_` alongside the
embedded native Window's `associated_document_`. The HTML setter changed only
the first field; the native setter changed only the second. Initial construction
manually set both, hiding the divergence until later document reassociation.
Typed Page/origin/settings queries and actual native dispatch could consequently
observe different documents for the same Window.

The duplicate HTML field is removed. The typed setter delegates to the native
Window setter, and its getter reads the same native record. Existing HTML origin,
frame-request, message-target, and owning-settings reads use that shared
association. Settings setup and `responsible_document()` preserve the source
Window-before-Document construction order by using the native optional getter
until the document exists. Initial construction now associates the document
through the same setter instead of setting two fields separately.

Four focused cases in `html/window_document_identity_test.v` verify:

- Native and typed reassociation in both directions, with actual Page identity,
  current base URL/origin, and the source scripting gate following the associated
  document's disabled Page.
- Actual Window legacy dispatch targeting the replacement document, then the
  original document after restoration, while retaining Window callback/current
  target and original current-event identity.
- A genuine XML SVG document, Window, and native navigable performing the
  association steps used by ScopedSVGImageDocument: same actual Page and realm,
  replacement active-document identity, then original association and activity
  after restoration.
- Actual Window realm/settings creation before Document construction, including
  the absent association before construction and the same settings, realm,
  native Window, and owning Page afterward.

Final default-GC focused tests passed in
`Build/audit-fixes/source-window-document-identity-final-default.log`.
The final GC-none batch passed 3/3 files, including the four focused cases,
`html/page_document_owner_test.v`, and `html/performance_global_binding_test.v`:
`source-window-document-identity-complete-gc-none.log`.
The performance neighbor also passed default GC in
`source-window-document-timing-fixture-default.log`.
All commands used `v -old-compiler -enable-globals`, with `-gc none` added for
the corresponding runs.

The performance fixture now installs its intended time origin on the actual
Document before Window construction. Its previous write to `settings.time_origin_`
was ignored by the pinned Source Window time-origin getter, which reads the
associated Document's navigation-start timestamp. The old assertion happened to
pass when document construction took at least 50 milliseconds and failed when
construction was faster.

The native compact `window.document` value remains a document facade rather than
the complete generated LegacyUnforgeable/CachedAttribute getter. Source wrapper
cache invalidation in `Window::set_associated_document()` requires that pending
wrapper-world accessor cache; this slice does not fabricate a cache or replace
that facade with an incomplete wrapper. The SVG regression verifies the real
association and restoration primitives, without claiming completion of the
entire ScopedSVGImageDocument/PageClient renderer path. The separate
[UniversalGlobalScope queue-time ownership slice](UNIVERSAL_SCOPE_DOCUMENT_OWNERSHIP.md)
removes its document snapshot and captures the actual Window association when
queuing microtasks and rejected-promise notification tasks.
