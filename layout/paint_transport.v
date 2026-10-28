module layout

import css
import dom
import html
import math
import painting
import platform
import strings

// The paint tree transport. The typed layout pipeline (Document::update_layout and the translated
// formatting contexts) publishes its used geometry and resolved paint style into `BlockBox`
// records, which the browser shell and the painting bridge consume: `BlockBox.paint_order()`
// flattens the tree into z-index paint order, `paint_commands()` builds the display list from it,
// and hit testing and element geometry queries read the same records. This transport has no
// upstream counterpart; upstream paints its PaintableBox tree directly.

// The used thickness of a box's four edges (margin / padding / border), in CSS px.
pub struct BoxEdges {
pub:
	top    f64
	right  f64
	bottom f64
	left   f64
}

pub struct BoxColors {
pub:
	top    css.Color
	right  css.Color
	bottom css.Color
	left   css.Color
}

pub struct CornerRadius {
pub:
	x f64
	y f64
}

pub struct BoxRadii {
pub:
	top_left     CornerRadius
	top_right    CornerRadius
	bottom_right CornerRadius
	bottom_left  CornerRadius
}

pub struct BackgroundImageLayer {
pub:
	url                string
	svg_document       ?&dom.Document
	static_svg_resource ?&StaticSVGBackgroundResource
	intrinsic_width    f64
	intrinsic_height   f64
	gradient_source    ?css.StyleValue
	gradient_context   css.ColorResolutionContext
	repeat_x           string
	repeat_y           string
	size               string
	position_x         string
	position_y         string
	origin             string
	clip               string
	attachment         string
	computed_layer     ?css.BackgroundLayerData
	resolution_context css.LengthResolutionContext
	layout_coordinate_scale f64 = 1
	color_scheme       css.PreferredColorScheme = .auto_
}

// The state consumed by Painting::PaintableBox::paint(PaintPhase::Overlay).
// Geometry is in document CSS pixels, matching absolute_padding_box_rect() and
// scrollable_overflow_rect() in the upstream paintable.
pub struct CompatibilityOverlayData {
pub:
	scrollable_overflow      LayoutRect
	scroll_offset_x          f64
	scroll_offset_y          f64
	can_scroll_horizontally  bool
	can_scroll_vertically    bool
	scrollbar_width          css.ScrollbarWidth
	scrollbar_thumb_color    css.Color
	scrollbar_track_color    css.Color
	default_scrollbar_colors bool = true
	has_resizer              bool
	chrome_mirrored          bool
}

// Overflow clipping is part of the accumulated visual context for descendants,
// while the box's own background, border, outline, and overlay stay outside it.
// This is the renderer-facing form of ViewportPaintable::compute_clip_data().
pub struct CompatibilityOverflowClip {
pub:
	rect         LayoutRect
	corner_radii BoxRadii
}

pub struct BoxBorderStyles {
pub:
	top    painting.LineStyle = .solid
	right  painting.LineStyle = .solid
	bottom painting.LineStyle = .solid
	left   painting.LineStyle = .solid
}

// Painting::Paintable::SelectionStyle, retained on each typed text fragment so
// repaint can build the source-ordered render spans without re-entering style
// computation. The boolean flags preserve Optional<T> exactly: an explicitly
// empty text-shadow suppresses the fragment's ordinary shadows.
pub struct TextSelectionStyle {
pub:
	background_color css.Color
	text_color       css.Color
	text_color_set   bool
	text_shadows     []BoxShadow
	text_shadows_set bool
	decoration       string = 'none'
	decoration_color css.Color
	decoration_style string = 'solid'
	decoration_set   bool
}

fn solid_box_border_styles() BoxBorderStyles {
	return BoxBorderStyles{}
}

// A laid-out inline fragment: one word positioned within a line, with its own box, text, and color
// (for selection, hit-testing, inline backgrounds, and painting).
pub struct TextFragment {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
pub:
	text           string
	color          css.Color
	font_size      f64 = 16.0
	bold           bool
	italic         bool
	mono           bool
	font_smoothing css.FontSmoothing
	// Words from the same DOM text node can be shaped and painted as one run when CSS uses natural
	// letter/word spacing, so the renderer uses the font's glyph advances across the whole run.
	text_run_id           i64
	shape_as_run          bool
	separator_after       string
	separator_width_after f64
	preserves_spaces      bool
	rtl                   bool
	// Paint style of the inline element that generated this word. Words with the same non-zero node
	// id are joined into one inline box on each line before their text is painted.
	inline_node_id           i64
	// The inline box's decorations come from its line piece in the line's
	// box_decorations instead of the words it directly parents.
	decorations_from_piece   bool
	fragment_left_edge_away  bool
	fragment_right_edge_away bool
	background_color         css.Color
	background_images        []BackgroundImageLayer
	border                   BoxEdges
	padding                  BoxEdges
	border_color             css.Color
	border_colors            BoxColors
	border_styles            BoxBorderStyles = solid_box_border_styles()
	border_radius            f64
	border_radii             BoxRadii
	outline_width            f64
	outline_offset           f64
	outline_color            css.Color
	outline_style            painting.LineStyle = .none
	outline_is_auto          bool
	shadow                   ?BoxShadow
	shadows                  []BoxShadow
	// The resolved text-decoration covering this word.
	decoration           string = 'none'
	decoration_color     css.Color
	decoration_color_set bool
	decoration_skip_ink  bool = true
	decoration_style     string = 'solid'
	decoration_thickness f64
	// PaintableFragment retains the line builder's baseline rather than
	// reconstructing it from an assumed 0.8em ascent at paint time.
	baseline                 f64
	baseline_set             bool
	paint_line_top           ?f64
	font_metrics_set         bool
	font_ascent              f64
	font_descent             f64
	font_x_height            f64
	glyph_height             f64
	decoration_thickness_set bool
	text_underline_offset    f64
	text_underline_position  string = 'auto'
	// Chromium-policy documents snap decorations with Blink's geometry, which
	// distinguishes an automatic text-underline-offset from an explicit length.
	chromium_decorations       bool
	text_underline_offset_auto bool
	// PaintableFragment retains the source layout node, offsets, and glyph run.
	// These are live paint inputs: selection state/range can change without a
	// relayout, while the shaped glyph advances remain owned by the line box.
	layout_handle      voidptr = unsafe { nil }
	paintable_fragment painting.PaintableFragment
	text_shadows       []BoxShadow
	selection_style    TextSelectionStyle
}

// A laid-out line box within a block's inline formatting context: `x`/`y` is the top-left of the
// line's content in CSS px, `width` the used width of the content on the line (after wrapping), and
// `height` the line-height. `x` reflects `text-align` within the content box. `fragments` are the
// individual words placed in the line's physical inline direction.
pub struct TextLine {
pub mut:
	x         f64
	y         f64
	width     f64
	height    f64
	fragments []TextFragment
	// Chromium-policy inline box decorations painted from whole line pieces,
	// outermost box first.
	box_decorations []TextFragment
}

// A laid-out block box: `x`/`y`/`width`/`height` are the *content box* geometry in CSS px, relative
// to the top-left of the initial containing block; `margin`/`border`/`padding` surround it.
//
// `outer_top_margin`/`outer_bottom_margin` are the *collapsed* margins at the box's top/bottom edges:
// they equal `margin.top`/`margin.bottom` unless a first/last child's adjoining margin collapsed
// through the box (parent/child collapsing), in which case they may be larger. The parent uses them
// to collapse this box's margins against its siblings.
//
// `lines` are the inline line boxes of a text-bearing block (empty for a block with block children).
struct StaticPosition {
	x                         f64
	y                         f64
	width                     f64
	height                    f64
	horizontal_alignment      StaticPositionAlignment = .start
	vertical_alignment        StaticPositionAlignment = .start
	has_containing_block_rect bool
	containing_block_x        f64
	containing_block_y        f64
	containing_block_width    f64
	containing_block_height   f64
}

// Optional geometry is immutable after publication. Keep its storage only on
// boxes that use it, and share that snapshot when a paint tree is copied.
fn retained_box_paint_payload[T](value ?T) ?&T {
	snapshot := value or { return none }
	return &snapshot
}

pub struct BlockBox {
pub:
	tag_name string
pub mut:
	// Blink paints a box's background and clips its background images to the
	// pixel-snapped border box; Chromium-policy documents do the same.
	snaps_background_rect bool
	x                   f64
	y                   f64
	width               f64
	height              f64
	margin              BoxEdges
	border              BoxEdges
	padding             BoxEdges
	outer_top_margin    f64
	outer_bottom_margin f64
	// The z-index used for paint ordering among siblings: the integer `z-index` of a positioned box,
	// else 0 (`auto` and non-positioned boxes don't reorder).
	z_index               int
	z_index_auto          bool = true
	positioned            bool
	floating              bool
	absolutely_positioned bool
	inline_or_replaced    bool
	atomic_in_flow        bool
	stacking_context      bool
	paintable_with_lines  bool
	// Retained table paint metadata from PaintableBox. Collapsed cells do not
	// paint ordinary borders; their winning edges are emitted by the table in
	// the dedicated TableCollapsedBorder phase.
	table_inside           bool
	table_cell             bool
	uses_collapsed_borders bool
	table_cell_coordinates ?&painting.TableCellCoordinates
	table_cell_borders     ?&painting.BordersDataWithElementKind
	empty_cells_hide       bool
	has_layout_children    bool
	// The computed background-color, text color, and border color, used to build the display list.
	background_color css.Color
	background_srgb_color &PaintSRGBColor = unsafe { nil }
	text_color       css.Color
	border_color     css.Color
	border_colors    BoxColors
	border_styles    BoxBorderStyles = solid_box_border_styles()
	// Outline color and line style remain common; optional geometry lives in decorations().
	outline_color  css.Color
	outline_style  painting.LineStyle = .solid
	outline_is_auto bool
	replaced_image_rendering  css.ImageRendering
	form_control_color_scheme  css.PreferredColorScheme
	form_control_accent_color  ?css.Color
	form_control_accent_is_auto bool
	skip_background_paint    bool
	// `opacity` is this box's own opacity (0..1) in the tree; in a paint-order entry it holds the
	// cumulative opacity (this box's times its ancestors').
	opacity        f64 = 1.0
	// Non-perspective 3D transforms retain an isolated surface in Chromium.
	chromium_compositor_surface bool
	mix_blend_mode painting.CompositingAndBlendingOperator
	// Whether this box paints its own background/border/text (`visibility: visible`). A
	// `visibility: hidden` box still takes up space but is not painted; because `visibility` inherits,
	// each box carries its own resolved value, so a visible descendant of a hidden box still paints.
	visible bool = true
	// Paintable::visible_for_hit_testing() additionally excludes pointer-events:none.
	pointer_events_enabled bool = true
	// The `unique_id` of the element this box was laid out for, so a box can be found from its element
	// (backing getBoundingClientRect).
	node_id                       i64
	hit_test_continuation_node_id i64
	// Identity of the typed Layout::Node which created this paintable. DOM keeps
	// the same opaque handle on its module-cycle wrapper, allowing repaint
	// invalidation to address the corresponding retained phase cache directly.
	layout_handle voidptr = unsafe { nil }
	children      []BlockBox
	lines         []TextLine
	// Immutable SVG state is absent on ordinary HTML boxes. Its path payload is
	// shared directly with retained commands and earlier paint snapshots.
	svg_data &BlockBoxSVGData = unsafe { nil }
	// MarkerPaintable transport for the predefined counter styles which
	// LibWeb intentionally renders as a geometric image instead of text.
	marker_shape string
	// Scrollbars and the CSS resize handle paint after the outline in the
	// overlay phase. None means this box has neither kind of overlay.
	overlay ?&CompatibilityOverlayData
	// A scroll frame exists only when layout measured overflow beyond the
	// scrollport, except that the root transport box also carries the viewport's
	// mandatory scroll frame. Clipping also exists for overflow:clip without a
	// scroll frame.
	has_scrollable_overflow bool
	scrollable_overflow     ?LayoutRect
	overflow_clip           ?&CompatibilityOverflowClip
	writing_mode      css.WritingMode
	direction         css.Direction
	sticky_position      bool
	is_viewport_scroller bool

	// The element-local transform is retained separately so the accumulated
	// visual-context tree can interleave transforms, clips, and scroll frames in
	// source order. `paint_transform` remains the old cumulative compatibility
	// value for callers which construct BlockBox trees directly.
	own_paint_transform [6]f64
	// Full transform retained for 3D backface visibility. The affine field above
	// remains the renderer's projection of the element's z=0 plane.
	own_paint_transform_4x4 css.FloatMatrix4x4
	uses_own_paint_transform_4x4 bool
	// Cumulative CSS 2D transform in document coordinates. An all-zero value is the compact identity
	// representation used by boxes which do not establish a transformed paint subtree.
	paint_transform [6]f64
	// Immutable cold paint snapshots; ordinary boxes share the empty defaults.
	media_data &BlockBoxMediaData = unsafe { nil }
	decoration_data &BlockBoxDecorationData = unsafe { nil }
	filter_data &BlockBoxFilterData = unsafe { nil }
	scroll_snap_data &BlockBoxScrollSnapData = unsafe { nil }
	clip_data &BlockBoxClipData = unsafe { nil }
	canvas_data &BlockBoxCanvasData = unsafe { nil }
mut:
	own_scroll_frame_index                         int
	sticky_scroll_frame_index                      int
	accumulated_visual_context_index               int
	accumulated_visual_context_for_descendants_idx int
	plane_root_for_descendants_idx                 int
	// The box's own effects and (non-synthetic) transform nodes, or 0. Compositor
	// samples patch these values in place while the tree keeps its shape.
	own_effects_visual_context_idx                 int
	own_transform_visual_context_idx               int
	fixed_background_visual_context                ?int
	canvas_background_scroll_context               ?int
	fixed_to_viewport                              bool
	// PaintableBox retains one Scrollbar object per axis. Their hover/grab state
	// survives display-list rebuilds and selects thin versus gutter geometry.
	horizontal_scrollbar painting.Scrollbar = painting.Scrollbar.create(.horizontal)
	vertical_scrollbar   painting.Scrollbar = painting.Scrollbar.create(.vertical)
}

// A rectangle in the layout coordinate space (document coordinates when laid out from the root).
pub struct LayoutRect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

// This box's border box (content plus padding and border) as a rectangle.
pub fn (b &BlockBox) border_box() LayoutRect {
	return LayoutRect{
		x: b.x - b.padding.left - b.border.left
		y: b.y - b.padding.top - b.border.top
		width: b.width + b.padding.left + b.padding.right + b.border.left + b.border.right
		height: b.height + b.padding.top + b.padding.bottom + b.border.top + b.border.bottom
	}
}

// Whether `x`/`y` falls within this box's border box.
fn (rect LayoutRect) contains(x f64, y f64) bool {
	return x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y + rect.height
}

// Hit-test the point (`x`, `y`): the `node_id` of the topmost box whose border box contains it, or
// none. Walks the paint order back-to-front, so the last-painted (topmost, z-index-aware) box wins —
// backing document.elementFromPoint.
pub fn (b &BlockBox) hit_test(x f64, y f64) ?i64 {
	// ViewportPaintable::hit_test walks retained Paintable references. Keep the
	// same ownership shape here; materializing shallow BlockBox copies for every
	// pointer event made hit testing proportional to the size of this large
	// transport struct as well as the number of boxes.
	return hit_test_paint_order(b.paint_order_box_references(), x, y)
}

// PaintableBox::transform_point_to_local() maps the screen point back through
// the accumulated visual context before testing the untransformed border box.
fn (b &BlockBox) border_radii_data() painting.BorderRadiiData {
	return painting.BorderRadiiData{
		top_left: painting.BorderRadiusData{b.decorations().border_radii.top_left.x, b.decorations().border_radii.top_left.y}
		top_right: painting.BorderRadiusData{b.decorations().border_radii.top_right.x, b.decorations().border_radii.top_right.y}
		bottom_right: painting.BorderRadiusData{b.decorations().border_radii.bottom_right.x, b.decorations().border_radii.bottom_right.y}
		bottom_left: painting.BorderRadiusData{b.decorations().border_radii.bottom_left.x, b.decorations().border_radii.bottom_left.y}
	}
}

fn (b &BlockBox) border_box_contains_hit_test_point(point painting.Point) bool {
	border_box := b.border_box()
	if !border_box.contains(point.x, point.y) {
		return false
	}
	return b.border_radii_data().contains(point, painting.Rect{border_box.x, border_box.y, border_box.width, border_box.height})
}

// SVGPathPaintable::hit_test() first checks the transformed bounding quad of
// the raw path. Its layout box includes stroke inflation, so the ordinary
// PaintableBox containment check alone admits points which upstream rejects.
fn (b &BlockBox) svg_path_bounding_box_contains_hit_test_point(point painting.Point) bool {
	if !b.has_svg_path() {
		return true
	}
	matrix := normalized_affine(b.svg_path().path_transform)
	determinant := matrix[0] * matrix[3] - matrix[1] * matrix[2]
	if determinant == 0 {
		return false
	}
	translated_x := point.x - matrix[4]
	translated_y := point.y - matrix[5]
	local_point := painting.Point{
		x: (matrix[3] * translated_x - matrix[2] * translated_y) / determinant
		y: (-matrix[1] * translated_x + matrix[0] * translated_y) / determinant
	}
	return b.svg_data.bounding_box.contains(local_point)
}

fn (b &BlockBox) contains_hit_test_point(x f64, y f64) bool {
	mut local_point := painting.Point{x, y}
	if affine_is_compact_identity(b.paint_transform) {
		return b.svg_path_bounding_box_contains_hit_test_point(local_point)
			&& b.border_box_contains_hit_test_point(local_point)
	}
	matrix := normalized_affine(b.paint_transform)
	determinant := matrix[0] * matrix[3] - matrix[1] * matrix[2]
	if determinant == 0 {
		return false
	}
	translated_x := x - matrix[4]
	translated_y := y - matrix[5]
	local_point = painting.Point{
		x: (matrix[3] * translated_x - matrix[2] * translated_y) / determinant
		y: (-matrix[1] * translated_x + matrix[0] * translated_y) / determinant
	}
	return b.svg_path_bounding_box_contains_hit_test_point(local_point)
		&& b.border_box_contains_hit_test_point(local_point)
}

fn hit_test_paint_order(order []&BlockBox, x f64, y f64) ?i64 {
	for i := order.len - 1; i >= 0; i-- {
		box := order[i]
		node_id := box.node_id_for_hit_test()
		if node_id != 0 && box.visible && box.pointer_events_enabled
			&& box.contains_hit_test_point(x, y) {
			return node_id
		}
	}
	return none
}

fn (b &BlockBox) node_id_for_hit_test() i64 {
	if b.node_id != 0 {
		return b.node_id
	}
	return b.hit_test_continuation_node_id
}

fn element_for_paint_node_id(node_id i64) ?&dom.Element {
	node := dom.Node.from_unique_id(dom.UniqueNodeID(node_id)) or { return none }
	return node.as_element()
}

// The element at the point (`x`, `y`) — hit-test the box tree, then follow the retained DOM identity
// just as Paintable::dom_node() does upstream. Analogous to document.elementFromPoint.
pub fn (b &BlockBox) element_at_point(x f64, y f64, _root &dom.Node) ?&dom.Element {
	node_id := b.hit_test(x, y) or { return none }
	return element_for_paint_node_id(node_id)
}

// An item produced by the rendered-text collection: either a run of text or a *required line break
// count* (a positive integer, held as a negative-tagged marker). We model the variant as a struct
// with a `line_breaks` count of 0 meaning "this is a text item" and >0 meaning "this is a run of N
// required line breaks" (the `text` field is then empty).
struct TextItem {
	text        string
	line_breaks int
	// Whether ASCII white-space in `text` participates in CSS collapsing with adjacent text boxes.
	collapsible bool
}

struct PaintOrderBuckets {
mut:
	negative []BlockBox
	normal   []BlockBox
	zero     []BlockBox
	positive []BlockBox
}

// Upstream Painting keeps a retained Paintable tree and its stacking-context
// lists contain references to those paintables. The compatibility `paint_order`
// API above predates that model and returns BlockBox values, but the renderer
// must not use it: copying a BlockBox also copies its descendant arrays and made
// display-list construction quadratic on large documents. These entries retain
// the source box identity and carry only the accumulated opacity that upstream
// derives from the enclosing visual contexts.
struct PaintOrderEntry {
	box     &BlockBox
	opacity f64
}

struct PaintOrderReferenceBuckets {
mut:
	negative []&BlockBox
	normal   []&BlockBox
	zero     []&BlockBox
	positive []&BlockBox
}

struct PaintOrderSortEntry {
	box        &BlockBox
	tree_order int
}

enum CompatibilityPaintPhase {
	background
	border
	table_collapsed_border
	foreground
	outline
	overlay
}

const compatibility_paint_phase_count = 6

enum CompatibilityDescendantPaintPhase {
	background_and_borders
	floats
	background_and_borders_for_inline_and_replaced
	foreground
}

struct CompatibilityPaintStep {
	box   &BlockBox
	phase CompatibilityPaintPhase
mut:
	entry_index int = -1
}

struct CompatibilityStackingContextMembers {
mut:
	negative []&BlockBox
	zero     []&BlockBox
	positive []&BlockBox
}

// Flatten this box's subtree in stacking-context order. Descendant stacking contexts are hoisted
// through ancestors that do not establish a context, then sorted as negative, zero, and positive
// stack levels. Positioned `z-index:auto` descendants occupy the zero phase without trapping their
// own stacking-context descendants. Opacity and transforms establish atomic contexts.
pub fn (b &BlockBox) paint_order() []BlockBox {
	mut order := []BlockBox{}
	for entry in b.paint_order_entries() {
		mut box := *entry.box
		box.children = []
		box.opacity = entry.opacity
		order << box
	}
	return order
}

fn (b &BlockBox) paint_order_entries() []PaintOrderEntry {
	mut order := []PaintOrderEntry{}
	b.collect_stacking_context_references(mut order, 1.0)
	return order
}

fn (b &BlockBox) paint_order_box_references() []&BlockBox {
	entries := b.paint_order_entries()
	mut order := []&BlockBox{cap: entries.len}
	for entry in entries {
		order << entry.box
	}
	return order
}

fn (b &BlockBox) collect_paint_reference_buckets(mut buckets PaintOrderReferenceBuckets, positioned_group bool) {
	for child_index := 0; child_index < b.children.len; child_index++ {
		child := unsafe { &b.children[child_index] }
		if child.stacking_context {
			if child.z_index < 0 {
				buckets.negative << child
			} else if child.z_index > 0 {
				buckets.positive << child
			} else {
				buckets.zero << child
			}
			continue
		}
		child_positioned_group := positioned_group || child.positioned
		if child_positioned_group {
			buckets.zero << child
		} else {
			buckets.normal << child
		}
		child.collect_paint_reference_buckets(mut buckets, child_positioned_group)
	}
}

fn (b &BlockBox) collect_stacking_context_references(mut order []PaintOrderEntry, inherited_opacity f64) {
	effective_opacity := inherited_opacity * b.opacity
	order << PaintOrderEntry{
		box: unsafe { b }
		opacity: effective_opacity
	}
	mut buckets := PaintOrderReferenceBuckets{}
	b.collect_paint_reference_buckets(mut buckets, false)
	for context in stable_sort_box_references_by_z(buckets.negative) {
		context.collect_stacking_context_references(mut order, effective_opacity)
	}
	for box in buckets.normal {
		order << PaintOrderEntry{
			box: unsafe { box }
			opacity: effective_opacity * box.opacity
		}
	}
	for box in buckets.zero {
		if box.stacking_context {
			box.collect_stacking_context_references(mut order, effective_opacity)
		} else {
			order << PaintOrderEntry{
				box: unsafe { box }
				opacity: effective_opacity * box.opacity
			}
		}
	}
	for context in stable_sort_box_references_by_z(buckets.positive) {
		context.collect_stacking_context_references(mut order, effective_opacity)
	}
}

// A single entry in the display list produced from a laid-out box tree: either a filled rectangle
// (`fill_rect`, e.g. a background) or drawn text (`draw_text`). `color` is the serialized paint color.
pub struct PaintClip {
pub:
	rect                LayoutRect
	corner_radii        BoxRadii
	is_path             bool
	is_svg_mask         bool
	is_svg_content_mask bool
	// Packed ClipPathSegment records (12 f32 values each) are built once per
	// retained context replay and shared by all commands using this clip.
	path_data       []f32
	path_even_odd   bool
	path_components []PaintPath
	mask_operations []PaintMaskOperation
	cache_key       u64
	scope_id        u64
	mask_luminance  bool
	// The accumulated transform at the point where this clip node appears.
	// Descendant scroll frames may therefore move content without moving the
	// overflow clip itself.
	transform [6]f64
}

// Commands which share one accumulated visual context also share this retained
// clip list. This mirrors DisplayList's state switching without copying every
// ancestor clip into every phase command.
pub struct PaintClipList {
pub:
	items []PaintClip
}

pub enum PaintVisualLayerKind {
	css_effect
	css_filter
	svg_mask
}

pub struct PaintVisualLayer {
pub:
	kind       PaintVisualLayerKind
	scope_id   u64
	opacity    f64 = 1.0
	blend_mode painting.CompositingAndBlendingOperator
	// Clip active at the effect node, before any descendant clips. Its viewport
	// bounds conservatively limit the native transparency surface.
	clip_rect  ?LayoutRect
	filter     ?painting.GfxFilter = ?painting.GfxFilter(none)
	mask_clip  PaintClip
}

pub struct PaintVisualLayerList {
pub:
	items []PaintVisualLayer
}

pub struct PaintPath {
pub:
	path_data     []f32
	path_even_odd bool
	transform     [6]f64
}

pub enum PaintMaskOperationKind {
	begin_opacity
	end_opacity
	image
	path
}

pub struct PaintMaskOperation {
pub:
	kind                   PaintMaskOperationKind
	opacity                f64 = 1.0
	image_url              string
	image_rect             LayoutRect
	image_position_x       string = '50%'
	image_position_y       string = '50%'
	image_rendering        css.ImageRendering
	image_paintable        ?painting.ImagePaintable
	path_data              []f32
	path_even_odd          bool
	transform              [6]f64
	fill_color             string
	stroke_color           string
	fill_linear_gradient   ?painting.SVGLinearGradientPaintStyle
	stroke_linear_gradient ?painting.SVGLinearGradientPaintStyle
	fill_radial_gradient   ?painting.SVGRadialGradientPaintStyle
	stroke_radial_gradient ?painting.SVGRadialGradientPaintStyle
	fill_pattern           ?&painting.SVGPatternPaintStyle
	stroke_pattern         ?&painting.SVGPatternPaintStyle
	has_fill               bool
	has_stroke             bool
	fill_opacity           f64 = 1.0
	stroke_opacity         f64 = 1.0
	stroke_width           f64
	stroke_linecap         int
	stroke_linejoin        int
	stroke_miterlimit      f64 = 4.0
	stroke_first           bool
}

// One shaped text run used as opaque coverage by BackgroundPainting.cpp's
// background-clip:text mask. Color and descendant opacity deliberately do not
// participate: upstream records each glyph run in solid black into the mask.
pub struct PaintTextClipRun {
pub:
	x         f64
	y         f64
	width     f64
	height    f64
	text      string
	font_size f64 = 16.0
	bold      bool
	italic    bool
	mono      bool
	rtl       bool
	// BackgroundPainting.cpp records the same retained glyph run as ordinary
	// foreground text, in opaque white, into the text clip mask.
	glyph_run           ?&platform.GlyphRun
	glyph_translation_x f64
	glyph_translation_y f64
	glyph_orientation   painting.Orientation
	font_smoothing      css.FontSmoothing
}

// BackgroundPainting resolves these retained CSS values at replay time. Share
// one snapshot through phase caches and recordings instead of embedding the
// complete length-resolution context in every text and border command.
pub struct PaintBackgroundLayerData {
pub:
	layer              css.BackgroundLayerData
	resolution_context css.LengthResolutionContext
	layout_coordinate_scale f64 = 1
}

// Source-shaped geometry retained only by inner and outer box shadows.
// Text shadows use their glyph run and common command rectangle instead.
pub struct PaintBoxShadowData {
pub:
	content_rect  LayoutRect
	content_radii BoxRadii
	clip_radii    BoxRadii
	inner_rect    LayoutRect
	inner_radii   BoxRadii
}

// Spell out absent payloads: the compatibility compiler otherwise constructs
// their nested defaults (including allocated lengths) before wrapping in none.
// Immutable background and replaced-image parameters, shared by retained
// phases and recordings. Live scroll offsets remain on PaintCommand.
pub struct PaintImageData {
pub:
	image_url                   string
	background_svg_document     ?&dom.Document = ?&dom.Document(none)
	background_static_svg_resource ?&StaticSVGBackgroundResource = ?&StaticSVGBackgroundResource(none)
	background_svg_color_scheme css.PreferredColorScheme = .auto_
	image_intrinsic_width       f64
	image_intrinsic_height      f64
	image_repeat_x              string
	image_repeat_y              string
	image_size                  string
	image_position_x            string
	image_position_y            string
	image_rendering             css.ImageRendering
	image_clip_x                f64
	image_clip_y                f64
	image_clip_width            f64
	image_clip_height           f64
	image_clip_radii            BoxRadii
	// Opaque block borders can obscure part of an image without moving its
	// positioning area or the rounded clip shared with the background color.
	background_image_destination ?LayoutRect = ?LayoutRect(none)
	image_attachment            string
	background_layer_data       ?&PaintBackgroundLayerData = ?&PaintBackgroundLayerData(none)
	background_blend_mode       painting.BlendMode
}

// Immutable source-space path and SVG paint parameters, shared through
// cached phases and recordings. Common colors, stroke width and live transforms
// stay on PaintCommand; force-dark publishes a copied payload for new gradients.
pub struct PaintSVGPathData {
pub:
	path      string
	path_data []f32
	path_transform         [6]f64
	path_polygons          [][]f64
	svg_gradient_data      ?&PaintSVGGradientData = ?&PaintSVGGradientData(none)
	svg_solid_color_data   &PaintSVGSolidColorData = unsafe { nil }
	fill_pattern           ?&painting.SVGPatternPaintStyle = ?&painting.SVGPatternPaintStyle(none)
	stroke_pattern         ?&painting.SVGPatternPaintStyle = ?&painting.SVGPatternPaintStyle(none)
	stroke_dasharray       []f64
	stroke_dashoffset      f64
	non_scaling_stroke     bool
	stroke_first           bool
	fill_even_odd          bool
	stroke_linecap         int
	stroke_linejoin        int
	stroke_miterlimit      f64 = 4.0
	fill_opacity           f64 = 1.0
	stroke_opacity         f64 = 1.0
}

pub struct PaintCommand {
pub mut:
	kind      string // fill_rect/fill_rounded_rect/stroke_rounded_rect/fill_ellipse/stroke_ellipse/fill_polygon/draw_line/draw_text/draw_svg_path
	x         f64
	y         f64
	width     f64
	height    f64
	color     string
	srgb_color_data &PaintSRGBColor = unsafe { nil }
	force_dark_role           painting.ForceDarkRole
	force_dark_role_set       bool
	force_dark_backdrop       ?painting.Color = ?painting.Color(none)
	apply_force_dark_to_image bool
	line_box_debug            bool
	// Keep the shape flags in this existing boolean/padding group: adding a
	// rare border payload must not widen every retained paint command.
	// A square fill_rect that Blink rasterizes as an antialiased GPU rectangle,
	// such as a text decoration with fractional ends.
	antialiased_rect bool
	// Native text fields use non-AA paint flags, including their fill underlay.
	disable_antialias bool
	// A rounded fill_rect drawn with the following border or background image.
	underlays_next bool
	text      string // for 'draw_text'
	font_size f64 = 16.0 // for 'draw_text'
	bold      bool
	italic    bool
	mono      bool
	rtl       bool // base paragraph direction for shaped text
	// DisplayListRecorder::DrawGlyphRun retains shaped glyph indices and
	// positions. Raw text remains only as the portable/backend compatibility
	// fallback; the native player must not shape it again during every repaint.
	glyph_run           ?&platform.GlyphRun = ?&platform.GlyphRun(none)
	glyph_translation_x f64
	glyph_translation_y f64
	glyph_orientation   painting.Orientation
	font_smoothing      css.FontSmoothing
	opacity             f64 = 1.0 // the box's cumulative opacity (this box × its ancestors')
	// Product of the retained CSS effect layers surrounding this command. The
	// native player divides it out of `opacity`, because those layers composite
	// the complete subtree atomically. Portable backends keep the historical
	// flattened-alpha fallback until they gain offscreen effect surfaces.
	group_opacity f64 = 1.0
	radius        f64 // corner radius for a rounded 'fill_rect' (0 = square)
	// Box-local CSS border geometry resolves its snapped origin against the
	// current retained transform, including compositor-only animation updates.
	local_border_data &PaintLocalBorderData = unsafe { nil }
	// NativeTheme keeps CSS-sized geometry at the snapped device-pixel origin.
	checkbox_theme_data &PaintCheckboxThemeData = unsafe { nil }
	// Rectangles clipped out of an antialiased 'fill_rect' without
	// antialiasing, as left, top, right and bottom: skip-ink decoration gaps.
	clip_outs []f64
	// Retained used corner radii for `fill_rounded_rect`. This mirrors Painting's
	// FillRoundedRect command instead of discarding elliptical/per-corner radii into vertices.
	corner_radii    BoxRadii
	blur            f64 // Gaussian blur radius for a 'fill_rect' (0 = hard edges), used by box-shadow
	shadow_offset_x f64
	shadow_offset_y f64
	shadow_spread   f64
	outer_shadow    bool // clip the shadow source out of the original border box
	// Ordinary commands need no box-shadow geometry. Shadow commands retain
	// one immutable source-space snapshot across phase caches and replays.
	box_shadow_data &PaintBoxShadowData = unsafe { nil }
	// Only gradient commands retain a resolved background image. Share its
	// immutable snapshot across cached phases instead of embedding it in every
	// text, border and image command.
	gradient                  ?&LinearGradient = ?&LinearGradient(none)
	gradient_background_layer bool
	// Immutable path parameters remain in source space across live replay.
	svg_data &PaintSVGPathData = unsafe { nil }
	// Cumulative CSS/SVG affine transform in `matrix(a,b,c,d,e,f)` order. All-zero means identity.
	transform              [6]f64
	points                 []f64
	stroke_color           string
	stroke_width           f64
	line_style             string = 'solid'
	// Immutable background and replaced-image parameters are retained only by
	// commands which use them, and shared through phase caches and replay.
	image_data &PaintImageData = unsafe { nil }
	image_scroll_offset_x       f64
	image_scroll_offset_y       f64
	// BackgroundPainting temporarily switches only fixed layers to the visual
	// context which compensates every ancestor scroll frame.
	visual_context_index ?int = ?int(none)
	// Allocate immutable replaced-content snapshots only for commands which
	// use them. Most commands are text or borders and need no media payload.
	// Background images continue through BackgroundPainting.
	image_paintable       ?&painting.ImagePaintable = ?&painting.ImagePaintable(none)
	replaced_image_bitmap ?&dom.Bitmap_ = ?&dom.Bitmap_(none)
	// CanvasPaintable publishes its current RGBA surface as external content.
	canvas_bitmap    ?&dom.Bitmap_ = ?&dom.Bitmap_(none)
	canvas_paintable ?&painting.CanvasPaintable = ?&painting.CanvasPaintable(none)
	// VideoPaintable retains the representation switch separately from the
	// optional poster/current-frame bitmap.
	video_bitmap         ?&dom.Bitmap_ = ?&dom.Bitmap_(none)
	video_frame_source   ?&painting.VideoFrameSource = ?&painting.VideoFrameSource(none)
	video_representation painting.VideoRepresentation
	video_paintable      ?&painting.VideoPaintable = ?&painting.VideoPaintable(none)
	// NavigableContainerViewportPaintable retains the hosted document's
	// display list as a nested command stream rather than rasterizing it.
	nested_viewport_commands  []PaintCommand
	nested_viewport_paintable ?&painting.NavigableContainerViewportPaintable = ?&painting.NavigableContainerViewportPaintable(none)
	// Synthetic balanced controls around the complete background color/layer
	// group. The begin command owns the inclusive-subtree glyph runs.
	text_clip_runs []PaintTextClipRun
	// Display-list replay retains every accumulated clip node in source order.
	// The scalar rectangle is their conservative intersection for fast reject
	// and the non-native scissor fallback; native rasterization consumes the
	// shared clip list so rounded and nested clips preserve their exact shapes.
	has_clip    bool
	clip_x      f64
	clip_y      f64
	clip_width  f64
	clip_height f64
	clip_list   &PaintClipList = unsafe { nil }
	// A DisplayListRecorder clip local to this command's paint phase. Unlike an
	// accumulated visual-context clip, it does not apply to other phases or
	// descendants (FieldSetPaintable uses this for its background and top edge).
	recording_clip ?LayoutRect = ?LayoutRect(none)
	// Effects and SVG masks are group operations. Retain their ancestor order so
	// replay can emit balanced layer boundaries around the complete subtree.
	visual_layer_list &PaintVisualLayerList = unsafe { nil }
	visual_layer_data ?&PaintVisualLayer = ?&PaintVisualLayer(none)
	// ApplyBackdropFilter samples the already-painted destination. If this box
	// also has `filter`, that sample comes from outside its newly-opened filter
	// layer while the filtered backdrop is painted into the layer with the box.
	backdrop_filter_data           ?&painting.GfxFilter = ?&painting.GfxFilter(none)
	backdrop_source_outside_filter bool
	// Nested viewport replay can override the mask geometry while sharing the
	// immutable layer snapshot retained by the original recording.
	mask_clip_data ?&PaintClip = ?&PaintClip(none)
	// Fixed commands inherit the root visual context rather than the viewport
	// scroll frame. Retain that classification for native/debug consumers.
	fixed_to_viewport bool
	// PaintScrollBar is moved by the live snapshot in DisplayListPlayer rather
	// than forcing its retained overlay phase to be regenerated.
	scrollbar_axis                   string
	scrollbar_thumb_travel_ratio     f64
	scrollbar_recorded_scroll_offset f64
mut:
	paint_box_index int
	paint_phase     CompatibilityPaintPhase
}

// Logical SVG defaults require no payload allocation for ordinary commands.
pub fn (command &PaintCommand) svg() PaintSVGPathData {
	if command.svg_data != unsafe { nil } {
		return *command.svg_data
	}
	return PaintSVGPathData{}
}

// Logical defaults preserve commands which have no image payload. Callers in
// image/gradient branches take one snapshot rather than copying this per field.
pub fn (command &PaintCommand) image() PaintImageData {
	return paint_image_data(command.image_data)
}

// The accessors below are also free functions over the command's payload
// pointers: calling a method on a command held by value would make current V
// move that copy to the heap, since the command holds an inline transform array.
fn paint_image_data(data &PaintImageData) PaintImageData {
	if data != unsafe { nil } {
		return *data
	}
	return PaintImageData{}
}

// Debug recordings ask every command for its URL without materializing the
// larger image defaults for ordinary text, border and control commands.
pub fn (command &PaintCommand) image_url() string {
	if command.image_data != unsafe { nil } {
		return command.image_data.image_url
	}
	return ''
}

pub fn (command &PaintCommand) box_shadow() PaintBoxShadowData {
	if command.box_shadow_data != unsafe { nil } {
		return *command.box_shadow_data
	}
	return PaintBoxShadowData{}
}

// Synthetic layer commands retain their immutable payload separately. Ordinary
// text, borders, and backgrounds keep these options empty instead of carrying
// almost a kilobyte of unused layer, mask, and filter storage through every copy.
pub fn (command &PaintCommand) visual_layer() PaintVisualLayer {
	if layer := command.visual_layer_data {
		return *layer
	}
	return PaintVisualLayer{}
}

pub fn (command &PaintCommand) mask_clip() PaintClip {
	return paint_mask_clip(command.mask_clip_data, command.visual_layer_data)
}

fn paint_mask_clip(mask_clip ?&PaintClip, visual_layer ?&PaintVisualLayer) PaintClip {
	if clip := mask_clip {
		return *clip
	}
	if layer := visual_layer {
		return layer.mask_clip
	}
	return PaintClip{}
}

pub fn (command &PaintCommand) backdrop_filter() ?painting.GfxFilter {
	filter := command.backdrop_filter_data or { return none }
	return *filter
}

fn retained_paint_backdrop_filter(filter ?painting.GfxFilter) ?&painting.GfxFilter {
	if value := filter {
		return &painting.GfxFilter{ ...value }
	}
	return none
}

// A resolved `box-shadow`: pixel offsets from the border box, blur and spread radii, color, and
// whether the shadow is clipped inward at the padding edge. Offsets/radii are resolved to px.
pub struct BoxShadow {
pub:
	offset_x f64
	offset_y f64
	blur     f64
	spread   f64
	color    css.Color
	inset    bool
	srgb_color_data &PaintSRGBColor = unsafe { nil }
}

fn painting_shadow_data_from_transport(shadow BoxShadow) painting.ShadowData {
	return painting.ShadowData{
		color: painting.Color{shadow.color.r, shadow.color.g, shadow.color.b, shadow.color.a}
		offset_x: shadow.offset_x
		offset_y: shadow.offset_y
		blur_radius: shadow.blur
		spread_distance: shadow.spread
		placement: if shadow.inset { .inner } else { .outer }
	}
}

fn painting_border_radii_data_from_transport(radii BoxRadii) painting.BorderRadiiData {
	return painting.BorderRadiiData{
		top_left: painting.BorderRadiusData{radii.top_left.x, radii.top_left.y}
		top_right: painting.BorderRadiusData{radii.top_right.x, radii.top_right.y}
		bottom_right: painting.BorderRadiusData{radii.bottom_right.x, radii.bottom_right.y}
		bottom_left: painting.BorderRadiusData{radii.bottom_left.x, radii.bottom_left.y}
	}
}

fn painting_border_data_from_transport(border BoxEdges, colors BoxColors,
	styles BoxBorderStyles) painting.BordersData {
	return painting.BordersData{
		top: painting.BorderData{painting.Color{colors.top.r, colors.top.g, colors.top.b, colors.top.a}, styles.top, border.top}
		right: painting.BorderData{painting.Color{colors.right.r, colors.right.g, colors.right.b, colors.right.a}, styles.right, border.right}
		bottom: painting.BorderData{painting.Color{colors.bottom.r, colors.bottom.g, colors.bottom.b, colors.bottom.a}, styles.bottom, border.bottom}
		left: painting.BorderData{painting.Color{colors.left.r, colors.left.g, colors.left.b, colors.left.a}, styles.left, border.left}
	}
}

// Active lowering of PaintableBox::paint_box_shadow() through the direct
// ShadowPainting.cpp geometry translation.
fn paintable_box_paint_box_shadow(mut commands []PaintCommand, shadows []BoxShadow,
	border BoxEdges, colors BoxColors, styles BoxBorderStyles, radii BoxRadii,
	border_rect LayoutRect, padding_rect LayoutRect, opacity f64) {
	if shadows.len == 0 {
		return
	}
	mut layers := []painting.ShadowData{cap: shadows.len}
	for shadow in shadows {
		layers << painting_shadow_data_from_transport(shadow)
	}
	converter := painting.new_device_pixel_converter(1.0) or { return }
	resolved := painting.paint_box_shadow(painting.Rect{border_rect.x, border_rect.y, border_rect.width, border_rect.height}, painting.Rect{padding_rect.x, padding_rect.y, padding_rect.width, padding_rect.height}, painting_border_data_from_transport(border, colors, styles), painting_border_radii_data_from_transport(radii), layers, converter)
	for index, shadow in resolved {
		if shadow.placement == .outer {
			commands << PaintCommand{
				kind: 'paint_outer_box_shadow'
				x: shadow.shadow_rect.x
				y: shadow.shadow_rect.y
				width: shadow.shadow_rect.width
				height: shadow.shadow_rect.height
				color: painting_color_string(shadow.color)
				srgb_color_data: shadows[shadows.len - 1 - index].srgb_color_data
				force_dark_role: .foreground
				force_dark_role_set: true
				opacity: opacity
				blur: shadow.blur_radius
				corner_radii: transport_radii_from_painting(shadow.shadow_corner_radii)
				box_shadow_data: &PaintBoxShadowData{
					content_rect: LayoutRect{shadow.content_rect.x, shadow.content_rect.y,
						shadow.content_rect.width, shadow.content_rect.height}
					content_radii: transport_radii_from_painting(shadow.content_corner_radii)
					clip_radii: transport_radii_from_painting(shadow.clip_corner_radii)
				}
			}
		} else {
			commands << PaintCommand{
				kind: 'paint_inner_box_shadow'
				x: shadow.outer_shadow_rect.x
				y: shadow.outer_shadow_rect.y
				width: shadow.outer_shadow_rect.width
				height: shadow.outer_shadow_rect.height
				color: painting_color_string(shadow.color)
				force_dark_role: .foreground
				force_dark_role_set: true
				opacity: opacity
				blur: shadow.blur_radius
				corner_radii: transport_radii_from_painting(shadow.content_corner_radii)
				box_shadow_data: &PaintBoxShadowData{
					content_rect: LayoutRect{shadow.content_rect.x, shadow.content_rect.y,
						shadow.content_rect.width, shadow.content_rect.height}
					content_radii: transport_radii_from_painting(shadow.content_corner_radii)
					clip_radii: transport_radii_from_painting(shadow.clip_corner_radii)
					inner_rect: LayoutRect{shadow.inner_shadow_rect.x, shadow.inner_shadow_rect.y,
						shadow.inner_shadow_rect.width, shadow.inner_shadow_rect.height}
					inner_radii: transport_radii_from_painting(shadow.inner_corner_radii)
				}
			}
		}
	}
}

fn append_inset_shadow_commands(mut commands []PaintCommand, shadows []BoxShadow, x f64, y f64, width f64, height f64, radius f64, opacity f64) {
	for shadow in shadows {
		if !shadow.inset {
			continue
		}
		commands << PaintCommand{
			kind: 'fill_inset_shadow'
			x: x
			y: y
			width: width
			height: height
			color: shadow.color.serialize()
			force_dark_role: .foreground
			force_dark_role_set: true
			opacity: opacity
			radius: clamp_radius(radius, width, height)
			blur: shadow.blur
			shadow_offset_x: shadow.offset_x
			shadow_offset_y: shadow.offset_y
			shadow_spread: shadow.spread
		}
	}
}

fn background_box_rect(box &BlockBox, box_name string) LayoutRect {
	return background_box_rect_from_border(box, box_name, box.border_box())
}

fn background_box_rect_from_border(box &BlockBox, box_name string, border LayoutRect) LayoutRect {
	return match box_name.trim_space().to_lower() {
		'content-box' {
			LayoutRect{
				x: border.x + box.border.left + box.padding.left
				y: border.y + box.border.top + box.padding.top
				width: non_negative(border.width - box.border.left - box.border.right - box.padding.left - box.padding.right)
				height: non_negative(border.height - box.border.top - box.border.bottom - box.padding.top - box.padding.bottom)
			}
		}
		'padding-box' {
			LayoutRect{
				x: border.x + box.border.left
				y: border.y + box.border.top
				width: non_negative(border.width - box.border.left - box.border.right)
				height: non_negative(border.height - box.border.top - box.border.bottom)
			}
		}
		else {
			border
		}
	}
}

fn shrink_corner_radius(radius CornerRadius, horizontal f64, vertical f64) CornerRadius {
	return CornerRadius{non_negative(radius.x - horizontal), non_negative(radius.y - vertical)}
}

fn background_box_radii(box &BlockBox, box_name string, border_radii BoxRadii, rect LayoutRect) BoxRadii {
	name := box_name.trim_space().to_lower()
	mut radii := border_radii
	if name == 'padding-box' || name == 'content-box' {
		radii = BoxRadii{
			top_left: shrink_corner_radius(radii.top_left, box.border.left, box.border.top)
			top_right: shrink_corner_radius(radii.top_right, box.border.right, box.border.top)
			bottom_right: shrink_corner_radius(radii.bottom_right, box.border.right, box.border.bottom)
			bottom_left: shrink_corner_radius(radii.bottom_left, box.border.left, box.border.bottom)
		}
	}
	if name == 'content-box' {
		radii = BoxRadii{
			top_left: shrink_corner_radius(radii.top_left, box.padding.left, box.padding.top)
			top_right: shrink_corner_radius(radii.top_right, box.padding.right, box.padding.top)
			bottom_right: shrink_corner_radius(radii.bottom_right, box.padding.right, box.padding.bottom)
			bottom_left: shrink_corner_radius(radii.bottom_left, box.padding.left, box.padding.bottom)
		}
	}
	return normalize_box_radii(radii, rect.width, rect.height)
}

fn background_image_layer_blend_mode(layer BackgroundImageLayer) painting.BlendMode {
	if computed_layer := layer.computed_layer {
		return painting.blend_mode_from_css(computed_layer.blend_mode)
	}
	return .normal
}

fn retained_background_layer_data(layer BackgroundImageLayer) ?&PaintBackgroundLayerData {
	computed_layer := layer.computed_layer or { return none }
	return &PaintBackgroundLayerData{
		layer: computed_layer
		resolution_context: layer.resolution_context
		layout_coordinate_scale: layer.layout_coordinate_scale
	}
}

fn background_layer_command(layer BackgroundImageLayer, origin LayoutRect, clip LayoutRect,
	clip_radii BoxRadii, opacity f64, radius f64, points []f64,
	background_scroll_offset painting.Point, image_rendering css.ImageRendering,
	fixed_background_visual_context ?int, initial_containing_block LayoutRect,
	snap_generated_image bool, image_destination ?LayoutRect) ?PaintCommand {
	blend_mode := background_image_layer_blend_mode(layer)
	mut positioning_area := origin
	mut visual_context_index := ?int(none)
	if layer.attachment == 'fixed' {
		if fixed_context := fixed_background_visual_context {
			positioning_area = initial_containing_block
			visual_context_index = fixed_context
		}
	}
	if source := layer.gradient_source {
		computed_layer := layer.computed_layer or { return none }
		// The default auto-size, zero-position gradient fills the snapped
		// positioning area. Other sizes retain their separate positioning phase.
		if snap_generated_image && chromium_default_gradient_geometry(computed_layer) {
			positioning_area = pixel_snapped_layout_rect(positioning_area)
		}
		resolved_layer := painting.resolve_background_layer_without_intrinsic(painting.BackgroundLayerWithoutIntrinsicResolutionInput{
			layer: computed_layer
			image_id: source.serialize(.normal)
			background_positioning_area: painting.Rect{positioning_area.x, positioning_area.y, positioning_area.width, positioning_area.height}
			resolution_context: layer.resolution_context
		}) or { return none }
		gradient := resolve_background_gradient(source, resolved_layer.image_rect.width, resolved_layer.image_rect.height, layer.resolution_context, layer.gradient_context) or {
			return none
		}
		return PaintCommand{
			kind: 'fill_gradient'
			x: positioning_area.x
			y: positioning_area.y
			width: positioning_area.width
			height: positioning_area.height
			opacity: opacity
			radius: radius
			points: points
			gradient: &LinearGradient{...gradient}
			gradient_background_layer: true
			force_dark_role: .background
			force_dark_role_set: true
			image_data: &PaintImageData{
				image_clip_x: clip.x
				image_clip_y: clip.y
				image_clip_width: clip.width
				image_clip_height: clip.height
				image_clip_radii: clip_radii
				image_attachment: layer.attachment
				background_layer_data: retained_background_layer_data(layer)
				background_blend_mode: blend_mode
			}
			image_scroll_offset_x: background_scroll_offset.x
			image_scroll_offset_y: background_scroll_offset.y
			visual_context_index: visual_context_index
		}
	}
	if layer.url == '' {
		return none
	}
	return PaintCommand{
		kind: 'draw_background_image'
		x: positioning_area.x
		y: positioning_area.y
		width: positioning_area.width
		height: positioning_area.height
		opacity: opacity
		radius: radius
		points: points
		image_data: &PaintImageData{
			image_url: layer.url
			background_svg_document: layer.svg_document
			background_static_svg_resource: layer.static_svg_resource
			background_svg_color_scheme: layer.color_scheme
			image_intrinsic_width: layer.intrinsic_width
			image_intrinsic_height: layer.intrinsic_height
			image_repeat_x: layer.repeat_x
			image_repeat_y: layer.repeat_y
			image_size: layer.size
			image_position_x: layer.position_x
			image_position_y: layer.position_y
			image_rendering: image_rendering
			background_image_destination: image_destination
			image_clip_x: clip.x
			image_clip_y: clip.y
			image_clip_width: clip.width
			image_clip_height: clip.height
			image_clip_radii: clip_radii
			image_attachment: layer.attachment
			background_layer_data: retained_background_layer_data(layer)
			background_blend_mode: blend_mode
		}
		force_dark_role: .background
		force_dark_role_set: true
		image_scroll_offset_x: background_scroll_offset.x
		image_scroll_offset_y: background_scroll_offset.y
		visual_context_index: visual_context_index
	}
}

// Blink's ToPixelSnappedRect(): each edge rounds to the nearest whole pixel.
fn pixel_snapped_layout_rect(rect LayoutRect) LayoutRect {
	left := math.floor(rect.x + 0.5)
	top := math.floor(rect.y + 0.5)
	return LayoutRect{left, top, non_negative(math.floor(rect.x + rect.width + 0.5) - left),
		non_negative(math.floor(rect.y + rect.height + 0.5) - top)}
}

fn rect_union(first LayoutRect, second LayoutRect) LayoutRect {
	left := math.min(first.x, second.x)
	top := math.min(first.y, second.y)
	right := math.max(first.x + first.width, second.x + second.width)
	bottom := math.max(first.y + first.height, second.y + second.height)
	return LayoutRect{left, top, non_negative(right - left), non_negative(bottom - top)}
}

fn (b &BlockBox) current_scroll_offset(fallback CompatibilityOverlayData) painting.Point {
	// The C++ display-list player applies the latest ScrollStateSnapshot when it
	// replays PaintScrollBar. Read the DOM-side paintable here so a newly recorded
	// compatibility display list observes offsets changed since layout.
	if b.node_id != 0 {
		if node := dom.Node.from_unique_id(dom.UniqueNodeID(b.node_id)) {
			// The transport's root element also represents the omitted viewport
			// box. Its scrollbar follows the document, not the element's offset.
			if b.is_viewport_scroller {
				viewport := node.document().layout_viewport_rect()
				return painting.Point{viewport.x, viewport.y}
			}
			if paintable := node.paintable_box() {
				offset := paintable.scroll_offset()
				return painting.Point{offset.x() * node.document().layout_coordinate_scale(),
					offset.y() * node.document().layout_coordinate_scale()}
			}
		}
	}
	return painting.Point{fallback.scroll_offset_x, fallback.scroll_offset_y}
}

fn (b &BlockBox) compatibility_absolute_padding_rect() painting.Rect {
	if b.is_viewport_scroller {
		return painting.Rect{
			width: b.canvas().viewport_width
			height: b.canvas().viewport_height
		}
	}
	return painting.Rect{
		x: b.x - b.padding.left
		y: b.y - b.padding.top
		width: b.width + b.padding.left + b.padding.right
		height: b.height + b.padding.top + b.padding.bottom
	}
}

fn (b &BlockBox) compatibility_scrollbar_geometry_input(overlay CompatibilityOverlayData,
	direction painting.ScrollDirection, metrics painting.ChromeMetrics,
	with_gutter bool) painting.ScrollbarGeometryInput {
	return painting.ScrollbarGeometryInput{
		direction: direction
		padding_rect: b.compatibility_absolute_padding_rect()
		scrollable_overflow: painting.Rect{
			x: overlay.scrollable_overflow.x
			y: overlay.scrollable_overflow.y
			width: overlay.scrollable_overflow.width
			height: overlay.scrollable_overflow.height
		}
		scroll_offset: b.current_scroll_offset(overlay)
		metrics: metrics
		with_gutter: with_gutter
		chrome_mirrored: overlay.chrome_mirrored
		has_resizer: overlay.has_resizer
		has_other_scrollbar: if direction == .vertical {
			overlay.can_scroll_horizontally
		} else {
			overlay.can_scroll_vertically
		}
	}
}

// Direct translation of PaintableBox::resizer_contains(), also consumed by
// ResizeHandle::contains(). The visible grip grows through the adjacent border
// on the physical end side and through the bottom border.
fn (b &BlockBox) compatibility_resizer_contains(position painting.Point,
	overlay CompatibilityOverlayData, metrics painting.ChromeMetrics) bool {
	mut rect := painting.paintable_box_absolute_resizer_rect(b.compatibility_absolute_padding_rect(), overlay.has_resizer, overlay.chrome_mirrored, metrics) or { return false }
	rect = if overlay.chrome_mirrored {
		rect.inflated(0, 0, b.border.bottom, b.border.left)
	} else {
		rect.inflated(0, b.border.right, b.border.bottom, 0)
	}
	return rect.contains(position)
}

struct CompatibilityFormControlState {
	checked       bool
	indeterminate bool
	enabled       bool = true
	activated     bool
}

// CheckBoxPaintable and RadioButtonPaintable read HTMLInputElement state when
// they paint, rather than copying the checked content attribute during layout.
// Keep the BlockBox values only as the detached compatibility fallback.
fn (b &BlockBox) current_form_control_state() CompatibilityFormControlState {
	if b.node_id != 0 {
		if node := dom.Node.from_unique_id(dom.UniqueNodeID(b.node_id)) {
			if element := node.as_element() {
				if element.is_html_element() && element.local_name() == 'input' {
					input := unsafe { &dom.HTMLInputElement(element) }
					return CompatibilityFormControlState{
						checked: input.checked()
						indeterminate: input.indeterminate()
						enabled: !element.is_actually_disabled()
						activated: element.is_being_activated()
					}
				}
			}
		}
	}
	return CompatibilityFormControlState{
		checked: b.media().form_control_checked
		indeterminate: b.media().form_control_indeterminate
		enabled: b.media().form_control_enabled
		activated: b.media().form_control_activated
	}
}

fn lightened_paint_color(color css.Color) css.Color {
	return css.Color{
		r: u8(math.min(255.0, f64(color.r) * 1.2))
		g: u8(math.min(255.0, f64(color.g) * 1.2))
		b: u8(math.min(255.0, f64(color.b) * 1.2))
		a: color.a
	}
}

fn append_scrollbar_overlay_command(mut commands []PaintCommand, data painting.ScrollbarData, overlay CompatibilityOverlayData, opacity f64, direction painting.ScrollDirection, recorded_scroll_offset f64) {
	// PaintableBox rounds both retained scrollbar rectangles at the recorder
	// boundary. Leaving the proportional thumb length fractional shifts the
	// antialiased end cap even when all surrounding layout geometry is exact.
	converter := painting.new_device_pixel_converter(1.0) or { return }
	rounded_gutter := converter.rounded_device_rect(data.gutter_rect)
	gutter := painting.Rect{rounded_gutter.x, rounded_gutter.y, rounded_gutter.width, rounded_gutter.height}
	rounded_thumb := converter.rounded_device_rect(data.thumb_rect)
	thumb := painting.Rect{rounded_thumb.x, rounded_thumb.y, rounded_thumb.width, rounded_thumb.height}
	// Scrollbar::is_enlarged() is false until pointer interaction enlarges it,
	// so the ordinary overlay has no gutter. Preserve the gutter path for data
	// produced by that translated geometry helper as the interaction layer grows.
	if gutter.width > 0 && gutter.height > 0 {
		commands << PaintCommand{
			kind: 'fill_rect'
			x: gutter.x
			y: gutter.y
			width: gutter.width
			height: gutter.height
			color: overlay.scrollbar_track_color.serialize()
			scrollbar_axis: if direction == .vertical { 'vertical' } else { 'horizontal' }
			force_dark_role: .background
			force_dark_role_set: true
			opacity: opacity
		}
	}
	thumb_color := overlay.scrollbar_thumb_color
	// SkRRect normalizes the player's width/2 radius against the short axis.
	// DisplayListPlayerSkia constructs the rrect with width/2; SkRRect itself
	// scales oversized horizontal radii for a short horizontal scrollbar.
	radius := thumb.width / 2.0
	radii := BoxRadii{
		top_left: CornerRadius{radius, radius}
		top_right: CornerRadius{radius, radius}
		bottom_right: CornerRadius{radius, radius}
		bottom_left: CornerRadius{radius, radius}
	}
	commands << PaintCommand{
		kind: 'fill_rounded_rect'
		x: thumb.x
		y: thumb.y
		width: thumb.width
		height: thumb.height
		color: thumb_color.serialize()
		force_dark_role: .background
		force_dark_role_set: true
		opacity: opacity
		corner_radii: radii
		scrollbar_axis: if direction == .vertical { 'vertical' } else { 'horizontal' }
		scrollbar_thumb_travel_ratio: data.thumb_travel_to_scroll_ratio
		scrollbar_recorded_scroll_offset: recorded_scroll_offset
	}
	commands << PaintCommand{
		kind: 'stroke_rounded_rect'
		x: thumb.x
		y: thumb.y
		width: thumb.width
		height: thumb.height
		color: lightened_paint_color(thumb_color).serialize()
		force_dark_role: .background
		force_dark_role_set: true
		opacity: opacity
		radius: radius
		stroke_width: 1
		scrollbar_axis: if direction == .vertical { 'vertical' } else { 'horizontal' }
		scrollbar_thumb_travel_ratio: data.thumb_travel_to_scroll_ratio
		scrollbar_recorded_scroll_offset: recorded_scroll_offset
	}
}

fn append_resizer_line_command(mut commands []PaintCommand, from_x f64, from_y f64, to_x f64, to_y f64, color css.Color, opacity f64) {
	commands << PaintCommand{
		kind: 'draw_line'
		x: math.min(from_x, to_x)
		y: math.min(from_y, to_y)
		width: math.abs(from_x - to_x)
		height: math.abs(from_y - to_y)
		color: color.serialize()
		force_dark_role: .foreground
		force_dark_role_set: true
		opacity: opacity
		points: [from_x, from_y, to_x, to_y]
		stroke_width: 1
	}
}

fn (b &BlockBox) append_overlay_commands(mut commands []PaintCommand, metrics painting.ChromeMetrics, opacity f64) {
	overlay := b.overlay or { return }
	padding_rect := b.compatibility_absolute_padding_rect()
	paint_scrollbars := !b.is_viewport_scroller || painting.should_paint_viewport_scrollbars()
	if paint_scrollbars && overlay.scrollbar_width != .none_ {
		// PaintableBox::paint visits vertical before horizontal.
		if overlay.can_scroll_vertically {
			input := b.compatibility_scrollbar_geometry_input(overlay, .vertical, metrics, b.vertical_scrollbar.is_enlarged())
			if data := painting.paintable_box_compute_scrollbar_data(input) {
				append_scrollbar_overlay_command(mut commands, data, overlay, opacity, .vertical, input.scroll_offset.y)
			}
		}
		if overlay.can_scroll_horizontally {
			input := b.compatibility_scrollbar_geometry_input(overlay, .horizontal, metrics, b.horizontal_scrollbar.is_enlarged())
			if data := painting.paintable_box_compute_scrollbar_data(input) {
				append_scrollbar_overlay_command(mut commands, data, overlay, opacity, .horizontal, input.scroll_offset.x)
			}
		}
	}

	if !overlay.has_resizer {
		return
	}
	if b.snaps_background_rect && b.layout_handle != unsafe { nil } {
		scale := unsafe { &Node(b.layout_handle) }.document().layout_coordinate_scale()
		append_chromium_resizer(mut commands, LayoutRect{padding_rect.x, padding_rect.y,
			padding_rect.width, padding_rect.height}, overlay.chrome_mirrored, scale, opacity)
		return
	}
	// Translation of the overlay gripper loop in PaintableBox::paint(). Device
	// scale is one in this display list, so the rounded 12px box becomes the same
	// 8px inner line area.
	resizer_rect := painting.paintable_box_absolute_resizer_rect(padding_rect, overlay.has_resizer, overlay.chrome_mirrored, metrics) or { return }
	padding := metrics.resize_gripper_padding
	mut resizer_x := resizer_rect.x
	resizer_x += padding + if overlay.chrome_mirrored { padding / 2.0 } else { -padding / 2.0 }
	resizer_y := resizer_rect.y + padding - padding / 2.0
	resizer_size := math.max(0.0, resizer_rect.width - 2.0 * padding)
	third := int(resizer_size) / 3
	if third <= 0 {
		return
	}
	light := css.Color{255, 255, 255, 100}
	dark := css.Color{0, 0, 0, 100}
	for step := third - 1; step < int(resizer_size); step += third {
		from_x := if overlay.chrome_mirrored {
			resizer_x + f64(step)
		} else {
			resizer_x + resizer_size - f64(step)
		}
		to_x := if overlay.chrome_mirrored { resizer_x } else { resizer_x + resizer_size }
		bottom := resizer_y + resizer_size
		append_resizer_line_command(mut commands, from_x, bottom, to_x, bottom - f64(step), light, opacity)
		from_x_dark := if overlay.chrome_mirrored {
			resizer_x + f64(step + 1)
		} else {
			resizer_x + resizer_size - f64(step + 1)
		}
		append_resizer_line_command(mut commands, from_x_dark, bottom, to_x, bottom - f64(step + 1), dark, opacity)
	}
}

fn collect_table_cells(box &BlockBox, mut cells []painting.TableCellPaintData) {
	for child_index := 0; child_index < box.children.len; child_index++ {
		child := unsafe { &box.children[child_index] }
		if child.table_cell {
			coordinates := child.table_cell_coordinates or { continue }
			borders := child.table_cell_borders or { continue }
			border_rect := child.border_box()
			radii := effective_box_radii(child.decorations().border_radii, child.decorations().border_radius, border_rect.width, border_rect.height)
			cells << painting.TableCellPaintData{
				coordinates: *coordinates
				rect: painting.Rect{border_rect.x, border_rect.y, border_rect.width, border_rect.height}
				borders: *borders
				radii: painting.BorderRadiiData{
					top_left: painting.BorderRadiusData{radii.top_left.x, radii.top_left.y}
					top_right: painting.BorderRadiusData{radii.top_right.x, radii.top_right.y}
					bottom_right: painting.BorderRadiusData{radii.bottom_right.x, radii.bottom_right.y}
					bottom_left: painting.BorderRadiusData{radii.bottom_left.x, radii.bottom_left.y}
				}
				empty_cells_hide: child.empty_cells_hide
				has_children: child.has_layout_children
			}
			// collect_cell_boxes() stops at cells, so a nested table is painted by
			// its own principal box rather than by the outer table.
			continue
		}
		collect_table_cells(child, mut cells)
	}
}

fn painting_color_string(color painting.Color) string {
	return css.Color{color.r, color.g, color.b, color.a}.serialize()
}

fn painting_line_style_string(style painting.LineStyle) string {
	return match style {
		.dotted { 'dotted' }
		.dashed { 'dashed' }
		else { 'solid' }
	}
}

enum TableRoundedClipEdge {
	left
	right
	top
	bottom
}

fn table_clip_point_inside(x f64, y f64, rect painting.IntRect, edge TableRoundedClipEdge) bool {
	return match edge {
		.left { x >= f64(rect.left()) }
		.right { x <= f64(rect.right()) }
		.top { y >= f64(rect.top()) }
		.bottom { y <= f64(rect.bottom()) }
	}
}

fn table_clip_intersection(from_x f64, from_y f64, to_x f64, to_y f64, rect painting.IntRect, edge TableRoundedClipEdge) (f64, f64) {
	if edge == .left || edge == .right {
		x := if edge == .left { f64(rect.left()) } else { f64(rect.right()) }
		t := if to_x != from_x { (x - from_x) / (to_x - from_x) } else { 0.0 }
		return x, from_y + (to_y - from_y) * t
	}
	y := if edge == .top { f64(rect.top()) } else { f64(rect.bottom()) }
	t := if to_y != from_y { (y - from_y) / (to_y - from_y) } else { 0.0 }
	return from_x + (to_x - from_x) * t, y
}

fn table_clip_polygon_edge(points []f64, rect painting.IntRect, edge TableRoundedClipEdge) []f64 {
	if points.len < 4 {
		return []f64{}
	}
	mut result := []f64{}
	mut from_x := points[points.len - 2]
	mut from_y := points[points.len - 1]
	mut from_inside := table_clip_point_inside(from_x, from_y, rect, edge)
	for index := 0; index + 1 < points.len; index += 2 {
		to_x := points[index]
		to_y := points[index + 1]
		to_inside := table_clip_point_inside(to_x, to_y, rect, edge)
		if to_inside != from_inside {
			intersection_x, intersection_y := table_clip_intersection(from_x, from_y, to_x, to_y, rect, edge)
			result << intersection_x
			result << intersection_y
		}
		if to_inside {
			result << to_x
			result << to_y
		}
		from_x = to_x
		from_y = to_y
		from_inside = to_inside
	}
	return result
}

// The active backend consumes the DisplayList clip produced by
// paint_all_borders() as explicit geometry. This is the Sutherland-Hodgman
// intersection of the rounded outer border path and one painted border side.
fn clipped_table_border_points(clip painting.AddRoundedRectClip, rect painting.IntRect) []f64 {
	radii := BoxRadii{
		top_left: CornerRadius{clip.corner_radii.top_left.horizontal, clip.corner_radii.top_left.vertical}
		top_right: CornerRadius{clip.corner_radii.top_right.horizontal, clip.corner_radii.top_right.vertical}
		bottom_right: CornerRadius{clip.corner_radii.bottom_right.horizontal, clip.corner_radii.bottom_right.vertical}
		bottom_left: CornerRadius{clip.corner_radii.bottom_left.horizontal, clip.corner_radii.bottom_left.vertical}
	}
	mut points := rounded_rect_points(clip.border_rect.x, clip.border_rect.y, clip.border_rect.width, clip.border_rect.height, radii)
	for edge in [TableRoundedClipEdge.left, .right, .top, .bottom] {
		points = table_clip_polygon_edge(points, rect, edge)
	}
	return points
}

fn canvas_path_from_painting_path(path painting.ClipPathVisualData) html.CanvasGfxPath {
	mut result := html.CanvasGfxPath{}
	for segment in path.segments {
		point := html.FloatPoint{segment.point.x, segment.point.y}
		match segment.kind {
			.move_to { result.move_to(point) }
			.line_to { result.line_to(point) }
			.quadratic_bezier_curve_to {
				result.quadratic_bezier_curve_to(html.FloatPoint{segment.control_point_0.x, segment.control_point_0.y}, point)
			}
			.cubic_bezier_curve_to {
				result.cubic_bezier_curve_to(html.FloatPoint{segment.control_point_0.x, segment.control_point_0.y}, html.FloatPoint{segment.control_point_1.x, segment.control_point_1.y}, point)
			}
			.elliptical_arc_to {
				result.elliptical_arc_to(point, html.FloatSize{segment.radii.width, segment.radii.height}, segment.rotation, segment.large_arc, segment.sweep)
			}
			.close_path { result.close() }
		}
	}
	return result
}

fn painting_path_svg(path painting.ClipPathVisualData) string {
	mut builder := strings.new_builder(path.segments.len * 24)
	for segment in path.segments {
		match segment.kind {
			.move_to {
				builder.write_string('M ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)} ')
			}
			.line_to {
				builder.write_string('L ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)} ')
			}
			.quadratic_bezier_curve_to {
				builder.write_string('Q ${fmt_px(segment.control_point_0.x)} ${fmt_px(segment.control_point_0.y)} ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)} ')
			}
			.cubic_bezier_curve_to {
				builder.write_string('C ${fmt_px(segment.control_point_0.x)} ${fmt_px(segment.control_point_0.y)} ${fmt_px(segment.control_point_1.x)} ${fmt_px(segment.control_point_1.y)} ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)} ')
			}
			.elliptical_arc_to {
				builder.write_string('A ${fmt_px(segment.radii.width)} ${fmt_px(segment.radii.height)} ${fmt_px(segment.rotation)} ${if segment.large_arc {
					1
				} else {
					0
				}} ${if segment.sweep { 1 } else { 0 }} ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)} ')
			}
			.close_path { builder.write_string('Z ') }
		}
	}
	return builder.str().trim_space()
}

fn flattened_painting_path(path painting.ClipPathVisualData) [][]f64 {
	mut result := [][]f64{}
	for polygon in html.canvas_gfx_path_flattened_polygons(canvas_path_from_painting_path(path)) {
		mut points := []f64{cap: polygon.len * 2}
		for point in polygon {
			points << point.x
			points << point.y
		}
		result << points
	}
	return result
}

fn transport_radii_from_painting(radii painting.CornerRadii) BoxRadii {
	return BoxRadii{
		top_left: CornerRadius{radii.top_left.horizontal, radii.top_left.vertical}
		top_right: CornerRadius{radii.top_right.horizontal, radii.top_right.vertical}
		bottom_right: CornerRadius{radii.bottom_right.horizontal, radii.bottom_right.vertical}
		bottom_left: CornerRadius{radii.bottom_left.horizontal, radii.bottom_left.vertical}
	}
}

fn layout_rect_from_painting_int_rect(rect painting.IntRect) LayoutRect {
	return LayoutRect{rect.x, rect.y, rect.width, rect.height}
}

fn set_recording_clip_for_range(mut commands []PaintCommand, start int, end int,
	clip painting.IntRect) {
	resolved := layout_rect_from_painting_int_rect(clip)
	for index := start; index < end; index++ {
		commands[index].recording_clip = resolved
	}
}

fn set_force_dark_role_for_range(mut commands []PaintCommand, start int, end int,
	role painting.ForceDarkRole) {
	for index := start; index < end; index++ {
		commands[index].force_dark_role = role
		commands[index].force_dark_role_set = true
	}
}

fn set_force_dark_backdrop_for_range(mut commands []PaintCommand, start int, end int,
	color css.Color) {
	backdrop := painting.Color{color.r, color.g, color.b, color.a}
	for index := start; index < end; index++ {
		commands[index].force_dark_backdrop = backdrop
	}
}

fn append_painting_display_command(mut commands []PaintCommand,
	display_command painting.DisplayListCommand, opacity f64) {
	match display_command {
		painting.DrawRect {
			commands << PaintCommand{
				kind: 'stroke_rounded_rect'
				x: display_command.rect.x
				y: display_command.rect.y
				width: display_command.rect.width
				height: display_command.rect.height
				color: painting_color_string(display_command.color)
				opacity: opacity
				stroke_width: 1
			}
		}
		painting.FillRect {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: display_command.rect.x
				y: display_command.rect.y
				width: display_command.rect.width
				height: display_command.rect.height
				color: painting_color_string(display_command.color)
				opacity: opacity
			}
		}
		painting.FillRoundedRect {
			commands << PaintCommand{
				kind: 'fill_rounded_rect'
				x: display_command.rect.x
				y: display_command.rect.y
				width: display_command.rect.width
				height: display_command.rect.height
				color: painting_color_string(display_command.color)
				opacity: opacity
				corner_radii: transport_radii_from_painting(display_command.corner_radii)
			}
		}
		painting.FillPath {
			polygons := flattened_painting_path(display_command.path)
			commands << PaintCommand{
				kind: 'draw_svg_path'
				x: display_command.path_bounding_rect.x
				y: display_command.path_bounding_rect.y
				width: display_command.path_bounding_rect.width
				height: display_command.path_bounding_rect.height
				color: painting_color_string(display_command.color)
				opacity: opacity * display_command.opacity
				svg_data: &PaintSVGPathData{
					path: painting_path_svg(display_command.path)
					path_data: compatibility_pack_clip_path_segments(display_command.path)
					path_polygons: polygons
					fill_even_odd: display_command.winding_rule == .even_odd
				}
				points: if polygons.len > 0 { polygons[0] } else { []f64{} }
			}
		}
		painting.DrawEllipse {
			commands << PaintCommand{
				kind: 'stroke_ellipse'
				x: display_command.rect.x
				y: display_command.rect.y
				width: display_command.rect.width
				height: display_command.rect.height
				color: painting_color_string(display_command.color)
				opacity: opacity
				stroke_width: display_command.thickness
			}
		}
		painting.FillEllipse {
			commands << PaintCommand{
				kind: 'fill_ellipse'
				x: display_command.rect.x
				y: display_command.rect.y
				width: display_command.rect.width
				height: display_command.rect.height
				color: painting_color_string(display_command.color)
				opacity: opacity
			}
		}
		painting.DrawLine {
			commands << PaintCommand{
				kind: 'draw_line'
				x: display_command.from.x
				y: display_command.from.y
				width: display_command.to.x - display_command.from.x
				height: display_command.to.y - display_command.from.y
				color: painting_color_string(display_command.color)
				opacity: opacity
				points: [f64(display_command.from.x), f64(display_command.from.y),
					f64(display_command.to.x), f64(display_command.to.y)]
				stroke_width: display_command.thickness
				line_style: painting_line_style_string(display_command.line_style)
			}
		}
		painting.ApplyBackdropFilter {
			commands << PaintCommand{
				kind: 'apply_backdrop_filter'
				x: display_command.backdrop_region.x
				y: display_command.backdrop_region.y
				width: display_command.backdrop_region.width
				height: display_command.backdrop_region.height
				corner_radii: transport_radii_from_painting(display_command.corner_radii)
				backdrop_filter_data: retained_paint_backdrop_filter(display_command.filter)
				opacity: opacity
			}
		}
		else {}
	}
}

// Direct translation of PaintableBox::paint_backdrop_filter(). The display-list
// command is recorded before the background and box-shadow commands and is
// clipped to the normalized border radii by the player.
fn paintable_box_paint_backdrop_filter(mut commands []PaintCommand, box &BlockBox,
	border_rect LayoutRect, border_radii BoxRadii, opacity f64) {
	filter := box.filters().backdrop_filter.to_gfx_filter(1.0) or { return }
	region := compatibility_rounded_int_rect(border_rect)
	if region.is_empty() {
		return
	}
	start := commands.len
	append_painting_display_command(mut commands, painting.ApplyBackdropFilter{
		backdrop_region: region
		corner_radii: painting_radii_from_transport(border_radii)
		filter: filter
	}, opacity)
	if commands.len > start {
		commands[start].backdrop_source_outside_filter = box.filters().filter.to_gfx_filter(1.0) != none
	}
}

fn (b &BlockBox) append_table_border_commands(mut commands []PaintCommand, opacity f64) {
	if !b.table_inside {
		return
	}
	mut cells := []painting.TableCellPaintData{}
	collect_table_cells(b, mut cells)
	converter := painting.new_device_pixel_converter(1.0) or { return }
	mut rounded_clip := ?painting.AddRoundedRectClip(none)
	start := commands.len
	for display_command in painting.paint_table_borders(cells, b.uses_collapsed_borders, converter) {
		match display_command {
			painting.Save {
				rounded_clip = none
			}
			painting.AddRoundedRectClip {
				rounded_clip = display_command
			}
			painting.Restore {
				rounded_clip = none
			}
			painting.FillRect {
				points := if clip := rounded_clip {
					clipped_table_border_points(clip, display_command.rect)
				} else {
					[]f64{}
				}
				if rounded_clip != none && points.len < 6 {
					continue
				}
				commands << PaintCommand{
					kind: if points.len > 0 { 'fill_polygon' } else { 'fill_rect' }
					x: display_command.rect.x
					y: display_command.rect.y
					width: display_command.rect.width
					height: display_command.rect.height
					color: painting_color_string(display_command.color)
					opacity: opacity
					points: points
				}
			}
			painting.DrawLine {
				append_painting_display_command(mut commands, display_command, opacity)
			}
			painting.FillPath {
				append_painting_display_command(mut commands, display_command, opacity)
			}
			else {}
		}
	}
	set_force_dark_role_for_range(mut commands, start, commands.len, .border)
}

// Build the display list for this box tree: for each box in paint order — a background fill (when the
// background-color isn't transparent) over its border box, then one fill per non-zero border edge,
// then a draw-text command per inline fragment in that fragment's color. This is the layout →
// rendering bridge.
//
fn (b &BlockBox) flat_paint_commands(entries []PaintOrderEntry) []PaintCommand {
	return b.flat_paint_commands_for_entries(entries, []bool{})
}

// Generate only the selected paintables when refreshing invalid cache entries.
// An empty selector is the initial full-cache path.
fn (b &BlockBox) flat_paint_commands_for_entries(entries []PaintOrderEntry, selected []bool) []PaintCommand {
	mut recorder := PaintPhaseCommandRecorder{}
	return b.record_paint_commands_for_entries(entries, selected, mut recorder)
}

// The flat compatibility API retains its complete vector. Retained painting
// publishes one entry at a time instead: its temporary buffer is reused, and
// no document-sized second copy needs to survive until cache construction ends.
fn (b &BlockBox) record_paint_commands_for_entries(entries []PaintOrderEntry, selected []bool,
	mut recorder PaintPhaseCommandRecorder) []PaintCommand {
	mut commands := []PaintCommand{}
	metrics := painting.new_chrome_metrics(1.0) or { return commands }
	for entry_index, entry in entries {
		platform.cooperative_work_checkpoint()
		if selected.len > 0 && !selected[entry_index] {
			continue
		}
		box := entry.box
		// A `visibility: hidden` box takes up space but paints nothing (its visible descendants are
		// separate paint-order entries and still paint).
		if !box.visible {
			continue
		}
		command_start := commands.len
		opacity := entry.opacity
		empty_cell_hidden := box.table_cell && box.empty_cells_hide && !box.has_layout_children
		border_left := box.x - box.padding.left - box.border.left
		border_top := box.y - box.padding.top - box.border.top
		border_width := box.width + box.padding.left + box.padding.right + box.border.left + box.border.right
		border_height := box.height + box.padding.top + box.padding.bottom + box.border.top + box.border.bottom
		border_rect := LayoutRect{border_left, border_top, border_width, border_height}
		native_text_control := if !empty_cell_hidden && !box.skip_background_paint {
			chromium_native_text_control(box)
		} else { '' }
		background_border_rect := if box.canvas().paints_canvas_background && box.canvas().canvas_width > 0 && box.canvas().canvas_height > 0 {
			rect_union(border_rect, LayoutRect{box.canvas().canvas_x, box.canvas().canvas_y, box.canvas().canvas_width, box.canvas().canvas_height})
		} else if box.snaps_background_rect {
			pixel_snapped_layout_rect(border_rect)
		} else {
			border_rect
		}
		// StackingContext::paint() and SVGSVGPaintable::paint_svg_box() record a
		// transparent rectangle for an SVG filter even when the source paints no
		// pixels. It expands the effect input to the target bounds so feFlood and
		// feImage can generate content for otherwise-empty elements.
		if svg_filter_bounds := box.filters().filter.svg_filter_bounds() {
			if !svg_filter_bounds.is_empty() {
				commands << PaintCommand{
					kind: 'fill_rect_transparent'
					x: svg_filter_bounds.x
					y: svg_filter_bounds.y
					width: svg_filter_bounds.width
					height: svg_filter_bounds.height
					color: 'rgba(0 0 0 / 0)'
					opacity: opacity
				}
			}
		}

		// All four radii have already undergone CSS overlap reduction; the scalar is retained for the
		// compact uniform-circle renderer path.
		box_radii := effective_box_radii(box.decorations().border_radii, box.decorations().border_radius, border_width, border_height)
		uniform_circle_radii := box_radii_are_uniform_circles(box_radii)
		radius := if uniform_circle_radii { box_radii.top_left.x } else { 0.0 }
		rounded_points := if !box_radii_are_zero(box_radii) && !uniform_circle_radii {
			rounded_rect_points(border_left, border_top, border_width, border_height, box_radii)
		} else {
			[]f64{}
		}
		// The resolved shadow list is immutable while recording. Share its backing
		// store, as PaintableBox does upstream, instead of copying every layer on
		// every repaint. The empty-list compatibility case creates its own array,
		// including when the published empty list has spare backing capacity.
		mut box_shadows := unsafe { box.decorations().shadows }
		if box_shadows.len == 0 {
			if shadow := box.decorations().shadow {
				box_shadows = [shadow]
			}
		}
		background_paint_start := commands.len
		if !empty_cell_hidden {
			paintable_box_paint_backdrop_filter(mut commands, box, border_rect, box_radii, opacity)
		}
		if box.snaps_background_rect && box.background_color.a == 255
			&& !box.skip_background_paint && !empty_cell_hidden
			&& box.decorations().background_color_clip == 'border-box' && box_shadows.any(!it.inset) {
			outer_start := commands.len
			paintable_box_paint_box_shadow(mut commands, box_shadows.filter(!it.inset),
				box.border, effective_border_colors(box.border_colors, box.border_color),
				box.border_styles, box_radii, border_rect, border_rect, opacity)
			chromium_inset_opaque_shadow_clips(mut commands, outer_start, box.layout_handle)
			box_shadows = box_shadows.filter(it.inset)
		}
		background_isolated := box.decorations().background_images.any(background_image_layer_blend_mode(it) != .normal)
		needs_background_text_clip := box.decorations().background_color_clip == 'text'
			&& !box.canvas().paints_canvas_background && !box.skip_background_paint && !empty_cell_hidden
		if needs_background_text_clip {
			commands << PaintCommand{
				kind: 'begin_background_text_clip'
				x: background_border_rect.x
				y: background_border_rect.y
				width: background_border_rect.width
				height: background_border_rect.height
				text_clip_runs: compute_text_clip_paths(box)
			}
		}
		if background_isolated && !box.skip_background_paint && !empty_cell_hidden {
			commands << PaintCommand{ kind: 'begin_background_blend_group' }
		}
		mut color_rect := background_box_rect_from_border(box, box.decorations().background_color_clip, background_border_rect)
		mut color_radii := background_box_radii(box, box.decorations().background_color_clip, box_radii, color_rect)
		if box.snaps_background_rect && box.decorations().background_color_clip == 'border-box'
			&& !box.canvas().paints_canvas_background && !box_radii_are_zero(color_radii) {
			color_rect, color_radii = chromium_background_under_opaque_border(color_rect,
				color_radii, box.border, effective_border_colors(box.border_colors, box.border_color), box.border_styles)
		}
		if native_text_control != '' {
			scale := unsafe { &Node(box.layout_handle) }.document().layout_coordinate_scale()
			append_chromium_native_text_control(mut commands, border_rect, native_text_control, scale, opacity)
		} else if !box.skip_background_paint && !empty_cell_hidden && box.background_color.a > 0 && !box.canvas().paints_canvas_background && !box_radii_are_zero(color_radii) {
			if box_radii_are_uniform_circles(color_radii) {
				commands << PaintCommand{
					kind: 'fill_rect'
					x: color_rect.x
					y: color_rect.y
					width: color_rect.width
					height: color_rect.height
					color: box.background_color.serialize()
					srgb_color_data: box.background_srgb_color
					opacity: opacity
					radius: color_radii.top_left.x
				}
			} else {
				commands << PaintCommand{
					kind: 'fill_rounded_rect'
					x: color_rect.x
					y: color_rect.y
					width: color_rect.width
					height: color_rect.height
					color: box.background_color.serialize()
					srgb_color_data: box.background_srgb_color
					opacity: opacity
					corner_radii: color_radii
				}
			}
		} else if !box.skip_background_paint && !empty_cell_hidden && box.background_color.a > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: color_rect.x
				y: color_rect.y
				width: color_rect.width
				height: color_rect.height
				color: box.background_color.serialize()
					srgb_color_data: box.background_srgb_color
				opacity: opacity
			}
		}
		// Compatibility-only boxes still carry their single parsed gradient separately. Typed layout
		// retains gradients in the ordered image layer list below, as BackgroundPainting does.
		if !box.skip_background_paint && !empty_cell_hidden {
			has_retained_gradient_layer := box.decorations().background_images.any(it.gradient_source != none)
			if grad := box.decorations().background_gradient {
				if !has_retained_gradient_layer {
					gradient_points := if box.canvas().paints_canvas_background {
						[]f64{}
					} else {
						rounded_points
					}
					commands << PaintCommand{
						kind: 'fill_gradient'
						x: background_border_rect.x
						y: background_border_rect.y
						width: background_border_rect.width
						height: background_border_rect.height
						opacity: opacity
						radius: if box.canvas().paints_canvas_background { 0.0 } else { radius }
						gradient: grad
						points: gradient_points
					}
				}
			}
			// Background layers are listed front-to-back in CSS and painted back-to-front.
			background_scroll_offset := if overlay := box.overlay {
				box.current_scroll_offset(overlay)
			} else {
				painting.Point{}
			}
			for layer_index := box.decorations().background_images.len - 1; layer_index >= 0; layer_index-- {
				layer := box.decorations().background_images[layer_index]
				origin := background_box_rect(box, layer.origin)
				image_destination := if box.snaps_background_rect && layer.clip == 'border-box'
					&& !box.canvas().paints_canvas_background && !box.table_cell
					&& !box.uses_collapsed_borders {
					?LayoutRect(chromium_background_image_destination(background_border_rect,
						box.border, effective_border_colors(box.border_colors, box.border_color), box.border_styles))
				} else { none }
				mut clip := background_box_rect_from_border(box, layer.clip, background_border_rect)
				mut clip_radii := if box.canvas().paints_canvas_background {
					BoxRadii{}
				} else {
					background_box_radii(box, layer.clip, box_radii, clip)
				}
				if box.snaps_background_rect && layer.clip == 'border-box'
					&& !box.canvas().paints_canvas_background && !box_radii_are_zero(clip_radii) {
					clip, clip_radii = chromium_background_under_opaque_border(clip,
						clip_radii, box.border, effective_border_colors(box.border_colors, box.border_color), box.border_styles)
				}
				if command := background_layer_command(layer, origin, clip, clip_radii, opacity, if box.canvas().paints_canvas_background {
					0.0
				} else {
					radius
				}, if box.canvas().paints_canvas_background { []f64{} } else { rounded_points }, background_scroll_offset, box.replaced_image_rendering, box.fixed_background_visual_context, LayoutRect{
					x: 0
					y: 0
					width: b.canvas().viewport_width
					height: b.canvas().viewport_height
				}, box.snaps_background_rect, image_destination) {
					// Canvas images move with the viewport's scroll frame. The
					// canvas color and fixed layers stay in the box's own context.
					commands << if box.canvas().paints_canvas_background && layer.attachment == 'scroll' {
						PaintCommand{ ...command, visual_context_index: box.canvas_background_scroll_context }
					} else { command }
					if box.snaps_background_rect {
						chromium_pair_background_image_color(mut commands)
					}
				}
			}
		}
		if background_isolated && !box.skip_background_paint && !empty_cell_hidden {
			commands << PaintCommand{ kind: 'end_background_blend_group' }
		}
		if needs_background_text_clip {
			commands << PaintCommand{ kind: 'end_background_text_clip' }
		}
		if fieldset := box.media().fieldset_paintable {
			converter := painting.new_device_pixel_converter(1.0) or { return commands }
			if clip := fieldset.background_clip_rect(converter) {
				set_recording_clip_for_range(mut commands, background_paint_start, commands.len, clip)
			}
		}
		if !empty_cell_hidden {
			paintable_box_paint_box_shadow(mut commands, box_shadows, box.border, effective_border_colors(box.border_colors, box.border_color), box.border_styles, box_radii, border_rect, LayoutRect{
				x: border_left + box.border.left
				y: border_top + box.border.top
				width: non_negative(border_width - box.border.left - box.border.right)
				height: non_negative(border_height - box.border.top - box.border.bottom)
			}, opacity)
		}
		foreground_replaced_start := commands.len
		mut drew_image_fallback := false
		if paintable := box.media().replaced_image_paintable {
			if paintable.broken_image_fallback_scale > 0 {
				append_chromium_broken_image(mut commands, paintable, opacity)
				drew_image_fallback = true
			}
		}
		if (box.media().replaced_image_url != '' || box.media().replaced_image_bitmap != none)
			&& box.media().nested_viewport_document == none && !drew_image_fallback {
			commands << PaintCommand{
				kind: if box.media().replaced_image_paintable != none {
					'draw_replaced_image'
				} else if box.media().is_svg_image { 'draw_svg_image' } else { 'draw_background_image' }
				x: box.x
				y: box.y
				width: box.width
				height: box.height
				opacity: opacity
				image_data: &PaintImageData{
					image_url: box.media().replaced_image_url
					image_repeat_x: 'no-repeat'
					image_repeat_y: 'no-repeat'
					image_size: box.media().replaced_image_size
					image_position_x: box.media().replaced_image_position_x
					image_position_y: box.media().replaced_image_position_y
					image_rendering: box.replaced_image_rendering
					image_clip_x: box.x
					image_clip_y: box.y
					image_clip_width: box.width
					image_clip_height: box.height
				}
				replaced_image_bitmap: box.media().replaced_image_bitmap
				image_paintable: box.media().replaced_image_paintable
				force_dark_role: .background
				force_dark_role_set: true
			}
		}
		if bitmap := box.media().canvas_bitmap {
			if canvas_paintable := box.media().canvas_paintable {
				commands << PaintCommand{
					kind: 'draw_canvas'
					x: box.x
					y: box.y
					width: box.width
					height: box.height
					opacity: opacity
					canvas_bitmap: bitmap
					canvas_paintable: canvas_paintable
				}
			}
		}
		if video_paintable := box.media().video_paintable {
			commands << PaintCommand{
				kind: 'draw_video'
				x: box.x
				y: box.y
				width: box.width
				height: box.height
				opacity: opacity
				video_bitmap: box.media().video_bitmap
				video_frame_source: box.media().video_frame_source
				video_representation: box.media().video_representation
				video_paintable: video_paintable
			}
		}
		if nested_viewport_paintable := box.media().nested_viewport_paintable {
			if hosted_document := box.media().nested_viewport_document {
				if hosted_document.is_render_blocked() {
					continue
				}
				nested_rect := nested_viewport_paintable.nested_rect or {
					nested_viewport_paintable.viewport_rect
				}
				layout_size := nested_viewport_paintable.nested_layout_size or {
					painting.Size{nested_rect.width, nested_rect.height}
				}
				nested_layout := run_document_layout(hosted_document, layout_size.width, layout_size.height) or {
					DocumentLayoutResult{}
				}
				if nested_layout.root != unsafe { nil } {
					mut mutable_hosted_document := unsafe { &dom.Document(hosted_document) }
					// The copied commands below outlive the hosted document's
					// own scenes.
					mark_display_list_scenes_borrowed(hosted_document)
					if nested_display_list := mutable_hosted_document.record_display_list() {
						mut nested_commands := display_list_commands(nested_display_list).clone()
						if nested_viewport_paintable.nested_layout_size != none
							&& layout_size.width > 0 && layout_size.height > 0 {
							// The SVG recording uses the CSS container; the image draw
							// maps that recording onto its snapped destination rectangle.
							scale := [nested_rect.width / layout_size.width, f64(0), 0,
								nested_rect.height / layout_size.height, 0, 0]!
							for index, nested in nested_commands {
								nested_commands[index] = paint_command_for_nested_viewport(nested,
									scale, painting.IntPoint{}, 1)
							}
						}
						commands << PaintCommand{
							kind: 'paint_nested_display_list'
							x: nested_rect.x
							y: nested_rect.y
							width: nested_rect.width
							height: nested_rect.height
							opacity: opacity
							nested_viewport_commands: nested_commands
							nested_viewport_paintable: nested_viewport_paintable
						}
					}
				}
			}
		}
		form_control_state := box.current_form_control_state()
		if box.media().form_control_kind in ['checkbox', 'radio'] {
			mut scale := 1.0
			if box.layout_handle != unsafe { nil } {
				scale = unsafe { &Node(box.layout_handle) }.document().layout_coordinate_scale()
			}
			converter := painting.new_device_pixel_converter(1.0) or { return commands }
			control_rect := painting.centered_form_control_rect(painting.Rect{
				x: box.x
				y: box.y
				width: box.width
				height: box.height
			}, converter)
			if box.snaps_background_rect && box.media().form_control_kind == 'checkbox'
				&& !form_control_state.checked && !form_control_state.indeterminate
				&& form_control_state.enabled && !form_control_state.activated
				&& box.form_control_color_scheme != .dark {
				append_chromium_unchecked_checkbox(mut commands, chromium_snapped_control_rect(box.x,
					box.y, box.width, box.height), scale, opacity)
			} else if box.snaps_background_rect && box.media().form_control_kind == 'checkbox'
				&& form_control_state.checked && !form_control_state.indeterminate
				&& form_control_state.enabled && !form_control_state.activated
				&& box.form_control_color_scheme != .dark && box.form_control_accent_is_auto {
				append_chromium_checked_checkbox(mut commands, chromium_snapped_control_rect(box.x,
					box.y, box.width, box.height), scale, opacity)
			} else {
				input_colors := painting.compute_input_colors(box.form_control_color_scheme, box.form_control_accent_color)
				display_commands := if box.media().form_control_kind == 'checkbox' {
					painting.checkbox_commands(control_rect, form_control_state.checked, form_control_state.indeterminate, form_control_state.enabled, form_control_state.activated, box.form_control_color_scheme, input_colors)
				} else {
					painting.radio_button_commands(control_rect, form_control_state.checked, form_control_state.enabled, form_control_state.activated, box.form_control_color_scheme, input_colors)
				}
				// A control is one upstream display-list replay unit. Keep its overlapping
				// antialiased primitives on one Skia surface so intermediate 8-bit Cocoa
				// composites cannot round the shared edges independently.
				control_start := commands.len
				commands << PaintCommand{
					kind: 'begin_skia_command_group'
					x: control_rect.x
					y: control_rect.y
					width: control_rect.width
					height: control_rect.height
				}
				for display_command in display_commands {
					append_painting_display_command(mut commands, display_command, opacity)
				}
				commands << PaintCommand{ kind: 'end_skia_command_group' }
				if box.media().form_control_kind == 'checkbox' && form_control_state.checked
					&& !form_control_state.indeterminate {
					set_force_dark_role_for_range(mut commands, control_start + 1, control_start + 2,
						.background)
					set_force_dark_role_for_range(mut commands, control_start + 2, control_start + 3,
						.foreground)
				} else {
					set_force_dark_role_for_range(mut commands, control_start + 1, control_start + 2,
						.border)
					set_force_dark_role_for_range(mut commands, control_start + 2, control_start + 3,
						.background)
					if (box.media().form_control_kind == 'checkbox' && form_control_state.indeterminate)
						|| (box.media().form_control_kind == 'radio' && form_control_state.checked) {
						set_force_dark_role_for_range(mut commands, control_start + 3, control_start + 4,
							.foreground)
					}
				}
			}
		}
		foreground_replaced_end := commands.len
		// Translate each border side through Painting's source-shaped BorderPainting paths. Matching
		// colors are batched while each used thickness is represented independently.
		border_start := commands.len
		// PaintableBox::paint() skips ordinary borders for collapsed cells and
		// for the collapsed table principal. Their shared edges are painted below.
		if native_text_control == '' && !box.table_cell && !(box.uses_collapsed_borders && box.table_inside) {
			border_colors := effective_border_colors(box.border_colors, box.border_color)
			if fieldset := box.media().fieldset_paintable {
				converter := painting.new_device_pixel_converter(1.0) or { return commands }
				borders := painting_borders_from_transport(box.border, border_colors, box.border_styles)
				for fieldset_command in fieldset.paint(borders, painting_radii_from_transport(box_radii), converter) {
					command_start_index := commands.len
					append_painting_display_command(mut commands, fieldset_command.command, opacity)
					set_force_dark_role_for_range(mut commands, command_start_index, commands.len,
						.border)
					if clip := fieldset_command.clip {
						set_recording_clip_for_range(mut commands, command_start_index, commands.len, clip)
					}
				}
			} else if !append_chromium_partial_border(mut commands, box, border_colors,
				box_radii, border_rect, opacity) {
				append_translated_border_commands(mut commands, box.border, border_colors, box.border_styles, box_radii, border_left, border_top, border_width, border_height, opacity, box.snaps_background_rect)
			}
		}
		border_end := commands.len
		chromium_pair_rounded_border_background(mut commands, background_paint_start,
			border_start, border_end)
		table_border_start := commands.len
		box.append_table_border_commands(mut commands, opacity)
		table_border_end := commands.len
		// PaintableBox::paint() inflates the border rect and radii, then sends outlines through the
		// same BorderPainting.cpp dispatcher as ordinary borders.
		outline_start := commands.len
		append_translated_outline_commands(mut commands, box.decorations().outline_width, box.decorations().outline_offset, box.outline_color, box.outline_style, box.outline_is_auto, box_radii, border_left, border_top, border_width, border_height, opacity, box.snaps_background_rect)
		outline_end := commands.len
		foreground_content_start := commands.len
		append_chromium_menu_list_arrow(mut commands, box, border_rect, opacity)
		if box.svg_data != unsafe { nil } && box.svg_path().path.len > 0 {
			commands << PaintCommand{
				kind: 'draw_svg_path'
				x: box.x
				y: box.y
				width: box.width
				height: box.height
				color: box.svg_data.fill_color
				svg_data: normalized_box_svg_path(box.svg_path())
				force_dark_role: .svg
				force_dark_role_set: true
				opacity: opacity
				points: box.svg_data.points
				stroke_color: box.svg_data.stroke_color
				stroke_width: box.svg_data.stroke_width
			}
		}
		if box.marker_shape.len > 0 {
			marker_start := commands.len
			if marker_kind := painting.marker_kind_from_name(box.marker_shape) {
				converter := painting.new_device_pixel_converter(1.0) or { return commands }
				marker := painting.MarkerPaintable{
					marker_rect: painting.Rect{box.x, box.y, box.width, box.height}
					kind: marker_kind
					color: painting.Color{box.text_color.r, box.text_color.g, box.text_color.b, box.text_color.a}
				}
				for display_command in marker.paint(converter) {
					append_painting_display_command(mut commands, display_command, opacity)
				}
			}
			set_force_dark_role_for_range(mut commands, marker_start, commands.len, .list_symbol)
		}
		mut inline_outlines := [][]PaintCommand{}
		for line_index in 0 .. box.lines.len {
			line := unsafe { &box.lines[line_index] }
			fragment_commands := if line.box_decorations.len > 0 {
				mut decorated := line.box_decorations.clone()
				decorated << line.fragments
				inline_fragment_commands(decorated, opacity)
			} else {
				inline_fragment_commands(line.fragments, opacity)
			}
			commands << fragment_commands.decorations
			if fragment_commands.outlines.len > 0 {
				if inline_outlines.len == 0 {
					inline_outlines = [][]PaintCommand{len: box.lines.len}
				}
				inline_outlines[line_index] = fragment_commands.outlines
			}
		}
		for line_index in 0 .. box.lines.len {
			line := unsafe { &box.lines[line_index] }
			// Inline outlines and glyphs retain their per-line order after every
			// line's border phase has completed. This keeps a following line's
			// border from covering the previous line's outline at overlaps.
			if inline_outlines.len > 0 { commands << inline_outlines[line_index] }
			append_text_fragment_commands_with_debug(mut commands, line.fragments, opacity,
				recorder.include_line_box_debug)
		}
		if box.paintable_with_lines {
			if cursor := paint_cursor(box, opacity) {
				commands << cursor
			}
		}
		foreground_content_end := commands.len
		overlay_start := commands.len
		box.append_overlay_commands(mut commands, metrics, opacity)
		overlay_end := commands.len
		for command_index := command_start; command_index < commands.len; command_index++ {
			commands[command_index].transform = box.paint_transform
			chromium_local_background(mut commands[command_index], box)
			data := commands[command_index].local_border_data
			if data != unsafe { nil } {
				commands[command_index].transform = chromium_local_border_transform(data,
					box.paint_transform, box.own_paint_transform)
			}
			commands[command_index].paint_box_index = entry_index
			commands[command_index].force_dark_backdrop = painting.Color{box.background_color.r,
				box.background_color.g, box.background_color.b, box.background_color.a}
			if recording_clip := commands[command_index].recording_clip {
				clip_transform := normalized_affine(box.paint_transform)
				mapped_clip := compatibility_affine_map_rect(clip_transform, recording_clip)
				commands[command_index].has_clip = true
				commands[command_index].clip_x = mapped_clip.x
				commands[command_index].clip_y = mapped_clip.y
				commands[command_index].clip_width = mapped_clip.width
				commands[command_index].clip_height = mapped_clip.height
				commands[command_index].clip_list = &PaintClipList{
					items: [PaintClip{
						rect: recording_clip
						transform: clip_transform
					}]
				}
			}
		}
		for command_index := foreground_replaced_start; command_index < foreground_replaced_end; command_index++ {
			commands[command_index].paint_phase = .foreground
		}
		for command_index := border_start; command_index < border_end; command_index++ {
			commands[command_index].paint_phase = .border
		}
		for command_index := table_border_start; command_index < table_border_end; command_index++ {
			commands[command_index].paint_phase = .table_collapsed_border
		}
		for command_index := outline_start; command_index < outline_end; command_index++ {
			commands[command_index].paint_phase = .outline
		}
		for command_index := foreground_content_start; command_index < foreground_content_end; command_index++ {
			commands[command_index].paint_phase = .foreground
		}
		for command_index := overlay_start; command_index < overlay_end; command_index++ {
			commands[command_index].paint_phase = .overlay
		}
		if recorder.phase_commands.len > 0 {
			recorder.publish_commands(mut commands)
		}
	}
	// A render-blocked nested viewport can leave commands from the beginning
	// of its entry unclassified. Preserve the flat API's existing transport for
	// that early exit, including when it is the final entry.
	if recorder.phase_commands.len > 0 {
		recorder.publish_commands(mut commands)
	}
	return commands
}

fn append_compatibility_paint_step(box &BlockBox, phase CompatibilityPaintPhase, mut steps []CompatibilityPaintStep) {
	steps << CompatibilityPaintStep{
		box: unsafe { box }
		phase: phase
	}
}

// Collect the descendants owned by one stacking context. Nested contexts stop
// the walk; positioned z-index:auto descendants remain atomic paint entries,
// while their real stacking-context descendants still belong to this context.
fn (b &BlockBox) collect_compatibility_stacking_context_members(mut members CompatibilityStackingContextMembers) {
	for child_index := 0; child_index < b.children.len; child_index++ {
		child := unsafe { &b.children[child_index] }
		if child.stacking_context {
			if child.z_index < 0 {
				members.negative << child
			} else if child.z_index > 0 {
				members.positive << child
			} else {
				members.zero << child
			}
			continue
		}
		if child.positioned {
			members.zero << child
		}
		child.collect_compatibility_stacking_context_members(mut members)
	}
}

fn (b &BlockBox) collect_compatibility_descendant_paint_steps(phase CompatibilityDescendantPaintPhase, mut steps []CompatibilityPaintStep) {
	for child_index := 0; child_index < b.children.len; child_index++ {
		child := unsafe { &b.children[child_index] }
		if child.stacking_context {
			continue
		}
		// Positioned descendants with z-index:auto are painted atomically during
		// the stack-level-zero phase, just like StackingContext::paint_internal().
		if child.positioned {
			continue
		}
		// Flex/grid items paint like inline blocks. Their
		// backgrounds must stay beside their own foreground, rather than being
		// hoisted ahead of an earlier sibling's foreground.
		if child.atomic_in_flow {
			if phase == .foreground {
				child.collect_compatibility_node_as_stacking_context_steps(mut steps)
			}
			continue
		}
		// A non-positioned float is treated as a temporary stacking context in
		// the float phase. Its real stacking-context descendants remain hoisted.
		if child.floating {
			if phase == .floats {
				child.collect_compatibility_node_as_stacking_context_steps(mut steps)
			}
			continue
		}

		match phase {
			.background_and_borders {
				if !child.inline_or_replaced {
					append_compatibility_paint_step(child, .background, mut steps)
					append_compatibility_paint_step(child, .border, mut steps)
					child.collect_compatibility_descendant_paint_steps(phase, mut steps)
					append_compatibility_paint_step(child, .table_collapsed_border, mut steps)
				}
			}
			.floats {
				child.collect_compatibility_descendant_paint_steps(phase, mut steps)
			}
			.background_and_borders_for_inline_and_replaced {
				if child.inline_or_replaced {
					append_compatibility_paint_step(child, .background, mut steps)
					append_compatibility_paint_step(child, .border, mut steps)
					append_compatibility_paint_step(child, .table_collapsed_border, mut steps)
					child.collect_compatibility_descendant_paint_steps(.background_and_borders, mut steps)
				}
				child.collect_compatibility_descendant_paint_steps(phase, mut steps)
			}
			.foreground {
				append_compatibility_paint_step(child, .foreground, mut steps)
				child.collect_compatibility_descendant_paint_steps(phase, mut steps)
				append_compatibility_paint_step(child, .outline, mut steps)
				append_compatibility_paint_step(child, .overlay, mut steps)
			}
		}
	}
}

fn (b &BlockBox) collect_compatibility_node_as_stacking_context_steps(mut steps []CompatibilityPaintStep) {
	append_compatibility_paint_step(b, .background, mut steps)
	append_compatibility_paint_step(b, .border, mut steps)
	b.collect_compatibility_descendant_paint_steps(.background_and_borders, mut steps)
	b.collect_compatibility_descendant_paint_steps(.floats, mut steps)
	b.collect_compatibility_descendant_paint_steps(.background_and_borders_for_inline_and_replaced, mut steps)
	append_compatibility_paint_step(b, .foreground, mut steps)
	b.collect_compatibility_descendant_paint_steps(.foreground, mut steps)
	append_compatibility_paint_step(b, .outline, mut steps)
	append_compatibility_paint_step(b, .overlay, mut steps)
}

fn (b &BlockBox) has_noninvertible_paint_transform() bool {
	if affine_is_compact_identity(b.paint_transform) {
		return false
	}
	matrix := normalized_affine(b.paint_transform)
	return matrix[0] * matrix[3] - matrix[1] * matrix[2] == 0
}

// Translation of Painting::StackingContext::paint_internal() for the active
// compatibility BlockBox transport. It preserves the upstream phase ordering;
// the command-generation details remain in flat_paint_commands().
fn (b &BlockBox) collect_compatibility_stacking_context_paint_steps(mut steps []CompatibilityPaintStep,
	for_hit_testing bool) {
	if (!for_hit_testing && b.opacity == 0) || b.has_noninvertible_paint_transform() {
		return
	}

	mut members := CompatibilityStackingContextMembers{}
	b.collect_compatibility_stacking_context_members(mut members)

	append_compatibility_paint_step(b, .background, mut steps)
	append_compatibility_paint_step(b, .border, mut steps)

	for child in stable_sort_box_references_by_z(members.negative) {
		child.collect_compatibility_stacking_context_paint_steps(mut steps, for_hit_testing)
	}

	b.collect_compatibility_descendant_paint_steps(.background_and_borders, mut steps)
	b.collect_compatibility_descendant_paint_steps(.floats, mut steps)
	b.collect_compatibility_descendant_paint_steps(.background_and_borders_for_inline_and_replaced, mut steps)
	append_compatibility_paint_step(b, .foreground, mut steps)
	b.collect_compatibility_descendant_paint_steps(.foreground, mut steps)

	for child in members.zero {
		if child.stacking_context {
			child.collect_compatibility_stacking_context_paint_steps(mut steps, for_hit_testing)
		} else {
			child.collect_compatibility_node_as_stacking_context_steps(mut steps)
		}
	}

	for child in stable_sort_box_references_by_z(members.positive) {
		child.collect_compatibility_stacking_context_paint_steps(mut steps, for_hit_testing)
	}

	append_compatibility_paint_step(b, .outline, mut steps)
	append_compatibility_paint_step(b, .overlay, mut steps)
}

// ViewportPaintable::build_stacking_context_tree() retains and sorts this
// structure upstream. Resolve each paint step to its retained paintable once,
// so repaint and hit testing share the same tree instead of independently
// walking, sorting, and indexing the compatibility transport.
fn (b &BlockBox) compatibility_paint_plan() ([]PaintOrderEntry, []CompatibilityPaintStep) {
	// Sorting buckets, growth buffers and the identity index are only builder
	// state. The retained plans contain values and borrowed pointers to boxes.
	scratch := platform.begin_thread_scratch('compatibility paint plan')
	entries := b.paint_order_entries()
	mut entry_indexes := map[u64]int{}
	for index, entry in entries {
		entry_indexes[u64(voidptr(entry.box))] = index
	}
	mut steps := []CompatibilityPaintStep{cap: entries.len * compatibility_paint_phase_count}
	b.collect_compatibility_stacking_context_paint_steps(mut steps, false)
	for mut step in steps {
		step.entry_index = entry_indexes[u64(voidptr(step.box))] or { -1 }
	}
	scratch.leave()
	mut retained_entries := []PaintOrderEntry{cap: entries.len}
	for entry in entries { retained_entries << entry }
	mut retained_steps := []CompatibilityPaintStep{cap: steps.len}
	for step in steps { retained_steps << step }
	scratch.finish()
	return retained_entries, retained_steps
}

// StackingContext::hit_test() follows the same phases in reverse but, unlike
// paint(), opacity:0 remains hit-testable. Non-invertible contexts are omitted
// from both plans.
fn (b &BlockBox) compatibility_hit_test_steps(entry_count int) []CompatibilityPaintStep {
	// Bound the temporary collector once, then retain only the emitted slots.
	// The same workspace owns stacking-context membership and sorting buffers.
	scratch := platform.begin_thread_scratch('compatibility hit test plan')
	mut steps := []CompatibilityPaintStep{cap: entry_count * compatibility_paint_phase_count}
	b.collect_compatibility_stacking_context_paint_steps(mut steps, true)
	scratch.leave()
	mut retained := []CompatibilityPaintStep{cap: steps.len}
	for step in steps { retained << step }
	scratch.finish()
	return retained
}

// Build commands once per retained box, then replay each box's cached phase in
// the order produced by the translated stacking-context algorithm. This keeps
// display-list construction linear while matching C++'s phase boundaries.
pub fn (b &BlockBox) paint_commands() []PaintCommand {
	entries, steps := b.compatibility_paint_plan()
	return b.paint_commands_from_plan(entries, steps)
}

fn (b &BlockBox) paint_commands_from_plan(entries []PaintOrderEntry, steps []CompatibilityPaintStep) []PaintCommand {
	phase_commands, command_count := b.build_paint_phase_command_cache(entries)
	return replay_cached_paint_commands(steps, phase_commands, command_count, false)
}

// Translation of PaintableBox::m_cached_phase_commands. Each retained box has
// one bucket for every PaintPhase, populated by its first paint and reused by
// later display-list recordings until paint-cache invalidation.
fn (b &BlockBox) build_paint_phase_command_cache(entries []PaintOrderEntry) ([][]PaintCommand, int) {
	return b.build_reusing_paint_phase_command_cache(entries, [][]PaintCommand{})
}

struct PaintPhaseCommandRecorder {
mut:
	include_line_box_debug bool = true
	phase_commands  [][]PaintCommand
	bucket_counts   []int
	touched_buckets []int
	command_count   int
}

$if test {
	fn new_paint_phase_command_recorder(entry_count int) PaintPhaseCommandRecorder {
		return new_reusing_paint_phase_command_recorder(entry_count, [][]PaintCommand{})
	}
}

fn (mut recorder PaintPhaseCommandRecorder) publish_commands(mut commands []PaintCommand) {
	// Count through references: PaintCommand contains wide optional payloads,
	// and examining its phase must not copy one of those records.
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		bucket := command.paint_box_index * compatibility_paint_phase_count + int(command.paint_phase)
		if recorder.bucket_counts[bucket] == 0 {
			recorder.touched_buckets << bucket
		}
		recorder.bucket_counts[bucket]++
	}
	for bucket in recorder.touched_buckets {
		// Usually a bucket is written once. Keeping an existing prefix also
		// preserves commands retained by the flat generator's early exits.
		recorder.reserve_phase_bucket(bucket, recorder.bucket_counts[bucket])
	}
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		bucket := command.paint_box_index * compatibility_paint_phase_count + int(command.paint_phase)
		recorder.phase_commands[bucket] << *command
	}
	for bucket in recorder.touched_buckets {
		recorder.bucket_counts[bucket] = 0
	}
	recorder.touched_buckets.clear()
	recorder.command_count += commands.len
	commands.clear()
}

// Regenerate only invalidated PaintableBox entries. This is the retained-cache
// path used after a box-level repaint request; document-level repaint requests
// can replay every existing bucket without calling paint again.
fn (b &BlockBox) refresh_paint_phase_command_cache(entries []PaintOrderEntry, mut phase_commands [][]PaintCommand, mut entry_valid []bool) int {
	return b.refresh_selected_paint_phase_command_cache(entries, []bool{}, mut phase_commands, mut entry_valid)
}

fn (b &BlockBox) refresh_selected_paint_phase_command_cache(entries []PaintOrderEntry, visible []bool, mut phase_commands [][]PaintCommand, mut entry_valid []bool) int {
	return b.refresh_selected_paint_phase_command_cache_with_debug(entries, visible,
		mut phase_commands, mut entry_valid, true)
}

fn (b &BlockBox) refresh_selected_paint_phase_command_cache_with_debug(entries []PaintOrderEntry,
	visible []bool, mut phase_commands [][]PaintCommand, mut entry_valid []bool,
	include_line_box_debug bool) int {
	// Most repaints invalidate no entry; find that out before allocating.
	mut has_invalid_entry := false
	for index in 0 .. entries.len {
		if !entry_valid[index] && (visible.len == 0 || visible[index]) {
			has_invalid_entry = true
			break
		}
	}
	if !has_invalid_entry {
		return 0
	}
	mut selected := []bool{len: entries.len}
	for index in 0 .. entries.len {
		selected[index] = !entry_valid[index] && (visible.len == 0 || visible[index])
	}
	mut recorder := PaintPhaseCommandRecorder{
		include_line_box_debug: include_line_box_debug
		phase_commands: unsafe { phase_commands }
		bucket_counts: []int{len: phase_commands.len}
		touched_buckets: []int{cap: compatibility_paint_phase_count}
	}
	// The owner has already cleared invalidated buckets. Valid bucket headers
	// remain unchanged, while refreshed entries receive exact-sized storage.
	b.record_paint_commands_for_entries(entries, selected, mut recorder)
	for index in 0 .. entries.len {
		if selected[index] {
			entry_valid[index] = true
		}
	}
	return recorder.command_count
}

// StackingContext::paint_node() replays the cached phase vector at each step in
// the retained stacking-context traversal. Keep that replay separate from cache
// construction so repaints do not regenerate or redistribute box commands.
fn cached_paint_replay_command_count(steps []CompatibilityPaintStep, phase_commands [][]PaintCommand,
	show_line_box_borders bool) int {
	mut count := 0
	for step in steps {
		if step.entry_index < 0 { continue }
		bucket := step.entry_index * compatibility_paint_phase_count + int(step.phase)
		for index in 0 .. phase_commands[bucket].len {
			if show_line_box_borders || !phase_commands[bucket][index].line_box_debug {
				count++
			}
		}
	}
	return count
}

fn replay_cached_paint_commands(steps []CompatibilityPaintStep, phase_commands [][]PaintCommand,
	_command_count int, show_line_box_borders bool) []PaintCommand {
	count := cached_paint_replay_command_count(steps, phase_commands, show_line_box_borders)
	mut commands := []PaintCommand{cap: count}
	for step in steps {
		if step.entry_index < 0 {
			continue
		}
		bucket := step.entry_index * compatibility_paint_phase_count + int(step.phase)
		for index in 0 .. phase_commands[bucket].len {
			cached_command := unsafe { &phase_commands[bucket][index] }
			if cached_command.line_box_debug && !show_line_box_borders { continue }
			mut command := *cached_command
			apply_live_scrollbar_offset(mut command, step.box)
			apply_live_background_offsets(mut command, step.box)
			commands << command
		}
	}
	return commands
}

fn apply_live_background_offsets(mut command PaintCommand, box &BlockBox) {
	if command.kind != 'draw_background_image'
		&& !(command.kind == 'fill_gradient' && command.gradient_background_layer) {
		return
	}
	if overlay := box.overlay {
		current := box.current_scroll_offset(overlay)
		command.image_scroll_offset_x = current.x
		command.image_scroll_offset_y = current.y
	}
}

fn apply_live_scrollbar_offset(mut command PaintCommand, box &BlockBox) {
	if command.scrollbar_axis == '' || command.scrollbar_thumb_travel_ratio == 0 {
		return
	}
	overlay := box.overlay or { return }
	current := box.current_scroll_offset(overlay)
	if command.scrollbar_axis == 'vertical' {
		command.y += (current.y - command.scrollbar_recorded_scroll_offset) * command.scrollbar_thumb_travel_ratio
	} else {
		command.x += (current.x - command.scrollbar_recorded_scroll_offset) * command.scrollbar_thumb_travel_ratio
	}
}

fn text_fragments_share_run(first TextFragment, next TextFragment) bool {
	if first_run := first.paintable_fragment.glyph_run {
		if next_run := next.paintable_fragment.glyph_run {
			if (first_run.face() != next_run.face() || !first_run.font().has_same_identity(next_run.font()))
				&& next_run.glyphs().any(it.should_paint) {
				return false
			}
		}
	}
	return first.shape_as_run && next.shape_as_run && first.text_run_id != 0 && first.text_run_id == next.text_run_id && first.inline_node_id == next.inline_node_id && first.color == next.color && first.font_size == next.font_size && first.bold == next.bold && first.italic == next.italic && first.mono == next.mono && first.font_smoothing == next.font_smoothing && first.decoration == next.decoration && first.decoration_color == next.decoration_color && first.decoration_color_set == next.decoration_color_set && first.decoration_style == next.decoration_style && first.decoration_thickness == next.decoration_thickness && first.preserves_spaces == next.preserves_spaces && first.rtl == next.rtl
		&& text_fragments_share_chromium_font(first, next)
}

// Chromium-policy text never repaints from its raw string: fragments shaped
// with different fallback fonts each paint their own glyph run at the
// layout baseline.
fn text_fragments_share_chromium_font(first TextFragment, next TextFragment) bool {
	first_run := first.paintable_fragment.glyph_run or { return true }
	first_font := first_run.font()
	if first_font.font_rendering_policy != .chromium {
		return true
	}
	next_run := next.paintable_fragment.glyph_run or { return false }
	next_font := next_run.font()
	return first_run.face() == next_run.face() && first_font.family == next_font.family
		&& first_font.source_path == next_font.source_path
		&& first_font.point_size == next_font.point_size && first_font.weight == next_font.weight
}

fn combined_text_fragment_glyph_run(fragments []TextFragment, run_left f64) ?&platform.GlyphRun {
	if fragments.len == 0 {
		return none
	}
	first_run := fragments[0].paintable_fragment.glyph_run or { return none }
	first_font := first_run.font()
	first_baseline := fragments[0].y + fragments[0].baseline
	mut glyphs := []platform.Glyph{}
	for fragment in fragments {
		run := fragment.paintable_fragment.glyph_run or { return none }
		font := run.font()
		if run.face() != first_run.face() || font.family != first_font.family
			|| font.source_path != first_font.source_path || font.point_size != first_font.point_size
			|| font.weight != first_font.weight
			|| fragment.paintable_fragment.orientation != fragments[0].paintable_fragment.orientation {
			// Default-ignorable controls can be assigned a fallback font even
			// though every glyph in that fragment is deliberately non-painting.
			// Their glyph IDs never reach replay, so they may remain in the
			// combined bookkeeping run without forcing raw-string fallback.
			if run.glyphs().any(it.should_paint) {
				return none
			}
		}
		for source_glyph in run.glyphs() {
			mut glyph := source_glyph
			glyph.position.translate_by(f32(fragment.x - run_left), f32(fragment.y + fragment.baseline - first_baseline))
			glyphs << glyph
		}
	}
	return platform.GlyphRun.new_with_face(first_font, first_run.text_type(), glyphs, first_run.face())
}

fn append_line_box_debug_commands(mut commands []PaintCommand, fragment TextFragment,
	opacity f64) {
	if fragment.paintable_fragment.length_in_code_units == 0 {
		return
	}
	commands << PaintCommand{
		kind: 'stroke_rounded_rect'
		x: fragment.x
		y: fragment.y
		width: fragment.width
		height: fragment.height
		color: '#00ff00'
		force_dark_role: .none_
		force_dark_role_set: true
		opacity: opacity
		stroke_width: 1
		line_box_debug: true
	}
	commands << PaintCommand{
		kind: 'draw_line'
		color: '#ff0000'
		force_dark_role: .none_
		force_dark_role_set: true
		opacity: opacity
		stroke_width: 1
		points: [fragment.x, fragment.y + fragment.baseline,
			fragment.x + fragment.width - 1, fragment.y + fragment.baseline]
		line_box_debug: true
	}
}

// Only compact a newly replayed command buffer, never a retained phase bucket.
// Cached guides remain available when the inspector toggles their visibility.
$if test {
	fn filter_line_box_debug_commands(mut commands []PaintCommand, visible bool) {
		if visible {
			return
		}
		mut write_index := 0
		for read_index in 0 .. commands.len {
			if commands[read_index].line_box_debug {
				continue
			}
			if write_index != read_index {
				commands[write_index] = commands[read_index]
			}
			write_index++
		}
		commands.trim(write_index)
	}
}

// Compatibility layout can still supply word fragments for one naturally-spaced DOM text node;
// coalesce those into one paint command. The typed adapter already supplies the committed C++-shaped
// LineBoxFragment intact, so it takes the single-fragment path without rebuilding the string.
fn unselected_text_fragment_commands_with_debug(fragments []TextFragment, opacity f64,
	include_line_box_debug bool) []PaintCommand {
	mut commands := []PaintCommand{}
	append_unselected_text_fragment_commands(mut commands, fragments, opacity,
		include_line_box_debug)
	return commands
}

// Entry recording reuses its command buffer across lines and boxes. Emit text
// into that buffer directly instead of allocating and copying a wide temporary
// command vector for each line.
fn append_unselected_text_fragment_commands(mut commands []PaintCommand,
	fragments []TextFragment, opacity f64, include_line_box_debug bool) {
	mut i := 0
	for i < fragments.len {
		platform.cooperative_work_checkpoint()
		first := fragments[i]
		mut j := i + 1
		for j < fragments.len && text_fragments_share_run(first, fragments[j]) {
			j++
		}
		mut text_capacity := first.text.len
		for k := i + 1; k < j; k++ {
			text_capacity += fragments[k - 1].separator_after.len + fragments[k].text.len
		}
		if first.preserves_spaces {
			text_capacity += fragments[j - 1].separator_after.len
		}
		mut text_builder := strings.new_builder(text_capacity)
		text_builder.write_string(first.text)
		for k := i + 1; k < j; k++ {
			text_builder.write_string(fragments[k - 1].separator_after)
			text_builder.write_string(fragments[k].text)
		}
		if first.preserves_spaces {
			text_builder.write_string(fragments[j - 1].separator_after)
		}
		text := text_builder.str()
		mut run_left := first.x
		mut run_right := first.x + first.width
		for k := i + 1; k < j; k++ {
			if fragments[k].x < run_left {
				run_left = fragments[k].x
			}
			if fragments[k].x + fragments[k].width > run_right {
				run_right = fragments[k].x + fragments[k].width
			}
		}
		if first.preserves_spaces {
			if first.rtl {
				run_left -= fragments[j - 1].separator_width_after
			} else {
				run_right += fragments[j - 1].separator_width_after
			}
		}
		if include_line_box_debug {
			for k := i; k < j; k++ {
				append_line_box_debug_commands(mut commands, fragments[k], opacity)
			}
		}
		mut text_command := PaintCommand{
			kind: 'draw_text'
			x: run_left
			y: first.y
			width: run_right - run_left
			height: first.height
			color: first.color.serialize()
			text: text
			font_size: first.font_size
			bold: first.bold
			italic: first.italic
			mono: first.mono
			font_smoothing: first.font_smoothing
			rtl: first.rtl
			opacity: opacity
		}
		// Typed layout transports one committed LineBoxFragment per entry. Join
		// compatible retained runs without reshaping so a synthetic block ellipsis
		// can keep the boundary text node's paint-run identity. Mixed-font groups
		// keep the raw-string fallback above.
		if j == i + 1 {
			if glyph_run := first.paintable_fragment.glyph_run {
				mut retained_run := unsafe { &platform.GlyphRun(glyph_run) }
				retained_run.refresh_replay_data()
				text_command.glyph_run = retained_run
				text_command.glyph_translation_x = first.x
				text_command.glyph_translation_y = text_fragment_paint_top(first) + first.baseline
				text_command.glyph_orientation = first.paintable_fragment.orientation
			}
		} else if combined_run := combined_text_fragment_glyph_run(fragments[i..j], run_left) {
			text_command.glyph_run = combined_run
			text_command.glyph_translation_x = run_left
			text_command.glyph_translation_y = text_fragment_paint_top(first) + first.baseline
			text_command.glyph_orientation = first.paintable_fragment.orientation
		}
		commands << text_command
		for k := i; k < j; k++ {
			commands << decoration_commands(fragments[k], opacity)
		}
		i = j
	}
}

fn unselected_text_fragment_commands(fragments []TextFragment, opacity f64) []PaintCommand {
	return unselected_text_fragment_commands_with_debug(fragments, opacity, false)
}

struct TextRenderSpan {
	fragment_index    int
	start_code_unit   int
	end_code_unit     int
	text_color        css.Color
	background_color  css.Color
	shadow_layers     []BoxShadow
	shadow_layers_set bool
	decoration        string
	decoration_color  css.Color
	decoration_style  string
	decoration_set    bool
}

fn dom_selection_state_to_painting(state dom.SelectionState) painting.SelectionState {
	return match state {
		.none { .none }
		.start { .start }
		.end { .end }
		.start_and_end { .start_and_end }
		.full { .full }
	}
}

// Route the active transport through PaintableFragment's direct translation
// instead of maintaining a second renderer-local selection calculation.
fn text_fragment_compute_selection_offsets(fragment TextFragment,
	state painting.SelectionState, start_offset int, end_offset int) ?painting.SelectionOffsets {
	return fragment.paintable_fragment.compute_selection_offsets(state, start_offset, end_offset)
}

// PaintableFragment::selection_range_for_text_control().
fn selection_range_for_text_control(fragment TextFragment) ?painting.SelectionOffsets {
	if fragment.layout_handle == unsafe { nil } {
		return none
	}
	layout_node := unsafe { &Node(fragment.layout_handle) }
	fragment_dom_node := layout_node.dom_node() or { return none }
	focused := layout_node.document().focused_area() or { return none }
	focused_element := focused.as_element() or { return none }
	mut selection_start := 0
	mut selection_end := 0
	mut control_text_node := ?&dom.Text(none)
	if focused.is_html_input_element() {
		model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(focused_element) })
		if !model.selection_or_range_applies() {
			return none
		}
		control_text_node = model.form_associated_element_to_text_node()
		selection_start = int(model.text_control.selection_start())
		selection_end = int(model.text_control.selection_end())
	} else if focused_element.is_html_element() && focused_element.local_name() == 'textarea' {
		model := html.html_text_area_element_model_for_dom_element(unsafe {
			&dom.HTMLTextAreaElement(focused_element)
		})
		control_text_node = model.form_associated_element_to_text_node()
		selection_start = int(model.text.selection_start())
		selection_end = int(model.text.selection_end())
	} else {
		return none
	}
	text_node := control_text_node or { return none }
	if voidptr(text_node.as_node()) != voidptr(fragment_dom_node)
		|| selection_start == selection_end {
		return none
	}
	return text_fragment_compute_selection_offsets(fragment, .start_and_end, selection_start, selection_end)
}

// PaintableFragment::selection_offsets(). Text-control state takes precedence
// over the document Selection just as it does upstream.
fn selection_offsets(fragment TextFragment) ?painting.SelectionOffsets {
	if offsets := selection_range_for_text_control(fragment) {
		return offsets
	}
	if fragment.layout_handle == unsafe { nil } {
		return none
	}
	layout_node := unsafe { &Node(fragment.layout_handle) }
	dom_node := layout_node.dom_node() or { return none }
	paintable := dom_node.unsafe_paintable() or { return none }
	state := dom_selection_state_to_painting(paintable.selection_state)
	if state == .none {
		return none
	}
	selection := layout_node.document().get_selection() or { return none }
	range := selection.range() or { return none }
	return text_fragment_compute_selection_offsets(fragment, state, range.start_offset(), range.end_offset())
}

fn text_fragment_has_active_selection(fragment TextFragment) bool {
	return selection_offsets(fragment) != none
}

// PaintableFragment::range_rect() over the retained LineBoxFragment glyph run.
fn text_fragment_relative_range_rect(fragment TextFragment, start int, end int) LayoutRect {
	paintable_fragment := fragment.paintable_fragment
	rect := paintable_fragment.range_rect(.start_and_end, paintable_fragment.source_offset_for_local_rendered(start, .start), paintable_fragment.source_offset_for_local_rendered(end, .end))
	return LayoutRect{rect.x, rect.y, rect.width, rect.height}
}

// PaintableFragment::selection_rect(). The DOM-dependent range lookup stays at
// the Layout bridge, while range geometry remains owned by PaintableFragment.
fn selection_rect(fragment TextFragment) LayoutRect {
	offsets := selection_offsets(fragment) or { return LayoutRect{} }
	return text_fragment_relative_range_rect(fragment, offsets.start, offsets.end)
}

fn rounded_text_span_rect(rect LayoutRect) LayoutRect {
	converter := painting.new_device_pixel_converter(1.0) or { return rect }
	rounded := converter.rounded_device_rect(painting.Rect{rect.x, rect.y, rect.width, rect.height})
	return LayoutRect{f64(rounded.x), f64(rounded.y), f64(rounded.width), f64(rounded.height)}
}

// PaintableWithLines.cpp::compute_render_spans().
fn compute_render_spans(fragments []TextFragment) []TextRenderSpan {
	mut spans := []TextRenderSpan{cap: fragments.len}
	for fragment_index, fragment in fragments {
		fragment_length := fragment.paintable_fragment.length_in_code_units
		fragment_selection_offsets := selection_offsets(fragment) or {
			spans << TextRenderSpan{
				fragment_index: fragment_index
				end_code_unit: fragment_length
				text_color: fragment.color
			}
			continue
		}
		style := fragment.selection_style
		selection_text_color := if style.text_color_set { style.text_color } else { fragment.color }
		if fragment_selection_offsets.start > 0 {
			spans << TextRenderSpan{
				fragment_index: fragment_index
				end_code_unit: fragment_selection_offsets.start
				text_color: fragment.color
			}
		}
		if fragment_selection_offsets.start < fragment_selection_offsets.end {
			spans << TextRenderSpan{
				fragment_index: fragment_index
				start_code_unit: fragment_selection_offsets.start
				end_code_unit: fragment_selection_offsets.end
				text_color: selection_text_color
				background_color: style.background_color
				shadow_layers: style.text_shadows
				shadow_layers_set: style.text_shadows_set
				decoration: style.decoration
				decoration_color: style.decoration_color
				decoration_style: style.decoration_style
				decoration_set: style.decoration_set
			}
		}
		if fragment_selection_offsets.end < fragment_length {
			spans << TextRenderSpan{
				fragment_index: fragment_index
				start_code_unit: fragment_selection_offsets.end
				end_code_unit: fragment_length
				text_color: fragment.color
			}
		}
	}
	return spans
}

fn text_span_rect(fragment TextFragment, span TextRenderSpan) LayoutRect {
	return text_fragment_relative_range_rect(fragment, span.start_code_unit, span.end_code_unit)
}

// ShadowPainting.cpp slices by UTF-16 code-unit boundaries without rebasing
// glyph positions. This matters for ligatures, combining marks, bidi runs, and
// a selected span that begins after the first glyph in its line fragment.
fn text_shadow_glyph_run(fragment TextFragment, span TextRenderSpan) ?&platform.GlyphRun {
	glyph_run := fragment.paintable_fragment.glyph_run or { return none }
	mut retained_run := unsafe { &platform.GlyphRun(glyph_run) }
	retained_run.refresh_replay_data()
	if span.start_code_unit == 0
		&& span.end_code_unit == fragment.paintable_fragment.length_in_code_units {
		return retained_run
	}
	glyphs := retained_run.glyphs()
	mut start_glyph := 0
	mut glyph_count := 0
	mut code_unit_offset := 0
	for index, glyph in glyphs {
		if code_unit_offset == span.start_code_unit {
			start_glyph = index
		}
		code_unit_offset += glyph.length_in_code_units
		if code_unit_offset == span.end_code_unit {
			glyph_count = index - start_glyph + 1
			break
		}
	}
	if glyph_count > 0 {
		return retained_run.slice(start_glyph, glyph_count)
	}
	return retained_run
}

// ShadowPainting.cpp::paint_text_shadow().
fn paint_text_shadow(mut commands []PaintCommand, fragment TextFragment,
	span TextRenderSpan, opacity f64) {
	layers := if span.shadow_layers_set { span.shadow_layers } else { fragment.text_shadows }
	if layers.len == 0 {
		return
	}
	span_text := utf16_substring_for_line_box(fragment.text, span.start_code_unit, span.end_code_unit - span.start_code_unit)
	glyph_run := text_shadow_glyph_run(fragment, span)
	for layer_index := layers.len - 1; layer_index >= 0; layer_index-- {
		layer := layers[layer_index]
		mut shadow_command := PaintCommand{
			kind: 'draw_text_shadow'
			x: fragment.x + layer.offset_x
			y: fragment.y + layer.offset_y
			width: fragment.width
			height: fragment.height
			color: layer.color.serialize()
			text: span_text
			font_size: fragment.font_size
			bold: fragment.bold
			italic: fragment.italic
			mono: fragment.mono
			font_smoothing: fragment.font_smoothing
			rtl: fragment.rtl
			opacity: opacity
			blur: layer.blur
		}
		if retained_run := glyph_run {
			shadow_command.glyph_run = retained_run
			shadow_command.glyph_translation_x = fragment.x + layer.offset_x
			shadow_command.glyph_translation_y = text_fragment_paint_top(fragment) + fragment.baseline +
				layer.offset_y
		}
		commands << shadow_command
	}
}

// Blink snaps the containing paint fragment's origin, preserving each text
// box's alignment inside it. Culled inline ancestors keep the line's origin;
// decorated or spaced inline boxes establish an origin of their own.
fn text_fragment_paint_top(fragment TextFragment) f64 {
	if fragment.paintable_fragment.orientation == .horizontal {
		if run := fragment.paintable_fragment.glyph_run {
			if run.font().font_rendering_policy == .chromium {
				if top := fragment.paint_line_top {
					return fragment.y + math.floor(top + 0.5) - top
				}
				return math.floor(fragment.y + 0.5)
			}
		}
	}
	return fragment.y
}

// PaintableWithLines.cpp::paint_text_fragment().
fn paint_text_fragment(mut commands []PaintCommand, fragment TextFragment,
	span TextRenderSpan, opacity f64) {
	if span.start_code_unit == span.end_code_unit {
		return
	}
	full_fragment := span.start_code_unit == 0
		&& span.end_code_unit == fragment.paintable_fragment.length_in_code_units
	mut text_command := PaintCommand{
		kind: 'draw_text'
		x: fragment.x
		y: fragment.y
		width: fragment.width
		height: fragment.height
		color: span.text_color.serialize()
		text: fragment.text
		font_size: fragment.font_size
		bold: fragment.bold
		italic: fragment.italic
		mono: fragment.mono
		font_smoothing: fragment.font_smoothing
		rtl: fragment.rtl
		opacity: opacity
	}
	if glyph_run := fragment.paintable_fragment.glyph_run {
		mut retained_run := unsafe { &platform.GlyphRun(glyph_run) }
		retained_run.refresh_replay_data()
		text_command.glyph_run = retained_run
		text_command.glyph_translation_x = fragment.x
		text_command.glyph_translation_y = text_fragment_paint_top(fragment) + fragment.baseline
		text_command.glyph_orientation = fragment.paintable_fragment.orientation
	}
	span_rect := text_span_rect(fragment, span)
	if !full_fragment {
		text_command.recording_clip = rounded_text_span_rect(span_rect)
	}
	commands << text_command
	decoration_rect := if full_fragment {
		LayoutRect{fragment.x, fragment.y, fragment.width, fragment.height}
	} else {
		span_rect
	}
	decoration_fragment := if span.decoration_set {
		TextFragment{
			...fragment
			x: decoration_rect.x
			y: decoration_rect.y
			width: decoration_rect.width
			height: decoration_rect.height
			decoration: span.decoration
			decoration_color: span.decoration_color
			decoration_color_set: true
			decoration_style: span.decoration_style
		}
	} else {
		TextFragment{
			...fragment
			x: decoration_rect.x
			y: decoration_rect.y
			width: decoration_rect.width
			height: decoration_rect.height
		}
	}
	commands << decoration_commands(decoration_fragment, opacity)
}

// PaintableWithLines::paint(Foreground): selection backgrounds for all spans,
// then all shadows, then glyphs and decorations.
fn append_selected_text_fragment_commands(mut commands []PaintCommand,
	fragments []TextFragment, opacity f64, include_line_box_debug bool) {
	spans := compute_render_spans(fragments)
	for span in spans {
		if span.background_color.a == 0 {
			continue
		}
		rect := rounded_text_span_rect(selection_rect(fragments[span.fragment_index]))
		commands << PaintCommand{
			kind: 'fill_rect'
			x: rect.x
			y: rect.y
			width: rect.width
			height: rect.height
			color: span.background_color.serialize()
			force_dark_role: .selection
			force_dark_role_set: true
			opacity: opacity
		}
	}
	for span in spans {
		paint_text_shadow(mut commands, fragments[span.fragment_index], span, opacity)
	}
	for span in spans {
		if include_line_box_debug {
			append_line_box_debug_commands(mut commands, fragments[span.fragment_index], opacity)
		}
		paint_text_fragment(mut commands, fragments[span.fragment_index], span, opacity)
	}
}

$if test {
	fn append_text_fragment_commands(mut commands []PaintCommand, fragments []TextFragment,
		opacity f64) {
		append_text_fragment_commands_with_debug(mut commands, fragments, opacity, true)
	}
}

fn append_text_fragment_commands_with_debug(mut commands []PaintCommand, fragments []TextFragment,
	opacity f64, include_line_box_debug bool) {
	if !fragments.any(text_fragment_has_active_selection(it))
		&& !fragments.any(it.text_shadows.len > 0) {
		append_unselected_text_fragment_commands(mut commands, fragments, opacity, include_line_box_debug)
		return
	}
	append_selected_text_fragment_commands(mut commands, fragments, opacity, include_line_box_debug)
}

// Boundary offsets are inclusive, so a caret at a fragment edge resolves to
// the first retained fragment just as Vector::first_matching() does upstream.
fn fragment_at_node_offset(box &BlockBox, position_node &dom.Node, offset int) ?&TextFragment {
	for line_index in 0 .. box.lines.len {
		for fragment_index in 0 .. box.lines[line_index].fragments.len {
			fragment := unsafe { &box.lines[line_index].fragments[fragment_index] }
			if fragment.layout_handle == unsafe { nil } {
				continue
			}
			layout_node := unsafe { &Node(fragment.layout_handle) }
			fragment_node := layout_node.dom_node() or { continue }
			start := fragment.paintable_fragment.start_offset
			end := fragment.paintable_fragment.source_end_offset()
			if voidptr(fragment_node) == voidptr(position_node) && offset >= start
				&& offset <= end {
				return fragment
			}
		}
	}
	return none
}

// PaintableWithLines::fragment_at_position().
fn fragment_at_position(box &BlockBox, position &dom.Position) ?&TextFragment {
	position_node := position.node() or { return none }
	return fragment_at_node_offset(box, position_node, position.offset())
}

struct TextChildBoundaryCaret {
	fragment    &TextFragment = unsafe { nil }
	text_offset int
}

// BoxViews.cpp::caret_rect_for_child_offset() first resolves a boundary beside
// a text child through that child's retained fragment. Editors can keep the
// selection on the parent after inserting text; its geometry must be identical
// to the corresponding text-node offset.
fn text_child_boundary_caret(box &BlockBox, parent &dom.Node,
	offset int) ?TextChildBoundaryCaret {
	if offset > 0 {
		if previous_child := parent.child_at_index(offset - 1) {
			if previous_child.is_text() {
				text_offset := previous_child.length()
				if fragment := fragment_at_node_offset(box, previous_child, text_offset) {
					return TextChildBoundaryCaret{fragment, text_offset}
				}
			}
		}
	}
	if next_child := parent.child_at_index(offset) {
		if next_child.is_text() {
			if fragment := fragment_at_node_offset(box, next_child, 0) {
				return TextChildBoundaryCaret{fragment, 0}
			}
		}
	}
	return none
}

fn active_text_control_is_mutable(document &dom.Document) bool {
	active := document.active_element() or { return false }
	if active.is_html_input_element() {
		return html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(active) }).is_mutable()
	}
	if active.is_html_element() && active.local_name() == 'textarea' {
		return html.html_text_area_element_model_for_dom_element(unsafe {
			&dom.HTMLTextAreaElement(active)
		}).is_mutable()
	}
	return false
}

// BoxViews.cpp::caret_rect_for_empty_line(). Text-fragment carets use the
// font's typographic height rather than the full line-height box; empty
// elements must keep that height and center the caret in any extra leading.
fn caret_rect_for_empty_line(node &Node, x f64, y f64) LayoutRect {
	font_metrics := node.first_available_font().pixel_metrics()
	line_height := node.computed_values().line_height().to_double()
	typographic_height := CSSPixels.nearest_value_for(f64(font_metrics.ascent + font_metrics.descent)).to_double()
	caret_height := math.min(line_height, typographic_height)
	return LayoutRect{
		x: x
		y: y + (line_height - caret_height) / 2.0
		width: 1
		height: caret_height
	}
}

// PaintableWithLines::paint_cursor(). The cursor is recorded after all text
// spans in this foreground bucket and therefore participates in the same
// targeted cache invalidation as upstream.
fn paint_cursor(box &BlockBox, opacity f64) ?PaintCommand {
	if box.layout_handle == unsafe { nil } {
		return none
	}
	layout_node := unsafe { &Node(box.layout_handle) }
	document := layout_node.document()
	if !document.get_cursor_blink_state() {
		return none
	}
	navigable := document.navigable() or { return none }
	if !navigable.is_focused() || !document.shows_focus_state() {
		return none
	}
	position := document.cursor_position() or { return none }
	dom_node := layout_node.dom_node() or { return none }
	if !active_text_control_is_mutable(document) && !dom_node.is_editable_or_editing_host() {
		return none
	}
	mut rect := LayoutRect{}
	mut caret_color := css.Color{}
	if fragment := fragment_at_position(box, position) {
		fragment_layout_node := unsafe { &Node(fragment.layout_handle) }
		caret_color = fragment_layout_node.computed_values().caret_color()
		fragment_rect := fragment.paintable_fragment.range_rect(.start_and_end, position.offset(), position.offset())
		rect = LayoutRect{fragment_rect.x, fragment_rect.y, fragment_rect.width, fragment_rect.height}
	} else if position_node := position.node() {
		if boundary := text_child_boundary_caret(box, position_node, position.offset()) {
			fragment_layout_node := unsafe { &Node(boundary.fragment.layout_handle) }
			caret_color = fragment_layout_node.computed_values().caret_color()
			fragment_rect := boundary.fragment.paintable_fragment.range_rect(.start_and_end, boundary.text_offset, boundary.text_offset)
			rect = LayoutRect{fragment_rect.x, fragment_rect.y, fragment_rect.width, fragment_rect.height}
		} else {
			return paint_empty_cursor(box, layout_node, dom_node, position_node, opacity)
		}
	} else {
		return none
	}
	if caret_color.a == 0 {
		return none
	}
	rounded := rounded_text_span_rect(rect)
	return PaintCommand{
		kind: 'fill_rect'
		x: rounded.x
		y: rounded.y
		width: rounded.width
		height: rounded.height
		color: caret_color.serialize()
		opacity: opacity
	}
}

fn paint_empty_cursor(box &BlockBox, layout_node &Node, dom_node &dom.Node,
	position_node &dom.Node, opacity f64) ?PaintCommand {
	mut caret_layout_node := unsafe { layout_node }
	mut caret_x := box.x - box.padding.left
	mut caret_y := box.y - box.padding.top
	if voidptr(position_node) != voidptr(dom_node) {
		// Empty inline elements have no text fragment or standalone BlockBox.
		// Their Paintable retains the source layout node and resolves its
		// position through the containing line paintable.
		paintable := position_node.unsafe_paintable() or { return none }
		if paintable.layout_handle == unsafe { nil } {
			return none
		}
		position_layout_node := unsafe { &Node(paintable.layout_handle) }
		if !position_layout_node.is_inline_node() {
			return none
		}
		containing_block := position_layout_node.containing_block() or { return none }
		if voidptr(containing_block) != voidptr(layout_node) {
			return none
		}
		caret_layout_node = position_layout_node
		caret_position := paintable.box_type_agnostic_position()
		caret_x = caret_position.x()
		caret_y = caret_position.y()
	}
	caret_color := caret_layout_node.computed_values().caret_color()
	if caret_color.a == 0 {
		return none
	}
	rounded := rounded_text_span_rect(caret_rect_for_empty_line(caret_layout_node, caret_x, caret_y))
	return PaintCommand{
		kind: 'fill_rect'
		x: rounded.x
		y: rounded.y
		width: rounded.width
		height: rounded.height
		color: caret_color.serialize()
		opacity: opacity
	}
}

fn append_background_text_clip_runs(box &BlockBox, mut runs []PaintTextClipRun) {
	if box.paintable_with_lines {
		for line in box.lines {
			for command in unselected_text_fragment_commands(line.fragments, 1.0) {
				if command.kind != 'draw_text' || command.text == '' {
					continue
				}
				runs << PaintTextClipRun{
					x: command.x
					y: command.y
					width: command.width
					height: command.height
					text: command.text
					font_size: command.font_size
					bold: command.bold
					italic: command.italic
					mono: command.mono
					rtl: command.rtl
					glyph_run: command.glyph_run
					glyph_translation_x: command.glyph_translation_x
					glyph_translation_y: command.glyph_translation_y
					glyph_orientation: command.glyph_orientation
					font_smoothing: command.font_smoothing
				}
			}
		}
	}
	// Borrow each child: passing a loop copy's address would heap-allocate it.
	for i in 0 .. box.children.len {
		child := &box.children[i]
		// Backgrounds 4: descendants that are neither in flow nor floating do
		// not contribute, and their complete subtrees are skipped.
		if child.absolutely_positioned && !child.floating {
			continue
		}
		append_background_text_clip_runs(child, mut runs)
	}
}

// BackgroundPainting.cpp::compute_text_clip_paths(), represented as retained
// shaped-run inputs until the backend records the black glyph mask.
fn compute_text_clip_paths(box &BlockBox) []PaintTextClipRun {
	mut runs := []PaintTextClipRun{}
	append_background_text_clip_runs(box, mut runs)
	return runs
}

// Paint the decorating boxes generated by inline elements before their text. Consecutive word
// fragments from the same element are joined, so the background/border also covers collapsed spaces
// between words. A wrapping inline gets one decorating box per line.
struct InlineFragmentPaintCommands {
mut:
	decorations []PaintCommand
	outlines    []PaintCommand
}

fn inline_fragment_commands(fragments []TextFragment, opacity f64) InlineFragmentPaintCommands {
	mut commands := []PaintCommand{}
	mut outlines := []PaintCommand{}
	mut i := 0
	for i < fragments.len {
		decoration_start := commands.len
		outline_start := outlines.len
		first := fragments[i]
		if first.inline_node_id == 0 || first.decorations_from_piece {
			i++
			continue
		}
		mut j := i + 1
		for j < fragments.len && fragments[j].inline_node_id == first.inline_node_id
			&& !fragments[j].decorations_from_piece {
			j++
		}
		last := fragments[j - 1]
		effective_border := BoxEdges{
			top: first.border.top
			right: if last.fragment_right_edge_away { 0.0 } else { first.border.right }
			bottom: first.border.bottom
			left: if first.fragment_left_edge_away { 0.0 } else { first.border.left }
		}
		decorating_fragment := TextFragment{
			...first
			border: effective_border
		}
		unrounded_border_rect := painting.Rect{
			x: first.x - first.padding.left - effective_border.left
			y: first.y - first.padding.top - first.border.top
			width: last.x + last.width - first.x + first.padding.left + first.padding.right + effective_border.left + effective_border.right
			height: first.height + first.padding.top + first.padding.bottom + first.border.top + first.border.bottom
		}
		converter := painting.new_device_pixel_converter(1.0) or { return InlineFragmentPaintCommands{} }
		device_border_rect := converter.rounded_device_rect(unrounded_border_rect)
		left := f64(device_border_rect.x)
		top := f64(device_border_rect.y)
		width := f64(device_border_rect.width)
		height := f64(device_border_rect.height)
		border_rect := LayoutRect{left, top, width, height}
		specified_radii := BoxRadii{
			top_left: if first.fragment_left_edge_away {
				CornerRadius{}
			} else {
				first.border_radii.top_left
			}
			top_right: if last.fragment_right_edge_away {
				CornerRadius{}
			} else {
				first.border_radii.top_right
			}
			bottom_right: if last.fragment_right_edge_away {
				CornerRadius{}
			} else {
				first.border_radii.bottom_right
			}
			bottom_left: if first.fragment_left_edge_away {
				CornerRadius{}
			} else {
				first.border_radii.bottom_left
			}
		}
		fragment_radii := effective_box_radii(specified_radii, if first.fragment_left_edge_away
			|| last.fragment_right_edge_away {
			0.0
		} else {
			first.border_radius
		}, width, height)
		uniform_circle_radii := box_radii_are_uniform_circles(fragment_radii)
		radius := if uniform_circle_radii { fragment_radii.top_left.x } else { 0.0 }
		mut fragment_shadows := unsafe { first.shadows }
		if fragment_shadows.len == 0 {
			if shadow := first.shadow {
				fragment_shadows << shadow
			}
		}
		outer_shadows := fragment_shadows.filter(!it.inset)
		outer_start := commands.len
		paintable_box_paint_box_shadow(mut commands, outer_shadows, effective_border, first.border_colors, first.border_styles, fragment_radii, border_rect, border_rect, opacity)
		first_is_chromium := if run := first.paintable_fragment.glyph_run {
			run.font().font_rendering_policy == .chromium
		} else {
			first.chromium_decorations && first.paintable_fragment.glyph_run == none
				&& first.text == ''
		}
		if first_is_chromium && first.background_color.a == 255 {
			chromium_inset_opaque_shadow_clips(mut commands, outer_start, first.layout_handle)
		}
		background_start := commands.len
		background_isolated := first.background_images.any(background_image_layer_blend_mode(it) != .normal)
		if background_isolated {
			commands << PaintCommand{ kind: 'begin_background_blend_group' }
		}
		if first.background_color.a > 0 && !box_radii_are_zero(fragment_radii) {
			if uniform_circle_radii {
				commands << PaintCommand{
					kind: 'fill_rect'
					x: left
					y: top
					width: width
					height: height
					color: first.background_color.serialize()
					opacity: opacity
					radius: radius
				}
			} else {
				commands << PaintCommand{
					kind: 'fill_rounded_rect'
					x: left
					y: top
					width: width
					height: height
					color: first.background_color.serialize()
					opacity: opacity
					corner_radii: fragment_radii
				}
			}
		} else if first.background_color.a > 0 {
			commands << PaintCommand{
				kind: 'fill_rect'
				x: left
				y: top
				width: width
				height: height
				color: first.background_color.serialize()
				opacity: opacity
				radius: radius
			}
		}
		for layer_index := first.background_images.len - 1; layer_index >= 0; layer_index-- {
			layer := first.background_images[layer_index]
			origin := inline_background_box_rect(decorating_fragment, layer.origin, border_rect)
			clip := inline_background_box_rect(decorating_fragment, layer.clip, border_rect)
			if command := background_layer_command(layer, origin, clip, fragment_radii, opacity, radius, []f64{}, painting.Point{}, .auto_, none, LayoutRect{}, first_is_chromium, none) {
				commands << command
				if first_is_chromium {
					chromium_pair_background_image_color(mut commands)
				}
			}
		}
		if background_isolated {
			commands << PaintCommand{ kind: 'end_background_blend_group' }
		}
		set_force_dark_role_for_range(mut commands, background_start, commands.len, .background)
		append_inset_shadow_commands(mut commands, fragment_shadows, left + effective_border.left, top + effective_border.top, non_negative(width - effective_border.left - effective_border.right), non_negative(height - effective_border.top - effective_border.bottom), non_negative(radius - effective_border.top), opacity)
		border_colors := effective_border_colors(first.border_colors, first.border_color)
		chromium_border := first_is_chromium
		append_translated_border_commands(mut commands, effective_border, border_colors, first.border_styles, fragment_radii, left, top, width, height, opacity, chromium_border)
		append_translated_outline_commands(mut outlines, first.outline_width, first.outline_offset, first.outline_color, first.outline_style, first.outline_is_auto, fragment_radii, left, top, width, height, opacity, first_is_chromium)
		set_force_dark_backdrop_for_range(mut commands, decoration_start, commands.len,
			first.background_color)
		set_force_dark_backdrop_for_range(mut outlines, outline_start, outlines.len,
			first.background_color)
		i = j
	}
	return InlineFragmentPaintCommands{
		decorations: commands
		outlines: outlines
	}
}

fn inline_background_box_rect(fragment TextFragment, box_name string, border LayoutRect) LayoutRect {
	return match box_name.trim_space().to_lower() {
		'content-box' {
			LayoutRect{
				x: border.x + fragment.border.left + fragment.padding.left
				y: border.y + fragment.border.top + fragment.padding.top
				width: non_negative(border.width - fragment.border.left - fragment.border.right - fragment.padding.left - fragment.padding.right)
				height: non_negative(border.height - fragment.border.top - fragment.border.bottom - fragment.padding.top - fragment.padding.bottom)
			}
		}
		'padding-box' {
			LayoutRect{
				x: border.x + fragment.border.left
				y: border.y + fragment.border.top
				width: non_negative(border.width - fragment.border.left - fragment.border.right)
				height: non_negative(border.height - fragment.border.top - fragment.border.bottom)
			}
		}
		else { border }
	}
}

fn append_text_decoration_draw_line(mut commands []PaintCommand, from painting.IntPoint, to painting.IntPoint, color string, thickness int, style string, opacity f64) {
	commands << PaintCommand{
		kind: 'draw_line'
		x: from.x
		y: from.y
		width: to.x - from.x
		height: to.y - from.y
		color: color
		opacity: opacity
		points: [f64(from.x), f64(from.y), f64(to.x), f64(to.y)]
		stroke_width: thickness
		line_style: style
	}
}

fn triangle_wave_line_to(mut segments []painting.ClipPathSegment, mut points []painting.Point, point painting.Point) {
	segments << painting.ClipPathSegment{
		kind: .line_to
		point: point
	}
	points << point
}

// Direct translation of PaintableWithLines.cpp::build_triangle_wave_path().
fn build_triangle_wave_path(from painting.IntPoint, to painting.IntPoint, amplitude f64) painting.ClipPathVisualData {
	if from.y != to.y || amplitude <= 0 {
		return painting.ClipPathVisualData{}
	}
	start := painting.Point{f64(from.x), f64(from.y)}
	mut segments := [painting.ClipPathSegment{
		kind: .move_to
		point: start
	}]
	mut points := [start]
	wavelength := amplitude * 2.0
	half_wavelength := amplitude
	quarter_wavelength := amplitude / 2.0
	mut position := start
	mut remaining := math.abs(f64(to.x) - position.x)
	for remaining > wavelength {
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + quarter_wavelength, position.y - quarter_wavelength})
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + quarter_wavelength + half_wavelength, position.y + quarter_wavelength})
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + wavelength, position.y})
		position = painting.Point{position.x + wavelength, position.y}
		remaining = math.abs(f64(to.x) - position.x)
	}
	if remaining > quarter_wavelength {
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + quarter_wavelength, position.y - quarter_wavelength})
		position = painting.Point{position.x + quarter_wavelength, position.y}
		remaining = math.abs(f64(to.x) - position.x)
	} else if remaining >= 1 {
		fraction := remaining / quarter_wavelength
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + fraction * quarter_wavelength, position.y - fraction * quarter_wavelength})
		remaining = 0
	}
	if remaining > half_wavelength {
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + half_wavelength, position.y + quarter_wavelength})
		position = painting.Point{position.x + half_wavelength, position.y}
		remaining = math.abs(f64(to.x) - position.x)
	} else if remaining >= 1 {
		fraction := remaining / half_wavelength
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + fraction * half_wavelength, position.y - quarter_wavelength + fraction * half_wavelength})
		remaining = 0
	}
	if remaining >= 1 {
		fraction := remaining / quarter_wavelength
		triangle_wave_line_to(mut segments, mut points, painting.Point{position.x + fraction * quarter_wavelength, position.y + (1.0 - fraction) * quarter_wavelength})
	}
	return painting.ClipPathVisualData{
		segments: segments
		polygons: [points.clone()]
		polygon: points
	}
}

fn append_text_decoration_style(mut commands []PaintCommand, line string, start painting.IntPoint, end painting.IntPoint, color string, thickness int, style string, opacity f64) {
	mut line_start := start
	mut line_end := end
	match style {
		'double' {
			// Two parallel lines with a 1px gap, expanding away from the text.
			step := thickness + 1
			match line {
				'line-through' {
					line_start = painting.IntPoint{line_start.x, line_start.y - step / 2}
					line_end = painting.IntPoint{line_end.x, line_end.y - step / 2}
				}
				else {}
			}
			append_text_decoration_draw_line(mut commands, line_start, line_end, color, thickness, 'solid', opacity)
			second_y := if line == 'overline' { line_start.y - step } else { line_start.y + step }
			append_text_decoration_draw_line(mut commands, painting.IntPoint{line_start.x, second_y}, painting.IntPoint{line_end.x, second_y}, color, thickness, 'solid', opacity)
		}
		'wavy' {
			// The wave oscillates around its center. Move that center away from the text so its near
			// peaks do not overlap the glyphs.
			wave_offset := thickness / 2 + 1
			match line {
				'underline' {
					line_start = painting.IntPoint{line_start.x, line_start.y + wave_offset}
					line_end = painting.IntPoint{line_end.x, line_end.y + wave_offset}
				}
				'overline' {
					line_start = painting.IntPoint{line_start.x, line_start.y - wave_offset}
					line_end = painting.IntPoint{line_end.x, line_end.y - wave_offset}
				}
				else {}
			}
			path := build_triangle_wave_path(line_start, line_end, f64(thickness * 3))
			if path.segments.len == 0 {
				return
			}
			mut flat_points := []f64{}
			for point in path.polygon {
				flat_points << point.x
				flat_points << point.y
			}
			commands << PaintCommand{
				kind: 'draw_svg_path'
				x: math.min(f64(line_start.x), f64(line_end.x))
				y: math.min(f64(line_start.y), f64(line_end.y)) - f64(thickness * 3)
				width: math.abs(f64(line_end.x - line_start.x))
				height: f64(thickness * 6)
				opacity: opacity
				svg_data: &PaintSVGPathData{
					path: painting_path_svg(path)
					path_data: compatibility_pack_clip_path_segments(path)
					path_polygons: [flat_points.clone()]
					stroke_linecap: 1
					stroke_linejoin: 1
					stroke_miterlimit: 0
				}
				points: flat_points
				stroke_color: color
				stroke_width: thickness
			}
		}
		else {
			append_text_decoration_draw_line(mut commands, line_start, line_end, color, thickness, style, opacity)
		}
	}
}

struct TextDecorationSegment {
	start_x int
	end_x   int
}

// CSS Text Decoration 4 skip-ink. LibGfx returns one horizontal ink interval per shaped glyph;
// dilating those intervals creates the visible gaps around descenders and overline intersections.
fn text_decoration_skip_ink_segments(fragment TextFragment, line string, start_x int, end_x int, line_y int, thickness int) []TextDecorationSegment {
	if !fragment.decoration_skip_ink || line !in ['underline', 'overline'] {
		return [TextDecorationSegment{
			start_x: start_x
			end_x: end_x
		}]
	}
	glyph_run := fragment.paintable_fragment.glyph_run or {
		return [TextDecorationSegment{
			start_x: start_x
			end_x: end_x
		}]
	}
	blob_origin_x := fragment.x
	blob_origin_y := fragment.y + fragment.baseline
	half_thickness := f64(thickness) / 2.0
	y_top := f32(f64(line_y) - half_thickness - blob_origin_y)
	y_bottom := f32(f64(line_y) + half_thickness - blob_origin_y)
	intervals := glyph_run.glyph_intercepts(1, y_top, y_bottom)
	if intervals.len == 0 {
		return [TextDecorationSegment{
			start_x: start_x
			end_x: end_x
		}]
	}
	dilation := math.max(fragment.font_size / 20.0, 2.0)
	mut segments := []TextDecorationSegment{}
	mut current_x := int(math.round(fragment.x))
	mut index := 0
	for index + 1 < intervals.len {
		gap_start := int(math.floor(f64(intervals[index]) + blob_origin_x - dilation))
		gap_end := int(math.ceil(f64(intervals[index + 1]) + blob_origin_x + dilation))
		segment_start := if current_x > start_x { current_x } else { start_x }
		segment_end := if gap_start < end_x { gap_start } else { end_x }
		if segment_start < segment_end {
			segments << TextDecorationSegment{
				start_x: segment_start
				end_x: segment_end
			}
		}
		if gap_end > current_x {
			current_x = gap_end
		}
		index += 2
	}
	segment_start := if current_x > start_x { current_x } else { start_x }
	if segment_start < end_x {
		segments << TextDecorationSegment{
			start_x: segment_start
			end_x: end_x
		}
	}
	return segments
}

// Direct translation of PaintableWithLines.cpp::paint_text_decoration().
fn paint_text_decoration(fragment TextFragment, opacity f64) []PaintCommand {
	if fragment.decoration == '' || fragment.decoration == 'none' {
		return []PaintCommand{}
	}
	mut glyph_height := fragment.glyph_height
	mut font_ascent := fragment.font_ascent
	mut font_descent := fragment.font_descent
	if !fragment.font_metrics_set {
		font := &platform.Font{
			family: if fragment.mono { 'monospace' } else { 'sans-serif' }
			point_size: f32(fragment.font_size)
			weight: if fragment.bold { 700 } else { 400 }
		}
		metrics := font.pixel_metrics()
		glyph_height = f64(metrics.size)
		font_ascent = f64(metrics.ascent)
		font_descent = f64(metrics.descent)
	}
	typographic_height := font_ascent + font_descent
	baseline := if fragment.baseline_set {
		fragment.baseline
	} else {
		font_ascent + (fragment.height - typographic_height) / 2.0
	}
	base_color := if fragment.decoration_color_set {
		fragment.decoration_color.serialize()
	} else {
		fragment.color.serialize()
	}
	css_thickness := if fragment.decoration_thickness_set || fragment.decoration_thickness > 0 {
		math.max(fragment.decoration_thickness, 1.0)
	} else {
		math.max(glyph_height * 0.1, 1.0)
	}
	mut commands := chromium_ancestor_text_decoration_commands(fragment, opacity)
	for input_line in fragment.decoration.fields() {
		mut line := input_line
		mut color := base_color
		mut line_thickness := css_thickness
		mut thickness := int(math.round(line_thickness))
		mut style := if fragment.decoration_style == '' {
			'solid'
		} else {
			fragment.decoration_style
		}
		mut underline_offset := fragment.text_underline_offset
		if line == 'spelling-error' {
			color = 'rgb(255 0 0)'
			line_thickness = 1
			thickness = 1
			style = 'wavy'
			line = 'underline'
			underline_offset = 2
		} else if line == 'grammar-error' {
			color = 'rgb(0 128 0)'
			line_thickness = 1
			thickness = 1
			style = 'wavy'
			line = 'underline'
			underline_offset = 2
		}
		if line == 'none' || line == 'blink' {
			return commands
		}
		if fragment.chromium_decorations && line == 'underline' && style == 'solid'
			&& fragment.text_underline_position != 'under' {
			previous_count := commands.len
			append_chromium_solid_underline(mut commands, fragment, font_ascent, color, opacity)
			if previous_count > 0 && commands.len == previous_count + 1 {
				previous := commands[previous_count - 1]
				current := commands[previous_count]
				if previous.kind == 'fill_rect' && previous.antialiased_rect
					&& previous.clip_outs == current.clip_outs
					&& previous.x == current.x && previous.y == current.y
					&& previous.width == current.width && previous.height == current.height {
					commands[previous_count - 1].underlays_next = true
				}
			}
			continue
		}
		mut line_y := 0.0
		match line {
			'underline' {
				position := if fragment.text_underline_position == 'under' {
					baseline + font_descent
				} else {
					baseline
				}
				// The position denotes the near edge of the stroke; painting consumes its center.
				line_y = fragment.y + position + underline_offset + line_thickness / 2.0
			}
			'overline' {
				line_y = fragment.y + baseline - glyph_height - line_thickness / 2.0
			}
			'line-through' {
				// Gfx stores point size in typographic points while this adapter carries CSS pixels.
				line_y = fragment.y + baseline - fragment.font_size * 0.75 * 0.5
			}
			else {
				continue
			}
		}
		start_x := int(math.round(fragment.x))
		end_x := int(math.round(fragment.x + fragment.width))
		rounded_y := int(math.round(line_y))
		segments := text_decoration_skip_ink_segments(fragment, line, start_x, end_x, rounded_y, thickness)
		for segment in segments {
			append_text_decoration_style(mut commands, line, painting.IntPoint{segment.start_x, rounded_y}, painting.IntPoint{segment.end_x, rounded_y}, color, thickness, style, opacity)
		}
	}
	return commands
}

// Blink paints a themed control into its pixel-snapped box, rounding each edge,
// and then uses the largest centered square.
fn chromium_snapped_control_rect(x f64, y f64, width f64, height f64) painting.IntRect {
	left := int(math.floor(x + 0.5))
	top := int(math.floor(y + 0.5))
	snapped_width := int(math.floor(x + width + 0.5)) - left
	snapped_height := int(math.floor(y + height + 0.5)) - top
	side := if snapped_width < snapped_height { snapped_width } else { snapped_height }
	return painting.IntRect{
		x:      left + (snapped_width - side) / 2
		y:      top + (snapped_height - side) / 2
		width:  side
		height: side
	}
}

// Blink's NativeThemeBase::PaintCheckboxRadioCommon() for an enabled, unchecked
// check box: a white background inset by a fifth of the 1px border, then the
// #767676 border stroked half a pixel inside the control, both with a 2px
// radius. Both shapes blend over the page through the isolated GPU backend in
// one pass, as Brave's GPU rasterization draws them into one raster tile: a
// multisampled tile resolves their shared edge pixels together.
fn append_chromium_unchecked_checkbox(mut commands []PaintCommand, rect painting.IntRect, scale f64, opacity f64) {
	theme := &PaintCheckboxThemeData{rect, scale}
	commands << PaintCommand{
		kind:                'fill_rect'
		x:                   f64(rect.x) + 0.2 * scale
		y:                   f64(rect.y) + 0.2 * scale
		width:               f64(rect.width) - 0.4 * scale
		height:              f64(rect.height) - 0.4 * scale
		radius:              2 * scale
		underlays_next:      true
		checkbox_theme_data: theme
		color:               'rgb(255 255 255)'
		opacity:             opacity
		force_dark_role:     .background
		force_dark_role_set: true
	}
	commands << PaintCommand{
		kind:                'stroke_rounded_rect'
		x:                   f64(rect.x) + 0.5 * scale
		y:                   f64(rect.y) + 0.5 * scale
		width:               f64(rect.width) - scale
		height:              f64(rect.height) - scale
		radius:              2 * scale
		stroke_width:        scale
		checkbox_theme_data: theme
		color:               'rgb(118 118 118)'
		opacity:             opacity
		force_dark_role:     .border
		force_dark_role_set: true
	}
}

// Blink's TextDecorationInfo::ComputeUnderlineLineData() for a solid auto or
// from-font underline: the line starts below the rounded ascent by a gap of
// half its thickness (none for an explicit offset), and DecorationLinePainter
// snaps its top to the pixel grid and floors its thickness. Only the inline
// ends remain fractional and antialiased.
fn append_chromium_solid_underline(mut commands []PaintCommand, fragment TextFragment, font_ascent f64, color string, opacity f64) {
	specified_thickness := if fragment.decoration_thickness_set {
		math.round(fragment.decoration_thickness)
	} else {
		fragment.font_size / 10.0
	}
	thickness := math.max(specified_thickness, 1.0)
	gap := if fragment.text_underline_offset_auto {
		math.max(1.0, math.ceil(thickness / 2.0))
	} else {
		0.0
	}
	offset := if fragment.text_underline_offset_auto {
		0.0
	} else {
		math.round(fragment.text_underline_offset)
	}
	line_offset := math.round(font_ascent) + gap + offset
	top := math.floor(fragment.y + line_offset + 0.5)
	height := math.max(math.floor(thickness), 1.0)
	if fragment.width <= 0 {
		return
	}
	commands << PaintCommand{
		kind:             'fill_rect'
		x:                fragment.x
		y:                top
		width:            fragment.width
		height:           height
		color:            color
		opacity:          opacity
		antialiased_rect: true
		clip_outs:        chromium_skip_ink_clips(fragment, font_ascent, line_offset, thickness,
			top, height)
	}
}

// TextPainter::ClipDecorationLine(): glyph outlines crossing the decoration,
// inset by half a pixel vertically, are clipped out without antialiasing over
// their extent, dilated horizontally by the thickness and vertically by a
// pixel. Returns left, top, right and bottom for each clip in paint order.
// The top of the skip-ink stripe below the baseline. Blink rounds a text line's
// top to a whole pixel before it draws the glyphs, but places decorations from
// the unrounded top, so the stripe moves against the glyphs by the fraction the
// line top was rounded by.
fn chromium_skip_ink_stripe_upper(line_offset f64, font_ascent f64, fragment_y f64) f64 {
	return line_offset + 0.5 - math.round(font_ascent) + (fragment_y - math.round(fragment_y))
}

fn chromium_skip_ink_clips(fragment TextFragment, font_ascent f64, line_offset f64, thickness f64, top f64, height f64) []f64 {
	if !fragment.decoration_skip_ink {
		return []f64{}
	}
	glyph_run := fragment.paintable_fragment.glyph_run or { return []f64{} }
	upper := chromium_skip_ink_stripe_upper(line_offset, font_ascent, fragment.y)
	stripe := math.max(thickness - 1.0, 0.0)
	intervals := glyph_run.glyph_intercepts(1, f32(upper), f32(upper + stripe))
	dilation := math.min(thickness, 13.0)
	mut clips := []f64{}
	for index := 0; index + 1 < intervals.len; index += 2 {
		clips << [fragment.x + f64(intervals[index]) - dilation, top - 0.5,
			fragment.x + f64(intervals[index + 1]) + dilation, top + height + 0.5]
	}
	return clips
}

fn decoration_commands(fragment TextFragment, opacity f64) []PaintCommand {
	return paint_text_decoration(fragment, opacity)
}

pub fn resolved_background_gradient_tiles(command PaintCommand) []painting.Rect {
	if !command.gradient_background_layer {
		return [painting.Rect{command.x, command.y, command.width, command.height}]
	}
	image_data := paint_image_data(command.image_data)
	background_data := image_data.background_layer_data or { return []painting.Rect{} }
	resolved := painting.resolve_background_layer_without_intrinsic(painting.BackgroundLayerWithoutIntrinsicResolutionInput{
		layer: background_data.layer
		image_id: 'gradient'
		background_positioning_area: painting.Rect{command.x, command.y, command.width, command.height}
		resolution_context: background_data.resolution_context
	}) or { return []painting.Rect{} }
	return painting.background_tiles_limited(resolved, painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, painting.Rect{image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height}, 4096)
}

fn stable_sort_box_references_by_z(items []&BlockBox) []&BlockBox {
	// StackingContext::sort() uses z-index and the retained tree-order index as
	// a total key. Do the same here so the general-purpose sort is O(n log n)
	// without relying on sort stability for equal z-index values.
	mut sortable := []PaintOrderSortEntry{cap: items.len}
	for tree_order, box in items {
		sortable << PaintOrderSortEntry{
			box: unsafe { box }
			tree_order: tree_order
		}
	}
	sortable.sort_with_compare(fn (first &PaintOrderSortEntry, second &PaintOrderSortEntry) int {
		if first.box.z_index < second.box.z_index {
			return -1
		}
		if first.box.z_index > second.box.z_index {
			return 1
		}
		return first.tree_order - second.tree_order
	})
	mut result := []&BlockBox{cap: sortable.len}
	for entry in sortable {
		result << entry.box
	}
	return result
}

fn affine_identity() [6]f64 {
	return [f64(1), 0, 0, 1, 0, 0]!
}

fn affine_is_compact_identity(matrix [6]f64) bool {
	return matrix == [6]f64{}
}

fn normalized_affine(matrix [6]f64) [6]f64 {
	return if affine_is_compact_identity(matrix) { affine_identity() } else { matrix }
}

fn multiply_affine(left_value [6]f64, right_value [6]f64) [6]f64 {
	left := normalized_affine(left_value)
	right := normalized_affine(right_value)
	a := left[0] * right[0] + left[2] * right[1]
	b := left[1] * right[0] + left[3] * right[1]
	c := left[0] * right[2] + left[2] * right[3]
	d := left[1] * right[2] + left[3] * right[3]
	e := left[0] * right[4] + left[2] * right[5] + left[4]
	f := left[1] * right[4] + left[3] * right[5] + left[5]
	return [f64(a), b, c, d, e, f]!
}

fn translated_affine(dx f64, dy f64) [6]f64 {
	return [f64(1), 0, 0, 1, dx, dy]!
}

fn affine_around_origin(matrix [6]f64, origin_x f64, origin_y f64) [6]f64 {
	return multiply_affine(translated_affine(origin_x, origin_y), multiply_affine(matrix, translated_affine(-origin_x, -origin_y)))
}

fn nested_viewport_mask_operation(operation PaintMaskOperation, ancestor [6]f64) PaintMaskOperation {
	return PaintMaskOperation{
		...operation
		transform: multiply_affine(ancestor, operation.transform)
	}
}

fn nested_viewport_clip(clip PaintClip, ancestor [6]f64) PaintClip {
	mut cache_key := clip.cache_key
	if clip.is_svg_mask || clip.is_svg_content_mask {
		for value in ancestor {
			cache_key = svg_clip_hash_mix(cache_key, math.f64_bits(value))
		}
	}
	return PaintClip{
		...clip
		path_components: clip.path_components.map(PaintPath{
			...it
			transform: multiply_affine(ancestor, it.transform)
		})
		mask_operations: clip.mask_operations.map(nested_viewport_mask_operation(it, ancestor))
		cache_key: cache_key
		transform: multiply_affine(ancestor, clip.transform)
	}
}

// DisplayListPlayerSkia translates the canvas by the nested display-list rect
// before replay. The compatibility player stores transforms per command, so
// compose that translation and the embedding paintable's visual transform into
// each command (including retained clip/mask geometry) at the replay boundary.
pub fn paint_command_for_nested_viewport(command PaintCommand, outer_transform [6]f64,
	nested_origin painting.IntPoint, outer_opacity f64) PaintCommand {
	ancestor := multiply_affine(outer_transform, translated_affine(f64(nested_origin.x), f64(nested_origin.y)))
	mut transformed := command
	transformed.transform = multiply_affine(ancestor, command.transform)
	transformed.opacity = command.opacity * outer_opacity
	if command.has_clip {
		mapped_clip := compatibility_affine_map_rect(ancestor, LayoutRect{
			x: command.clip_x
			y: command.clip_y
			width: command.clip_width
			height: command.clip_height
		})
		transformed.clip_x = mapped_clip.x
		transformed.clip_y = mapped_clip.y
		transformed.clip_width = mapped_clip.width
		transformed.clip_height = mapped_clip.height
	}
	if command.clip_list != unsafe { nil } {
		transformed.clip_list = &PaintClipList{
			items: command.clip_list.items.map(nested_viewport_clip(it, ancestor))
		}
	}
	// The retained layer snapshot can be shared by recordings. Transform only
	// this nested replay's mask and leave the earlier recording untouched.
	if command.mask_clip_data != none || command.visual_layer_data != none {
		clip := nested_viewport_clip(paint_mask_clip(command.mask_clip_data, command.visual_layer_data),
			ancestor)
		transformed.mask_clip_data = &PaintClip{
			...clip
			transform: [clip.transform[0], clip.transform[1], clip.transform[2],
				clip.transform[3], clip.transform[4], clip.transform[5]]!
		}
	}
	return transformed
}

// Format a px value: drop the fractional part for whole numbers so snapshots read cleanly.
fn fmt_px(v f64) string {
	if v == f64(int(v)) {
		return int(v).str()
	}
	return v.str()
}

// The margin-box height: the vertical space this box occupies in its parent's flow.
pub fn (b &BlockBox) margin_box_height() f64 {
	return b.margin.top + b.border.top + b.padding.top + b.height + b.padding.bottom + b.border.bottom + b.margin.bottom
}

// The margin-box width: content plus padding, border, and margin on both sides.
pub fn (b &BlockBox) margin_box_width() f64 {
	return b.margin.left + b.border.left + b.padding.left + b.width + b.padding.right + b.border.right + b.margin.right
}

// Older callers construct renderer boxes with only `border_color`. Treat an entirely empty color
// set as that legacy uniform color; translated layout paths always populate all four colors.
fn effective_border_colors(colors BoxColors, fallback css.Color) BoxColors {
	if colors.top.a == 0 && colors.right.a == 0 && colors.bottom.a == 0 && colors.left.a == 0 && fallback.a > 0 {
		return BoxColors{fallback, fallback, fallback, fallback}
	}
	return colors
}

fn box_radii_are_zero(radii BoxRadii) bool {
	return radii.top_left.x == 0 && radii.top_left.y == 0 && radii.top_right.x == 0 && radii.top_right.y == 0 && radii.bottom_right.x == 0 && radii.bottom_right.y == 0 && radii.bottom_left.x == 0 && radii.bottom_left.y == 0
}

fn effective_box_radii(radii BoxRadii, fallback f64, width f64, height f64) BoxRadii {
	if box_radii_are_zero(radii) && fallback > 0 {
		corner := CornerRadius{fallback, fallback}
		return normalize_box_radii(BoxRadii{corner, corner, corner, corner}, width, height)
	}
	return normalize_box_radii(radii, width, height)
}

fn box_radii_are_uniform_circles(radii BoxRadii) bool {
	return radii.top_left.x == radii.top_left.y && radii.top_left == radii.top_right && radii.top_left == radii.bottom_right && radii.top_left == radii.bottom_left
}

fn append_ellipse_arc(mut points []f64, center_x f64, center_y f64, radius CornerRadius, start_angle f64, end_angle f64) {
	steps := 5
	for step in 0 .. steps {
		t := f64(step) / f64(steps - 1)
		angle := start_angle + (end_angle - start_angle) * t
		points << center_x + radius.x * math.cos(angle)
		points << center_y + radius.y * math.sin(angle)
	}
}

// Tessellate retained rounded-rectangle geometry for immediate backends which only expose polygon
// fills. Native and SVG backends consume the radii directly and preserve elliptical arcs.
pub fn rounded_rect_points(x f64, y f64, width f64, height f64, input_radii BoxRadii) []f64 {
	radii := normalize_box_radii(input_radii, width, height)
	mut points := []f64{}
	append_ellipse_arc(mut points, x + radii.top_left.x, y + radii.top_left.y, radii.top_left, math.pi, math.pi * 1.5)
	append_ellipse_arc(mut points, x + width - radii.top_right.x, y + radii.top_right.y, radii.top_right, math.pi * 1.5, math.pi * 2.0)
	append_ellipse_arc(mut points, x + width - radii.bottom_right.x, y + height - radii.bottom_right.y, radii.bottom_right, 0, math.pi * 0.5)
	append_ellipse_arc(mut points, x + radii.bottom_left.x, y + height - radii.bottom_left.y, radii.bottom_left, math.pi * 0.5, math.pi)
	return points
}

fn painting_borders_from_transport(border BoxEdges, colors BoxColors,
	styles BoxBorderStyles) painting.DeviceBordersData {
	return painting.DeviceBordersData{
		top: painting.DeviceBorderData{
			color: painting.Color{colors.top.r, colors.top.g, colors.top.b, colors.top.a}
			line_style: styles.top
			width: int(math.round(border.top))
		}
		right: painting.DeviceBorderData{
			color: painting.Color{colors.right.r, colors.right.g, colors.right.b, colors.right.a}
			line_style: styles.right
			width: int(math.round(border.right))
		}
		bottom: painting.DeviceBorderData{
			color: painting.Color{colors.bottom.r, colors.bottom.g, colors.bottom.b, colors.bottom.a}
			line_style: styles.bottom
			width: int(math.round(border.bottom))
		}
		left: painting.DeviceBorderData{
			color: painting.Color{colors.left.r, colors.left.g, colors.left.b, colors.left.a}
			line_style: styles.left
			width: int(math.round(border.left))
		}
	}
}

fn painting_radii_from_transport(radii BoxRadii) painting.CornerRadii {
	return painting.CornerRadii{
		top_left: painting.CornerRadius{
			horizontal: int(math.floor(math.max(0.0, radii.top_left.x)))
			vertical: int(math.floor(math.max(0.0, radii.top_left.y)))
		}
		top_right: painting.CornerRadius{
			horizontal: int(math.floor(math.max(0.0, radii.top_right.x)))
			vertical: int(math.floor(math.max(0.0, radii.top_right.y)))
		}
		bottom_right: painting.CornerRadius{
			horizontal: int(math.floor(math.max(0.0, radii.bottom_right.x)))
			vertical: int(math.floor(math.max(0.0, radii.bottom_right.y)))
		}
		bottom_left: painting.CornerRadius{
			horizontal: int(math.floor(math.max(0.0, radii.bottom_left.x)))
			vertical: int(math.floor(math.max(0.0, radii.bottom_left.y)))
		}
	}
}

fn append_translated_border_commands(mut commands []PaintCommand, border BoxEdges,
	colors BoxColors, styles BoxBorderStyles, radii BoxRadii, x f64, y f64, width f64,
	height f64, opacity f64, chromium bool) {
	start := commands.len
	left := int(math.round(x))
	top := int(math.round(y))
	rect := painting.IntRect{
		x: left
		y: top
		width: int(math.round(x + width)) - left
		height: int(math.round(y + height)) - top
	}
	if chromium && append_chromium_uniform_border(mut commands, border, colors, styles, radii, rect, opacity) {
		set_force_dark_role_for_range(mut commands, start, commands.len, .border)
		return
	}
	if chromium && append_chromium_single_rounded_border(mut commands, border, colors, styles, radii, rect, opacity) {
		set_force_dark_role_for_range(mut commands, start, commands.len, .border)
		return
	}
	for display_command in painting.paint_all_borders(rect, painting_radii_from_transport(radii), painting_borders_from_transport(border, colors, styles)) {
		append_painting_display_command(mut commands, display_command, opacity)
	}
	set_force_dark_role_for_range(mut commands, start, commands.len, .border)
}

fn inflated_outline_corner(radius CornerRadius, horizontal f64, vertical f64) CornerRadius {
	return CornerRadius{
		x: if radius.x == 0 { 0.0 } else { math.max(0.0, radius.x + horizontal) }
		y: if radius.y == 0 { 0.0 } else { math.max(0.0, radius.y + vertical) }
	}
}

// Direct compatibility lowering of PaintableBox.cpp's outline phase. The line
// style is resolved before this point, while the retained auto flag preserves
// the user-agent focus-ring force-dark exemption.
fn append_translated_outline_commands(mut commands []PaintCommand, outline_width f64,
	outline_offset f64, outline_color css.Color, outline_style painting.LineStyle,
	outline_is_auto bool, border_radii BoxRadii, border_x f64, border_y f64, border_width f64,
	border_height f64, opacity f64, chromium bool) {
	start := commands.len
	outline_painting_color := painting.Color{outline_color.r, outline_color.g, outline_color.b, outline_color.a}
	outline_borders := painting.borders_data_for_outline(outline_painting_color, outline_style, outline_width) or { return }
	mut offset_x := outline_offset
	mut offset_y := outline_offset
	if border_width / 2.0 + offset_x < 0 {
		offset_x = -border_width / 2.0
	}
	if border_height / 2.0 + offset_y < 0 {
		offset_y = -border_height / 2.0
	}
	left_inflate := outline_width + offset_x
	right_inflate := outline_width + offset_x
	top_inflate := outline_width + offset_y
	bottom_inflate := outline_width + offset_y
	outline_radii := BoxRadii{
		top_left: inflated_outline_corner(border_radii.top_left, left_inflate, top_inflate)
		top_right: inflated_outline_corner(border_radii.top_right, right_inflate, top_inflate)
		bottom_right: inflated_outline_corner(border_radii.bottom_right, right_inflate, bottom_inflate)
		bottom_left: inflated_outline_corner(border_radii.bottom_left, left_inflate, bottom_inflate)
	}
	converter := painting.new_device_pixel_converter(1.0) or { return }
	outline_rect := converter.rounded_device_rect(painting.Rect{
		x: border_x - left_inflate
		y: border_y - top_inflate
		width: border_width + left_inflate + right_inflate
		height: border_height + top_inflate + bottom_inflate
	})
	widths := BoxEdges{outline_width, outline_width, outline_width, outline_width}
	colors := BoxColors{outline_color, outline_color, outline_color, outline_color}
	styles := BoxBorderStyles{outline_style, outline_style, outline_style, outline_style}
	// Solid outlines use the same analytic rounded stroke as solid borders.
	// Four separately rasterized paths otherwise leave seams at their corners.
	if !chromium || !append_chromium_uniform_border(mut commands, widths, colors, styles,
		outline_radii, outline_rect, opacity) {
		for display_command in painting.paint_all_borders(outline_rect, painting_radii_from_transport(outline_radii), outline_borders.to_device_pixels(converter)) {
			append_painting_display_command(mut commands, display_command, opacity)
		}
	}
	set_force_dark_role_for_range(mut commands, start, commands.len, if outline_is_auto {
		painting.ForceDarkRole.none_
	} else {
		painting.ForceDarkRole.border
	})
}

struct LegacyTableCellPlacement {
	element  &dom.Element = unsafe { nil }
	row      int
	column   int
	row_span int = 1
	col_span int = 1
}

// A grid item's auto-flow placement: its starting column and row, and how many columns it spans.
struct GridPlacement {
	col  int = -1
	row  int = -1
	span int = 1
}

struct LegacyGridAxisPlacement {
	start int = -1
	span  int = 1
}

struct LegacyGridTrackSizing {
mut:
	base         f64
	limit        f64
	flex         f64
	stretch_auto bool
}

struct LegacyGridAxisRect {
	start f64
	size  f64
}

// A float's vertical band and the inner edge past which in-flow inline content sits: for a left
// float `inner_edge` is its right margin edge (content starts to the right); for a right float it is
// its left margin edge (content ends to the left). Coordinates are in the local (content-top = 0)
// frame, matching line boxes.
struct FloatBand {
	is_left    bool
	top        f64
	bottom     f64
	inner_edge f64
}

struct WhiteSpaceBehavior {
	collapse string
	wrap     string
	trim     string
}

fn (white_space WhiteSpaceBehavior) preserves_spaces() bool {
	return white_space.collapse in ['preserve', 'preserve-spaces', 'break-spaces']
}

fn scale_corner_radius(radius CornerRadius, factor f64) CornerRadius {
	return CornerRadius{radius.x * factor, radius.y * factor}
}

fn normalize_box_radii(radii BoxRadii, width f64, height f64) BoxRadii {
	mut factor := 1.0
	available_sizes := [width, width, height, height]!
	radius_sums := [radii.top_left.x + radii.top_right.x, radii.bottom_left.x + radii.bottom_right.x,
		radii.top_left.y + radii.bottom_left.y, radii.top_right.y + radii.bottom_right.y]!
	for index, sum in radius_sums {
		available := available_sizes[index]
		if sum > 0 && available / sum < factor {
			factor = available / sum
		}
	}
	return BoxRadii{
		top_left: scale_corner_radius(radii.top_left, factor)
		top_right: scale_corner_radius(radii.top_right, factor)
		bottom_right: scale_corner_radius(radii.bottom_right, factor)
		bottom_left: scale_corner_radius(radii.bottom_left, factor)
	}
}

pub struct GradientStop {
pub:
	color  css.Color
	offset f64
}

// A resolved CSS gradient background image. Linear vectors and radial centers/radii use
// objectBoundingBox fractions; conic start angles are stored in degrees (CSS: 0deg points upward).
pub struct LinearGradient {
pub:
	x1                   f64
	y1                   f64
	x2                   f64
	y2                   f64
	colors               []css.Color // retained for compatibility with callers inspecting parsed colors
	stops                []GradientStop
	interpolation_method ?css.ColorInterpolationMethod
	css_angle_degrees    ?f64
	radial               bool // compatibility discriminator; `kind` is authoritative
	kind                 string = 'linear' // linear/radial/conic
	center_x             f64 = 0.5
	center_y             f64 = 0.5
	radius_x             f64 = 0.5
	radius_y             f64 = 0.5
	start_degrees        f64
}

struct ParsedGradientStops {
	colors []css.Color
	stops  []GradientStop
}

fn gradient_stops_or_fallback(gradient LinearGradient) []GradientStop {
	if gradient.stops.len > 0 {
		return gradient.stops
	}
	mut stops := []GradientStop{cap: gradient.colors.len}
	for index, color in gradient.colors {
		stops << GradientStop{
			color: color
			offset: if gradient.colors.len > 1 {
				f64(index) / f64(gradient.colors.len - 1)
			} else {
				0.0
			}
		}
	}
	return stops
}

fn gradient_stop_count(gradient LinearGradient) int {
	return if gradient.stops.len > 0 { gradient.stops.len } else { gradient.colors.len }
}

fn gradient_stop_at(gradient LinearGradient, index int) GradientStop {
	if gradient.stops.len > 0 { return gradient.stops[index] }
	return GradientStop{gradient.colors[index], if gradient.colors.len > 1 {
		f64(index) / f64(gradient.colors.len - 1)
	} else { 0.0 }}
}

// Sum-type construction boxes its enum in current V. Share the immutable
// default instead of allocating one box for every interpolation sample.
const fallback_gradient_interpolation = css.ColorInterpolationMethod(css.RectangularColorSpace.srgb)

pub fn gradient_color_at(gradient LinearGradient, position f64) css.Color {
	count := gradient_stop_count(gradient)
	if count == 0 {
		return css.Color{0, 0, 0, 0}
	}
	if count == 1 {
		return gradient_stop_at(gradient, 0).color
	}
	minimum := gradient_stop_at(gradient, 0).offset
	maximum := gradient_stop_at(gradient, count - 1).offset
	p := if position < minimum {
		minimum
	} else if position > maximum {
		maximum
	} else {
		position
	}
	mut right := 1
	for right < count && gradient_stop_at(gradient, right).offset < p {
		right++
	}
	if right >= count {
		return gradient_stop_at(gradient, count - 1).color
	}
	left := gradient_stop_at(gradient, right - 1)
	next := gradient_stop_at(gradient, right)
	span := next.offset - left.offset
	t := if span > 0 { (p - left.offset) / span } else { 1.0 }
	method := gradient.interpolation_method or { fallback_gradient_interpolation }
	return css.interpolate_gradient_color(left.color, next.color, t, method)
}

// CoreGraphics only interpolates the component values supplied to CGGradient. Sample each
// resolved CSS stop span so the native one-draw gradient path retains Skia's premultiplied-alpha
// and non-sRGB interpolation semantics. Original stop boundaries are kept (including duplicate
// positions), so hard color transitions remain hard instead of being spread over a sample.
pub fn sampled_gradient_stops(gradient LinearGradient, subdivisions int) []GradientStop {
	mut sampled := []GradientStop{}
	sampled_gradient_stops_into(gradient, subdivisions, mut sampled)
	return sampled
}

// The caller owns and reuses `sampled`; it must not alias the source stops.
pub fn sampled_gradient_stops_into(gradient LinearGradient, subdivisions int,
	mut sampled []GradientStop) {
	sampled.clear()
	count := gradient_stop_count(gradient)
	if count == 0 {
		return
	}
	if count == 1 {
		sampled << GradientStop{gradient_stop_at(gradient, 0).color, 0.0}
		sampled << GradientStop{gradient_stop_at(gradient, 0).color, 1.0}
		return
	}

	steps := math.max(subdivisions, 1)
	sampled << GradientStop{
		color: gradient_color_at(gradient, 0.0)
		offset: 0.0
	}
	for index := 1; index < count; index++ {
		left := gradient_stop_at(gradient, index - 1)
		right := gradient_stop_at(gradient, index)
		span := right.offset - left.offset
		if span <= 0 {
			if right.offset >= 0 && right.offset <= 1 {
				sampled << GradientStop{right.color, right.offset}
			}
			continue
		}
		visible_start := math.max(left.offset, 0.0)
		visible_end := math.min(right.offset, 1.0)
		if visible_end < visible_start {
			continue
		}
		if visible_start > sampled[sampled.len - 1].offset {
			sampled << GradientStop{
				color: gradient_color_at(gradient, visible_start)
				offset: visible_start
			}
		}
		for sample in 1 .. steps {
			offset := visible_start + (visible_end - visible_start) * f64(sample) / f64(steps)
			if offset > 0 && offset < 1 {
				sampled << GradientStop{
					color: gradient_color_at(gradient, offset)
					offset: offset
				}
			}
		}
		if right.offset >= 0 && right.offset <= 1 {
			sampled << GradientStop{right.color, right.offset}
		} else if visible_end == 1.0 {
			sampled << GradientStop{
				color: gradient_color_at(gradient, 1.0)
				offset: 1.0
			}
		}
	}
	if sampled[sampled.len - 1].offset < 1 {
		sampled << GradientStop{
			color: gradient_color_at(gradient, 1.0)
			offset: 1.0
		}
	}
}

fn parsed_background_repeat(value string) (string, string) {
	trimmed := value.trim_space().to_lower()
	if trimmed == 'repeat-x' {
		return 'repeat', 'no-repeat'
	}
	if trimmed == 'repeat-y' {
		return 'no-repeat', 'repeat'
	}
	tokens := trimmed.fields()
	if tokens.len == 0 {
		return 'repeat', 'repeat'
	}
	return tokens[0], if tokens.len > 1 {
		tokens[1]
	} else {
		tokens[0]
	}
}

// A word of inline content with its own measured metrics, taken from the element it comes from — so
// a nested inline element with its own font-size measures its text at that size.
struct InlineWord {
	text                 string
	width                f64 // platform-shaped advance (or an atomic box's margin-box width)
	height               f64 // this word's line-height contribution (or an atomic box's margin-box height)
	color                css.Color // this word's computed text color
	font_size            f64
	bold                 bool
	italic               bool
	mono                 bool
	decoration           string = 'none' // this word's computed text-decoration-line
	decoration_color     css.Color
	decoration_color_set bool
	decoration_skip_ink  bool = true
	decoration_style     string = 'solid'
	decoration_thickness f64
	text_run_id          i64
	shape_as_run         bool
	preserves_spaces     bool
	inline_node_id       i64
	background_color     css.Color
	border               BoxEdges
	border_color         css.Color
	border_colors        BoxColors
	border_styles        BoxBorderStyles = solid_box_border_styles()
	border_radius        f64
	border_radii         BoxRadii
	shadow               ?BoxShadow
	shadows              []BoxShadow
	// For an atomic inline (an `inline-block`), the laid-out box (at margin-box origin (0,0)); the item
	// occupies `width`×`height` on the line and is painted as its own box rather than as text.
	box ?BlockBox
	// An abspos item is retained as a zero-width line-builder item. Once trailing space and wrapping
	// have settled, its previous fragment determines the static position exactly where the C++ IFC
	// calculates it.
	positioned_node_id             i64
	positioned_fixed               bool
	positioned_block_outside       bool
	positioned_previous_sibling_id i64
mut:
	space_after     f64 // collapsed/preserved separator advance following this word
	separator_after string
}

// Gather a block's inline content as segments of styled words, split at `<br>` and (when
// `preserve_newlines`) at newlines. Each word is measured with the font/line-height of the element it
// comes from. `display: none` and out-of-flow descendants contribute nothing. The result always has
// at least one (possibly empty) segment.
struct InlineTextToken {
	text string
mut:
	separator string
}

fn non_negative(v f64) f64 {
	return if v > 0 { v } else { 0.0 }
}

// Clamp a corner radius so it never exceeds half of the smaller box dimension (a larger specified
// radius is reduced proportionally to that limit, per CSS border-radius overflow handling).
fn clamp_radius(radius f64, width f64, height f64) f64 {
	if radius <= 0 {
		return 0
	}
	limit := (if width < height { width } else { height }) / 2.0
	return if radius > limit { limit } else { radius }
}

// The rectangle (in absolute px) that an absolutely positioned element resolves its insets, size, and
// position against — the padding box of its nearest positioned ancestor, or the initial containing
// block (viewport) if none.
struct PositionedContainingBlock {
	x      f64
	y      f64
	width  f64
	height f64
}

$if test {
	fn initial_containing_block(element &dom.Element, fallback_width f64, fallback_height f64) PositionedContainingBlock {
		viewport := element.document().layout_viewport_rect()
		return PositionedContainingBlock{
			x: viewport.x
			y: viewport.y
			width: if viewport.width > 0 { viewport.width } else { fallback_width }
			height: if viewport.height > 0 { viewport.height } else { fallback_height }
		}
	}
}

fn resolved_computed_transform_matrix(computed &css.ComputedProperties, border_left f64, border_top f64, border_width f64, border_height f64) [6]f64 {
	matrix := css.resolve_computed_transform_2d_matrix(computed, border_width, border_height) or {
		return [6]f64{}
	}
	origin := computed.transform_origin()
	context := computed.length_resolution_context()
	origin_x := origin.x.to_px(context, css.CSSPixels.nearest_value_for(border_width)).to_double()
	origin_y := origin.y.to_px(context, css.CSSPixels.nearest_value_for(border_height)).to_double()
	return affine_around_origin(matrix, border_left + origin_x, border_top + origin_y)
}

fn resolved_computed_transform_4x4_matrix(computed &css.ComputedProperties, border_left f64,
	border_top f64, border_width f64, border_height f64) css.FloatMatrix4x4 {
	matrix := css.resolve_computed_transform_4x4_matrix(computed, border_width, border_height) or {
		return css.FloatMatrix4x4.identity()
	}
	origin := computed.transform_origin()
	context := computed.length_resolution_context()
	origin_x := border_left + origin.x.to_px(context, css.CSSPixels.nearest_value_for(border_width)).to_double()
	origin_y := border_top + origin.y.to_px(context, css.CSSPixels.nearest_value_for(border_height)).to_double()
	return css.translation_matrix_4x4(origin_x, origin_y, 0).multiply(matrix).multiply(css.translation_matrix_4x4(-origin_x, -origin_y, 0))
}

// Find the laid-out box for the element with `node_id` (its `unique_id`) anywhere in this subtree.
pub fn (b &BlockBox) find_box(node_id i64) ?BlockBox {
	if b.node_id == node_id {
		return *b
	}
	for child in b.children {
		if found := child.find_box(node_id) {
			return found
		}
	}
	return none
}

// The border-box rectangle of `element` within this laid-out tree — a working getBoundingClientRect
// (in document coordinates when the tree was laid out from the document root). None if not laid out.
pub fn (b &BlockBox) bounding_rect_for(element &dom.Element) ?LayoutRect {
	box := b.find_box(i64(element.as_node().unique_id())) or { return none }
	return box.border_box()
}

fn background_blend_mode_css(mode painting.BlendMode) string {
	return match mode {
		.normal { 'normal' }
		.multiply { 'multiply' }
		.screen { 'screen' }
		.overlay { 'overlay' }
		.darken { 'darken' }
		.lighten { 'lighten' }
		.color_dodge { 'color-dodge' }
		.color_burn { 'color-burn' }
		.hard_light { 'hard-light' }
		.soft_light { 'soft-light' }
		.difference { 'difference' }
		.exclusion { 'exclusion' }
		.hue { 'hue' }
		.saturation { 'saturation' }
		.color { 'color' }
		.luminosity { 'luminosity' }
		.plus_darker { 'plus-darker' }
		.plus_lighter { 'plus-lighter' }
	}
}

// Escape the five XML metacharacters so text can go inside SVG markup.
fn escape_xml(text string) string {
	return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&apos;')
}

fn retained_svg_linear_gradient_definition(id string,
	style painting.SVGLinearGradientPaintStyle) string {
	mut stops := ''
	for stop in style.gradient.color_stops {
		color := css.Color{stop.color.r, stop.color.g, stop.color.b, 255}
		stops += '<stop offset="${fmt_px(stop.position * 100.0)}%" stop-color="${color.serialize()}" stop-opacity="${fmt_px(f64(stop.color.a) / 255.0)}"/>'
	}
	transform := style.gradient.gradient_transform or { painting.Affine{} }
	spread := match style.gradient.spread_method {
		.pad { 'pad' }
		.repeat { 'repeat' }
		.reflect { 'reflect' }
	}
	color_interpolation := if style.gradient.color_space == .linear_srgb {
		'linearRGB'
	} else {
		'sRGB'
	}
	return '<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${fmt_px(style.start_point.x)}" y1="${fmt_px(style.start_point.y)}" x2="${fmt_px(style.end_point.x)}" y2="${fmt_px(style.end_point.y)}" gradientTransform="matrix(${fmt_px(transform.a)} ${fmt_px(transform.b)} ${fmt_px(transform.c)} ${fmt_px(transform.d)} ${fmt_px(transform.e)} ${fmt_px(transform.f)})" spreadMethod="${spread}" color-interpolation="${color_interpolation}">${stops}</linearGradient>'
}

fn retained_svg_radial_gradient_definition(id string,
	style painting.SVGRadialGradientPaintStyle) string {
	mut stops := ''
	for stop in style.gradient.color_stops {
		color := css.Color{stop.color.r, stop.color.g, stop.color.b, 255}
		stops += '<stop offset="${fmt_px(stop.position * 100.0)}%" stop-color="${color.serialize()}" stop-opacity="${fmt_px(f64(stop.color.a) / 255.0)}"/>'
	}
	transform := style.gradient.gradient_transform or { painting.Affine{} }
	spread := match style.gradient.spread_method {
		.pad { 'pad' }
		.repeat { 'repeat' }
		.reflect { 'reflect' }
	}
	color_interpolation := if style.gradient.color_space == .linear_srgb {
		'linearRGB'
	} else {
		'sRGB'
	}
	return '<radialGradient id="${id}" gradientUnits="userSpaceOnUse" fx="${fmt_px(style.start_center.x)}" fy="${fmt_px(style.start_center.y)}" fr="${fmt_px(style.start_radius)}" cx="${fmt_px(style.end_center.x)}" cy="${fmt_px(style.end_center.y)}" r="${fmt_px(style.end_radius)}" gradientTransform="matrix(${fmt_px(transform.a)} ${fmt_px(transform.b)} ${fmt_px(transform.c)} ${fmt_px(transform.d)} ${fmt_px(transform.e)} ${fmt_px(transform.f)})" spreadMethod="${spread}" color-interpolation="${color_interpolation}">${stops}</radialGradient>'
}

fn retained_clip_path_data(path painting.ClipPathVisualData) string {
	mut commands := []string{cap: path.segments.len}
	for segment in path.segments {
		commands << match segment.kind {
			.move_to { 'M ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)}' }
			.line_to { 'L ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)}' }
			.quadratic_bezier_curve_to {
				'Q ${fmt_px(segment.control_point_0.x)} ${fmt_px(segment.control_point_0.y)} ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)}'
			}
			.cubic_bezier_curve_to {
				'C ${fmt_px(segment.control_point_0.x)} ${fmt_px(segment.control_point_0.y)} ${fmt_px(segment.control_point_1.x)} ${fmt_px(segment.control_point_1.y)} ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)}'
			}
			.elliptical_arc_to {
				'A ${fmt_px(segment.radii.width)} ${fmt_px(segment.radii.height)} ${fmt_px(segment.rotation * 180.0 / math.pi)} ${if segment.large_arc {
					1
				} else {
					0
				}} ${if segment.sweep { 1 } else { 0 }} ${fmt_px(segment.point.x)} ${fmt_px(segment.point.y)}'
			}
			.close_path { 'Z' }
		}
	}
	return commands.join(' ')
}

fn retained_svg_pattern_definition(id string, style &painting.SVGPatternPaintStyle,
	depth int) string {
	if depth >= 16 {
		return '<pattern id="${id}" patternUnits="userSpaceOnUse"/>'
	}
	mut definitions := []string{}
	mut content := []string{}
	if display_list := style.tile_display_list {
		for operation_index, operation in display_list.operations {
			match operation.kind {
				.begin_filter {
					content << '<g>'
				}
				.begin_opacity {
					content << '<g opacity="${fmt_px(operation.opacity)}">'
				}
				.end_opacity {
					content << '</g>'
				}
				.end_filter {
					content << '</g>'
				}
				.image {
					transform := operation.transform
					content << '<image href="${escape_xml(operation.image_url)}" x="${fmt_px(operation.image_rect.x)}" y="${fmt_px(operation.image_rect.y)}" width="${fmt_px(operation.image_rect.width)}" height="${fmt_px(operation.image_rect.height)}" preserveAspectRatio="xMidYMid meet" transform="matrix(${fmt_px(transform.a)} ${fmt_px(transform.b)} ${fmt_px(transform.c)} ${fmt_px(transform.d)} ${fmt_px(transform.e)} ${fmt_px(transform.f)})"/>'
				}
				.path {
					mut fill_uses_paint_server := false
					mut stroke_uses_paint_server := false
					mut fill := if operation.has_fill {
						css.Color{operation.fill_color.r, operation.fill_color.g, operation.fill_color.b, 255}.serialize()
					} else {
						'none'
					}
					mut stroke := if operation.has_stroke {
						css.Color{operation.stroke_color.r, operation.stroke_color.g, operation.stroke_color.b, 255}.serialize()
					} else {
						'none'
					}
					if gradient := operation.fill_linear_gradient {
						fill_uses_paint_server = true
						paint_id := '${id}-paint-${operation_index}-fill'
						definitions << retained_svg_linear_gradient_definition(paint_id, gradient)
						fill = 'url(#${paint_id})'
					} else if gradient := operation.fill_radial_gradient {
						fill_uses_paint_server = true
						paint_id := '${id}-paint-${operation_index}-fill'
						definitions << retained_svg_radial_gradient_definition(paint_id, gradient)
						fill = 'url(#${paint_id})'
					} else if pattern := operation.fill_pattern {
						fill_uses_paint_server = true
						paint_id := '${id}-paint-${operation_index}-fill'
						definitions << retained_svg_pattern_definition(paint_id, pattern, depth + 1)
						fill = 'url(#${paint_id})'
					}
					if gradient := operation.stroke_linear_gradient {
						stroke_uses_paint_server = true
						paint_id := '${id}-paint-${operation_index}-stroke'
						definitions << retained_svg_linear_gradient_definition(paint_id, gradient)
						stroke = 'url(#${paint_id})'
					} else if gradient := operation.stroke_radial_gradient {
						stroke_uses_paint_server = true
						paint_id := '${id}-paint-${operation_index}-stroke'
						definitions << retained_svg_radial_gradient_definition(paint_id, gradient)
						stroke = 'url(#${paint_id})'
					} else if pattern := operation.stroke_pattern {
						stroke_uses_paint_server = true
						paint_id := '${id}-paint-${operation_index}-stroke'
						definitions << retained_svg_pattern_definition(paint_id, pattern, depth + 1)
						stroke = 'url(#${paint_id})'
					}
					transform := operation.transform
					fill_rule := if operation.path.fill_rule == .even_odd {
						'evenodd'
					} else {
						'nonzero'
					}
					linecap := match operation.stroke_linecap {
						.round { 'round' }
						.square { 'square' }
						else { 'butt' }
					}
					linejoin := match operation.stroke_linejoin {
						.round { 'round' }
						.bevel { 'bevel' }
						else { 'miter' }
					}
					paint_order := if operation.stroke_first {
						' paint-order="stroke fill"'
					} else {
						''
					}
					fill_opacity := if fill_uses_paint_server {
						operation.fill_opacity
					} else {
						operation.fill_opacity * f64(operation.fill_color.a) / 255.0
					}
					stroke_opacity := if stroke_uses_paint_server {
						operation.stroke_opacity
					} else {
						operation.stroke_opacity * f64(operation.stroke_color.a) / 255.0
					}
					content << '<path d="${retained_clip_path_data(operation.path)}" transform="matrix(${fmt_px(transform.a)} ${fmt_px(transform.b)} ${fmt_px(transform.c)} ${fmt_px(transform.d)} ${fmt_px(transform.e)} ${fmt_px(transform.f)})" fill="${fill}" fill-rule="${fill_rule}" fill-opacity="${fmt_px(fill_opacity)}" stroke="${stroke}" stroke-opacity="${fmt_px(stroke_opacity)}" stroke-width="${fmt_px(operation.stroke_width)}" stroke-linecap="${linecap}" stroke-linejoin="${linejoin}" stroke-miterlimit="${fmt_px(operation.stroke_miter_limit)}"${paint_order}/>'
				}
			}
		}
	}
	tile := style.tile_rect
	transform := style.pattern_transform or { painting.Affine{} }
	inner_definitions := if definitions.len > 0 {
		'<defs>${definitions.join('')}</defs>'
	} else {
		''
	}
	return '<pattern id="${id}" patternUnits="userSpaceOnUse" x="${fmt_px(tile.x)}" y="${fmt_px(tile.y)}" width="${fmt_px(tile.width)}" height="${fmt_px(tile.height)}" patternTransform="matrix(${fmt_px(transform.a)} ${fmt_px(transform.b)} ${fmt_px(transform.c)} ${fmt_px(transform.d)} ${fmt_px(transform.e)} ${fmt_px(transform.f)})">${inner_definitions}${content.join('')}</pattern>'
}

fn css_gradient_svg_stops(gradient LinearGradient, resolved_stops []GradientStop) []GradientStop {
	method := gradient.interpolation_method or {
		css.ColorInterpolationMethod(css.RectangularColorSpace.srgb)
	}
	if method is css.RectangularColorSpace
		&& method in [css.RectangularColorSpace.srgb, .srgb_linear] {
		return resolved_stops
	}
	if resolved_stops.len < 2 {
		return resolved_stops
	}

	// SVG only exposes sRGB and linear-sRGB interpolation. Sample the exact CSS
	// interpolation path into sRGB stops for the other Skia color spaces.
	mut sampled := []GradientStop{cap: (resolved_stops.len - 1) * 16 + 1}
	sampled << resolved_stops[0]
	for index := 1; index < resolved_stops.len; index++ {
		left := resolved_stops[index - 1]
		right := resolved_stops[index]
		span := right.offset - left.offset
		if span > 0 {
			for sample in 1 .. 16 {
				offset := left.offset + span * f64(sample) / 16.0
				sampled << GradientStop{
					color: gradient_color_at(gradient, offset)
					offset: offset
				}
			}
		}
		sampled << right
	}
	return sampled
}

fn css_gradient_svg_color_interpolation(gradient LinearGradient) string {
	method := gradient.interpolation_method or {
		css.ColorInterpolationMethod(css.RectangularColorSpace.srgb)
	}
	if method is css.RectangularColorSpace && method == css.RectangularColorSpace.srgb_linear {
		return ' color-interpolation="linearRGB"'
	}
	return ' color-interpolation="sRGB"'
}

// Render this box tree to an SVG document `width`×`height` px: each display-list command becomes a
// `<rect>` (fills, backgrounds, borders) or `<text>` (in paint order, honoring opacity). A blurred
// fill (box-shadow) gets a Gaussian-blur `<filter>`. This closes the pipeline — an HTML string laid
// out and turned into a viewable image.
//
// Text commands carry Layout's resolved font size and advance width. SVG's textLength contract keeps
// the backend's glyph shaping within that exact Layout width while the shared fallback ascent places
// the baseline consistently with the native renderer.
pub fn (b &BlockBox) render_svg(width f64, height f64) string {
	mut defs := []string{}
	mut body := []string{}
	for command in b.paint_commands() {
		if command.kind == 'begin_background_text_clip' {
			id := 'background-text-mask${defs.len}'
			mut glyphs := ''
			for run in command.text_clip_runs {
				half_leading := (run.height - run.font_size) / 2.0
				baseline := run.y + half_leading + run.font_size * 0.8
				weight := if run.bold { ' font-weight="bold"' } else { '' }
				style := if run.italic { ' font-style="italic"' } else { '' }
				family := if run.mono { ' font-family="monospace"' } else { '' }
				text_x := if run.rtl { run.x + run.width } else { run.x }
				direction := if run.rtl { ' direction="rtl" unicode-bidi="plaintext"' } else { '' }
				glyphs += '<text x="${fmt_px(text_x)}" y="${fmt_px(baseline)}" font-size="${fmt_px(run.font_size)}" textLength="${fmt_px(run.width)}" lengthAdjust="spacingAndGlyphs"${direction}${weight}${style}${family} fill="white">${escape_xml(run.text)}</text>'
			}
			defs << '<mask id="${id}" maskUnits="userSpaceOnUse" maskContentUnits="userSpaceOnUse" x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}" style="mask-type:alpha">${glyphs}</mask>'
			body << '<g mask="url(#${id})">'
			continue
		}
		if command.kind == 'end_background_text_clip' {
			body << '</g>'
			continue
		}
		if command.kind == 'begin_background_blend_group' {
			body << '<g style="isolation:isolate">'
			continue
		}
		if command.kind == 'end_background_blend_group' {
			body << '</g>'
			continue
		}
		body_start := body.len
		if command.kind == 'fill_rect' {
			corner := if command.radius > 0 {
				' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"'
			} else {
				''
			}
			mut filter := ''
			if command.blur > 0 {
				id := 'blur${defs.len}'
				// The blur can bleed past the rect, so give the filter region generous margins.
				defs << '<filter id="${id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${fmt_px(command.blur / 2.0)}"/></filter>'
				filter = ' filter="url(#${id})"'
			}
			body << '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'fill_rounded_rect' {
			path := rounded_rect_svg_path(command.x, command.y, command.width, command.height, command.corner_radii)
			body << '<path d="${path}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'paint_outer_box_shadow' {
			geometry := command.box_shadow()
			margin := command.blur * 2.0
			left := math.min(command.x, geometry.content_rect.x) - margin
			top := math.min(command.y, geometry.content_rect.y) - margin
			right := math.max(command.x + command.width, geometry.content_rect.x + geometry.content_rect.width) + margin
			bottom := math.max(command.y + command.height, geometry.content_rect.y + geometry.content_rect.height) + margin
			clip_id := 'outer-shadow-clip${defs.len}'
			outside_path := rounded_rect_svg_path(left, top, right - left, bottom - top, BoxRadii{})
			content_path := rounded_rect_svg_path(geometry.content_rect.x, geometry.content_rect.y, geometry.content_rect.width, geometry.content_rect.height, geometry.content_radii)
			defs << '<clipPath id="${clip_id}" clipPathUnits="userSpaceOnUse"><path d="${outside_path} ${content_path}" clip-rule="evenodd"/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'outer-shadow-blur${defs.len}'
				defs << '<filter id="${filter_id}" filterUnits="userSpaceOnUse" x="${fmt_px(left)}" y="${fmt_px(top)}" width="${fmt_px(right - left)}" height="${fmt_px(bottom - top)}"><feGaussianBlur stdDeviation="${fmt_px(f64(int(command.blur) / 2))}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			shadow_path := rounded_rect_svg_path(command.x, command.y, command.width, command.height, command.corner_radii)
			body << '<path d="${shadow_path}" clip-path="url(#${clip_id})"${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'paint_inner_box_shadow' {
			geometry := command.box_shadow()
			content_path := rounded_rect_svg_path(geometry.content_rect.x, geometry.content_rect.y, geometry.content_rect.width, geometry.content_rect.height, geometry.content_radii)
			clip_path := rounded_rect_svg_path(geometry.content_rect.x, geometry.content_rect.y, geometry.content_rect.width, geometry.content_rect.height, geometry.clip_radii)
			content_clip_id := 'inner-shadow-content${defs.len}'
			defs << '<clipPath id="${content_clip_id}" clipPathUnits="userSpaceOnUse"><path d="${content_path}"/></clipPath>'
			scoped_clip_id := 'inner-shadow-scoped${defs.len}'
			defs << '<clipPath id="${scoped_clip_id}" clipPathUnits="userSpaceOnUse"><path d="${clip_path}"/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'inner-shadow-blur${defs.len}'
				margin := command.blur * 2.0
				defs << '<filter id="${filter_id}" filterUnits="userSpaceOnUse" x="${fmt_px(geometry.content_rect.x - margin)}" y="${fmt_px(geometry.content_rect.y - margin)}" width="${fmt_px(geometry.content_rect.width + margin * 2.0)}" height="${fmt_px(geometry.content_rect.height + margin * 2.0)}"><feGaussianBlur stdDeviation="${fmt_px(f64(int(command.blur) / 2))}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			outer_path := rounded_rect_svg_path(command.x, command.y, command.width, command.height, command.corner_radii)
			inner_path := if geometry.inner_rect.width > 0 && geometry.inner_rect.height > 0 {
				rounded_rect_svg_path(geometry.inner_rect.x, geometry.inner_rect.y, geometry.inner_rect.width, geometry.inner_rect.height, geometry.inner_radii)
			} else {
				''
			}
			body << '<g clip-path="url(#${scoped_clip_id})"><g clip-path="url(#${content_clip_id})"><path d="${outer_path} ${inner_path}" fill-rule="evenodd"${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/></g></g>'
		} else if command.kind == 'fill_inset_shadow' {
			clip_id := 'inset-clip${defs.len}'
			corner := if command.radius > 0 {
				' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"'
			} else {
				''
			}
			defs << '<clipPath id="${clip_id}"><rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'inset-blur${defs.len}'
				defs << '<filter id="${filter_id}" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="${fmt_px(command.blur / 2.0)}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			base := command.blur + command.shadow_spread
			left := non_negative(base - command.shadow_offset_x)
			right := non_negative(base + command.shadow_offset_x)
			top := non_negative(base - command.shadow_offset_y)
			bottom := non_negative(base + command.shadow_offset_y)
			mut pieces := ''
			if left > 0 {
				pieces += '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(left)}" height="${fmt_px(command.height)}"/>'
			}
			if right > 0 {
				pieces += '<rect x="${fmt_px(command.x + command.width - right)}" y="${fmt_px(command.y)}" width="${fmt_px(right)}" height="${fmt_px(command.height)}"/>'
			}
			if top > 0 {
				pieces += '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(top)}"/>'
			}
			if bottom > 0 {
				pieces += '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y + command.height - bottom)}" width="${fmt_px(command.width)}" height="${fmt_px(bottom)}"/>'
			}
			body << '<g clip-path="url(#${clip_id})"${filter} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}">${pieces}</g>'
		} else if rounded_single_border_mode(command.kind) > 0 {
			for fallback in rounded_single_border_fallback(command) {
				if fallback.svg_data != unsafe { nil } {
					path := fallback.svg_data
					body << '<path d="${path.path}" fill="${fallback.color}" fill-opacity="${fmt_px(fallback.opacity)}"/>'
				}
			}
		} else if command.kind == 'paint_uniform_border' {
			path := rounded_rect_svg_path(command.x, command.y, command.width, command.height, command.corner_radii)
			body << '<path d="${path}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
		} else if command.kind == 'stroke_rounded_rect' {
			if command.points.len > 0 {
				mut points := []string{}
				for index := 0; index + 1 < command.points.len; index += 2 {
					points << '${fmt_px(command.points[index])},${fmt_px(command.points[index + 1])}'
				}
				body << '<polygon points="${points.join(' ')}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
			} else {
				half_stroke := command.stroke_width / 2.0
				body << '<rect x="${fmt_px(command.x + half_stroke)}" y="${fmt_px(command.y + half_stroke)}" width="${fmt_px(non_negative(command.width - command.stroke_width))}" height="${fmt_px(non_negative(command.height - command.stroke_width))}" rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
			}
		} else if command.kind == 'fill_ellipse' {
			body << '<ellipse cx="${fmt_px(command.x + command.width / 2)}" cy="${fmt_px(command.y + command.height / 2)}" rx="${fmt_px(command.width / 2)}" ry="${fmt_px(command.height / 2)}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'stroke_ellipse' {
			body << '<ellipse cx="${fmt_px(command.x + command.width / 2)}" cy="${fmt_px(command.y + command.height / 2)}" rx="${fmt_px(command.width / 2)}" ry="${fmt_px(command.height / 2)}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"/>'
		} else if command.kind == 'fill_polygon' {
			mut points := []string{}
			for index := 0; index + 1 < command.points.len; index += 2 {
				points << '${fmt_px(command.points[index])},${fmt_px(command.points[index + 1])}'
			}
			body << '<polygon points="${points.join(' ')}" fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}"/>'
		} else if command.kind == 'draw_line' {
			linecap := if command.line_style == 'dotted' { ' stroke-linecap="round"' } else { '' }
			dasharray := match command.line_style {
				'dashed' {
					' stroke-dasharray="${fmt_px(command.stroke_width * 3)} ${fmt_px(command.stroke_width * 3)}"'
				}
				'dotted' { ' stroke-dasharray="0 ${fmt_px(command.stroke_width * 2)}"' }
				else { '' }
			}
			body << '<line x1="${fmt_px(command.x)}" y1="${fmt_px(command.y)}" x2="${fmt_px(command.x + command.width)}" y2="${fmt_px(command.y + command.height)}" fill="none" stroke="${command.color}" stroke-opacity="${fmt_px(command.opacity)}" stroke-width="${fmt_px(command.stroke_width)}"${linecap}${dasharray}/>'
		} else if command.kind == 'fill_gradient' {
			image_data := command.image()
			if grad := command.gradient {
				tiles := resolved_background_gradient_tiles(command)
				mut stops := ''
				resolved_stops := if grad.stops.len > 0 {
					grad.stops
				} else {
					mut fallback := []GradientStop{}
					for index, color in grad.colors {
						fallback << GradientStop{
							color: color
							offset: if grad.colors.len > 1 {
								f64(index) / f64(grad.colors.len - 1)
							} else {
								0.0
							}
						}
					}
					fallback
				}
				for stop in css_gradient_svg_stops(grad, resolved_stops) {
					stops += '<stop offset="${fmt_px(stop.offset * 100.0)}%" stop-color="${stop.color.serialize()}" stop-opacity="${fmt_px(f64(stop.color.a) / 255.0)}"/>'
				}
				color_interpolation := css_gradient_svg_color_interpolation(grad)
				corner := if command.radius > 0 && !command.gradient_background_layer {
					' rx="${fmt_px(command.radius)}" ry="${fmt_px(command.radius)}"'
				} else {
					''
				}
				mut rounded_polygon_points := []string{}
				for index := 0; index + 1 < command.points.len; index += 2 {
					rounded_polygon_points << '${fmt_px(command.points[index])},${fmt_px(command.points[index + 1])}'
				}
				clip_shape := if command.gradient_background_layer
					&& !box_radii_are_zero(image_data.image_clip_radii) {
					'<path d="${rounded_rect_svg_path(image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height, image_data.image_clip_radii)}"/>'
				} else if command.gradient_background_layer {
					'<rect x="${fmt_px(image_data.image_clip_x)}" y="${fmt_px(image_data.image_clip_y)}" width="${fmt_px(image_data.image_clip_width)}" height="${fmt_px(image_data.image_clip_height)}"/>'
				} else if rounded_polygon_points.len > 0 {
					'<polygon points="${rounded_polygon_points.join(' ')}"/>'
				} else {
					'<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}/>'
				}
				blend := if image_data.background_blend_mode == .normal {
					''
				} else {
					' style="mix-blend-mode:${background_blend_mode_css(image_data.background_blend_mode)}"'
				}
				if grad.kind == 'conic' {
					clip_id := 'gradient-clip${defs.len}'
					defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
					mut wedges := ''
					for tile in tiles {
						center_x := tile.x + tile.width * grad.center_x
						center_y := tile.y + tile.height * grad.center_y
						radius := math.sqrt(tile.width * tile.width + tile.height * tile.height)
						steps := 128
						for step in 0 .. steps {
							start_fraction := f64(step) / f64(steps)
							end_fraction := f64(step + 1) / f64(steps)
							start_angle := (grad.start_degrees + start_fraction * 360.0 - 90.0) * math.pi / 180.0
							end_angle := (grad.start_degrees + end_fraction * 360.0 - 90.0) * math.pi / 180.0
							start_x := center_x + math.cos(start_angle) * radius
							start_y := center_y + math.sin(start_angle) * radius
							end_x := center_x + math.cos(end_angle) * radius
							end_y := center_y + math.sin(end_angle) * radius
							color := gradient_color_at(grad, (start_fraction + end_fraction) / 2.0)
							wedges += '<polygon points="${fmt_px(center_x)},${fmt_px(center_y)} ${fmt_px(start_x)},${fmt_px(start_y)} ${fmt_px(end_x)},${fmt_px(end_y)}" fill="${color.serialize()}" fill-opacity="${fmt_px(command.opacity * f64(color.a) / 255.0)}"/>'
						}
					}
					body << '<g clip-path="url(#${clip_id})"${blend}>${wedges}</g>'
				} else {
					id := 'grad${defs.len}'
					if grad.kind == 'radial' || grad.radial {
						transform := if grad.radius_x != grad.radius_y && grad.radius_x > 0 {
							' gradientTransform="translate(${fmt_px(grad.center_x)} ${fmt_px(grad.center_y)}) scale(1 ${fmt_px(grad.radius_y / grad.radius_x)}) translate(${fmt_px(-grad.center_x)} ${fmt_px(-grad.center_y)})"'
						} else {
							''
						}
						defs << '<radialGradient id="${id}" cx="${fmt_px(grad.center_x * 100.0)}%" cy="${fmt_px(grad.center_y * 100.0)}%" r="${fmt_px(grad.radius_x * 100.0)}%"${transform}${color_interpolation}>${stops}</radialGradient>'
					} else {
						defs << '<linearGradient id="${id}" x1="${fmt_px(grad.x1 * 100.0)}%" y1="${fmt_px(grad.y1 * 100.0)}%" x2="${fmt_px(grad.x2 * 100.0)}%" y2="${fmt_px(grad.y2 * 100.0)}%"${color_interpolation}>${stops}</linearGradient>'
					}
					if command.gradient_background_layer {
						clip_id := 'gradient-clip${defs.len}'
						defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
						mut tile_rects := ''
						for tile in tiles {
							tile_rects += '<rect x="${fmt_px(tile.x)}" y="${fmt_px(tile.y)}" width="${fmt_px(tile.width)}" height="${fmt_px(tile.height)}" fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
						}
						body << '<g clip-path="url(#${clip_id})"${blend}>${tile_rects}</g>'
					} else if rounded_polygon_points.len > 0 {
						body << '<polygon points="${rounded_polygon_points.join(' ')}" fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
					} else {
						body << '<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner} fill="url(#${id})" fill-opacity="${fmt_px(command.opacity)}"/>'
					}
				}
			}
		} else if command.kind in ['draw_background_image', 'draw_replaced_image'] {
			image_data := command.image()
			clip_id := 'imageclip${defs.len}'
			clip_shape := if !box_radii_are_zero(image_data.image_clip_radii) {
				'<path d="${rounded_rect_svg_path(image_data.image_clip_x, image_data.image_clip_y, image_data.image_clip_width, image_data.image_clip_height, image_data.image_clip_radii)}"/>'
			} else {
				'<rect x="${fmt_px(image_data.image_clip_x)}" y="${fmt_px(image_data.image_clip_y)}" width="${fmt_px(image_data.image_clip_width)}" height="${fmt_px(image_data.image_clip_height)}"/>'
			}
			defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
			aspect := if image_data.image_size.trim_space().to_lower() == 'cover' {
				'xMidYMid slice'
			} else if image_data.image_size.trim_space().to_lower() == 'contain' {
				'xMidYMid meet'
			} else {
				'xMinYMin meet'
			}
			blend := if image_data.background_blend_mode == .normal {
				''
			} else {
				' style="mix-blend-mode:${background_blend_mode_css(image_data.background_blend_mode)}"'
			}
			body << '<image href="${escape_xml(image_data.image_url)}" x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}" preserveAspectRatio="${aspect}" clip-path="url(#${clip_id})" opacity="${fmt_px(command.opacity)}"${blend} data-background-repeat="${escape_xml(image_data.image_repeat_x)} ${escape_xml(image_data.image_repeat_y)}" data-background-position="${escape_xml(image_data.image_position_x)} ${escape_xml(image_data.image_position_y)}"/>'
		} else if command.kind == 'draw_text' {
			half_leading := (command.height - command.font_size) / 2.0
			baseline := command.y + half_leading + command.font_size * 0.8
			weight := if command.bold { ' font-weight="bold"' } else { '' }
			style := if command.italic { ' font-style="italic"' } else { '' }
			family := if command.mono { ' font-family="monospace"' } else { '' }
			text_x := if command.rtl { command.x + command.width } else { command.x }
			direction := if command.rtl { ' direction="rtl" unicode-bidi="plaintext"' } else { '' }
			body << '<text x="${fmt_px(text_x)}" y="${fmt_px(baseline)}" font-size="${fmt_px(command.font_size)}" textLength="${fmt_px(command.width)}" lengthAdjust="spacingAndGlyphs"${direction}${weight}${style}${family} fill="${command.color}" fill-opacity="${fmt_px(command.opacity)}">${escape_xml(command.text)}</text>'
		} else if command.kind == 'draw_svg_path' {
			svg_data := command.svg()
			path_matrix := normalized_affine(svg_data.path_transform)
			mut fill := if command.color.len > 0 { command.color } else { 'none' }
			mut stroke := if command.stroke_color.len > 0 { command.stroke_color } else { 'none' }
			if gradient := command.fill_linear_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_linear_gradient_definition(id, gradient)
				fill = 'url(#${id})'
			} else if gradient := command.fill_radial_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_radial_gradient_definition(id, gradient)
				fill = 'url(#${id})'
			} else if pattern := svg_data.fill_pattern {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_pattern_definition(id, pattern, 0)
				fill = 'url(#${id})'
			}
			if gradient := command.stroke_linear_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_linear_gradient_definition(id, gradient)
				stroke = 'url(#${id})'
			} else if gradient := command.stroke_radial_gradient() {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_radial_gradient_definition(id, gradient)
				stroke = 'url(#${id})'
			} else if pattern := svg_data.stroke_pattern {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_pattern_definition(id, pattern, 0)
				stroke = 'url(#${id})'
			}
			fill_rule := if svg_data.fill_even_odd { 'evenodd' } else { 'nonzero' }
			paint_order := if svg_data.stroke_first { ' paint-order="stroke fill"' } else { '' }
			linecap := match svg_data.stroke_linecap {
				1 { 'round' }
				2 { 'square' }
				else { 'butt' }
			}
			linejoin := match svg_data.stroke_linejoin {
				1 { 'round' }
				2 { 'bevel' }
				else { 'miter' }
			}
			vector_effect := if svg_data.non_scaling_stroke {
				' vector-effect="non-scaling-stroke"'
			} else {
				''
			}
			dasharray := if svg_data.stroke_dasharray.len > 0 {
				' stroke-dasharray="${svg_data.stroke_dasharray.map(fmt_px(it)).join(' ')}" stroke-dashoffset="${fmt_px(svg_data.stroke_dashoffset)}"'
			} else {
				''
			}
			body << '<path d="${escape_xml(svg_data.path)}" transform="matrix(${fmt_px(path_matrix[0])} ${fmt_px(path_matrix[1])} ${fmt_px(path_matrix[2])} ${fmt_px(path_matrix[3])} ${fmt_px(path_matrix[4])} ${fmt_px(path_matrix[5])})" fill="${fill}" fill-rule="${fill_rule}" fill-opacity="${fmt_px(command.opacity * svg_data.fill_opacity)}" stroke="${stroke}" stroke-opacity="${fmt_px(command.opacity * svg_data.stroke_opacity)}" stroke-width="${fmt_px(command.stroke_width)}" stroke-linecap="${linecap}" stroke-linejoin="${linejoin}" stroke-miterlimit="${fmt_px(svg_data.stroke_miterlimit)}"${dasharray}${paint_order}${vector_effect}/>'
		}
		if body.len > body_start && !affine_is_identity(command.transform) {
			matrix := normalized_affine(command.transform)
			transformed_body := body[body_start..].join('')
			body = body[..body_start].clone()
			body << '<g transform="matrix(${fmt_px(matrix[0])} ${fmt_px(matrix[1])} ${fmt_px(matrix[2])} ${fmt_px(matrix[3])} ${fmt_px(matrix[4])} ${fmt_px(matrix[5])})">${transformed_body}</g>'
		}
	}
	mut parts := [
		'<svg xmlns="http://www.w3.org/2000/svg" width="${fmt_px(width)}" height="${fmt_px(height)}">',
	]
	if defs.len > 0 {
		parts << '<defs>${defs.join('')}</defs>'
	}
	parts << body
	parts << '</svg>'
	return parts.join('\n')
}

fn affine_is_identity(matrix [6]f64) bool {
	return normalized_affine(matrix) == affine_identity()
}

// A readable indented dump of the box tree — `tag (x,y) WxH` per box, children nested — for
// snapshot tests and debugging. Whole numbers print without a trailing `.0`.
pub fn (b &BlockBox) tree_repr() string {
	mut lines := []string{}
	b.append_repr(0, mut lines)
	return lines.join('\n')
}

fn (b &BlockBox) append_repr(depth int, mut lines []string) {
	indent := '  '.repeat(depth)
	lines << '${indent}${b.tag_name} (${fmt_px(b.x)},${fmt_px(b.y)}) ${fmt_px(b.width)}x${fmt_px(b.height)}'
	for child in b.children {
		child.append_repr(depth + 1, mut lines)
	}
}

fn rounded_rect_svg_path(x f64, y f64, width f64, height f64, input_radii BoxRadii) string {
	radii := normalize_box_radii(input_radii, width, height)
	mut path := 'M ${fmt_px(x + radii.top_left.x)} ${fmt_px(y)}'
	path += ' L ${fmt_px(x + width - radii.top_right.x)} ${fmt_px(y)}'
	if radii.top_right.x > 0 && radii.top_right.y > 0 {
		path += ' A ${fmt_px(radii.top_right.x)} ${fmt_px(radii.top_right.y)} 0 0 1 ${fmt_px(x + width)} ${fmt_px(y + radii.top_right.y)}'
	} else {
		path += ' L ${fmt_px(x + width)} ${fmt_px(y)}'
	}
	path += ' L ${fmt_px(x + width)} ${fmt_px(y + height - radii.bottom_right.y)}'
	if radii.bottom_right.x > 0 && radii.bottom_right.y > 0 {
		path += ' A ${fmt_px(radii.bottom_right.x)} ${fmt_px(radii.bottom_right.y)} 0 0 1 ${fmt_px(x + width - radii.bottom_right.x)} ${fmt_px(y + height)}'
	} else {
		path += ' L ${fmt_px(x + width)} ${fmt_px(y + height)}'
	}
	path += ' L ${fmt_px(x + radii.bottom_left.x)} ${fmt_px(y + height)}'
	if radii.bottom_left.x > 0 && radii.bottom_left.y > 0 {
		path += ' A ${fmt_px(radii.bottom_left.x)} ${fmt_px(radii.bottom_left.y)} 0 0 1 ${fmt_px(x)} ${fmt_px(y + height - radii.bottom_left.y)}'
	} else {
		path += ' L ${fmt_px(x)} ${fmt_px(y + height)}'
	}
	path += ' L ${fmt_px(x)} ${fmt_px(y + radii.top_left.y)}'
	if radii.top_left.x > 0 && radii.top_left.y > 0 {
		path += ' A ${fmt_px(radii.top_left.x)} ${fmt_px(radii.top_left.y)} 0 0 1 ${fmt_px(x + radii.top_left.x)} ${fmt_px(y)}'
	} else {
		path += ' L ${fmt_px(x)} ${fmt_px(y)}'
	}
	return path + ' Z'
}
