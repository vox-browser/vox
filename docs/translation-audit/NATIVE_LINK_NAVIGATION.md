# Native link navigation and image responses

The 2026-10-17 correction keeps a concrete destination string, with an explicit
Boehm reachability anchor, alive through compact click callbacks and layout.
The pending navigation slot can then be cleared before replay without losing
the URL. Implementation and the focused lifetime fixture: `aa272ada`.

Before this correction, native Cocoa input on live old.reddit.com followed a
title link into a DuckDuckGo search containing corrupted bytes. The reported
ResourceLoader message is another possible reuse of the same storage. The
retained failing window run is `Build/reddit-link-repro/before-link.log` and
`before-link.png`. The small in-process lifetime fixture passes on both old
and corrected source; it exercises forced collection and resource work, but
is not by itself a failing reproduction of the optimized native-window issue.

The corrected native comments-link capture loads the actual Reddit post with
HTTP 200 at its original comments URL. Seven existing native navigation cases
pass, preserving cancellation and nested-label activation. The new lifetime
case passes in the optimized C-O2 Boehm build, and its default-GC and no-GC
variants also pass. Strict/deep signing verification and headless startup pass.
Evidence is retained under `Build/reddit-link-repro/`, including
`native-navigation-final-v2.log`, `lifetime-optimized-after.log`,
`lifetime-no-gc-after.log`, `after-comments.log` and `after-comments.png`.

The title-link check also exposed the existing non-HTML response fallback
laying out PNG bytes as text; that run timed out after 70 seconds. HTTP image
responses now wrap their already-fetched bytes in a data URL and use ordinary
image decoding and replaced-element painting. The preview fits the viewport,
while the outer document and navigation retain the response URL. HTML and
escaped plain-text response handling are preserved. This compact preview is
not a translation of every upstream image-document behavior.

Image-response implementation and focused tests: `e2574419`. The HTTP fixture
fetches an actual PNG response, preserves the document URL and exact image bytes,
checks decoded natural dimensions and retained image painting, and rejects any
binary-text paint commands. Both response-document cases pass, along with the
existing HTTP navigation cases. The original response-test selection has one
passing file and one failed file because its invalid-MIME fixture incorrectly
expected quotes to be escaped in text content; the corrected fixture preserves
the existing text-context escaping behavior. Logs remain in
`image-document-tests.log` and `image-document-tests-v2.log`.

The final optimized bundle rebuild, strict/deep signing check and headless
startup pass. Repeating the native title click now navigates to the actual
`i.redd.it` PNG URL and captures the decoded image, fitted to the viewport,
with HTTP 200 and two retained paint commands. The process exits normally;
the previous binary-text stall is gone. Final native evidence is
`after-image-preview.log`, `after-image-preview.png` and
`headless-image-preview.log` in the same evidence directory.

These are two additional fixes in this task after starting revision
`43e73b0c`. Focused checks do not reset the broad verification cadence. Only
these browser-support changes receive verification credit; unrelated
concurrent changes and historical ownership inventories remain outside it.
