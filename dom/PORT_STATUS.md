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
HTML DragEvent. Public JavaScript MouseEvent fields remain open. See
[related-target evidence](../docs/translation-audit/MOUSE_EVENT_RELATED_TARGET.md).

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
