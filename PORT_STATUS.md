# LibWeb V translation inventory

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb`

Translation workspace: `~/code/vox2`
Audited: 2026-09-30

## Upstream delta since the V snapshot

The last Ladybird commit on 2026-03-24 is
`1d025620e3344e3cc9aee26fe815d8675e4f9810` ("Everywhere: Move Mach
bootstrap listener into LibIPC"). The upstream checkout used for the current
refresh is `963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11).

The implementation review/translation workload between those commits is
**150,914 added lines in module-owned LibWeb `.cpp` files**. Rewritten and
removed behavior also has to be audited, so the complete implementation churn
is **288,219 lines**. These are physical diff lines and intentionally measure
the upstream review input, not the amount of V code a faithful translation
will produce.

| Diff scope | Files | Added | Deleted | Churn |
| --- | ---: | ---: | ---: | ---: |
| Module-owned LibWeb `.cpp` | 1,309 | 150,914 | 137,305 | 288,219 |
| Root-support LibWeb `.cpp` | 5 | 313 | 684 | 997 |
| All LibWeb headers | 1,442 | 42,247 | 29,692 | 71,939 |
| All LibWeb `.cpp` and headers | 2,756 | 193,474 | 167,681 | 361,155 |

There are 8,152 upstream commits in the range, of which 5,077 touch
`Libraries/LibWeb`. Reproduce the count and the per-module breakdown against
any upstream checkout with:

```sh
python3 tools/upstream_delta.py --upstream ~/code/3rd/ladybird
```

### 2026-09-11 rendering refresh slice

The current refresh translates the upstream behavior exercised by all 24
screenshot cases added after the baseline. It includes animated CSS image
timing and invalidation, single-value background sizing, canvas-to-canvas
ordering, form-control sizing/colors, fieldset clipping, inline-fragment
borders and shadows, adaptive overlay scrollbars, nested and out-of-line SVG
viewports, SVG clipping/patterns/non-scaling strokes and Skia gradient replay,
and FFmpeg-backed video/MSE/canvas frame presentation (including 10-bit YUV).
The comparison driver reads upstream fuzzy metadata and, on macOS only, admits
at most 64 additional sparse Skia CPU edge samples with a maximum channel error
of 20. Exact comparisons remain exact. All 24 new cases pass this bounded
workflow. The complete refresh run also covers the three default smoke cases
and five modified SVG cases: all 32 invocations pass (31 distinct fixtures).
The four CSS Scroll Snap initial-layout reftests also pass with exact zero-pixel
diffs, covering mandatory and proximity selection plus horizontal, vertical-lr,
and vertical-rl writing modes.
Button layout now forwards the button's definite block-size basis through its
anonymous flex and content wrappers. Percentage-height descendants therefore
continue to use the button content height when the content wrapper has a
smaller post-flexing height, including aspect-ratio, padded, fractional, nested,
and resized-equivalent cases.
Structured serialization records now keep a same-process side table for fixed
and growable shared array buffers. Local clones and cloned typed-array views
share one flattened backing store, while records crossing the byte-only IPC
boundary reconstruct an independent shared buffer from their encoded fallback
copy. Maximum lengths and growth remain visible through local aliases; storage
serialization and the default cross-origin-isolation gate still reject shared
buffers.
Custom properties declared in `@keyframes` now participate in animation
sampling. Registered values use typed computed-value interpolation and
composition, unregistered values animate discretely, important declarations
suppress the animation, and missing endpoints use the underlying value. The
sampled overlay is visible to `var()` resolution in longhands, shorthands, and
other animations; target and descendant styles refresh when it changes, while
the ordinary inherited environment remains independently replaceable beneath
the overlay.
Module-preload links now run the translated graph-fetch algorithm with their
typed script-like, style, JSON, or text destination and preserve nonce,
integrity, CORS credentials, referrer policy, parser metadata, and fetch
priority. Successful JavaScript roots start descendant fetching and all module
types populate the reusable module map; failures remove the in-progress entry
so a later import can retry. Media mismatches suppress both fetches and events,
while speculative parser requests preserve the same options but deliberately
leave the module map untouched so intervening CSP metadata remains effective.
Module maps now use the `javascript-or-wasm` type key and store all completion
callbacks in each in-progress entry. Fetch completion atomically installs the
module or removes a failure before notifying every waiter, including when an
implementation fetch hook aborts without a response. Text synthetic modules
expose their decoded source through their sole `default` export.
Dedicated worker termination now invalidates queued and already-scheduled
outside-port deliveries, closes the implicit port, discards the translated
worker event loop, releases its startup keepalive, and removes the owning
`PageClient` worker-agent record. Repeated worker creation and termination no
longer leaves live worker processes or IPC-equivalent state behind.
Meta `color-scheme` discovery now carries the `only` modifier separately from
the supported scheme list. Changing either value advances the document style
environment and schedules media-query and full-style reevaluation, preserving
the opt-out signal consumed by force-dark painting. Full-document parsing
refreshes this metadata after tree construction, so an initial declaration is
available to the first style and force-dark decision. The compact script bridge
also exposes `document.head`, reflects meta `name` and `content` properties, and
refreshes supported schemes after replaying live DOM mutations. A dynamically
inserted `only light` declaration therefore invalidates cached dark paint while
leaving the force-dark page setting intact.
Force-dark display-list resolution now assigns the upstream color roles to
backgrounds, text and shadows, borders, selections, SVG, gradients, markers,
form controls, scrollbars, and resizers. Border and selection resolution sees
the authored backdrop, while automatic focus rings and inspector/debug
overlays remain unchanged. The navigable's thresholds and page opt-out are
applied after recording and before retained commands reach native replay.
Decoded raster replay samples at most roughly one thousand pixels for the
translated palette, luminance, saturation, transparency, and chroma classifier.
Eligible icon and separator frames are cached after per-pixel Oklab inversion;
the CSS-size gate and classifier leave large or photographic images unchanged.
Line-box debugging now records each text fragment's green bounds and red
baseline immediately before its glyphs. The commands remain in the retained
paint cache for inexpensive toggling, are omitted from ordinary display lists,
and carry the explicit no-force-dark role when exposed.
Inline layout now publishes conservative glyph-run painted bounds in CSS pixels
when it finalizes each retained run. Merging, ellipsis, and line clamping dirty
the packed replay data and bounds together; finalization refreshes both once.
Display-list recording scales and positions the cached bounds with ties-to-even
rounding and retains the fragment rectangle separately, so damage and culling
use glyph ink without recomputing font bounds during every recording pass.
Overflow wrapping now follows the upstream shaped-text path.
`overflow-wrap:anywhere`, `overflow-wrap:break-word`, and legacy
`word-break:break-word` split only at extended grapheme boundaries, preserve
UTF-16 offsets and font/edge state across the resulting fragments, and continue
through changing float-intrusion bands. `anywhere` and the legacy value affect
min-content sizing, while `break-word` only supplies emergency breaks at a
definite line width. The textarea UA rule was already current, and the hot path
returns before segmenting text that fits. The four upstream overflow-wrap
reftests are pixel-exact, and the layout corpus gains the float and textarea
cases without regressions. Preserved trailing spaces and tabs now provide the
upstream soft wrap opportunity for following text; the V path distinguishes
them from collapsed whitespace so existing float-band placement stays stable.
An overflowing line now ignores `text-align` and stays aligned to inline-start;
RTL content wider than its block consequently extends to the left, matching the
upstream scrollable-overflow geometry.
Locale-sensitive casing now carries an element's inherited language into the
Unicode case mapper. A live `lang` mutation invalidates cached rendered text and
marks casing-transformed text for layout, so Turkish dotted-I changes appear in
the same update. The CSS/Layout font boundary also reuses last-resort handles
that resolve to the same concrete face, matching upstream fragment identity.
Table width resolution now retains whether `fit-content` had an argument. The
keyword form clamps against the available inline size, while explicit zero
length and percentage arguments clamp to min-content; intrinsic min/max width
constraints also clear the principal table's stale generic-block end margin.
Text shaping now applies computed `word-spacing` to spaces, no-break spaces,
and collapsed line feeds. The exact shaped advance of trailing ASCII whitespace
is retained through fragment merging and intrinsic shape reuse, so line-end
trimming subtracts precisely what shaping added, including text spacing.
Each inline formatting context is also classified before chunk generation.
Provably LTR paragraphs keep neutral punctuation in LTR shaping runs, preserving
contextual positioning and kerning across apostrophes and hyphens, while RTL,
mixed-direction, and `unicode-bidi` content retains per-code-point direction
resolution. This matches the updated `div_align.html` snapshot.
Unicode default-ignorable controls remain in shaped glyph records for UTF-16
bookkeeping but receive zero advance and are omitted from bounds, intercepts,
and retained paint buffers. Non-painting fallback-font fragments no longer
force raw-string replay, and the upstream input-placeholder reftest is exact.
HarfBuzz font scaling now clamps in double precision before conversion to the
library's 32-bit scale. Huge CSS font sizes no longer overflow during intrinsic
text measurement, and saturated cache entries remain separated by point size.
Text shaping now shares the upstream cache boundary across width-only and full
glyph-run consumers. Cached glyphs remain origin-relative and font-independent,
spacing keys compare their exact bit patterns, common single-ASCII shapes use
the dedicated fast path, and the upstream 64-font/16,384-text LRU limits are
enforced without allowing callers to mutate retained cache entries.
Font-face matching now keeps URL sources lazy while a cascade is merely probed
and starts a request only when shaping selects a pending face that covers the
code point. The `font-display` block, swap, and failure periods implement the
`auto`, `block`, `swap`, `fallback`, and `optional` timelines; invisible fallback
retains its ordinary metrics, only the selected pending face is resolved, and
deadline transitions invalidate the owning font computer.
Pending cache/decode font work can defer the document's first paint without
holding later rendering for a network request. The document font computer owns
that decision and exposes the completed/pending result through Internals.
Font-computer invalidation also advances an environment generation. Canvas and
offscreen-canvas drawing state retain the computed cascade behind the `font`
shorthand and refresh it when that generation changes, including cascades saved
and later restored around a font load.
Decoded bitmap transport now identifies row orientation independently from
alpha representation. FFmpeg video and video-backed canvas snapshots stay in
their native top-down order, while the existing Quartz-ordered image path keeps
its one native replay flip.
CSSOM `CaretPosition` and `Document.caretPositionFromPoint()` now consume the
retained text-fragment hit-test offsets, expose a transformed one-pixel client
rectangle, reject points outside the viewport, and retarget positions through
shadow hosts unless the caller explicitly exposes the corresponding shadow
root.
Custom-element state sets now feed the translated selector matcher, so
`:state()` participates in direct selector matching and DOM queries while set
mutation continues to invalidate style.
Cross-parent `moveBefore()` operations now invalidate cached inherited language
through the complete shadow-including moved subtree. The existing subtree
recascade then observes both the refreshed language and V's live parent-derived
directionality, so `:lang()`, `:dir()`, and inherited computed styles follow the
new parent without adding needless invalidation for same-parent reordering.
Slot removal now retains the exact descendant-slot list while unregistering a
subtree from its former shadow root. Each removed slot is reassigned directly,
so nested slots clear their assigned-node lists and light-tree nodes drop stale
`assignedSlot` links after either removal or `moveBefore()`.
Direct CSSOM `StyleSheetList` insertion now keeps an untitled alternate sheet
disabled instead of accidentally matching the initially empty preferred-set
name. Persistent untitled sheets and named alternates selected by a
case-insensitive preferred-set match retain their existing behavior.
Platform input-method sessions now expose the complete composition contract to
page script. `compositionstart` precedes each `compositionupdate` and its
non-cancelable `insertCompositionText` `beforeinput`/`input` pair, with
`compositionend` after the final update. Input, textarea, and contenteditable
paths preserve marked-range replacement, selected starting text, replacement
commits, cancellation, unmarking, event data, and `isComposing`; the V editing
bridge refreshes the marked node after rebuilding contenteditable markup.
Media resource selection now distinguishes automatic selection from an explicit
`load()` call. Paused `preload="none"` media continues to wait and emits
`suspend` during automatic selection, while `load()` starts the fetch; changing
preload/autoplay or calling `play()` resumes a deferred fetch. The explicit
selection marker survives resumption after document adoption and is cleared
before the next automatic selection.
The native `load()` operation now validates the actual DOM receiver before
mutation replay and calls that same model, preserving unused-argument and
exception behavior. Reset abort, emptied and timeupdate events wait for the
owner's task queue; the current unpaused pending play batch rejects with one
actual AbortError under its Document execution context. State and validated
default-rate reset commit before delivery. Stable-state selection, full load
resets and physical playback remain unfinished. See
[load task and native caller evidence](docs/translation-audit/MEDIA_LOAD_TASK_OWNER.md).
First decoded-data notification now queues `loadeddata` once per load on the
actual media owner. Explicit and automatic load entry rearm its flag; the exact
nonempty-network metadata-to-data branch consumes it and synchronously releases
the owner's current Document load delay. Buffering oscillations do not repeat
the event, and adoption preserves token ownership. Other readiness events,
full resource timing and physical decoding remain unfinished. See
[first-data task and delay evidence](docs/translation-audit/MEDIA_LOADED_DATA_OWNER.md).
Metadata notification now queues `loadedmetadata` from the exact nonempty-network
nothing-to-metadata readiness transition. Fetched responses and MediaSource
initialization share the actual owner's branch. Fetch listeners receive metadata
after durationchange and before loadeddata, and read live state at delivery.
Reload cancels only that owner's old notification. Full resource timing and
physical decoding remain unfinished. See
[metadata task and caller evidence](docs/translation-audit/MEDIA_METADATA_TASK_OWNER.md).
Canplay notification now queues on the actual media owner at the exact
nonempty-network current-or-less to future/enough readiness crossing. First-data
notification precedes canplay, and its readiness-driven playing task follows.
The original pending play batch and start position are captured before listeners
can call play(); manager start remains immediate. Reload cancels only the
owner's old event, and later tasks use its adopted Document and active delivery
check. Full readiness/autoplay and physical decoding remain unfinished. See
[canplay task, promise and caller evidence](docs/translation-audit/MEDIA_CANPLAY_TASK_OWNER.md).
Canplaythrough notification now queues on each changed nonempty-network
transition into enough data, after any first-data, canplay and readiness-driven
playing tasks. The original pending promise batch resolves before this event;
future-to-enough queues only canplaythrough. Listeners observe live readiness,
reload cancels only the owner's old tasks, and later tasks use its adopted
Document and active delivery check. The actual SourceBuffer coded-frame caller
also enters this branch. Enough-data autoplay substeps, buffering-drop waiting,
complete resource/readiness/seek and physical decoding remain unfinished. See
[canplaythrough task and caller evidence](docs/translation-audit/MEDIA_CANPLAYTHROUGH_TASK_OWNER.md).
Autoplay eligibility now checks the automatic-features sandbox flag of the
actual audio/video owner's current Document. Sandboxed autoplay plus
`preload="none"` remains deferred, while explicit `load()` fetches without
starting playback. Adoption and later sandbox changes consult live ownership.
Permissions Policy and enough-data autoplay boundaries remain. See
[autoplay sandbox and caller evidence](docs/translation-audit/MEDIA_AUTOPLAY_SANDBOX_OWNER.md).
Resource autoplay now uses is_allowed_to_play through the current Document's
sticky Window activation, origin settings and effective volume, including actual
Page mute. Consumed transient activation retains sticky permission. Allowlisting
and the file exception follow the existing settings translation; adoption reads
the new Document and Window. Explicit load fetches blocked media without
autoplaying. The complete enough-data autoplay branch remains unported. See
[playback permission and resource caller evidence](docs/translation-audit/MEDIA_PLAYBACK_POLICY_OWNER.md).
The public V model play caller now rejects a denied request with a typed
NotAllowedError before checking unsupported media or entering internal play.
Denial preserves owner state and older pending promises, performs no fetch and
queues no play tasks. The current Document supplies permission after adoption.
Native exception conversion preserves record/wrapper identity. See
[model play permission evidence](docs/translation-audit/MEDIA_PLAY_PERMISSION_OWNER.md).
Volume and muted changes now queue volumechange before checking current
Document playback permission. Denial enters internal pause immediately, then
updates effective volume; timeupdate/pause and captured model-promise rejection
remain deferred in order. Already-paused blocked owners disable autoplay without
fetching. Page-wide mute retains its separate update-only path. Native volume/
muted setters reach this actual owner helper. Complete media algorithms remain
open. See
[volume-change policy evidence](docs/translation-audit/MEDIA_VOLUME_POLICY_OWNER.md).

Permitted V play now rejects MEDIA_ERR_SRC_NOT_SUPPORTED with a fresh typed
NotSupportedError carrying the actual MediaError message. Permission denial
still precedes that check; rejection leaves earlier requests and owner state
intact. Native conversion preserves exception identity and Unicode/NUL messages.
See [unsupported play evidence](docs/translation-audit/MEDIA_PLAY_SOURCE_ERROR_OWNER.md).

Native JavaScript `play()` now returns a real Promise backed by the actual
DOM media owner's WebIDL capability. Parsed and created media inherit that
native method, with the generic fulfilled stub removed. Binding failures reject
with their original reason; waiting requests settle through the owner's existing
playing, pause, load and ended batches. Selection and MediaSource failures now
carry typed NotSupportedError records, and ended rejection uses AbortError,
under the current Document execution context. All 17 new cases pass within
24/24 selected files in both GC modes. Signed production startup, an ordinary
native probe, two exact play viewports, 14 exact SVG preservation pairs and all
11 configured smoke cases pass. The pinned load FIXME for already-captured
canceled-task batches remains pending; complete resource/readiness/seek/MSE,
Permissions Policy, enough-data autoplay, physical decoding and automatic
ownership remain open. See
[native play promise evidence](docs/translation-audit/NATIVE_MEDIA_PLAY_PROMISE_OWNER.md).

Ordinary audio/video listener registration now inherits the installed native
EventTarget method after successful compact media binding. Registration,
removal and dispatch share the actual DOM owner, including parsed and created
media, trusted queued events and the existing play-promise settlement order.
Listener identity, capture-sensitive removal, once and object callbacks use the
existing native machinery. Late registration on a ready frame creates no fake
loadeddata/seeked callback. Actual Page pointer release delivers one trusted
media click before compact replay and preserves cancellation; image, object
and SVG compact paths remain covered. All six new cases pass within 19/19
selected files in both GC modes. Signed startup, the active ordinary production
probe, two exact listener viewports, 14 exact SVG pairs and all 11 configured
smoke cases pass. General nonmedia EventTarget, handler attributes, complete
media interfaces and Cocoa/input hit-testing parity remain open. See
[ordinary media listener evidence](docs/translation-audit/NATIVE_MEDIA_EVENT_LISTENER_OWNER.md).

Script-assigned onplay/onpause/onloadeddata and 20 other media handlers now
reach the actual DOM owner through native accessors. Parsed and created media
preserve callback identity, listener-slot order and trusted queued event/Promise
order. The shared LegacyTreatNonObjectAsNull conversion retains any object and
skips noncallable invocation without reading handleEvent or entering callback
contexts; primitives clear the handler. All ten new cases pass within 24/24
selected files in both GC modes. Signed startup, an active ordinary production
probe, two exact handler viewports, 14 exact SVG pairs and all 11 configured
smoke cases pass. Raw inline element compilation, onclick/general HTMLElement
handlers, full prototype placement, foreign realms and weak ownership remain
open, along with the pinned load captured-task FIXME and full media/physical
decoding. See
[native media handler evidence](docs/translation-audit/NATIVE_MEDIA_EVENT_HANDLER_OWNER.md).

Script-assigned media onpointerdown/onpointerup/onmousedown/onmouseup now
reach actual DOM handler records. Parsed and created owners preserve identity,
slot replacement and trusted Page press/release order. Pointerdown false
suppresses compatibility mouse events until release while preserving click;
mouseup false does not block click, and compact replay adds nothing. All five
new cases pass within 18/18 selected files in both GC modes. Signed startup,
an active ordinary probe, two exact pages, 14 exact SVG pairs and all 11 smoke
cases pass (eight exact). Explicit-target Page fixtures do not establish Cocoa
transport, hit testing or full input-interface parity. Raw inline compilation,
onclick/other handlers, full prototype placement, realms, weak ownership and
the pinned load/full media/physical decoding boundaries remain open. See
[press/release evidence](docs/translation-audit/NATIVE_MEDIA_POINTER_HANDLER_OWNER.md).

Script-assigned media onclick now reaches the actual HTML audio/video
owner's native handler map. Callback identity, listener slot order, trusted
Page delivery and false cancellation use existing source algorithms. Private
Event/Page receipts are compact adapter bookkeeping: an already-processed
native handler cannot trigger stale raw replay after self-mutation. Replay
reads current DOM raw text after flushing compact mutations and uses a stable
bridge key; generic image/object/SVG paths remain intact. Raw fallback still
uses a plain compact Event and Function, leaving real inline compilation open.
Implementation and eight focused cases: `8c567b08`. The unchanged parent
baseline compiles the native/main files and fails six functions; the two Page
tests require new APIs and are unexecuted on that baseline. All eight cases
then pass, and 22/22 selected files pass in both GC modes. Signed startup,
the active optimized probe, two exact pages, 14 exact SVG pairs and all 11
configured smoke cases pass (eight exact).

Explicit-target Page fixtures do not establish Cocoa transport, hit testing
or complete input interfaces. Full prototype placement, other handler
attributes, foreign realms, weak ownership, full/physical media and the pinned
load captured-task FIXME remain separate work.
[Native click evidence](docs/translation-audit/NATIVE_MEDIA_CLICK_HANDLER_OWNER.md).

Media onauxclick and ondblclick now share actual audio/video native
handler slots. Primary dblclick follows click even when click is canceled;
its own cancellation does not change the primary activation result. Middle/
right auxclick uses exact false cancellation, while zero permits activation.
Parsed/created owners preserve identity, handler order, self-replacement and
exception reporting. Existing primary receipts suppress same-release raw
onclick installed by a throwing dblclick callback. Implementation adds only
two names to the selected handler list; main/Page/dispatcher/bootstrap remain
unchanged. Implementation and five cases: `5ba4d87c`. Parent baseline compiles
both files and fails all five initial descriptor guards, leaving later Page
assertions unexecuted there. Final bytes pass focused/ordinary optimized tests,
and 25/25 selected files pass in both GC modes. Signed startup, two exact
synthetic-Event pages and all 11 configured smoke cases pass (eight exact).

Actual trusted Page fixtures supply explicit DOM targets/buttons/counts;
synthetic-Event pages supply separate browser binding coverage. Physical Cocoa
input/hit testing, platform double-click recognition, full input fields and
prototypes, raw inline compilation, foreign realms, weak ownership, full media/
physical playback and the pinned load captured-task FIXME remain open.
[Auxiliary handler evidence](docs/translation-audit/NATIVE_MEDIA_AUXILIARY_HANDLER_OWNER.md).

Media onpointermove and onmousemove now share actual audio/video native
handler slots. Existing Page dispatch delivers pointermove then compatibility
mousemove. Pointermove false alone still permits mousemove; mousemove false
controls the canceled result, while zero permits it. Canceled pointerdown
suppresses compatibility moves until release, preserves click and restores
the next pair. Parsed/created owners keep identity/order, self-replacement,
null/reactivation, original thrown-object reporting and live DOM polling.
Implementation adds only two names; main/Page/dispatcher/bootstrap and click
receipts remain unchanged. Implementation and five cases: `e5ae9afb`. Both
parent files compile and all five functions stop at their initial descriptor
guards; later Page assertions run only after installation. Identical final
bytes pass focused/ordinary optimized tests, and 27/27 selected files pass
in both GC modes. Signed startup, two exact synthetic-Event pages and all
11 configured smoke cases pass (eight exact).

Trusted Page fixtures supply explicit native DOM targets; synthetic Event
pages provide separate browser binding coverage. That handler slice validates
the base Event surface; the later owner-local MouseEvent binding exposes
inherited mouse fields. Node-less InputTarget logging remains a separate
fallback. `Page.handle_mousemove()`
ignores button-mask/modifier arguments and does not install complete client
coordinates; these tests establish no field parity. Physical Cocoa transport/
hit testing, full prototypes, raw inline compilation, foreign realms, weak ownership and
full media/physical playback/load captured-task boundaries remain open.
[Movement handler evidence](docs/translation-audit/NATIVE_MEDIA_MOVEMENT_HANDLER_OWNER.md).

Window-owned runtimes now expose the inherited UIEvent binding over
actual native records: constructor, view/detail/dynamic which and legacy
initUIEvent. Native accessors and initializer preserve IDL metadata, brands,
conversion order and dispatch-time no-op after argument conversion. Actual
Page media callbacks retain native identity, owning view, current-event state,
cancellation and DOM polling. Late Window attachment preserves the original
Event parent and actual global; known UI-family wrappers use a retained
prototype. Implementation and six cases: `d1b86d81`. Both parent files compile
and all six initial UIEvent guards fail there; later assertions remain
unexecuted. Final bytes pass focused and ordinary optimized tests, and 12/12
selected files pass in both GC modes. Signed startup, two exact synthetic
UIEvent pages and all 11 smoke cases pass (eight exact).

View mapping is explicitly owner-local; foreign WindowProxy wrappers are
unsupported. Trusted Page fixtures use explicit targets and platform values,
and expose existing record data rather than full input construction parity:
pressed compatibility moves retain the V mousedown detail and supplied button;
upstream normal mousemove supplies zero detail and primary. Other concrete UI
subclass constructors/prototypes/fields, Page mousemove argument/coordinate
mapping, physical Cocoa input/hit testing/default actions, raw inline element
compilation, foreign realms and weak ownership remain open, along with full
media/physical playback and the pinned load captured-task FIXME.
[UIEvent evidence](docs/translation-audit/NATIVE_UI_EVENT_OWNER.md).

MouseEvent-family related targets now use the base Event state that dispatch
retargets for each listener and clears at shadow boundaries. Construction,
legacy initialization, current-state clones and trusted hover agree with that
canonical slot, including inherited DragEvent records. Six focused cases
compile and fail actual assertions on the parent, then pass with final bytes;
12 selected files pass in both GC modes and the new cases pass optimized.
Signed startup and all 11 existing smoke cases pass (eight exact). The actual
Window-owner fixture in that core slice uses a private native observer. The
later owner-local MouseEvent binding supplies its public constructor/getters;
the later PointerEvent binding completes that concrete owner-local
surface; the later WheelEvent binding supplies its own interface.
DragEvent remains open.
[Related-target evidence](docs/translation-audit/MOUSE_EVENT_RELATED_TARGET.md).

Window-owned runtimes now expose MouseEvent's constructor, nineteen native
getters and getModifierState/initMouseEvent. Actual mouse-derived records
inherit the retained UIEvent/Event chain, with source dictionary/legacy
conversion, virtual PointerEvent coordinates and canonical relatedTarget.
The owner-local constructor observes newTarget.prototype once and uses the
original interface fallback; omitted dictionaries preserve their empty default.
Implementation/new tests are committed as db342c95. Six focused cases match
those bytes, and ordinary optimized cases pass there, together with signed
startup, two exact synthetic untrusted MouseEvent pages and all 11 smoke
cases (eight exact).

Final 14/14 default and GC-disabled batches run at a03691e5, which changes only
an existing test's capture from the local Runtime pointer variable's address
to the actual Runtime. All binding/new-case bytes remain identical. The first
default failure and seven isolated diagnostics remain recorded separately;
labels prove the wrong capture but do not establish a host-GC or nil-context
causal mechanism. The later PointerEvent binding supplies that concrete
owner-local interface. The later WheelEvent binding supplies its own
constructor/prototype/fields. DragEvent,
foreign views/realms, weak ownership, complete Page input construction
and physical Cocoa input/hit testing/default actions remain open.
[MouseEvent evidence](docs/translation-audit/NATIVE_MOUSE_EVENT_OWNER.md).

Window-owned runtimes now expose PointerEvent's constructor, thirteen native
getters, getPredictedEvents() and secure-owner getCoalescedEvents(). Native
Pointer records use their retained prototype above MouseEvent/UIEvent/Event;
all inherited coordinate overrides and canonical relatedTarget remain live.
Forty-three dictionary members convert in inherited lexical order, including
restricted doubles/floats, signed integers, optional independent angle/tilt
defaults and genuine iterable PointerEvent sequences. Sequence operations
return fresh Arrays preserving native child identity. The pinned generator's
abrupt sequence path does not perform IteratorClose; this is an explicit
source boundary. Secure exposure follows existing owning settings.

Implementation c9dc0da2 contains only nine root/browser feature paths and
retains the independent preceding CSS commit 7c3576ec. Ancestral baseline and
focused records use feb97f38: both new files compile there and all seven initial
availability guards fail; seven focused cases pass with the same final test
bytes. Later parent assertions are unexecuted. All 17 files pass both GC modes,
and seven ordinary optimized cases pass at c9dc0da2. Final private production
verification passes ten stages at c9dc0da2, with two pixel-exact untrusted
Pointer pages and all 11 smoke cases (eight exact). The retained private image
and dylib belong to the final artifact closure. The records freeze 5,003 source
hashes, 47 selected / 154 production references, 66
current artifacts and 1,859 prior artifacts. Earlier Rust-PATH and post-run
shared-binary overwrite observations receive diagnostic credit separately.

The validated source is an isolated checkout inside this canonical repository,
pinned to c9dc0da2. Later canonical Layout edits and their new regression are
preserved separately and are outside this proof. Element pointer capture,
touch/pen and hardware sampling/prediction, concrete DragEvent interface,
foreign views/realms, weak ownership and complete Page/physical input remain
open. The browser continues to use JavaScriptCore.
[PointerEvent evidence](docs/translation-audit/NATIVE_POINTER_EVENT_OWNER.md).

Window-owned runtimes now expose WheelEvent's constructor, seven native
getters and three delta-mode constants over actual records, inheriting
MouseEvent/UIEvent/Event. Thirty-four dictionary members convert in
inherited lexical order; restricted doubles, wrapped integers and native
round-to-even legacy fallback preserve the pinned source. Initial/late
owner exposure, wrapper identity, relatedTarget and inherited initializers
remain live. Five native and two owner cases pass focused and optimized;
all 20 selected files pass in both GC modes at 813dd838. Final production
exits nine steps, with eight fresh checks and ten logical checks including
the explicitly verified retained -prod -gc none build: strict signing/startup,
two exact pages and 11 smoke cases (eight exact). The failed media
onwheel probe preserves 43 artifacts. That failed page receives no pass
credit; final native listener pages use the same frozen private signed image.
The closure retains 102 current / 1,960 prior hashes. Factory/DOM
owner dispatch establishes synthetic native bindings; physical Cocoa/Page
wheel delivery/default scrolling and compact media onwheel remain open,
alongside DragEvent, foreign realms and weak ownership. Later concurrent
canonical work remains outside the isolated source pin.
[WheelEvent evidence](docs/translation-audit/NATIVE_WHEEL_EVENT_OWNER.md).

Window-owned runtimes now expose DragEvent's constructor and sole native
dataTransfer getter over actual HTML records, inheriting
MouseEvent/UIEvent/Event. Twenty-nine dictionary members convert in inherited
lexical order. Null defaults and genuine owner-local DataTransfer brands
preserve native identity without inspecting author properties or Proxies. The
separately committed bounded identity prerequisite is 6296e27c; it adds no
public DataTransfer constructor or operations. The HTML constructor now
creates an untrusted record; internal create behavior, dispatch and inherited
initializer preservation remain intact.

9 focused and optimized DragEvent cases pass; 3 identity cases pass in both GC
modes. All 21 selected files pass in both GC modes at 682a7827. Private
production completes 10 stages: signed startup, two pixel-exact null-transfer
pages and all 11 screenshot smoke cases. Genuine nonnull transfer identity is
established by the focused native/actual-owner tests. Interrupted initial test
and production attempts remain preserved without pass credit; detached
supervisors record the completed terminal exits. A separately archived
verification-only dispatcher-path correction changes no implementation or test
result. The verified closure retains 70 current / 2,087 prior artifacts.

This completes the pinned owner-local DragEvent interface. Public DataTransfer
operations, DataTransferItem/List/file exposure, media ondrag handlers,
physical Page/Cocoa drag generation, store-mode transitions and default
actions remain open, alongside foreign views/realms and weak ownership.
JavaScriptCore remains the browser engine. The frozen production source uses
its historical Ladybird bundle name; current Vox branding and later concurrent
work are outside that validation pin.

[DragEvent evidence](docs/translation-audit/NATIVE_DRAG_EVENT_OWNER.md).

Window-owned JavaScriptCore runtimes now expose native DataTransfer
construction, dropEffect/effectAllowed, getData/setData/clearData and frozen
types over actual HTML stores. Existing owner-local wrappers gain the public
prototype without changing identity. UTF-16 preserves NUL and lone surrogates;
type arrays cache by native record, revision and runtime. The `b335958e`
source passes nine focused/optimized cases, thirteen selected files in both GC
modes, signed startup, two pixel-exact nonnull-transfer pages and eleven
screenshot smoke cases. Public item/file-list and drag-image surfaces,
physical drag delivery, store transitions/default actions, foreign realms and
weak ownership remain open. See [DataTransfer string-store
evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_STRING_OWNER.md).

Window-owned DataTransfer now exposes its native read-only files getter over
existing FileAPI owners. The pinned implementation and generator return fresh
FileList/File snapshots despite the IDL SameObject annotation; old snapshots
retain their bytes after store/mode changes. Native receiver branding precedes
FileAPI dependency lookup. At `b59e211c`, seven new and twelve focused cases
pass, fourteen selected files pass in both GC modes, and seven optimized cases
pass. Signed startup, two pixel-exact genuine empty-list pages and eleven
smoke cases pass. Nonempty files use focused native owner tests. Public items,
drag images, hardware file delivery and weak/foreign ownership remain open.
See [DataTransfer files
evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_FILES_OWNER.md).

The `:indeterminate`, `:open`, and `:closed` selectors now read live checkbox,
input-picker, and select-picker state. Control transitions mirror that state at
the DOM boundary and schedule style invalidation; `switch` checkboxes retain
the current upstream exclusion from `:indeterminate`.
Rich clipboard HTML is now parsed as an inert contextual fragment before use.
The translated sanitizer removes active elements, event handlers, `srcdoc`,
and JavaScript URL attributes while preserving ordinary markup, inline styles,
and safe relative, network, and data URLs.
Plain-text clipboard serialization now follows rendered structure: it omits
hidden, unpainted, and `user-select:none` text; emits paragraph, explicit-break,
table-cell, and table-row separators; includes rendered image alternative text;
and slices text at UTF-16 range boundaries. Navigable copy and cut selection
text use this shared serializer.
Rich clipboard serialization now clones the selected rendered tree, preserving
`display:contents` and inline markup while omitting hidden subtrees and clipped
transport-only wrappers. Partial text selections retain exact UTF-16 endpoints,
and navigables expose the resulting HTML alongside their plain selected text.
The interchange-whitespace translator now classifies ASCII-whitespace text and
rebalances collapsible space/newline runs into ordinary-text and protected-space
tokens. Rich clipboard serialization applies those tokens as span-wrapped
non-breaking spaces while retaining verbatim text whose computed
`white-space-collapse` mode is non-collapsing.
When a cloned fragment contains only sibling list items, rich clipboard
serialization now restores their shared `ol` or `ul` ancestor, including its
authored attributes.
Empty selected list items at fragment edges are now encoded as
`Apple-interchange-newline` markers inside the following item or after the
list, preserving their rendered paragraph boundaries for rich paste.
Partial selections inside one text node now materialize computed color,
background, font, and text-decoration differences from the editing host on a
clipboard span, retaining formatting that range cloning alone cannot carry.
Legacy single-`font` runs can now be removed or converted to inline color
spans, including quirks-mode legacy color parsing and preservation of text-run
seams. Rich clipboard serialization uses the rendered source color and keeps
protected whitespace runs independently styled.
Replacement fragments now consume rich-clipboard transport markup: they remove
top-level formatting whitespace and trailing interchange markers, retain a
leading marker as structural state, unwrap protected-space spans, prune empty
inline staging wrappers, protect external edge whitespace, and classify text-
only and block-containing fragments before insertion.
Inserted-fragment tracking now retains its connected top-level nodes, nested
text nodes, first and last structural extent, leading text shape, and terminal
atomic content while replacement preparation moves or substitutes nodes.
Independent mutation-tracked ranges now own replacement start and end points.
Their endpoints follow ordinary DOM mutation and explicitly relocate across
left-to-right and right-to-left text-node merges without range-order coupling.
Inserted-content tracking now combines structural nodes, the mutation-adjusted
destination seam, replacement topology, semantic content endpoints, terminal
atomic content, paragraph-integration state, and whitespace context throughout
fragment insertion and completion.
Editing DOM moves now preserve the active selection and internal mutation-
tracked ranges using Ladybird's boundary relocation rules. Wrapper removal uses
the same path, retaining selection and replacement seams while children are
hoisted into their parent.
Paragraph-boundary splitting now exposes text positions outside text nodes,
clones inline ancestor chains around interior boundaries, avoids empty clones at
wrapper edges, and moves the paragraph suffix into a shallow block clone.
Inline insertion preparation now advances equivalent trailing-edge caret
positions, identifies the highest modifiable destination style, splits that
inline chain for independent pasted styling, and defers list destinations to
the dedicated list-item path.
Paragraph transfer now moves or unwraps source paragraph children at a mutation-
tracked destination, applies explicit legacy-font style policy, removes the
source wrapper, and optionally coalesces the destination text seam while
returning the semantic moved range.
Visible editing positions now retain distinct script-visible and canonical
caret boundaries, delegate movement and extension canonicalization to the
translated caret navigator, scan rendered text and paragraph breaks, and
distinguish true block edges from carets beside atomic inline layout boxes.
Caret navigation now discovers text and atomic hosts from retained layout,
uses rendered line ownership for cross-node equivalence, recognizes empty-line
breaks from their containing block, and no longer joins caret positions across
separate block lines merely because they share an editing host.
Paragraph integration now decides both inserted seams from rendered visible
positions before mutation, respecting original paragraph-aligned selections,
list and table-cell context, heading compatibility, blockquotes, atomic caret
anchors, and empty transport paragraphs.
Replacement-range completion now coalesces both text seams while relocating
semantic endpoints, normalizes only interior protected clipboard spaces,
repairs integrated-paragraph whitespace, removes empty modifiable wrappers,
and preserves terminal atomic and empty-container caret boundaries.
Replacement-style cleanup now compares the destination cascade with and without
each inserted inline declaration, removes redundant longhands while preserving
custom properties, and unwraps empty style-only spans without disturbing live
selection or replacement ranges.
Block replacement planning now chooses split, after-block, internal-paragraph,
list-item, and empty-block insertion paths from rendered caret boundaries, and
integrates a pasted list into a matching destination list without losing the
tracked inserted extent.
Trailing interchange newlines now advance replacement carets into the retained
destination suffix, preserve genuine empty terminal paragraphs, and materialize
or enter the correct following list item at list boundaries.
DOM insertion seams now canonicalize collapsible and protected spaces across
inline wrappers, stop at atomic clipboard content, and leave preserved
white-space runs untouched.
Collapsed inline selection replacement now inserts prepared fragments through a
mutation-tracked range, splits destination formatting chains, removes redundant
transport styles and empty block props, normalizes both whitespace/text seams,
and collapses the live selection at the semantic inserted endpoint.
Collapsed block selection replacement now executes the planned split, after-
block, internal-paragraph, list-item, and empty-block paths; integrates matching
lists and eligible paragraph seams; preserves destination suffix whitespace and
trailing breaks; and finalizes the live caret through the shared cleanup path.
Inline replacement now validates every pasted descendant against its live HTML
ancestors after insertion. It applies the complete editing allowed-child table,
splits illegal inline, paragraph, anchor, and heading wrappers while preserving
ranges, wraps orphan definition items, and converts otherwise orphaned
paragraph-prohibited elements to the document's default single-line container.
Reversible edit commands now cover node insertion/removal, UTF-16 character-
data replacement, text splitting, attribute changes, fragment expansion, and
range insertion. Undo and redo replay the original nodes only after validating
the live DOM and refuse script-invalidated mutations atomically.
Document editing history now records those proxy mutations as user-level undo
steps, captures and restores directed selections, coalesces compatible typing
and deletion runs, prunes detached editing hosts, and atomically drops steps
invalidated by later script mutations. User history actions dispatch trusted,
cancelable `beforeinput` and follow successful replay with `input`; raw DOM
mutation during an active recording is diagnosed through a cycle-free DOM hook.
Text inputs and textareas now enter that same history through the DOM/HTML
interface boundary. Their value replacements retain UTF-16 offsets, synchronize
the control model and shadow text during replay, restore the control's directed
selection, coalesce typing and directional deletion runs, and keep paste as a
separate undo unit.
`execCommand()` and the `queryCommand*()` methods now run the translated
Commands and Internal/Algorithms steps directly on the live DOM instead of a
serialized host model. Commands mutate through the recording proxies, read
state and values from resolved style, record command-specific history
categories, and route `execCommand("undo")` and `execCommand("redo")` to the
shared history. The paste pipeline records through the same proxies, so pasted
content is undone as one step.
Rich copy now serializes through the translated styled-markup selection,
accumulator, and serializer, which derive interchange-newline boundaries from
visible positions and flatten lone transport wrappers. The caret navigator
follows the current upstream editing canonicalization, adjacent-host, word, and
editing-host boundary rules; line and page movement still wait for a painting
hit-test display list.
Case-insensitive command-enabled queries now reflect the actual undo and redo
stack state, including histories created by form controls.
The Page bridge now exposes navigable undo and redo entry points, recognizes
the platform undo/redo keyboard shortcuts, and forwards editing-history stack
state to `PageClient` so browser chrome can keep menu availability current.
Live document-selection range mutations and form-control caret navigation now
close an open typing unit, while selection changes made by the edit being
recorded or by history replay remain coalesced.
Contenteditable user edits now carry their UI input type through the live
command bridge. Cut takes the backward-delete path, cut and paste remain
standalone history units, and their trusted input events report
`deleteByCut`/`insertFromPaste` with the corresponding nullable data.
Clipboard insertion now crosses the active input-target boundary. Rich editing
hosts prefer sanitized HTML and execute it as one undoable `insertHTML` edit,
while `plaintext-only` hosts and form controls insert the normalized plain-text
representation; Page forwards both representations after `beforeinput`.
Select-all now follows the active input-events target before falling back to
the document body. Focused text controls select their complete value,
contenteditable hosts use rendered document-boundary navigation, and the Page
keyboard path recognizes the platform Ctrl/Cmd+A shortcut.
The common input-events target now also owns keyboard insertion, return-key
handling, and caret navigation. Page routes character/deletion keys and
character, word, rendered-line, page, Home/End, Shift-extension, and macOS
document-boundary movement to the focused form control or contenteditable host;
textarea returns insert line breaks while input returns preserve form action.
The platform Ctrl/Cmd+C, X, and V key combinations now enter the shared copy,
cut, and asynchronous paste actions, preserving their clipboard event,
representation filtering, newline normalization, and completion behavior.
System clipboard representations now retain whether their payload is raw bytes
or a user-selected file. Script-facing `read()` and `readText()` omit the
file-backed entries, while an explicit trusted paste turns raw PNG bytes and
selected image files into file items, generates a data-URL image, and sends it
through the same sanitized rich-editing insertion path.
Mouse-driven editing selection now also crosses the common input-target
boundary. Contenteditable constrains dragging to its active host, controls use
their shadow text node, and anchor/focus updates retain hit-test affinity while
keeping the control's selection model synchronized.

The refreshed current-tree semantic inventory reports 4,175 unmatched C++
spellings. That is a structural review queue rather than a count of missing behaviors: active V
implementations often consolidate C++ class hierarchies and overloads under a
single typed path. Empty/default-return implementations are checked separately,
and the refreshed audit has no suspicious trivial bodies awaiting review.

The current Layout refresh also follows shadow hosts while locating a positioned
inline containing block. Absolutely positioned shadow-tree descendants therefore
use their inline host instead of falling back to the viewport.
Inline containing-block rectangles are translated to the outer positioned box
through containing blocks rather than layout-tree parents, so internal table
row and row-group offsets are not counted twice for inline hosts inside cells.
Atomic inline used offsets are copied from fragments after final line alignment;
absolute-position static-position conversion therefore includes the atomic
inline's completed baseline and text-alignment shift.
CSS Scroll Snap now uses the translated candidate collection and selection
algorithms for element and viewport scrollers. It resolves physical and logical
axes, scroll margin and padding, oversized covering ranges, proximity and
mandatory strictness, directional `scroll-snap-stop: always`, and cross-axis
visibility. Snapped areas survive layout-tree replacement and are reselected
after relayout, including viewport scrollers and focused or targeted-area
preference. Containers without a previous selection also snap after initial
layout. Momentum-fling displacement estimation follows the compositor's rounded
geometric-decay calculation.
Flex and inline-flex fieldsets retain their special legend layout while applying
flex direction, wrapping, alignment, and gaps to the anonymous content box. The
wrapper is also created for flex fieldsets without a rendered legend.
Fieldsets with a flow inner display lay out as flow-root, and inline fieldsets
as inline-block, while their computed display is unchanged; an inline
fieldset therefore joins its parent's line as one atomic inline.
Line boxes derive their exported baseline from the final placement of the first
unshifted text fragment instead of retaining only the pre-alignment font strut.
Lines without such text keep the alignment-baseline fallback, including the
far-edge block offset used by reversed writing modes.
List items that establish an independent formatting context lay out their own
markers, outside markers align with the list item's first baseline, and the
marker line height floors only automatic list item heights. Marker symbols,
suffixes, list-style images, and authored `::marker` content now flow through
generated inline children of the marker box. Their own run discards a stale
zero-width intrinsic probe before measuring that content, including for floated
list items containing shrink-to-fit inline fieldsets. Inside markers participate in the
principal inline run, including through a trailing anonymous wrapper after
block content, and use the bundled layout-test symbol face. Live box-presence
changes now rebuild layout; a hidden list item drops its box and invalidates
cached ordinals so subsequent markers renumber. A hidden document element
leaves an empty viewport that still reports its root block formatting context. A single
authored generated image becomes the originating element or pseudo-element's
replacement box before quote controls resolve; list-item and display-contents
pseudos retain inline image children instead. Empty generated strings create a
text node only inside ordinary inline pseudo-elements. Quote controls that
resolve to no text under `quotes: none` remain represented in the layout tree
without being mistaken for authored empty strings: they contribute no line
fragment and retain zero geometry at the containing block origin.
Viewport propagation now copies the root scrollbar width and the containment-
aware principal writing mode and direction, while selecting and neutralizing
the correct root/body overflow origin.
The contain-intrinsic physical and logical longhands now parse and compute
non-negative lengths, preserve the optional `auto` state, and expand and
serialize the two-axis shorthand with the current upstream grammar.
Size-contained boxes now substitute those explicit physical inner dimensions
for content-derived automatic sizes across block and independent formatting
contexts, including inline blocks in vertical writing modes.
The multi-column rule longhands and shorthand now parse in any component order,
compute rule widths independently of the rule style, resolve `currentcolor`, and
round-trip through CSS declaration serialization.
The fragmentation break-before, break-after, and break-inside properties now
accept their complete CSS Break keyword grammars and retain typed computed
values for future pagination and multicolumn layout consumers.
Box decoration breaks and multicolumn fills now accept their complete keyword
grammars and retain typed computed values for future layout and painting
consumers.
The legacy page-break-before, page-break-after, and page-break-inside
shorthands now map their restricted grammars to the modern break longhands and
follow the upstream CSSOM serialization rules, including unresolved values.
The standard and legacy line-clamp shorthands now expand and serialize their
max-lines, block-ellipsis, and continue longhands with the upstream grammars.
Legacy vertical WebKit boxes retain their authored display while computing to
an independent flow-root or inline-block when clamping is active.
Layout now establishes those line-clamp containers, counts descendant in-flow
line boxes across block children, suppresses later in-flow content, and paints
automatic, omitted, custom, and inherited block ellipses. Ellipsis placement
uses retained soft-wrap boundaries with glyph-boundary fallback and bidi-aware
placement; scrollable overflow, DOM visual-line projection, and the typed paint
adapter exclude clamped fragments. The legacy horizontal WebKit-box path uses
its effective row flex direction. The upstream `line-clamp-properties` input
and reference render with an exact zero-pixel difference in the native V app.
Synthetic ellipses retain Ladybird's boundary text-node ownership and UTF-16
offsets. The paint bridge joins compatible retained glyph runs without
reshaping, while unsupported glyphs take the same native fallback path as
literal mixed-font text.
CSS scroll margins now implement all physical and logical longhands plus the
four-side, block-axis, and inline-axis shorthands. Signed lengths and calculated
lengths compute through the normal logical-property mapping, and scroll-into-view
expands the target border box by the resolved physical margins.
CSS scroll padding now implements all physical and logical longhands plus the
four-side, block-axis, and inline-axis shorthands. Non-negative lengths,
percentages, `auto`, and calculated values compute through the normal logical-
property mapping. Scroll-into-view resolves percentages against the corresponding
scrollport dimension and applies the root scrolling element's padding to viewport
alignment.
The scroll-snap-align, scroll-snap-stop, and scroll-snap-type grammars now
parse and retain typed computed values. Alignment pairs use shortest-value
serialization, scroll-snap-type normalizes its default `proximity` strictness,
and the computed layer exposes physical axis, alignment, stop, and strictness
enums for scrolling and painting consumers.
SVG filters now compute and inherit `color-interpolation-filters`, track the
operating color space of each graph result, insert only the required sRGB and
linear-light conversions, and preserve the special color-space behavior of
flood, image, offset, displacement-map, turbulence, and final filter output.
The native filter bridge applies those conversions, runs component-transfer
tables directly in the selected space, clamps arithmetic output to
premultiplied alpha, and renders turbulence through upstream's Skia Perlin
shader. Turbulence replay forwards scaled, half-away-from-zero-rounded stitch
tile dimensions and rasterizes the retained filter target rather than the
browser's full canvas, keeping deterministic noise independent of chrome
offsets. The turbulence and fractal-noise canonical screenshots are exact
zero-pixel matches.
Decoded `feImage` resources now retain their absolute URL in the graph, preload
through the browser image cache, and attach the decoded frame during native
replay. The same filter boundaries are retained inside SVG pattern tiles, and
the compact script bridge exposes completed images and late `load` listeners so
visibility changes do not strand a cached pre-load tile. The three new
`feImage` reference cases are exact zero-pixel matches.
The same script bridge now round-trips the reflected `src` property and
`setAttribute("src", ...)` for image elements into the live DOM. Synchronously
decoded replacements enter the translated HTML image update boundary and
explicitly invalidate layout plus retained paint input, so an intrinsic-size
replacement with unchanged dimensions still repaints. The upstream
`svg-image-source-switch-same-size` reference pair is pixel-identical.
Document ID-map additions, removals, and changes now invalidate published SVG
paint resources like upstream, so a previously shadowed gradient or pattern is
resolved after an HTML/SVG ID collision changes. The compact browser bridge
tracks elements independently of their mutable or duplicate IDs, preserves
SVG attribute case and namespaces, creates SVG children, replays
`moveBefore()`, and commits the retained final keyframe used by completed paint
animations. The nine new gradient, pattern, and ID-collision mutation reftests
are exact zero-pixel matches.
Ladybird's new color-matrix reftest is an exact zero-pixel match; its displacement
and turbulence mismatch references both differ. The comparison driver now
follows both `rel="match"` and `rel="mismatch"` references.

Incremental HTML parsing now retains undecoded encoding-sensitive bytes while
scripts are not yet permitted to run or the tokenizer is paused on a
parser-blocking script. Encoding confidence, late meta-charset processing,
on-the-fly decoder replacement, parser-resume notification, and implied-EOF
draining follow the current upstream parser. Focused streaming tests cover both
the initial deferred-start path and the parser-blocking-script regression with
a late Windows-1252 declaration.

SVG and MathML computed display now follows CSS Display's unboxing rules.
`display: contents` computes to `none` for an outermost SVG that participates
in CSS box layout, for SVG elements outside the allowed container/text-child
set, and for every MathML element. The allowed nested SVG elements continue to
hoist their contents, and an SVG nested through `foreignObject` correctly
starts a new outermost-SVG boundary. Focused tests mirror upstream's complete
13-element SVG computed-display matrix and also cover MathML and the
`foreignObject` position boundary.

The compact document bridge now preserves namespaces and case-sensitive local
names when replaying `document.createElementNS()` and attributes on
script-created SVG content. Layout construction exits SVG rendering context at
`foreignObject`, skips SVG graphics in its HTML subtree, and re-enters only at
a nested SVG root. The upstream
`svg/foreignObject-with-svg-namespace-child.html` corpus case now matches
exactly.

SVG viewport boxes now append their SVG content directly even when the outer
SVG is block-level. Whitespace text and `foreignObject` siblings no longer gain
anonymous HTML block wrappers, matching both upstream absolute-positioned
`foreignObject` corpus cases. Their inline-child state now follows the upstream
insertion rule as well: an in-flow block `foreignObject` clears a block SVG
viewport's flag, while remaining an interrupting block in an inline SVG
viewport. This also matches `svg/foreignObject-with-mask.html` without changing
the default inline SVG cases.

Attached SVG mask, clip, and pattern layout subtrees now keep the active SVG
formatting context as their coordinate containing block. A resource referenced
from a translated `foreignObject` therefore starts at its own `(0, 0)` origin,
and its SVG descendants no longer inherit the host's translation.

Resolved SVG `foreignObject` geometry supplies definite available space to its
independent formatting context without becoming a definite CSS percentage
basis. Percentage-height HTML descendants therefore remain automatic, matching
the upstream viewBox geometry corpus case.

The compact script bridge now replays `Element.remove()` through the DOM removal
algorithm. Removing a referenced SVG mask consequently marks its registered
referencer for layout-tree rebuilding and drops the synthetic resource box,
matching the upstream resource-removal corpus case.

Inline declarations on UA-shadow elements associated with host pseudo-elements
now resolve logical aliases against the inherited pseudo-element writing mode
and direction before entering the physical computed-property table. A
placeholder added by script after the input's first layout therefore retains
its negative inline-start overlay margin, and the upstream
`input-placeholder.html` corpus case now matches exactly.

Fallback number-input stepper buttons now seed their SVG `d` computed property
from the same path data used to construct the internal icon element. SVG layout
therefore retains the up/down path bounds, matching both the upstream
`input-number-placeholder.html` and `number-input-appearance.html` corpus cases.

Anonymous whitespace-only flex children, including an empty button's generated
content box, are now skipped before used values are created. Debug output keeps
the skipped box's inline-block identity without inventing geometry. This matches
the explicit `LayoutState` lifecycle and fixes the two empty-button snapshots,
`flex-baseline-alignment.html`, and
`flex/box-baseline-with-inline-flex-empty-child.html`.

Inline-grid formatting no longer materializes used values for anonymous
whitespace runs that grid placement skipped. They remain present in the layout
tree but unpainted, matching `grid/fit-content-3.html`.

GIF image loading now follows upstream's tolerant LZW behavior: a stream that
ends without an explicit end-of-information code keeps the successfully decoded
frame and its natural dimensions. The one-pixel data GIF in
`table-replaced-child-percentage-height-in-auto-table.html` therefore supplies
the table's intrinsic width and height instead of collapsing the table to zero.

Collapsed-table intrinsic probes now replay the cached grid's winning borders
into each throwaway layout state. Anonymous wrapper intrinsic widths retain the
table-owned outer shares, percentage border-box widths subtract those split
shares, and the wrapper's exported row baselines follow the final collapsed-
border content-origin rebase. This matches
`table/width-distribution-of-max-width-increment.html` and
`table/border-collapse-is-inherited.html` while preserving the separate-border
absolute-positioned, nested, and max-content table cases.

Pseudo-elements generated by the document element no longer receive root-only
box transformations. In particular, `html::first-letter` remains inline and
resolves `em` lengths against the originating root's computed font metrics.
The native browser bridge now replays live `Selection.selectAllChildren()`,
`getRangeAt()`, and `Range.surroundContents()` mutations through the translated
DOM implementation; upstream's `first-letter-of-html-root-refcrash` reftest is
an exact zero-pixel match.

HTML image `x` and `y` geometry queries now resolve accumulated paint and
hit-testing state only after finding committed layout geometry. Images without
a box return zero before that work, avoiding stale paint-property resolution
for disconnected and non-rendered elements. Focused tests observe both the
committed-box resolution path and the no-box early return.

The inherited `-webkit-font-smoothing` property now accepts all four upstream
keywords and propagates through ordinary glyph runs, text shadows, and
`background-clip: text` masks. The macOS native renderer maps those modes to
Skia and CoreGraphics font rasterization settings, including Blink-compatible
non-dilated outlines for `antialiased`; direct screenshots verify that the
rasterization mode changes pixels.

The browser script bridge now preserves explicit `Range` boundary points,
replays `removeAllRanges()` and successive selection moves in order, moves
existing nodes through `insertBefore()`, and applies CSSOM rule declaration
changes before style computation. The three upstream live-selection reftests
now match exactly, including insertion between unchanged boundaries and moving
a highlight between subtrees after its `::selection` rule changes.

Range client rectangles now include selected retained text fragments and map
each fragment through its containing block's accumulated visual context.
Element client rectangles use the same viewport transform boundary, so their
geometry agrees under CSS transforms and both reflect live ancestor scrolling.

Empty editable blocks, paragraphs, and inline elements now derive caret height
from the selected font's ascent plus descent, cap it at the computed line
height, and center it in the line's extra leading. The compact browser bridge
replays `Selection.collapse()` at element and text boundaries, so the upstream
`empty-caret-with-placeholder` reference pair paints real carets and matches
with an exact zero-pixel diff.

Selections left on a parent's child boundary now derive their caret rectangle
from the adjacent retained text fragment, preferring the previous text child's
end before the next text child's start. This preserves identical LTR, RTL, and
vertical geometry between parent and text-node offsets. The compact browser
attaches a focused HTML navigable before display-list recording, and the visible
`caret-after-first-character` reference pair matches with an exact zero-pixel
diff.

Dashed CSS calls now resolve and evaluate active `@function` definitions during
arbitrary substitution. The translated evaluator carries parameter and result
registrations through function-local scopes, applies defaults and typed syntax,
resolves local declarations and inheritance, caches resolved local properties,
and preserves CSS-wide result-keyword behavior. Shared guarded substitution
contexts now mark the complete cycle and include function identity in property
dependencies. Arguments substitute before missing/excess arity rejection, and
custom properties retain function-registry access when a normal property later
depends on them. Focused tests mirror the five new upstream regressions for
cycle fallback, context identity, evaluation order, result keywords, and
registry dependency.

CSS backface visibility now parses, computes, inherits, serializes, and
interpolates through the typed property pipeline. The transform implementation
retains full 4x4 matrices, builds explicit and synthetic 3D planes, bounds
backface tests at their plane roots, and resets ancestor culling when a
descendant enters its own 3D sorting plane. Painting and hit testing share that
culling decision. The browser animation loop refreshes retained paint-only
transform state after load-handler and `requestAnimationFrame` mutations. The
expanded backface comparison set passes 25/25 cases: 23 are exact and two stay
within the comparison workflow's checked tolerances.

The earlier inventory mapped every upstream implementation filename to V code,
but filename and symbol-name coverage did not establish behavioral parity. A
semantic re-audit found name-only `upstream_*entry_points.v` coverage-shim
files. Every such file has now been compared with the corresponding upstream
bodies, rewritten where necessary, and promoted under an implementation name;
the current audit has no quarantined coverage files. The remaining `Present`
modules still have upstream bodies that require the same behavioral audit.

A 2026-09-26 triage of the 285 trivial-bodied V functions against upstream
found 230 faithful, 28 V-only helpers (25 adapters, 3 placeholders), and 27 real
divergences.
Those translated since: bare `safe`/`unsafe` alignment keywords, canvas repaint
requests, navigator languages, queued media source and element tasks,
traversal initiator sandboxing, theme color resolution, layout tree teardown,
time-origin-relative DOM timestamps, external software hand-off, navigation
start times for new browsing contexts and navigated documents, hyperlink
activation and following through the navigable, form and interactive element
activation behavior from event dispatch, the navigators' ID, language, online,
and hardware mixins, media devices bound to their window's document, navigation
referrer policies from hyperlinks, per-element focusable areas with their
rendering requirement and image maps, request policy containers, and style
elements that create their sheets in the style scope's style sheet list with
the parser handshake and script-blocking state. Hyperlink downloads now fire
their cancellable Navigation API event, honor sandboxing, fetch with the
download initiator and URL credentials, apply the upstream Content-Disposition
and same-origin filename precedence, sanitize the result, and stream response
bodies through the owning PageClient. Navigation responses with an attachment
disposition now take that download path without installing a document or
history entry, enforce both source and target sandboxing, and retain request-
server identity for direct PageClient handoff. Still open:

- The browser shell dispatches clicks through its JavaScript mirror and follows
  links itself instead of the page event handler's click and activation path.
- `<link rel=stylesheet>` sheets are read from local files by a layout-time
  CSS bridge, and the shell inlines remote ones as style elements, instead of
  `HTMLLinkElement` fetching and processing them; the shell installs no fetch
  host, so the fetch module has no resource loader behind it.
- The compositor keeps its own visual context tree instead of
  `AccumulatedVisualContextTree` spatial transforms and sticky offsets.
- The WebGL module is not connected to `<canvas>` or the DOM event model.
- IndexedDB's browser binding exposes queued open/upgrade and store get/put/add
  requests through the native transaction model. Cursor/index bindings, complete
  event bubbling, arbitrary structured clone graphs and persistent storage remain
  open; see `indexeddb/PORT_STATUS.md` for the scoped 2026-10-25 checkpoint.
- Stream transfer and ML-KEM remain untranslated.

`Complete` means every upstream `.cpp` unit has an audited V implementation
mapping. `Present` means translated module code exists but its full upstream
coverage has not yet been audited. `Untranslated` means no module translation
was found. The remaining module rows retain their earlier inventory status
until their own behavioral re-audits are performed.

The 2026-10-01 structural audit (`python3 tools/libweb_translation_audit.py
--json`) inventories 21,401 upstream function bodies across those 1,193 C++
files. It reports 14,261 candidate name matches, 525 consolidated name matches,
and **4,158 unmatched bodies**, alongside constructors, operators, binding/GC
functions, and field matches. These classifications are a source-comparison
worklist, not evidence that a matched body behaves like upstream or that an
unmatched body has no renamed translation. The whole Ladybird translation is
not complete. Remaining browser integration gaps above and the runtime boundary
in [`libjs/PORT_STATUS.md`](libjs/PORT_STATUS.md) require implementation and
behavioral verification. Full coverage must not be inferred from the `Complete`
filename-mapping label.

LOC is physical line count (`wc -l`), including comments and blank lines.
Implementation and test V counts are disjoint. The V columns count all tracked
package `.v` files, including generated V assets and supporting translations.
The WebAssembly package also contains its separately audited LibWasm core; its
V LOC is not a count of LibWeb WebAssembly source equivalence. `Selection`
includes its shared `dom/selection.v` implementation, and `UIEvents` includes
its shared `dom/ui_events.v` implementation. Their shared DOM test files are
counted under the corresponding owner once. Root support and other support modules
are documented separately in `ROOT_SUPPORT.md` and are not included below.
The upstream `Crypto` module maps to the `webcrypto/` V package so it can use
V's standard `crypto.*` modules without shadowing that namespace.
The IDL-only `Fullscreen` package delegates its state machine to the shared
translated DOM implementation.

Verified at `33ba13ac`, the physical inventory is retained in
`Build/audit-fixes/native-wheel-input-routing-inventory-current.json` (SHA256 `590ac39c939ef72b92c769b0c66f7fdaf09c2825e64ce6a64141dbaa39764557`).
All 78 owners / 2,238 assigned files contain 433,415 implementation / 161,056
test V LOC at this code pin.
The native wheel-input routing feature assigns three Page paths: +46
implementation / +327 test physical lines and one assigned file from actual
parent `31355243`. Four root browser/support paths remain excluded. The
separate previous `0cd374b6` to parent range contains the CSS compatibility
byte correction with zero physical-line delta and documentation commits; these
receive no wheel test or implementation credit. Exact per-path hashes/newlines
and owner deltas remain in the counter. Later work outside `33ba13ac` requires
its own pin.
The previous native media wheel-handler inventory at `0cd374b6` (2026-10-14) remains preserved in
`Build/audit-fixes/native-media-wheel-handler-inventory-current.json` (SHA256 `393db2d4bee0aeabeae05a4d6caf1c0785526ad70ea2065cdf7cc33ed26b3495`).
At that pin, 78 owners / 2,237 assigned files contain 433,369 implementation /
160,729 test V LOC.
The onwheel feature changes three excluded browser/root paths and adds no
assigned implementation, test or file count. Independent intervening assigned
commits are reconciled separately from `a503c977` to actual parent `777c3cf9`:
CSS +76 implementation / +266 test lines / +8 files; DOM +3 implementation /
+16 test lines / +1 files; Layout +27 implementation / +54 test lines / +1
files. Exact per-path hashes/newlines and per-commit attribution remain in the
counter; these commits receive no separate feature or test credit here. Later
work outside `0cd374b6` requires its own pin.
The previous native media drag-handler inventory at `a503c977` (2026-10-14) remains preserved in
`Build/audit-fixes/native-media-drag-handlers-inventory-current.json` (SHA256 `9dc686e6ab4186f3d7a1bd4e137bf657ccad63e8b1d89f7d424a66b29b9da2bc`).
The seven native media drag/drop handler attributes change only three excluded
browser/root support paths. Assigned implementation and test LOC, all 78 owner
rows and every assigned byte hash/newline count remain unchanged from the
prior `fdc13cca` entry inventory and actual feature parent `dc5aa34d`. No
intervening assigned slice is counted. These are physical counts and do not
establish behavioral equivalence or additional test credit.
Exact full Git and assigned input maps are retained for the prior entry
inventory, actual feature parent and committed feature. Later concurrent
canonical work stays outside this pin. Upstream source-unit counts, mapping
labels and the historical finding ledger remain unchanged.
The previous DataTransfer entry inventory at `fdc13cca` (2026-10-13) remains preserved in
`Build/audit-fixes/native-data-transfer-entry-inventory-current.json` (SHA256 `f3062da8a0c0354822688a690594c6497ce8771933ef566068f0229a61e35a26`),
with 2,227 files / 433,263 implementation / 160,393 test V LOC. Its original
EntriesAPI/HTML feature accounting below remains dated history at that pin.
The public native DataTransferItem.webkitGetAsEntry and FileSystemEntry
metadata feature changes only four assigned EntriesAPI/HTML paths: +21
implementation / +80 test lines and +2 assigned files from actual parent
`fffc5c57`. The owner deltas are EntriesAPI +21 implementation / +27 test
lines / +1 assigned file; HTML +0 implementation / +53 test lines / +1
assigned file. 9 root/browser support and test paths remain excluded. Assigned
hashes and counts at the actual feature parent remain unchanged from the prior
`e3ff95fd` inventory; no intervening assigned slice is counted. These are
physical counts and do not establish behavioral equivalence or additional test
credit.
Exact full Git and assigned input maps are retained for the prior
string-callback inventory, actual feature parent and committed feature. Later
concurrent canonical work stays outside this pin. Upstream source-unit counts,
mapping labels and the historical finding ledger remain unchanged.
The previous DataTransfer string-callback inventory at `e3ff95fd` remains preserved in
`Build/audit-fixes/native-data-transfer-string-callback-inventory-current.json` (SHA256 `61b814a88cb00769fd88dcb29f12b4b93fd0c80e582b4a74fdbb5e33309cead5`),
with 2,225 files / 433,242 implementation / 160,313 test V LOC. Its separate
feature accounting remains +11 HTML implementation / +41 test lines / +1 file;
the prior DataTransfer addition, items, string and older evidence retain their
own source pins.
The previous DataTransfer item-addition inventory at `bbe330a8` remains preserved in
`Build/audit-fixes/native-data-transfer-add-inventory-current.json` (SHA256 `4872c275d35da716c0cbbfb3f86e95d85375ddb8202e84a3dd10bc28c10d4648`),
with 2,224 files / 433,231 implementation / 160,272 test V LOC. Its separate
feature accounting remains +15 HTML implementation / +55 test lines / +1 file;
the prior DataTransfer items, string and older evidence retain their own
source pins.
The previous DataTransfer items inventory at `e775be45` remains preserved in
`Build/audit-fixes/native-data-transfer-items-inventory-current.json` (SHA256 `7b5ad87afb6c18b8529c2fce174a96e9ef9e863926ffaaa3618d1dde0ba3dfed`),
with 2,223 files / 433,216 implementation / 160,217 test V LOC. Its separate
feature accounting remains +10 HTML implementation / +74 test lines / +1 file;
the prior DataTransfer string and older evidence retain their own source pins.
The prior DataTransfer string inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-b335958e.json` (SHA256 `d1312ce3780a77a3ebcab3a487d3052ebbdedb51cfdd0e60a4992134892dea81`),
with 2,217 files / 433,002 implementation / 159,798 test V LOC.
The prior DragEvent inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-682a7827.json` (SHA256 `1e30f605ac80b9e550e7749cc1c62330556e8491793952db1de86a8b2b54a9a3`),
with 2,216 files / 432,960 implementation / 159,684 test V LOC.
The prior WheelEvent inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-813dd838.json` (SHA256
`7d2154cc1ce69f1ea0dda25e8eda6f2df52c76abc7df473c463da13e8ca1cce5`),
with 2,213 files / 432,942 implementation / 159,469 test V LOC.
The prior PointerEvent inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-c9dc0da2.json` (SHA256
`3c5062172b28d38dda0a7e9d3d842470e270a78fd45aee5f07ba0a68633c54b5`),
with 2,212 files / 432,869 implementation / 159,348 test V LOC.
The prior MouseEvent inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-db342c95.json` (SHA256
`8faec2d3db2fcb54835b7e6867dfbe177b498d5da213b5b5b145212b0b234522`),
with 2,211 files / 432,871 implementation / 159,242 test V LOC.
The previous canonical related-target inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-dd0cc2d5.json` (SHA256
`568534bda24ca5538af3196bacd984810907a7fd79a60c064135af6cb4478b51`).
That slice changed only DOM and UIEvents: implementation shrank by two lines
in DOM and one in UIEvents, and its 285-line core test belongs to DOM.
The previous UIEvent inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-d1b86d81.json` (SHA256
`1d396d2178a0173ebe3f267c44e8a13bb7eac2ce5ce68cfdade2ad6ce2dfa265`).
The previous media movement inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-e5ae9afb.json` (SHA256
`16e41f1d3ac526bd0ed255fae0aeebb752d66421da4b1d587f69cde20f9a5c9c`).
The previous media auxclick/dblclick inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-5ba4d87c.json` (SHA256
`90982b16fe88bc53a2ad6f1a6f89d53950ef88a4e7250cc86ec5619997e7dadc`).
The previous media onclick inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-8c567b08.json` (SHA256
`1aef0cc514a53f73405c61efa11b1400cccb54024aecb7b7479a56cdf63a458b`).
The previous media press/release-handler inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-9ee0685b.json` (SHA256
`e8b19228fb5b400542347570c7198c7314e675bdee14a05ac890e947a31e38da`).
The previous media-handler inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-60ef4bb2.json` (SHA256
`087ef5bb19a9b329c861227032f77769c3f552171b6a30ab496b2e37d4522a7b`).
The previous ordinary-listener inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-4ef8e6e5.json` (SHA256
`64cd5fb2cfa150fe9505b5e07dc6f6251a8e2211fd7d0d9ce93481eaee33fcff`).
The previous native-play inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-58fde80e.json` (SHA256
`87f5275d06b35029406cead2eca001cb606389db9aa58958d6fbb3ff1b1c6f01`).
The previous unsupported-play inventory remains preserved in
`Build/audit-fixes/source-current-module-loc-aa9a5e27.json` (SHA256
`166070c623211b8600db5300c89ed5219375d0e4045728c12117361ad8cca27c`).
Source-unit mappings and physical LOC do not establish runtime parity.

The table below records package V LOC verified at `33ba13ac` on 2026-10-13 UTC; upstream counts
and structural mapping labels retain the pinned inventory. It covers 76 current
implementation-bearing upstream modules plus the translated IDL/IPC-only
`Fullscreen` and `Worker` packages, and all 1,193 module-owned `.cpp`
implementation units. Root-level LibWeb `.cpp` support units are mapped
separately in `ROOT_SUPPORT.md`. The removed upstream `PermissionsPolicy`
module's small compatibility package remains in the repository but is excluded
from the current-module totals.

| Upstream module | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ARIA` | 6 | 1,955 | 2,574 | 410 | Complete |
| `Animations` | 10 | 5,187 | 4,254 | 1,420 | Complete |
| `Bindings` | 11 | 2,501 | 2,718 | 1,116 | Complete |
| `CSS` | 215 | 47,722 | 115,091 | 18,229 | Present |
| `Clipboard` | 4 | 1,009 | 1,123 | 409 | Complete |
| `Compositor` | 6 | 1,687 | 2,403 | 361 | Complete |
| `Compression` | 2 | 348 | 471 | 143 | Complete |
| `ContentSecurityPolicy` | 37 | 4,725 | 2,816 | 514 | Complete |
| `CookieStore` | 2 | 850 | 1,059 | 482 | Complete |
| `CredentialManagement` | 6 | 382 | 420 | 301 | Complete |
| `Crypto` | 6 | 13,412 | 7,957 | 7,989 | Complete |
| `DOM` | 59 | 34,859 | 43,502 | 5,066 | Complete |
| `DOMURL` | 4 | 1,039 | 854 | 464 | Complete |
| `Editing` | 26 | 12,720 | 13,938 | 226 | Complete |
| `Encoding` | 6 | 769 | 5,356 | 4,495 | Complete |
| `EncryptedMediaExtensions` | 3 | 535 | 572 | 329 | Complete |
| `EntriesAPI` | 1 | 47 | 65 | 59 | Complete |
| `EventTiming` | 1 | 122 | 153 | 95 | Complete |
| `Fetch` | 33 | 8,493 | 6,678 | 3,228 | Complete |
| `FileAPI` | 6 | 1,357 | 1,493 | 858 | Complete |
| `Fullscreen` | 0 | 0 | 93 | 177 | Complete |
| `GPC` | 1 | 21 | 16 | 13 | Complete |
| `Gamepad` | 6 | 1,351 | 860 | 323 | Complete |
| `Geolocation` | 4 | 643 | 535 | 224 | Complete |
| `Geometry` | 8 | 2,078 | 2,121 | 1,041 | Complete |
| `HTML` | 286 | 83,853 | 69,710 | 40,722 | Complete |
| `HighResolutionTime` | 2 | 516 | 500 | 213 | Complete |
| `IndexedDB` | 19 | 6,991 | 5,455 | 1,388 | Complete |
| `Infra` | 3 | 385 | 548 | 102 | Complete |
| `Internals` | 7 | 2,583 | 2,337 | 1,067 | Complete |
| `IntersectionObserver` | 2 | 528 | 668 | 413 | Complete |
| `Layout` | 9 | 4,001 | 44,944 | 18,415 | Present |
| `Loader` | 6 | 1,291 | 1,921 | 664 | Complete |
| `MathML` | 6 | 369 | 653 | 162 | Complete |
| `MediaCapabilitiesAPI` | 1 | 345 | 657 | 129 | Complete |
| `MediaCapture` | 5 | 1,475 | 1,240 | 247 | Complete |
| `MediaSourceExtensions` | 13 | 4,094 | 4,079 | 2,343 | Complete |
| `MimeSniff` | 2 | 1,607 | 1,108 | 308 | Complete |
| `MixedContent` | 1 | 127 | 93 | 105 | Complete |
| `NavigationTiming` | 4 | 497 | 645 | 130 | Complete |
| `NotificationsAPI` | 1 | 301 | 370 | 101 | Complete |
| `Page` | 8 | 6,450 | 6,901 | 3,170 | Complete |
| `Painting` | 22 | 8,227 | 7,993 | 2,628 | Present |
| `PerformanceTimeline` | 5 | 476 | 502 | 154 | Complete |
| `PermissionsAPI` | 3 | 388 | 239 | 74 | Complete |
| `Platform` | 4 | 431 | 2,851 | 692 | Complete |
| `ReferrerPolicy` | 2 | 341 | 105 | 223 | Complete |
| `RequestIdleCallback` | 1 | 52 | 59 | 18 | Complete |
| `ResizeObserver` | 4 | 424 | 605 | 231 | Complete |
| `ResourceTiming` | 1 | 357 | 342 | 90 | Complete |
| `SRI` | 1 | 198 | 156 | 100 | Complete |
| `SVG` | 82 | 9,020 | 6,747 | 1,708 | Complete |
| `SecureContexts` | 1 | 76 | 59 | 13 | Complete |
| `Selection` | 3 | 1,470 | 1,479 | 332 | Present |
| `Serial` | 2 | 366 | 243 | 35 | Complete |
| `ServiceWorker` | 11 | 2,608 | 1,573 | 513 | Complete |
| `Speech` | 11 | 421 | 668 | 130 | Complete |
| `StorageAPI` | 6 | 433 | 584 | 449 | Complete |
| `Streams` | 22 | 8,789 | 7,421 | 4,888 | Complete |
| `TrustedTypes` | 7 | 1,175 | 863 | 222 | Complete |
| `UIEvents` | 12 | 1,871 | 1,489 | 474 | Complete |
| `URLPattern` | 1 | 223 | 1,703 | 257 | Complete |
| `UserTiming` | 2 | 160 | 119 | 35 | Complete |
| `ViewTransition` | 1 | 1,054 | 743 | 349 | Complete |
| `WebAssembly` | 7 | 3,441 | 11,143 | 10,277 | Complete |
| `WebAudio` | 47 | 8,256 | 8,682 | 3,247 | Complete |
| `WebDriver` | 16 | 5,321 | 3,934 | 862 | Complete |
| `WebGL` | 42 | 7,846 | 6,627 | 11,753 | Complete |
| `WebIDL` | 10 | 2,466 | 2,551 | 1,299 | Complete |
| `WebLocks` | 5 | 647 | 701 | 169 | Complete |
| `WebSockets` | 1 | 476 | 409 | 156 | Complete |
| `WebVTT` | 2 | 378 | 464 | 232 | Complete |
| `WebXR` | 6 | 492 | 411 | 139 | Complete |
| `Worker` | 0 | 0 | 142 | 75 | Complete |
| `XHR` | 7 | 1,855 | 1,695 | 1,197 | Complete |
| `XLink` | 1 | 16 | 13 | 10 | Complete |
| `XML` | 2 | 556 | 477 | 164 | Complete |
| `XPath` | 5 | 435 | 672 | 210 | Complete |
| **Total** | **1,193** | **329,970** | **433,415** | **161,056** | **74 complete, 4 present, 0 untranslated** |

### Live editability refresh

Live `contenteditable` attribute changes and `designMode` transitions refresh
inherited editability, retained caret hit-test targets, and `:read-only` /
`:read-write` state. Selector invalidation also reaches relational and sibling
dependencies. An editing-host transition relays out empty text even when its
inherited editable flag remains true, so stale caret fragments cannot keep an
empty descendant tall. Enabling design mode resets selection and focuses the
document element once; repeated `on` assignments preserve the current selection.

The interrupted implementation in `1767041` was subsequently validated by the
complete 656-file LibWeb suite, the native engine/JavaScript smoke check, and all
11 default screenshot comparisons. The additional LibJS frontend suite is
recorded separately below because it was introduced after that full-suite run.

## Verification

### Separate LibJS frontend and runtime

The refreshed [`libjs/`](libjs/PORT_STATUS.md) package imports the February
`libjs_v` frontend and translates later parser, Unicode, AST ownership, scope,
and serialization behavior against the current Ladybird checkout. It also
translates the LibJS VM record: execution contexts and the interpreter stack,
environment and Reference records, realms, error objects with tracebacks and the
`ErrorType` table, promise and finalization job queues, host hooks, exception
unwinding, and the file-backed module loader bookkeeping. The supported execution
slice includes the V bytecode generator and interpreter, BigInt numeric operations,
native calls, object coercion, ordinary property reads/writes/updates, delete/in,
numeric, URI, and legacy global functions, and data/accessor descriptors. Native cached
accessors preserve holder/receiver identity and reject stale cache publication
after getter mutation. Descriptor conversion and ordered bulk definitions follow
the upstream algorithms with explicit intrinsic-prototype/ToObject boundaries.
Function intrinsics add call/apply/bind/toString, restricted caller/arguments
accessors, array-like argument collection, and bound callables. Compiled
`instanceof` supports ordinary and custom handlers and bound targets while
preserving the pinned upstream's documented no-handler fallback behavior.
Default native globals inherit each realm's Function prototype; its Object
prototype and constructor linkage remain pending.
Native and bound construction preserve arguments, callee realms, new-target
identity, and prototype fallback through the translated constructor operations.
Compiled `new` expressions retain upstream evaluation order. Boolean and Symbol
wrappers/prototypes/globals are translated, including Boolean construction,
Symbol's description accessor and registry, and primitive property receivers.
Number/BigInt wrapper records and all primitive ToObject cases are translated
with explicit Number/BigInt/String prototype dependencies. Their builtin graphs
and primitive Reference integration remain pending. GetV, GetMethod and Invoke are
translated with explicit intrinsic prototype dependencies.
BigInt's complete constructor/prototype records retain one number-hint
conversion, source metadata, throwing construction, asIntN/asUintN width and
OOM behavior, and branded radix formatting/valueOf. Its locale native body
preserves NumberFormat construction and FormatNumeric forwarding through explicit
Intl dependencies. Object/Intl graph integration and production BigInt global
installation remain pending; the browser tests exercise the records under test
host names without supplying replacement locale formatting.
Number constructor/prototype records now retain source initialization order,
constant descriptors, parse-function aliases, noncoercing static predicates,
exact BigInt-to-double rounding, and branded fixed, scientific, radix and valueOf
bodies. The prototype itself carries NumberData = +0. Scientific rounding follows
the upstream exact binary arithmetic and decimal-boundary candidate comparison;
AK's untranslated Dragonbox seed backend is an explicit dependency. Locale calls
retain the current realm's NumberFormat/FormatNumeric dependencies and the original
numeric payload. Tests supply decimal-form fixtures and an Intl plumbing marker;
production Number installation and primitive Reference integration remain pending.
ObjectPrototype's eleven native bodies now translate own/enumerable and prototype
membership, valueOf/toLocaleString, Annex B accessor definition/lookup and __proto__
reads/writes, preserving source coercion order and existing opposite callbacks.
RequireObjectCoercible and immutable-prototype dispatch likewise follow upstream.
These bodies retain explicit primitive dependencies; ObjectPrototype initialization
and its toString/IsArray/type-record chain remain pending. A test-only browser host
exercises them through compiled scripts, including symbol accessors, live prototype
changes and recovery after cycles or immutable-prototype errors.
Reflect's complete record and thirteen native bodies translate descriptor/property
operations, explicit get/set receivers, prototype/extensibility checks, ordered
key arrays and apply/construct validation. Failed mutations return booleans while
conversion and accessor errors propagate. Object/Array intrinsic dependencies stay
explicit; production Reflect installation and Proxy internal methods remain pending.
The browser tests exercise the translated record through compiled scripts without
creating a JavaScriptCore context.
Host-created String exotic objects preserve fixed UTF-16 character descriptors,
definition compatibility, and virtual-index key order. String's complete constructor
record retains call/construct, raw templates, character creation, source metadata
and explicit prototype/boxing dependencies. Thirty-nine prototype native bodies
translate branding, UTF-16 access/slicing/search, concatenation, exact whitespace
trimming, well-formed repair, iterator creation, repetition, padding, all 13
legacy HTML wrappers, Unicode casing, all four normalization forms, string
replacement/splitting and symbol dispatch. GetSubstitution retains all dollar
tokens, numbered/named captures and live conversion/getter ordering. split creates
real Array records using an explicit prototype dependency. RegExp symbol methods
and builtin shortcuts remain pending. The UTF-16 casing/normalization helpers
retain upstream's native ICU dependency, ASCII casing
shortcut and failure behavior. Intl locale casing/collation remain pending.
Validation and repair match 2,388 pinned simdutf cases.
fromCodePoint retains the pinned source's integral
ToInt32 wraparound before its range check. The remaining 10 prototype native
bodies, initialization/aliases, bytecode builtin shortcuts, production String
installation and primitive Reference integration remain pending.
RegExp preparation translates strict/permissive flag handling, exact UTF-16
error messages, named-group surrogate/origin checks, Unicode escape normalization
and source escaping. All 9,202 native LibJS/AK preparation cases match exactly in
both GC modes. RegExp records, constructor/prototype methods, grammar compilation
and matching remain pending; helper validation does not establish regex parity.
LibRegex's complete AST and bytecode models, recursive owned cloning and
ASCII/WTF-16 input/capture primitives are translated. All 36,166 native Rust
helper cases match exactly in both GC modes. Pattern-hint analysis and literal
prefilters additionally match 112,458 native cases, including complete hint
metadata, control-flow/suffix checks and exhaustive UTF-16 ASCII folding. Its
VM scratch storage, register snapshots, saved choices, modifier/repetition
transitions and directional character traversal additionally match 14,942 native
cases. Case canonicalization, builtin classes, literal matching, word boundaries
and numbered/named backreferences add 113,204 exact native Rust/C++ comparisons.
UnicodeSet expansion, bounded case closures, inverse-range matching, character
classes and simple-scan membership add 255,240 exact native comparisons, including
every BMP code point and all eight character-class flag combinations.
Unicode property resolution, strict aliases, script extensions, case-closed
queries and string-property packing add 129,233 exact native comparisons.
These include complete string-property output and every BMP code point; macOS
queries use standard ICU 78 rather than Apple's private-use category tailoring.
Simple-match predicates and candidate filters add 389,048 exact native
comparisons. Single-match, greedy and find-all scan execution adds 32,481,
including complete capture buffers and capacity exhaustion.
The parser, compiler, backtracking dispatch and general VM execution remain pending.
Array exotic records retain sparse, nonconfigurable length descriptors, grow
only after successful indexed definitions, and restore failed truncations at
the highest fixed index. Property definitions propagate VM exceptions through
compiled writes and Function.apply. Upstream indexed collection, stable merge
sort, and array-element comparison helpers are translated; Array constructors,
prototype methods, and literals remain pending.
Synchronous iterator records implement stepping, deferred value-getter errors,
completion-preserving close/close-all, and list/callback collection. Host-created
String and ordinary-Array iterators expose branded next methods, Unicode code
points, live lengths, and entry-pair arrays through explicit intrinsic dependencies.
Iterator intrinsic installation, ordinary Array iterator-producing methods,
helpers and async iteration remain pending. Array iterator stepping also uses
translated TypedArray witnesses, including live lengths and recoverable bounds errors.
ArrayBuffer records and owned/host-backed DataBlocks preserve zeroed allocation,
copy/move/resize, captured host lengths and keyed detachment. Its constructor,
four accessors, resize, species-aware slice and both transfer methods are now
installed in each realm and execute through the browser's translated VM.
DataView construction, three property accessors and all 22 numeric methods are
installed, with fixed/tracking bounds witnesses, byte-order handling, BigInt
modulo conversion and Float16 rounding. Host-created TypedArray records translate
all twelve element types, integer-indexed exotic methods, fixed/tracking witnesses
and all four initialization paths. Concrete constructor behavior uses explicit
prototype dependencies for scalar lengths, iterables, array-like input and
TypedArray copies; TypedArrayCreate and numeric comparison are also translated.
Native behavior functions cover four branded accessors, at, @@toStringTag,
includes/indexOf/lastIndexOf, reverse and sort through the primitive boxing
boundary. Callback bodies add every/some/forEach, the four predicate searches,
reduce/reduceRight and entries/keys/values. They retain snapshot traversal lengths,
live element reads, argument-presence errors and explicit iterator dependencies.
copyWithin preserves bit encodings across overlapping byte copies; fill retains
ordered numeric conversion, fresh bounds and the chunked integer path. join
assembles exact UTF-16 fields from live elements after separator conversion.
TypedArrayCreateSameType and toReversed/toSorted/with create independent results
through explicit current-realm intrinsic constructor dependencies.
Species/default factories and filter/map/slice/subarray preserve allocation
timing, custom result kinds, tracking views and raw-byte copying. set retains
the pinned raw/numeric and array-like paths, including its documented original-view
read flaw after an aliased conversion clone. toLocaleString uses translated GetV
and Invoke with explicit Number/BigInt locale dependencies. All native
TypedArrayPrototype method bodies are translated. The abstract constructor
adds from/of/species, while the prototype initializer retains source metadata,
the shared Array toString identity and the values/@@iterator alias. These records
use explicit dependencies. All twelve concrete constructor/prototype records and
Uint8Array's six hex/base64 methods are translated, including 16,470 exact codec
comparisons against the pinned upstream dependency. Production builtin installation,
the complete intrinsic graph, Object toString, Number/BigInt locale formatting
and caged storage remain pending. The LibJS status file records the
storage, allocator and native binary16 representation boundaries.
SharedArrayBuffer allocation reserves the maximum capacity while exposing the
initial length. Its constructor, three accessors, growth hook and species-aware
slicing are installed and tested with live DataView witnesses. Cross-agent
shared-memory ordering remains pending, as in the pinned upstream active bodies.
The LibJS package's 212 test files pass in both GC and no-GC mode, and all 100
upstream AST fixtures match exactly with no case overrides. All 884 repository
test files are verified, including the native bridge and eighteen browser
integration files. Eleven interrupted WebGL/WebIDL jobs passed after a fresh
two-job rerun.
The native browser and inline-document layout bridge now prepare page scripts
through LibJS and associate classic execution with translated Script, Realm,
and VM embedding contexts. Sources retain their URLs and parse goals; syntax
failures are positioned and isolated per script. Classic scripts share global
lexical bindings and run promise checkpoints before the next script. The browser
default `--js-engine=javascriptcore` mode uses JavaScriptCore for execution and
its JavaScript objects and jobs. `--js-engine=libjs` executes the supported V
bytecode slice without initializing or falling back to JavaScriptCore. Remaining
bytecode generation, ECMAScript functions, intrinsic/builtin objects, regex
compilation, module linking, and LibWeb host bindings remain untranslated.

The integration passes the browser package's eighteen test files in both GC modes,
the native bridge tests, the production bundle build and both engine headless
smoke checks. The function/array refresh also passes all 11 default screenshot cases
and the pixel-exact same-size SVG source switch. The earlier 25-comparison run
additionally covered 13 pixel-exact SVG paint-server mutation cases.
The Boolean/Symbol, construction, iterator, buffer, DataView, SharedArrayBuffer
and TypedArray record/construction/prototype refresh also passes
`inline-node` and the pixel-exact same-size SVG source-switch comparison after
rebuilding the bundle.

### LibWeb checks

The semantic inventory exits nonzero while structural spellings still require
manual classification. It scans LibWeb implementation and root support files;
the separate LibJS package is excluded from its symbols, fields and review queues
(`db4e4fc`). LibJS gaps remain tracked in `libjs/PORT_STATUS.md`. Its current
baseline is:

```text
$ python3 tools/libweb_translation_audit.py
upstream modules: 76
upstream .cpp files: 1193
upstream implementations: 21401
quarantined name-only coverage shims: 0 files / 0 functions
explicit semantic-divergence markers: 6
reviewed upstream-equivalent trivial implementations: 541
suspicious empty/default-return implementations: 0
  candidate-name-match: 14261
  unmatched: 4158
  language-constructor-or-destructor: 1383
  gc-or-binding-runtime: 655
  consolidated-name-match: 525
  namespace-template-specialization: 177
  language-operator: 124
  language-template-trait: 64
  value-record-field-match: 54

unmatched implementations by module:

   1681 CSS
    588 DOM
   1173 HTML
    312 Layout
    404 Painting

$ v -old-compiler -enable-globals run tools/layout_corpus.v --all
Layout corpus: 1089 passed, 0 failed, 1089 total

$ v -old-compiler -enable-globals test .
Summary for all V _test.v files: 656 passed, 656 total.

$ Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
Ladybird V smoke check passed

$ ./compare_screenshots.sh <four-overflow-wrap-reftests>
4 passed, 4 total (all exact zero-pixel diffs)

$ ./compare_screenshots.sh <24-new-cases>
24 passed, 24 total

$ ./compare_screenshots.sh
11 passed, 11 total (including 3 live-selection, 2 caret, and the
default-ignorable-code-points reftest)
```

The two corpus cases whose checked-in upstream text dumps predate the current
Rust layout output use narrowly documented exact overrides under
`tools/layout_expected/`; the other 1,087 cases compare directly with upstream.
The 2026-09-30 function-delta snapshot taken before the shadow-root registry fix
classifies every changed definition since the March
baseline, including root support and the consolidated anchor/style-element
lifecycle hooks: 0 of 7,247 changed definitions remain unclassified after
counting signature-only changes and removing exact cross-module moves. Its
remaining 4,130-entry structural queue is confined to definitions classified
as added in the five large source/Rust-restructured modules; the audit leaves
those visible instead of accepting them through an old symbol-name match.
That snapshot contains 8,607 added, 7,247 changed, and 5,860 removed definitions.
Its unmatched added entries comprise 1,665 CSS, 1,168 HTML, 590 DOM,
396 Painting, and 311 Layout definitions. These function-delta counts supersede
the older semantic-inventory breakdown printed above.

The subsequent DOM behavioral review implements shadow-root document
registration and adoption from upstream `1284aa854c0`. Author and user-agent
roots register when created and transfer with nested roots when their host is
adopted, including disconnected hosts. Adoption invalidates scope caches
derived from the old document while retaining author and adopted stylesheets.
Document counter-style mutations now refresh inherited counter text in those
roots; focused tests reproduce the stale text before the fix and verify
creation, repeated adoption, transfer back, and finalization. The new
`ShadowRoot::adopted_from` entry resolves to the active V adoption path.

The Editing reconciliation accounts for all 432 current upstream
implementations. Its five primitive command subclasses are dispatched by V's
tagged `EditCommand`, inline undo-step getters use the corresponding typed
record fields, callback traversal returns the same tree-order list for direct
iteration, and C++'s owned-string-to-view helper has no V representation.
Editing therefore has no unmatched structural entries; each explicit mapping
fails open if its concrete V target disappears.

The 2026-09-08 default-body pass exhausted the suspicious-stub queue at that
checkpoint and then
closed the ten unmatched symbols outside CSS, Layout, and Painting. It added
document-owned animation-timeline updates, the observable constructed-sheet
adoption callbacks, and live SVG `use` shadow trees. Consequently every
remaining unmatched symbol at that checkpoint was contained in the three large
modules already under structural and differential audit. The refreshed
September source introduced and reorganized spellings and 18 new trivial-body
review candidates across many modules; the current structural count above is
not a claim that every one lacks behavior.

The Painting state pass then reduced that module from 230 to 146 unmatched
implementations without adding class-shaped facades. It tied `PaintableBox`
geometry, scroll/visual-context state, table metadata, and phase caches to the
live `UsedValues`, `BlockBox`, and `DocumentLayoutResult` records; mapped the
base `Paintable`, line-fragment, and viewport operations to their active
lowering and replay functions; and fixed the one behavioral discrepancy found
during comparison. Static grid items with a non-auto `z-index` are now treated
as positioned by the paint transport, while ordinary static boxes remain in
their normal paint group.

The next active-path pass reduced Painting from 146 to 142. It translated
`Paintable::scroll_ancestor_to_offset_into_view()` through the retained text
fragments and typed containing-block chain, so DOM selections and anonymous
text-control cursors scroll their nearest overflow ancestor or the viewport.
It also restored `SVGPathPaintable::hit_test()`'s raw path-bounds gate: stroke
inflation still contributes layout and paint bounds but cannot make the
inflated margin win `elementFromPoint()`.

`Paintable::box_type_agnostic_position()` now crosses the active DOM/Layout
bridge as well, reducing Painting from 142 to 141. Label activation updates
layout and uses that content-box origin plus the live viewport scroll offset to
recompute a cloned control click's `offsetX`/`offsetY`, as upstream requires.

The inspector-overlay pass then reduced Painting from 141 to 137. The earlier
broken-image branch reduced it to 136 and established the pending third provider
state: image and image-input requests occupy blank replaced space while a new,
in-flight, or pending request can still produce pixels. The current upstream
representation then replaces the bespoke `ImagePaintable` fallback entirely.
Known-broken and source-less elements with nonempty `alt` content attach a
closed UA shadow tree and create an ordinary non-replaced layout node, so CSS
font inheritance, wrapping, selection, and find-in-page use normal text layout.
Source, request, and alternative-text changes refresh that shadow content and
rebuild the node kind when the element moves between fallback text, pending
blank space, and decoded pixels. The `img-alt-text-font` reftest is pixel-exact.

Decoded bitmap data now exposes its retained external-memory size and tracks
live clients for static images as well as animations. Shared resource requests
and the list of available images carry monotonic LRU touch serials and prune to
the upstream 8 MiB/96-entry document limits after successful loads. Entries
whose decoded data still has a display client are excluded from both cache
accounting and eviction: removing them would free no pixels, but would force a
framework-created replacement element to fetch and decode the same URL again.
Focused tests cover external-memory accounting, touch order, size/count
eviction, client registration/release by an image element, and retention of a
live image; the full repository suite passes 651/651.

Decoded image data now also carries the upstream response provenance needed by
canvas security. Shared resource completion preserves the Fetch response's
CORS-cross-origin bit, while the compact synchronous image hook derives the
equivalent opaque no-CORS state from the selected URL and the owning document's
origin. Drawing such an image permanently clears the 2D context's origin-clean
flag. `getImageData()`, HTML canvas data-URL serialization, and blob
serialization then reject with a security error; successful CORS image loads
stay readable. Focused tests cover provenance on bitmap and animated decoded
data, shared and direct image loads, draw-time tainting, pixel readback, and
both HTML serialization paths; the full repository suite remains 651/651.

The viewport content-visibility pass reduces Painting from 136 to 134. Layout
now caches the committed `PaintableBox` objects whose used
`content-visibility` is `auto`, and `ViewportPaintable` exposes the source-shaped
setter and readonly accessor used by the HTML rendering loop. That loop performs
initial viewport-proximity determinations and repeats layout when a previously
undetermined box is initially relevant; it also runs the translated
ResizeObserver gather/broadcast loop to a fixed point. Relevance now includes
focused and selected contents, top-layer descendants, and view-transition
captures as well as viewport proximity.

The backing-store lifecycle pass reduces Painting from 134 to 133. Navigable
viewport changes now restart the source's three-second single-shot timer and
grow device-pixel backing stores with a 256-pixel resize cushion. When the
timer fires, the stores shrink to the exact viewport; each allocation publishes
fresh bitmap IDs to PageClient and the rendering thread. The DOM/Page bridge
supplies the actual device scale, and SVG or child navigables retain the source
early-return behavior.

The 800 checkpoint reconciles the remaining reviewed Layout node/iterator/flex
record shapes and 44 specialized paintable factories, accessors, resets, and
kind discriminators with the active typed lowering path. It also translates
`Layout::css_clamp()` into the flex algorithm, preserving CSS's permitted
maximum-below-minimum ordering, and makes `Node::has_css_transform()` account
for the individual `rotate`, `translate`, and `scale` properties. The full
suite passes 392/392 at this checkpoint.

The 700 checkpoint completes Painting's structural reconciliation against the
renderer-independent command, recording, playback, typed-lowering, and native
resource boundaries, taking Painting from 88 unmatched implementations to
zero. Layout falls from 15 to 4 after translating nested SVG viewport natural
metrics and committed child-viewport sizing, the local margin-box geometry
helper, and inter-word NBSP classification; the active image-provider paths are
also explicitly accounted for. The full suite passes 392/392 at this
checkpoint.

The 600 checkpoint reconciles 100 methods from the previously differential-
tested CSS calculation cluster. Upstream's virtual calculation-node hierarchy
maps to V's live `CalcNode` sum type, its typed record fields, and the parser,
simplifier, resolver, serializer, equality, and Typed OM reification paths.
This reduces the calculation cluster from 238 to 138 and CSS from 696 to 596
without adding class-shaped facade functions. The full suite passes 392/392 at
this checkpoint.

The 500 checkpoint reconciles the next 100 calculation-tree bodies: inversion,
rounding, the inverse and remaining trigonometric functions, exponential and
stepped functions, and calculation-result arithmetic. These map to the same
live `CalcNode` fields and resolver/simplifier paths, reducing the calculation
cluster from 138 to 38 and CSS from 596 to 496. The full suite passes 392/392 at
this checkpoint.

The 400 checkpoint closes the final 38 calculation-tree shapes, then reconciles
the concrete V records replacing the `CalculatedOr` and `PercentageOr` C++
templates, boolean-expression factories, optional column counts, rule-list
iteration, and reviewed stylesheet/image accessors. The pending-image and
associated-font stylesheet lifecycle hooks remain explicitly unmatched. CSS
falls from 496 to 396, and the full suite passes 392/392 at this checkpoint.

The 300 checkpoint reconciles the next 100 CSS bodies with the active V model:
media-feature and `@supports` leaf classes fold into `BooleanExpression`,
selector variants expose typed record fields and parse through the decomposed
complex/simple selector routines, token-stream transactions use the explicit
mark stack, syntax subclasses use one tagged `SyntaxNode`, and eleven error
record hash methods share the exhaustive `ParsingError` key function. CSS falls
from 396 to 296 without adding facade implementations, and the full suite
passes 392/392 at this checkpoint.

The 200 checkpoint reconciles another 100 reviewed CSS shapes: the remainder of
syntax-node serialization, basic-shape serialization and geometry, computed
CSSOM conversion and Typed OM property maps, abstract images, color components,
length contexts, UA style scopes, easing functions, and concrete color fields.
The generated WebIDL self-upcast is classified as a binding-runtime artifact.
CSS falls from 296 to 196 without adding facade implementations, and the full
suite passes 392/392 at this checkpoint.

The 100 checkpoint reconciles another 100 reviewed CSS shapes: typed parser
wrappers and calculation construction, CSS Syntax rule and declaration parsing,
descriptor and Typed OM conversions, rule-subclass records, and per-variant
style-value equality. Known implementation boundaries remain visible rather
than being classified through adjacent code. CSS falls from 196 to 96 without
adding audit-only facades, and the full suite passes 392/392 at this checkpoint.

The zero checkpoint closed the final 100 implementations reviewed against the
2026-03-24 baseline. Direct
translations cover stylesheet invalidation and font/image ownership, numeric
and transform interpolation (including matrix decomposition), grid-track
interpolation and composition, descriptor conversion, Unicode-range
serialization, meter matching, color/style-value operations, list markers, and
text font selection. The remaining C++ ownership accessors, template artifacts,
record fields, and decomposed algorithms are classified only where the active V
path supplies the same responsibility. At that baseline, the audit accounted
for all 18,658 upstream implementations with 0 unmatched, 0 suspicious trivial
bodies, and 0 quarantined coverage shims. The current September audit above
supersedes that historical count. Focused matrix/grid regressions and the full
suite passed 392/392 at this checkpoint.

Flex and grid layout were additionally checked differentially against the upstream
browser with `tools/layout_dump.v`. Flex: a 489-case generated corpus (directions,
wrapping, justify/align keywords, gaps, box-model edges, order, aspect ratios,
item min/max sizes and auto margins) plus an 80-case `align-self` matrix. Grid: a
715-case corpus (track templates including `repeat()`, `minmax()`,
`fit-content()` and `auto-fill`/`auto-fit`, auto-flow modes, explicit and negative
line placement, spans, template areas, named lines, gaps, and the
justify/align-content/items/self keywords).

The grid corpus agrees with `Build/release/bin/Ladybird.app --headless=layout-tree`
on all 715 cases, the flex corpus on all 489, and the `align-self` /
`align-content` matrices on all 80 cases each.

## Native browser rendering

The translated browser builds as `Build/v/Ladybird.app` and passes its
JavaScript/DOM headless smoke check. Its 800x600 `https://example.com` document
capture was compared with an upstream Ladybird capture from the same checkout:

```text
different pixels: 11888 / 480000 (2.4767%)
pixels with channel error over 10: 6767 (1.4098%)
mean absolute error: 0.6846
RMSE: 7.8784
```

The page geometry and content coincide visually; the remaining pixel delta is
concentrated on glyph edges rendered by the two native text backends. The
layout-test comparison path selects Ladybird's Serenity Sans test face.
Production style and geometry already run through `Document::update_style()`,
`StyleComputer`, `Layout::TreeBuilder`, and the typed formatting contexts. The
active compatibility renderer still adapts that typed tree to `BlockBox` and
`PaintCommand`; this transport conversion is a real remaining handwritten
boundary and is not counted as a completed Painting translation. It replays
retained box commands through
Ladybird's stacking-context phase order instead of painting each flattened box
atomically. Its hit-test path reverses that retained phase plan so overlay
chrome, foreground fragments, and border-box fallback preserve their painted
depth without rebuilding paint order or rescanning the DOM for each mouse
event. It resolves the direct DOM owner and applies inverse transforms and
`pointer-events` filtering at the same boundary. The hit plan separately keeps
zero-opacity stacking contexts targetable while excluding non-invertible ones,
and preserves the source's rectangle-only context-root fallback separately from
ordinary boxes' rounded-corner containment.
Committed text runs also remain source-shaped
`PaintableFragment`s instead of being expanded into compatibility word objects
and joined again before native shaping. The native shell records through the
translated `Document::record_display_list()` lifecycle; painting and hit testing
share one retained sorted stacking plan, and command storage crosses the native
boundary without a full-array clone. Retained per-paintable `PaintPhase` command
buckets survive document-level repaints, while `PaintableBox` repaint requests
selectively regenerate that box and its anonymous children. Explicit all-cache
and stacking invalidation clear the whole store, matching the separate C++
invalidation boundaries. Checkbox/radio buckets read live DOM checkedness and
indeterminate state rather than a layout-time attribute snapshot; the translated
`HTMLInputElement::set_checked()` invalidation refreshes the retained commands.
The three-way display-list invalidation mode retains that hit-test plan for
paint-command-only style, focus, selection, media, image, inspector, and
scrollbar changes. The nine properties marked as affecting hit testing upstream
still discard it, and the compatibility renderer eagerly remaps a logically
retained plan when its paint-tree transport snapshot is refreshed so input
dispatch never observes stale pointers or records paint commands synchronously.
Its overlay phase uses Painting's translated scrollbar geometry and
ports PaintableBox's scrollbar colors, mirroring, current-offset placement, and
resize-gripper drawing. That geometry now also drives scrollbar and resize-handle
hit testing, including horizontal-before-vertical checks, resize-corner
precedence, border inflation, and stable chrome-widget identity. Both
`elementFromPoint()` and `elementsFromPoint()` consume the same phase order.
Retained replay and hit testing now share translated
`ScrollState` snapshots: a mandatory root frame and live element offsets
transform descendant content, padding-box clips contain overflow, sticky
constraints track element or viewport scrollports and containing blocks, and
fixed contexts remain rooted to the viewport. Accumulated overflow clips retain
their nested transformed shapes and elliptical per-corner radii in shared
context lists; the native Quartz path intersects those shapes with antialiased
rounded clipping rather than reducing them to bounding boxes. CSS basic-shape
`clip-path` now follows the same accumulated-context order as
C++ and retains move, line, quadratic/cubic Bezier, elliptical-arc, close, and
nonzero/even-odd path state. Quartz clips with the exact retained curves, while
hit testing consumes contours flattened once when the paint tree is built;
neither path is reparsed per command or pointer event. Legacy CSS2
`clip: rect(...)` now follows `PaintableBox::get_clip_rect()` too: it is resolved
from an absolute/fixed box's border box, inserted after its transform and before
`clip-path`, and shared by the box's own paint, descendants, and hit testing.
Negative extents become an empty clip and the four edges use the same rounded
device conversion as C++. Five upstream reftest pairs, including transformed,
offscreen, descendant, and image cases, render with zero differing pixels.
The final `PaintableBox` hit-test gate also rejects points outside normalized
elliptical border radii instead of treating every rounded box as rectangular.
The overlay and visual-context paths now share direct translations of
`PaintableBox::overflow_property_applies()`, `physical_resize_axes()`,
`has_resizer()`, and `is_chrome_mirrored()` instead of embedding those decisions
in compatibility conditionals. SVG/inline/ruby/internal-display exclusions,
table-cell/caption exceptions, viewport and generated-content suppression,
logical-axis mapping, and RTL/vertical chrome placement are covered as one
source-shaped predicate matrix.
Scrollbar layout now follows `PaintableBox::available_scrollbar_length()`,
`absolute_scrollbar_rect()`, `compute_scrollbar_data()`, and
`absolute_resizer_rect()` as separate source-shaped operations. In particular,
resizer-adjusted scrollbar lengths retain C++'s signed geometry for boxes
smaller than the platform gripper instead of being prematurely clamped by the
combined V helper.
Inspector highlighting now records after the ordinary phase stream as well.
Box paintables unite continuation content, padding, border, and margin geometry,
draw the upstream yellow/cyan/green/magenta overlay plus its size tooltip, and
text paintables outline every matching fragment with its red baseline. The
overlay retains scroll, transform, and perspective state while deliberately
discarding clip paths, overflow clips, masks, and effects; changing or clearing
the highlighted DOM node invalidates only the assembled retained display list.
The retained scrollbar objects now also translate `Scrollbar.cpp`'s hover and
thumb-grab state rather than calling a stateless pointer-ratio helper. Hover
enlarges both paint and hit geometry; track presses use C++'s constrained grab
point, captured moves retain that point, and the resulting element scroll
offset is rounded through `CSSPixels::nearest_value_for`. Page's chrome-widget
dispatcher separately preserves captured-before-current-target routing and the
independent `CaptureInput`/`SwallowEvent` decisions. A retained widget index
keeps captured moves O(1), matching C++'s direct object reference rather than
rescanning the paint tree for every pointer event.
`ScrollFrame` and `ScrollState` now expose the source accessors and in-place
`for_each_*_frame()` traversal used by `ViewportPaintable::refresh_scroll_state()`.
The active bridge no longer allocates sticky and ordinary index arrays on every
refresh, `clear()` keeps the vector capacity across paint-tree rebuilds, and
snapshot conversion follows C++'s `FloatPoint` precision. The resulting
snapshot is retained and replaced only when scroll state is dirty, so display
recording, hit testing, and captured chrome dispatch no longer allocate and
copy every frame on each query.
The retained `ScrollState` now owns that dirty bit instead of mirroring it on
the document layout result. Element and viewport scroll-offset storage perform
the invalidation next to the mutation, visual-context rebuilding completes
before offsets are refreshed, and display-list/hit-test/chrome consumers enter
through the shared paint-property update instead of issuing defensive refreshes.
`LIBWEB_VERIFY_SCROLL_STATE=1` force-derives a temporary snapshot after every
skipped refresh and asserts that it matches the retained publication without
replacing its storage.
Scroll-frame parent selection now directly follows
`PaintableBox::nearest_scroll_frame_index()`: fixed paintables attach to the
root frame, ordinary descendants stop at an intervening fixed containing block,
and sticky descendants retain the outer scrollport needed by their constraints.
Percentage sticky insets now resolve against the separate
`PaintableBox::nearest_scrollable_ancestor()` walk. This skips an
`overflow:hidden` containing block even though it owns a programmatic scroll
frame, and uses the next wheel-scrollable ancestor as C++ does.
The overflow-clip path now calls a standalone translation of
`PaintableBox::overflow_clip_edge_rect()`: ordinary boxes start at the absolute
padding box, replaced boxes start at the content box, and the four resolved
clip-margin edges inflate that origin independently.
Outline transport now comes from a direct `PaintableBox::outline_data()`
translation instead of three independent adapter conversions. The operation
resolves `auto` to a 2px solid system accent outline and applies Painting's
shared transparent/none/zero-width suppression before transport.
Border-radius transport now follows `PaintableBox::border_radii_data()` and
`normalized_border_radii_data()` directly. Lengths and overlap factors remain
fixed-point through the source's two refinement passes, and padding-edge clips
only shrink adjacent radii instead of running a second, invented normalization.
Hit-test eligibility now uses a direct
`Paintable::visible_for_hit_testing()` predicate, excluding inert DOM nodes as
well as `pointer-events:none`. Upstream no longer splits inlines around
in-flow blocks, so an interrupting block that declines a hit falls through to
the block container behind it rather than to its inline parent.
The active DOM/layout bridge records the absolute border box of every
paintable an inline generates, one per line. `PaintableBox`'s three absolute
united-rectangle operations unite those boxes, skipping empty boxes after the
first; `HTMLElement` CSSOM offsets therefore span all of an inline's lines
while the line that only hosts an interrupting block contributes nothing,
matching the upstream flat-inline regression.
`PaintableBox::transform_reference_box()` is translated on the same active path:
CSS boxes remap fill/stroke/view to content/border, SVG paintables remap
content/border to fill/stroke, and SVG view-box transforms use the nearest SVG
viewport. `ViewportPaintable::compute_transform()` now composes individual
`translate`, `rotate`, and `scale` before the transform list. The HTML reference
and both WPT percentage-translate reference pairs are pixel-identical; the
mixed HTML/SVG screenshot improved from 24,212 to 9,859 differing pixels and
MAE 4.6117 to 0.2584, leaving raster-edge and text-antialiasing deltas.
`PaintableWithLines::paint_text_decoration()` and
`build_triangle_wave_path()` now replace the renderer-local decoration
reconstruction. Baselines and font metrics come from committed line fragments;
thickness and endpoints use upstream rounding; double-line offsets, native
dotted/dashed strokes, underline position/offset, and the round-joined triangle
wave follow the C++ switch directly. A retained fragment whose style mutation
invalidated the aliased V font cache now rematerializes that cascade through the
document's shared font computer, preserving C++'s immutable-ComputedValues
lifetime across repeated relayouts. The anonymous-wrapper, minimum-thickness,
and underline-offset upstream reference pairs are pixel-identical. Text
selection now follows the adjacent upstream `PaintableWithLines`
foreground pipeline as well. Committed fragments retain their shaped glyph run;
selection and text-control ranges split it at UTF-16 boundaries; explicit
`::selection` color, shadow, and decoration inheritance plus the UA shadow-host
fallback are resolved once; and all backgrounds, shadows, then clipped glyph
runs/decorations are recorded in source order. Selection-state changes
selectively invalidate retained phase commands, while unselected text keeps the
existing coalesced fast path. Quartz consumes the new blurred text-shadow
command and the portable player preserves its layer order with a sharp fallback.
The adjacent `fragment_at_position()` and `paint_cursor()` methods now use the
same retained UTF-16 glyph geometry for a focused editable caret, including the
padding-box fallback for an empty editing host and custom `caret-color`. Empty
block, paragraph, and inline fallbacks use the first available font's ascent
plus descent, capped by line height and centered in its extra leading, so their
geometry remains stable when the first character appears. Parent child offsets
beside text use that text child's retained fragment geometry, so they agree with
equivalent text-node offsets in horizontal and vertical writing modes. Cursor
moves, focus changes, and blink transitions invalidate only the old and new
containing-block foreground buckets, rather than either replaying a stale caret
or discarding the full paint cache.
`PaintableWithLines::hit_test()` and `hit_test_fragments()` now run on that same
retained fragment representation. Exact hits return the text node and
glyph-derived UTF-16 offset; text-cursor misses preserve upstream's nearest-edge
candidate comparison, current-selection ancestry gate, `user-select: none`
exclusion, and empty editable-host offset-zero path. The former active shortcut
that reduced inline content to its containing box remains only as the source
fallback after fragment testing.
Native checkbox and radio foreground painting now uses direct translations of
`InputColors`, `CheckBoxPaintable`, and `RadioButtonPaintable` rather than
renderer-local white boxes and approximate paths. Theme and accent colors,
disabled and active shading, contrast correction, device rounding, rounded
layers, and the exact checkmark path reach the active display list. A focused
upstream control capture has matching geometry and colors; its scale-normalized
MAE is 0.9256, with residuals confined to rasterized edges.
`FieldSetPaintable` now owns fieldset background and border recording on the
active path. Its effective top edge is derived from the rendered legend's
margin box, its background is clipped to the shifted visual border box, and its
top border is replayed only through the device-rounded segments beside the
legend. The recorder-local clips compose with transforms and accumulated
overflow/mask contexts without leaking into descendants or other paint phases;
a transparent-legend capture confirms the former border-through-legend artifact
is gone. Its font-free, scale-normalized upstream comparison has no channel
error above 1 and MAE 0.0244. Geometric list markers also use
`MarkerPaintable::paint()` instead of a renderer-local shape switch. The direct
path preserves CSS-pixel rounding, enclosing device rectangles, exact
disclosure triangles, and typed square/circle/disc commands. Native Quartz now
consumes ellipse commands rather than sending them to the inactive software
surface, restoring the missing circle and disc markers; the five-shape upstream
corpus improves from MAE 0.4082 to 0.1665. Wheel routing follows the C++
containing-block fallback, including
declining
programmatic-only hidden overflow and saturated inner scrollers. These updates
preserve layout and per-phase command caches while refreshing visual scroll
state and dynamic scrollbar thumbs. Uniform rounded box backgrounds now use
one native rounded path, matching the Skia display-list player, rather than a
renderer-local composition of three rectangles and four circles. This removes
six draws per box, fixes translucent corner artifacts, and preserves the arcs
through rotation, skew, and nonuniform scale. The focused nested-overflow
screenshot improved from 103,304 to 4,022 pixels over channel error 3 (MAE
3.2946 to 0.1633); its residual delta is on antialiased path edges. SVG
geometry now reaches the native Quartz renderer as its retained move, line,
quadratic/cubic Bezier, elliptical-arc,
and close segments, including fill rule and stroke cap/join/miter state. URL
`<clipPath>` resources follow `SVGMaskable`'s paint-time path: the attached
resource subtree, target/resource transforms, `userSpaceOnUse` or
`objectBoundingBox` units, per-component `clip-rule`, and component union are
retained in a reusable alpha-mask cache. Empty resources suppress the target;
the mask is deliberately excluded from hit testing, as in C++. SVG `<mask>`
path content now follows the same retained nested-display-list boundary: normal
fill/stroke colors and opacity, `paint-order`, group opacity layers, mask-area
clipping, `maskContentUnits`, and alpha/luminance conversion are composited once
over the complete target context with `destination-in`. URL clips use that same
layer boundary instead of applying antialiased coverage independently to every
leaf command. The shared four-entry native cache rasterizes only each mask's
transformed bounds, not a full-window surface. SVG text is materialized from
the shaped per-code-point computed font cascade into the same quadratic path
representation as `Gfx::Path::glyph_run()`, including lazy author faces and
invisible fallback, so ordinary text and text inside a mask share SVG
fill/stroke/paint-order and mask compositing. Text chunks apply `text-anchor`
once across their nested runs and advance following tspans by shaped advance
rather than outline bounds. SVG `<textPath>` now follows
`Path::place_glyph_runs_along()` too: it measures only the referenced path's
first contour, rotates retained glyph outlines to each tangent, and enforces
the glyph-midpoint cutoff before the same normal or mask path replay. SVG `<image>` now follows
`ImagePaintable` through href/XLink selection, intrinsic-ratio sizing, forced
`contain`, computed object position, `image-rendering` scaling selection,
image-rect clipping, and transformed native bitmap replay. The same ordered
bitmap operations can supply alpha or luminance inside `<mask>`, including
nested group opacity. Canvas boxes now cross the same typed paint boundary:
`CanvasPaintable::paint()` presents an existing surface without allocating one
for untouched elements, retains the RGBA content as `DrawExternalContent`, and
applies upstream scaling-mode selection plus border-shrunken corner clipping.
Native replay consumes that surface directly. Video boxes now retain
`VideoPaintable`'s full representation switch as well: current and first frames
use external content, posters use scaled immutable bitmaps, and the no-data
case records transparent black, all under the same rectangular and
border-shrunken rounded clips. Iframe `srcdoc` documents now cross that boundary
as nested display lists too.
`NavigableContainerViewportPaintable::paint()` updates and records the child at
the iframe content size, clips it to the border-shrunken rounded viewport, and
replays it under the parent transform without rasterizing the child tree.
URL `<linearGradient>` and `<radialGradient>`
fill and stroke paints now retain C++'s same-document resource resolution, href
inheritance and precedence, normalized computed stops, `gradientUnits`,
`gradientTransform`, `spreadMethod`, color interpolation, and paint order.
Radial gradients additionally retain the two focal/end circles, `fr`, C++'s
negative-radius inheritance behavior, and width-relative radius resolution.
Skia consumes both retained gradient styles directly for ordinary paths;
bounded Quartz mask surfaces consume the same data for mask content. Both paths
preserve pad/repeat/reflect tiling instead of substituting the URL paint's
fallback color. SVG `<pattern>` now follows C++'s retained paint-server
path as well: same-document href inheritance, first content-owning linked
resource selection, `patternUnits`, `patternContentUnits`, `viewBox`,
`preserveAspectRatio`, CSS-transform precedence, `patternTransform`, and
non-invertible/empty-tile rejection feed a cached tile display list. Tile
content preserves ordered solid, linear/radial gradient, image, nested-pattern,
stroke, and group-opacity operations. Object-bounding-box content is normalized
against the target origin before rasterization, matching the C++ recorder's
content-origin translation. Quartz caches the resulting high-DPI tile and
repeats it for normal fill/stroke and alpha/luminance mask content. Standard CSS
filters now follow `PaintableBox::resolve_css_filter()` and
`ResolvedCSSFilter::to_gfx_filter()`: retained computed blur, drop-shadow,
brightness, contrast, grayscale, invert, opacity, saturate, sepia, and
hue-rotate operations preserve C++ composition order and create one visual
layer around the complete filtered subtree. Filter layers and SVG masks share
one ordered scope stream, so either may correctly contain the other. The native
Core Image replay uses LibGfx's exact color matrices and device-scaled blur and
drop-shadow geometry instead of filtering individual leaf commands.
`PaintableBox::paint_backdrop_filter()` now uses that same translated resolver
for `backdrop-filter`, records `ApplyBackdropFilter` before the box background
and shadows, and retains the normalized border radii and accumulated clips and
transforms. Quartz snapshots the already-painted destination, applies the
LibGfx operation chain through the shared Core Image implementation, and
composites only the transformed rounded region. If the box also has `filter`,
the sample comes from outside its newly opened filter layer and the result is
painted inside it with the rest of the box. Backdrop presence is cached when
the display list changes (including nested viewports); pages without it remain
on the direct rendering path, and Core Image evaluates only the backdrop's
device bounds. SVG URL filters no longer use the earlier generic sequential
placeholder graph:
`SVGFilterElement::gfx_filter()` is represented with LibGfx constructor input
order and primitive-specific state, including explicit SourceAlpha and
luminance matrices, named-result fallback, blend/composite/arithmetic modes,
component-transfer channel tables, matrix/saturate/hue operations, merge,
morphology, offset, turbulence, displacement, and the specified six-node
drop-shadow expansion. Same-document fragment URLs now resolve the live
`SVGFilterElement`, preserve the standard-CSS-inside/SVG-outside composition
order, and carry the resolved target region and computed flood color/opacity to
native replay. Empty-source, content-generating graphs retain C++'s transparent
target-bounds display-list trigger. Core Image executes flood, every translated
blend/composite mode (including arithmetic and plus-darker), anisotropic blur
and morphology, color matrix/saturate/hue, component-transfer tables, merge,
offset, and channel-selecting displacement while propagating logical graph
extents instead of allocating or flooding the full canvas. Native turbulence,
filter color-space conversions, and decoded-bitmap `feImage` graph inputs now
execute through that graph. The native turbulence node uses Skia's matching
Perlin shader over the retained target bounds and preserves rounded stitch-tile
dimensions. Decoded resources retain their graph URL and target bounds, while
nested pattern display lists replay the same filter layer and bitmap frame. Its
table phase consumes the translated collapsed and separate border collector,
including conflict winners, cell snapping, empty-cell suppression, and exact
rounded-cell repainting. Ordinary block and inline borders now retain their
computed per-edge styles and consume the direct `BorderPainting.cpp`
translation, including elliptical joins, same-color path batching,
dotted/dashed endpoints, inset/outset colors, and double/groove/ridge recursion.
Outlines resolve their computed style and `auto` accent color, inflate the border
geometry with the C++ negative-offset clamp, and enter the same dispatcher.
The root/body branches of `PaintableBox::paint_background()` are now a single
source-shaped operation. When the body's background is propagated to the root
canvas, its `image-rendering` value travels with its color and image layers
instead of leaving the root's sampling mode in place.
Background propagation also identifies the document's first body before
looking for its generated box. If that body has no box, a later rendered body
keeps and paints its own background; containment is read only from the boxes
that actually exist, matching the upstream restyle-time crash fix.
URL backgrounds now retain typed layer data and enter the direct
`BackgroundPainting.cpp` sizing/repetition path after decode. This restores the
source ordering for default sizing, contain/cover, `round` aspect correction,
fixed-point positions, `space` gaps, and attachment handling. Cached replay
refreshes local and viewport scroll offsets, while Quartz resolves tiles in CSS
coordinates, then applies the accumulated transform and the layer's shrunken
elliptical clip radii. The previous screen-AABB sizing and stale-scroll paths
are gone. Non-normal URL layers now paint with all 18 translated CSS blend
modes inside the isolated background group required by
`BackgroundPainting.cpp`, rather than blending directly with page content.
Background sizing and repeat positioning now remain fixed-point `CSSPixels`
through contain/cover scaling, `round` correction, aspect restoration, and the
source's exact first-visible-tile calculation. Ordinary repeat and round layers
without `space` gaps replay as one device-rounded native tiled-image operation,
matching `DrawRepeatedDecodedImageFrame` instead of allocating up to 4,096 tile
rectangles and crossing the renderer boundary once per tile.
Typed linear, radial, and conic gradients now travel through that same ordered
background-image list instead of a separate first-gradient shortcut. Each
gradient is resolved only after `BackgroundPainting.cpp` determines its tile
size with absent intrinsic dimensions, and retains its own origin, clip,
position, size, repetition, attachment, and blend mode. Blocks, inline
fragments, portable SVG, and native Quartz replay all consume the same layer
geometry; transformed native gradients sample in tile-local coordinates and
clip against the exact per-corner elliptical background box.
The gradient parser now follows `GradientParsing.cpp` for interpolation-method
placement, geometry ordering, double-position stops, position-first stops, and
transition-hint attachment. Modern stops select the upstream OKLab default;
legacy stops retain sRGB. Resolved gradients carry that method into every
backend, where the V sampler mirrors `DisplayListPlayerSkia`'s premultiplied
sRGB, linear-sRGB, Lab/OKLab, wide-gamut RGB, and polar-space interpolation,
including hue routing and Skia's powerless-hue neighbor substitution. Portable
SVG uses native sRGB/linearRGB when exact and emits sampled stops for the other
spaces instead of silently falling back to raw sRGB channel mixing.
The same group now implements `background-clip:text`. It records the element's
inclusive-subtree glyph runs, skips absolute/fixed subtrees while retaining
floats, masks the color and all image layers together, and leaves root canvas
backgrounds unmasked. Quartz rasterizes the real configured document font into
one bounded alpha mask before compositing the background group; portable SVG
emits the equivalent user-space text mask.
Full typed Painting
display-list integration remains outstanding.

## Native live DataTransfer items

Window-owned DataTransfer now exposes a stable native live items list and
cached indexed item wrappers. Native length/remove/clear and kind/type/getAsFile
preserve the store's access modes, raw UTF-16 metadata and surviving item identity.
Successful file reads return fresh copied Files; the pinned clear implementation
removes text only and preserves files. At `e775be45`, nine new cases and fourteen
focused cases pass, seventeen selected files pass in both GC modes, and nine
optimized cases pass. Signed startup, two pixel-exact genuine text-item pages and
eleven smoke cases pass. Nonempty files and mode gates use native owner tests.
Public add/getAsString/webkitGetAsEntry/setDragImage, hardware delivery and
weak/foreign wrapper ownership remain pending. See [DataTransfer items
evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEMS_OWNER.md).

## Native DataTransferItemList.add

Window-owned DataTransferItemList.add now selects the native File overload for
one argument and converts data then type as raw UTF-16 DOMStrings for two or more.
Zero arguments fail overload resolution before receiver branding; selected calls
convert before the store's mode gate. Added items share the live indexed wrappers,
and duplicate string types throw fresh typed NotSupportedError objects. At
`bbe330a8`, 9 new / 16 focused cases pass;
15 selected files / 52 cases pass in each GC mode,
and 9 optimized cases pass. Signed startup, two pixel-exact
genuine mixed string/File pages and eleven screenshot smoke cases pass. Public
File names use USVString conversion; copied bytes and access modes have native
owner-task coverage. getAsString/webkitGetAsEntry/setDragImage, physical delivery
and default actions, media ondrag handlers and weak/foreign ownership remain open.
See [DataTransfer item-add evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ADD_OWNER.md).

## Native DataTransferItem.getAsString

Window-owned DataTransferItem.getAsString now brands its native receiver before
required-argument and nullable-callable conversion, then snapshots readable text
as raw UTF-16. It queues an asynchronous unspecified task without a Document;
callbacks receive one argument, retain their captured incumbent owner, and keep
the original data after removal or store changes. Return values and throws are
discarded without then access or exception reporting; queued roots are released
and closing the runtime safely skips pending calls. At `e3ff95fd`, 8 new /
15 focused cases pass; 15 selected files /
47 cases pass in each GC mode, and 8 optimized cases pass.
Signed startup, two pixel-exact asynchronous callback pages and eleven screenshot
smoke cases pass (8 exact, 3 at established tolerances). Native owner fixtures
verify video/audio drag dispatch, callbacks with the actual Page scripting gate
disabled, and asynchronous DOM mutations. Foreign function
realms, weak ownership, entries, drag images, physical delivery/default actions
and media ondrag handlers remain open. The browser still uses JavaScriptCore.
See [DataTransfer string-callback evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_STRING_CALLBACK_OWNER.md).

## Native DataTransferItem.webkitGetAsEntry

Window-owned DataTransferItem.webkitGetAsEntry now brands its native receiver,
ignores extra arguments, and returns a fresh FileSystemEntry snapshot for readable
file items. Protected, removed, disassociated and text items return null. Entries
expose native readonly isFile/isDirectory/name getters through their owner registry;
raw stored names retain lone surrogates and NUL units through the pinned upstream
round trip. Later public constructor/property changes cannot replace native records.
At `fdc13cca`, 12 new / 21 focused cases pass;
15 selected files / 49 cases pass in each
GC mode, and 12 optimized cases pass. Signed startup, two pixel-exact
entry pages and eleven screenshot smoke cases pass (8 exact, 3 at
established tolerances). Real Page fixtures retain drag identity and cancellation
from parsed video to script-created audio listeners. Upstream FIXME path, filesystem
and parent operations remain absent; generic entry callbacks, directory traversal,
physical/default drag delivery, foreign WindowProxy handling and weak ownership
remain open. The browser still uses JavaScriptCore.
See [DataTransfer entry evidence](docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ENTRY_OWNER.md).

## Native media drag/drop handlers

Native media ondrag, ondragend, ondragenter, ondragleave, ondragover,
ondragstart and ondrop now use the existing owner-backed event-handler pipeline.
Native receiver checks precede replay; legacy primitive assignments become null,
object callbacks retain identity, replacement keeps the listener position, and
null removal followed by reactivation appends the slot. Only actual boolean false
cancels dispatch. Parsed video and script-created audio handlers receive the real
DragEvent and native DataTransfer/item payload, with fresh File/Entry snapshots,
balanced settings/VM contexts and the actual Page scripting gate. Raw content
handler source stays uncompiled and remains in the attribute after IDL replacement.
At `a503c977`, 6 new / 20 focused cases pass;
15 selected files / 52 cases pass
in each GC mode, and 6 optimized cases pass. Signed startup, two
pixel-exact public drag-handler pages and eleven screenshot smoke cases pass
(8 exact, 3 at established tolerances). Public page dispatch is
untrusted; focused V fixtures also exercise trusted embedding DOM dispatch.
The compact HTMLMediaElement prototype remains a partial flattened surface.
Physical Cocoa/Page drag production, automatic store transitions/default actions,
weak/foreign ownership and the complete HTMLElement handler hierarchy remain open.
Upstream FIXME setDragImage stays absent without an invented public stub.
The browser still uses JavaScriptCore; existing native play() promises remain complete.
Verification and the physical inventory remain pinned to `a503c977`. 3 later independently authored commits are preserved at documentation base `a79d432b`; their CSS/Layout sources and counts are outside this slice's verified source and inventory counter. A later inventory refresh must account for those separate changes under its own pin.
See [media drag-handler evidence](docs/translation-audit/NATIVE_MEDIA_DRAG_HANDLERS_OWNER.md).

## Native media wheel handler

Native HTMLMediaElement.onwheel now uses the existing owner-backed handler registry,
which exposes 40 handler names. Receiver branding precedes replay. Callback identity,
listener-slot replacement/null removal, exact boolean-false cancellation and the actual
Page scripting gate use the shared EventTarget machinery. Parsed video and script-created
audio receive real WheelEvent deltas and native owner identity, with trusted embedding
dispatch and same-wrapper untrusted public redispatch. Raw content source stays uncompiled.
At `0cd374b6`, 6 new / 13 focused cases pass;
8 files / 27 cases pass in each GC mode,
and 6 optimized cases pass at corrected validation `ea533888`.
The separate compatibility commit removes two redundant CSS option defaults with
zero line-count change; CSS semantic tests pass in both GC modes. Original optimized
and production compilation failures remain preserved without passing credit.
Ten physical production stages pass. The original posthoc provenance child fails a
stale GC-branch parser check; its failure remains preserved and receives no full
supervisor credit. A metadata-only supplemental provenance proof completes with
actual exit zero using the same build/screenshots. Signed startup, two pixel-exact public handler
pages and eleven configured smoke cases pass. Only ordinary actual false sets the
canceled flag, including for a noncancelable event; preventDefault retains its own gate.
Physical Cocoa/Page delivery, default scrolling, blocking-wheel subtree/compositor
invalidation, complete HTMLElement handler coverage and weak/foreign ownership remain
open. The browser still uses JavaScriptCore. Existing native play() promises remain complete.
See [media wheel-handler evidence](docs/translation-audit/NATIVE_MEDIA_WHEEL_HANDLER_OWNER.md).

Native wheel input routing (`33ba13ac`, 2026-10-13 UTC):
Native wheel input reaches the owning Page's actual trusted DOM WheelEvent before scrolling. Cancellation blocks inner and viewport defaults; accepted DOM/style mutations force a fresh hit. Native media/VDOM listeners retain fractional fields and UA-shadow retargeting. Verification on 2026-10-13 UTC covers 23 selected cases in each GC mode (18 unchanged cases plus five corrected Page-fixture cases), signed production startup with three software GG injections, and the 11-case screenshot smoke set (8 exact / 3 retained tolerance). Original failed Page-fixture batches remain without full-batch/test-body pass credit. Generic compact HTMLElement listeners/raw handlers, zoom, nested routing, snap/compositor orchestration and physical OS-device injection remain outside this scope. See [wheel-input evidence](docs/translation-audit/NATIVE_WHEEL_INPUT_ROUTING.md).

Native ordinary Element wheel listeners (`25c58496`, 2026-10-14 UTC):
Ordinary compact Element facades now route case-sensitive wheel add/remove listeners to their actual owning DOM EventTarget, preserving other legacy click/load delivery. Lazy facade resolution and retained created-node identities cover HTML, SVG qualified names and nullable namespaces. Receiver branding precedes one author DOMString conversion; captured native options retain callback/capture identity, once, passive and AbortSignal behavior. Listener return false is ignored; preventDefault retains its gates. Verification on 2026-10-14 UTC composes five unchanged files /16 passing cases with three corrected owner cases in each GC mode (six files /19 cases, six new functions). Original numeric-expression and intermediate conditional-pointer compiler fixture failures retain zero owner-body/full-batch credit. A bounded first-context CanvasHost sizing correction preserves the existing canvas identity and honors dimensions set before getContext. Fresh isolated signed production at the synthetic feature-plus-correction pin completes five stages and verifies six software GG injections, eleven screenshot smoke cases (eight exact /three tolerated) and eight exact SVG regressions. The original canonical preflight has no build credit; the first isolated production retains a canvas-text failure, ten smoke passes and no full-batch/SVG credit. Both failures and a later interrupted build with unavailable terminal status remain preserved without full pass credit; concurrent canonical work is preserved. No onwheel IDL/raw content compilation or full HTMLElement prototype surface is added. See [Element wheel-listener evidence](docs/translation-audit/NATIVE_ELEMENT_WHEEL_LISTENERS.md).

Scoped ordinary Element wheel-listener inventory (`25c58496`, 2026-10-14 UTC):
At this code pin only, the independent counter records 78 owners /2,238
assigned files /433,415 implementation /161,056 test physical V LOC. All
eight feature paths are excluded browser/root support paths: zero assigned
file, implementation or test deltas, with assigned hashes/newlines exact.
`Build/audit-fixes/native-element-wheel-listeners-inventory-current.json` (SHA256 `f27a9da741d5ab51c87a9eec381c4fbc35a38fb95fc914aed4d2854836521a7d`).
The prior 33ba13ac/590ac counter and its separate Page +46 implementation
/+327 test lines /one-file attribution remain dated history, along with
all older inventory, source-unit mapping and finding-ledger records.
`Build/audit-fixes/native-wheel-input-routing-inventory-current.json` (SHA256 `590ac39c939ef72b92c769b0c66f7fdaf09c2825e64ce6a64141dbaa39764557`).
Current global inventory fields, tables and references remain unchanged.
Later independent canonical CSS/Layout changes are outside this code pin
and receive no Element wheel validation or parity credit.

Native compact Element `onwheel` (`d86d5ac2`, 2026-10-14 UTC): HTML, SVG and MathML
facades use their actual EventTarget handler slot, preserving native owner identity,
legacy callback conversion, replacement order and exact false cancellation. Raw HTML
attribute replay preserves equal-text writes and absent removals; raw Element source
remains uncompiled. Seven selected files /17 cases pass in each GC mode through composed
verification: nine cases completed before a CLI interruption and eight remaining cases
completed in persistent runs. Verification uses production 3a3aa08a and tests 29aab226.
Signed build/startup, two exact handler pages, all 11 smoke cases (eight exact) and
eight exact SVG regressions passed. Current global inventory and historical records
remain intact. See [Element onwheel
evidence](docs/translation-audit/NATIVE_ELEMENT_WHEEL_HANDLER.md).

Native compact Element wheel-handler scoped inventory (`d86d5ac2`, 2026-10-14 UTC): all
six owned browser/root implementation and test paths remain excluded by the existing
translation-owner rules. Each owned commit has zero assigned-file, implementation-LOC
and test-LOC delta against its own parent. This append keeps current global tables, pins
and historical ledgers intact. Counter:
`Build/audit-fixes/native-element-wheel-handler-inventory-scoped-v1.json` (SHA256
`e9b99ef0d72ed5fe2595c7a02c3bc59fa17c1851853fffd8e03b67189e8ae507`). [Element onwheel
evidence](docs/translation-audit/NATIVE_ELEMENT_WHEEL_HANDLER.md).

Native compact HTML raw `onwheel` (`16274a24`, 2026-10-14 UTC): Raw wheel attributes
compile lazily into the actual owner's EventTarget slot. Scoped lookup uses the Element
facade, actual cached form owner when available, owning Document facade and relevant
global. FunctionBody validation precedes the scoped factory; strictness, cached callback
identity, listener order, equal-text raw/IDL replacement, CSP checks and exact false
cancellation use the native handler path. Validation: All 23 cases in seven selected
files pass in each GC mode through exact-source composition; production 16274a24 passes
signed build/startup, two exact raw-handler pages, all 11 smoke cases (eight exact) and
eight exact SVG regressions through a retained continuation. The actual JavaScriptCore
function source remains anonymous, and compact named-property surfaces remain partial.
Raw non-wheel handlers, unavailable form-owner models, excluded
media/img/object/fieldset/output/custom owners, foreign realms and physical device
injection remain open. See [raw HTML wheel-handler
evidence](docs/translation-audit/NATIVE_ELEMENT_WHEEL_RAW_HANDLER.md).

Native compact HTML raw wheel-handler scoped inventory (`16274a24`, 2026-10-14 UTC): The
feature owns three assigned DOM paths and five excluded browser/root support paths.
Independent counter result against its own parent: DOM adds one assigned file, six
implementation and 129 test physical V lines against feature parent b01cc68a. All five
browser/root paths and both later fixture-only commits are excluded; their assigned
deltas are zero. Counter:
`Build/audit-fixes/native-element-wheel-raw-handler-inventory-scoped-v1.json` (SHA256
`423f80910bd1daaf59158dcc7525e59823a33b99d8a990321fadce36d5b8786f`) This append
preserves current global tables, pins, references, source-unit mappings and historical
finding ledgers. See [raw HTML wheel-handler
evidence](docs/translation-audit/NATIVE_ELEMENT_WHEEL_RAW_HANDLER.md).

Native compact media raw `onwheel` (`ba8108a9`, 2026-10-14 UTC): Audio/video raw wheel
attributes compile lazily through the actual native owner. The combined Document
compiler verifies the same Runtime, Document, settings, wrapper, cached model and live
MediaElementHost record; an array retains installed owners. Isolated FunctionBody
parsing precedes lazy wrapper resolution, which is followed by slot/source and ownership
rechecks. Lookup uses actual Element -> Document -> Global objects, with no
ancestor-form scope. Cache, listener order, equal-text raw/IDL replacement, CSP,
strictness, scripting gates, original exceptions and exact false cancellation stay on
the native handler path. Actual validation: All 30 cases in nine selected files pass in
each GC mode, including six new cases; the fresh signed browser passes startup, two
exact media raw handler pages, all 11 smoke cases (eight exact) and eight exact SVG
cases. Other raw handlers, unavailable/generic/foreign owners, close during active JS,
partial named-property interfaces, anonymous JSC intrinsic source and physical input
parity remain open. See [raw media wheel-handler
evidence](docs/translation-audit/NATIVE_MEDIA_WHEEL_RAW_HANDLER.md).

Native compact media raw wheel-handler scoped inventory (`ba8108a9`, 2026-10-14 UTC):
The seven owned implementation/test paths are excluded browser/root support under the
sealed owner rules. Verified assigned DOM delta: zero files, zero implementation lines
and zero test lines. Actual independent feature/parent accounting: Against actual parent
58149ba1, all seven feature paths are excluded browser/root support under the sealed
78-owner assignment. Assigned DOM changes are zero files, zero implementation physical V
lines and zero test physical V lines. Counter:
`Build/audit-fixes/native-media-wheel-raw-handler-inventory-scoped-v1.json` (SHA256
`db2fda4bc1e5b241de40e7d5f053316f180ca4c45baa7b99b329ac130a29ffed`) This append
preserves existing global tables, pins, references, source-unit mappings and historical
ledgers. See [raw media wheel-handler
evidence](docs/translation-audit/NATIVE_MEDIA_WHEEL_RAW_HANDLER.md).

Native compact media raw `onplay` / `onpause` (`aa6f0246`, 2026-10-14 UTC):
HTML audio/video attributes now compile lazily through their actual native owner.
The optional name-aware DOM availability guard preserves unsupported or unavailable
raw slots and legacy compilers. The media resolver checks the requested slot before
and after lazy binding; isolated FunctionBody parsing precedes wrapper creation.
Element -> Document -> Global scope, callback caching, CSP and scripting gates,
original exceptions, listener order and balanced owner contexts remain native.
Explicit equal-text attribute writes replace IDL callbacks; absent removals retain
IDL-only callbacks. Actual queued play/pause delivery, replacement before delivery,
reentrant pause, trusted Event identity and pending-promise ordering pass focused
owner tests. All 47 cases in 14
selected files pass in both GC modes, including eight new cases. A fresh signed
Boehm browser passes startup and two pixel-exact author-dispatch pages. The user
then requested broad suites once per ten fixes; the remaining broad screenshot continuation was stopped
and broad smoke/SVG cases have no full-suite credit for this slice. Other raw media names,
generic/foreign owners, partial named-property interfaces, anonymous JSC intrinsic
source and full LibJS/HTML/interface parity remain open. See [evidence](docs/translation-audit/NATIVE_MEDIA_LIFECYCLE_RAW_HANDLER.md).

Native compact media raw lifecycle-handler scoped inventory (`aa6f0246`,
2026-10-14 UTC): Against its actual feature parent, three owned DOM paths add
1 assigned file, 5 implementation and
93 test physical V lines. Seven browser/root support paths are
excluded under the sealed 78-owner assignment. Counter:
`Build/audit-fixes/native-media-lifecycle-raw-handler-inventory-scoped-v1.json` (SHA256 `7d14c9c050b3314215db3864ce01b7a3d9df2e704f13d8f05b8ffa5755e74f62`).
Existing global tables, pins, source mappings and historical ledgers remain
preserved. Accounting adds no behavioral parity or validation credit.
See [evidence](docs/translation-audit/NATIVE_MEDIA_LIFECYCLE_RAW_HANDLER.md).

Native compact media raw `onplaying` / `onwaiting` (`2aab6ba2`, 2026-10-14 UTC):
Owner-local HTML audio/video readiness attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Actual queued waiting preserves pending play promises; actual playing delivers
its raw callback before resolving its captured promise batch, including when
that handler calls pause(). Native Event identity, Element -> Document -> Global
scope, caching, resolver reentrancy, raw/IDL replacement, CSP, scripting gates,
original exceptions and DOM/paint replay pass focused checks. Six new cases and
the three changed boundary fixtures pass: 16 cases in five selected files in
both GC modes. Unsupported-name boundaries now use oncanplay; other raw media
names and unavailable/foreign owners remain open. Production and broad
regression suites are deferred under the user's ten-fix cadence. Batch counter:
1/10 after aa6f0246. The preexisting synchronous buffering-drop waiting path is
outside this slice and differs from the pinned upstream FIXME. See [evidence](docs/translation-audit/NATIVE_MEDIA_READINESS_RAW_HANDLER.md).

Native compact media raw readiness-handler scoped inventory (`2aab6ba2`,
2026-10-14 UTC): All eight owned browser/root support paths are excluded under
the sealed 78-owner rules. Independent feature/parent physical-LF accounting
adds zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-readiness-raw-handler-inventory-scoped-v1.json` (SHA256 `4a5ddcd1962bb29fa86e50defd18600203d011e90c3fb235276c46b3c3a07858`).
Global tables, pins, source mappings and historical ledgers remain preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
1/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](docs/translation-audit/NATIVE_MEDIA_READINESS_RAW_HANDLER.md).

Native compact media raw `oncanplay` / `oncanplaythrough` (`bc80a4b7`, 2026-10-14 UTC):
Owner-local HTML audio/video can-play attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Actual readiness delivery fires canplay before the captured playing promise
batch resolves; canplaythrough follows its fulfillment. A canplay handler may
pause without stealing the previously captured promise batch. Native Event identity, Element -> Document -> Global
scope, caching, resolver reentrancy, raw/IDL replacement, CSP, scripting gates,
original exceptions and DOM/paint replay pass focused checks. Six new cases and
the three changed boundary fixtures pass: 16 cases in five selected files in
both GC modes. Unsupported-name boundaries now use onerror; other raw media
names and unavailable/foreign owners remain open. Production and broad
regression suites are deferred under the user's ten-fix cadence. Batch counter:
2/10 after aa6f0246. See [evidence](docs/translation-audit/NATIVE_MEDIA_CANPLAY_RAW_HANDLER.md).

Native compact media raw can-play-handler scoped inventory (`bc80a4b7`,
2026-10-14 UTC): All eight owned browser/root support paths are excluded under
the sealed 78-owner rules. Independent feature/parent physical-LF accounting
adds zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-canplay-raw-handler-inventory-scoped-v1.json` (SHA256 `d8a72dad76f60ae0753acfec6ebf6c89280c162ff69d89d209e1cc7c827c2ce5`).
Global tables, pins, source mappings and historical ledgers remain preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
2/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](docs/translation-audit/NATIVE_MEDIA_CANPLAY_RAW_HANDLER.md).

Native compact media raw `onloadedmetadata` / `onloadeddata` (`f9ec154f`, 2026-10-14 UTC):
Owner-local HTML audio/video metadata/data attributes compile lazily through
the existing name-aware native compiler and ordered content-attribute replay.
Actual media tasks preserve metadata-before-data notification and consume the
first-data flag when queuing, once per load. Native Event identity, Element ->
Document -> Global scope, caching, resolver reentrancy, raw/IDL replacement,
CSP, scripting gates, original exceptions and DOM/paint replay pass focused
checks. Six new cases and the two changed binding boundary fixtures pass:
12 cases in four selected files in both GC modes. Unsupported-name boundaries
now use onerror; other raw media names and unavailable/foreign owners remain
open. Production and broad regression suites are deferred under the user's
ten-fix cadence. Batch counter: 3/10 after aa6f0246. See [evidence](docs/translation-audit/NATIVE_MEDIA_DATA_RAW_HANDLER.md).

Native compact media raw metadata/data-handler scoped inventory (`f9ec154f`,
2026-10-14 UTC): All seven owned browser/root support paths are excluded under
the sealed 78-owner rules. Independent feature/parent physical-LF accounting
adds zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-data-raw-handler-inventory-scoped-v1.json` (SHA256 `347a64f0ce1cf3a34bdbfd5645693321965b25bc2df0dd4d2979c6e9b46df767`).
Global tables, pins, source mappings and historical ledgers remain preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
3/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](docs/translation-audit/NATIVE_MEDIA_DATA_RAW_HANDLER.md).

Native compact media raw `onratechange` / `onvolumechange` (`5d549d51`;
owner-fixture corrections `d1a0df47` and `89fab31e`, 2026-10-14 UTC):
Owner-local audio/video settings attributes use lazy native compilation and
ordered content-attribute replay. Changed setters queue native media tasks;
equal writes and rejected values add none. Six focused cases per GC mode pass
across three detached source epochs: binding cases pass at the original
feature, and owner cases pass at the final explicit-branch correction. Original
combined commands exit 1 after binding success on owner C compilation; owner
runtime cases are zero. The first owner-only correction also exits 1 at the V
frontend with zero runtime cases. Both failures, all sources, helpers and logs
remain retained. The final epoch keeps identified foreign committed changes
without adding root feature or broad-suite credit. Scopes, Event identity,
owner gates, replacement/removal, reentrant setters, exceptions, later listeners
and retained DOM painting are covered. Production and broad suites are
deferred. Batch: 4/10 after aa6f0246; fixture corrections belong to this one
translation slice. See [evidence](docs/translation-audit/NATIVE_MEDIA_SETTINGS_RAW_HANDLER.md).

Native media settings-handler component inventory (`5d549d51`,
`d1a0df47`, `89fab31e`, 2026-10-14 UTC): Three root components compare
the original five-path feature and two one-path owner-fixture corrections
against their actual parents. Foreign intervening commits are excluded;
final current source hashes are stored separately against frozen-v3. The five
owned browser/root paths are excluded under sealed 78-owner rules, adding zero
assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-settings-raw-handler-inventory-scoped-v4.json` (SHA256 `210c1aa9c3436fe0ae6d48d4fac3e7cfaf5dccf4a89a3e53d7444676bfda1220`). Global
tables, pins, source mappings and historical ledgers remain preserved.
Accounting adds no behavior or validation credit. Three source epochs and both
failed owner-compilation attempts remain explicit. Batch stays 4/10 after
aa6f0246; fixture corrections and documentation add no translation fix.
See [evidence](docs/translation-audit/NATIVE_MEDIA_SETTINGS_RAW_HANDLER.md).

Native compact media raw `ontimeupdate` / `ondurationchange` (`ef218fdf`, 2026-10-14 UTC):
Owner-local HTML audio/video timeline attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Actual native duration calls, including equal known values, queue durationchange;
NaN resets are silent. Fresh normal time-marches tasks deliver timeupdate,
and its running-handler guard suppresses a reentrant request. Parsed video
and created audio keep live duration and currentTime values, Element ->
Document -> Global scope, Event identity, cache and owner gates. Prequeued
replacement/removal, original strict exceptions, later listeners and retained
DOM painting pass six cases in two selected files in both GC modes. Other raw
media names and unavailable/foreign owners remain open. Production and broad
regression suites are deferred under the user's ten-fix cadence. Batch counter:
5/10 after aa6f0246. See [evidence](docs/translation-audit/NATIVE_MEDIA_TIMELINE_RAW_HANDLER.md).

Native compact media raw timeline-handler scoped inventory (`ef218fdf`,
2026-10-14 UTC): Five owned browser/root support paths are excluded under the
sealed 78-owner rules. Independent feature/parent physical-LF accounting adds
zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-timeline-raw-handler-inventory-scoped-v1.json` (SHA256 `956970f14822b2169d7ce285ee59179e20f5a4bf8b26cbdcae57127900d4199c`).
Global tables, pins, source mappings and historical ledgers are preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
5/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](docs/translation-audit/NATIVE_MEDIA_TIMELINE_RAW_HANDLER.md).

Native compact media raw `onseeking` / `onseeked` (`b864154a`, 2026-10-14 UTC):
Owner-local HTML audio/video seek attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Controlled metadata/range/clock hooks exercise parsed-video currentTime
accurate seeks and created-audio fastSeek fast-after requests. Actual seeking
tasks observe the live seeking flag; native completion clears it before
timeupdate and seeked delivery. Element -> Document -> Global scope, Event
identity, cache and owner gates, live prequeued/reentrant replacement/removal,
strict original exceptions, later listeners and retained DOM painting pass
six cases in two selected files in both GC modes. HAVE_NOTHING and failed conversion paths
queue no seek events. Real network, decode, backend completion,
cancellation, seeks without a playback manager, and full seek-range parity
receive no new credit. The tested committed feature epoch supplies these passes. The initial seal
refused concurrent foreign main.v paint changes; its actual failed record is
retained. Four current owned files and two exact main gates are authenticated
through retained snapshots; current foreign paint receives no pass credit.
Production and broad suites remain deferred. Batch counter: 6/10 after aa6f0246.
See [evidence](docs/translation-audit/NATIVE_MEDIA_SEEK_RAW_HANDLER.md).

Native compact media raw seek-handler scoped inventory (`b864154a`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds zero
assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-seek-raw-handler-inventory-scoped-v1.json` (SHA256 `61d0c1314a40b3bb5b59c183d4d7a49ba71512fbd61063dd0b3d7d773a0e9179`).
Global tables, pins, mappings and historical ledgers stay preserved; accounting
adds no behavioral or test credit. Batch remains 6/10 after aa6f0246, since
this independent documentation commit is not another translation fix.
See [evidence](docs/translation-audit/NATIVE_MEDIA_SEEK_RAW_HANDLER.md).

Native compact media raw `onprogress` / `onsuspend` (`739e00b8`, 2026-10-14 UTC):
Owner-local HTML audio/video progress attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Fresh native ongoing processing queues loading and its initial progress;
the actual queued completion dispatches progress, moves networkState to idle,
then dispatches suspend within one task. Parsed video and created audio expose
live loading/idle states, Element -> Document -> Global scopes, native Event
identity/cache/owner gates and retained painting. Equal raw writes, prequeued
replacement/reentrant completion, removals, scripting gates, strict original
exceptions and later listeners pass six cases in two files in both GC modes.
No network, timer-boundary, preload/cancel, decoding/backend or completion
readiness credit is claimed. Four current owned files and two exact main
gates are authenticated through retained snapshots; current full main and
foreign changes receive no test credit. Production and broad suites remain
deferred. Batch counter: 7/10 after aa6f0246. See [evidence](docs/translation-audit/NATIVE_MEDIA_PROGRESS_RAW_HANDLER.md).

Native compact media raw progress/suspend scoped inventory (`739e00b8`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds
zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-progress-raw-handler-inventory-scoped-v1.json` (SHA256 `07dd77510b5be5d09cafc3b80723e24291f77107a3c3faeb71141d42d9db94bb`).
Global tables, pins, mappings and historical ledgers stay preserved;
accounting adds no behavioral or test credit. Batch remains 7/10 after
aa6f0246, since this independent documentation commit is not another
translation fix. See [evidence](docs/translation-audit/NATIVE_MEDIA_PROGRESS_RAW_HANDLER.md).

Native compact media raw `onabort` / `onemptied` (`50d3cd34`, 2026-10-14 UTC):
Owner-local HTML audio/video reset attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Actual source-empty JavaScript load calls discard only each owner's pending
media tasks and queue abort, emptied and a conditional position timeupdate.
Parsed video and created audio retain callback caches/scopes, native Event
identity, owner gates, live replacement/reentrant load/removal and painting.
Closed scripting gates preserve raw strings; a strict abort exception leaves
later listeners and the separate emptied task intact. Six cases in two files
pass in both GC modes. V's existing eager empty-resource selection exposes
Empty(0), differing from upstream's immediate NoSource(3) and queued
stable-state selection; that timing deviation remains. No complete source
selection/EMPTY-reset, prior promises, play/seek policy, network/fetch,
decoder/backend or timer-boundary credit is claimed. Four current files and
two exact main gates are authenticated through retained snapshots, with no
full-current/foreign-main test credit. Batch: 8/10 after aa6f0246; production
and broad suites remain deferred. See [evidence](docs/translation-audit/NATIVE_MEDIA_RESET_RAW_HANDLER.md).

Native compact media raw abort/emptied scoped inventory (`50d3cd34`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds
zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-reset-raw-handler-inventory-scoped-v1.json` (SHA256 `92535a67615d288fc4c5b7001fdd34c1a3ddd7c4c9c27cd296e478209b4f9677`).
Global tables, pins, mappings and historical ledgers stay preserved;
accounting adds no behavioral or test credit. Batch remains 8/10 after
aa6f0246, since this independent documentation commit is not another
translation fix. See [evidence](docs/translation-audit/NATIVE_MEDIA_RESET_RAW_HANDLER.md).

Native compact media raw `onloadstart` (`b4a325cb`, 2026-10-14 UTC):
Owner-local HTML audio/video loadstart attributes compile lazily through the
existing name-aware native compiler and ordered content-attribute replay.
Parsed video and created audio source replay plus explicit JavaScript load
produce two trusted native callbacks and static response-hook calls per owner.
V invokes each callback synchronously before its hook and native load return,
while loading with empty currentSrc and HAVE_NOTHING readiness. Six cases in
two files pass in both GC modes, covering scopes/cache/Event identity,
latest raw bodies before queued load invocation, nested same-source load,
removals, scripting gates, strict original exceptions, later listeners and
painting. Upstream queues selection/loadstart and installs currentSrc before
delivery; that existing V timing deviation remains. No generation-cancel,
source-switch, error-interface, network/backend, promise or full parity
credit is claimed. Four current files and two exact main gates are
authenticated through retained snapshots, with no full-current/foreign-main
credit. Batch: 9/10 after aa6f0246; production and broad suites remain
deferred. See [evidence](docs/translation-audit/NATIVE_MEDIA_LOADSTART_RAW_HANDLER.md).

Native compact media raw loadstart scoped inventory (`b4a325cb`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds
zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-loadstart-raw-handler-inventory-scoped-v1.json` (SHA256 `8b35cc3810a833155a918c22a226234024c7fe191a877e12e332e94ae8a9b864`).
Global tables, pins, mappings and historical ledgers stay preserved;
accounting adds no behavioral or test credit. Batch remains 9/10 after
aa6f0246, since this independent documentation commit is not another
translation fix. See [evidence](docs/translation-audit/NATIVE_MEDIA_LOADSTART_RAW_HANDLER.md).

Native compact media raw `onended` / `onresize` (`05655652`, 2026-10-14 UTC):
Owner-local HTML audio/video raw attributes compile lazily through the
existing native compiler and ordered content-attribute replay. Controlled
native video dimensions supply trusted resize tasks; equal or empty dimensions
do not. Parsed video and created audio expose the preserved deferred ended
flag and native timeupdate/pause/ended task order at a controlled endpoint.
Six focused cases cover scopes/cache, native Event identity, equal writes,
latest prequeued raw bodies, reentry/removals, scripting gates, original strict
exceptions, later listeners and retained painting. No decoder/backend,
live JavaScript video geometry, pending-promise or full playback parity credit.
Ten-fix validation combines focused 2/6 with explicit initial native 40/126
passing subsets plus isolated corrected invocation fixture 1/5 per GC mode,
giving 43 files/137 cases without repeating successful native files. Initial
native exits remain 1/1; aggregate success does not give those batches whole
pass credit. Full LibJS original exits are 0/0: default retains 232 explicit
rows plus unchanged missing 2/3 observed once; no-GC retains all 234 rows.
All effective 234 files pass each mode without a full suite repeat; AST 100
is exact, and the fresh signed Boehm browser passes startup, two exact wheel
pages, default 11 smoke with unchanged tolerances and eight exact SVG cases.
Prior records, scratch and unrelated work remain retained. Broad baseline
advances from aa6f0246 to 05655652; cadence resets to 0/10 only after the
actual broad terminal receipts. No full repository or full interface parity
claim. See [evidence](docs/translation-audit/NATIVE_MEDIA_COMPLETION_RAW_HANDLER.md).

Native compact media raw ended/resize scoped inventory (`05655652`,
2026-10-14 UTC): Five owned browser/root paths remain excluded under the
sealed 78-owner rules. Original feature and one-path fixture-repair byte and physical-LF accounting
against their separate actual parents
adds zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-completion-raw-handler-inventory-scoped-v2.json` (SHA256 `94636fc4d955f1876457b225e9670258514bded337ed9c9dbdc0bd7c8a805730`).
Global tables, pins, mappings and historical ledgers stay preserved;
counting adds no behavior/test credit. The completed ten-fix broad batch
retains 43/137 native union per GC mode, full LibJS 234 each GC, exact AST 100
and signed production/screenshot evidence; baseline is 05655652 and the
next batch remains 0/10. This independently reviewable documentation commit
is not another translation fix. See [evidence](docs/translation-audit/NATIVE_MEDIA_COMPLETION_RAW_HANDLER.md).

Native compact media raw `onerror` (6ccb30aa, 2026-10-14 UTC):
HTML audio/video raw error attributes compile lazily through their actual native owner and ordered content-attribute bridge. Media callbacks receive one Event argument, including genuine ErrorEvent probes; Window's special error convention remains separate. Seven new cases cover native failure records/events, scopes/cache, replacement/removal, scripting/CSP gates, original exceptions, retained painting, captured play promise ordering and reentrant load(). Focused evidence combines seven passing v2 cases and four corrected owner cases per GC mode, totaling 11 cases across three files; the passing seven are not rerun. Failed whole-batch attempts remain retained without wholesale pass credit. Twelve old browser boundary fixtures receive static-only verification of their three-line onstalled substitution. Native MediaError JavaScript getters and backend scheduling remain open. Broad regression, production and screenshot checks are deferred; batch counter is 1/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_ERROR_RAW_HANDLER.md).

Native compact media raw `onerror` (6ccb30aa, 2026-10-14 UTC):
All 18 unique browser/root implementation and test paths remain outside the sealed assigned DOM inventory. The feature adds 766 physical V lines in its two new test files; the focused owner-fixture correction adds seven more, for 773 lines across 19 physical transaction rows and 18 unique paths. Runtime gates and boundary replacements keep their physical line counts. Assigned DOM files, implementation lines and test lines each change by zero. Global ownership tables and prior ledgers remain preserved. Counting adds no behavioral credit, and this documentation commit is not another translation fix. Batch remains 1/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_ERROR_RAW_HANDLER.md).

Native MediaError and media error getter (1801de0b, 2026-10-14 UTC):
Native HTMLMediaElement.error now returns null or a stable runtime-local wrapper for its actual MediaError record. The readonly branded code/message getters preserve exact NUL/non-BMP strings; the illegal constructor, constants and interface metadata are installed in the Window realm. Saved errors survive load/reset/replacement, foreign wrappers reject, and public close guards reject closed access and release protected roots. The retained three passing owner cases and four corrected binding cases provide seven focused new cases per GC mode, including actual failure callbacks and play/reentrant-load ordering. Controlled hooks do not establish backend scheduling or full playback parity. Broad, production and screenshot checks remain deferred; batch is 2/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_ERROR_HOST.md).

Native MediaError and media error getter (1801de0b, 2026-10-14 UTC):
The five unique native media-error implementation/test paths remain outside assigned DOM inventory. Across seven physical transaction rows (feature plus test correction), this excluded support slice adds 406 physical V test lines and 137 physical V implementation lines; assigned DOM files, implementation lines and test lines change by zero. Previous inventory and evidence records remain preserved. This documentation update adds no behavior credit and does not increment the fix count. Batch remains 2/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_ERROR_HOST.md).

Native media played and seekable getters (c275ad4e, 2026-10-14 UTC):
Native audio/video played and seekable getters now return fresh static TimeRanges wrappers for the actual V model snapshots. Saved ranges survive pause, resource replacement and load/reset; native receiver checks precede replay, original replay exceptions survive, and old getter indexes remain intact. The retained three passing binding cases and two corrected owner cases provide five focused new cases per GC mode, including parsed/created media, actual load/play/pause callbacks, scope lookup and retained painting. Existing V pause-time played recording and response-populated seekability are preserved; continuous playback, normalization and unbounded/MSE generation remain outside this binding slice. Broad, production and screenshot checks are deferred; batch is 3/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_TIMELINE_RANGES_HOST.md).

Native media played and seekable getters (c275ad4e, 2026-10-14 UTC):
The three native timeline-range implementation/test paths remain outside assigned DOM inventory. Across four physical transaction rows (three feature paths plus one fixture correction), they add 380 physical V test lines and four physical V implementation lines; assigned DOM files, implementation lines and test lines change by zero. Previous ownership tables, inventory and evidence remain preserved. This documentation update adds no behavioral credit or fix count. Batch remains 3/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_TIMELINE_RANGES_HOST.md).

Native media canPlayType and completed SVG-video namespace guard (89c63468 / a1a5fcf8 / 4c78eaa2, 2026-10-14 UTC):
Native canPlayType() now exposes the actual V media classifier through branded one-argument DOMString conversion followed by compact replay. Original exceptions and exact primitive results survive; existing MIME/codecs limitations remain. Owner validation also exposed an unsafe SVG video cast, fixed separately by HTML-namespace checks in both page video installers, document bootstrap, canvas frame selection, and retained layout conversion. Retained binding cases and fresh owner/namespace cases cover seven distinct cases per GC mode. The native operation is fix4 and the namespace guard is fix5; broad suites, production builds and screenshots remain deferred at 5/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_CAN_PLAY_TYPE_HOST.md).

Native media canPlayType and completed SVG-video namespace guard (89c63468 / a1a5fcf8 / 4c78eaa2, 2026-10-14 UTC):
The native canPlayType feature changes three excluded browser/root paths, adding 325 physical V test lines and 21 implementation lines. The namespace guard and its follow-up add 153 test lines and four implementation lines. Across seven transaction rows and six unique paths: 478 test lines and 25 implementation lines; assigned DOM files, implementation lines and test lines each change by zero. Previous ownership tables and records remain preserved. Documentation and inventory add no behavioral credit or fix count. Batch remains 5/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_CAN_PLAY_TYPE_HOST.md).

Native media defaultMuted (af34b569, 2026-10-14 UTC):
Native defaultMuted now reflects the actual HTML audio/video muted content attribute through branded native boolean accessors. Setters check the receiver, apply ToBoolean, replay pending DOM changes, then mutate and synchronize the attribute. A captured media-only WeakMap synchronizes the compact facade without invoking author attribute methods, so later dirty snapshots preserve the write. Runtime muted and playback/fetch state remain independent. Five focused cases cover metadata, receiver ordering, ToBoolean, normalization, replay exceptions, cleanup, parsed/created owners, poisoned intrinsics and retained painting. Synchronous customized-built-in CEReactions delivery remains open. The isolated committed source earns test credit; concurrent rendering and full HTMLElement behavior remain outside this slice. Broad suites, production builds and screenshots remain deferred at 6/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_DEFAULT_MUTED_HOST.md).

Native media defaultMuted (af34b569, 2026-10-14 UTC):
The defaultMuted slice changes six excluded browser/root paths: the host record, native binding, private reflection bootstrap, two focused test files and two media bootstrap gates in main.v. Feature-parent physical-LF accounting adds 337 V test lines and 94 implementation lines while assigned DOM files, implementation lines and test lines each change by zero. Existing ownership tables and prior ledgers remain preserved. This documentation update adds no behavioral credit or fix count; cadence remains 6/10 after 05655652.
See [evidence](docs/translation-audit/NATIVE_MEDIA_DEFAULT_MUTED_HOST.md).

Native media loop (2e06dfd2, 2026-10-14 UTC):
HTML audio/video facades expose native loop getter/setter functions. Reads use the actual loop content attribute; writes apply WebIDL boolean conversion, normalize presence to an empty value or remove the attribute, and synchronize captured facade state before a later dirty replay. Native branding precedes replay, author conversion hooks stay untouched, and replay exceptions retain their JavaScript identity. The V model reads its live DOM owner, retains an ownerless fallback, and captures loop presence at the actual playback endpoint. Active looping seeks to zero without pause/ended; paused looping does not seek, and later mutations preserve the captured non-loop endpoint decision. Non-loop completion dispatches timeupdate, rechecks live position, direction and paused state before conditionally pausing, then fires ended. Seven distinct focused cases pass per GC mode. The original default-GC run exited 1 and receives no whole-run pass credit; its five passing binding/DOM cases are retained and combined with the corrected two-case owner test, whose actual test exit is zero. Its single-row output initially made the evidence wrapper exit 1; a fresh parser authenticates the successful output without rerunning it. The first no-GC run passes all seven cases in three files with test and supervisor exits zero. Synchronous customized-built-in CEReactions timing and full media backend behavior remain open. This is fix 7/10; the fixture repair does not advance the counter, and broad suites remain deferred.
See [evidence](docs/translation-audit/NATIVE_MEDIA_LOOP_HOST.md).

Native media loop (2e06dfd2, 2026-10-14 UTC):
The five-path feature adds 53 implementation LF and 503 focused-test LF: three native binding cases, two browser-owner cases, and two DOM-owner cases. The separate one-path owner fixture repair adds 5 test LF, making 508 test LF across six physical transaction rows and five unique support paths. All paths remain outside assigned DOM ownership, so the assigned DOM file, implementation-line, and test-line deltas are zero. Seven distinct focused cases pass per GC mode: default combines five retained cases with the corrected owner test’s two cases, and the first no-GC run passes all seven cases in three files. Original failed batch and single-row evidence-parser failure remain retained without whole-wrapper pass credit; successful test output is authenticated without repeating passing files. Prior preservation covers 236,808 authenticated records without rehashing historical files; the broad-suite cadence remains 7/10 after the fixture repair.
See [evidence](docs/translation-audit/NATIVE_MEDIA_LOOP_HOST.md).

Native media autoplay (446dcc55, 2026-10-14 UTC):
HTML audio/video facades expose native autoplay accessors that brand the receiver, apply WebIDL boolean conversion without author conversion hooks, replay pending DOM changes, and reflect actual attribute presence. The setter publishes protected facade state before model mutation can fetch and reenter JavaScript, preserving an inner autoplay=false write. The model reads live DOM presence, retains an ownerless fallback, preserves parsed nonempty values, and notifies only existing HTML media owners for unnamespaced autoplay mutations. Adoption installs the destination document hook, so current origin policy and sandbox flags govern deferred selection. An allowed change resumes automatic preload="none" fetching once; controlled responses exercise playback and native events. Seven focused cases in three files passed in both GC modes, with actual test and supervisor exits zero and identical before/after source snapshots. Controls lifecycle, native enumerated preload, full media backend behavior and synchronous customized-built-in CEReactions timing remain open. Cadence is 8/10; broad suites, production builds and screenshot suites remain deferred.
See [evidence](docs/translation-audit/NATIVE_MEDIA_AUTOPLAY_HOST.md).

Native media autoplay (446dcc55, 2026-10-14 UTC):
The eight-path feature adds 87 implementation LF and 599 test LF across three new test files: binding 173, browser owner 222 and HTML owner 204. Under authenticated sealed 78-owner rules, DOM's three existing core paths add 12 implementation LF (6 state-hook, 1 document field, 5 element notification), zero test LF and zero files. HTML adds 35 implementation LF, 204 test LF and one file. Excluded native/browser/root support adds 40 implementation LF, 395 test LF and two files. These are scoped feature-parent deltas; global ownership tables and legacy totals retain their original pins, with no full recount. Seven focused cases passed in each GC mode; source hashes, modes, index, native SDK and toolchain remained unchanged. Prior preservation covers 255,624 authenticated records without a historical union walk, and cadence remains 8/10.
See [evidence](docs/translation-audit/NATIVE_MEDIA_AUTOPLAY_HOST.md).

Native media preload (169c907e, 2026-10-15 UTC):
HTML audio/video facades expose native preload accessors. The getter returns canonical none, metadata or auto from live DOM content, with metadata for absent, empty and invalid values. Setters brand the receiver, convert once to DOMString with NUL/lone-surrogate preservation, replay pending changes, publish the raw string through protected facade synchronization, then mutate the actual attribute. Raw strings and canonical getter values remain distinct; an inner preload="none" written during fetch reentry survives. The existing DOM resource notification now covers autoplay and preload, retaining namespace, lazy-owner and adoption boundaries. Leaving a deferred none state resumes automatic fetching once while playback remains subject to policy and sandbox; explicit load and permitted autoplay retain their existing overrides. Seven focused cases in three files passed in both GC modes, with actual test and supervisor exits zero and unchanged before/after source snapshots. Metadata-only fetching, controls lifecycle, full backend/interface parity and synchronous customized-built-in CEReactions timing remain open. Broad suites, production builds and screenshots remain deferred at 9/10.
See [evidence](docs/translation-audit/NATIVE_MEDIA_PRELOAD_HOST.md).

Native media preload (169c907e, 2026-10-15 UTC):
The nine-path feature adds 60 implementation LF and 574 test LF across three new files: binding 161, browser owner 190 and HTML owner 223. Six implementation paths change bytes: native binding +37 LF, private bootstrap +1, HTML model +22, and three DOM core paths with zero net LF. Sealed 78-owner accounting therefore records DOM +0 implementation LF, +0 test LF and +0 files; HTML +22 implementation LF, +223 test LF and +1 file; excluded browser/root support +38 implementation LF, +351 test LF and +2 files. These are scoped feature-parent deltas, with legacy global tables and pins preserved and no full recount. Seven focused cases passed in each GC mode, with all test and supervisor exits zero. Prior preservation inherits 265,099 authenticated records without a historical union walk; cadence is 9/10.
See [evidence](docs/translation-audit/NATIVE_MEDIA_PRELOAD_HOST.md).

Native media crossOrigin (f2e223c9, 2026-10-15 UTC):
HTML audio/video facades expose native crossOrigin accessors with nullable DOMString reflection and canonical anonymous/use-credentials getters. Null, undefined and omitted setter input remove the content attribute; other inputs receive one UTF16-preserving conversion before replay, followed by captured raw-string synchronization before the DOM/model write. Branding precedes conversion and original exceptions remain intact. The typed V query reads the live DOM owner after direct mutations and adoption without restarting media or promoting deferred resource selection. Both original three-file runs exited 1: only the native binding file/three cases passed in each GC mode, while both owner files failed compilation. A separate two-path fixture correction preserves every input and assertion; the two owner files/four cases now pass in each GC mode with actual test and supervisor exits zero. Every tracked source hash except those two fixture paths, and every tracked mode, was verified equal to the original source. Combined focused credit is three files/seven cases per mode: three retained binding cases plus four fresh owner cases. This remains fix 10/10, awaiting the broad batch; fixture repair does not increment the cadence. Full media transport CORS enforcement, controls lifecycle parity and synchronous customized-built-in CEReactions timing remain open.
See [evidence](docs/translation-audit/NATIVE_MEDIA_CROSS_ORIGIN_HOST.md).

Native media crossOrigin (f2e223c9, 2026-10-15 UTC):
The original five-path feature adds 65 implementation LF and 567 test LF. Its separate two-path fixture correction adds four test LF, yielding 571 total test LF: native binding 161 LF/3 cases, browser owner 217 LF/2 cases, and HTML owner 193 LF/2 cases. Across both transactions there are seven physical rows and five unique paths. Assigned HTML gains 19 implementation LF, 193 test LF and one test file. Excluded browser/root support gains 46 implementation LF, 378 test LF and two test files. Assigned DOM file, implementation-line and test-line deltas are zero; historical owner tables retain their pins. Both original whole selections failed and receive no wholesale pass credit. Only binding three-case credit per GC mode is carried; fresh two-owner/four-case validation passes in both GC modes with actual test and supervisor exits zero. The later ten-fix checkpoint will carry the verified focused three-file/seven-case composite without rerunning it and select only the remaining 63 native files/189 cases for a 66-file/196-case union per mode. All broad claims and the cadence reset remain pending.
See [evidence](docs/translation-audit/NATIVE_MEDIA_CROSS_ORIGIN_HOST.md).

Native media reflection ten-fix checkpoint (2026-10-15 UTC):
All selected validation for the native media reflection ten-fix checkpoint passed. Each GC mode has a disjoint 66-file/196-case native union: 63 newly checked files/189 cases plus the verified three-file/seven-case focused composite. Both GC modes passed all 234 LibJS files/778 test functions, and the unchanged official AST driver matched all 100 upstream cases exactly. Production carries the successful signed Boehm build, signing and startup from the retained failed original attempt; the production-only recovery passed two exact comparisons of retained page-load captures, eleven default smoke cases (eight exact, three under existing allowances), and eight exact SVG guards on the same signed executable. No browser rebuild, retained-pair recapture or successful focused-check rerun occurred. The authenticated evidence seal retains cadence at 10/10; only the final supervisor and root actual-zero receipt can reset it to 0/10 at tested fixture epoch f2e223c9e189004f0694c628535b286ed39a87fd. Browser execution still uses JavaScriptCore; full LibJS and native media backend/interface parity remain open.
Native reflection ten-fix checkpoint: all reviewed broad validation passed. Cadence remains 10/10 until the final supervisor and root actual-zero receipt authenticate reset to 0/10 at broad baseline f2e223c9e189004f0694c628535b286ed39a87fd.
See [batch evidence](docs/translation-audit/NATIVE_MEDIA_REFLECTION_TEN_FIX_BATCH.md).
