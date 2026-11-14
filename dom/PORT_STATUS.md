# DOM translation status

Live HTMLCollection caches retain document identity and attribute version
alongside tree version. Existing class-filtered collections update after class
replacement/removal without requiring a tree mutation. A focused native
regression covers live membership, tree-version stability and unchanged-read
cache reuse; this also supports the native LibJS DOM integration.

Complete translation of the current `Libraries/LibWeb/DOM` inventory, audited
against every adjacent `.h` and `.idl`. Selection and UIEvents implementations
that physically share the `dom` package are counted only in their own status
files.

Mouse-family related targets now share the canonical base Event slot used by
DOM dispatch. Constructors, typed accessors, legacy initialization and clones
retain its current state; trusted hover no longer maintains a second copy.
Real shadow-slot retargeting, suppression and clear-target cleanup are covered
by four core cases and two actual Window-owner cases, including inherited
HTML DragEvent. That historical core slice used a private native owner
observer. The later owner-local MouseEvent binding now exposes the public
constructor, nineteen getters and two operations over these same records,
including canonical relatedTarget and virtual PointerEvent coordinates; it
changes no DOM/Page/dispatch algorithm. The later owner-local PointerEvent
binding supplies its constructor, thirteen native getters and two sequence
operations, with secure-owner coalesced exposure and retained native child
identity. It preserves the Mouse/UI/Event chain and these same dispatch
records. Seven focused and optimized cases pass; all 17 selected files
pass in both GC modes. Final private production verification:
ten stages pass at c9dc0da2, with two pixel-exact untrusted Pointer pages and
all 11 smoke cases (eight exact). The pinned validation source includes
the preceding CSS fix and excludes later canonical Layout work. The later
WheelEvent binding supplies its own interface. DragEvent, Element pointer
capture and hardware generation remain open. See
[related-target evidence](../docs/translation-audit/MOUSE_EVENT_RELATED_TARGET.md)
[MouseEvent evidence](../docs/translation-audit/NATIVE_MOUSE_EVENT_OWNER.md)
and [PointerEvent evidence](../docs/translation-audit/NATIVE_POINTER_EVENT_OWNER.md).

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
[WheelEvent evidence](../docs/translation-audit/NATIVE_WHEEL_EVENT_OWNER.md).

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

[DragEvent evidence](../docs/translation-audit/NATIVE_DRAG_EVENT_OWNER.md).

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
evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_STRING_OWNER.md).

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
evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_FILES_OWNER.md).

Verified at `33ba13ac`, the disjoint DOM inventory contains 43,502
implementation V LOC and 5,066 test V LOC across 102 assigned files.
`Build/audit-fixes/native-wheel-input-routing-inventory-current.json` (SHA256 `590ac39c939ef72b92c769b0c66f7fdaf09c2825e64ce6a64141dbaa39764557`).
UIEvents contains 1,489 implementation / 474 test V LOC. Integrated totals
across 78 owners / 2,238 files are 433,415 implementation / 161,056 test V
LOC.
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
The previous DataTransfer string record remains preserved at
`Build/audit-fixes/source-current-module-loc-b335958e.json` (SHA256 `d1312ce3780a77a3ebcab3a487d3052ebbdedb51cfdd0e60a4992134892dea81`).
The previous DragEvent record remains preserved at
`Build/audit-fixes/source-current-module-loc-682a7827.json` (SHA256 `1e30f605ac80b9e550e7749cc1c62330556e8491793952db1de86a8b2b54a9a3`).
The previous WheelEvent record remains preserved at
`Build/audit-fixes/source-current-module-loc-813dd838.json` (SHA256
`7d2154cc1ce69f1ea0dda25e8eda6f2df52c76abc7df473c463da13e8ca1cce5`).
The previous PointerEvent record remains preserved at
`Build/audit-fixes/source-current-module-loc-c9dc0da2.json` (SHA256
`3c5062172b28d38dda0a7e9d3d842470e270a78fd45aee5f07ba0a68633c54b5`).
The previous db342c95 record remains preserved at
`Build/audit-fixes/source-current-module-loc-db342c95.json` (SHA256
`8faec2d3db2fcb54835b7e6867dfbe177b498d5da213b5b5b145212b0b234522`). The preceding
`Build/audit-fixes/source-current-module-loc-dd0cc2d5.json` (SHA256
`568534bda24ca5538af3196bacd984810907a7fd79a60c064135af6cb4478b51`) remains preserved.
The source mapping audit and historical physical counts below retain their
earlier scope.

| Upstream `.cpp` | LOC | Primary V mapping |
|---|---:|---|
| `AbortController.cpp` | 50 | `events.v` |
| `AbortSignal.cpp` | 232 | `events.v` |
| `AbstractElement.cpp` | 236 | `shadow_mutation_misc.v` |
| `AbstractRange.cpp` | 38 | `collections_ranges.v` |
| `AccessibilityTreeNode.cpp` | 83 | `shadow_mutation_misc.v` |
| `AdoptedStyleSheets.cpp` | 52 | `../css/adopted_style_sheets.v` (typed CSS boundary) |
| `Attr.cpp` | 142 | `character_nodes.v` |
| `CDATASection.cpp` | 28 | `character_nodes.v` |
| `CharacterData.cpp` | 207 | `character_nodes.v` |
| `Comment.cpp` | 34 | `character_nodes.v` |
| `CustomEvent.cpp` | 61 | `events.v` |
| `DOMEventListener.cpp` | 25 | `events.v` |
| `DOMImplementation.cpp` | 155 | `shadow_mutation_misc.v` |
| `DOMTokenList.cpp` | 348 | `collections_ranges.v` |
| `Document.cpp` | 8,179 | `document.v` |
| `DocumentFragment.cpp` | 44 | `character_nodes.v` |
| `DocumentLoadEventDelayer.cpp` | 38 | `shadow_mutation_misc.v` |
| `DocumentLoading.cpp` | 503 | `shadow_mutation_misc.v` |
| `DocumentObserver.cpp` | 96 | `shadow_mutation_misc.v` |
| `DocumentType.cpp` | 39 | `character_nodes.v` |
| `EditingHostManager.cpp` | 220 | `shadow_mutation_misc.v` |
| `Element.cpp` | 4,796 | `element.v` |
| `ElementByIdMap.cpp` | 94 | `shadow_mutation_misc.v` |
| `ElementFactory.cpp` | 785 | `shadow_mutation_misc.v` |
| `Event.cpp` | 277 | `events.v` |
| `EventDispatcher.cpp` | 443 | `events.v` |
| `EventTarget.cpp` | 890 | `events.v` |
| `HTMLCollection.cpp` | 186 | `collections_ranges.v` |
| `IDLEventListener.cpp` | 32 | `events.v` |
| `LiveNodeList.cpp` | 96 | `collections_ranges.v` |
| `MutationObserver.cpp` | 193 | `shadow_mutation_misc.v` |
| `MutationRecord.cpp` | 55 | `shadow_mutation_misc.v` |
| `MutationType.cpp` | 16 | `shadow_mutation_misc.v` |
| `NamedNodeMap.cpp` | 360 | `collections_ranges.v` |
| `Node.cpp` | 3,449 | `node.v` |
| `NodeFilter.cpp` | 33 | `collections_ranges.v` |
| `NodeIterator.cpp` | 258 | `collections_ranges.v` |
| `NodeList.cpp` | 36 | `collections_ranges.v` |
| `NodeOperations.cpp` | 46 | `collections_ranges.v` |
| `ParentNode.cpp` | 324 | `collections_ranges.v` |
| `Position.cpp` | 34 | `collections_ranges.v` |
| `ProcessingInstruction.cpp` | 29 | `character_nodes.v` |
| `PseudoElement.cpp` | 47 | `shadow_mutation_misc.v` |
| `QualifiedName.cpp` | 90 | `character_nodes.v` |
| `Range.cpp` | 1,300 | `collections_ranges.v` |
| `ShadowRoot.cpp` | 326 | `shadow_mutation_misc.v` |
| `Slot.cpp` | 21 | `shadow_mutation_misc.v` |
| `SlotRegistry.cpp` | 74 | `shadow_mutation_misc.v` |
| `Slottable.cpp` | 274 | `shadow_mutation_misc.v` |
| `StaticNodeList.cpp` | 51 | `collections_ranges.v` |
| `StaticRange.cpp` | 47 | `collections_ranges.v` |
| `StyleElementBase.cpp` | 174 | `style_element_base.v` |
| `StyleInvalidator.cpp` | 174 | `shadow_mutation_misc.v` |
| `Text.cpp` | 177 | `character_nodes.v` |
| `TreeWalker.cpp` | 397 | `collections_ranges.v` |
| `Utils.cpp` | 41 | `shadow_mutation_misc.v` |
| `XMLDocument.cpp` | 30 | `shadow_mutation_misc.v` |

- Upstream inventory: **57 `.cpp` / 26,465 LOC**, **67 `.h` / 6,636 LOC**,
  **37 `.idl` / 1,076 LOC**; **34,177 LOC total**.
- Physical V implementation assigned only here: **34,472 LOC** across 16
  implementation files. `upstream_node_entry_points.v`,
  `upstream_inline_entry_points.v`, and `upstream_algorithm_entry_points.v`
  cover the adjacent inline headers, mixins, and file-local algorithms that do
  not have their own `.cpp` mapping row.
- Physical focused tests assigned only here: **1,277 LOC** across 8 `_test.v`
  files (72 tests). `v test dom` also runs the separately counted Selection and
  UIEvents tests, for 10 test files / 86 tests total.
- The implementation-symbol audit inventories **1,819** upstream definitions:
  **1,631** direct matches, **38** checked consolidated-owner matches, and
  **150** constructors/runtime/language-only definitions. There are **zero
  unmatched definitions**.
- Document now owns the exact associated-animation-timeline registry used by
  the Web Animations update pass. The typed CSS boundary owns constructed
  adopted-sheet callbacks, while Document and ShadowRoot retain their cached
  list handles without introducing a DOM-to-CSS import cycle.
- Author and user-agent shadow-root creation populates the owning document's
  root registry. Adoption transfers every shadow-including root to the new
  document and invalidates document-derived scope caches; finalization removes
  the root from its current document. Focused DOM and CSS tests cover nested,
  disconnected, repeated, and native-control adoption, plus inherited counter
  text changing after document counter-style mutations.
- Content-visibility relevance now includes focused and selected subtrees,
  top-layer contents, and descendant view-transition captures in addition to
  viewport proximity. The viewport paintable bridge retains the post-layout
  cache consumed by HTML's rendering update.
- Live `contenteditable` and `designMode` changes recompute inherited
  editability and invalidate retained caret targets together with read/write
  selector state, including relational and sibling dependencies. Editing-host
  transitions relayout empty text even when its editable flag stays true.
  Enabling design mode resets selection and focuses the document element only
  on the transition to `on`. Validation covers the complete 656-file LibWeb
  suite, native headless smoke, and all 11 default screenshot comparisons.
- The opaque Page boundary now supplies device-pixel scale and backing-store
  allocation callbacks, allowing Navigable resizing to remain typed without a
  DOM-to-Page module dependency.
- `Document::is_fully_active()` now asks its logical parent navigable for the
  parent document's active state, so it does not require a locally hosted
  container document.
- Navigable exposes active-document URL and origin accessors at its public
  boundary. The single-process implementation reads the local document while
  keeping cross-tree callers independent of that hosting detail.
- Navigable's opaque HTML boundary also exposes session-history readiness and
  container load-delay decisions, allowing DOM-facing containers to query the
  content navigable without assuming its HTML model is locally hosted.
- Traversable and top-level traversable lookup now walk logical Navigable
  parents. Only an actual top-level traversable reports `is_traversable`, not a
  child that merely retained a pointer to its traversable root.
- Navigable exposes an active-document identity query alongside its URL,
  origin, and fully-active queries, preserving the form-submission target check
  without requiring callers to dereference a locally hosted active document.
- The independent audit replaced EventTarget's unsafe memory-shape probing with
  an authoritative Node discriminator, tags every Node/Document allocation,
  and verifies generic EventTarget dispatch plus distinct Document identity.
- External JS realms/bindings, layout/paint/CSS, navigation/fetch and native
  accessibility services remain typed host boundaries. Tree mutation, ranges,
  collections, events, shadow DOM/slots, node/element/document algorithms and
  WebIDL-visible state are implemented in V.

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
evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_ITEMS_OWNER.md).

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
See [DataTransfer item-add evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ADD_OWNER.md).

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
See [DataTransfer string-callback evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_STRING_CALLBACK_OWNER.md).

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
See [DataTransfer entry evidence](../docs/translation-audit/NATIVE_DATA_TRANSFER_ITEM_ENTRY_OWNER.md).

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
See [media drag-handler evidence](../docs/translation-audit/NATIVE_MEDIA_DRAG_HANDLERS_OWNER.md).

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
See [media wheel-handler evidence](../docs/translation-audit/NATIVE_MEDIA_WHEEL_HANDLER_OWNER.md).

Native wheel input routing (`33ba13ac`, 2026-10-13 UTC):
Native wheel input reaches the owning Page's actual trusted DOM WheelEvent before scrolling. Cancellation blocks inner and viewport defaults; accepted DOM/style mutations force a fresh hit. Native media/VDOM listeners retain fractional fields and UA-shadow retargeting. Verification on 2026-10-13 UTC covers 23 selected cases in each GC mode (18 unchanged cases plus five corrected Page-fixture cases), signed production startup with three software GG injections, and the 11-case screenshot smoke set (8 exact / 3 retained tolerance). Original failed Page-fixture batches remain without full-batch/test-body pass credit. Generic compact HTMLElement listeners/raw handlers, zoom, nested routing, snap/compositor orchestration and physical OS-device injection remain outside this scope. See [wheel-input evidence](../docs/translation-audit/NATIVE_WHEEL_INPUT_ROUTING.md).

Native ordinary Element wheel listeners (`25c58496`, 2026-10-14 UTC):
Ordinary compact Element facades now route case-sensitive wheel add/remove listeners to their actual owning DOM EventTarget, preserving other legacy click/load delivery. Lazy facade resolution and retained created-node identities cover HTML, SVG qualified names and nullable namespaces. Receiver branding precedes one author DOMString conversion; captured native options retain callback/capture identity, once, passive and AbortSignal behavior. Listener return false is ignored; preventDefault retains its gates. Verification on 2026-10-14 UTC composes five unchanged files /16 passing cases with three corrected owner cases in each GC mode (six files /19 cases, six new functions). Original numeric-expression and intermediate conditional-pointer compiler fixture failures retain zero owner-body/full-batch credit. A bounded first-context CanvasHost sizing correction preserves the existing canvas identity and honors dimensions set before getContext. Fresh isolated signed production at the synthetic feature-plus-correction pin completes five stages and verifies six software GG injections, eleven screenshot smoke cases (eight exact /three tolerated) and eight exact SVG regressions. The original canonical preflight has no build credit; the first isolated production retains a canvas-text failure, ten smoke passes and no full-batch/SVG credit. Both failures and a later interrupted build with unavailable terminal status remain preserved without full pass credit; concurrent canonical work is preserved. No onwheel IDL/raw content compilation or full HTMLElement prototype surface is added. See [Element wheel-listener evidence](../docs/translation-audit/NATIVE_ELEMENT_WHEEL_LISTENERS.md).

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
evidence](../docs/translation-audit/NATIVE_ELEMENT_WHEEL_HANDLER.md).

Native compact Element wheel-handler scoped inventory (`d86d5ac2`, 2026-10-14 UTC): all
six owned browser/root implementation and test paths remain excluded by the existing
translation-owner rules. Each owned commit has zero assigned-file, implementation-LOC
and test-LOC delta against its own parent. This append keeps current global tables, pins
and historical ledgers intact. Counter:
`Build/audit-fixes/native-element-wheel-handler-inventory-scoped-v1.json` (SHA256
`e9b99ef0d72ed5fe2595c7a02c3bc59fa17c1851853fffd8e03b67189e8ae507`). [Element onwheel
evidence](../docs/translation-audit/NATIVE_ELEMENT_WHEEL_HANDLER.md).

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
evidence](../docs/translation-audit/NATIVE_ELEMENT_WHEEL_RAW_HANDLER.md).

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
evidence](../docs/translation-audit/NATIVE_ELEMENT_WHEEL_RAW_HANDLER.md).

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
evidence](../docs/translation-audit/NATIVE_MEDIA_WHEEL_RAW_HANDLER.md).

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
evidence](../docs/translation-audit/NATIVE_MEDIA_WHEEL_RAW_HANDLER.md).

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
source and full LibJS/HTML/interface parity remain open. See [evidence](../docs/translation-audit/NATIVE_MEDIA_LIFECYCLE_RAW_HANDLER.md).

Native compact media raw lifecycle-handler scoped inventory (`aa6f0246`,
2026-10-14 UTC): Against its actual feature parent, three owned DOM paths add
1 assigned file, 5 implementation and
93 test physical V lines. Seven browser/root support paths are
excluded under the sealed 78-owner assignment. Counter:
`Build/audit-fixes/native-media-lifecycle-raw-handler-inventory-scoped-v1.json` (SHA256 `7d14c9c050b3314215db3864ce01b7a3d9df2e704f13d8f05b8ffa5755e74f62`).
Existing global tables, pins, source mappings and historical ledgers remain
preserved. Accounting adds no behavioral parity or validation credit.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_LIFECYCLE_RAW_HANDLER.md).

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
outside this slice and differs from the pinned upstream FIXME. See [evidence](../docs/translation-audit/NATIVE_MEDIA_READINESS_RAW_HANDLER.md).

Native compact media raw readiness-handler scoped inventory (`2aab6ba2`,
2026-10-14 UTC): All eight owned browser/root support paths are excluded under
the sealed 78-owner rules. Independent feature/parent physical-LF accounting
adds zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-readiness-raw-handler-inventory-scoped-v1.json` (SHA256 `4a5ddcd1962bb29fa86e50defd18600203d011e90c3fb235276c46b3c3a07858`).
Global tables, pins, source mappings and historical ledgers remain preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
1/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_READINESS_RAW_HANDLER.md).

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
2/10 after aa6f0246. See [evidence](../docs/translation-audit/NATIVE_MEDIA_CANPLAY_RAW_HANDLER.md).

Native compact media raw can-play-handler scoped inventory (`bc80a4b7`,
2026-10-14 UTC): All eight owned browser/root support paths are excluded under
the sealed 78-owner rules. Independent feature/parent physical-LF accounting
adds zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-canplay-raw-handler-inventory-scoped-v1.json` (SHA256 `d8a72dad76f60ae0753acfec6ebf6c89280c162ff69d89d209e1cc7c827c2ce5`).
Global tables, pins, source mappings and historical ledgers remain preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
2/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_CANPLAY_RAW_HANDLER.md).

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
ten-fix cadence. Batch counter: 3/10 after aa6f0246. See [evidence](../docs/translation-audit/NATIVE_MEDIA_DATA_RAW_HANDLER.md).

Native compact media raw metadata/data-handler scoped inventory (`f9ec154f`,
2026-10-14 UTC): All seven owned browser/root support paths are excluded under
the sealed 78-owner rules. Independent feature/parent physical-LF accounting
adds zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-data-raw-handler-inventory-scoped-v1.json` (SHA256 `347a64f0ce1cf3a34bdbfd5645693321965b25bc2df0dd4d2979c6e9b46df767`).
Global tables, pins, source mappings and historical ledgers remain preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
3/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_DATA_RAW_HANDLER.md).

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
translation slice. See [evidence](../docs/translation-audit/NATIVE_MEDIA_SETTINGS_RAW_HANDLER.md).

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
See [evidence](../docs/translation-audit/NATIVE_MEDIA_SETTINGS_RAW_HANDLER.md).

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
5/10 after aa6f0246. See [evidence](../docs/translation-audit/NATIVE_MEDIA_TIMELINE_RAW_HANDLER.md).

Native compact media raw timeline-handler scoped inventory (`ef218fdf`,
2026-10-14 UTC): Five owned browser/root support paths are excluded under the
sealed 78-owner rules. Independent feature/parent physical-LF accounting adds
zero assigned DOM files, implementation lines and test lines. Counter:
`Build/audit-fixes/native-media-timeline-raw-handler-inventory-scoped-v1.json` (SHA256 `956970f14822b2169d7ce285ee59179e20f5a4bf8b26cbdcae57127900d4199c`).
Global tables, pins, source mappings and historical ledgers are preserved;
accounting adds no test or behavioral parity credit. Batch counter remains
5/10 after aa6f0246; this documentation commit is not another translation fix.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_TIMELINE_RAW_HANDLER.md).

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
See [evidence](../docs/translation-audit/NATIVE_MEDIA_SEEK_RAW_HANDLER.md).

Native compact media raw seek-handler scoped inventory (`b864154a`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds zero
assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-seek-raw-handler-inventory-scoped-v1.json` (SHA256 `61d0c1314a40b3bb5b59c183d4d7a49ba71512fbd61063dd0b3d7d773a0e9179`).
Global tables, pins, mappings and historical ledgers stay preserved; accounting
adds no behavioral or test credit. Batch remains 6/10 after aa6f0246, since
this independent documentation commit is not another translation fix.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_SEEK_RAW_HANDLER.md).

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
deferred. Batch counter: 7/10 after aa6f0246. See [evidence](../docs/translation-audit/NATIVE_MEDIA_PROGRESS_RAW_HANDLER.md).

Native compact media raw progress/suspend scoped inventory (`739e00b8`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds
zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-progress-raw-handler-inventory-scoped-v1.json` (SHA256 `07dd77510b5be5d09cafc3b80723e24291f77107a3c3faeb71141d42d9db94bb`).
Global tables, pins, mappings and historical ledgers stay preserved;
accounting adds no behavioral or test credit. Batch remains 7/10 after
aa6f0246, since this independent documentation commit is not another
translation fix. See [evidence](../docs/translation-audit/NATIVE_MEDIA_PROGRESS_RAW_HANDLER.md).

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
and broad suites remain deferred. See [evidence](../docs/translation-audit/NATIVE_MEDIA_RESET_RAW_HANDLER.md).

Native compact media raw abort/emptied scoped inventory (`50d3cd34`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds
zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-reset-raw-handler-inventory-scoped-v1.json` (SHA256 `92535a67615d288fc4c5b7001fdd34c1a3ddd7c4c9c27cd296e478209b4f9677`).
Global tables, pins, mappings and historical ledgers stay preserved;
accounting adds no behavioral or test credit. Batch remains 8/10 after
aa6f0246, since this independent documentation commit is not another
translation fix. See [evidence](../docs/translation-audit/NATIVE_MEDIA_RESET_RAW_HANDLER.md).

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
deferred. See [evidence](../docs/translation-audit/NATIVE_MEDIA_LOADSTART_RAW_HANDLER.md).

Native compact media raw loadstart scoped inventory (`b4a325cb`,
2026-10-14 UTC): Five owned browser/root paths are excluded under the sealed
78-owner rules. Feature/actual-parent byte and physical-LF accounting adds
zero assigned DOM files, implementation lines or test lines. Counter:
`Build/audit-fixes/native-media-loadstart-raw-handler-inventory-scoped-v1.json` (SHA256 `8b35cc3810a833155a918c22a226234024c7fe191a877e12e332e94ae8a9b864`).
Global tables, pins, mappings and historical ledgers stay preserved;
accounting adds no behavioral or test credit. Batch remains 9/10 after
aa6f0246, since this independent documentation commit is not another
translation fix. See [evidence](../docs/translation-audit/NATIVE_MEDIA_LOADSTART_RAW_HANDLER.md).

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
claim. See [evidence](../docs/translation-audit/NATIVE_MEDIA_COMPLETION_RAW_HANDLER.md).

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
is not another translation fix. See [evidence](../docs/translation-audit/NATIVE_MEDIA_COMPLETION_RAW_HANDLER.md).

Native compact media raw `onerror` (6ccb30aa, 2026-10-14 UTC):
HTML audio/video raw error attributes compile lazily through their actual native owner and ordered content-attribute bridge. Media callbacks receive one Event argument, including genuine ErrorEvent probes; Window's special error convention remains separate. Seven new cases cover native failure records/events, scopes/cache, replacement/removal, scripting/CSP gates, original exceptions, retained painting, captured play promise ordering and reentrant load(). Focused evidence combines seven passing v2 cases and four corrected owner cases per GC mode, totaling 11 cases across three files; the passing seven are not rerun. Failed whole-batch attempts remain retained without wholesale pass credit. Twelve old browser boundary fixtures receive static-only verification of their three-line onstalled substitution. Native MediaError JavaScript getters and backend scheduling remain open. Broad regression, production and screenshot checks are deferred; batch counter is 1/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_ERROR_RAW_HANDLER.md).

Native compact media raw `onerror` (6ccb30aa, 2026-10-14 UTC):
All 18 unique browser/root implementation and test paths remain outside the sealed assigned DOM inventory. The feature adds 766 physical V lines in its two new test files; the focused owner-fixture correction adds seven more, for 773 lines across 19 physical transaction rows and 18 unique paths. Runtime gates and boundary replacements keep their physical line counts. Assigned DOM files, implementation lines and test lines each change by zero. Global ownership tables and prior ledgers remain preserved. Counting adds no behavioral credit, and this documentation commit is not another translation fix. Batch remains 1/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_ERROR_RAW_HANDLER.md).

Native MediaError and media error getter (1801de0b, 2026-10-14 UTC):
Native HTMLMediaElement.error now returns null or a stable runtime-local wrapper for its actual MediaError record. The readonly branded code/message getters preserve exact NUL/non-BMP strings; the illegal constructor, constants and interface metadata are installed in the Window realm. Saved errors survive load/reset/replacement, foreign wrappers reject, and public close guards reject closed access and release protected roots. The retained three passing owner cases and four corrected binding cases provide seven focused new cases per GC mode, including actual failure callbacks and play/reentrant-load ordering. Controlled hooks do not establish backend scheduling or full playback parity. Broad, production and screenshot checks remain deferred; batch is 2/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_ERROR_HOST.md).

Native MediaError and media error getter (1801de0b, 2026-10-14 UTC):
The five unique native media-error implementation/test paths remain outside assigned DOM inventory. Across seven physical transaction rows (feature plus test correction), this excluded support slice adds 406 physical V test lines and 137 physical V implementation lines; assigned DOM files, implementation lines and test lines change by zero. Previous inventory and evidence records remain preserved. This documentation update adds no behavior credit and does not increment the fix count. Batch remains 2/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_ERROR_HOST.md).

Native media played and seekable getters (c275ad4e, 2026-10-14 UTC):
Native audio/video played and seekable getters now return fresh static TimeRanges wrappers for the actual V model snapshots. Saved ranges survive pause, resource replacement and load/reset; native receiver checks precede replay, original replay exceptions survive, and old getter indexes remain intact. The retained three passing binding cases and two corrected owner cases provide five focused new cases per GC mode, including parsed/created media, actual load/play/pause callbacks, scope lookup and retained painting. Existing V pause-time played recording and response-populated seekability are preserved; continuous playback, normalization and unbounded/MSE generation remain outside this binding slice. Broad, production and screenshot checks are deferred; batch is 3/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_TIMELINE_RANGES_HOST.md).

Native media played and seekable getters (c275ad4e, 2026-10-14 UTC):
The three native timeline-range implementation/test paths remain outside assigned DOM inventory. Across four physical transaction rows (three feature paths plus one fixture correction), they add 380 physical V test lines and four physical V implementation lines; assigned DOM files, implementation lines and test lines change by zero. Previous ownership tables, inventory and evidence remain preserved. This documentation update adds no behavioral credit or fix count. Batch remains 3/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_TIMELINE_RANGES_HOST.md).

Native media canPlayType and completed SVG-video namespace guard (89c63468 / a1a5fcf8 / 4c78eaa2, 2026-10-14 UTC):
Native canPlayType() now exposes the actual V media classifier through branded one-argument DOMString conversion followed by compact replay. Original exceptions and exact primitive results survive; existing MIME/codecs limitations remain. Owner validation also exposed an unsafe SVG video cast, fixed separately by HTML-namespace checks in both page video installers, document bootstrap, canvas frame selection, and retained layout conversion. Retained binding cases and fresh owner/namespace cases cover seven distinct cases per GC mode. The native operation is fix4 and the namespace guard is fix5; broad suites, production builds and screenshots remain deferred at 5/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_CAN_PLAY_TYPE_HOST.md).

Native media canPlayType and completed SVG-video namespace guard (89c63468 / a1a5fcf8 / 4c78eaa2, 2026-10-14 UTC):
The native canPlayType feature changes three excluded browser/root paths, adding 325 physical V test lines and 21 implementation lines. The namespace guard and its follow-up add 153 test lines and four implementation lines. Across seven transaction rows and six unique paths: 478 test lines and 25 implementation lines; assigned DOM files, implementation lines and test lines each change by zero. Previous ownership tables and records remain preserved. Documentation and inventory add no behavioral credit or fix count. Batch remains 5/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_CAN_PLAY_TYPE_HOST.md).

Native media defaultMuted (af34b569, 2026-10-14 UTC):
Native defaultMuted now reflects the actual HTML audio/video muted content attribute through branded native boolean accessors. Setters check the receiver, apply ToBoolean, replay pending DOM changes, then mutate and synchronize the attribute. A captured media-only WeakMap synchronizes the compact facade without invoking author attribute methods, so later dirty snapshots preserve the write. Runtime muted and playback/fetch state remain independent. Five focused cases cover metadata, receiver ordering, ToBoolean, normalization, replay exceptions, cleanup, parsed/created owners, poisoned intrinsics and retained painting. Synchronous customized-built-in CEReactions delivery remains open. The isolated committed source earns test credit; concurrent rendering and full HTMLElement behavior remain outside this slice. Broad suites, production builds and screenshots remain deferred at 6/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_DEFAULT_MUTED_HOST.md).

Native media defaultMuted (af34b569, 2026-10-14 UTC):
The defaultMuted slice changes six excluded browser/root paths: the host record, native binding, private reflection bootstrap, two focused test files and two media bootstrap gates in main.v. Feature-parent physical-LF accounting adds 337 V test lines and 94 implementation lines while assigned DOM files, implementation lines and test lines each change by zero. Existing ownership tables and prior ledgers remain preserved. This documentation update adds no behavioral credit or fix count; cadence remains 6/10 after 05655652.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_DEFAULT_MUTED_HOST.md).

Native media loop (2e06dfd2, 2026-10-14 UTC):
HTML audio/video facades expose native loop getter/setter functions. Reads use the actual loop content attribute; writes apply WebIDL boolean conversion, normalize presence to an empty value or remove the attribute, and synchronize captured facade state before a later dirty replay. Native branding precedes replay, author conversion hooks stay untouched, and replay exceptions retain their JavaScript identity. The V model reads its live DOM owner, retains an ownerless fallback, and captures loop presence at the actual playback endpoint. Active looping seeks to zero without pause/ended; paused looping does not seek, and later mutations preserve the captured non-loop endpoint decision. Non-loop completion dispatches timeupdate, rechecks live position, direction and paused state before conditionally pausing, then fires ended. Seven distinct focused cases pass per GC mode. The original default-GC run exited 1 and receives no whole-run pass credit; its five passing binding/DOM cases are retained and combined with the corrected two-case owner test, whose actual test exit is zero. Its single-row output initially made the evidence wrapper exit 1; a fresh parser authenticates the successful output without rerunning it. The first no-GC run passes all seven cases in three files with test and supervisor exits zero. Synchronous customized-built-in CEReactions timing and full media backend behavior remain open. This is fix 7/10; the fixture repair does not advance the counter, and broad suites remain deferred.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_LOOP_HOST.md).

Native media loop (2e06dfd2, 2026-10-14 UTC):
The five-path feature adds 53 implementation LF and 503 focused-test LF: three native binding cases, two browser-owner cases, and two DOM-owner cases. The separate one-path owner fixture repair adds 5 test LF, making 508 test LF across six physical transaction rows and five unique support paths. All paths remain outside assigned DOM ownership, so the assigned DOM file, implementation-line, and test-line deltas are zero. Seven distinct focused cases pass per GC mode: default combines five retained cases with the corrected owner test’s two cases, and the first no-GC run passes all seven cases in three files. Original failed batch and single-row evidence-parser failure remain retained without whole-wrapper pass credit; successful test output is authenticated without repeating passing files. Prior preservation covers 236,808 authenticated records without rehashing historical files; the broad-suite cadence remains 7/10 after the fixture repair.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_LOOP_HOST.md).

Native media autoplay (446dcc55, 2026-10-14 UTC):
HTML audio/video facades expose native autoplay accessors that brand the receiver, apply WebIDL boolean conversion without author conversion hooks, replay pending DOM changes, and reflect actual attribute presence. The setter publishes protected facade state before model mutation can fetch and reenter JavaScript, preserving an inner autoplay=false write. The model reads live DOM presence, retains an ownerless fallback, preserves parsed nonempty values, and notifies only existing HTML media owners for unnamespaced autoplay mutations. Adoption installs the destination document hook, so current origin policy and sandbox flags govern deferred selection. An allowed change resumes automatic preload="none" fetching once; controlled responses exercise playback and native events. Seven focused cases in three files passed in both GC modes, with actual test and supervisor exits zero and identical before/after source snapshots. Controls lifecycle, native enumerated preload, full media backend behavior and synchronous customized-built-in CEReactions timing remain open. Cadence is 8/10; broad suites, production builds and screenshot suites remain deferred.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_AUTOPLAY_HOST.md).

Native media autoplay (446dcc55, 2026-10-14 UTC):
The eight-path feature adds 87 implementation LF and 599 test LF across three new test files: binding 173, browser owner 222 and HTML owner 204. Under authenticated sealed 78-owner rules, DOM's three existing core paths add 12 implementation LF (6 state-hook, 1 document field, 5 element notification), zero test LF and zero files. HTML adds 35 implementation LF, 204 test LF and one file. Excluded native/browser/root support adds 40 implementation LF, 395 test LF and two files. These are scoped feature-parent deltas; global ownership tables and legacy totals retain their original pins, with no full recount. Seven focused cases passed in each GC mode; source hashes, modes, index, native SDK and toolchain remained unchanged. Prior preservation covers 255,624 authenticated records without a historical union walk, and cadence remains 8/10.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_AUTOPLAY_HOST.md).

Native media preload (169c907e, 2026-10-15 UTC):
HTML audio/video facades expose native preload accessors. The getter returns canonical none, metadata or auto from live DOM content, with metadata for absent, empty and invalid values. Setters brand the receiver, convert once to DOMString with NUL/lone-surrogate preservation, replay pending changes, publish the raw string through protected facade synchronization, then mutate the actual attribute. Raw strings and canonical getter values remain distinct; an inner preload="none" written during fetch reentry survives. The existing DOM resource notification now covers autoplay and preload, retaining namespace, lazy-owner and adoption boundaries. Leaving a deferred none state resumes automatic fetching once while playback remains subject to policy and sandbox; explicit load and permitted autoplay retain their existing overrides. Seven focused cases in three files passed in both GC modes, with actual test and supervisor exits zero and unchanged before/after source snapshots. Metadata-only fetching, controls lifecycle, full backend/interface parity and synchronous customized-built-in CEReactions timing remain open. Broad suites, production builds and screenshots remain deferred at 9/10.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_PRELOAD_HOST.md).

Native media preload (169c907e, 2026-10-15 UTC):
The nine-path feature adds 60 implementation LF and 574 test LF across three new files: binding 161, browser owner 190 and HTML owner 223. Six implementation paths change bytes: native binding +37 LF, private bootstrap +1, HTML model +22, and three DOM core paths with zero net LF. Sealed 78-owner accounting therefore records DOM +0 implementation LF, +0 test LF and +0 files; HTML +22 implementation LF, +223 test LF and +1 file; excluded browser/root support +38 implementation LF, +351 test LF and +2 files. These are scoped feature-parent deltas, with legacy global tables and pins preserved and no full recount. Seven focused cases passed in each GC mode, with all test and supervisor exits zero. Prior preservation inherits 265,099 authenticated records without a historical union walk; cadence is 9/10.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_PRELOAD_HOST.md).

Native media crossOrigin (f2e223c9, 2026-10-15 UTC):
HTML audio/video facades expose native crossOrigin accessors with nullable DOMString reflection and canonical anonymous/use-credentials getters. Null, undefined and omitted setter input remove the content attribute; other inputs receive one UTF16-preserving conversion before replay, followed by captured raw-string synchronization before the DOM/model write. Branding precedes conversion and original exceptions remain intact. The typed V query reads the live DOM owner after direct mutations and adoption without restarting media or promoting deferred resource selection. Both original three-file runs exited 1: only the native binding file/three cases passed in each GC mode, while both owner files failed compilation. A separate two-path fixture correction preserves every input and assertion; the two owner files/four cases now pass in each GC mode with actual test and supervisor exits zero. Every tracked source hash except those two fixture paths, and every tracked mode, was verified equal to the original source. Combined focused credit is three files/seven cases per mode: three retained binding cases plus four fresh owner cases. This remains fix 10/10, awaiting the broad batch; fixture repair does not increment the cadence. Full media transport CORS enforcement, controls lifecycle parity and synchronous customized-built-in CEReactions timing remain open.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_CROSS_ORIGIN_HOST.md).

Native media crossOrigin (f2e223c9, 2026-10-15 UTC):
The original five-path feature adds 65 implementation LF and 567 test LF. Its separate two-path fixture correction adds four test LF, yielding 571 total test LF: native binding 161 LF/3 cases, browser owner 217 LF/2 cases, and HTML owner 193 LF/2 cases. Across both transactions there are seven physical rows and five unique paths. Assigned HTML gains 19 implementation LF, 193 test LF and one test file. Excluded browser/root support gains 46 implementation LF, 378 test LF and two test files. Assigned DOM file, implementation-line and test-line deltas are zero; historical owner tables retain their pins. Both original whole selections failed and receive no wholesale pass credit. Only binding three-case credit per GC mode is carried; fresh two-owner/four-case validation passes in both GC modes with actual test and supervisor exits zero. The later ten-fix checkpoint will carry the verified focused three-file/seven-case composite without rerunning it and select only the remaining 63 native files/189 cases for a 66-file/196-case union per mode. All broad claims and the cadence reset remain pending.
See [evidence](../docs/translation-audit/NATIVE_MEDIA_CROSS_ORIGIN_HOST.md).

Native media reflection ten-fix checkpoint (2026-10-15 UTC):
All selected validation for the native media reflection ten-fix checkpoint passed. Each GC mode has a disjoint 66-file/196-case native union: 63 newly checked files/189 cases plus the verified three-file/seven-case focused composite. Both GC modes passed all 234 LibJS files/778 test functions, and the unchanged official AST driver matched all 100 upstream cases exactly. Production carries the successful signed Boehm build, signing and startup from the retained failed original attempt; the production-only recovery passed two exact comparisons of retained page-load captures, eleven default smoke cases (eight exact, three under existing allowances), and eight exact SVG guards on the same signed executable. No browser rebuild, retained-pair recapture or successful focused-check rerun occurred. The authenticated evidence seal retains cadence at 10/10; only the final supervisor and root actual-zero receipt can reset it to 0/10 at tested fixture epoch f2e223c9e189004f0694c628535b286ed39a87fd. Browser execution still uses JavaScriptCore; full LibJS and native media backend/interface parity remain open.
Native reflection ten-fix checkpoint: all reviewed broad validation passed. Cadence remains 10/10 until the final supervisor and root actual-zero receipt authenticate reset to 0/10 at broad baseline f2e223c9e189004f0694c628535b286ed39a87fd.
See [batch evidence](../docs/translation-audit/NATIVE_MEDIA_REFLECTION_TEN_FIX_BATCH.md).
