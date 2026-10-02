# Image decode binding and retained image repaint

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/HTMLImageElement.cpp` (`decode()`, lines 542–645),
`HTMLImageElement.idl`, and the generated `HTMLImageElementPrototype.cpp`
decode binding. The repaint boundary follows `DOM::Document::record_display_list()`
and its display-list invalidation contract.

## Completed source slice

`HTMLImageElementModel.decode()` creates its actual WebIDL capability in the
image's owning settings/realm. The existing typed `dom.Promise` API observes that
same capability directly. Its state and reason are not copied into a second
settlement record.

The initial image microtask, completely-available fast path, original owning
DOM-manipulation settlement task, shared-request batching order, request identity,
and adopted-document activity checks remain in the translated image algorithm.
`EncodingError` now retains an actual `DOMException` record. Request comparisons
use pointer identity rather than structural V equality.

`browserjs.ImageHost` maps actual JavaScript wrappers to the actual DOM image and
its HTML model. It returns the actual JavaScriptCore Promise for the capability.
Each decode call creates a distinct capability. Generated-binding abrupt
completions become rejected Promises, including an invalid receiver; existing
JavaScript exception values retain their identity. Settlement can finish after
Runtime closes without entering a released JavaScript context.

The compact browser installs this host before creating its DOM wrappers and
author scripts. Its former immediate `Promise.resolve()` image decode is removed.
Image attributes reach the same native element and model, including detached
script-created images. Appending those images reuses their existing DOM record.
Decode replays preceding compact DOM mutations before entering the source
algorithm. The existing data/local-file raster decoder supplies actual decoded
frames through the embedding fetch hook; URL presence alone cannot fulfill decode.

Refreshing a retained renderer snapshot now invalidates Document's outer cached
DisplayList before erasing its concrete command vector. Previously a later frame
could return the old wrapper with an empty vector, making an otherwise valid SVG
image disappear. The upstream same-size source-switch fixture now retains green
nested SVG commands through the production BrowserApp layout and frame path.

## Verification

- Image decode lifecycle: six focused cases with `-gc none`, including owning
  realm/jobs, original request identity, and adopted-document rejection.
- Native image host: five focused cases with `-gc none`; the initial four cases
  also passed with default GC.
- Main image decode: two cases with default GC and `-gc none`.
- Full `main_test.v`: 65 cases with `-gc none`, including the updated detached
  decode case, which waits for the actual owning task before expecting fulfillment.
- Exact upstream `svg-image-source-switch-same-size.html`: four actual source
  rendering opportunities through `BrowserApp.relayout()` and DOM replay, with
  retained green vector commands matching direct typed layout. Screenshot capture
  is a separate native bundle check performed from the canonical worktree.

## Remaining boundaries

This slice completes the native decode binding; it does not establish full image
loader or garbage-collection parity.

The existing synchronous HTML image fetch hook and compact raster decoder remain
embedding adapters. The actual FetchController/image-codec asynchronous pipeline,
remote image transport, and complete animation/codec integration are separate
work. The layout adapter already parses and paints isolated SVG documents, but
the actual `SVGDecodedImageData` request completion/frame owner is not translated.
SVG painting continues through that adapter; native decode cannot claim an
available SVG request from those independent painted commands. The compact
image load/complete event snapshot adapter also remains separate from the native
decode capability and needs the source loader/event completion translation.

The pinned decode callbacks use `GC::Weak<HTMLImageElement>` for the
"Image element no longer available" rejection. The current DOM/model ownership
does not provide that collector weak-edge behavior: pending typed callbacks retain
the model, and compact wrappers remain rooted for Runtime's lifetime. Request and
activity failures are implemented and tested; collected-image disappearance must
remain open until the actual weak GC ownership boundary is translated.

The separate inline-document bridge did not contain the immediate decode stub.
It still needs native image wrapper installation to expose this same capability
through that entry point. JavaScriptCore remains the browser engine; this work
does not imply native LibJS image/Promise binding parity.
