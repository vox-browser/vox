# Repository instructions

## Commits

- Commit each completed translation feature separately with a focused commit
  message. Do not combine unrelated translation slices in one commit.
- Include the feature's focused tests in the same commit as its implementation.
- Keep documentation-only and tooling-only changes in separate commits when
  they are independently reviewable.

## LibWeb V translation

- This repository (`~/code/vox2`) is the canonical LibWeb V translation workspace.
- Use `~/code/3rd/ladybird/Libraries/LibWeb` as the upstream source reference.
- Keep all translated V implementation code, tests, generated translation assets,
  and translation-specific documentation in this repository.
- Do not place V translation files in the Ladybird upstream checkout.
- Preserve working translated behavior when replacing generated placeholders;
  add focused tests for each completed translation slice.

## LibJS translation

- Keep refreshed LibJS V code and tests in `libjs/` in this repository. Use
  `~/code/3rd/ladybird/Libraries/LibJS` as the upstream reference and
  `libjs/PORT_STATUS.md` for the completed slices, deviations, and remaining
  runtime work. The VM record (`vm.v` and the runtime records it depends on)
  translates `Runtime/VM.{h,cpp}` directly; keep new runtime slices in the same
  package with focused tests.
- Run `v -old-compiler -enable-globals test libjs`; exercise heap ownership with
  the same command plus `-gc none`.
- Compare the current upstream AST fixtures with
  `v -old-compiler -enable-globals run tools/libjs_ast_corpus.v --all`.
  Keep these comparisons exact; the driver has no case overrides.
- The browser still uses JavaScriptCore. The parser's 32-call recursion limit,
  absent regex backend, and the pending bytecode generation, interpreter loop,
  builtin objects, and module linking must not be described as full LibJS
  parity.

## Build and run Ladybird V

- Build the native macOS bundle from this repository with:

  ```sh
  cd ~/code/vox2
  ./build_ladybird.sh
  ```

- `build_ladybird.sh` uses `V_BIN` when set, then `v` from `PATH`, and finally
  `~/code/v/v`. It writes `Build/v/Ladybird.app` and ad-hoc signs the bundle.
- Launch the browser with `open Build/v/Ladybird.app`, or pass a URL, an HTML
  file, or literal HTML directly to its executable:

  ```sh
  Build/v/Ladybird.app/Contents/MacOS/Ladybird https://example.com
  Build/v/Ladybird.app/Contents/MacOS/Ladybird ./page.html
  ```

- Run the non-windowed engine/JavaScript startup check with:

  ```sh
  Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
  ```

- Run all translation tests from this repository with `v test .`. When `v` is
  not on `PATH`, use `~/code/v/v test .`.
- The V bundle is independent of upstream Ladybird at
  `~/code/3rd/ladybird/Build/release/bin/Ladybird.app`.

## Screenshot conformance workflow

- Capture only the rendered document viewport from the native V browser (excluding
  its toolbar, status bar, and macOS title bar) with:

  ```sh
  ./capture_screenshot.sh SOURCE OUTPUT.png [WIDTH [HEIGHT]]
  ```

  The default viewport is 800x600. The script rebuilds a stale bundle, captures
  the native Cocoa content view without Screen Recording permission, accounts
  for Retina scale, crops the browser chrome, and writes a logical-pixel PNG. Set
  `SCREENSHOT_SETTLE_SECONDS` when a page needs longer than the default two
  seconds to settle. Normal-height captures retry one failed browser launch
  before reporting an error, covering the intermittent AppKit/Metal window-
  initialization trap without hiding deterministic failures.

- Compare canonical upstream screenshot inputs pixel by pixel with:

  ```sh
  ./compare_screenshots.sh
  ./compare_screenshots.sh inline-node ordered-list
  ```

  With no arguments the current smoke set is `inline-node`, `ordered-list`,
  `text-decorations`, `line-clamp-properties`, `canvas-text`, the three
  live-selection reftests (`selection-focus-between-text-controls`,
  `selection-insert-between-boundaries`, and `selection-moves-between-subtrees`),
  `empty-caret-with-placeholder`, `caret-after-first-character`, and
  `default-ignorable-code-points-not-painted`.
  A case name first resolves against upstream
  `Tests/LibWeb/Screenshot/{input,expected}`, then against `Tests/LibWeb/Ref/input`.
  For a reftest, the command follows its
  `<link rel="match">` or `<link rel="mismatch">` and captures both pages through
  the V browser. An input HTML path is also accepted. The command prints differing-pixel,
  maximum-channel-error, MAE, and RMSE metrics and writes `*.actual.png` plus an
  amplified `*.diff.png` heatmap under `Build/comparisons/`.
- Keep `svg-image-source-switch-same-size` pixel-exact when changing the compact
  script bridge or image invalidation. Script-visible `img.src` replacements
  must reach the live DOM, refresh the image model, and invalidate both layout
  and retained paint input even when the replacement has identical dimensions.
- Keep the SVG paint-server mutation reftests pixel-exact when changing the
  compact script bridge. Preserve tree-order identity when IDs collide, SVG
  attribute case and namespaces, script-created SVG children, `moveBefore()`
  ordering, retained animation end values, and paint-resource invalidation when
  an ID enters or leaves the document lookup map.
- Override the defaults with `LADYBIRD_SOURCE_DIR`, `V_BIN`, and
  `SCREENSHOT_OUTPUT_DIR`. The capture workflow is macOS-specific because it uses
  the Cocoa view snapshot helper and `sips`; the PNG diff tool itself is portable and
  can be run directly with `v run tools/pixel_diff.v EXPECTED ACTUAL DIFF`.

## Latest translated behavior

- Cross-document navigation carries same-origin unload timestamps into the
  replacement document, but suppresses them after cross-origin redirects.
  Navigation-created documents also preserve their navigation-start record and
  timestamp the first `loading` readiness state for legacy timing attributes.
  Browser navigation parses with the final document URL already installed, so
  parser-created `<base>` elements freeze against that URL and all preloaded,
  styled, scripted, image, and video subresources use the resulting base URL.
  Hyperlink downloads fire the cancellable download-request navigate event,
  respect the sandboxed-downloads flag, fetch with the download initiator and
  URL credentials, select and sanitize the upstream suggested filename, and
  stream the response body through the owning page's download client.
  Navigation responses with an attachment disposition use the same filename
  and streaming path without committing a history entry; both source and
  target download sandboxing are enforced, and request-server responses retain
  their navigation identity for direct PageClient handoff.
- Media controls keep progress inside the positioned timeline-track wrapper,
  derive their timeline from the final seekable range, react to
  audio-track list events, use a semantic fullscreen button with the `F`
  shortcut, and coalesce scrub seeks with the upstream timeout. SourceBuffer
  coded-frame appends now enter the throttled media `progress` event path.
  Video controls fill the 300px by 150px default replaced size when no natural
  video dimensions exist; the replaced shadow wrapper receives both definite
  percentage bases from that resolved object size.
  Automatic resource selection still defers paused `preload="none"` media, but
  an explicit `load()` promotes that selection to fetch immediately; the
  promotion survives inactive-document adoption and resets for later automatic
  selections.
- File and color inputs request their picker from the `Page` attached to their
  own document, preserving nested-page ownership instead of routing through a
  top-level or per-model fallback. Range inputs retain a `20ch` by `16px` auto
  content size through their dedicated layout box while remaining ordinary
  non-replaced grid items that stretch across an available track. Unsupported
  and domain-specific input states fall back to the text-input layout box and
  shadow content instead of collapsing to zero width.
- Live input `type` changes preserve the old control model through the
  attribute-change hook and rebuild the layout tree when the state selects a
  different concrete box, including text-to-image transitions. Default text
  input padding belongs to the host control, remains author-overridable, and is
  no longer duplicated by the internal flex box or intrinsic line-height size.
  Visible placeholders overlay the full-width editor instead of collapsing it;
  number inputs group both layers in a dedicated flex item ahead of the steppers,
  and textareas use the same full-width flex overlay in every writing mode.
  Live UA-shadow placeholder styles resolve logical inline properties through
  the inherited writing mode and direction, so script-added placeholders keep
  the same full-width overlay as parser-created controls. Number-input stepper
  icons retain their `d` presentation attribute as computed SVG path geometry.
  Placeholder layers are excluded from hit testing and text selection. Input
  editors preserve interior and trailing whitespace verbatim. Single-line
  controls clamp undersized line heights to normal font metrics, and cursor
  scrolling leaves their logical block-axis position stable. Their intrinsic
  auto height likewise uses the selected face's resolved normal line-height,
  including at fractional and very small font sizes. Native input
  min/max-height clamps provide a definite basis to the internal flex editor
  when the inline size is explicit, keeping its text and placeholder centered
  in the constrained control. With both axes automatic, the upstream tentative
  block-size rerun preserves the input's intrinsic line height after a min/max
  violation. Select fallback buttons clone the selected option label after
  selectedness changes and position their chevron out of flow, so the label is
  the sole flex item and supplies the inline baseline; `appearance:none`
  removes both the chevron and its reserved inline-end space.
- Reload reconstructs child session history, nested windows inherit their
  top-level creation URL and origin, exhausted navigation bodies are released,
  and removing the body no longer leaves an otherwise loaded document
  render-blocked. Child navigables without an active document continue to
  delay their container's load event until a replacement document is active;
  child-document fully-active state follows the logical parent navigable even
  when its container document is hosted elsewhere. Navigables expose the
  active document URL and origin through the same remote-safe boundary used by
  cross-tree algorithms instead of requiring callers to dereference Document.
  X-Frame-Options and CSP `frame-ancestors` walk those logical parent
  navigables, including ancestors whose container document is not local.
  Containers likewise ask their content navigable for session-history
  readiness and load-event delay state instead of assuming local child state.
  A locally hosted child preserves a logical parent hosted elsewhere, while
  page-local debug state is inherited only from an available local parent. Its
  load-delay flag remains navigable-owned even when no local container document
  exists, and local containers are rescheduled after either flag transition.
  Traversable and top-level traversable lookup walk that logical parent chain;
  a child is not misclassified merely because it caches its traversable root.
  Active-document identity can also be queried through the Navigable boundary,
  so form-target checks do not require a locally accessible Document pointer.
- Flex layout completes clamped line measurement and forwards a button's
  definite percentage-height basis through its anonymous flex/content wrappers,
  including aspect-ratio sizing and post-flexing content heights. Non-flex/grid
  buttons derive that basis from their clamped used content height, so border-box
  minimums center their contents without making content-sized intrinsic heights
  spuriously definite. Empty anonymous button content and whitespace-only flex
  runs do not become flex items or acquire synthetic used geometry. Inline-grid
  whitespace runs likewise remain unlaid-out instead of gaining zero-sized
  paintables. It also honors
  flexible-grid intrinsic minimums and applies `min-height` while stretching
  lines. Once an auto-height row flex container has resolved its line cross
  sizes, it relays each item's used height as a definite basis to percentage-
  sized descendants, including items whose own percentage height was initially
  indefinite. Before that resolution, percentage cross-axis minimums remain
  indefinite and cannot transfer a provisional size through an item's aspect
  ratio into its flex base. Intrinsic column-flex measurement likewise keeps
  its original percentage basis across both passes and clears any numeric
  width retained after that basis becomes indefinite, so a stretched item's
  cyclic percentage minimum cannot inflate the width it helped determine or
  reuse geometry from an earlier normal-layout pass.
  Flex and grid item baselines ignore
  `vertical-align`, which has no effect on those item roles. Baseline consumers
  distinguish first and last
  sets: flex alignment derives the first set from content even for scroll
  containers, while inline block layout retains the legacy last-set bottom-edge
  fallback. A line box exports the final position of its first unshifted text
  fragment as its baseline, with its alignment baseline retained only as the
  fallback; reversed writing modes include their final block-axis offset. Flex
  intrinsic measurement resolves an inline flex container's automatic block
  size, including min/max constraints, before item and line alignment, and
  retains content-derived baselines before discarding measurement line boxes.
  Flex and grid containers also keep their content
  margins from collapsing through them, including at zero used height. A
  partially intrinsic outer SVG derives its missing max-content width from its
  intrinsic height and viewBox ratio,
  including when it is centered inside a column flex item. Media-control
  contents retain the upstream left alignment. Block formatting contexts keep
  unified float-intrusion bands, and inline lines use the maximum left and
  right intrusion across their complete block-axis span. Size and inline-size query
  containers establish independent formatting contexts, but
  an ordinary block with an automatic width still fills its containing block;
  containment's zero intrinsic size is not treated as a replaced-element width.
  Auto-width replaced elements transfer a definite height through their
  preferred aspect ratio before contributing their natural intrinsic width. A
  ratio-only replaced element with a cyclic percentage width contributes zero
  to min-content sizing and the 300px replaced fallback to max-content sizing.
  Its max-content size also transfers definite preferred, minimum, and maximum
  constraints through the preferred ratio, including calculated, cyclic, and
  border-box values; grid layout reapplies percentage block constraints against
  the completed grid area.
  Resolved `min-content`, `max-content`, and `fit-content` block sizes remain
  indefinite percentage bases for descendants, including fixed-position boxes
  whose used height is clamped or whose opposing insets are both specified.
  During grid track sizing, a non-replaced item's percentage block size is a
  cyclic auto contribution; it resolves against the completed grid area only
  after intrinsic row sizing and free-space distribution. Grid min/max-content
  probes likewise measure inline content without baking in the item's own
  min/max-width; cyclic percentage minimums use the still-indefinite grid area
  during track sizing and resolve against the completed area during item layout.
  A definite grid-item minimum resolves its border, padding, and margin edges
  before its first track-sizing contribution, so shrink-to-fit grids include
  the item's complete outer minimum even when no intrinsic probe ran first.
- Table column and column-group boxes retain their used grid geometry for
  painting and layout-tree inspection, including spanning columns, empty groups,
  border spacing, and RTL placement. Percentage column widths resolve against
  the assignable table width instead of the table's containing block. Table
  fixup also clears stale inline-child state from generated table roots and
  rows while preserving it on the generated cell that owns the inline run.
  Table cells derive their baseline from their first in-flow line or row, only
  baseline-aligned cells establish a row baseline, and inline tables export the
  first visible row through their wrapper while excluding captions. Rows grow
  to the shared baseline plus the largest non-spanning cell descent, keeping
  baseline-aligned descendants inside the row's used block size. Cells whose
  spanned columns are all collapsed remain laid out but are omitted with their
  complete subtree from retained painting and hit testing; a span that reaches
  any visible column remains displayed. Captions flow around the table grid in
  the wrapper formatting context: their outer sizes contribute to wrapper
  height, bottom captions follow the grid, and a stretched wrapper gives the
  grid the definite block space left after both caption groups. Caption
  preferred widths are resolved from computed style: `fit-content` contributes
  min-content, `max-content` contributes max-content, and border-box lengths
  exclude their border and padding before outer edges are added. In grid
  layout, the anonymous table wrapper owns placement, ordering, margins, and
  self-alignment while its width follows the principal table's intrinsic,
  min/max, box-sizing, percentage, and stretch constraints against the grid
  area. Table sizing distinguishes the keyword `fit-content`, whose limit is
  the available inline size, from an explicit zero `fit-content(0)` or
  `fit-content(0%)`, whose limit remains zero; intrinsic min/max constraints
  also leave no stale used margin on the principal table. A block
  container's own
  `vertical-align` positions that container only; direct text uses the
  anonymous inline box's initial baseline alignment, including inside cells.
  Collapsed borders split on whole CSS pixels at every grid line: cells own the
  inner shares, the table owns the outer shares, and painting snaps the derived
  border edges independently in device space. A collapsed table's used borders
  are the winning widths along the four outer grid edges; layout rebases its
  content origin after conflict resolution so those outer shares remain inside
  the table wrapper. Intrinsic min/max probes replay those winners into each
  throwaway layout state, include the table-owned inline shares in wrapper
  width, and shift the wrapper's exported baselines with the final block-axis
  rebase. Border-box percentage sizes subtract the split shares rather than the
  unsplit winning widths. Anonymous cells created by missing-cell fixup keep zero
  used borders, leaving each collapsed grid-line border wholly owned by real
  boxes on its sides. A cell's specified height is a content-box minimum in
  standards mode and grows its row by padding and borders; explicit
  `border-box` and the table-cell quirks-mode rule retain border-box sizing.
  The table itself has zero used padding in the collapsed-border model, so its
  grid and row backgrounds begin immediately inside the resolved outer border.
  Table rows use visual group order: the first header group is laid out first,
  the first footer group last, and additional header/footer groups retain tree
  order as ordinary row groups. Each row-group box starts at its own first row
  and spans through its own last row, even when loose rows occur between
  groups; collapsed rows do not synthesize spacing inside the group. Fixed
  layout ignores padding and borders on auto-width cells when measuring
  columns, adds content-box offsets to first-row percentage widths, and ignores
  later-row cells when deriving column measures. When those measures make a
  column narrower than its cell offsets, the cell reduces end/start padding
  and then borders so its painted border box stays within its columns. Columns
  and column groups with `visibility: collapse` retain their sizing influence,
  then lose their used width and adjacent spacing; cells and track boxes use
  only the visible columns they span while the table wrapper keeps its width.
- Parsed programs are reused for bytecode cache generation, nested idle
  callback periods are paced, Window named-property membership avoids full ID
  enumeration, and SVG presentation attributes retain their case-sensitive
  namespace behavior. SVG image documents without an explicit opt-in honor the
  embedding element's preferred color scheme.
- SVG `feTurbulence` and `fractalNoise` replay through the same Skia Perlin
  shader as upstream, including scaled and rounded `stitchTiles` dimensions.
  The native bridge rasterizes only the retained filter target, so browser
  chrome offsets cannot shift the deterministic noise field; both canonical
  turbulence screenshots remain pixel-exact.
- Same-process structured clones of fixed and growable `SharedArrayBuffer`
  objects alias one flattened backing store, including buffers reached through
  typed-array views. Serialization records retain a self-contained byte copy
  for process boundaries, while storage serialization and the default
  cross-origin-isolation gate continue to reject shared buffers.
- Incremental HTML parsing retains encoding-sensitive bytes while scripts are
  deferred or the tokenizer is paused on a parser-blocking script. Late meta
  charset declarations can replace the streaming decoder before those bytes
  are consumed, and retained input is drained before implied EOF.
- `rel=modulepreload` now selects the upstream script-like, style, JSON, and
  text destinations; preserves nonce, integrity, CORS credentials, referrer
  policy, and fetch priority; and populates reusable module-map entries while
  fetching JavaScript descendants. Failed preloads remain retryable, media
  mismatches stay silent, and speculative parser requests retain the fetch
  options without populating the module map ahead of later CSP metadata.
- Module maps use the `javascript-or-wasm` type key and retain every completion
  callback while a fetch is in progress. Completion installs a successful
  script or removes a failed entry before notifying all waiters, so aborted
  implementation fetch hooks can be retried; text modules expose their source
  through their sole `default` export.
- `Worker.terminate()` discards queued and already-scheduled message deliveries,
  clears the translated in-process worker event loop, closes the outside port,
  releases its startup keepalive, and asks the owning `PageClient` to shut down
  the worker agent without leaving an accumulated process record.
- Meta `color-scheme` discovery retains the declaration's `only` modifier
  alongside its supported scheme list and invalidates the style environment
  when either part changes. Parser-created metadata is refreshed when full
  document tree construction completes, so initial declarations affect the
  first force-dark decision as well as later DOM mutations.
- System clipboard entries distinguish raw bytes from user-selected files.
  Clipboard API reads hide file-backed entries, while explicit paste converts
  raw PNG data and selected image files into file items and inserts a sanitized
  data-URL image into rich editable hosts.
- SVG and MathML follow CSS Display unboxing rules: `display: contents`
  computes to `none` for CSS-box SVG roots, non-hoisting SVG elements, and all
  MathML elements. Nested SVG containers and text children keep `contents`,
  with `foreignObject` resetting the outermost-SVG boundary. The `:root`
  pseudo-class matches the document element in HTML, SVG, and XML documents,
  so standalone SVG roots receive the UA view-transition stacking context.
  SVG animation elements inherit the base element's no-layout-node behavior;
  inserted text remains in the DOM without turning `<set>` or `<animate>` into
  an inline layout box. Script-created SVG elements retain their namespace and
  case-sensitive local names, and descendants of `foreignObject` leave SVG
  rendering context until a nested SVG root establishes it again. SVG viewport
  children bypass HTML anonymous-block fixup regardless of the root's outer
  display, keeping text and `foreignObject` siblings directly attached. Their
  inline-child flag follows ordinary insertion semantics: an in-flow block
  `foreignObject` clears it for a block SVG viewport, but interrupts rather
  than clears the inline formatting context of an inline SVG viewport.
  Mask, clip, and pattern subtrees attached beneath translated SVG references
  retain the current SVG viewport as their coordinate containing block, so the
  resource begins at its own user-space origin rather than inheriting the
  reference's offset. A `foreignObject` receives its resolved SVG geometry as
  definite layout space without turning that geometry into a definite CSS
  percentage-height basis for its HTML descendants. The compact script bridge
  replays `Element.remove()`, allowing resource-removal invalidation to rebuild
  referencers and discard attached mask, clip, or pattern layout subtrees.
- Non-collapsible text whose flat-tree style parent has `display: contents`
  keeps an anonymous inline style wrapper while the parent itself is unboxed,
  including slotted text that then participates in flex-item blockification.
- Cross-parent `moveBefore()` operations discard cached inherited language for
  the complete shadow-including moved subtree. Subsequent `:lang()` and `:dir()`
  matching and inherited computed styles therefore reflect the new parent;
  same-parent reordering keeps the cache intact.
- Removing or moving a wrapper out of a shadow tree unregisters every
  descendant slot and reruns assignment for those exact slots. Their assigned
  node lists and each light-tree child's `assignedSlot` are cleared even when
  the removed subtree root is not itself a slot.
- Author and user-agent shadow roots register with their owning document at
  creation and move that registration when their host is adopted, including
  nested and disconnected roots. Adoption drops document-derived style caches,
  and later counter-style changes in the new document refresh inherited
  counter text in those roots without retaining the old document's definitions.
- Untitled alternate style sheets remain disabled during direct CSSOM
  `StyleSheetList` insertion. Only nonempty named alternates can join the
  selected preferred set; persistent untitled sheets remain enabled.
- CSS rule lists propagate owner-rule and parent-stylesheet changes through
  wrappers that already exist, including nested grouping lists. Dynamic and
  replacement `@font-face` rules synchronize their CSS-connected `FontFace`
  objects recursively, follow sheet and nested-media effectiveness, disconnect
  removed rule subtrees, and preserve stylesheet order ahead of manually added
  faces. A nested `MediaList` mutation invalidates and resynchronizes the sheet
  reached through its owning rule.
- Embedded CSS, quirks-mode, SVG, and MathML user-agent stylesheets track the
  current upstream sources, including text-control padding and wrapping, range
  sizing, image overflow clipping, and non-wrapping input buttons.
- The compact script bridge exposes live `<style>.sheet` insertion/deletion,
  constructed `CSSStyleSheet.replaceSync()`, and document
  `adoptedStyleSheets`. Embedded sheets retain their DOM owner and style-scope
  ownership, so dynamic `@counter-style` rules rebuild generated pseudo-content
  when their resolved counter-style dependency changes. Nested animation-frame
  callbacks can clear inline styles through the `style` IDL attribute and
  remove the root's reftest class through `documentElement.classList`, allowing
  null transform longhands to replace stale layout values on recomputation.
- CSS `anchor()` functions participate as typed length leaves inside inset
  calculations, including `calc()`, `min()`, `max()`, nested anchor fallbacks,
  and calculated fallbacks. They remain invalid outside inset properties.
  A `position-area: span-all` box unions its original containing block with its
  default anchor, resolves insets and percentages against that area, and uses
  anchor-centered alignment only for axes whose self-alignment remains normal.
- Platform input-method sessions dispatch `compositionstart`, per-update
  `compositionupdate` plus non-cancelable `insertCompositionText`
  `beforeinput`/`input` pairs, and `compositionend`. Marked ranges survive
  repeated updates in form controls and contenteditable hosts; commits,
  cancellation, unmarking, selected text, and replacement ranges preserve the
  upstream event ordering, data, and `isComposing` state.
- Pseudo-elements generated by the document element are not document roots:
  they keep their own display type and resolve font-relative lengths through
  the originating root element. The browser bridge replays live selection and
  `Range.surroundContents()` mutations used by the upstream crash reftest.
- HTML image `x`/`y` geometry resolves accumulated paint state only after a
  committed layout box is found; disconnected or `display:none` images return
  zero without touching stale paint properties. Image and image-input requests
  that are newly created, fetching, or awaiting a pending request render as
  blank space instead of flashing alternative text; broken and source-less
  images expose nonempty alternative text through a closed UA shadow tree and
  ordinary non-replaced layout, so inherited font, wrapping, selection, and
  find-in-page behavior use the normal text path. Request-state changes rebuild
  the representation when an image switches between fallback text, pending
  blank space, and decoded pixels. Decoded image data tracks live display
  clients for both static and animated bitmaps. GIF streams that omit the LZW
  end-of-information code retain successfully decoded pixels and their natural
  dimensions instead of being rejected as broken. The per-document shared-request
  cache and list of available images use upstream LRU touch serials and bounded
  memory/count pruning, while excluding live decoded images from both the
  accounting and eviction candidates so DOM re-creation can reuse them without
  a redundant fetch or decode. Decoded image data also retains its response's
  CORS-cross-origin state. Drawing opaque no-CORS image data permanently taints
  a 2D canvas, after which pixel readback and HTML canvas data-URL/blob
  serialization reject with a security error; CORS-approved images remain
  origin-clean.
- Canvas background propagation reads containment and background ownership from
  the boxes generated by the document's actual first body. An unboxed body
  inserted before a rendered body prevents the later body's background from
  being propagated or suppressed.
- `-webkit-font-smoothing` parses and inherits through computed style, reaches
  foreground text, text shadows, and `background-clip: text`, and selects the
  corresponding macOS Skia/CoreGraphics rasterization mode.
- Scripted boundary selections remain live when nodes are inserted between
  them, selection moves are replayed in order, and CSSOM selection-style
  mutations reach the final paint without retaining a stale highlight.
- Range text geometry is derived from retained glyph fragments and transformed
  into viewport coordinates through the fragment containing block. Range and
  element client rectangles therefore agree under CSS transforms and continue
  to follow live ancestor scroll offsets.
- Empty editable blocks, paragraphs, and inline elements size their caret from
  font ascent plus descent, cap it at line height, and center it in extra line
  leading. The compact browser bridge replays `Selection.collapse()` so the
  upstream placeholder reftest exercises a real caret on both sides.
- Parent child-boundary carets use the retained fragment of the adjacent text
  child, preferring the previous child's end before the next child's start.
  The compact browser attaches a focused HTML navigable before recording paint,
  so caret reftests exercise visible LTR, RTL, and vertical geometry.
- Dashed CSS calls now evaluate active `@function` definitions during arbitrary
  substitution. Function-local parameters, defaults, declarations, typed return
  syntax, inheritance, and resolved-value caching share guarded cycle state;
  property guards include function identity, arguments substitute before arity
  rejection, and custom-property dependencies retain access to the function
  registry.
- Grid track values accept calculated flex breadths such as `calc(1fr)`, retain
  their authored calculation for serialization, and resolve the calculation to
  an `fr` factor for track sizing. They also parse and serialize `subgrid`
  line-name lists, including
  fixed and `auto-fill` name repeats. Separate adjacent line-name sets are
  retained, and interpolation/composition involving a subgrid remains discrete.
  Grid layout inherits a subgrid axis's parent tracks, gutters, and line names,
  clamps placements to the inherited bounds, and includes nested descendants in
  the parent track-sizing pass. Subgrid border, padding, margin, and half-gap
  edge adjustments contribute to intrinsic sizing; standalone subgrids retain
  the ordinary-grid fallback. Resolved CSSOM exposes the subgrid's local line
  names without manufacturing pixel tracks. Implicit named-area boundaries are
  clipped to the subgrid's two-dimensional overlap and remain distinguishable
  from explicit line names as they pass through nested subgrids.
- Custom properties declared in `@keyframes` now animate. Registered values
  interpolate as typed computed values, unregistered values animate discretely,
  composition and `!important` suppression follow the upstream rules, and the
  sampled values participate in `var()` resolution for targets and descendants.
  Animation overlays retain their authored base environment so inherited custom-
  property changes continue to propagate through animated elements.
- Paint-command-only style and UI changes retain the hit-test display list
  across repaint. Border radii, SVG fill/fill-rule, pointer-events, resize, and
  visibility carry the upstream hit-test-affecting metadata and still invalidate
  it; focus, selection, media, image, inspector, and scrollbar paint changes do
  not make the next input event rebuild the plan. Direct and fieldset-inherited
  form-control disabled changes invalidate their retained paint commands so
  checkbox and radio glyphs immediately reflect live enabledness.
- Retained scroll state owns its single dirty bit and publishes a new snapshot
  only after visual-context structure is settled. Viewport and element offset
  stores invalidate at the mutation site, repeated consumers keep the existing
  snapshot, and `LIBWEB_VERIFY_SCROLL_STATE=1` force-derives skipped refreshes
  into a temporary snapshot to verify that the retained offsets are current.
- Inline layout now finalizes conservative glyph-run ink bounds together with
  retained replay data after merging, ellipsis, and line clamping. Painting
  scales and positions those cached CSS-pixel bounds and keeps them distinct
  from the fragment rectangle for display-list damage and culling. Block
  ellipses always retain their shaped glyph data, including a selected font's
  missing-glyph result, and reuse an authored face when the same concrete face
  is also the last resort; synthesized and literal ellipses therefore replay
  identically. A baseline-
  aligned inline block that raises a line's baseline also carries the font
  strut's descent below it, and wrapped lines advance from that expanded line-
  box end. `vertical-align: text-top` and `text-bottom` place atomic inlines
  against the immediate parent inline's font ascent and descent, including when
  that parent has a different font size; the box's independent baseline
  contribution still participates in selecting the common line baseline.
  `vertical-align: top` and `bottom` form line-relative aligned subtrees: their
  descendants move together after the final line size is known, nested roots
  remain independent, and contained absolute-position static markers receive
  the same shift. Direct text ignores the block container's own alignment.
  Forced-break nodes never enter the inline box-model stack, so borders and
  padding on a styled `<br>` cannot become leading metrics on the next line.
  Inline containing-block rectangles are converted through the containing-
  block chain rather than layout-tree parents, avoiding duplicate table row and
  row-group offsets for positioned descendants hosted inside table cells.
  Atomic inline used offsets are published only after final line alignment, so
  positioned descendants whose actual containing block lies outside the atomic
  inline inherit its final baseline and text-alignment displacement.
- Inline formatting contexts publish their final inline-end insertion position
  after forced breaks, alignment, RTL direction, and writing-mode conversion.
  Originally-inline absolutely positioned descendants routed through an
  anonymous wrapper therefore retain the exact static position computed by the
  wrapper's line layout. When no preceding fragment exists, their hypothetical
  first-line position begins after any left float intrusion instead of at the
  container origin.
- In-flow blocks inside inline boxes are no longer split into anonymous
  continuations. They stay children of their inline parent and interrupt its
  inline formatting context: the line builder force-breaks before them, the
  parent BFC lays them out in place, and inline content resumes on a new line
  after their pending bottom margin. A trailing interrupting block's margin
  collapses through an auto-height parent without bottom padding or border,
  its width contributes to intrinsic inline sizing, and a line hosting it
  exports the block's baseline. CSSOM offsets unite the inline's per-line
  border boxes, while the line that only hosts the block contributes an empty
  box at the block's position.
- Native inputs are replaced elements for inline layout even when a generic
  block container hosts their shadow content, so a button-type input with
  `display: inline` is placed as one atomic fragment. Elements using button
  layout establish a block formatting context. Fieldsets with a flow inner
  display lay out as flow-root, and inline fieldsets as inline-block, without
  changing their computed display; the first anonymous wrapper of a childless
  inline-block is itself an inline-block.
- A parent block formatting context lays out only the markers of list items in
  its own flow; a list item that establishes an independent formatting context
  lays out its marker in its own run, so floating, absolutely positioned, and
  flex-item list items get markers. Outside markers with a text baseline align
  with the list item's first baseline once its children are laid out, and
  otherwise stay centered in their line height. The marker line height floors
  only a list item's automatic block size, so a specified height wins over it.
  Normal marker symbols, suffixes, list-style images, and authored `::marker`
  content use generated inline children of the marker box. Inside markers
  participate atomically in the list item's inline run, including through a
  trailing anonymous wrapper after block content, and layout-test symbols use
  the bundled Noto fallback's real glyph coverage and advances. A marker's own
  run remeasures that generated content instead of reusing a zero-width result
  from an enclosing shrink-to-fit probe. A live
  `display:none` box-presence change rebuilds layout and clears cached list
  ordinals, so hiding a list item removes its box and renumbers later markers.
  A hidden document element leaves an empty viewport that still establishes
  and reports the root block formatting context.
- A single authored image in `content` makes its element or pseudo-element the
  replaced image box. Classification happens before quote controls and counters
  resolve; list-item and `display: contents` pseudos retain anonymous inline
  image children, including flex/grid wrapper fixup and table-display
  normalization.
- An empty generated string creates a text node only inside an ordinary inline
  pseudo-element, where its degenerate fragment retains the zero-sized content
  geometry and the pseudo-element's padding and borders. Other pseudo-element
  boxes with `content: ""` have no children and do not report inline content.
  Quote controls resolving to empty text under `quotes: none` retain their
  layout-tree child but do not create that degenerate fragment or advance its
  insertion position.
- `overflow-wrap:anywhere`, `overflow-wrap:break-word`, and the legacy
  `word-break:break-word` split overflowing shaped text only at extended
  grapheme boundaries. `anywhere` and the legacy value reduce min-content
  contributions; `break-word` remains an emergency break for definite line
  widths. Split runs preserve their UTF-16 offsets, font faces, inline edges,
  and float-band placement, and text that already fits avoids grapheme work.
  Preserved trailing spaces and tabs also provide a soft wrap opportunity for
  following text without treating ordinary collapsed whitespace as a second
  float-band break.
- A line wider than its containing block ignores `text-align` and stays flush
  with the inline-start edge. RTL overflow therefore extends leftward into the
  reachable scrollable overflow area instead of being stranded to the right.
- Locale-sensitive `text-transform` casing uses the inherited element language,
  and a live `lang` change invalidates both the rendered-text cache and layout
  for affected text nodes. Recreated CSS/Layout font handles that resolve to the
  same concrete face are canonicalized, so a last-resort missing glyph and the
  following covered glyphs retain Ladybird's single shaped fragment.
- Text shaping applies computed `word-spacing` to spaces, no-break spaces, and
  collapsed line feeds. It records the exact shaped advance of trailing ASCII
  whitespace, carries that record through fragment merging and intrinsic shape
  reuse, and subtracts it directly when trimming line ends. Inline formatting
  contexts that are provably left-to-right shape neutral punctuation as LTR,
  preserving contextual positioning and kerning across apostrophes, hyphens,
  and inline boundaries; mixed, controlled, and RTL text retains per-code-point
  direction handling. SVG text and text-on-path use the same per-code-point
  computed font cascade, including lazy author-face activation and invisible
  fallback, then materialize the shaped glyph positions as outlines. SVG text
  chunks apply their shared anchor once and advance nested tspans by shaped
  advance rather than ink bounds.
- Unicode default-ignorable controls remain in glyph runs for UTF-16 text
  bookkeeping but have zero advance and are excluded from bounds, intercepts,
  and retained paint buffers. Non-painting fallback-font fragments can still be
  coalesced with the surrounding retained text run.
- HarfBuzz font scales clamp in double precision before conversion to its
  32-bit API. Oversized CSS font sizes therefore survive intrinsic text
  measurement, while cached fonts with equal saturated scales keep distinct
  point-size state.
- Text shaping shares origin-relative cached glyph data across layout, canvas,
  and painting. Cache keys preserve exact spacing bit patterns, common ASCII
  shapes use the dedicated fast path, and font/text LRU eviction follows the
  upstream limits without exposing cached runs to caller mutation.
- URL-backed font faces stay lazy during cascade probes and load only after
  shaping selects a covered pending face. The complete `font-display` timeline
  controls invisible fallback, swapping, and failure, while cache/decode work
  may defer the first paint without letting network requests hold it open.
  File-backed face and cascade storage remains heap-owned under the native
  no-GC build; a synchronous lazy load refreshes every retained style and text
  cache generation together with `line-height: normal`, so the first shaping
  pass cannot mix author glyphs with fallback metrics.
  Local WOFF and WOFF2 resources are prepared into stable sfnt faces for shared
  metrics, HarfBuzz shaping, and native replay. A face completed during layout
  invalidates its cached cascade and participates in the pre-paint stabilization
  pass, so `line-height: normal` uses the loaded face's metrics.
- Font invalidation advances a shared environment generation. Canvas and
  offscreen-canvas text retain their computed cascades and refresh them after a
  font change, including cascades restored from saved drawing state.
- Force-dark painting classifies foreground, background, SVG, border,
  selection, and image colors with independently configurable brightness
  thresholds. Eligible colors invert through Oklab lightness while retaining
  hue and alpha; selection and border colors preserve backdrop contrast, and
  small images are classified from palette, luminance, saturation,
  transparency, and chroma features before filtering. Decoded raster replay
  samples and caches that verdict, applies the same Oklab inversion per pixel,
  and leaves photo-sized or photographic content unchanged. Display-list recording
  assigns those roles to backgrounds, text and shadows, borders, selections,
  SVG, gradients, markers, form controls, scrollbars, and resizers, while UA
  focus rings and inspector overlays remain unfiltered. Its page setting
  propagates to child navigables, presents a dark preferred color scheme,
  invalidates style and paint state, and skips filtering when the root or meta
  color-scheme declares `dark` or uses the `only` modifier. The compact script
  bridge exposes `document.head`, reflects meta `name` and `content` properties,
  and refreshes color-scheme metadata after live DOM mutation so cached dark
  paint is discarded when a document opts out. It also exposes the upstream
  force-dark threshold and debug-overlay internals;
  line-box debugging paints each fragment's green bounds and red baseline ahead
  of its glyphs and explicitly bypasses force-dark resolution.
- Native bitmap replay carries row orientation separately from alpha format, so
  FFmpeg video and video-backed canvas frames remain top-down while ordinary
  Quartz-ordered decoded images retain their required replay flip.

- Live `contenteditable` and `designMode` changes refresh inherited editability,
  retained caret hit-test targets, and read/write selector state, including
  relational and sibling dependencies. Editing-host changes relayout empty
  text even when its inherited editable flag stays true. Enabling design mode
  resets selection and focuses the document element once; repeated `on`
  assignments preserve selection.

- Native `pause()` validates the actual DOM audio/video receiver, ignores extra
  arguments, replays pending mutations and runs the same model caller. Empty
  network state enters automatic resource selection before the internal pause
  steps; paused `preload="none"` media remains deferred. Explicit pause commits
  state and the live clock immediately, then queues timeupdate, pause and
  captured-batch rejection with a shared AbortError under the owning document's
  execution context. A listener that resumes playback does not add its new
  promises to the earlier batch. Other media promise paths, native play promises
  and synchronous selection remain separate work.

- Internal play queues separate play and waiting tasks. Playing notification
  captures its pending promises and starting clock before the manager hook starts,
  then commits that position, fires playing and resolves only that batch under
  the current document's execution context. An already-playing call queues its
  own resolution without another playing event or manager start. A pause before
  delivery leaves the earlier playing task unconditional. Public native play
  promises, permission/error gates and other media algorithms
  remain separate work.

- Media audible state follows Source's started-playback flag, enabled audio
  tracks and effective volume. Waiting playback stays silent after becoming
  unpaused. Playing notification invokes manager play before setting started
  state; pause clears started state before manager pause and reports audio
  afterward. Actual transitions notify the owning PageClient before Document
  timer/lifecycle notification; queued playing events do not restart audio.
  Resource-specific track removal re-evaluates audio without clearing started
  state, and adoption routes subsequent notifications through the current Page.
  Native play promises and physical playback remain separate work.

- Eligible playing video retains a screen wake lock from its actual Document's
  Page when a video track is selected and an audio track is enabled. Volume and
  mute do not affect that predicate. Readiness, ended state and track changes
  re-evaluate the handle; pause, resource reset and explicit finalization release
  only that media owner's handle. Adoption releases and recreates a held handle
  against the new Page, including same-Page adoption. Multiple owners share the
  existing Page counter and notify its client only on first acquisition and last
  release. Automatic GC finalization and native power-management transport remain
  separate work.

- Page mute changes reach registered concrete media owners, update their manager
  volume hooks and then their audible state. Effective volume queries the current
  Document's actual Page before element mute and clamped volume. Unchanged Page
  mute assignments produce no callbacks; public volume/muted values, playback
  state, volumechange events and screen wake locks are unaffected. Concrete owner
  transitions notify the owning PageClient and Document; legacy media records
  update timers only for their matching attached document. Explicit finalization
  unregisters retained callbacks. Physical weak-node lookup, automatic collector
  finalization and general cross-Page registry integration remain separate work.

## Translated module inventory

All 78 translated LibWeb packages and all 1,193 current module-owned C++
implementation units have audited V mappings. As of 2026-10-08, the tracked module
packages contain 432,614 implementation V LOC and 156,375 test V LOC.
Physical LOC includes comments and blank lines. Root support code and browser
integration code are excluded. Package counts include generated V assets and
supporting translations; WebAssembly includes the separately audited LibWasm
core. LOC and source-unit mappings do not establish behavioral equivalence.
`Selection` includes `dom/selection.v`, and `UIEvents` includes `dom/ui_events.v`;
their shared DOM test files are counted under the corresponding owner once.

| Module | Implementation V LOC | Module | Implementation V LOC |
| --- | ---: | --- | ---: |
| ARIA | 2,574 | Animations | 4,254 |
| Bindings | 2,718 | CSS | 114,903 |
| Clipboard | 1,123 | Compositor | 2,403 |
| Compression | 471 | ContentSecurityPolicy | 2,816 |
| CookieStore | 1,059 | CredentialManagement | 420 |
| Crypto (`webcrypto/`) | 7,957 | DOM | 43,430 |
| DOMURL | 854 | Editing | 13,938 |
| Encoding | 5,356 | EncryptedMediaExtensions | 572 |
| EntriesAPI | 44 | EventTiming | 153 |
| Fetch | 6,678 | FileAPI | 1,493 |
| Fullscreen | 93 | GPC | 16 |
| Gamepad | 860 | Geolocation | 535 |
| Geometry | 2,121 | HTML | 69,495 |
| HighResolutionTime | 500 | IndexedDB | 5,455 |
| Infra | 548 | Internals | 2,337 |
| IntersectionObserver | 668 | Layout | 44,740 |
| Loader | 1,921 | MathML | 653 |
| MediaCapabilitiesAPI | 657 | MediaCapture | 1,240 |
| MediaSourceExtensions | 4,079 | MimeSniff | 1,108 |
| MixedContent | 93 | NavigationTiming | 645 |
| NotificationsAPI | 370 | Page | 6,840 |
| Painting | 7,979 | PerformanceTimeline | 502 |
| PermissionsAPI | 239 | Platform | 2,824 |
| ReferrerPolicy | 105 | RequestIdleCallback | 59 |
| ResizeObserver | 605 | ResourceTiming | 342 |
| SRI | 156 | SVG | 6,747 |
| SecureContexts | 59 | Selection | 1,479 |
| Serial | 243 | ServiceWorker | 1,573 |
| Speech | 668 | StorageAPI | 584 |
| Streams | 7,421 | TrustedTypes | 863 |
| UIEvents | 1,490 | URLPattern | 1,703 |
| UserTiming | 119 | ViewTransition | 743 |
| WebAssembly | 11,143 | WebAudio | 8,682 |
| WebDriver | 3,934 | WebGL | 6,627 |
| WebIDL | 2,551 | WebLocks | 701 |
| WebSockets | 409 | WebVTT | 464 |
| WebXR | 411 | Worker | 142 |
| XHR | 1,695 | XLink | 13 |
| XML | 477 | XPath | 672 |
| **Total** | **432,614** |  |  |

`PORT_STATUS.md` is the canonical detailed inventory. It also records upstream
C++ file/LOC counts, per-module test LOC, status, and the counting conventions;
keep its figures synchronized when translated files change materially.
