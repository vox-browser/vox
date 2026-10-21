# Repository instructions

## Development branch

- Do all development and commit all changes directly on `master` in the
  canonical checkout at `/Users/alex/code/vox2`.
- Do not create or use feature branches, detached checkouts, or Git worktrees
  for development. Serialize edits and commits in the canonical checkout.
- Keep new history linear with focused commits; do not rewrite existing shared
  history. Remove an existing worktree only after its committed and uncommitted
  logic has been incorporated into `master` and verified.

## Commits

- Commit every completed feature and fix after running the relevant checks.
  Do not leave implemented work uncommitted unless the user explicitly asks.
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
- Run `v -enable-globals test libjs` with current V; exercise heap ownership
  with the same command plus `-gc none`. Both modes also pass with the 0.5.2
  compatibility compiler (`-old-compiler`).
- Compare the current upstream AST fixtures with
  `v -enable-globals run tools/libjs_ast_corpus.v --all`.
  Keep these comparisons exact; the driver has no case overrides.
- The browser still uses JavaScriptCore. The parser's 32-call recursion limit,
  absent regex backend, and the pending bytecode generation, interpreter loop,
  builtin objects, and module linking must not be described as full LibJS
  parity.

## Build and run Vox

- Build the native macOS bundle from this repository with:

  ```sh
  cd ~/code/vox2
  sh build-prod-browser.sh
  ```

- `build-prod-browser.sh` uses `V_BIN` when set, then `v` from `PATH`, and finally
  `~/code/v/v`. It writes `Build/v/Vox.app` and ad-hoc signs the bundle.
  `build_ladybird.sh` is a compatibility alias for the same build.
- The browser builds with current V and fails rather than falling back to the
  0.5.2 compatibility compiler; an outdated `v` on `PATH` needs `V_BIN`.
  `LADYBIRD_V_GC=prealloc` builds use `-prealloc -gc none` and need V's
  bounded `v_realloc` copy under `-prealloc`. Under current V, `int` is 64-bit:
  hand native code `i32` data, and compare references with
  `voidptr(a) == voidptr(b)` (`==` compares the referenced values).
- Launch the browser with `open Build/v/Vox.app`, or pass a URL, an HTML
  file, or literal HTML directly to its executable:

  ```sh
  Build/v/Vox.app/Contents/MacOS/Vox https://example.com
  Build/v/Vox.app/Contents/MacOS/Vox ./page.html
  ```

- Run the non-windowed engine/JavaScript startup check with:

  ```sh
  Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke
  ```

- Run all translation tests from this repository with `v test .`. When `v` is
  not on `PATH`, use `~/code/v/v test .`.
- The V bundle is independent of upstream Ladybird at
  `~/code/3rd/ladybird/Build/release/bin/Ladybird.app`.
- On Linux, `sh build-prod-browser.sh` builds `Build/linux/vox`. See
  [Linux setup](docs/LINUX.md) for system dependencies and the pinned Skia
  bootstrap. Linux uses JavaScriptCoreGTK, GLib, Fontconfig, and the portable
  X11 renderer; the Cocoa painter and native media adapter remain macOS-specific.
- Run the Linux port checks with `python3 tools/test_linux_native.py` and
  `python3 tools/test_linux_browser.py`; the latter uses Xvfb and xdotool for
  actual window rendering and address-bar keyboard navigation. Use
  `python3 tools/test_linux_native.py --gc none` for ownership diagnostics.

## Screenshot conformance workflow

- Run windowed tests and visual checks on the display away from the pointer
  when two monitors are connected. Screenshot launches select it automatically;
  use `VOX_TEST_WINDOW=1` for other test launches. See
  [test window placement](docs/TEST_WINDOW_PLACEMENT.md).

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
  promises to the earlier batch. Complete media promise algorithms and
  synchronous selection remain separate work.

- Internal play queues separate play and waiting tasks. Playing notification
  captures its pending promises and starting clock before the manager hook starts,
  then commits that position, fires playing and resolves only that batch under
  the current document's execution context. An already-playing call queues its
  own resolution without another playing event or manager start. A pause before
  delivery leaves the earlier playing task unconditional. Complete resource,
  readiness and seek algorithms remain separate work.

- Media audible state follows Source's started-playback flag, enabled audio
  tracks and effective volume. Waiting playback stays silent after becoming
  unpaused. Playing notification invokes manager play before setting started
  state; pause clears started state before manager pause and reports audio
  afterward. Actual transitions notify the owning PageClient before Document
  timer/lifecycle notification; queued playing events do not restart audio.
  Resource-specific track removal re-evaluates audio without clearing started
  state, and adoption routes subsequent notifications through the current Page.
  Physical playback remains separate work.

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

- Media CSS states query the concrete HTML audio/video owner in the current
  Document. Paused/playing, element mute, seeking and blocked readiness refresh
  self, sibling, ancestor `:has()` and pseudo-element styles, including after
  adoption and inside the owning shadow scope. Playing follows the paused flag
  even without a playable resource; Page mute and zero volume do not set
  `:muted`. The style pass applies descendant plans queued by the `:has()` ancestor
  walk before computing styles. Complete resource/readiness algorithms and
  physical playback remain separate work.

- Native `load()` validates the actual DOM media receiver before replay, ignores
  extra arguments and calls the owning model. Load cancels only that owner's old
  tasks, queues abort/emptied/reset timeupdate, and rejects its current unpaused
  pending play batch with one actual AbortError under the Document context.
  State and default-rate reset commit before event delivery. Stable-state
  resource selection, complete load/reset behavior and physical playback remain
  separate work.

- First decoded-data notification queues `loadeddata` once per load on the
  actual media owner's task queue. Explicit and automatic load entry rearm the
  flag; only a nonempty-network metadata-to-data transition consumes it. That
  branch synchronously releases the current Document's owned load delay, even
  after first data was reported. Other readiness events, complete resource
  timing and physical decoding remain separate work.

- Metadata notification queues `loadedmetadata` from the actual media owner's
  nonempty-network `HAVE_NOTHING` to `HAVE_METADATA` readiness transition. The
  fetch adapter and MediaSource initialization share that branch, so listeners
  observe live state after task delivery instead of receiving a synchronous
  fetch-only event. Reload cancels only the owner's pending notification.
  Complete resource/readiness behavior and physical decoding remain separate
  work.

- Canplay notification queues on the actual media owner when a nonempty-network
  readiness state crosses from current-data-or-less to future or enough data.
  First-data delivery precedes canplay, and readiness-driven playing follows it.
  The pending play batch and start position are captured before listeners run;
  a listener-created promise stays outside that batch. Manager start remains
  immediate. Reload cancels only the owner's old task, and later tasks follow
  adoption and active-document delivery. Full readiness/autoplay and physical
  decoding remain separate work.

- Canplaythrough notification queues on the actual media owner whenever a
  nonempty-network readiness state changes to enough data. It follows any
  first-data, canplay and readiness-driven playing tasks, with the original
  promise batch resolved before canplaythrough delivery. Future-to-enough queues
  only this notification; unchanged readiness does not repeat it. Reload cancels
  only the owner's old task, and later tasks follow adoption and active-document
  delivery. Enough-data autoplay substeps, buffering-drop waiting, complete
  resource/readiness/seek and physical decoding remain separate work.

- Autoplay eligibility reads the automatic-features sandbox flag from the
  actual audio/video owner's current document. Sandboxed autoplay with
  `preload="none"` stays deferred; explicit `load()` fetches while leaving the
  owner paused. Adoption and later flag changes use the live document.
  Enough-data autoplay substeps and full Permissions Policy remain separate
  work.

- Resource autoplay consults the actual owner's current document origin,
  sticky Window activation and effective volume through the playback permission
  predicate. Consumed transient activation preserves sticky permission. Default
  policy allows inaudible media; origin allowlisting, the file exception and
  sticky activation can override blocking. Page mute follows its document,
  including after adoption. Explicit load fetches blocked media without
  starting autoplay. Full Permissions Policy and enough-data autoplay timing
  remain separate work.

- Public V model play rejects denied requests with a typed `NotAllowedError`
  before the existing unsupported-source check or internal play steps. It
  preserves earlier pending promises and queues no play tasks or fetch. The
  current document supplies permission after adoption; sticky activation still
  permits explicit play when sandboxing blocks autoplay.

- Volume/muted changes queue volumechange, then run internal pause when the
  current Document denies playback, before updating effective volume. The
  paused state and manager stop commit immediately; the existing timeupdate/
  pause task follows volumechange and rejects its captured model promise batch
  afterward. Already-paused blocked owners lose can-autoplay without fetching.
  Page-wide mute changes retain their separate update-only behavior.

- Permitted V play requests with an unsupported-source MediaError reject with
  a fresh typed NotSupportedError carrying its current message before appending
  a promise or entering internal play. Permission denial still wins. Native
  exception conversion retains Unicode/NUL messages and wrapper identity.

- Native JavaScript `play()` now returns a real Promise backed by the same
  WebIDL capability retained in the actual audio/video owner's pending list.
  Parsed and script-created media inherit the native method; ordinary compact
  elements no longer expose the fulfilled stub. Brand checks precede replay,
  binding failures reject with the original reason, and permitted requests stay
  pending until the owner's captured task batch settles. Permission, source,
  pause, load and ended failures expose typed DOMExceptions; resource selection,
  MediaSource failure and ended rejection share the current Document execution
  context. Load's pinned FIXME for already-captured canceled-task batches remains
  pending. Full resource/readiness/seek/MSE, enough-data autoplay, Permissions
  Policy, physical decoding and automatic ownership remain separate work. See
  [native play evidence](docs/translation-audit/NATIVE_MEDIA_PLAY_PROMISE_OWNER.md).

- Ordinary HTML audio/video `addEventListener`, `removeEventListener` and
  `dispatchEvent` calls now share the actual DOM owner's native EventTarget
  records. Successful compact media binding removes the generic own listener
  stub, preserving trusted queued play/pause/readiness events, callback identity,
  capture, once and listener-object behavior. A retained-frame fixture no longer
  causes fake late loadeddata/seeked callbacks. Real Page pointer release delivers
  media listeners before compact replay, with no duplicate click; native click
  cancellation reaches the Page flag. Image, object and SVG compact listeners
  retain their existing path. General nonmedia EventTarget, handler attributes,
  full media interfaces and Cocoa/input hit-testing parity remain separate work.
  See [ordinary media listener evidence](docs/translation-audit/NATIVE_MEDIA_EVENT_LISTENER_OWNER.md).

- Script-assigned media handlers now use native accessors for the selected 23
  media events on the actual DOM audio/video owner. Parsed and created media
  keep callback identity, listener-slot ordering, queued event delivery and
  existing play Promise order. Shared legacy handler conversion retains any
  object, clears primitive values and silently skips noncallable objects before
  callback context entry or handleEvent reads; ordinary listener objects keep
  their separate handleEvent path. Raw inline element compilation, onclick/
  general HTMLElement handlers, complete prototype placement, foreign realms
  and weak ownership remain separate work. The pinned load captured-task FIXME
  and full media/physical decoding boundaries remain. See
  [native media handler evidence](docs/translation-audit/NATIVE_MEDIA_EVENT_HANDLER_OWNER.md).

- Script-assigned media onpointerdown/onpointerup/onmousedown/onmouseup now
  use the actual DOM owner's native handler records. Parsed and created media
  keep callback identity, handler-slot order and trusted Page press/release
  delivery. Pointerdown false suppresses compatibility mouse delivery through
  release while preserving click; mouseup false does not block click. Compact
  replay adds no duplicate delivery. Page fixtures use explicit DOM targets;
  Cocoa transport, hit testing, full input interfaces, raw inline compilation,
  onclick/remaining handler attributes and complete prototype placement remain
  separate work, along with realms, weak ownership and the load/media boundaries.
  See [press/release handler evidence](docs/translation-audit/NATIVE_MEDIA_POINTER_HANDLER_OWNER.md).

- Native media onclick now shares the actual audio/video DOM handler slot,
  preserving callback identity, listener order, trusted Page delivery and
  cancellation. Private Event/Page receipts prevent stale compact raw replay
  after native self-mutation; replay reads the current DOM raw slot by stable
  bridge key after committing pending mutations. Untouched raw media fallback
  and generic image/object/SVG compact clicks remain. Raw fallback is still
  Function/plain-Event approximation; real inline compilation, full prototypes,
  other handlers, Cocoa/hit testing, input interfaces, realms, weak ownership,
  full/physical media and the pinned load FIXME remain separate work. See
  [native click evidence](docs/translation-audit/NATIVE_MEDIA_CLICK_HANDLER_OWNER.md).

- Native media onauxclick/ondblclick now reuse actual DOM handler slots and
  existing Page dispatch. Double-click cancellation preserves the primary
  click's activation result; middle/right auxclick exact false blocks it.
  Handler identity/order, self-replacement, exception reporting and the earlier
  primary receipt survive ordinary trusted Page tests. Main/Page/dispatcher/
  bootstrap remain unchanged. Explicit targets/counts and synthetic screenshot
  pages leave Cocoa/hit testing, complete input fields/prototypes, raw inline
  compilation, realms, weak ownership and full/physical media/load boundaries
  open. See [auxiliary handler evidence](docs/translation-audit/NATIVE_MEDIA_AUXILIARY_HANDLER_OWNER.md).

- Native media onpointermove/onmousemove now reuse actual DOM handler slots
  and existing Page move delivery. Pointermove cancellation preserves the
  compatibility mousemove; mousemove false controls the move result. Canceled
  pointerdown suppresses compatibility moves until release while preserving
  click. Parsed/created owners retain handler order, self-mutation, exception
  identity and DOM polling; compact replay adds no native callback. Main/Page/
  dispatcher/bootstrap remain unchanged. Explicit targets and a base Event
  surface leave Cocoa/hit testing, full input fields/prototypes, raw inline
  compilation, realms, weak ownership and full/physical media/load boundaries
  open. See [movement handler evidence](docs/translation-audit/NATIVE_MEDIA_MOVEMENT_HANDLER_OWNER.md).

- Window-owned runtimes now expose UIEvent constructor, view/detail/virtual
  which and the native legacy initializer over actual records. Receiver checks,
  WebIDL conversion order, dispatch guard, late attachment and captured parent/
  global identity use the existing owner. All ten UI families inherit the
  retained prototype; actual Page media callbacks keep current-event,
  cancellation and DOM polling. Owner-local views, existing Page move-data
  construction and concrete subclass interfaces remain explicit boundaries,
  alongside physical input, raw inline element compilation, realms, weak
  ownership and full media/load work. See [UIEvent evidence](docs/translation-audit/NATIVE_UI_EVENT_OWNER.md).

- Mouse, pointer and wheel events now share the base Event related-target
  state used by DOM dispatch; DragEvent inherits the corrected MouseEvent path.
  Construction, typed getters, legacy initialization, clones and trusted hover
  delivery follow per-listener shadow retargeting, suppression and clear-target
  cleanup. Six core/actual-owner cases pass, with 12 selected files in both GC
  modes and ordinary optimized validation. That core slice used a private
  owner observer; the later owner-local MouseEvent binding supplies its public
  constructor/getters, followed by the concrete PointerEvent and WheelEvent
  surfaces. The DragEvent interface remains open. See
  [related-target evidence](docs/translation-audit/MOUSE_EVENT_RELATED_TARGET.md).

- Window-owned runtimes now expose MouseEvent's public constructor, nineteen
  native getters and getModifierState/initMouseEvent over actual records.
  Dictionary conversion, a single constructor prototype read, PointerEvent
  coordinate overrides and canonical relatedTarget use the retained owner.
  Six focused/optimized cases match db342c95; signed startup, two exact pages
  and 11 smoke cases pass there. At a03691e5, 14 selected files pass in both GC
  modes after a separate one-line callback-fixture pointer correction. Binding/new-test
  bytes remain identical. The later PointerEvent binding completes that
  concrete owner-local interface. The later WheelEvent binding supplies its
  own interface; DragEvent, foreign views/realms,
  weak ownership and full Page/physical input remain open. See
  [MouseEvent evidence](docs/translation-audit/NATIVE_MOUSE_EVENT_OWNER.md).

- Window-owned runtimes now expose PointerEvent's constructor and thirteen
  native getters, getPredictedEvents and secure-context-only getCoalescedEvents.
  The retained Pointer/Mouse/UI/Event chain uses actual records, source numeric
  and iterable conversion, native child identity and fresh sequence arrays.
  The pinned angle defaults remain independent; abrupt generated sequence
  errors preserve the source's missing IteratorClose behavior. Seven focused
  and optimized cases pass; all 17 selected files pass in both GC modes.
  Private production passes ten stages at c9dc0da2, with two pixel-exact
  untrusted Pointer pages and all 11 smoke cases (eight exact).
  Its retained image/artifact closure preserves 66 current
  and 1,859 prior hashes. The preceding committed CSS regression remains in
  the 17-file batch. Later canonical Layout work is outside the frozen
  c9dc0da2 validation source. Element pointer capture, hardware input/prediction,
  concrete DragEvent interface, foreign views/realms, weak ownership and
  full Page/physical input remain open. See
  [PointerEvent evidence](docs/translation-audit/NATIVE_POINTER_EVENT_OWNER.md).

- Window-owned runtimes now expose WheelEvent's constructor, seven native
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
  See [WheelEvent evidence](docs/translation-audit/NATIVE_WHEEL_EVENT_OWNER.md).

- Window-owned runtimes now expose DragEvent's constructor and sole native
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

- Window-owned JavaScriptCore runtimes now expose native DataTransfer
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

- Window-owned DataTransfer now exposes its native read-only files getter over
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

- Window-owned DataTransfer now exposes a stable native live items list and
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

- Window-owned DataTransferItemList.add now selects the native File overload for
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

- Window-owned DataTransferItem.getAsString now brands its native receiver before
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

- Window-owned DataTransferItem.webkitGetAsEntry now brands its native receiver,
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

- Native media ondrag, ondragend, ondragenter, ondragleave, ondragover,
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

## Translated module inventory

All 78 translated LibWeb packages and all 1,193 current module-owned C++
implementation units have audited V mappings. Verified at `33ba13ac` on
2026-10-13 UTC, 2,238 assigned files contain 433,415 implementation V LOC and
161,056 test V LOC.
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
Physical LOC includes comments and blank lines. Root support code and browser
integration code are excluded. Package counts include generated V assets and
supporting translations; WebAssembly includes the separately audited LibWasm
core. LOC and source-unit mappings do not establish behavioral equivalence.
`Selection` includes `dom/selection.v`, and `UIEvents` includes `dom/ui_events.v`;
their shared DOM test files are counted under the corresponding owner once.

| Module | Implementation V LOC | Module | Implementation V LOC |
| --- | ---: | --- | ---: |
| ARIA | 2,574 | Animations | 4,254 |
| Bindings | 2,718 | CSS | 115,091 |
| Clipboard | 1,123 | Compositor | 2,403 |
| Compression | 471 | ContentSecurityPolicy | 2,816 |
| CookieStore | 1,059 | CredentialManagement | 420 |
| Crypto (`webcrypto/`) | 7,957 | DOM | 43,502 |
| DOMURL | 854 | Editing | 13,938 |
| Encoding | 5,356 | EncryptedMediaExtensions | 572 |
| EntriesAPI | 65 | EventTiming | 153 |
| Fetch | 6,678 | FileAPI | 1,493 |
| Fullscreen | 93 | GPC | 16 |
| Gamepad | 860 | Geolocation | 535 |
| Geometry | 2,121 | HTML | 69,710 |
| HighResolutionTime | 500 | IndexedDB | 5,455 |
| Infra | 548 | Internals | 2,337 |
| IntersectionObserver | 668 | Layout | 44,944 |
| Loader | 1,921 | MathML | 653 |
| MediaCapabilitiesAPI | 657 | MediaCapture | 1,240 |
| MediaSourceExtensions | 4,079 | MimeSniff | 1,108 |
| MixedContent | 93 | NavigationTiming | 645 |
| NotificationsAPI | 370 | Page | 6,901 |
| Painting | 7,993 | PerformanceTimeline | 502 |
| PermissionsAPI | 239 | Platform | 2,851 |
| ReferrerPolicy | 105 | RequestIdleCallback | 59 |
| ResizeObserver | 605 | ResourceTiming | 342 |
| SRI | 156 | SVG | 6,747 |
| SecureContexts | 59 | Selection | 1,479 |
| Serial | 243 | ServiceWorker | 1,573 |
| Speech | 668 | StorageAPI | 584 |
| Streams | 7,421 | TrustedTypes | 863 |
| UIEvents | 1,489 | URLPattern | 1,703 |
| UserTiming | 119 | ViewTransition | 743 |
| WebAssembly | 11,143 | WebAudio | 8,682 |
| WebDriver | 3,934 | WebGL | 6,627 |
| WebIDL | 2,551 | WebLocks | 701 |
| WebSockets | 409 | WebVTT | 464 |
| WebXR | 411 | Worker | 142 |
| XHR | 1,695 | XLink | 13 |
| XML | 477 | XPath | 672 |
| **Total** | **433,415** |  |  |

`PORT_STATUS.md` is the canonical detailed inventory. It also records upstream
C++ file/LOC counts, per-module test LOC, status, and the counting conventions;
keep its figures synchronized when translated files change materially.

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

## Verification cadence

- Run focused checks for each completed fix or translation slice.
- For instruction-count optimization, batch broad regression suites after each
  cumulative measured reduction of 5,000,000 retired instructions since the last
  broad verification. Compare the same benchmark endpoint and workload, record
  the measured baseline and accumulated savings, and do not run broad suites
  for every individual fix below that threshold.
  The Wikipedia performance broad batch covers the fixes through
  `24626bff` and test corrections `3d88268d`/`12713a3b`: 135 selected
  CSS/SVG/layout/native cases pass in both Boehm and no-GC C-O0 builds, all 100
  upstream LibJS AST fixtures compare exactly, and production C-O2 Boehm startup
  succeeds. All 39 screenshot comparisons complete: 29 are pixel-exact, 8 pass
  existing fuzzy bounds, and 2 gradient reference mismatches have identical
  decoded pixels in the original, intermediate, and final binaries. No bounds
  changed. All eight required live SVG mutation comparisons are pixel-exact.
  The matching 20-sprite fixture median falls from 22,560,405,990 to
  2,364,099,677 retired instructions, saving 20,196,306,313 (89.521%) with
  byte-identical screenshots. Additional measured savings after this batch:
  zero. The original whole Wikipedia frame was incomplete, so no whole-page
  CPU reduction is credited. Frozen-page startup through capture is 1,566.53 ms
  versus Chrome's 1,443.51 ms, with different endpoints; page-rendering parity
  remains open. See `docs/WIKIPEDIA_PERFORMANCE.md` for provenance and both
  unchanged reference mismatches. The prior CSS UTF-8 destinations batch
  `a278f7b1` and its separately credited GitHub savings remain recorded in
  `docs/GITHUB_PERFORMANCE.md`. Production GC remains enabled with one
  marker. Independent canonical work is preserved when its pre-build identity
  is unavailable.
  GitHub public-length resolution `137e4e85` passes 2,004 focused assertions
  per configuration and reduces the controlled resolver probe by 62.92%.
  Its matching 30-pair first-frame saving is 76,262,583 instructions;
  repeatable page credit is 0. Broad verification: passed.
  The focused viewport is exact. Chrome parity remains open; the isolated Root
  snapshot app receives no extra page credit. See `docs/GITHUB_PERFORMANCE.md`.
  GitHub integration of `058ba684`/`3235339f` passes five focused cases in both
  GC modes and the selected 87-case batch in both modes, plus 19 screenshots
  (16 exact). Its matching 30-pair observed saving is 19,881,368 instructions;
  repeatable credit is 0 because the interval includes zero. Additional observed
  savings after that batch are zero. The isolated performance app is frozen,
  preserves the canonical app and does not establish Chrome parity.
  Private inline-buffer release `77a59b25` passes 23,135 focused assertions
  per configuration and reduces its controlled formatting probe by 0.56%.
  Matching 30-pair observed savings are 35,773,386 instructions, with repeatable
  credit 0 because the interval includes zero. The selected 87-case batch passes
  both GC modes; 19 screenshots pass (16 exact), and the focused viewport is exact.
  Additional observed savings after that batch are zero; Chrome parity is open.
  Empty custom-property inheritance `35615f24` passes 1,310 focused
  assertions per configuration; the controlled installation probe uses 84.95%
  fewer retired instructions. Matching 30-pair observed savings are
  917,302,664, with repeatable page credit 917,302,664.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  Iterator-owned text context `3f660b04` passes 23,230 focused assertions
  per configuration. Matching 30-pair observed savings are 162,205,328.5
  instructions, with repeatable page credit 162,205,328.5.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  Deferred rare geometry `5f212342` passes 17,785 focused assertions per
  configuration; its complete intrinsic probe uses 20.21% fewer instructions.
  Matching 30-pair observed savings are 13,989,552.5, with
  repeatable page credit 0.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  Intrinsic column geometry `e4f2da02` passes 18,854 focused assertions
  per configuration; its complete nested-column probe uses 42.34% fewer
  instructions. Matching 30-pair observed savings are 68,913,646,
  with repeatable page credit 0.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  Bulk glyph append `90ddf27a` passes 956 common focused assertions per
  configuration plus 63 candidate self-append assertions in each GC mode;
  its complete inline-formatting probe uses 1.30% fewer instructions.
  Matching 30-pair observed savings are -782,470,908, with
  repeatable page credit 0.
  Broad verification: deferred below the observed 5,000,000-instruction gate.
  The focused viewport is exact; Chrome parity remains open.
  Queued `:has()` feature accumulation `32b44c5f` passes 573 focused assertions
  per configuration; its complete repeated-recording probe uses 75.42% fewer
  instructions. Matching 30-pair observed savings are -26,116,592.5,
  with repeatable page credit 0.
  Broad verification: deferred below the observed 5,000,000-instruction gate.
  The focused viewport is exact; Chrome parity remains open.
  Invalidation-union key reuse `48f50ae1` passes 498 focused assertions
  per configuration; complete fresh unions use 11.71% fewer instructions.
  Its page cohort is incomplete: four primaries are retained, then the unchanged
  control exhausts three pre-parse startup attempts. No primary is rerun,
  no page median or confidence interval is claimed, and page credit is zero.
  The focused viewport is exact. Broad verification is deferred; the last broad
  baseline remains `e4f2da02`. Chrome parity remains open.
  The 1 GiB document heap hint `33a0fd5e` passes 12 focused assertions in
  each Boehm configuration and one no-GC assertion. The threshold and explicit
  heap overrides remain unchanged; GC stays enabled with one marker.
  Matching 30-pair observed savings are 6,932,470,852, with
  repeatable page credit 6,932,470,852. Median process peak footprints are
  1,435.5 to 1,673 MiB.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  The 2 GiB document heap hint `58f034be` passes 12 focused assertions in
  each Boehm configuration and one no-GC assertion. The threshold and explicit
  heap overrides remain unchanged; GC stays enabled with one marker.
  Matching 30-pair observed savings are 4,270,440,396.5, with
  repeatable page credit 4,270,440,396.5. Median process peak footprints are
  1,681.5 to 2,731.1 MiB.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  The 4 GiB document heap hint `0c8030d5` passes 12 focused assertions in
  each Boehm configuration and one no-GC assertion. The threshold and explicit
  heap overrides remain unchanged; GC stays enabled with one marker.
  Matching 30-pair observed savings are 800,186,010, with
  repeatable page credit 800,186,010. Median process peak footprints are
  2,730.8 to 3,726 MiB.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; Chrome parity remains open.
  Horizontal row basis classification `115c667f` passes 20,783 focused
  assertions per configuration. Complete nested-row contexts use 70.87% fewer
  instructions. Matching 30-pair observed savings are -3,138,018,
  with repeatable page credit 0. Both builds retain the 4 GiB hint.
  Broad verification: deferred below the observed 5,000,000-instruction gate.
  The focused viewport is exact; Chrome parity remains open.
  The inside-layout height-consumer attempt `45645bb8` is reverted
  by `4b471c1d`. Its local probe saves 39.92%, but only 9/30 page pairs
  improve and the paired interval is entirely negative. Page credit is zero.
  Its rejected candidate passes 87 selected cases both GC and 19 screenshots
  (16 exact), triggered by the positive marginal-median point. Shipping broad
  baseline stays `0c8030d5`; no completed primary is discarded or rerun.
  Typed invalidation membership `45cd0e78` passes 6,180 focused
  assertions per configuration. Complete invalidation data construction uses
  3.87% fewer instructions. Matching 30-pair observed savings are
  3,913,662, with repeatable page credit 0.
  Broad verification: deferred below the observed 5,000,000-instruction gate.
  The focused viewport is exact; both retain 4 GiB. Chrome parity remains open.
  Optional rule-bucket lookup round50 is rejected before page sampling.
  Its sparse matching probe retires 6.80% more instructions, with all three
  pairs worse; the owned function is restored. Focused checks pass 1,640
  assertions per configuration. Failed pre-counter probes/profiles are kept.
  No page credit or baseline reset; round49 remains the control.
  Direct rule-bucket consumption `24b84c6d` passes 1,640 focused
  assertions per configuration. Complete matching-rule-set construction uses
  6.34% fewer instructions. Matching 30-pair observed savings are
  47,968,135, with repeatable page credit 47,968,135.
  Broad verification: passed 87 selected cases both GC and 19 screenshots (16 exact).
  The focused viewport is exact; both retain 4 GiB. Chrome parity remains open.
  Selector projection memo `0685dd2f` is reverted by `842abbea`.
  Focused checks pass 6,215 assertions per config; its local probe saves 1.85%.
  Page evidence is inconclusive: 12/30 wins, paired median -14,683,761.5 and
  interval [-33,674,456.5, 7,942,125]. All 60 primaries/PNGs remain; credit 0.
  Broad is deferred below 5M. Shipping baseline stays `24b84c6d`, additional
  applied savings 0; the next control is frozen 51. Chrome parity remains open.
  Retained-key invalidation registration `b7ec7b3d` passes 9,047 focused
  assertions per configuration; complete local construction uses 27.76% fewer
  instructions. All 30 page pairs improve; observed/repeatable savings are
  66,633,443, with paired interval [56,439,223, 79,594,921].
  Broad verification: 87 selected cases both GC, 19 screenshots (16 exact).
  Focused viewport is exact. Additional savings after this batch: 0.
  Frozen comparison retains 4 GiB; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Numeric input-spelling parsing `b138b3ff` passes 83,195 focused
  assertions per configuration; complete local tokenization uses 9.22% fewer
  instructions. Page point saving 35,340,570, 18/30 wins,
  paired interval [-22,803,364, 82,329,486]; repeatable page credit 0.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact),
  with an exact numeric viewport. Additional observed savings after broad: 0.
  Same frozen 4 GiB hint; concurrent Root parser/memory/UI work is excluded.
  Chrome parity remains open.
  ASCII HTML token strings `6b8cdbfc` pass 875 focused assertions
  per configuration; complete local tokenization uses 7.23% fewer instructions.
  Page point saving 37,191,052.5, 19/30 wins,
  paired interval [-8,743,002, 102,504,624]; repeatable page credit 0.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused ASCII/Unicode viewport exact. Additional observed savings: 0.
  Same frozen 4 GiB hint; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Private simple-selector borrowing `e00a80ba` passes 1,813 focused
  assertions per configuration; complete local matching uses 30.56% fewer
  instructions. Page point saving -20,357,725.5, 18/30 wins,
  paired interval [-12,030,300.5, 40,848,714]; repeatable page credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused selector viewport exact. Additional observed savings: 0.
  Same frozen 4 GiB hint; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Local cascade scratch `9ec31a78` passes 2,341 focused assertions
  per configuration; complete public author cascades use 19.05% fewer instructions.
  Page point saving 58,286,753.5, 30/30 wins,
  paired interval [55,286,399, 65,388,786.5]; repeatable page credit 58,286,753.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused cascade viewport exact. Additional observed savings: 0.
  Same frozen 4 GiB hint; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Default cascade entry arrays `89264a65` pass 5,005 focused assertions
  per configuration; complete public author cascades use 0.27% fewer instructions.
  Page point saving 3,529,869.5, 18/30 wins,
  paired interval [-2,155,959, 8,870,342.5]; repeatable page credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused cascade viewport exact. Additional observed savings: 3,529,869.5.
  Same frozen4GiB hint; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Cached pseudo-target type filtering `12b86290` passes 1,651 focused
  assertions per configuration; complete public rule queries use 10.12% fewer
  instructions. Page point saving 33,098,321.5, 24/30 wins,
  paired interval [26,393,968.5, 88,757,508]; repeatable page credit 33,098,321.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused pseudo viewport exact. Additional observed savings: 0.
  Same frozen 4 GiB hint; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Direct pseudo-candidate buckets `89f28a48` pass 4,224 focused assertions
  per configuration; complete public candidate batches use 44.92% fewer instructions.
  Page point saving 40,724,011, 24/30 wins,
  paired interval [20,205,238, 50,963,302.5]; repeatable page credit 40,724,011.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused pseudo viewport exact. Additional observed savings: 0.
  Same frozen 4 GiB hint; independent Root memory/UI work is excluded.
  Chrome parity remains open.
  Retained public length conversion `5362d3aa` passes 1,681 focused assertions
  per configuration; complete public length batches use 48.71% fewer instructions.
  Page point saving 88,528,628, 30/30 wins,
  paired interval [88,450,463.5, 109,407,807.5]; repeatable page credit 88,528,628.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused spacing viewport exact. Additional observed savings: 0.
  Both variants use the same frozen test-window startup helper; historical
  medians receive no subtraction. Same frozen 4 GiB hint; Root work excluded.
  Chrome parity remains open.
  Per-item private inline output round62 is rejected before page sampling.
  All three complete local pairs regress; median instructions rise 31.71%.
  Compatible focused harnesses pass 7,846 assertions per configuration;
  incompatible newer Root fixtures and pre-counter failures are retained.
  The two private functions are restored; no normal build/C audit/page/bundle
  success or CPU credit is claimed. Broad baseline/next control stay `5362d3aa`,
  additional carry 0. Canonical and GUI preserved; Chrome parity remains open.
  Initialize-once inline output round63 is also rejected locally: all three
  pairs regress, median +30.46%. Candidate checks pass 7,846 assertions in
  both GC modes; exact successful control checks are reused. Owned functions
  are restored; no page credit or broad reset. Next control stays `5362d3aa`.
  Direct general CSS retained-value bridge `0d75f899` passes 822 focused
  assertions per configuration; complete public size batches use 8.19% fewer
  instructions. Page point saving 31,416,027.5, 30/30 wins,
  paired interval [29,945,635, 35,821,624.5]; repeatable page credit 31,416,027.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused typed-size viewport exact. Additional observed savings: 0.
  Same frozen 4 GiB runtime/placement helper; Root work excluded; isolated helper
  pinned inside the app. Canonical/GUI preserved; Chrome parity remains open.
  Per-text-context spacing storage round65 is rejected before page sampling.
  All three C-O2 configurations pass 8,233 focused assertions; complete local
  iterator builds regress 0.34% at the median (two of three pairs worse).
  Only owned context/function/test edits are restored; all evidence remains.
  No page credit or baseline reset; frozen64 remains the next control.
  Direct retained-size input `94643b1e` passes 1,016 focused assertions
  per configuration; complete public size batches use 6.87% fewer instructions.
  Page point saving 694,229.5, 10/30 wins,
  paired interval [-9,688,071.5, 234,536]; repeatable page credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused typed-size viewport exact. Additional observed savings: 694,229.5.
  Same frozen 4 GiB runtime/placement; independent Root excluded; isolated app
  pins frozen helper. Canonical/GUI preserved; Chrome parity remains open.
  Existing environment reuse `50e85e25` integrates against frozen66:
  1,541 control/1,753 candidate assertions; complete style-update probe -9.50%.
  Page point saving -4,045,384.5, 11/30 wins,
  paired interval [-13,456,556.5, 1,074,561]; repeatable page credit 0.
  Frozen integration accepted.
  Broad verification: deferred below cumulative 5M gate;
  focused custom-property viewport exact. Additional observed savings: 694,229.5.
  Same4GiB/placement; original feature attribution retained; contemporary Root
  and canonical/GUI preserved. Chrome parity remains open.
  Direct retained-length edges `f04b5385` pass 1,878 focused assertions
  per configuration; complete public mixed-edge batches use 12.52% fewer instructions.
  Page point saving 18,481,684.5, 23/30 wins,
  paired interval [4,206,261.5, 19,450,328.5]; repeatable page credit 18,481,684.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused mixed-edge viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; contemporary Root excluded; isolated app pins frozen helper.
  Canonical/GUI preserved; Chrome parity remains open.
  Direct inline-item cursor consumption round69 is rejected before page sampling.
  All three C-O2 configurations pass 23,689 focused assertions; complete inline
  formatting regresses 0.56% at the median, with all three pairs worse.
  Only owned function/test edits are restored and all observations remain.
  Page credit and additional observed savings stay 0; frozen68 remains control.
  Fresh intrinsic glyph-cache owners `585086c9` pass 23,486 focused
  assertions per configuration; complete cold intrinsic formatting uses 5.32%
  fewer instructions. Page point saving 8,157,499,
  17/30 wins, paired interval [-7,804,090, 20,236,130.5];
  repeatable page credit 0. Broad verification:
  87 selected cases both GC and 19 screenshots (16 exact);
  focused inline viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Stable shaping font keys `029dbe41` pass 2,816 focused assertions
  per configuration; complete public shaping batches use 15.85% fewer
  instructions. Page point saving 4,121,747.5,
  18/30 wins, paired interval [-4,968,837.5, 29,769,618.5];
  repeatable page credit 0. Broad verification:
  deferred below cumulative 5M gate;
  focused retained-line viewport exact. Additional observed savings: 4,121,747.5.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Required property contexts `e58fb75b` (independent committed slice)
  pass 2,460 focused assertions per configuration; complete public style
  batches use 5.84% fewer instructions. Page point saving 97,323,207,
  30/30 wins, paired interval [98,599,644, 105,813,109];
  repeatable page credit 97,323,207. Broad verification:
  87 selected cases both GC and 19 screenshots (16 exact);
  focused property-context viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Rendered UTF-16 owner reuse `ef64934c` (independent committed slice)
  passes 87,326 common assertions per configuration, plus 30
  candidate owner-sharing assertions both GC. Complete chunk iteration uses
  2.28% fewer instructions. Page point saving 13,096,315.5,
  15/30 wins, paired interval [-8,965,098, 16,591,329.5];
  repeatable credit 0. Broad verification:
  87 selected cases both GC and 19 screenshots (16 exact);
  focused chunk viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Lazy invisible font cache `cc2573b5` (independent committed slice)
  passes 1,566 common assertions in 17 cases per configuration,
  plus 3 private candidate cases/1,025 assertions both GC. Complete public
  chunk iteration uses 0.48% fewer instructions.
  Page point saving 8,110,549, 19/30 wins,
  paired interval [-3,655,531.5, 24,806,773.5]; repeatable credit 0.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused chunk viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Stable scanned retained geometry `46ee6c14` (independent committed slice)
  passes 20,085 common assertions in 19 cases per configuration,
  plus 3 private candidate cases/2,356 assertions both GC.
  Complete public geometry batches use 4.86% fewer instructions.
  Page point saving -779,304.5, 12/30 wins,
  paired interval [-14,174,114, 7,072,008.5]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Unchanged optional layout flags `46e9bc17` (independent committed slice)
  pass 20,151 common assertions in 21 cases per configuration,
  plus 2 private candidate cases/87 assertions both GC.
  Complete public flag batches use 46.94% fewer instructions.
  Page point saving 3,959,664.5, 13/30 wins,
  paired interval [-16,938,044, 12,288,917.5]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused geometry/flags viewport exact. Additional observed savings: 3,959,664.5.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Shared computed font cascades `67aa5610` (independent committed slice)
  pass 2,688 common assertions in 36 cases per configuration,
  plus 5 original candidate cases/430 assertions both GC.
  Complete public cascade batches use 11.83% fewer instructions.
  Page point saving 165,468,539, 30/30 wins,
  paired interval [155,341,153, 175,729,180]; repeatable credit 165,468,539.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused cascade/geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Deferred initial DOM bridge text `eacfe0fb` (independent committed slice)
  pass 18,323 common assertions in 15 cases per configuration,
  plus 3 original candidate cases/15,390 assertions both GC.
  Complete public document layout batches use 21.92% fewer instructions.
  Page point saving 198,275,718, 30/30 wins,
  paired interval [187,157,749.5, 218,683,680]; repeatable credit 198,275,718.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused first-letter/geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  No-wrap soft-line segmentation `d1165164` (independent committed slice)
  pass 1,362 common assertions in 15 cases per configuration,
  plus 2 original candidate cases/1,046 assertions both GC.
  Complete fresh no-wrap chunk batches use 2.20% fewer instructions.
  Page point saving 7,103,056, 24/30 wins,
  paired interval [7,734,401.5, 25,628,850]; repeatable credit 7,103,056.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused no-wrap/geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Prepared DOM mirror reuse `57c0ace3` (independent committed slice)
  pass 18,323 common assertions in 15 cases per configuration,
  plus 3 original candidate cases/15,333 assertions both GC.
  Complete public document layout batches use 0.79% fewer instructions.
  Page point saving 24,761,143, 21/30 wins,
  paired interval [700,820, 20,786,409]; repeatable credit 24,761,143.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused prepared-mirror/geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Layout stabilization count cache `e91640ae` (independent committed slice)
  pass 18,323 common assertions in 15 cases per configuration,
  plus 2 original candidate cases/14 assertions both GC.
  Complete public clean-layout checks use 99.63% fewer instructions.
  Page point saving 6,739,185, 16/30 wins,
  paired interval [-5,299,778, 14,367,559]; repeatable credit 0.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused stabilization/geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Owned glyph vector transfer `172a526b` (independent committed slice)
  pass 184 common assertions in 7 cases per configuration,
  plus 3 original candidate cases/714 assertions both GC.
  Complete public cached-shape calls use 8.33% fewer instructions.
  Page point saving 3,504,193, 15/30 wins,
  paired interval [-7,026,766, 10,674,088.5]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained text/geometry viewport exact. Additional observed savings: 3,504,193.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Shared UA-only shadow selector cache `f53aea52` (independent committed slice)
  pass 15,387 common assertions in 19 cases per configuration,
  plus 8 original candidate cases/17,422 assertions both GC.
  Complete public shadow style computations use 99.06% fewer instructions.
  Page point saving -19,438,450.5, 14/30 wins,
  paired interval [-16,698,729.5, 9,769,998]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained text/geometry viewport exact. Additional observed savings: 3,504,193.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Interleaved font-key ring `7a4f5a48` (independent committed slice)
  passes 184 common assertions in 7 cases per configuration,
  plus 7 original candidate cases/4,397 Boehm/4,396 no-GC assertions.
  Complete public cached-shape calls use 7.13% fewer instructions.
  Page point saving 10,376,323.5, 19/30 wins,
  paired interval [-3,018,878, 18,820,187]; repeatable credit 0.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained text/geometry viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Bounded matching candidate buffers `a812c2b7` (independent committed slice)
  pass 15,387 common assertions in 19 cases per configuration,
  plus 3 original candidate cases/1,200 assertions in each GC mode.
  Complete public scoped matching calls use 12.63% fewer instructions.
  Page point saving 93,614,606, 30/30 wins,
  paired interval [79,075,063.5, 99,799,690]; repeatable credit 93,614,606.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Scanned cascade-entry chunks `8e1bb848` (independent committed slice)
  pass 1,107 common assertions in 9 cases per configuration,
  plus 12 candidate cases/392,972 assertions in each GC mode.
  Complete public author-cascade operations use 25.38% fewer instructions.
  Page point saving 27,433,352, 23/30 wins,
  paired interval [8,906,366.5, 38,217,787.5]; repeatable credit 27,433,352.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Shared style-value identity guard `d1978c4a` (independent committed slice)
  pass 2,510 common assertions in 16 cases per configuration,
  plus 6 candidate cases/2,343 assertions in each GC mode.
  Complete public property-invalidation batches use 10.60% fewer instructions.
  Page point saving -1,265,945, 16/30 wins,
  paired interval [-7,727,310, 9,666,451]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Fixed pseudo-class cache list `7bfd4306` (independent committed slice)
  pass 532 common assertions in 14 cases per configuration,
  plus 2 candidate cases/137 assertions in each GC mode.
  Complete public rule-cache builds use 0.08% fewer instructions.
  Page point saving -3,114,537.5, 16/30 wins,
  paired interval [-15,634,210, 19,344,679.5]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Lazy computed metadata maps `c3e9df79` (independent committed slice)
  pass 3,123 common assertions in 27 cases per configuration,
  plus 9 candidate cases/1,057 assertions in each GC mode.
  Complete public style computations use 0.87% fewer instructions.
  Page point saving 13,183,270.5, 24/30 wins,
  paired interval [38,310,223.5, 56,465,095]; repeatable credit 13,183,270.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Deferred computed layout snapshots round90 (`5dd943ad`) are locally rejected.
  All three C-O2 configurations pass 3,123 assertions in 27 common cases.
  Complete public style/materialization batches regress 2.11%; all three pairs
  are worse. The predeclared native gate exits 1 before launching any child.
  Six candidate-only cases remain unrun; no normal C audit or page result.
  Frozen89 remains control/broad baseline; page credit and observed carry stay 0.
  Root implementation and canonical/GUI browsers are preserved; Chrome open.
  Guarded font input refresh `790e3974` (independent committed slice)
  pass 5,231 common assertions in 51 cases per configuration,
  plus 11 candidate cases/8,104 assertions in each GC mode.
  Complete public font-change/style batches use 66.39% fewer instructions.
  Page point saving -9,109,847.5, 14/30 wins,
  paired interval [-24,432,443, 16,674,537]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Normal font-setting maps `ee49b287` (independent committed slice)
  pass 5,231 before and 5,219 candidate common assertions in 51 cases,
  plus 5 candidate cases/996 assertions in each GC mode.
  Complete public font-change/style batches use 0.67% fewer instructions.
  Page point saving -17,817,883, 16/30 wins,
  paired interval [-12,510,200, 19,075,781.5]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Internal normal font-setting maps `30094b69` (independent committed slice)
  pass 5,219 common assertions in 51 cases per configuration,
  plus 5 candidate cases/1,066 assertions in each GC mode.
  Complete public font-change/style batches use 0.64% fewer instructions.
  Page point saving 65,283,708.5, 21/30 wins,
  paired interval [7,210,623.5, 43,090,181.5]; repeatable credit 65,283,708.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Immutable inline-end snapshots `67dd3b64` (independent committed slice)
  pass 21,719 common assertions in 29 cases per configuration,
  plus 6 candidate cases/1,359 assertions in each GC mode.
  Complete public document-layout batches use 8.80% fewer instructions.
  Page point saving 26,377,765.5, 28/30 wins,
  paired interval [20,272,890.5, 29,370,545]; repeatable credit 26,377,765.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; contemporary Root excluded.
  Chrome parity remains open.
  Document-pass measurement chunk pooling round 95 (`0e1af050`) is locally rejected.
  The 29 common cases pass 21,719 before and 21,782 candidate assertions in
  each GC mode; 63 additional runtime invariant assertions explain the delta.
  Complete public layout batches increase median instructions 0.143%; 1/3 wins.
  The native gate exits 1 before launching any child; six contracts remain unrun.
  No normal C/page result; frozen 94 remains control and broad baseline.
  Page credit/carry 0; Root/canonical/GUI preserved; Chrome parity open.
  Private cold glyph-vector transfer `22bebff7` (independent committed slice)
  passes 37,736 common assertions in 5 cases per configuration,
  including all 4 original producer/ownership contracts. Cold public shaping
  batches use 2.22% fewer instructions.
  Page point saving 7,111,212, 17/30 wins,
  paired interval [-10,611,202, 28,051,677.5]; repeatable credit 0.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; rejected 95 excluded; canonical/GUI preserved; Root excluded.
  Chrome parity remains open.
  Valid empty inline caches `15c67b10` (independent committed slice)
  cover 7,242 functional assertions in 6 cases/configuration:
  5 original cases retained, corrected retention case 1,550 assertions;
  initial pointer-identity failures kept; separate constructor-skip contract bothGC.
  Complete mixed-empty public iterator batches use 68.74% fewer instructions.
  Page point saving 4,410,609.5, 13/30 wins,
  paired interval [-12,929,378.5, 10,891,495]; repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused retained viewport exact. Additional observed savings: 4,410,609.5.
  Same 4 GiB/placement; canonical/GUI preserved; Root excluded; Chrome parity open.
  Shared CSS gradient snapshots round 98 (`2cc0daac`) are locally rejected.
  The 30 common cases pass 21,737 assertions per configuration.
  Complete public layout batches increase median instructions 0.061%; 0/3 wins.
  The native gate exits 1 before launching any child; two contracts remain unrun.
  No normal C/page result; frozen 97 remains control, last broad batch is 96.
  Page credit 0; observed carry 4,410,609.5; Root/canonical/GUI preserved.
  Chrome parity remains open.
  Direct retained line-text emission `6ba23375` (independent committed slice)
  passes 21,719 common assertions in 28 functional cases/configuration,
  plus the byte-exact original append contract in both GC modes.
  Corrected complete public layout/display-list batches use 3.79% fewer
  instructions; pre-observation wait/checker failures remain preserved.
  Page point saving 25,604,193.5, 26/30 wins,
  paired interval [11,218,171.5, 45,875,052]; repeatable credit 25,604,193.5.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused retained viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement; canonical/GUI preserved; Root excluded; Chrome parity open.
  Immutable box-shadow payloads `2c208bc9` (independent committed slice)
  pass 22,107 common assertions in 29 functional cases/configuration.
  Two original contracts retained; only failed newer-source size bound repaired
  against exact frozen record. Initial checker/contract failures remain.
  Complete public layout/display-list batches use 7.63% fewer instructions.
  Page point saving 2,371,587, 19/30 wins,
  paired interval [-3,425,231.5, 20,221,579]; repeatable credit 0.
  Broad verification: deferred below the cumulative 5M gate;
  focused shadow viewport exact. Additional observed savings: 2,371,587.
  Same 4 GiB/placement; shared SSD cache parent; canonical/GUI preserved;
  Root excluded; Chrome parity open.
  Immutable rare paint payloads `811552fc` (independent committed slice)
  pass 22,107 common assertions in 29 functional cases/configuration,
  plus three byte-exact original contracts in both GC modes.
  Complete public layout/display-list batches use 28.89% fewer instructions.
  Page point saving 36,304,458, 20/30 wins,
  paired interval [975,500, 30,389,723]; repeatable credit 36,304,458.
  Broad verification: 87 selected cases both GC and 19 screenshots (16 exact);
  focused effect/mask viewport exact. Additional observed savings: 0.
  Same 4 GiB/placement and shared SSD cache parent; canonical/GUI preserved;
  Root excluded; Chrome parity open.
  Dependent style scopes `7a44b720` + `09791cde` are measured together.
  Seven common cases pass 52 assertions/configuration; 13 original candidate-only
  cases pass 170 assertions per GC. All 15 original bodies remain unchanged.
  Complete public class/style batches use 0.92% fewer instructions.
  Initial extractor/C-metadata audit failures remain; no passing unit/primary repeated.
  Page point saving 29,135,040, 26/30 wins;
  paired interval [15,045,962.5, 29,068,708], repeatable credit 29,135,040.
  Broad verification: 87 selected cases both GC; 19 comparisons (16 exact);
  focused deep/UA viewport exact; additional observed savings 0.
  Same 4 GiB, SSD and placement; frozen library loader proof retained.
  Root/canonical/GUI preserved. Individual component credit 0; Chrome parity open.
  Owned ASCII CSS UTF-8 destination `72ffc938` retains fresh constructors
  and clones terminated output; it is distinct from rejected10 borrowed input.
  27 common cases pass 169,184 assertions/configuration, including 5 new cases.
  Complete public CSS-value parse batches use 5.14% fewer instructions.
  Initial constructor-name C/profile extractors remain; only read-only repairs.
  Page point saving 174,458,989, 30/30 wins;
  paired interval [171,401,348.5, 187,162,697], repeatable credit 174,458,989.
  Broad verification: 87 selected cases both GC; 19 comparisons (16 exact);
  focused viewport exact; additional observed savings 0.
  Same 4 GiB, SSD, placement and frozen library loader proof; public decoder,
  encoding, filtering and arenas unchanged. Root/canonical/GUI preserved;
  Chrome parity remains open.
  Immutable image parameters `75966fb5` use an independently authenticated port.
  29 functional common cases pass 22,107 assertions/configuration; eight original
  contract bodies plus the sole failed-case setup repair pass both GC; all
  assertions remain. The baseline automatic-refresh failure is retained.
  Complete public image/layout/recording batches use 18.07% fewer instructions.
  Page point saving 7,558,950, 21/30 wins;
  paired interval [1,623,164, 23,311,872], repeatable credit 7,558,950.
  Broad verification: 87 selected cases both GC; 19 comparisons (16 exact);
  focused image/effect viewport exact; additional observed savings 0.
  Same 4 GiB, SSD, placement and frozen library loader proof; live scroll offsets,
  inline gradients, CSS decoding/filtering and GC unchanged. Root/canonical/GUI
  preserved. Absent SVG cull gate excluded; Chrome parity remains open.
  Dependent anonymous geometry `5dd943ad` + `67c853d6` + `32348332` is locally
  rejected in105; no old90 observation reused. 26 common functional cases pass
  3,123 assertions/configuration; 16 exact original contracts pass 30,272/GC.
  Complete mixed inline/block public layout+recording median increases 0.246%;
  1/3 wins. Both pre-native gates actually exit1; no normal/profile/page work.
  Page credit0; retain104 control/broad baseline and observed carry0.
  Completed artifact bytes remain in verified archives; no passing case repeated.
  Same4GiB; Root/canonical/GUI preserved; Chrome parity remains open.
  Full rendered-text grapheme cache `779b8408` uses five authored hunks/three paths.
  29 common functional cases pass 22,107 assertions/configuration; six contracts
  pass 25,011/GC. Five original bodies remain exact; one absent innerText setup
  call is omitted, all assertions retained. Initial compiler/gate exits1 archived.
  Complete public Unicode layout/recording batches use 2.02% fewer instructions.
  Page point saving 15,827,270, 25/30 wins;
  paired interval [5,067,656, 35,767,997.5], repeatable credit 15,827,270.
  Broad verification: 87 selected cases both GC; 19 screenshots/16 exact;
  focused Unicode/overflow viewport exact; observed carry 0.
  Segmentation, Unicode tables, substring context, 4 GiB and GC unchanged.
  Root/canonical/GUI preserved; Chrome parity remains open.
  Direct attribute visitor `4bf70518` uses three authored hunks in one CSS file.
  Ten common functional cases pass 852 assertions/configuration, including five
  exact original contracts. DOM, namespace and operator behavior remain covered.
  Complete public author-cascade batches use 2.28% fewer instructions.
  Page point saving 682,539.5, 15/30 wins;
  paired interval [-7,058,926.5, 9,791,488], repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused attribute viewport exact; observed carry 682,539.5.
  Same 4 GiB, SSD, placement, frozen helper and GC policy.
  Root/canonical/GUI preserved; Chrome parity remains open.
  Immutable general-selector borrowing `e289178a` uses two hunks/one CSS file;
  four new public contracts are committed with it. 12 common functional cases
  pass 1,418 assertions/configuration; contemporaneous Root passes 1,128/GC.
  Earlier parent/header boxing prototypes and all local observations retained.
  Complete public author-cascade batches use 3.36% fewer instructions.
  Page point saving 52,298,107, 30/30 wins;
  paired interval [45,029,424.5, 58,496,768], repeatable credit 52,298,107.
  Broad verification: 87 selected cases both GC; 19 screenshots/16 exact;
  focused general-selector viewport exact; observed carry 0.
  Same 4 GiB, SSD, placement, frozen helper and GC policy.
  Concurrent Root/canonical/GUI preserved; Chrome parity remains open.
  Direct DOM rendered-text collection `19f513dc` uses one authored bridge hunk
  and one exact new file. 28 common cases pass 21,835 assertions/configuration;
  five exact contracts pass 18,556/GC, including the restored 106 innerText call.
  Complete public Unicode layout/recording batches use 0.27% fewer instructions.
  Page point saving 175,782,410, 30/30 wins;
  paired interval [169,674,798.5, 189,042,702], repeatable credit 175,782,410.
  Broad verification: 87 selected cases both GC; 19 screenshots/16 exact;
  focused first-letter/whitespace viewport exact; observed carry 0.
  UTF-8 validated; malformed/grapheme fallback retains the unchanged iterator.
  Same 4 GiB, frozen helper, GC policy; Root/canonical/GUI preserved.
  Chrome parity remains open.
  Compact CSS selector payloads `201f3f90` use 60 authored hunks/eight paths;
  one cache hunk changes only indentation plus getters. SimpleSelector 496→176B.
  All 12 common cases pass 1,418 assertions/configuration; 11 exact contracts
  pass 825 Boehm/811 no-GC, including real weak-owner retention and release.
  Complete public parse/serialize/specificity/matching batches use 9.09% fewer instructions.
  Page point saving 102,009,370.5, 30/30 wins;
  paired interval [87,547,656, 107,348,072.5], repeatable credit 102,009,370.5.
  Broad verification: 87 selected cases both GC; 19 screenshots/16 exact;
  focused selector/Unicode viewport exact; observed carry 0.
  Same 4 GiB, frozen helper, GC policy; Root/canonical/GUI preserved.
  Chrome parity remains open.
  Borrowed short attribute ranges `45398f48` use one authored hunk/three helpers.
  All 12 common cases pass 1,418 assertions/configuration; two exact contracts
  pass 57,117/GC, including byte slices and ASCII-only case-fold behavior.
  Complete public parse/serialize/specificity/matching batches use 0.61% fewer instructions.
  Page point saving 4,867,127.5, 15/30 wins;
  paired interval [-9,093,655.5, 7,375,459.5], repeatable credit 0.
  Broad verification: deferred below cumulative 5M gate;
  focused attribute/Unicode viewport exact; observed carry 4,867,127.5.
  Diagnostic fixture-check failures retained; no completed samples repeated.
  Same 4 GiB, frozen helper, GC policy; Root/canonical/GUI preserved.
  Chrome parity remains open.
  DOM interactive-state round 112 (`722f9bcb`) is inapplicable to frozen 111:
  prerequisite `b487c142` supplies ElementRareData and its private mutable block.
  Before C-O2 passes 11 cases/60 assertions plus inactive; both candidates fail
  V checking before runtime. Ten contracts and fresh-document diagnostic unrun.
  All failures retained; no partial prerequisite repair, hardware samples or page credit.
  Frozen 111/control, 110/broad baseline, observed carry 4,867,127.5 preserved.
  Root/canonical/GUI preserved; Chrome parity open.
  Lazy element-map round 113 (`b487c142`) is locally rejected.
  All 12 common cases pass 69 assertions/configuration; 9 exact contracts bothGC
  pass DOM 87 Boehm/84 none plus CSS 952 each. Explicit mutable block retained.
  Fresh public parse/layout/record/finalize pipelines increase median instructions
  2.33%; 1/3 wins. All six samples/checksums/actual exits retained.
  Native gate exits 1 before normal/profile/page work; credit 0.
  Frozen 111/control, 110/broad baseline, observed carry 4,867,127.5 preserved.
  Root/canonical/GUI preserved; Chrome parity open.
  DOM state-family round 114 (`b487c142+722f9bcb`) fails an original ABI contract.
  Common 11 cases/60 assertions each; control batch safely reused from 112.
  Per GC: 18/19 exact candidate cases pass; allocation case expects 1960B Element,
  observes 2072B. Syntax-only audit identifies missing `ddfefde3` event storage,
  a 112B map/pointer gap; no size assertion changed. Weak-owner case passes.
  Fresh public pipelines use 0.77% fewer local instructions (16 batches),
  but contract failure blocks normal/profile/page work; credit 0; all samples retained.
  Frozen 111/control, 110/broad baseline, carry 4,867,127.5 preserved; Chrome parity open.
  Event-handler storage round 115 (`ddfefde3`) misses the local median gate.
  Common 12 cases/69 assertions each; before safely reused from 113.
  Focused composite: 56 exact cases per GC (DOM36/browser19/HTML1); all pass.
  Original HTML batches fail before cases: six separate embedder-API tests unavailable,
  receive zero credit. DOM singular-assert row authenticated; successful cases not rerun.
  Local 16 complete public pipelines: +0.094862% median instructions,
  2/3 wins; fixed samples retained. No normal/profile/page work; credit 0.
  Frozen 111/control, 110/broad baseline, carry 4,867,127.5 preserved; Chrome parity open.
  Complete DOM state round 116 (`ddfefde3+b487c142+722f9bcb`) passes its original ABI/owner checks.
  All 58 authored hunks/17 paths; common60/config; 23 exact candidate cases per GC.
  Local 16 complete public pipelines use 3.69% fewer instructions.
  Page 16,947,798,319.5 → 16,849,777,268; 30/30 wins.
  Saving/credit 98,021,051.5; paired interval [95,869,894, 116,306,577] positive.
  Broad 87 selected both GC/174 executions; 19 screenshots/16 exact; focused exact.
  Strict C/actual AST ownership audits pass; 60 real PNGs, no retries/recoveries/refreshes.
  Frozen116/control and broad baseline; observed carry resets to 0 after actual passes.
  Same 4 GiB/frozen helper/GC1+override2; isolated app; Root/canonical/GUI preserved.
  Failed standalone/reader/preparation receipts retained; Chrome parity remains open.
  Lazy cold style maps round 117 (`82ca20c6`) retain the pseudo map and defer three others.
  Root 7 cases: 112/106 asserts; common 60/config; 25 DOM18/CSS3/HTML4 contracts per GC pass.
  Local 16 complete public pipelines: -2.13%, 2/3 wins; all six samples retained.
  Page 16,795,334,683 → 16,781,463,328; 26/30 wins.
  Point saving 13,871,355; paired interval [10,826,526.5, 19,776,099]; credit 13,871,355.
  Broad: 87 both GC/174 executions, 19 screenshots/16 exact; focused viewport exact.
  Strict C/source/file-table audit; independent-only getters authenticated; 60 primaries retained.
  Next control 117; observed carry 0 after completed broad checks.
  Same 4 GiB/frozen helpers/GC1+override2; isolated app; Root/canonical/GUI preserved.
  Initial audit/preparation failures retained; Chrome parity remains open.
  Direct first-pseudo round 118 (`833ff5d3`) fails its local median gate.
  Root10 cases/150+143 asserts; common60/config;28 DOM21/CSS3/HTML4 contracts per GC pass.
  Local16 complete public pipelines: +0.097525%, 0/3 wins; all six retained.
  No normal/profile/C-audit/page/broad run; page credit0; original stale descriptions retained.
  Own revert `9a16b193` restores exact pre118 Root implementation/tests.
  Frozen117 control/broad baseline, carry0 and isolated117 app preserved; Chrome parity open.
  Computed-property inline round119 (`e51993f1`) fails its local median gate.
  Root2 cases/3289 asserts each: C-O2 bothGC and C-O0Boehm; frozen2/2931 perGC pass.
  Common60/config; local16 complete public pipelines +1.971223%, 1/3wins; all6 retained.
  No normal/profile/C-audit/page/broad run; page credit0; body/guard unchanged.
  Own revert `32525034` restores exact pre119 Root implementation/tests.
  Frozen117 control/broad baseline, carry0 and isolated117 app preserved; Chrome parity open.
  Parser raw-text round120 (`344144ba`) fails preflight: platform prerequisite absent.
  Before common117-final reused/60 asserts; candidate exits1 bothGC before any cases.
  No local/native/profile/C-audit/page/broad/app work or credit; failures retained.
  Full prerequisite `3f5d7e1e` changes native integration; no shim/partial port.
  Frozen117 control/broad baseline, carry0 and existing app/Root/canonical/GUI preserved.
  Hit-test capacity round 121 (`f0e55dc7`): two authored hunks/two layout paths.
  Common60/config; exact2 layout cases/20738asserts eachGC pass; phase/identity preserved.
  Local16 public pipelines -0.356946%/2wins; informational sign predeclared.
  Page 16,624,628,941 → 16,627,497,589; 15/30wins.
  Point saving -2,868,648; paired interval [-5,169,549, 4,928,997.5]; credit 0.
  Broad: deferred below5M gate; focused viewport exact.
  Strict C/source/filetable audit; all60 primaries retained; next control 117.
  Observed carry 0; same4GiB/frozenhelpers/GC1+override2.
  Isolated app; Root/canonical/GUI preserved; setup failures retained; Chrome parity open.
  Discarded indentation round 122 (`0ad51d75`): two authored hunks/two layout paths.
  Common60/config; exact3 layout/font cases/16971asserts eachGC pass; preserved text intact.
  Local16 public pipelines -1.319719%/2wins; all6 actual0 retained.
  Page 16,633,943,164.5 → 16,518,669,818.5; 30/30wins.
  Point saving 115,273,346; paired interval [110,306,565, 119,965,236]; credit 115,273,346.
  Broad: 87bothGC/174executions,19screens16exact; focused viewport exact.
  Strict C/source/filetable audit; all 60 primaries retained; next control 122.
  Observed carry 0; same4GiB/frozenhelpers/GC1+override2.
  Isolated app; Root/canonical/GUI preserved; ENOSPC receipts retained; Chrome parity open.
  Inline-piece scalar sorting round 123 (`7fab2d3a`) fails the Boehm ownership gate.
  Common60/config; original5 no-GC cases/360asserts pass; Boehm actual134/SIGABRT.
  First weak-owner mask1 retains document; next weak-link registration aborts; no weakened test.
  Local16 public pipelines +1.033810%/2wins; all6 samples/actual0 retained.
  No normal/profile/C-audit/page/broad work or page credit; Root feature remains untouched.
  Frozen122 control/broad baseline, carry0 and verified122 app preserved; Chrome parity open.
  Direct general grapheme round124 (`17270386` + `68fcaf57`): complete two-feature composition.
  Two final hunks/two runtime paths; all9 authored cases/2306314asserts eachGC pass.
  Common60/config; local16 public pipelines -0.900495%/3wins; all6 actual0 retained.
  Page 16,720,940,717.5 → 16,713,891,904; 20/30wins.
  Point saving 7,048,813.5; paired interval [389,718.5, 18,571,488.5]; credit 7,048,813.5.
  Broad: 87bothGC/174executions,19screens16exact; focused viewport exact.
  Strict C/source/filetable audit; static2094u32 table/no new GC roots; all60 primaries retained.
  Next control 124; observed carry 0.
  Same4GiB/frozenhelpers/GC1+override2; isolated app; Root/canonical/GUI preserved; Chrome open.
  Bounded cumulative offsets round125 (`b53d0b21`) fails the local median gate.
  One exact authored hunk; original3 cases/814asserts eachGC and common60/config pass.
  Local16 public pipelines +0.081623%/1wins; all6 actual0 retained.
  No normal/profile/C-audit/page/broad work or page credit; waiting audit stopped actual-15.
  Frozen124 control/broad baseline, carry0 and verified124 app preserved; Chrome parity open.
  Property-sharing closure round126:12 authored features/156hunks/18changed paths.
  C-only preflight actual1: required Document layout-readiness query remains private.
  Prepared69 original cases remain unexecuted; no native/runtime/local/profile/page work or credit.
  Duplicate replay/prelaunch failures retained; no visibility shim or omitted native hook.
  Frozen124 control/broad baseline, carry0 and verified124 app preserved; Chrome parity open.
  Property-sharing closure round127:15 authored features/167hunks/21changed paths.
  C-only preflight actual1: viewport-specific SVG document API is absent.
  Prepared76 original cases remain unexecuted; no native/runtime/local/profile/page work or credit.
  Complete SVG prerequisites required; no wrapper/shim or dropped call.
  Frozen124 control/broad baseline, carry0 and verified124 app preserved; Chrome parity open.
  Property-sharing closure round128:17 authored features/183hunks/23changed paths.
  C-only preflight0; common60/config and original2 DOM cases/19asserts eachGC pass.
  Other contract groups stop at compilation: scripting/cache APIs and legacy image-field accessors.
  Aggregate actual1; zero local samples/primaries/credit; all passes/failures retained.
  Frozen124 control/broad baseline, carry0 and verified124 app preserved; Chrome parity open.
  Property-sharing closure round129:20 authored features/206hunks/33changed paths.
  C-only preflight0; common60/config; original DOM2/19asserts eachGC pass.
  Layout33/34 eachGC fails viewport-scroll command; stronger probe1 bothGC, Root test restored.
  CSS41/42 Boehm fails document owner mask1; no-GC42/37943asserts passes; mask assertion intact.
  Main6 eachGC derived from actual0/quiet C runner; assertion totals unknown; HTML compile1.
  Aggregate1; zero local samples/primaries/credit; all outcomes and accessor proofs retained.
  Frozen124 control/broad baseline, carry0 and verified124 app preserved; Chrome parity open.
  Property-sharing closure round130:25 features/231authoredhunks/40changed runtime paths.
  C-only preflight0; common60/config; layout36/97315asserts and main7/57578 eachGC pass.
  HTML no-GC12/515 passes; Boehm10 passes, two owner-mask3 failures. DOM2/19 eachGC passes.
  CSS no-GC57/57997 passes; Boehm25 passes, six owner failures then actual134/SIGABRT.
  Local template missed contract gate: all6 samples retained, -13.72086%/3wins; no page credit.
  Future generator fixed; original drivers/results retained. Native gate1 starts zero normal jobs.
  Zero browser primaries/broad work; frozen124/control/broad/carry0/app preserved; Chrome open.
  Property-sharing closure round131:29 features/245authoredhunks/42changed runtime paths.
  C-only preflight0; common60/config; layout36/97315 and main7/57578 eachGC pass.
  CSS57/58010 Boehm and57/57997 none pass; paged-store/discarded-image owner masks0.
  DOM13 passes93/86 asserts. HTML none19/679 passes; Boehm18 passes, inline-style mask3 fails.
  Corrected local gate1 before builds/samples; native gate1 starts zero normal jobs.
  Zero browser primaries/broad work/credit; full582e160c collector prerequisite reviewed.
  Frozen124/control/broad/carry0/app and canonical/GUI preserved; Chrome parity open.
  Full property-sharing closure round132:30features/246hunks/42changed paths;133cases bothGC pass.
  Assertions213737/213707; common60/config; local16 full pipelines -14.14608%/3wins/all6actual0.
  Normal build/sign/smoke/profiles and entire-program independent C audit pass;120inputs/37includes.
  All60 real page runs/PNGs kept; raw16,732,830,539→16,731,188,629;14wins.
  Raw saving1,641,910; pairedCI[-2,910,368.5,12,256,702]; repeatablecredit0.
  Strict preparation rejects control1/2/1 vs candidate1/3/1; reader result1/actualexit0 retained.
  Pixel bands exact outside skeleton; focused viewport exact. No broad/bundle/GC pass or carry.
  Frozen124/control/broad/carry0/app and canonical/GUI preserved; isolate lifetime-only next; Chrome open.
  Callback-lifetime round133:10complete features/57authoredhunks/22runtimepaths/onehelper.
  All46 originalcases eachGC/20941Boehm/20914none;common60/config;weak-owner assertions unchanged.
  Local16 full pipelines -0.694940%/2wins;all6actual0,slower third candidate retained.
  Page 16,692,671,695→16,628,638,052;30/30wins;point/credit64,033,643.
  PairedCI[49,095,577,70,017,207.5];all60real0/PNGs;same1/2/1prep;fixed skeleton bands only.
  Broad87bothGC/174executions;19screens16exact;focused viewport exact;36actual4e loader proofs.
  Initial screenshot permission/validation/bundle failures retained;unfinished screenshots only resumed.
  Entire-program independent C/source audit;120inputs/37includes;profiles diagnostic only.
  Frozen133 control/broad/app;carry0;GC1+override2;Root/canonical/GUI preserved;Chrome parity open.
  Duplicate descendant invalidation round134 (`299be763`):two authoredhunks/oneDOMruntimepath.
  All3 originalcases/9asserts eachGC;common60/config;full public mutation pipeline -0.424320%/3wins.
  Page16,691,567,659→16,700,671,083;13/30wins;point-9,103,424.
  PairedCI[-17,031,595,4,418,269];repeatablecredit0;all60 primaries retained;same1/2/1prep.
  Broad:deferred below5M;focused viewport exact;strict entire-program C/source audit.
  Frozen133control;carry0;isolated app/GC1+override2;Root/canonical/GUI preserved;Chrome open.
  Absent block-margin round135 (`b994ddfa`):one exact hunk/one layout path;2cases/32asserts eachGC.
  Common60/config;normal C-only preflight0;local16full pipelines +1.561303%/1win/all6actual0.
  Local gate1/native launcher1;zero normal/profile/browser/broad/bundle work;no page credit.
  Frozen133 control/broad/app and carry0 retained;all completed observations preserved.
  Separate URL absent-entry feature ffceca4b+3focusedtests committed;7targetedcases/55asserts eachGC.
  Required-record budget and single-case reader corrections retain original failures;no ownership reruns.
  URL hardware/page result pending;canonical/GUI/foreign work preserved;Chrome parity open.
  Empty URL blob-entry round136 (`ffceca4b`):one authoredhunk/one URL path;3cases/25asserts eachGC.
  Common60/config;local16full pipelines -1.682884%/2wins/all6actual0 retained.
  Page16,636,990,294.5→16,619,034,452;18/30wins;point17,955,842.5.
  PairedCI[-7,745,377,12,856,654.5];repeatablecredit0;all60 retained;same1/2/1prep.
  Broad:87bothGC/174executions;19screens16exact;focused viewport exact;entire-program independent C audit.
  Frozen136control;carry0;isolated app/GC1+override2.
  Completed C compressed transparently with identical hashes;Root/canonical/GUI/foreign work preserved;Chrome open.
  Scroll-edge context round137 (`d318908d`):two authoredhunks/one layout path;3originalcases eachGC.
  Common60/config;local16full pipelines -0.440035%/2wins/all6actual0 retained.
  Page16,679,087,120→16,669,046,850.5;19/30wins;point10,040,269.5.
  PairedCI[-2,714,977.5,19,555,237];repeatablecredit0;all60 retained;same1/2/1prep.
  Broad:87bothGC/174executions;19screens16exact;focused viewport exact;entire-program independent C audit.
  Frozen137control;carry0;isolated app/GC1+override2.
  Separate iterative Node.root feature excluded;Root/canonical/GUI/foreign work preserved;Chrome open.
  Exact CSS integer round138 (`0f3a06e1`):three authoredhunks/one CSS function;4cases/98967asserts eachGC.
  Common60/config;local16full pipelines -1.939384%/2wins/all6actual0 retained.
  Page16,703,912,262.5→16,678,368,229.5;27/30wins;point25,544,033.
  PairedCI[13,083,661,43,926,162];repeatablecredit25,544,033;all60 retained;same1/2/1prep.
  Broad:87bothGC/174executions;19screens16exact;focused viewport exact;entire-program independent C audit.
  Only number-consumer C body changes;shifted assertion metadata authenticated;original reader1 retained.
  Frozen138control;carry0;isolated app/GC1+override2.
  Separate exact-fraction feature excluded;Root/canonical/GUI/foreign work preserved;Chrome open.
  Exact CSS fraction round139 (`cbfb7f11`):all5 Git hunks/one whole-function region;4cases/38736asserts eachGC.
  Common60/config;normal C-only frontend0;predeclared CSS-rich local16full pipelines +3.308673%/1win/all6actual0.
  Local gate1/native launcher1;zero normal/profile/page/broad/bundle work;accepted138/carry0 retained.
  Source-context and page-draft findings preserved;entire authored feature authenticated without projections.
  Separate identifier prefix feature86c7786c committed;20focusedcases/263510asserts eachGC composite.
  Original constructor-fixture batch1 retained;two passing cases reused plus18remaining cases actual0;no case repeat.
  Identifier hardware/page result pending;canonical/GUI/foreign work preserved;Chrome parity open.
  Identifier prefix round140 (`86c7786c`):one authored hunk/one CSS function;4cases/63165asserts eachGC.
  Common60/config;local16 full pipelines -1.853183%/2wins/all6 actual0 retained.
  Fresh page 16,643,508,973→16,605,545,345.5;29/30wins;point 37,963,627.5.
  PairedCI[20,652,239.5,56,405,530.5];repeatable credit 37,963,627.5;all60 primaries retained;same1/2/1 preparation.
  Focused viewport exact;broad passed;strict entire-program/source/native-input C audit.
  Accepted control 140;isolated140 app/GC1+override2;canonical/GUI/foreign work preserved.
  Separate escape accumulator cf0f012b committed;8cases/240143asserts eachGC;no hardware credit yet.
  Separate absent Size payload 818fe747 committed;3cases/2151asserts eachGC;excluded from140/page credit.
  Original reader/setup failures retained without runtime repeats;Chrome parity remains open.
  Hex escape round141 (`cf0f012b`):two authored Git hunks/one CSS function;4cases/202468asserts eachGC.
  Common60/config;declared512-rule escape scene/local16 full pipelines -0.271767%/2wins/all6 actual0.
  Fresh page 16,618,382,670.5→16,614,190,283;19/30wins;point 4,192,387.5.
  PairedCI[-9,156,015.5,14,238,649];repeatable credit 0;all60 primaries retained;same1/2/1 preparation.
  Focused viewport exact;broad skipped below 5,000,000-instruction threshold;strict entire-program/source/native-input C audit.
  Accepted control 141;isolated141 app/GC1+override2;canonical/GUI/foreign work preserved.
  Separate Size818fe747/3cases/2151asserts eachGC;old allocation driver1 retained;no hardware credit yet.
  Root setup failure retained without runtime repeats;Chrome parity remains open.
  Absent Size round142 (`818fe747`):one authored Git hunk/one record;3cases/2151asserts eachGC.
  Common60/config;canonical small scene/local16 full pipelines -1.431222%/2wins/all6 actual0.
  Fresh page 16,611,123,638→16,584,057,241.5;17/30wins;point 27,066,396.5.
  PairedCI[-5,745,182,12,590,968];repeatable credit 0;all60 retained;same1/2/1 preparation.
  Focused viewport exact;broad passed;prior carry4192387.5 included in gate.
  Accepted control 142;isolated142 app/GC1+override2;strict full independent C and exact16default-owner proof.
  Reader failures retained;no successful runtime repeats;canonical/GUI/foreign work preserved;Chrome parity open.
  Retained length round143 (`6c2c56d9`):one authored Git hunk/one function;7cases/1650asserts eachGC.
  CurrentV Root:four new cases/536asserts eachGC;old fullRoot C-closure failures retained separately.
  Common60/config;canonical small scene/local16 full pipelines -1.807659%/2wins/all6 actual0.
  Fresh page 16,721,401,895→16,724,246,003;15/30wins;point -2,844,108.
  PairedCI[-32,009,294.5,36,665,142];repeatable credit 0;all60 retained;same1/2/1 preparation.
  Focused viewport exact;broad skipped below 5,000,000-instruction threshold;prior carry0;strict entire-program independent C audit.
  Accepted control 142;isolated143 app/GC1+override2;canonical/GUI/foreign work preserved;Chrome open.
  Larger shape-index round144 (`c85909ed`):all4 runtime Git hunks/3paths;6cases/8430asserts eachGC.
  Common60/config;normal C-only frontend0;sealed44-word prose/public16 pipelines +0.514165%/1win/all6actual0.
  Local gate1/native launcher1/jobs0;zero normal/profile/page/broad/bundle work;accepted142/carry0 retained.
  Original namespace-reader and supplementary current-Root build failures retained;no shim or invented exits.
  Separate one-observation startup attribution actual0;full C restores byteexact;zero page credit.
  Canonical/GUI/foreign work preserved;Chrome parity remains open.
  Entity prefix round145 (`83acd036`):all3authored Git hunks/two whole HTML files;2cases/1301172asserts eachGC.
  Common60/config;cold local one complete public pipeline -1.002256%/3wins/all6actual0;outside-page startup included.
  Fresh page 16,470,624,891→16,505,507,967.5;5/30wins;point -34,883,076.5.
  PairedCI[-56,336,914.5,-36,722,833];repeatable credit 0;all60 retained;same1/2/1 preparation.
  Focused viewport exact;broad skipped below 5,000,000-instruction threshold;prior carry0;strict independent entire-program C audit.
  Accepted control 142;isolated145app/GC1+override2;canonical/GUI/foreign work preserved.
  Original profile hypothesis/dependent preprimary reader failures retained;read-only recovery0/no profile replay.
  Separate spacing6c498aec(3cases/1869eachGC) and zero-indent1f3ab03a(3cases/3753eachGC) committed;zero hardware credit yet.
  Supplementary current-V shape fixture interrupted143after2cases eachGC;no whole-batch pass;Chrome remains open.
  Spacing context round146 (`6c498aec`):all2authored Git hunks/one runtimepath;3cases/1869asserts eachGC reused exactly.
  Common60/config;normal C-only frontend0;unchanged canonical local16 pipelines +0.361193%/1win/all6actual0.
  Local gate1/native launcher1/jobs0;no normal binary/profile/page/broad/bundle;accepted142/carry0 retained.
  Separate one-observation full-browser profile142 after145:actual native/observer/browser0;7176raw call-count rows.
  Original unused-parser-wrapper expectation1 retained;counter-authenticated read-only correction0/no observation replay.
  Profile counts/timings/instrumented instructions earn0 page credit;zero-indent1f3ab03a measurement pending;Chrome remains open.
  Absolute zero-indent round147 (`1f3ab03a`):one authored Git hunk/whole constructor;3cases/3753asserts eachGC reused exactly.
  Common60/config;unchanged canonical local16 pipelines -2.395104%/3wins/all6actual0.
  Fresh page 16,458,024,756.5→16,430,923,346.5;24/30wins;point 27,101,410.
  PairedCI[11,843,791.5,34,654,931.5];repeatable credit 27,101,410;all60 retained;same1/2/1 preparation.
  Focused viewport exact;broad passed;prior carry0;strict independent entire-program C audit.
  Accepted control 147;isolated147app/GC1+override2;canonical/GUI/foreign work preserved.
  Profiles actual0:constructor4992each,context15106→10114,fontmetrics119860→114868;no profile credit.
  Original logical-axis/template-metadata findings retained;Chrome parity remains open.
  Context-independent size round148 (`7d16089e`):one authored Git hunk/whole function;3cases/1301asserts eachGC reused exactly.
  Common60/config;normal C-only frontend0;unchanged canonical local16 pipelines +0.127951%/1win/all6actual0.
  Local gate1/native launcher1/jobs0;no normal binary/profile/page/broad/bundle;accepted147/carry0 retained.
  Exact payload/rounding/box-sizing contracts retained;original zero-case fixture typing failures preserved.
  PrivateRAM prepared only for unstarted compilers;local variants/cache/evidence remain SSD;Chrome parity open.
  Inline property lookup round149 (`bcc4c557`):one original attribute hunk/body unchanged;2cases/2493asserts eachGC reused exactly.
  Common60/config;normal C-only frontend0;unchanged canonical local16 pipelines +1.780721%/2wins/all6actual0.
  Local gate1/native launcher1/jobs0;no normal binary/profile/page/broad/bundle;accepted147/carry0 retained.
  Read-only C definition confirms inline keyword only;no strict audit or profile pass. Both improving pairs/slower third retained.
  Matched RAM local scratch;durable C/actual exits and metadata errata retained;canonical/GUI/foreign work preserved;Chrome open.
  Retained length owner round150 (`9c2ff112`):one original Git hunk/whole getter;3cases/763asserts eachGC composed without replay.
  Original640assert case/driver1 retained;unfinished2cases123asserts/driver0 each;no fabricated whole-driver0. Common60/config.
  Declared public262144length-read local batch -7.679009%/3wins/all6actual0;zero local pagecredit.
  Fresh page 16,611,067,127.5→16,606,936,405;17/30wins;point 4,130,722.5.
  PairedCI[-5,939,354,9,976,399.5];repeatable credit 0;all60 retained;same1/2/1 preparation.
  Focused exact;broad skipped below 5,000,000-instruction threshold;prior carry0;strict entire-program C permits only getter body/source assertion offsets.
  Accepted control 150;isolated150app/GC1+override2;canonical/GUI/foreign work preserved.
  Profiles getter2359552each/helper2359552→authenticated0;no profile credit. Original audit/dependent failures retained;native argv resumed honestly.
  RAM compiler/SSD durable evidence declared;Chrome parity remains open.
  Nearest style walk round151 (`7cb580db`):one original Git hunk/whole function;3cases/791asserts eachGC reused exactly.
  Common60/config;normal C-only frontend0;unchanged canonical local16 pipelines +0.082512%/1wins/all6actual0.
  Local gate1/native launcher1/jobs0;no normal binary/profile/page/broad/bundle;accepted150/carry4130722.5 retained.
  Whole source/fixture authenticated;explicit loop preserves nearest owner and live tree reads;no strict C/profile pass.
  Original zero-case fixture typing failures retained;matched RAM scratch/durable actual evidence;canonical/GUI/foreign work preserved;Chrome open.
  Tokenizer buffer reuse round152 (`72042b98`):all18original runtime Git hunks/entire exact file;6cases/958asserts eachGC reused exactly.
  Two feature/four ASCII legacy cases;only duplicate module/import headers consolidated. Common60/config;normal C-only frontend0.
  Canonical local16 complete public pipelines +2.040550%/0wins/all6actual0.
  Local gate1/native launcher1/jobs0;no normal/profile/page/broad/bundle;accepted150/carry4130722.5 retained.
  Allocation bounds pass but no hardware saving;all observations kept. Strict independent C audit never starts.
  Missing marker prerequisite/draft label findings retained;matched RAM scratch/durable evidence;canonical/GUI/foreign work preserved;Chrome open.
  Fused ASCII token runes round153 (`8c18c440`+72042b98):all19runtime Git hunks/twostages/oneHTMLpath;9cases/3105asserts eachGC reused.
  Three new/six exact prerequisite+ASCII cases;only duplicate headers consolidated. Common60/config.
  Declared4096full public-tokenizer API batch -5.835950%/3wins/all6actual0;zero local pagecredit.
  Fresh page 16,644,748,217→16,618,105,061.5;24/30wins;point 26,643,155.5.
  PairedCI[16,382,423.5,32,691,527];repeatable credit 26,643,155.5;all60 retained;same1/2/1 preparation.
  Focused exact;broad passed;prior carry4130722.5;strict six-body/whole-program independent C audit.
  Accepted control 153;isolated153app/GC1+override2;canonical/GUI/foreign work preserved.
  Full profiles actual0;no call-count credit. Original scratch-path1/empty launcher/resume and reuse-prose errata retained;Chrome open.
  Fixed rune input bounds round154 (`72883d4a`):onecompletefunction/oneoriginalGit hunk/oneHTMLpath;11cases/9426asserts eachGC reused.
  Two new/nine exact prerequisite+ASCII cases;only duplicate headers consolidated. Common60/config.
  Declared4096full public-tokenizer API batch -1.616283%/3wins/all6actual0;zero local pagecredit.
  Fresh page 16,597,304,573→16,600,902,722.5;14/30wins;point -3,598,149.5.
  PairedCI[-9,987,167,8,657,818];repeatable credit 0;all60 retained;same1/2/1 preparation.
  Focused exact;broad skipped below 5,000,000-instruction threshold;prior carry0;strict one-body/whole-program independent C audit.
  Accepted control 153;isolated154app/GC1+override2;canonical/GUI/foreign work preserved.
  Full profiles actual0;no call-count credit. Actual/reported bootstrapseed154;capture guard preserves completed pages;Chrome open.
  Guarded replaced constraints round155 (`de867d73`):onewholefunction/oneGit hunk/oneLayoutpath.
  C-O2 logical6case composite/30973asserts eachGC;3new+3exactSVG-replaced. Originaldriver1/fivepasses retained;onlyfailedcase repairedactual0.
  Singlecaseparser1/committer1 retained;read-onlyevidencerecovery0;no completedcase repeated. Common60/config;C-onlyfrontend0.
  Canonical local16 complete public pipelines +2.081194%/1wins/all6actual0;allobservations retained.
  Localgate1/nativelauncher1/jobs0/pagerelease1;no normal/profile/page/broad/bundle;accepted153/broad153/carry0 retained.
  MatchedRAM/durableactualarchives;canonical/GUI/foreignpreserved;Chrome open.
  All-frozen flex return round156 (`286e6940`):onewholefunction/all3originalGit hunks/oneLayoutpath.
  Sixexactcases/16357asserts eachGC/actual0;3new+3unchangedsolvercases;completedchecks reused. Common60/config;C-onlyfrontend0.
  Predeclared32panels/eightvariants/16completepublicpipelines/96setupgeometrychecks;5initiallyfrozen+3iterative variants.
  Threefixedlocalpairs +0.071279%/1wins/all6actual0;allobservations retained.
  Localgate1/nativelauncher1/jobs0/pagerelease1;no normal/profile/page/broad/bundle;accepted153/broad153/carry0 retained.
  Originalreuse/frontendprose labels retainedwithhash-authenticatederrata. MatchedRAM/durableevidence;canonical/GUI/foreignpreserved;Chrome open.
  Retained flow composition round157 (14wholefeatures/98originalruntimehunks/17paths/5newfiles;19metadatahunks already accepted).
  All60focusedcases/55265asserts eachGC;59original+geometryguard;accepted104test-only image views;common60/config.
  Declared16fullpublicpipelines/twoquerycontainers/128stableparagraphs:local -8.177461%/3wins/all6actual0;zero pagecredit.
  All30pairs/60actual0/60PNGs retained;raw point 155,796,301.5/29wins/rawCI[143,345,378,158,326,524.5];seed157/30000bootstrap.
  Strict preparation1:control1/2/1,candidate1/3/1;unaccepted/credit0/matchingobservedcarry0. No relaxed counts or reruns.
  Focusedviewport exact;no broad/bundle/GC157 pass;acceptedcontrol/broad/app153 preserved.
  Full profiles/strict entire-program C actual0;reservedvariable/parser and inventorypath failures retained;canonical/GUI/foreign preserved;Chrome open.
  First intrinsic height slot round158 (`bc1c1c69`):all4originalruntimehunks/twoLayoutpaths;5unchangedoriginalcases/14986asserts eachGC reused.
  Common60/config;declared canonical147scene/16fullpublicpipelines/192textchecks:local -4.113248%/2wins/all6actual0;zero pagecredit.
  Fresh page 16,360,893,532.5→16,350,090,559;28/30wins;point 10,802,973.5.
  PairedCI[8,777,041,12,397,119];repeatable credit 10,802,973.5;all60retained;same1/2/1preparation;seed158/30000bootstrap.
  Focused exact;broad passed;prior carry0;strict independent entire-program C/all4authoredhunks.
  Accepted control 158;isolated158app/GC1+override2;canonical/GUI/foreign preserved;fullprofiles actual0/no callcountcredit;Chrome open.
  Lazy layout indexes round159 (`513b998e`):all5originalruntimehunks/twoLayoutpaths;5unchangedoriginalcases/14994asserts eachGC reused.
  Common60/config;normal C-onlyfrontend0;declared canonical147scene/16fullpublicpipelines/192textchecks.
  Threefixedlocalpairs +0.183824%/0wins/all6actual0;allobservations retained;zero pagecredit.
  Localgate1/native-release1/no native-start/jobs0;no normal/profile/independentC/page/broad/bundle/GC159 pass.
  Acceptedcontrol/broad/app158/carry0 preserved;original predicate1 and archiveprose erratum retained;canonical/GUI/foreign preserved;Chrome open.
  Bucketed CSS lookup round160 (`1d746ab4`):all2runtimehunks/twoCSSpaths+sevenoriginaltoolinghunks/all6featurefiles.
  ThreeexactVcases/5269asserts eachconfiguration;869keywords/440properties;common60/config;C-onlyfrontend0;fullmapping generatoraudit actual0.
  Original3Pythonpasses reported/individualexitunknown;originalbadreceipt and audit-syntax1 retained;no successful case repeated.
  Declared canonical147scene/16fullpublicpipelines/192textchecks:local +3.835884%/1wins/all6actual0;zero pagecredit.
  Localgate1/native-release1/no native-start/jobs0;no normal/profile/independentC/page/broad/bundle/GC160 pass.
  Readonly keyword C1→333optionaltemps is diagnostic only;acceptedcontrol/broad/app158/carry0 and canonical/GUI/foreign preserved;Chrome open.
- Outside instruction-count optimization, run broad regression suites once per
  ten completed fixes, not after every fix.
  Broad suites include full translation/package test batches, the full LibJS AST
  corpus, the default screenshot smoke set, and broad SVG regression batches.
  Between batches, select only the cases directly relevant to the change.
- Outside instruction-count optimization, record each completed fix after the
  latest broad-test baseline in its audit entry so the next broad run happens at
  ten fixes. Its latest broad unit-test baseline is aa6f0246: 47 cases in 14
  selected files passed in both GC
  modes before this cadence was requested. Start the next ten-fix batch after
  that commit; do not repeat its completed broad tests.

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
