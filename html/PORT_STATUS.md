# HTML module V translation — port status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/HTML` (554 files, ~93 kloc
incl. headers; ~73 kloc of `.cpp`).

This tracks the HTML-module translation into `~/code/libweb_v` (the `html` module,
plus HTML-spec Event subclasses that live in `dom` for dispatch-identification
reasons — see `dom/html_events.v`).

## Coverage snapshot

- **Translated with real logic:** ~163 of 261 `.cpp` files (~55 kloc). See the
  `// Translation of …` headers in `html/*.v` and `dom/*.v`.
- **Trivial / no `.cpp` logic (already covered by the stub element structs in
  `dom/document.v`):** the constructor-only element files (e.g. `HTMLDivElement`,
  `HTMLSpanElement`, `HTMLParagraphElement`, `HTMLPreElement`, `HTMLQuoteElement`,
  `HTMLModElement`, `HTMLTimeElement`, `HTMLDataElement`, `HTMLHeadElement`,
  `HTMLMenuElement`, `HTMLParamElement`, `HTMLPictureElement`, `HTMLDListElement`,
  `HTMLDirectoryElement`, `HTMLUnknownElement`, …). Their reflected string
  attributes come from generated IDL bindings, not `.cpp` logic; nothing to port.

## Remaining `.cpp` files with real logic

Grouped by how self-contained they are (dependency-first ordering). "Deps" notes the
untranslated subsystems each pulls in.

### A. Self-contained (portable now, little/no untranslated deps)
- `TextMetrics.cpp` — DONE (`html/text_metrics.v`)
- `External.cpp` — DONE (`html/external.v`)
- `AnimationFrameCallbackDriver.cpp` — DONE (`html/animation_frame_callback_driver.v`)
- `Canvas/CanvasPath.cpp`, `Path2D.cpp` — path geometry math (needs a Gfx::Path repr)
- `Canvas/CanvasState.cpp`, `Canvas/CanvasSettings.cpp` — drawing-state stack
- `SelectItem.cpp` — IPC encode/decode (see note in `selected_file.v` re: IPC scope)
- `ErrorInformation.cpp` — data holder
- `ValidityState.cpp` — BLOCKED: thin wrapper over `FormAssociatedElement`
  (`suffering_from_*()`), which is untranslated (1169 lines)

### B. Event subclasses
- DONE in `dom/html_events.v`: `CloseEvent`, `SubmitEvent`, `ToggleEvent`, `CommandEvent`,
  `PopStateEvent`, `HashChangeEvent`, `PageTransitionEvent`, `StorageEvent`,
  `PromiseRejectionEvent` (promise/reason as opaque `JSValue`).
- DONE in `html/track_event.v`: `TrackEvent`. It references the html-module track types
  (Audio/Video/TextTrack), which can't be named from `dom` (dom→html cycle), so it lives in
  `html` and embeds `dom.Event` directly, setting `EventInterface.track_event`. This
  established the html-side Event-subclass pattern (needs `dom.current_event_timestamp()`,
  now public).
- Still deferred (need untranslated types): `MessageEvent` (MessagePort),
  `NavigationCurrentEntryChangeEvent` (NavigationHistoryEntry), `DragEvent`
  (MouseEvent + `html.DataTransfer`; use the html-side pattern above),
  `FormDataEvent` (XHR::FormData).

### C. Media text tracks (coherent cluster, follows `html/media_tracks.v` pattern)
- DONE — `html/text_tracks.v`: `TextTrack.cpp`, `TextTrackList.cpp`, `TextTrackCue.cpp`,
  `TextTrackCueList.cpp`, `TextTrackObserver.cpp`. These embed `dom.EventTarget` and reuse
  its `event_handler_attribute` machinery for the on* handlers. Added the `enter`/`exit`/
  `cuechange`/`change`/`addtrack`/`removetrack` event-name constants to `html/html.v`.

### D. Medium, host-object-bound (need Window / WorkerGlobalScope / BrowsingContext)
- `BarProp.cpp`, `WorkerLocation.cpp`, `Navigator.cpp`, `WorkerNavigator.cpp`,
  `ValidityState.cpp`, `RadioNodeList.cpp`, `HTMLFormControlsCollection.cpp`,
  `HTMLOrSVGElement.cpp`, `PopoverTargetAttributes.cpp`, `ElementInternals.cpp`,
  `ImageRequest.cpp`, `ImageData.cpp`, `ImageBitmap.cpp`, `BitmapDecodedImageData.cpp`,
  `AnimatedDecodedImageData.cpp`

### E. Large subsystems (deep untranslated dependencies — biggest effort)
- Canvas 2D: `CanvasRenderingContext2D.cpp` (1317), `OffscreenCanvasRenderingContext2D.cpp`,
  `OffscreenCanvas.cpp`, `Canvas/CanvasFillStrokeStyles.cpp`,
  `Canvas/CanvasTextDrawingStyles.cpp`, `Canvas/CanvasDrawImage.cpp`, `CanvasPattern.cpp`
  — deps: Gfx painter
- Navigation: `TraversableNavigable.cpp` (1480), `NavigateEvent.cpp`,
  `NavigationHistoryEntry.cpp`, `NavigationDestination.cpp`, `NavigationTransition.cpp`,
  `NavigationObserver.cpp`, `BrowsingContextGroup.cpp` — deps: Navigable (partial), SHE
- Serialization: `StructuredSerialize.cpp` (1397), `XMLSerializer.cpp` (936),
  `DOMParser.cpp` — deps: JS values / serialization
- Workers: `WorkerGlobalScope.cpp`, `DedicatedWorkerGlobalScope.cpp`,
  `SharedWorkerGlobalScope.cpp`, `Worker.cpp`, `SharedWorker.cpp`, `WorkerAgentParent.cpp`,
  `WorkerDebugConsoleClient.cpp`, `WorkletGlobalScope.cpp`, `ShadowRealmGlobalScope.cpp`,
  `AbstractWorker.cpp` — deps: JS realm/agent, IPC
- Scripting: `Scripting/Environments.cpp` (691),
  `Scripting/{Classic,Module}Script.cpp`, `Scripting/ModuleMap.cpp`,
  `Scripting/{Window,Worker}EnvironmentSettingsObject.cpp`, `Scripting/*` — deps: JS realm
- Messaging: `MessagePort.cpp` (425), `MessageEvent.cpp`, `MessageChannel.cpp`,
  `BroadcastChannel.cpp`, `EventSource.cpp` — deps: IPC / transfer
- Misc: `MediaControls.cpp`, `RenderingThread.cpp`, `UniversalGlobalScope.cpp`,
  `HTMLHyperlinkElementUtils.cpp`, `CrossOrigin/AbstractOperations.cpp`,
  `CrossOrigin/Reporting.cpp`, `NavigatorBeacon.cpp`

### F. Name tables (verify against existing `html/html.v` / `dom` before porting)
- `AttributeNames.cpp`, `TagNames.cpp`, `EventNames.cpp`,
  `CustomElements/CustomElementReactionNames.cpp`

## Dependency-blocker matrix (remaining real-logic files)

A systematic scan of the remaining files' includes for untranslated subsystems. A file is
"clean" only if it touches none of these. Most remaining large files sit behind exactly one
or two subsystems — porting those subsystems unblocks whole clusters, so that ordering is the
fastest path to completion.

| Blocking subsystem | count | representative files |
| --- | --- | --- |
| JS runtime (VM, realm, bytecode, exec-context) | 32 | `Scripting/*`, `StructuredSerialize`, `Navigator`, `Navigation*`, `EventSource`, `BroadcastChannel` |
| LibGfx (painter, path, color, paint style) | 14 | `CanvasRenderingContext2D`, `Canvas/*`, `Image*`, `OffscreenCanvas*` |
| LibURL (WHATWG URL parser + components) | 14 | `HTMLHyperlinkElementUtils` (DONE), `WorkerLocation` (DONE), `NavigatorBeacon`, several `Scripting/*` |
| Navigable / session history | 11 | `TraversableNavigable`, `NavigateEvent`, `Navigation*` |
| LibWeb Layout/Painting | 6 | `CanvasRenderingContext2D`, `RenderingThread`, image data |
| LibWeb Fetch | 5 | `EventSource`, `ImageRequest`, `NavigatorBeacon`, `Scripting/Environments` |
| LibIPC (transfer/serialize) | 3 | `MessagePort`, `SelectItem`, `StructuredSerialize` |
| Threading | 2 | `RenderingThread`, `WorkerAgentParent` |
| `FormAssociatedElement` (untranslated, 1169 loc) | 2 | `ValidityState`, `PopoverTargetAttributes` |

**Genuinely clean & completable now** (only DOM/Infra/already-translated deps):
- `XMLSerializer` (936) — DONE (`html/xml_serializer.v`, 692 loc + tests). Full DOM-Parsing XML
  serialization algorithm. Added `dom` accessors: `Attr_.namespace_uri()/prefix()/local_name()`,
  const `Element.attribute_list()`, `Node.as_document()`. Nullable FlyStrings → the `OptName`
  struct; the `HashMap<Optional<FlyString>, …>` namespace-prefix map → a V `map[string]` with a
  sentinel-encoded key for the null namespace; the `u64&` prefix index → `PrefixIndexCounter`
  (V forbids mutable primitive params).
- `SourceSnapshotParams` — DONE (`html/source_snapshot_params.v`), fetch_client held opaque.
- `AbstractWorker` — DONE (`html/abstract_worker.v`), onerror over the event target.
- `WorkerNavigator`, `Scripting/{SimilarOriginWindowAgent,WorkerAgent}` — reassessed as BLOCKED
  (JS `Agent`, `ServiceWorkerContainer`, `CustomElementReactionsStack` — untranslated).

## Subsystem progress: minimal URL record

`dom.URL` gained WHATWG-URL component accessors backed by `net.urllib` (the "minimal URL record"):
`scheme()`, `username()`, `password()`, `host()`, `serialized_host()`, `port()`, `serialize_path()`,
`query()`, `origin()` (+ existing `fragment()`/`serialize()`), plus `Origin.serialize()`. This
unblocked `WorkerLocation` (DONE, `html/worker_location.v` — held its URL directly since
`WorkerGlobalScope` is untranslated) and `HTMLHyperlinkElementUtils` (DONE,
`html/html_hyperlink_element_utils.v` — all getters + setters as free functions over the element's
href attribute). `dom.URL` also gained component **setters** (`with_protocol`/`with_username`/
`with_password`/`with_host`/`with_hostname`/`with_port`/`with_pathname`/`with_query`) and the
predicates `has_an_opaque_path()` / `cannot_have_a_username_or_password_or_port()`. The setters
approximate `URL::Parser::basic_parse(..., state_override)` by mutating the parsed net.urllib.URL and
reserializing (documented); byte-exact WHATWG parsing would need a real LibURL port.

## Subsystem progress: Canvas 2D (state + path layers)

- `Canvas/CanvasState.{h,cpp}` — DONE (`html/canvas_state.v`): the drawing-state stack
  (`save`/`restore`/`reset`/`is_context_lost`), `FillOrStrokeStyle`, and the full `DrawingState`
  (transform, line/shadow/text/alpha/composite/image-smoothing + the Canvas* IDL enums).
- `Canvas/CanvasPath.cpp` — DONE (`html/canvas_path.v`): the full path-building geometry
  (move/line/quad/bezier/arc/ellipse/arc_to/rect/round_rect) including the ellipse full-circle
  handling and the arc_to tangent-circle math, against a faithful minimal `Gfx::Path` segment
  model (`CanvasGfxPath`). `CanvasAffineTransform` gained `map()` / `inverse()`.
- `Path2D.cpp` — DONE (`html/path2d.v`): embeds `CanvasPath`; copy-constructor and `add_path`
  (copy-transformed + append). The SVG-path-data constructor is a documented FIXME (SVG parser
  untranslated).

Gfx value types (Color, AffineTransform, path segments) are represented directly; `Gfx::Painter`
/`PaintStyle`/`Filter`/font and `CanvasPattern` remain opaque, and curve/arc tessellation and the
actual pixel ops stay painter-side (documented at each site). This is the opaque-Gfx pattern for the
rest of the cluster (`CanvasFillStrokeStyles`, `CanvasTextDrawingStyles`, `CanvasRenderingContext2D`,
offscreen) — those remain, blocked on deeper Gfx/CSS-font/JS-value pieces.

Note: `DOMParser` looks clean by size but is blocked (TrustedTypes + XML parser + Window/global
plumbing). Byte-exact URL setters would need a real LibURL port — `dom.URL` is only a
string wrapper today (no component accessors/setters).

## Conventions (unchanged from existing translations)
- Element algorithms are free functions `html_<element>_<member>(el &dom.HTMLXElement)`;
  cast to the base with `unsafe { &dom.Element(el) }` for attribute access.
- Reflected attributes go through `get_attribute` / `set_attribute_value`.
- HTML-spec Event subclasses live in `dom/html_events.v` and add an `EventInterface`
  enum value in `dom/ui_events.v` (Event, its timestamp helper, and dispatch all live
  in `dom`).
- Use opaque placeholders (`voidptr`, callbacks, forward refs) for subsystems not yet
  translated — do not invent behavior. Keep the `// Translation of …` header.
- Verify with a full workspace build: `v -o /tmp/out .` (compiles every module together).
