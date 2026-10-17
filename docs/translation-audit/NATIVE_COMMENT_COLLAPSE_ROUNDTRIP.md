# Native comment collapse and expand regression

The reported `javascript:void(0)` navigation error is reproduced with native
Cocoa mouse-down/up delivery on a comment control without an `id`. The retained
pre-fix executable changes the address to `javascript:void(0)` and renders
“Unsupported URL scheme”. Evidence is in
`Build/reddit-collapse-roundtrip/before.log` and `before.png`.

The correction combines stable click identity and cancellation (`303edafd`)
with JavaScript URL execution in the active document (`b81f1e53`). Non-string
completions leave that document in place instead of entering the fetch loader.

`main_comment_collapse_roundtrip_test.v` (`a3396b72`) exercises both clicks through Page
pointer delivery, compact handler replay and deferred navigation processing.
The handler returns undefined, matching Reddit's `togglecomment` completion,
so the `javascript:void(0)` default action is exercised rather than canceled.
The test checks that collapse hides both the parent body and nested reply,
expand restores both, the handler runs once per click, and the original
document, address and single history entry survive. Both its default-GC and
no-GC runs pass in `Build/reddit-collapse-roundtrip/focused.log` and `no-gc.log`.

The optimized signed bundle passes native Cocoa collapse and expand checks.
The final screenshots hide and restore both text regions; the post-click native
address remains the fixture URL. `native-result.json` records both successful
window runs and viewport assertions, alongside passing strict/deep signature
verification and headless startup. The original DOM-audit assertion sampled
the document before the delayed click, even though its screenshot already
showed correct collapse. That failed verification is retained in
`native-result.initial.json`; the final checks read the resulting viewport and
post-click address instead. No application change was needed for that repair.

The production build completed with exit zero in an isolated output directory
(`Build/reddit-comment-click/production-final-build.json`). The verified bundle
is installed at `Build/v/Vox.app`; its executable matches the native-tested copy
with SHA-256 `f3ae8743a1d86eee94fd565101d8460ed7a411f9d3ce8f1d294d703e984b2fd5`.
`installed-result.json` records passing strict/deep signing and headless startup
for that installed path. Later concurrent workspace changes are outside this
browser-support verification credit.

All eight SVG bridge guards remain pixel-exact on the same verified executable,
including same-size image source replacement and paint-server mutations.
`svg-result.json` and `svg-guards/svg-guards.log` retain the zero-exit result
and individual zero-difference comparisons.

This is a controlled comment fixture, not live Reddit compatibility credit.
The cached Reddit initializer also fails independently on missing compact DOM
operations: its first observed error is `parentNode.removeChild`, and an
isolated diagnostic shim then exposes incomplete deep-clone/last-child support.
Those failures can leave the site's `togglecomment` undefined. The diagnostic
shim exists only in ignored Build artifacts; it is not installed in the browser.
The retained diagnostics are `initializer-diagnostic.log` and
`initializer-remove-child.log` in the same evidence directory.

Focused browser-support verification does not reset the broad translation
verification cadence or establish full LibJS or live-site parity.
