# Old Reddit comment expansion

Clicking an ID-less comment expansion control could replay the click on the
wrong facade, lose cancellation, and pass a temporary navigation string across
layout/GC boundaries. A `javascript:void(0)` default action could also enter
ordinary URL/search handling. Reddit's jQuery initialization additionally needed
native removal, detached deep cloning, last-child access and tag collections.

This report contains seven focused fixes after the inherited broad-test baseline
recorded in `AGENTS.md` (`f2e223c9`). They are recorded here individually; this
entry does not reset the repository's broad-test cadence.

- `303edafd`: dispatch clicks using stable native element identity, bubble through
  compact ancestors, honor cancellation and retain navigation strings.
- `b81f1e53`: execute JavaScript URLs in the current document, replacing markup
  only for string completion values, subject to script/CSP policy.
- `03c2914d`: clone actual detached subtrees and expose native last-child identity,
  including character-data reads and writes.
- `b70d021c`: remove children through the native parent, preserving return identity
  and native wrong-parent errors, and allow later reinsertion.
- `757a6677`: expose live tag-name collections with native HTML/SVG name matching.
- `099bf357`: reuse a tag collection's members until the document tree version
  changes, avoiding full member serialization for every indexed read.
- `ff38f636`: track pending compact edits directly, preserving native read
  flushes without scanning every facade for each collection member.

The 33-case focused run passed in both default GC and `-gc none` modes.
The private nine-program Reddit script replay passed, expanding and collapsing
an original comment while preserving its URL. It compares class membership
rather than whitespace/order, which jQuery normalizes. Earlier replays recorded
unrelated `ownerDocument.defaultView` diagnostics; this focused check does not
require every site diagnostic to be clear.

The optimized Boehm macOS bundle built and signed successfully. Strict signature
verification, native startup and a real window click passed; the screenshot
shows expanded content with an unchanged URL. All eight required SVG mutation
comparisons are pixel-exact. The final native cached-thread replay passed without
DOM shims: a window click invoked Reddit's original toggle, changed the actual
comment and retained the local replay URL. The verified bundle was installed
into `Build/v/Vox.app`; its predecessor is preserved under ignored `Build/`.

Focused implementation tests are in `main_comment_expansion_test.v`,
`main_javascript_navigation_test.v`, `main_compact_last_child_test.v`,
`main_compact_remove_child_test.v`, `main_compact_tag_collection_test.v` and
`main_compact_tag_collection_live_test.v`. The existing clone-node, media-click
and navigation cases supply neighbor regression checks. Cached account-bearing
Reddit markup and script fixtures remain private under ignored
`Build/reddit-comment-click/`.

The browser continues to use JavaScriptCore. This change does not establish
complete Node/HTMLCollection or Reddit compatibility.

Local evidence receipts are under ignored `Build/reddit-comment-click/`:
`pending-final-default.json`, `pending-final-none.json`,
`actual-scripts-verified.json`, `production-final-verified-build.json`,
`native-dom-verified.json`, `native-real-thread.json` and `installed.json`.
The two temporary test drivers are preserved there as `*.v.source`, outside
root test discovery. Interrupted diagnostic runs and the overly strict class
string assertion are not counted as passing runs. Private replay HTML/JSON is
not committed.
