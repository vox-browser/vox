# DOM translation status

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

Verified at `b335958e`, the disjoint DOM inventory contains 43,499
implementation V LOC and 5,050 test V LOC across 101 assigned files.
`Build/audit-fixes/source-current-module-loc-b335958e.json` (SHA256 `d1312ce3780a77a3ebcab3a487d3052ebbdedb51cfdd0e60a4992134892dea81`).
Every assigned committed byte hash and physical newline is verified.
DOM/UIEvents assigned bytes remain unchanged by this slice; UIEvents remains
1,489 implementation / 474 test V LOC. Integrated totals across 78 owners /
2,217 files are 433,002 implementation / 159,798 test V LOC.
Only the assigned HTML string model and new HTML test change: +42
implementation / +114 test lines and one file. Intervening docs change no
assigned bytes, newlines or ownership. Six root/browser support/test paths
remain excluded. Later concurrent work is outside this pin; counts do not
establish runtime parity.
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
