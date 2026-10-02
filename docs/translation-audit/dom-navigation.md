# DOM, HTML, navigation and canvas translation audit

Baseline: upstream Ladybird commit `963d46a829f3e1b79f44dba9d02afb70654300fa`, read from `/Users/alex/code/3rd/ladybird`. Repository inspected: `/Users/alex/code/vox2`. Audit date: 2026-10-02.

The V source snapshot is commit `692d54bc642a5ceac601e2f47e7f5e9e6e2d0642`. That documentation-only commit appeared externally while the audit was running and recorded the pre-existing status-document edits; it did not change the implementation being compared. This report adds documentation on top of that snapshot.

The assigned set is **21 C++ files, 63,423 physical lines**: every `Libraries/LibWeb/DOM/*.cpp` and recursive `Libraries/LibWeb/HTML/**/*.cpp` source with at least 1,000 physical lines. This is a source audit with selected algorithm and caller comparisons, not exhaustive branch verification. The requested standard—no stubs, no untranslated logic, and no replacement algorithms—is not met by the verified examples below. Historical authorship cannot be established by reading current source alone; a shorter or differently structured V body is not, by itself, evidence that somebody wrote it from scratch.

No implementation files were changed. Existing `README.md`, `PORT_STATUS.md`, and `libjs/PORT_STATUS.md` edits were left alone. No browser or test suite was run for this documentation-only audit; findings below are source-proven differences, with suggested behavioral checks for subsequent implementation work.

## Coverage and comparison depth

Upstream paths in this table are relative to `Libraries/LibWeb`. Line ranges describe bodies inspected, not a claim that every intervening branch was verified. Repository counterparts are often spread over several packages; callback-backed DOM/layout handles were followed into their concrete implementations before labeling them as missing logic.

| Upstream source | Lines | Actual V counterparts inspected | Comparison depth / result |
| --- | ---: | --- | --- |
| `DOM/Document.cpp` | 11,527 | `dom/document.v`, `dom/document_helper_algorithms.v`, `html/document_parse.v`, `html/navigable.v`, `layout/dom_layout_bridge.v`, `css/dom_css_bridge.v` | Sampled construction 327–470, document write 1004–1048, layout entry/bridges, and unload 5985–6080. Dynamic markup has substantive translated logic; layout handles reach concrete layout. The direct construction method still drops supplied sandbox flags: DN-19. Other construction/performance/partial-relayout branches remain unverified. |
| `DOM/Element.cpp` | 7,032 | `dom/element.v`, `dom/events.v`, `layout/dom_layout_bridge.v`, `dom/scroll_into_view_algorithms.v` | Sampled link target/noopener 438–525, client geometry 3030–3212, visibility 5559 onward, and pointer-lock/capture 6562/6744. Concrete geometry omissions: DN-13. Pointer capture, pointer lock, and CSS zoom are upstream TODOs, not newly missing translations. |
| `DOM/EventTarget.cpp` | 1,102 | `dom/events.v`, `dom/document.v`, `html/activation_behavior.v`, `main.v`, `browserjs/document_bridge.v` | Compared listener registration/removal/dispatch, body-handler targeting, raw handler compilation 588–723 and invocation 868–931. Native click adapter inspected as an alternate caller: DN-01. |
| `DOM/Node.cpp` | 4,226 | `dom/node.v`, `dom/node_inline_algorithms.v`, `dom/element.v`, `dom/document.v` | Sampled pre-insertion validation/insertion 701–1076, live-range mutation, cloning 1601–1669, move/lifecycle handling, and equality 3005–3104. Substantive cloning/registry/shadow-root and mutation algorithms exist. No defect established in those sampled bodies; accessibility and remaining invalidation branches not certified. |
| `DOM/Range.cpp` | 1,416 | `dom/collections_ranges.v`, `dom/selection.v`, `layout/viewport_paint_bridge.v`, `painting/paintable.v` | Compared extraction/cloning/deletion, boundary repair, client rectangles 1218–1368 and contextual-fragment 1370–1414. Glyph rectangles reach retained painting callbacks (`layout/viewport_paint_bridge.v:27`, `:889–947`). No defect established in sampled geometry/mutation bodies; collapsed geometry FIXME is upstream too. |
| `HTML/Canvas/Canvas2DContextBase.cpp` | 1,567 | `html/canvas_rendering_algorithms.v`, `html/canvas_rendering_context_2d.v`, `html/offscreen_canvas.v`, `html/canvas_state.v`, `main.v`, `native_skia_text_darwin.cpp` | Compared stroke/fill 624–713, preparation/metrics 946–1095, shadows 1398–1482, filter state and raster callers. DN-10 distinguishes V API raster limitations from native canvas-text gradient replay. Remote compositor command transport was only sampled. |
| `HTML/EventLoop/EventLoop.cpp` | 1,062 | `html/event_loop.v`, `html/universal_global_scope.v`, `indexeddb/algorithm_operations.v` | Compared rendering filtering/stage ordering 413–535, observer layout loop, microtask checkpoint 814–867, and document ordering 869–939. DN-11 and DN-12. |
| `HTML/FormAssociatedElement.cpp` | 1,624 | `html/form_associated_element.v`, `html/form_elements.v`, `dom/element.v`, `html/element_internals.v` | Compared form-owner reset 357–421, custom-element lifecycle hooks 423–465, reset 163–172, validity delegates and text-control selection/range text around 1000–1210. DN-07; base empty lifecycle hooks also differ for form-associated custom elements. Text editing is substantial, not certified exhaustively. |
| `HTML/HTMLElement.cpp` | 2,681 | `html/html_element_algorithms.v`, `html/html_element_popover.v`, `dom/element.v`, `html/element_internals.v` | Sampled rendered-text getter/setter, offset geometry 771–806, synthetic click 1065–1096, attach-internals and popover show/hide. No concrete defect established in those samples. ARIA role table, all popover stack/reentrancy branches, and remaining IDL properties unverified. |
| `HTML/HTMLFormElement.cpp` | 1,390 | `html/html_form_element.v`, `html/form_elements.v`, `html/form_control_infrastructure.v`, `dom/html_events.v`, `xhr/form_data.v` | Compared implicit submission 91–117, submit pipeline 119–361, reset 362–382, named members and form-data caller. DN-04, DN-05, DN-06. Followed upstream call into `FormControlInfrastructure.cpp` and V caller into its actual simplified entry builder. |
| `HTML/HTMLImageElement.cpp` | 1,698 | `html/html_image_element.v`, `html/shared_resource_request.v`, `html/source_set.v`, `dom/document.v`, `main.v` | Compared decode 542–650, request state/update selection 731 onward, source sets around 1430–1600, dimensions and alternative-text representation. DN-08 is specific to decode lifecycle/timing; source selection and pending-image representation are substantive. Native JS `decode()` adapter also inspected. |
| `HTML/HTMLInputElement.cpp` | 4,120 | `html/html_input_element.v`, `html/form_associated_element.v`, `html/form_elements.v`, `dom/element.v` | Sampled pattern compilation 303–335, reset 2125–2162, activation, type changes/shadow control, validation around 3801–3893 and picker ownership. DN-09 plus reset caller issue DN-05. Other input states/date/number edge cases not certified. |
| `HTML/HTMLLinkElement.cpp` | 1,347 | `html/html_link_element.v`, `css/dom_css_bridge.v`, `html/scripting_fetching.v`, `main.v` | Compared attribute changes 194–301, preload 887–980, stylesheet response 1009 onward and modulepreload 660–750; followed separate local-link style-scope bridge. DN-16. The absent same-type stylesheet object is partly compensated by the local bridge, so it is not treated as proof that all linked CSS is missing. |
| `HTML/HTMLMediaElement.cpp` | 3,346 | `html/html_media_element.v`, `html/media_elements.v`, `html/media_tracks.v`, `main.v` | Sampled play/pause 613–643, seeking 2750–2865, time-marches-on 3211–3300 and playback-manager hooks. DN-14 covers two deterministic media-algorithm differences; decoder/platform completeness was not certified. Text cue TODOs are largely upstream TODOs. |
| `HTML/LocalNavigable.cpp` | 6,642 | `html/navigable.v`, `html/navigation_population_request.v`, `html/local_navigable_downloads.v`, `html/traversable_navigable.v`, `dom/document.v`, `dom/input_method_composition.v` | Sampled download handoff 457–530, history/persisted state around 984–1368, active-document boundaries 1381–1453, composition entry points, scrolling 6275–6606. Download/page and logical-parent bridges are substantive. Smooth-scroll operation/lifecycle missing from inspected V path: DN-15. Cross-process reconstruction and all compositor paths not certified. |
| `HTML/Navigation.cpp` | 1,675 | `html/navigation.v`, `html/navigate_event.v`, `html/navigation_objects.v`, `html/navigable.v` | Compared updateCurrentEntry 155–184, navigate/tracker handling, intercept completion 971–1072 and firing 1074–1394. DN-02. Canonical history UI-process synchronization sampled, not certified. |
| `HTML/Parser/HTMLParser.cpp` | 2,697 | `html/html_parser.v`, `html/html_parser_modes.v`, `html/html_parser_table_modes.v`, `html/html_parser_foreign.v`, `html/html_parser_fragment.v`, `html/incremental_document_parser.v` | Sampled script-end blocking 305–409, encoding change 440–495, fragment setup, streaming decoder callbacks and abort 2286 onward. C++ now delegates tree construction to Rust; V keeps its own translated parser mode bodies. No defect established in those samples; encoding navigation restart is missing upstream too. Remaining Rust-host/parser correspondence requires a separate full audit. |
| `HTML/Scripting/Fetching.cpp` | 1,531 | `html/scripting_fetching.v`, `html/scripting_runtime.v`, `html/module_map.v`, `browserjs/runtime.v` | Compared request/options and module-map completion, graph fetch and link 1448–1530, off-thread/cache adapters. DN-03. Synchronous host fetch/parse callbacks are explicit adaptations; actual module instantiation/linking is not supplied by those callbacks. |
| `HTML/StructuredSerialize.cpp` | 2,613 | `html/structured_serialize.v`, `html/message_port.v`, `html/universal_global_scope.v`, `html/image_bitmap.v` | Compared buffer/view serialization 1190–1321, array/object/error/serializable dispatch around 1340–1639, decoding and transfer implementations elsewhere. DN-17. Same-process shared backing-store preservation exists; transfer methods were found in `html/message_port.v`, not mislabeled absent. Storage envelope/platform-object registry not exhaustively verified. |
| `HTML/Window.cpp` | 2,367 | `html/window.v`, `html/window_context.v`, `html/pdf_viewer_plugins.v`, `main.v` | Sampled open/close/dialog adapters 1129–1480, resolved-style/media queries 1623–1700, named objects 2157–2342, find 2344–2365 and idle callbacks. DN-18. Dialog hooks are legitimate embedding adapters; native application find behavior remains separate from the Window model examined. |
| `HTML/WindowOrWorkerGlobalScope.cpp` | 1,760 | `html/window_or_worker_global_scope.v`, `html/universal_global_scope.v`, `html/timer.v`, `html/error_information.v`, `html/message_port.v` | Sampled base64/clone dispatch, timer throttling 1345–1447, exception reporting 1599–1685, service getters and origin extraction. DN-20 and DN-21. Base64/clone/queuing-strategy methods moved to `html/universal_global_scope.v`; lack of a same-file method is not evidence of missing translation. |

## Verified findings

Finding IDs are local to this audit. **High** means an implemented upstream behavior is absent or observably changed in the compared V entry point. **Medium** denotes a narrower integration/API omission. Unless explicitly stated, these are findings about translated API/model behavior, not a claim that every native-browser route goes through that API.

### DN-01 — Raw inline event handlers become inert callbacks (High)

Upstream `DOM/EventTarget.cpp:588–719` compiles the handler as an ECMAScript function, rejects invalid function bodies, installs document/form/element scope environments, and retains a callable function. `dom/events.v:1186–1220` instead synthesizes `compiled_source_text_` and returns a `handle_event` callback that ignores its arguments and always returns `undefined`. Searching the callback field and compiler helper found no hook that replaces this callback with a JS evaluator; the source-string test checks the text, not execution.

The native application partly bypasses this: `main.v:1395` snapshots `onclick`, and `main.v:1521` explicitly calls `Function("event", s.onclick)` for clicks. That adapter handles click bodies but discards the handler's return value and does not implement the upstream document/form/element lexical environment. Thus a native click test can pass while the translated EventTarget method remains inert, and `onclick="return false"` does not acquire the cancellation semantics through that adapter.

Remediation: install an actual handler compiler/evaluator at this boundary, preserving syntax failure, scope and return-value handling. Check attribute-created `onclick`, another inline event type, invalid handler syntax, and `return false` through both DOM and native adapters.

### DN-02 — Intercepted navigation continues normal navigation and finishes synchronously (High)

Upstream `HTML/Navigation.cpp:971–1072` waits for all intercept-handler promises before finishing, checks document activity and abort state, and reports rejected values through an `ErrorEvent`. `HTML/Navigation.cpp:1388–1394` returns **false** when the event was intercepted, which tells the caller to stop its ordinary navigation path.

`html/navigation.v:391–414` immediately invokes handlers, calls `finish(true)`, clears the ongoing event, and returns **true** even after interception. `html/navigate_event.v:28` types a handler as `fn () !`, and `:255–261` runs it synchronously, so promise-backed waiting cannot occur. `Navigation.navigate()` continues after firing (`html/navigation.v:499–522`) to create/update its own entry. The URL/history update and intercept completion ordering are therefore different, not merely an alternative IPC representation.

Remediation: preserve the intercepted-return contract; use promise-capable handlers, keep the ongoing event until settlement, and retain committed/finished ordering and abort checks. Check an intercepted cross-document navigation, delayed fulfillment, rejection, and a superseding navigation.

### DN-03 — Module linking is represented by a boolean after a fetch walk (High)

Upstream `HTML/Scripting/Fetching.cpp:1485–1503` calls `LoadRequestedModules`, waits on its promise, invokes the module record's `link()` and records its exception. `html/scripting_fetching.v:774–809` recursively fetches imports and sets `module_script.linked = true`; no instantiation/link operation or link-failure callback occurs. `html/scripting_runtime.v:482–487` represents a module record as source text, rather than a runtime module record with exports/import bindings. The public graph wrapper `html/scripting_fetching.v:813–831` reports successful completion on that fetch-walk result.

The runtime alternative does not supply missing linking: `browserjs/runtime.v:102–104` rejects module execution. This is a verified untranslated runtime slice; preserving module-map waiters and descendant fetch options does not establish linking correctness.

Remediation: translate module records/instantiation and link-error propagation, then connect graph loading to them. Check an import of a nonexistent export, conflicting exports and cyclic module graphs, in addition to successful resource fetching.

### DN-04 — Form submission uses a reduced entry-list algorithm (High)

`HTML/HTMLFormElement.cpp:204–210` calls the substantive `construct_entry_list` in `HTML/FormControlInfrastructure.cpp:111–265`. That algorithm skips unchecked checkbox/radio controls, expands select options and selected files, handles image coordinates/custom elements/`dirname`/`_charset_`, and fires a mutable `FormDataEvent` before cloning entries.

The actual V caller is `html/form_elements.v:720`; its builder `:650–663` filters enabled/submittable/name/button and emits one string entry from `control.value()` for every remaining control. There is no checkedness filter, file/option expansion or formdata dispatch in that body. `html/form_control_infrastructure.v:1–122` supplies encoding utilities, not an alternate complete entry builder. `xhr/form_data.v:55–66` and credential-management code call the same simplified builder.

Remediation: route all callers through the translated complete construction algorithm. At minimum check unchecked controls, a multiple select, file entries, image button coordinates and a formdata listener that changes the payload.

### DN-05 — Form reset bypasses the implemented control reset algorithms (High)

Upstream `HTML/HTMLFormElement.cpp:362–382` dispatches reset, copies associated controls and virtually calls each resettable element's reset algorithm. `HTML/HTMLInputElement.cpp:2125–2162` restores checkedness, clears dirty state and files, sanitizes values and updates the editor/shadow tree.

V has a substantive input reset at `html/html_input_element.v:2564` and textarea/select reset methods. However `html/form_elements.v:677–685` holds base `FormAssociatedElement` pointers and calls `FormAssociatedElement.reset_algorithm()` at `html/form_associated_element.v:312–314`, which only assigns the `value` attribute into the base model. There is no subclass dispatch in that caller. It also iterates the live array instead of an upstream copied membership list. Restoring a changed checkbox or editor through form reset therefore misses behavior already implemented in the individual input model.

Remediation: dispatch the concrete input/select/textarea/custom reset algorithms from the form loop, using stable associated-control membership. Check checkbox state, file clearing, textarea display value and selected options after `form.reset()`.

### DN-06 — Submit events lose their submitter interface (High)

Upstream `HTML/HTMLFormElement.cpp:175–188` creates `SubmitEvent` with the submitter button and cancellation/bubbling flags. `html/form_elements.v:711–714` creates a plain `dom.Event('submit')`. The proper V `SubmitEvent` exists at `dom/html_events.v:160–195` but is not used by the form pipeline. This is a missed call-site translation, not an absent supporting type.

Remediation: dispatch the existing `SubmitEvent` with the actual submitter. Check `requestSubmit(button)` and submission from the form itself.

### DN-07 — Form-owner lookup skips an earlier non-form with the same ID (High)

Upstream `HTML/FormAssociatedElement.cpp:388–400` stops at the first HTML element with the matching ID, associating it only if that element is a form. `html/form_associated_element.v:65–76` searches only for matching **form** elements, and `:301–303` uses that result. For `<div id=f></div><form id=f></form><input form=f>`, the V lookup incorrectly picks the later form.

The same file has additional concrete custom-element omissions: upstream `HTML/FormAssociatedElement.cpp:163–172` queues `formResetCallback`; V `html/form_associated_element.v:312–314` assigns a base value. Upstream lifecycle hooks at `HTML/FormAssociatedElement.cpp:423–465` update custom disabled state; the V base hooks `html/form_associated_element.v:177–183` are empty. Upstream `HTML/FormAssociatedElement.cpp:410–413` enqueues a changed owner's `formAssociatedCallback`; the inspected V reset-owner path has no corresponding dispatch. Concrete input/button hooks elsewhere do not substitute custom-element reactions.

Remediation: use first-ID tree-order lookup, then type-check it, and implement the custom reactions. Check duplicate IDs and owner/disabled/reset changes on a form-associated custom element.

### DN-08 — Image decode omits active-document checks and initial asynchronous ordering (High)

Upstream `HTML/HTMLImageElement.cpp:550–650` begins in a microtask, rejects if the document is not fully active, then queues DOM tasks to settle available-image promises. It rechecks document activity and request identity after completion.

`html/html_image_element.v:542–579` immediately returns an already resolved/rejected promise for completed/broken requests and checks neither initial nor completion-time fully-active state. The later batching-dispatcher callbacks preserve some request-state ordering, but cannot replace those lifecycle checks or the initial microtask step. The native bridge is a separate reduced path: `main.v:1500` gives every img wrapper `decode: Promise.resolve()`; this also does not implement request/document-dependent rejection.

Remediation: preserve the microtask entry, document gates, expected-request identity and settlement tasks in both paths. Check inactive documents, request replacement and the already-decoded settlement order.

### DN-09 — Input pattern compilation substitutes V regex semantics (High)

Upstream `HTML/HTMLInputElement.cpp:303–335` compiles ECMAScript regex with `unicode_sets = true`, first validates the unanchored pattern, then wraps it in a noncapturing `^(?:...)$` group. `html/html_input_element.v:748–753` invokes V's different regex engine and uses a capturing `^(...)$` wrapper. The comment explicitly acknowledges missing UnicodeSets. Validation at `:2517–2525` consumes that engine's result.

The current source thus cannot preserve the upstream Unicode property/set grammar or all ECMAScript syntax/matching rules. This is a deliberate runtime substitution, not an upstream regex TODO.

Remediation: connect an ECMAScript-compatible regex backend with the same compile flags and anchoring. Check Unicode property escapes/set operations, invalid patterns, and capture/backreference numbering.

### DN-10 — Canvas path rasterization drops paint-style, blur, filter and stroke semantics (High)

Upstream `HTML/Canvas/Canvas2DContextBase.cpp:624–660` and `:684–709` emit commands carrying full gradient/pattern paint styles, dash/cap/join/miter state, filter and blending. Shadows at `:1398–1482` carry blur and the composed transform.

The translated API path `html/canvas_rendering_algorithms.v:716–742` reduces fill/stroke styles to a color. `html/canvas_state.v:192–195` returns black for gradient/pattern values even though `to_gfx_paint_style()` at `:205–212` retains them. The raster loop `html/canvas_rendering_algorithms.v:689–713` tests distance to each segment; it does not consume dash/cap/join/miter settings. Shadow calls translate the path and draw it sharply, never using `shadow_blur`. Filter parsing at `html/canvas_rendering_algorithms.v:638–646` only retains a string; the inspected path raster execution never consumes it.

This must not be generalized to all native canvas painting: `main.v:1493–1495` records gradient **text** operations, and `:1689–1784` replays them into native Skia with gradient stops. That provides a separate successful gradient-text path. The API path above still lacks the actual upstream operations, and the compact fillRect adapter at `main.v:1490–1495` also converts a gradient object through its color parser. Existing native glyph rendering is a platform adapter; the reduced segment-distance raster is an algorithm replacement requiring review.

Remediation: preserve full styles/state in execution and translate the canvas command semantics, while reusing the native raster backend. Check gradient/pattern path fills, dashed/capped/joined strokes, shadow blur and filtered drawing separately from text screenshots.

### DN-11 — Microtask checkpoints omit their final cleanup steps (High)

Upstream `HTML/EventLoop/EventLoop.cpp:846–863` notifies rejected promises for every related environment, cleans IndexedDB transactions and finishes the VM execution generation after draining microtasks. `html/event_loop.v:679–692` drains its queue and merely clears the checkpoint flag.

Supporting V functions exist: `html/universal_global_scope.v:140` handles rejected-promise notification, `indexeddb/algorithm_operations.v:311` handles transaction cleanup and `libjs/vm.v:912` finishes generations. Searches found no invocation of those services from the translated event-loop checkpoint. Separate VM/interpreter generation calls and separate JavaScriptCore promise behavior do not execute the missing HTML environment/IndexedDB cleanup steps.

Remediation: wire the cleanup operations to the correct related environments/databases/runtime at each checkpoint. Check unhandled rejection delivery and an IndexedDB transaction becoming inactive after its callback task.

### DN-12 — Rendering uses registration order and drops two document filters (High)

Upstream `HTML/EventLoop/EventLoop.cpp:869–939` sorts registered documents so a container document precedes its descendant. V `html/event_loop.v:694–703` filters the registration array without sorting; no navigation-change ordering invalidation or sort exists in that call path. Rendering callbacks therefore rely on creation/registration order even after a document's containing relationship changes.

Upstream rendering filters `HTML/EventLoop/EventLoop.cpp:483–509` exclude documents whose rendering is suppressed for a view transition and navigables without a rendering opportunity. The V rendering predicate `html/event_loop.v:577–579` checks fully-active, decoded-SVG, render-blocked and hidden state only. Its additional per-document combined resize/scroll/media/animation loop at `html/event_loop.v:592–599` also differs from upstream's per-stage loops over all documents. The findings concern actual implemented upstream filters/ordering, not its separate unnecessary-rendering/reveal FIXME steps.

Remediation: implement the ordered active-document set, view-transition suppression and per-navigable opportunity filter. Check reparented/nested documents and suppressed view-transition rendering.

### DN-13 — Element client geometry omits root/quirks and inline exceptions (High)

Upstream `DOM/Element.cpp:3155–3204` gives the standards root/quirks body the viewport dimensions. `dom/element.v:2293–2312` always returns retained content plus padding. Root CSS sizing can consequently change the result that upstream returns from the viewport.

Upstream `DOM/Element.cpp:3105–3151` returns zero for non-box/inline-flow displays and reads visible computed borders. V `dom/element.v:2277–2290` returns retained border values if geometry exists without those display checks. Retained layout attachment in `layout/dom_layout_bridge.v` does not add the missing API conditions. The constant `current_css_zoom()` nearby is an upstream FIXME, excluded from this finding.

Remediation: translate the root/quirks early returns and inline/no-box conditions. Check constrained `<html>` dimensions and an inline span with author borders.

### DN-14 — Media seeking and timeupdate use different algorithms (High)

Upstream `HTML/HTMLMediaElement.cpp:2785–2796` clears seeking and returns if seekable has no ranges, before queuing seeking/seeked. V `html/html_media_element.v:1232–1274` fires seeking before checking ranges, only clamps to ranges when their length is positive, and otherwise continues to update the position, invoke the seek hook or finish the seek.

Upstream `HTML/HTMLMediaElement.cpp:3228–3250` throttles normal-playback timeupdate by monotonic **wall time** and queues a media task. V `html/html_media_element.v:1553–1567` dispatches immediately when the media position differs by at least 0.015 seconds. The comment asserts equivalence, but playback speed, repeated timestamps, discontinuities and burst ticks make the two clocks observably different. Upstream cue-processing FIXME steps are excluded.

Remediation: preserve the empty-range exit and wall-clock/task-based timeupdate scheduling. Check an empty seekable range and rapid playback ticks at non-unit playback rates.

### DN-15 — Navigable scroll promises always resolve after an instant change (High)

Upstream `HTML/LocalNavigable.cpp:6275–6406` honors explicit/computed smooth behavior, coalesces same-destination scrolls, aborts/replaces operations, holds promises until completion and queues scrollend. V `html/navigable.v:2056–2084` clamps/snaps/sets the offset and returns an already resolved promise; its signature does not accept behavior. DOM element scrolling at `dom/element.v:3755–3794` similarly changes retained offsets and resolves immediately.

Scrolling/snapping bridges do exist, so this is not a claim that viewport scrolling is a stub. The missing piece is upstream smooth-operation timing/state and settlement. Platform/compositor transport can legitimately differ, but even upstream's main-thread fallback implements these semantics.

Remediation: translate the scroll operation state machine and completion paths, retaining a platform-neutral main-thread fallback. Check CSS/IDL smooth behavior, replacement by a second scroll, same-target coalescing and scrollend/promise order.

### DN-16 — Live local-link media changes do not refresh the installed sheet (High)

Upstream `HTML/HTMLLinkElement.cpp:252–259` forwards a media attribute change to its live sheet; stylesheet processing `:1009` onward creates a CSS-owned sheet in the correct scope. The V model at `html/html_link_element.v:684–720` retains decoded CSS text only; its media mutation branch `:827–834` updates no stylesheet object.

The separate integration is real: `css/dom_css_bridge.v:660–730` parses local links and installs full CSS sheets with initial media/title/alternate metadata. However its cache key at `:681` includes only resolved URL and CSS text; its change detection at `:693` compares those keys. A later media change with the same resource leaves that comparison unchanged, so `initialize_a_css_style_sheet()` is not rerun and the previous media value stays installed. `style_sheet_for_owner_node()` uses that same sync path. This caller trace rules out reporting all linked CSS as missing while exposing a concrete live-update hole. The cache also excludes title/alternate metadata, but this finding does not certify upstream behavior for those live mutations.

Remediation: unify HTMLLinkElement's loaded sheet with the CSS-owned object and update its live media without relying solely on resource-text cache keys. Check changing a loaded local link's media from matching to nonmatching and back.

### DN-17 — Structured cloning loses resizable ArrayBuffer capacity (High)

Upstream `HTML/StructuredSerialize.cpp:1234–1258` rejects detached buffers and distinguishes resizable buffers, encoding maximum byte length; decoding preserves it. `html/structured_serialize.v:237–268` handles growable shared buffers but always writes the fixed `.array_buffer` tag and bytes for a non-shared buffer, ignoring `StructuredObject.max_byte_length`. Decoding `:662` onward therefore cannot restore resizability.

The buffer view writer at `html/structured_serialize.v:270–286` also lacks upstream out-of-bounds witness validation at `HTML/StructuredSerialize.cpp:1266–1280`, and `StructuredObject` has no detached-state representation. These are limitations of the runtime-neutral object model, not proof that transfer APIs are wholly absent: transfers are implemented in `html/message_port.v:83–161`.

Remediation: translate resizable/detached buffer state and viewed-buffer validation, then connect to real runtime objects. Check cloning a resizable non-shared buffer and a view made out of bounds by resizing.

### DN-18 — Window.find counts DOM source text without selecting a rendered match (High)

Upstream `HTML/Window.cpp:2344–2365` calls the owning Page's find-in-page machinery or next-match operation. The caller at `Page/Page.cpp:1147–1190` gathers document matches and updates actual selection; `DOM/Document.cpp:9741` onward searches the layout arena. `html/window.v:1057–1070` lowercases `descendant_text_content()`, counts occurrences and increments an index. It never calls Page search or sets a selection, and includes raw DOM text such as script/style/display-none descendants rather than following rendered search behavior.

Native application find UI may use its own Page path; that does not make this Window method a translation of the upstream caller.

Remediation: route Window.find through the existing Page search boundary with the upstream case sensitivity/wrap/selection options. Check visible versus hidden/script text and selection movement on repeated searches.

### DN-19 — Direct navigation document construction drops supplied sandbox flags (High, entry-point scoped)

Upstream `DOM/Document.cpp:434–465` installs `navigation_params.final_sandboxing_flag_set`, policy container, about-base URL and a global custom-element registry on the new document. `dom/NavigationParams` carries `final_sandboxing_flag_bits` (`dom/document.v:2122`), but `Document.create_and_initialize()` at `:5251–5281` never installs those bits. Its `run_csp_initialization()` consequently runs against the document defaults. Policy/about-base/registry information is also not represented/copied by this reduced direct constructor.

Another real navigation path at `html/navigable.v:1195–1228` installs sandbox flags/settings independently; that prevents claiming every browser navigation loses sandboxing. It does not repair the direct translated Document entry point. This is a concrete entry-point inconsistency and a source-completeness gap.

Remediation: unify construction through a complete navigation-parameter contract, or make the direct constructor perform the same initialization. Check a document created directly with sandboxed scripts/forms flags and about:srcdoc base metadata.

### DN-20 — Global exception reporting replaces ErrorEvent and changes omitError behavior (High)

Upstream `HTML/WindowOrWorkerGlobalScope.cpp:1606–1685` extracts error metadata, mutes cross-origin script errors, nulls only `error` for omitError, always dispatches the appropriate cancelable `ErrorEvent` unless recursively reporting, and routes an unhandled dedicated-worker error to its owner.

`html/window_or_worker_global_scope.v:771–783` records the supplied value and emits a plain Event only when omitError is **false**. It omits metadata, muted-error handling and worker-owner delivery. `html/error_information.v` and `dom.ErrorEvent` already provide supporting translated types, but this method does not call them. Native console/JS exception handling is a separate embedding route.

Remediation: use the existing error-information and ErrorEvent types, preserve omitError/cancellation and connect worker propagation. Check error fields, muted errors, omitError and worker exceptions.

### DN-21 — Global service getters return empty facades (Medium, API integration)

Upstream `HTML/WindowOrWorkerGlobalScope.cpp:1591–1596`, `:1687–1709` lazily creates functional IDBFactory, Crypto, CacheStorage and TrustedTypePolicyFactory objects. V declares those four global-return types as empty structs at `html/window_or_worker_global_scope.v:88–98`, then returns them at `:800–834`. They do not contain a typed backend object, operations or a service callback.

Separate API packages exist; this finding is specifically that the global getter boundary does not expose those implementations. It must not be read as saying the complete IndexedDB/Crypto/TrustedTypes packages are absent.

Remediation: return or wrap the real translated service objects and preserve per-global identity/settings. Check operations obtained through each global getter, not only direct package-level unit tests.

## Upstream TODOs and legitimate adapters excluded from defects

- `Element::current_css_zoom()` at `DOM/Element.cpp:3207–3211` itself returns 1.0; the V constant is faithful to that upstream TODO.
- Pointer capture at `DOM/Element.cpp:6562` and pointer lock at `:6744–6748` are unimplemented upstream. The translated no-op/rejection does not establish newly untranslated implemented logic.
- HTML encoding navigation restart at `HTML/Parser/HTMLParser.cpp:485–494` is explicitly an upstream FIXME. The V comment at `html/html_parser.v:332` must not be counted as an additional translation failure; the streaming change-encoding callback does implement the supported restart-free path.
- `intend_to_store_in_bfcache = false` at `DOM/Document.cpp:6007–6009` already matches the V unload simplification; that comment alone is not a divergence.
- Link-element source-set update in `HTML/HTMLImageElement.cpp:1450` onward contains upstream `TODO()`. The V comment identifying that branch is not evidence that the img source-set algorithm is missing.
- The DOM CSS/layout/paintable/parser handles are dependency-cycle adapters with real installed callbacks. Labels such as “Layout stubs” in `dom/document.v` are stale descriptions for many of these types, so they were not used as defect evidence.
- JavaScriptCore execution, Cocoa dialogs and native Skia glyph rasterization are explicit runtime/platform adaptations. Their existence does not establish full translation fidelity, but neither does retaining a C/native backend make a source slice a stub. The report isolates the actual lost algorithms and incorrect callback/result contracts.

## Remaining work before certification

For every assigned file, a full function/branch correspondence inventory is still needed, including current upstream Rust ownership/FFI behavior. Add focused behavioral checks to each repaired slice and exercise both its V API entry point and the native script/browser integration where those differ. Existing screenshot successes validate the covered rendered cases; they do not prove the missing event, lifecycle, buffer, form or asynchronous algorithms above. Repository history and provenance review are needed for the independent “no logic written from scratch” requirement.
