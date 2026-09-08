module layout

import css
import dom
import encoding.utf8
import html
import math
import painting
import platform
import strings

// A minimal block formatting context: it consumes the css computed-value layer (computed lengths,
// percentages) to produce real box geometry, including the box model — margins, padding, and
// borders. Block boxes stack vertically; each is sized within its containing block's content width;
// a box with `height: auto` takes the height of its stacked children. This is the first layout code
// that actually runs on the cascade output — and where percentage widths (which computed_length_px
// can't resolve without a containing block) get resolved.
//
// Adjoining vertical margins collapse (CSS 2.1 §8.3.1): between in-flow siblings, and between a box
// and its first/last child when no border/padding separates them (parent/child collapsing, via each
// box's propagated outer margins) — unless the box establishes a block formatting context
// (`overflow` != visible / `display: flow-root`), which contains its children's margins. A box with
// no block-level children but with text content gets a
// height from a coarse inline pass (line count × line-height). `box-sizing: border-box` makes a
// specified width/height include padding+border. Used width and height are clamped by min/max-width
// and min/max-height; `width` also accepts min-content/max-content/fit-content and abspos boxes
// shrink-to-fit. Horizontal `auto` margins absorb leftover space (both auto centers the box; a
// single one right/left-aligns). `position: relative` offsets a box (and its subtree) by its insets
// without disturbing the flow (as does `transform: translate(...)`). Text-bearing blocks produce inline line boxes (word-wrapped, `<br>`-
// and `white-space`-aware) positioned per `text-align`. Floated children are placed at the content
// edges (out of flow); `clear` moves a block below them, a BFC grows to contain them, and inline
// content wraps around them. `BlockBox.paint_order()` flattens the tree into z-index paint order, and
// `paint_commands()` builds a display list (background fills + text draws) from it.
// The compatibility transport below still has explicit parity notes at the individual reduced
// algorithms; this summary intentionally describes only behavior implemented here.

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
	text      string
	color     css.Color
	font_size f64 = 16.0
	bold      bool
	italic    bool
	mono      bool
	// Words from the same DOM text node can be shaped and painted as one run when CSS uses natural
	// letter/word spacing. This lets the renderer use the font's real glyph advances instead of
	// exposing this minimal layout engine's half-em width estimates between every word.
	text_run_id           i64
	shape_as_run          bool
	separator_after       string
	separator_width_after f64
	preserves_spaces      bool
	rtl                   bool
	// Paint style of the inline element that generated this word. Words with the same non-zero node
	// id are joined into one inline box on each line before their text is painted.
	inline_node_id    i64
	background_color  css.Color
	background_images []BackgroundImageLayer
	border            BoxEdges
	border_color      css.Color
	border_colors     BoxColors
	border_styles     BoxBorderStyles = solid_box_border_styles()
	border_radius     f64
	border_radii      BoxRadii
	shadow            ?BoxShadow
	shadows           []BoxShadow
	// The resolved text-decoration covering this word.
	decoration           string = 'none'
	decoration_color     css.Color
	decoration_color_set bool
	decoration_style     string = 'solid'
	decoration_thickness f64
	// PaintableFragment retains the line builder's baseline rather than
	// reconstructing it from an assumed 0.8em ascent at paint time.
	baseline                 f64
	baseline_set             bool
	font_metrics_set         bool
	font_ascent              f64
	font_descent             f64
	font_x_height            f64
	glyph_height             f64
	decoration_thickness_set bool
	text_underline_offset    f64
	text_underline_position  string = 'auto'
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
}

fn translated_paintable_fragment(fragment painting.PaintableFragment, dx f64,
	dy f64) painting.PaintableFragment {
	mut translated := fragment
	translated.offset = translated.offset.add(painting.Point{dx, dy})
	return translated
}

// Return a copy of `line` (and its fragments) shifted by (`dx`, `dy`).
fn translate_line(line TextLine, dx f64, dy f64) TextLine {
	return TextLine{
		x: line.x + dx
		y: line.y + dy
		width: line.width
		height: line.height
		fragments: line.fragments.map(TextFragment{
			x: it.x + dx
			y: it.y + dy
			width: it.width
			height: it.height
			text: it.text
			color: it.color
			font_size: it.font_size
			bold: it.bold
			italic: it.italic
			mono: it.mono
			text_run_id: it.text_run_id
			shape_as_run: it.shape_as_run
			separator_after: it.separator_after
			separator_width_after: it.separator_width_after
			preserves_spaces: it.preserves_spaces
			rtl: it.rtl
			inline_node_id: it.inline_node_id
			background_color: it.background_color
			background_images: it.background_images.clone()
			border: it.border
			border_color: it.border_color
			border_colors: it.border_colors
			border_styles: it.border_styles
			border_radius: it.border_radius
			border_radii: it.border_radii
			shadow: it.shadow
			shadows: it.shadows.clone()
			decoration: it.decoration
			decoration_color: it.decoration_color
			decoration_color_set: it.decoration_color_set
			decoration_style: it.decoration_style
			decoration_thickness: it.decoration_thickness
			baseline: it.baseline
			baseline_set: it.baseline_set
			font_metrics_set: it.font_metrics_set
			font_ascent: it.font_ascent
			font_descent: it.font_descent
			font_x_height: it.font_x_height
			glyph_height: it.glyph_height
			decoration_thickness_set: it.decoration_thickness_set
			text_underline_offset: it.text_underline_offset
			text_underline_position: it.text_underline_position
			layout_handle: it.layout_handle
			paintable_fragment: translated_paintable_fragment(it.paintable_fragment, dx, dy)
			text_shadows: it.text_shadows.clone()
			selection_style: it.selection_style
		})
	}
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

// StaticPositionRect::aligned_position_for_box_with_size(). Alignment is intentionally resolved
// after the abspos box's margins and dimensions are final.
fn (position StaticPosition) aligned_for_margin_box(width f64, height f64) StaticPosition {
	return StaticPosition{
		x: position.x + match position.horizontal_alignment {
			.center { (position.width - width) / 2.0 }
			.end { position.width - width }
			.start { 0.0 }
		}
		y: position.y + match position.vertical_alignment {
			.center { (position.height - height) / 2.0 }
			.end { position.height - height }
			.start { 0.0 }
		}
	}
}

pub struct BlockBox {
pub:
	tag_name string
pub mut:
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
	stacking_context      bool
	paintable_with_lines  bool
	// Retained table paint metadata from PaintableBox. Collapsed cells do not
	// paint ordinary borders; their winning edges are emitted by the table in
	// the dedicated TableCollapsedBorder phase.
	table_inside           bool
	table_cell             bool
	uses_collapsed_borders bool
	table_cell_coordinates ?painting.TableCellCoordinates
	table_cell_borders     ?painting.BordersDataWithElementKind
	empty_cells_hide       bool
	has_layout_children    bool
	// The computed background-color, text color, and border color, used to build the display list.
	background_color css.Color
	text_color       css.Color
	border_color     css.Color
	border_colors    BoxColors
	border_styles    BoxBorderStyles = solid_box_border_styles()
	// The uniform border-radius (px) applied when filling the background/border box.
	border_radius f64
	border_radii  BoxRadii
	// The outline (painted outside the border box, not affecting layout): its width (0 = none), the
	// gap between the border edge and the outline (`outline-offset`, may be negative), and its color.
	outline_width  f64
	outline_offset f64
	outline_color  css.Color
	outline_style  painting.LineStyle = .solid
	// Drop shadows behind the box. `shadow` retains the first entry for compatibility; `shadows`
	// carries the complete comma-separated outer-shadow list.
	shadow  ?BoxShadow
	shadows []BoxShadow
	// A `linear-gradient` background image, painted over the background color, or none.
	background_gradient   ?LinearGradient
	background_images     []BackgroundImageLayer
	background_color_clip string = 'border-box'
	// Replaced image content paints over CSS backgrounds and below borders.
	replaced_image_url        string
	replaced_image_size       string
	replaced_image_position_x string
	replaced_image_position_y string
	replaced_image_rendering  css.ImageRendering
	replaced_image_paintable  ?painting.ImagePaintable
	canvas_bitmap             ?&dom.ImmutableBitmap_
	canvas_paintable          ?painting.CanvasPaintable
	video_bitmap              ?&dom.ImmutableBitmap_
	video_external_source     ?&html.MediaExternalContentSource
	video_representation      painting.VideoRepresentation
	video_paintable           ?painting.VideoPaintable
	nested_viewport_document  ?&dom.Document
	nested_viewport_paintable ?painting.NavigableContainerViewportPaintable
	// Retained for detached compatibility commands; typed HTML/SVG images carry
	// their source semantics in replaced_image_paintable.
	is_svg_image               bool
	form_control_kind          string
	form_control_checked       bool
	form_control_indeterminate bool
	form_control_enabled       bool = true
	form_control_activated     bool
	form_control_color_scheme  css.PreferredColorScheme
	form_control_accent_color  ?css.Color
	fieldset_paintable         ?painting.FieldSetPaintable
	// Root backgrounds cover the viewport canvas. A transparent HTML root may receive these values
	// from the body background according to CSS canvas-background propagation.
	canvas_background_color  css.Color
	canvas_x                 f64
	canvas_y                 f64
	canvas_width             f64
	canvas_height            f64
	paints_canvas_background bool
	skip_background_paint    bool
	// `opacity` is this box's own opacity (0..1) in the tree; in a paint-order entry it holds the
	// cumulative opacity (this box's times its ancestors').
	opacity f64 = 1.0
	// Painting::ResolvedCSSFilter retained from computed style. The visual-context
	// builder converts this to a device filter before display-list replay.
	filter          painting.ResolvedCSSFilter
	backdrop_filter painting.ResolvedCSSFilter
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
	// SVGPathPaintable transport. The path remains in SVG user coordinates;
	// transform maps it into document CSS pixels. points is the flattened
	// endpoint representation used by the native shell's immediate renderer.
	has_svg_path               bool
	svg_path                   string
	svg_path_data              []f32
	svg_path_bounding_box      painting.Rect
	svg_transform              [6]f64
	svg_points                 []f64
	svg_fill_color             string
	svg_fill_linear_gradient   ?painting.SVGLinearGradientPaintStyle
	svg_fill_radial_gradient   ?painting.SVGRadialGradientPaintStyle
	svg_fill_pattern           ?&painting.SVGPatternPaintStyle
	svg_fill_even_odd          bool
	svg_stroke_color           string
	svg_stroke_linear_gradient ?painting.SVGLinearGradientPaintStyle
	svg_stroke_radial_gradient ?painting.SVGRadialGradientPaintStyle
	svg_stroke_pattern         ?&painting.SVGPatternPaintStyle
	svg_stroke_width           f64
	svg_stroke_first           bool
	svg_stroke_linecap         int
	svg_stroke_linejoin        int
	svg_stroke_miterlimit      f64 = 4.0
	svg_fill_opacity           f64 = 1.0
	svg_stroke_opacity         f64 = 1.0
	// MarkerPaintable transport for the predefined counter styles which
	// LibWeb intentionally renders as a geometric image instead of text.
	marker_shape string
	// Scrollbars and the CSS resize handle paint after the outline in the
	// overlay phase. None means this box has neither kind of overlay.
	overlay ?CompatibilityOverlayData
	// A scroll frame exists only when layout measured overflow beyond the
	// scrollport, except that the root transport box also carries the viewport's
	// mandatory scroll frame. Clipping also exists for overflow:clip without a
	// scroll frame.
	has_scrollable_overflow bool
	scrollable_overflow     ?LayoutRect
	overflow_clip           ?CompatibilityOverflowClip
	// CSS2 `clip: rect(...)`, resolved from an absolute/fixed box's border box.
	// Unlike overflow clipping, this belongs to the box's own visual context and
	// therefore clips both the box and its descendants.
	css_clip ?LayoutRect
	// CSS basic-shape clip-path geometry is retained in absolute document
	// coordinates, matching Painting::ClipPathData.
	clip_path            ?painting.ClipPathVisualData
	svg_clip             ?painting.SVGClipVisualData
	svg_mask             ?painting.SVGMaskVisualData
	sticky_position      bool
	is_viewport_scroller bool
	viewport_width       f64
	viewport_height      f64
	// The element-local transform is retained separately so the accumulated
	// visual-context tree can interleave transforms, clips, and scroll frames in
	// source order. `paint_transform` remains the old cumulative compatibility
	// value for callers which construct BlockBox trees directly.
	own_paint_transform [6]f64
	// Cumulative CSS 2D transform in document coordinates. An all-zero value is the compact identity
	// representation used by boxes which do not establish a transformed paint subtree.
	paint_transform [6]f64
mut:
	// Out-of-flow descendants retain the position they would have occupied in this formatting
	// context until their actual containing block lays them out. Absolute positions stop at the
	// nearest positioned ancestor; fixed positions travel to the initial containing block.
	absolute_static_positions                      map[i64]StaticPosition
	fixed_static_positions                         map[i64]StaticPosition
	own_scroll_frame_index                         int
	sticky_scroll_frame_index                      int
	accumulated_visual_context_index               int
	accumulated_visual_context_for_descendants_idx int
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

// The CSSOM *resolved* value of `property_name` for `element` (analogous to
// `getComputedStyle(element).getPropertyValue(name)`), backed by this laid-out box tree. The
// layout-dependent box metrics — width/height (used content-box size) and the used padding/margin/
// border widths — return their USED px from the box; every other property falls back to the
// layout-free computed value (`css.computed_style_value`). This closes the earlier getComputedStyle gap
// where a percentage/`auto` width would otherwise return its specified value.
pub fn (b &BlockBox) resolved_style_value(element &dom.Element, property_name string, author_rules []&css.CSSRule) string {
	if box := b.find_box(i64(element.as_node().unique_id())) {
		used := match property_name {
			'width' { box.width }
			'height' { box.height }
			'padding-top' { box.padding.top }
			'padding-right' { box.padding.right }
			'padding-bottom' { box.padding.bottom }
			'padding-left' { box.padding.left }
			'margin-top' { box.margin.top }
			'margin-right' { box.margin.right }
			'margin-bottom' { box.margin.bottom }
			'margin-left' { box.margin.left }
			'border-top-width' { box.border.top }
			'border-right-width' { box.border.right }
			'border-bottom-width' { box.border.bottom }
			'border-left-width' { box.border.left }
			else {
				return css.computed_style_value(element, property_name, author_rules)
			}
		}
		return '${fmt_px(used)}px'
	}
	return css.computed_style_value(element, property_name, author_rules)
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
		top_left: painting.BorderRadiusData{b.border_radii.top_left.x, b.border_radii.top_left.y}
		top_right: painting.BorderRadiusData{b.border_radii.top_right.x, b.border_radii.top_right.y}
		bottom_right: painting.BorderRadiusData{b.border_radii.bottom_right.x, b.border_radii.bottom_right.y}
		bottom_left: painting.BorderRadiusData{b.border_radii.bottom_left.x, b.border_radii.bottom_left.y}
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
	if !b.has_svg_path {
		return true
	}
	matrix := normalized_affine(b.svg_transform)
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
	return b.svg_path_bounding_box.contains(local_point)
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

// Return every painted element under the point, front-to-back. This is the
// paint-order counterpart of Painting::ViewportPaintable::hit_test_all and is
// consumed by Document::elementsFromPoint().
pub fn (b &BlockBox) elements_at_point(x f64, y f64, _root &dom.Node) []&dom.Element {
	order := b.paint_order_box_references()
	mut elements := []&dom.Element{}
	for i := order.len - 1; i >= 0; i-- {
		box := order[i]
		node_id := box.node_id_for_hit_test()
		if node_id == 0 || !box.visible || !box.pointer_events_enabled
			|| !box.contains_hit_test_point(x, y) {
			continue
		}
		if element := element_for_paint_node_id(node_id) {
			elements << element
		}
	}
	return elements
}

// The border-box width/height of `element` (its `offsetWidth`/`offsetHeight`), or none if not laid out.
pub fn (b &BlockBox) offset_width_for(element &dom.Element) ?f64 {
	if element.as_node().layout_node() == none {
		return (b.bounding_rect_for(element) or { return none }).width
	}
	if !element.is_html_element() {
		return none
	}
	install_document_layout_hook(element.document())
	return f64(html.html_element_offset_width(unsafe { &dom.HTMLElement(element) }))
}

pub fn (b &BlockBox) offset_height_for(element &dom.Element) ?f64 {
	if element.as_node().layout_node() == none {
		return (b.bounding_rect_for(element) or { return none }).height
	}
	if !element.is_html_element() {
		return none
	}
	install_document_layout_hook(element.document())
	return f64(html.html_element_offset_height(unsafe { &dom.HTMLElement(element) }))
}

// Compatibility entry point for HTMLElement::offset_parent(). Keep this API on
// the translated CSSOM View algorithm and retained layout tree rather than
// maintaining a second ancestor walk over serialized style values.
pub fn offset_parent_element(element &dom.Element, author_rules []&css.CSSRule) ?&dom.Element {
	if !element.is_html_element() {
		return none
	}
	if element.as_node().layout_node() == none {
		mut current := element.as_node().parent_element() or { return none }
		for {
			local := current.local_name()
			if is_positioned(position_value(current, author_rules)) || local == 'body' || (position_value(element, author_rules) == 'static' && local in [
				'td',
				'th',
				'table',
			]) {
				return current
			}
			current = current.as_node().parent_element() or { return none }
		}
		return none
	}
	install_document_layout_hook(element.document())
	return html.html_element_offset_parent(unsafe { &dom.HTMLElement(element) })
}

// `element`'s offsetTop: its border-box top relative to its offsetParent's padding-box top (or the
// document top when there is no offsetParent).
pub fn (b &BlockBox) offset_top_for(element &dom.Element, author_rules []&css.CSSRule) ?f64 {
	if element.as_node().layout_node() == none {
		element_box := b.find_box(i64(element.as_node().unique_id())) or { return none }
		element_border_top := element_box.y - element_box.padding.top - element_box.border.top
		parent := offset_parent_element(element, author_rules) or { return element_border_top }
		parent_box := b.find_box(i64(parent.as_node().unique_id())) or { return element_border_top }
		return element_border_top - (parent_box.y - parent_box.padding.top)
	}
	if !element.is_html_element() {
		return none
	}
	install_document_layout_hook(element.document())
	return f64(html.html_element_offset_top(unsafe { &dom.HTMLElement(element) }))
}

// `element`'s offsetLeft: its border-box left relative to its offsetParent's padding-box left.
pub fn (b &BlockBox) offset_left_for(element &dom.Element, author_rules []&css.CSSRule) ?f64 {
	if element.as_node().layout_node() == none {
		element_box := b.find_box(i64(element.as_node().unique_id())) or { return none }
		element_border_left := element_box.x - element_box.padding.left - element_box.border.left
		parent := offset_parent_element(element, author_rules) or { return element_border_left }
		parent_box := b.find_box(i64(parent.as_node().unique_id())) or { return element_border_left }
		return element_border_left - (parent_box.x - parent_box.padding.left)
	}
	if !element.is_html_element() {
		return none
	}
	install_document_layout_hook(element.document())
	return f64(html.html_element_offset_left(unsafe { &dom.HTMLElement(element) }))
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

// The rendered text of `element` — the `innerText`/`outerText` getter, i.e. the HTML "get the text
// steps" (https://html.spec.whatwg.org/multipage/dom.html#get-the-text-steps). Unlike `textContent`
// it reflects rendering: `display:none` and `visibility:hidden` subtrees are omitted, runs of
// collapsible white-space are collapsed across text-box boundaries and trimmed at line edges, CSS
// text transforms are applied, `<br>`/table/block boundaries introduce their specified separators,
// and `<p>` is surrounded by blank lines.
pub fn inner_text(element &dom.Element, author_rules []&css.CSSRule) string {
	if !element.is_html_element() {
		return element.as_node().descendant_text_content()
	}
	if element.as_node().layout_node() == none {
		return inner_text_for_detached_compatibility_tree(element, author_rules)
	}
	install_document_layout_hook(element.document())
	return html.html_element_inner_text(unsafe { &dom.HTMLElement(element) })
}

// Detached compatibility trees have no Document/Navigable layout lifecycle,
// so they cannot enter HTMLElement::get_the_text_steps(). Keep the old test
// transport isolated here; attached browser documents always use the retained
// source-shaped algorithm above.
fn inner_text_for_detached_compatibility_tree(element &dom.Element, author_rules []&css.CSSRule) string {
	mut results := []TextItem{}
	for child in element.as_node().children_as_vector() {
		results << rendered_text_items(child, author_rules)
	}
	results = results.filter(it.line_breaks > 0 || it.text != '')
	for results.len > 0 && results[0].line_breaks > 0 {
		results.delete(0)
	}
	for results.len > 0 && results[results.len - 1].line_breaks > 0 {
		results.delete(results.len - 1)
	}
	mut out := []u8{}
	mut i := 0
	mut last_text_was_collapsible := false
	for i < results.len {
		item := results[i]
		if item.line_breaks == 0 {
			append_inner_text_item(mut out, item)
			last_text_was_collapsible = item.collapsible
			i++
			continue
		}
		mut max_breaks := item.line_breaks
		mut j := i + 1
		for j < results.len && results[j].line_breaks > 0 {
			if results[j].line_breaks > max_breaks {
				max_breaks = results[j].line_breaks
			}
			j++
		}
		for out.len > 0 && out[out.len - 1] == ` ` {
			out.delete_last()
		}
		for _ in 0 .. max_breaks {
			out << `\n`
		}
		last_text_was_collapsible = false
		i = j
	}
	if last_text_was_collapsible {
		for out.len > 0 && out[out.len - 1] == ` ` {
			out.delete_last()
		}
	}
	return out.bytestr()
}

// Append a rendered text-box item while applying the white-space processing that occurs between
// adjacent CSS text boxes. `collapse_rendered_whitespace` handles runs inside one box; this closes
// the boundary and line-edge cases from the HTML rendered-text collection algorithm.
fn append_inner_text_item(mut out []u8, item TextItem) {
	for byte in item.text.bytes() {
		if byte == `\n` {
			if item.collapsible {
				for out.len > 0 && out[out.len - 1] == ` ` {
					out.delete_last()
				}
			}
			out << byte
			continue
		}
		if item.collapsible && byte == ` ` {
			if out.len == 0 || out[out.len - 1] in [` `, `\n`] {
				continue
			}
		}
		out << byte
	}
}

// The rendered-text collection steps for a single node
// (https://html.spec.whatwg.org/multipage/dom.html#rendered-text-collection-steps).
fn rendered_text_items(node &dom.Node, author_rules []&css.CSSRule) []TextItem {
	// A text node contributes its data after white-space processing (using the parent's white-space,
	// which is inherited). It has no children and is only reached inside a rendered subtree.
	if node.is_text() {
		text := unsafe { &dom.Text(node) }.data()
		white_space := if parent := node.parent_element() {
			visibility_id := css.property_id_from_string('visibility') or { return []TextItem{} }
			if css.cascaded_value_with_ua(parent, visibility_id, author_rules) != 'visible' {
				return []TextItem{}
			}
			resolved_white_space_behavior(parent, author_rules)
		} else {
			white_space_behavior_from_longhands('collapse', 'wrap', 'none')
		}
		transformed := if parent := node.parent_element() {
			transform := css.cascaded_value_with_ua(parent, css.property_id_from_string('text-transform') or {
				return []TextItem{}
			}, author_rules)
			apply_text_transform(text, transform)
		} else {
			text
		}
		return [
			TextItem{
				text: collapse_rendered_whitespace(transformed, white_space)
				collapsible: !white_space.preserves_spaces()
			},
		]
	}

	element := node.as_element() or { return []TextItem{} }

	// 3. A `display:none` subtree is not rendered and contributes nothing.
	display := css.cascaded_value_with_ua(element, css.property_id_from_string('display') or {
		return []TextItem{}
	}, author_rules)
	if display == 'none' {
		return []TextItem{}
	}

	// 1. Collect the children's items first (tree order).
	mut items := []TextItem{}
	for child in node.children_as_vector() {
		items << rendered_text_items(child, author_rules)
	}

	// 2. A `visibility:hidden` box hides its own contribution but not its (possibly re-shown) children.
	visibility := css.cascaded_value_with_ua(element, css.property_id_from_string('visibility') or {
		return items
	}, author_rules)
	if visibility != 'visible' {
		return items
	}
	if content_visibility_id := css.property_id_from_string('content-visibility') {
		if css.cascaded_value_with_ua(element, content_visibility_id, author_rules) == 'hidden' {
			return items
		}
	}

	local := element.local_name()

	// 5. `<br>` contributes a single line feed.
	if local == 'br' {
		items << TextItem{
			text: '\n'
		}
		return items
	}

	// Table cells are tab-separated and rows are LF-separated, except after the final sibling box.
	if display == 'table-cell' && node.next_sibling() != none {
		items << TextItem{
			text: '\t'
		}
	}
	if display == 'table-row' && node.next_sibling() != none {
		items << TextItem{
			text: '\n'
		}
	}

	// 8. `<p>` is surrounded by 2 required line breaks (a blank line).
	if local == 'p' {
		items.prepend(TextItem{ line_breaks: 2 })
		items << TextItem{
			line_breaks: 2
		}
		return items
	}

	// 9. A block-level box is surrounded by 1 required line break.
	if inner_text_display_has_block_boundaries(display) {
		items.prepend(TextItem{ line_breaks: 1 })
		items << TextItem{
			line_breaks: 1
		}
	}
	return items
}

fn inner_text_display_has_block_boundaries(display string) bool {
	if display == 'table-caption' {
		return true
	}
	if display in ['table-cell', 'table-row', 'table-row-group', 'table-header-group',
		'table-footer-group', 'table-column', 'table-column-group'] {
		return false
	}
	return is_block_level_display(display)
}

// Apply the CSS white-space collapsing that `innerText` observes. For collapsible white-space
// (`normal`/`nowrap`) every run of ASCII whitespace collapses to a single space. `pre`/`pre-wrap`
// preserve spaces and newlines verbatim; `pre-line` collapses spaces but keeps newlines.
fn collapse_rendered_whitespace(text string, white_space WhiteSpaceBehavior) string {
	if white_space.preserves_spaces() && white_space.preserves_newlines() {
		return text
	}
	if white_space.collapse == 'discard' {
		return text.bytes().filter(it !in [` `, `\t`, `\n`, `\r`, u8(12)]).bytestr()
	}
	if white_space.preserves_spaces() {
		// `preserve-spaces` turns tabs and segment breaks into spaces without
		// collapsing the resulting run. CRLF is one segment break.
		mut out := []u8{}
		mut i := 0
		bytes := text.bytes()
		for i < bytes.len {
			if bytes[i] == `\r` {
				out << ` `
				i++
				if i < bytes.len && bytes[i] == `\n` {
					i++
				}
			} else if bytes[i] in [`\n`, `\t`, u8(12)] {
				out << ` `
				i++
			} else {
				out << bytes[i]
				i++
			}
		}
		return out.bytestr()
	}
	preserve_newlines := white_space.preserves_newlines()
	mut out := []u8{}
	mut in_space := false
	for c in text {
		is_ws := c == ` ` || c == `\t` || c == `\n` || c == `\r` || c == 12 // FF
		if preserve_newlines && c == `\n` {
			// Flush any pending collapsed space run as nothing (a newline absorbs adjacent spaces).
			in_space = false
			out << `\n`
			continue
		}
		if is_ws {
			in_space = true
			continue
		}
		if in_space {
			out << ` `
			in_space = false
		}
		out << c
	}
	if in_space {
		out << ` `
	}
	return out.bytestr()
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

fn append_shallow_paint_entry(box &BlockBox, mut order []BlockBox, inherited_opacity f64) {
	mut entry := *box
	entry.children = []
	entry.opacity = inherited_opacity * box.opacity
	order << entry
}

fn (b &BlockBox) collect_paint_buckets(mut buckets PaintOrderBuckets, positioned_group bool) {
	for child in b.children {
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
		child.collect_paint_buckets(mut buckets, child_positioned_group)
	}
}

fn (b &BlockBox) collect_stacking_context(mut order []BlockBox, inherited_opacity f64) {
	effective_opacity := inherited_opacity * b.opacity
	append_shallow_paint_entry(b, mut order, inherited_opacity)
	mut buckets := PaintOrderBuckets{}
	b.collect_paint_buckets(mut buckets, false)
	for context in stable_sort_by_z(buckets.negative) {
		context.collect_stacking_context(mut order, effective_opacity)
	}
	for box in buckets.normal {
		append_shallow_paint_entry(&box, mut order, effective_opacity)
	}
	for box in buckets.zero {
		if box.stacking_context {
			box.collect_stacking_context(mut order, effective_opacity)
		} else {
			append_shallow_paint_entry(&box, mut order, effective_opacity)
		}
	}
	for context in stable_sort_by_z(buckets.positive) {
		context.collect_stacking_context(mut order, effective_opacity)
	}
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
	css_filter
	svg_mask
}

pub struct PaintVisualLayer {
pub:
	kind      PaintVisualLayerKind
	scope_id  u64
	filter    ?painting.GfxFilter
	mask_clip PaintClip
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
}

pub struct PaintCommand {
pub mut:
	kind      string // fill_rect/fill_rounded_rect/stroke_rounded_rect/fill_ellipse/stroke_ellipse/fill_polygon/draw_line/draw_text/draw_svg_path
	x         f64
	y         f64
	width     f64
	height    f64
	color     string
	text      string // for 'draw_text'
	font_size f64 = 16.0 // for 'draw_text'
	bold      bool
	italic    bool
	mono      bool
	rtl       bool // base paragraph direction for shaped text
	// DisplayListRecorder::DrawGlyphRun retains shaped glyph indices and
	// positions. Raw text remains only as the portable/backend compatibility
	// fallback; the native player must not shape it again during every repaint.
	glyph_run           ?&platform.GlyphRun
	glyph_translation_x f64
	glyph_translation_y f64
	glyph_orientation   painting.Orientation
	opacity             f64 = 1.0 // the box's cumulative opacity (this box × its ancestors')
	radius              f64 // corner radius for a rounded 'fill_rect' (0 = square)
	// Retained used corner radii for `fill_rounded_rect`. This mirrors Painting's
	// FillRoundedRect command instead of discarding elliptical/per-corner radii into vertices.
	corner_radii    BoxRadii
	blur            f64 // Gaussian blur radius for a 'fill_rect' (0 = hard edges), used by box-shadow
	shadow_offset_x f64
	shadow_offset_y f64
	shadow_spread   f64
	outer_shadow    bool // clip the shadow source out of the original border box
	// Source-shaped PaintOuterBoxShadow/PaintInnerBoxShadow payload. Unlike the
	// legacy scalar fields above, these retain distinct elliptical corner radii
	// for the content clip, shadow shape, and inner cutout.
	shadow_content_x      f64
	shadow_content_y      f64
	shadow_content_width  f64
	shadow_content_height f64
	shadow_content_radii  BoxRadii
	shadow_clip_radii     BoxRadii
	shadow_inner_x        f64
	shadow_inner_y        f64
	shadow_inner_width    f64
	shadow_inner_height   f64
	shadow_inner_radii    BoxRadii
	// The gradient for a 'fill_gradient' command (a linear-gradient background).
	gradient                  ?LinearGradient
	gradient_background_layer bool
	// `draw_svg_path` payload.
	path      string
	path_data []f32
	// Cumulative CSS/SVG affine transform in `matrix(a,b,c,d,e,f)` order. All-zero means identity.
	transform              [6]f64
	path_transform         [6]f64
	points                 []f64
	path_polygons          [][]f64
	stroke_color           string
	fill_linear_gradient   ?painting.SVGLinearGradientPaintStyle
	stroke_linear_gradient ?painting.SVGLinearGradientPaintStyle
	fill_radial_gradient   ?painting.SVGRadialGradientPaintStyle
	stroke_radial_gradient ?painting.SVGRadialGradientPaintStyle
	fill_pattern           ?&painting.SVGPatternPaintStyle
	stroke_pattern         ?&painting.SVGPatternPaintStyle
	stroke_width           f64
	stroke_first           bool
	fill_even_odd          bool
	stroke_linecap         int
	stroke_linejoin        int
	stroke_miterlimit      f64 = 4.0
	line_style             string = 'solid'
	fill_opacity           f64 = 1.0
	stroke_opacity         f64 = 1.0
	// `draw_background_image` payload. Intrinsic dimensions are resolved by the image renderer.
	image_url                string
	image_repeat_x           string
	image_repeat_y           string
	image_size               string
	image_position_x         string
	image_position_y         string
	image_rendering          css.ImageRendering
	image_clip_x             f64
	image_clip_y             f64
	image_clip_width         f64
	image_clip_height        f64
	image_clip_radii         BoxRadii
	image_attachment         string
	image_computed_layer     ?css.BackgroundLayerData
	image_resolution_context css.LengthResolutionContext
	image_scroll_offset_x    f64
	image_scroll_offset_y    f64
	image_viewport_offset_x  f64
	image_viewport_offset_y  f64
	background_blend_mode    painting.BlendMode
	// ImagePaintable's retained, typed replaced-content geometry. Background
	// images leave this empty and continue through BackgroundPainting.
	image_paintable ?painting.ImagePaintable
	// CanvasPaintable publishes its current RGBA surface as external content.
	canvas_bitmap    ?&dom.ImmutableBitmap_
	canvas_paintable ?painting.CanvasPaintable
	// VideoPaintable retains the representation switch separately from the
	// optional poster/current-frame bitmap.
	video_bitmap          ?&dom.ImmutableBitmap_
	video_external_source ?&html.MediaExternalContentSource
	video_representation  painting.VideoRepresentation
	video_paintable       ?painting.VideoPaintable
	// NavigableContainerViewportPaintable retains the hosted document's
	// display list as a nested command stream rather than rasterizing it.
	nested_viewport_commands  []PaintCommand
	nested_viewport_paintable ?painting.NavigableContainerViewportPaintable
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
	recording_clip ?LayoutRect
	// Effects and SVG masks are group operations. Retain their ancestor order so
	// replay can emit balanced layer boundaries around the complete subtree.
	visual_layer_list &PaintVisualLayerList = unsafe { nil }
	visual_layer      PaintVisualLayer
	// ApplyBackdropFilter samples the already-painted destination. If this box
	// also has `filter`, that sample comes from outside its newly-opened filter
	// layer while the filtered backdrop is painted into the layer with the box.
	backdrop_filter                ?painting.GfxFilter
	backdrop_source_outside_filter bool
	// Synthetic display-list controls bracket all commands belonging to one
	// SVG mask/clip stacking scope so destination-in is applied once.
	mask_clip PaintClip
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
	for shadow in resolved {
		if shadow.placement == .outer {
			commands << PaintCommand{
				kind: 'paint_outer_box_shadow'
				x: shadow.shadow_rect.x
				y: shadow.shadow_rect.y
				width: shadow.shadow_rect.width
				height: shadow.shadow_rect.height
				color: painting_color_string(shadow.color)
				opacity: opacity
				blur: shadow.blur_radius
				corner_radii: transport_radii_from_painting(shadow.shadow_corner_radii)
				shadow_content_x: shadow.content_rect.x
				shadow_content_y: shadow.content_rect.y
				shadow_content_width: shadow.content_rect.width
				shadow_content_height: shadow.content_rect.height
				shadow_content_radii: transport_radii_from_painting(shadow.content_corner_radii)
				shadow_clip_radii: transport_radii_from_painting(shadow.clip_corner_radii)
			}
		} else {
			commands << PaintCommand{
				kind: 'paint_inner_box_shadow'
				x: shadow.outer_shadow_rect.x
				y: shadow.outer_shadow_rect.y
				width: shadow.outer_shadow_rect.width
				height: shadow.outer_shadow_rect.height
				color: painting_color_string(shadow.color)
				opacity: opacity
				blur: shadow.blur_radius
				corner_radii: transport_radii_from_painting(shadow.content_corner_radii)
				shadow_content_x: shadow.content_rect.x
				shadow_content_y: shadow.content_rect.y
				shadow_content_width: shadow.content_rect.width
				shadow_content_height: shadow.content_rect.height
				shadow_content_radii: transport_radii_from_painting(shadow.content_corner_radii)
				shadow_clip_radii: transport_radii_from_painting(shadow.clip_corner_radii)
				shadow_inner_x: shadow.inner_shadow_rect.x
				shadow_inner_y: shadow.inner_shadow_rect.y
				shadow_inner_width: shadow.inner_shadow_rect.width
				shadow_inner_height: shadow.inner_shadow_rect.height
				shadow_inner_radii: transport_radii_from_painting(shadow.inner_corner_radii)
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

fn background_layer_command(layer BackgroundImageLayer, origin LayoutRect, clip LayoutRect,
	clip_radii BoxRadii, opacity f64, radius f64, points []f64,
	background_scroll_offset painting.Point, image_rendering css.ImageRendering) ?PaintCommand {
	blend_mode := background_image_layer_blend_mode(layer)
	if source := layer.gradient_source {
		computed_layer := layer.computed_layer or { return none }
		resolved_layer := painting.resolve_background_layer_without_intrinsic(painting.BackgroundLayerWithoutIntrinsicResolutionInput{
			layer: computed_layer
			image_id: source.serialize(.normal)
			background_positioning_area: painting.Rect{origin.x, origin.y, origin.width, origin.height}
			resolution_context: layer.resolution_context
		}) or { return none }
		gradient := resolve_background_gradient(source, resolved_layer.image_rect.width, resolved_layer.image_rect.height, layer.resolution_context, layer.gradient_context) or {
			return none
		}
		return PaintCommand{
			kind: 'fill_gradient'
			x: origin.x
			y: origin.y
			width: origin.width
			height: origin.height
			opacity: opacity
			radius: radius
			points: points
			gradient: gradient
			gradient_background_layer: true
			image_clip_x: clip.x
			image_clip_y: clip.y
			image_clip_width: clip.width
			image_clip_height: clip.height
			image_clip_radii: clip_radii
			image_attachment: layer.attachment
			image_computed_layer: computed_layer
			image_resolution_context: layer.resolution_context
			image_scroll_offset_x: background_scroll_offset.x
			image_scroll_offset_y: background_scroll_offset.y
			background_blend_mode: blend_mode
		}
	}
	if layer.url == '' {
		return none
	}
	return PaintCommand{
		kind: 'draw_background_image'
		x: origin.x
		y: origin.y
		width: origin.width
		height: origin.height
		opacity: opacity
		radius: radius
		points: points
		image_url: layer.url
		image_repeat_x: layer.repeat_x
		image_repeat_y: layer.repeat_y
		image_size: layer.size
		image_position_x: layer.position_x
		image_position_y: layer.position_y
		image_rendering: image_rendering
		image_clip_x: clip.x
		image_clip_y: clip.y
		image_clip_width: clip.width
		image_clip_height: clip.height
		image_clip_radii: clip_radii
		image_attachment: layer.attachment
		image_computed_layer: layer.computed_layer
		image_resolution_context: layer.resolution_context
		image_scroll_offset_x: background_scroll_offset.x
		image_scroll_offset_y: background_scroll_offset.y
		background_blend_mode: blend_mode
	}
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
			if paintable := node.paintable_box() {
				offset := paintable.scroll_offset()
				return painting.Point{offset.x(), offset.y()}
			}
		}
	}
	return painting.Point{fallback.scroll_offset_x, fallback.scroll_offset_y}
}

fn (b &BlockBox) compatibility_absolute_padding_rect() painting.Rect {
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
		checked: b.form_control_checked
		indeterminate: b.form_control_indeterminate
		enabled: b.form_control_enabled
		activated: b.form_control_activated
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
	// Scrollbar::is_enlarged() is false until pointer interaction enlarges it,
	// so the ordinary overlay has no gutter. Preserve the gutter path for data
	// produced by that translated geometry helper as the interaction layer grows.
	if data.gutter_rect.width > 0 && data.gutter_rect.height > 0 {
		commands << PaintCommand{
			kind: 'fill_rect'
			x: data.gutter_rect.x
			y: data.gutter_rect.y
			width: data.gutter_rect.width
			height: data.gutter_rect.height
			color: overlay.scrollbar_track_color.serialize()
			opacity: opacity
		}
	}
	thumb := data.thumb_rect
	mut thumb_color := overlay.scrollbar_thumb_color
	if data.gutter_rect.width <= 0 && data.gutter_rect.height <= 0 && overlay.default_scrollbar_colors {
		// DisplayListPlayerSkia lowers only the initial thin thumb to alpha 128.
		thumb_color.a = 128
	}
	// SkRRect normalizes the player's width/2 radius against the short axis.
	radius := math.min(thumb.width, thumb.height) / 2.0
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
		opacity: opacity
		points: [from_x, from_y, to_x, to_y]
		stroke_width: 1
	}
}

fn (b &BlockBox) append_overlay_commands(mut commands []PaintCommand, metrics painting.ChromeMetrics, opacity f64) {
	overlay := b.overlay or { return }
	padding_rect := b.compatibility_absolute_padding_rect()
	if overlay.scrollbar_width != .none_ {
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
			radii := effective_box_radii(child.border_radii, child.border_radius, border_rect.width, border_rect.height)
			cells << painting.TableCellPaintData{
				coordinates: coordinates
				rect: painting.Rect{border_rect.x, border_rect.y, border_rect.width, border_rect.height}
				borders: borders
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

fn append_painting_display_command(mut commands []PaintCommand,
	display_command painting.DisplayListCommand, opacity f64) {
	match display_command {
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
				path: painting_path_svg(display_command.path)
				path_data: compatibility_pack_clip_path_segments(display_command.path)
				points: if polygons.len > 0 { polygons[0] } else { []f64{} }
				path_polygons: polygons
				fill_even_odd: display_command.winding_rule == .even_odd
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
				backdrop_filter: display_command.filter
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
	filter := box.backdrop_filter.to_gfx_filter(1.0) or { return }
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
		commands[start].backdrop_source_outside_filter = box.filter.to_gfx_filter(1.0) != none
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
	mut commands := []PaintCommand{}
	metrics := painting.new_chrome_metrics(1.0) or { return commands }
	for entry_index, entry in entries {
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
		background_border_rect := if box.paints_canvas_background && box.canvas_width > 0 && box.canvas_height > 0 {
			rect_union(border_rect, LayoutRect{box.canvas_x, box.canvas_y, box.canvas_width, box.canvas_height})
		} else {
			border_rect
		}
		// StackingContext::paint() and SVGSVGPaintable::paint_svg_box() record a
		// transparent rectangle for an SVG filter even when the source paints no
		// pixels. It expands the effect input to the target bounds so feFlood and
		// feImage can generate content for otherwise-empty elements.
		if svg_filter_bounds := box.filter.svg_filter_bounds {
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
		box_radii := effective_box_radii(box.border_radii, box.border_radius, border_width, border_height)
		uniform_circle_radii := box_radii_are_uniform_circles(box_radii)
		radius := if uniform_circle_radii { box_radii.top_left.x } else { 0.0 }
		rounded_points := if !box_radii_are_zero(box_radii) && !uniform_circle_radii {
			rounded_rect_points(border_left, border_top, border_width, border_height, box_radii)
		} else {
			[]f64{}
		}
		// The resolved shadow list is immutable while recording. Share its backing
		// store, as PaintableBox does upstream, instead of copying every layer on
		// every repaint. The local header is only appended to for the empty-list
		// compatibility case, so no element visible through the box is mutated.
		mut box_shadows := unsafe { box.shadows }
		if box_shadows.len == 0 {
			if shadow := box.shadow {
				box_shadows << shadow
			}
		}
		background_paint_start := commands.len
		if !empty_cell_hidden {
			paintable_box_paint_backdrop_filter(mut commands, box, border_rect, box_radii, opacity)
		}
		background_isolated := box.background_images.any(background_image_layer_blend_mode(it) != .normal)
		needs_background_text_clip := box.background_color_clip == 'text'
			&& !box.paints_canvas_background && !box.skip_background_paint && !empty_cell_hidden
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
		color_rect := background_box_rect_from_border(box, box.background_color_clip, background_border_rect)
		color_radii := background_box_radii(box, box.background_color_clip, box_radii, color_rect)
		if !box.skip_background_paint && !empty_cell_hidden && box.background_color.a > 0 && !box.paints_canvas_background && !box_radii_are_zero(color_radii) {
			if box_radii_are_uniform_circles(color_radii) {
				commands << PaintCommand{
					kind: 'fill_rect'
					x: color_rect.x
					y: color_rect.y
					width: color_rect.width
					height: color_rect.height
					color: box.background_color.serialize()
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
				opacity: opacity
			}
		}
		// Compatibility-only boxes still carry their single parsed gradient separately. Typed layout
		// retains gradients in the ordered image layer list below, as BackgroundPainting does.
		if !box.skip_background_paint && !empty_cell_hidden {
			has_retained_gradient_layer := box.background_images.any(it.gradient_source != none)
			if grad := box.background_gradient {
				if !has_retained_gradient_layer {
					gradient_points := if box.paints_canvas_background {
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
						radius: if box.paints_canvas_background { 0.0 } else { radius }
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
			for layer_index := box.background_images.len - 1; layer_index >= 0; layer_index-- {
				layer := box.background_images[layer_index]
				origin := background_box_rect(box, layer.origin)
				clip := background_box_rect_from_border(box, layer.clip, background_border_rect)
				clip_radii := if box.paints_canvas_background {
					BoxRadii{}
				} else {
					background_box_radii(box, layer.clip, box_radii, clip)
				}
				if command := background_layer_command(layer, origin, clip, clip_radii, opacity, if box.paints_canvas_background {
					0.0
				} else {
					radius
				}, if box.paints_canvas_background { []f64{} } else { rounded_points }, background_scroll_offset, box.replaced_image_rendering) {
					commands << command
				}
			}
		}
		if background_isolated && !box.skip_background_paint && !empty_cell_hidden {
			commands << PaintCommand{ kind: 'end_background_blend_group' }
		}
		if needs_background_text_clip {
			commands << PaintCommand{ kind: 'end_background_text_clip' }
		}
		if fieldset := box.fieldset_paintable {
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
		if box.replaced_image_url != '' {
			commands << PaintCommand{
				kind: if box.replaced_image_paintable != none {
					'draw_replaced_image'
				} else if box.is_svg_image { 'draw_svg_image' } else { 'draw_background_image' }
				x: box.x
				y: box.y
				width: box.width
				height: box.height
				opacity: opacity
				image_url: box.replaced_image_url
				image_repeat_x: 'no-repeat'
				image_repeat_y: 'no-repeat'
				image_size: box.replaced_image_size
				image_position_x: box.replaced_image_position_x
				image_position_y: box.replaced_image_position_y
				image_rendering: box.replaced_image_rendering
				image_clip_x: box.x
				image_clip_y: box.y
				image_clip_width: box.width
				image_clip_height: box.height
				image_paintable: box.replaced_image_paintable
			}
		}
		if bitmap := box.canvas_bitmap {
			if canvas_paintable := box.canvas_paintable {
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
		if video_paintable := box.video_paintable {
			commands << PaintCommand{
				kind: 'draw_video'
				x: box.x
				y: box.y
				width: box.width
				height: box.height
				opacity: opacity
				video_bitmap: box.video_bitmap
				video_external_source: box.video_external_source
				video_representation: box.video_representation
				video_paintable: video_paintable
			}
		}
		if nested_viewport_paintable := box.nested_viewport_paintable {
			if hosted_document := box.nested_viewport_document {
				nested_layout := run_document_layout(hosted_document, box.width, box.height) or {
					DocumentLayoutResult{}
				}
				if nested_layout.root != unsafe { nil } {
					mut mutable_hosted_document := unsafe { &dom.Document(hosted_document) }
					if nested_display_list := mutable_hosted_document.record_display_list() {
						commands << PaintCommand{
							kind: 'paint_nested_display_list'
							x: box.x
							y: box.y
							width: box.width
							height: box.height
							opacity: opacity
							nested_viewport_commands: display_list_commands(nested_display_list).clone()
							nested_viewport_paintable: nested_viewport_paintable
						}
					}
				}
			}
		}
		form_control_state := box.current_form_control_state()
		if box.form_control_kind in ['checkbox', 'radio'] {
			converter := painting.new_device_pixel_converter(1.0) or { return commands }
			control_rect := converter.enclosing_device_rect(painting.Rect{
				x: box.x
				y: box.y
				width: box.width
				height: box.height
			})
			input_colors := painting.compute_input_colors(box.form_control_color_scheme, box.form_control_accent_color)
			display_commands := if box.form_control_kind == 'checkbox' {
				painting.checkbox_commands(control_rect, form_control_state.checked, form_control_state.indeterminate, form_control_state.enabled, form_control_state.activated, box.form_control_color_scheme, input_colors)
			} else {
				painting.radio_button_commands(control_rect, form_control_state.checked, form_control_state.enabled, form_control_state.activated, box.form_control_color_scheme, input_colors)
			}
			for display_command in display_commands {
				append_painting_display_command(mut commands, display_command, opacity)
			}
		}
		foreground_replaced_end := commands.len
		// Translate each border side through Painting's source-shaped BorderPainting paths. Matching
		// colors are batched while each used thickness is represented independently.
		border_start := commands.len
		// PaintableBox::paint() skips ordinary borders for collapsed cells and
		// for the collapsed table principal. Their shared edges are painted below.
		if !box.table_cell && !(box.uses_collapsed_borders && box.table_inside) {
			border_colors := effective_border_colors(box.border_colors, box.border_color)
			if fieldset := box.fieldset_paintable {
				converter := painting.new_device_pixel_converter(1.0) or { return commands }
				borders := painting_borders_from_transport(box.border, border_colors, box.border_styles)
				for fieldset_command in fieldset.paint(borders, painting_radii_from_transport(box_radii), converter) {
					command_start_index := commands.len
					append_painting_display_command(mut commands, fieldset_command.command, opacity)
					if clip := fieldset_command.clip {
						set_recording_clip_for_range(mut commands, command_start_index, commands.len, clip)
					}
				}
			} else {
				append_translated_border_commands(mut commands, box.border, border_colors, box.border_styles, box_radii, border_left, border_top, border_width, border_height, opacity)
			}
		}
		border_end := commands.len
		table_border_start := commands.len
		box.append_table_border_commands(mut commands, opacity)
		table_border_end := commands.len
		// PaintableBox::paint() inflates the border rect and radii, then sends outlines through the
		// same BorderPainting.cpp dispatcher as ordinary borders.
		outline_start := commands.len
		append_translated_outline_commands(mut commands, box.outline_width, box.outline_offset, box.outline_color, box.outline_style, box_radii, border_left, border_top, border_width, border_height, opacity)
		outline_end := commands.len
		foreground_content_start := commands.len
		if box.svg_path.len > 0 {
			commands << PaintCommand{
				kind: 'draw_svg_path'
				x: box.x
				y: box.y
				width: box.width
				height: box.height
				color: box.svg_fill_color
				fill_linear_gradient: box.svg_fill_linear_gradient
				fill_radial_gradient: box.svg_fill_radial_gradient
				fill_pattern: box.svg_fill_pattern
				opacity: opacity
				path: box.svg_path
				path_data: box.svg_path_data
				path_transform: box.svg_transform
				points: box.svg_points
				fill_even_odd: box.svg_fill_even_odd
				stroke_color: box.svg_stroke_color
				stroke_linear_gradient: box.svg_stroke_linear_gradient
				stroke_radial_gradient: box.svg_stroke_radial_gradient
				stroke_pattern: box.svg_stroke_pattern
				stroke_width: box.svg_stroke_width
				stroke_first: box.svg_stroke_first
				stroke_linecap: box.svg_stroke_linecap
				stroke_linejoin: box.svg_stroke_linejoin
				stroke_miterlimit: box.svg_stroke_miterlimit
				fill_opacity: box.svg_fill_opacity
				stroke_opacity: box.svg_stroke_opacity
			}
		}
		if box.marker_shape.len > 0 {
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
		}
		for line in box.lines {
			commands << inline_fragment_commands(line.fragments, opacity)
			commands << text_fragment_commands(line.fragments, opacity)
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
			commands[command_index].paint_box_index = entry_index
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
	return entries, steps
}

// StackingContext::hit_test() follows the same phases in reverse but, unlike
// paint(), opacity:0 remains hit-testable. Non-invertible contexts are omitted
// from both plans.
fn (b &BlockBox) compatibility_hit_test_steps() []CompatibilityPaintStep {
	mut steps := []CompatibilityPaintStep{}
	b.collect_compatibility_stacking_context_paint_steps(mut steps, true)
	return steps
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
	return replay_cached_paint_commands(steps, phase_commands, command_count)
}

// Translation of PaintableBox::m_cached_phase_commands. Each retained box has
// one bucket for every PaintPhase, populated by its first paint and reused by
// later display-list recordings until paint-cache invalidation.
fn (b &BlockBox) build_paint_phase_command_cache(entries []PaintOrderEntry) ([][]PaintCommand, int) {
	flat_commands := b.flat_paint_commands(entries)
	mut phase_commands := [][]PaintCommand{len: entries.len * compatibility_paint_phase_count}
	for command in flat_commands {
		bucket := command.paint_box_index * compatibility_paint_phase_count + int(command.paint_phase)
		phase_commands[bucket] << command
	}
	return phase_commands, flat_commands.len
}

// Regenerate only invalidated PaintableBox entries. This is the retained-cache
// path used after a box-level repaint request; document-level repaint requests
// can replay every existing bucket without calling paint again.
fn (b &BlockBox) refresh_paint_phase_command_cache(entries []PaintOrderEntry, mut phase_commands [][]PaintCommand, mut entry_valid []bool) int {
	mut selected := []bool{len: entries.len}
	mut has_invalid_entry := false
	for index in 0 .. entries.len {
		if !entry_valid[index] {
			selected[index] = true
			has_invalid_entry = true
		}
	}
	if !has_invalid_entry {
		return 0
	}
	flat_commands := b.flat_paint_commands_for_entries(entries, selected)
	for command in flat_commands {
		bucket := command.paint_box_index * compatibility_paint_phase_count + int(command.paint_phase)
		phase_commands[bucket] << command
	}
	for index in 0 .. entries.len {
		if selected[index] {
			entry_valid[index] = true
		}
	}
	return flat_commands.len
}

// StackingContext::paint_node() replays the cached phase vector at each step in
// the retained stacking-context traversal. Keep that replay separate from cache
// construction so repaints do not regenerate or redistribute box commands.
fn replay_cached_paint_commands(steps []CompatibilityPaintStep, phase_commands [][]PaintCommand, command_count int) []PaintCommand {
	mut commands := []PaintCommand{cap: command_count}
	mut viewport_scroll_offset := painting.Point{}
	if steps.len > 0 {
		root := steps[0].box
		if overlay := root.overlay {
			viewport_scroll_offset = root.current_scroll_offset(overlay)
		}
	}
	for step in steps {
		if step.entry_index < 0 {
			continue
		}
		bucket := step.entry_index * compatibility_paint_phase_count + int(step.phase)
		for cached_command in phase_commands[bucket] {
			mut command := cached_command
			apply_live_scrollbar_offset(mut command, step.box)
			apply_live_background_offsets(mut command, step.box, viewport_scroll_offset)
			commands << command
		}
	}
	return commands
}

fn apply_live_background_offsets(mut command PaintCommand, box &BlockBox,
	viewport_scroll_offset painting.Point) {
	if command.kind != 'draw_background_image'
		&& !(command.kind == 'fill_gradient' && command.gradient_background_layer) {
		return
	}
	if overlay := box.overlay {
		current := box.current_scroll_offset(overlay)
		command.image_scroll_offset_x = current.x
		command.image_scroll_offset_y = current.y
	}
	command.image_viewport_offset_x = viewport_scroll_offset.x
	command.image_viewport_offset_y = viewport_scroll_offset.y
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
	return first.shape_as_run && next.shape_as_run && first.text_run_id != 0 && first.text_run_id == next.text_run_id && first.inline_node_id == next.inline_node_id && first.color == next.color && first.font_size == next.font_size && first.bold == next.bold && first.italic == next.italic && first.mono == next.mono && first.decoration == next.decoration && first.decoration_color == next.decoration_color && first.decoration_color_set == next.decoration_color_set && first.decoration_style == next.decoration_style && first.decoration_thickness == next.decoration_thickness && first.preserves_spaces == next.preserves_spaces && first.rtl == next.rtl
}

// Compatibility layout can still supply word fragments for one naturally-spaced DOM text node;
// coalesce those into one paint command. The typed adapter already supplies the committed C++-shaped
// LineBoxFragment intact, so it takes the single-fragment path without rebuilding the string.
fn unselected_text_fragment_commands(fragments []TextFragment, opacity f64) []PaintCommand {
	mut commands := []PaintCommand{}
	mut i := 0
	for i < fragments.len {
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
			rtl: first.rtl
			opacity: opacity
		}
		// Typed layout transports one committed LineBoxFragment per entry. A
		// compatibility run assembled from several word fragments has no single
		// retained glyph run and keeps the raw-string fallback above.
		if j == i + 1 {
			if glyph_run := first.paintable_fragment.glyph_run {
				mut retained_run := unsafe { &platform.GlyphRun(glyph_run) }
				retained_run.refresh_replay_data()
				text_command.glyph_run = retained_run
				text_command.glyph_translation_x = first.x
				text_command.glyph_translation_y = first.y + first.baseline
				text_command.glyph_orientation = first.paintable_fragment.orientation
			}
		}
		commands << text_command
		for k := i; k < j; k++ {
			commands << decoration_commands(fragments[k], opacity)
		}
		i = j
	}
	return commands
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
	rect := paintable_fragment.range_rect(.start_and_end, paintable_fragment.start_offset + start, paintable_fragment.start_offset + end)
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
			rtl: fragment.rtl
			opacity: opacity
			blur: layer.blur
		}
		if retained_run := glyph_run {
			shadow_command.glyph_run = retained_run
			shadow_command.glyph_translation_x = fragment.x + layer.offset_x
			shadow_command.glyph_translation_y = fragment.y + fragment.baseline + layer.offset_y
		}
		commands << shadow_command
	}
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
		rtl: fragment.rtl
		opacity: opacity
	}
	if glyph_run := fragment.paintable_fragment.glyph_run {
		mut retained_run := unsafe { &platform.GlyphRun(glyph_run) }
		retained_run.refresh_replay_data()
		text_command.glyph_run = retained_run
		text_command.glyph_translation_x = fragment.x
		text_command.glyph_translation_y = fragment.y + fragment.baseline
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
fn selected_text_fragment_commands(fragments []TextFragment, opacity f64) []PaintCommand {
	spans := compute_render_spans(fragments)
	mut commands := []PaintCommand{}
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
			opacity: opacity
		}
	}
	for span in spans {
		paint_text_shadow(mut commands, fragments[span.fragment_index], span, opacity)
	}
	for span in spans {
		paint_text_fragment(mut commands, fragments[span.fragment_index], span, opacity)
	}
	return commands
}

fn text_fragment_commands(fragments []TextFragment, opacity f64) []PaintCommand {
	if !fragments.any(text_fragment_has_active_selection(it))
		&& !fragments.any(it.text_shadows.len > 0) {
		return unselected_text_fragment_commands(fragments, opacity)
	}
	return selected_text_fragment_commands(fragments, opacity)
}

// PaintableWithLines::fragment_at_position(). Boundary offsets are inclusive,
// so a caret at a fragment edge resolves to the first retained fragment just
// as Vector::first_matching() does upstream.
fn fragment_at_position(box &BlockBox, position &dom.Position) ?&TextFragment {
	position_node := position.node() or { return none }
	for line_index in 0 .. box.lines.len {
		for fragment_index in 0 .. box.lines[line_index].fragments.len {
			fragment := unsafe { &box.lines[line_index].fragments[fragment_index] }
			if fragment.layout_handle == unsafe { nil } {
				continue
			}
			layout_node := unsafe { &Node(fragment.layout_handle) }
			fragment_node := layout_node.dom_node() or { continue }
			start := fragment.paintable_fragment.start_offset
			end := start + fragment.paintable_fragment.length_in_code_units
			if voidptr(fragment_node) == voidptr(position_node) && position.offset() >= start
				&& position.offset() <= end {
				return fragment
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
	if !navigable.is_focused() {
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
	} else {
		position_node := position.node() or { return none }
		if voidptr(position_node) != voidptr(dom_node) {
			return none
		}
		caret_color = layout_node.computed_values().caret_color()
		rect = LayoutRect{
			x: box.x - box.padding.left
			y: box.y - box.padding.top
			width: 1
			height: layout_node.computed_values().line_height().to_double()
		}
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
				}
			}
		}
	}
	for child in box.children {
		// Backgrounds 4: descendants that are neither in flow nor floating do
		// not contribute, and their complete subtrees are skipped.
		if child.absolutely_positioned && !child.floating {
			continue
		}
		append_background_text_clip_runs(&child, mut runs)
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
fn inline_fragment_commands(fragments []TextFragment, opacity f64) []PaintCommand {
	mut commands := []PaintCommand{}
	mut i := 0
	for i < fragments.len {
		first := fragments[i]
		if first.inline_node_id == 0 {
			i++
			continue
		}
		mut j := i + 1
		for j < fragments.len && fragments[j].inline_node_id == first.inline_node_id {
			j++
		}
		last := fragments[j - 1]
		left := first.x - first.border.left
		top := first.y - first.border.top
		width := last.x + last.width - first.x + first.border.left + first.border.right
		height := first.height + first.border.top + first.border.bottom
		fragment_radii := effective_box_radii(first.border_radii, first.border_radius, width, height)
		uniform_circle_radii := box_radii_are_uniform_circles(fragment_radii)
		radius := if uniform_circle_radii { fragment_radii.top_left.x } else { 0.0 }
		mut fragment_shadows := unsafe { first.shadows }
		if fragment_shadows.len == 0 {
			if shadow := first.shadow {
				fragment_shadows << shadow
			}
		}
		for shadow in fragment_shadows {
			if shadow.inset {
				continue
			}
			shadow_width := width + 2.0 * shadow.spread
			shadow_height := height + 2.0 * shadow.spread
			commands << PaintCommand{
				kind: 'fill_rect'
				x: left + shadow.offset_x - shadow.spread
				y: top + shadow.offset_y - shadow.spread
				width: shadow_width
				height: shadow_height
				color: shadow.color.serialize()
				opacity: opacity
				radius: clamp_radius(first.border_radius, shadow_width, shadow_height)
				blur: shadow.blur
				shadow_offset_x: shadow.offset_x
				shadow_offset_y: shadow.offset_y
				shadow_spread: shadow.spread
				outer_shadow: true
			}
		}
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
			if command := background_layer_command(layer, LayoutRect{left, top, width, height}, LayoutRect{left, top, width, height}, fragment_radii, opacity, radius, []f64{}, painting.Point{}, .auto_) {
				commands << command
			}
		}
		if background_isolated {
			commands << PaintCommand{ kind: 'end_background_blend_group' }
		}
		append_inset_shadow_commands(mut commands, fragment_shadows, left + first.border.left, top + first.border.top, non_negative(width - first.border.left - first.border.right), non_negative(height - first.border.top - first.border.bottom), non_negative(radius - first.border.top), opacity)
		border_colors := effective_border_colors(first.border_colors, first.border_color)
		append_translated_border_commands(mut commands, first.border, border_colors, first.border_styles, fragment_radii, left, top, width, height, opacity)
		i = j
	}
	return commands
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
			match line {
				'overline' {
					line_start = painting.IntPoint{line_start.x, line_start.y - thickness - 1}
					line_end = painting.IntPoint{line_end.x, line_end.y - thickness - 1}
				}
				'line-through' {
					line_start = painting.IntPoint{line_start.x, line_start.y - thickness / 2}
					line_end = painting.IntPoint{line_end.x, line_end.y - thickness / 2}
				}
				else {}
			}
			append_text_decoration_draw_line(mut commands, line_start, line_end, color, thickness, 'solid', opacity)
			append_text_decoration_draw_line(mut commands, painting.IntPoint{line_start.x, line_start.y + thickness + 1}, painting.IntPoint{line_end.x, line_end.y + thickness + 1}, color, thickness, 'solid', opacity)
		}
		'wavy' {
			match line {
				'underline' {
					line_start = painting.IntPoint{line_start.x, line_start.y + thickness + 1}
					line_end = painting.IntPoint{line_end.x, line_end.y + thickness + 1}
				}
				'overline' {
					line_start = painting.IntPoint{line_start.x, line_start.y - thickness - 1}
					line_end = painting.IntPoint{line_end.x, line_end.y - thickness - 1}
				}
				'line-through' {
					line_start = painting.IntPoint{line_start.x, line_start.y - thickness / 2}
					line_end = painting.IntPoint{line_end.x, line_end.y - thickness / 2}
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
				path: painting_path_svg(path)
				path_data: compatibility_pack_clip_path_segments(path)
				points: flat_points
				path_polygons: [flat_points.clone()]
				stroke_color: color
				stroke_width: thickness
				stroke_linecap: 1
				stroke_linejoin: 1
				stroke_miterlimit: 0
			}
		}
		else {
			append_text_decoration_draw_line(mut commands, line_start, line_end, color, thickness, style, opacity)
		}
	}
}

// Direct translation of PaintableWithLines.cpp::paint_text_decoration().
fn paint_text_decoration(fragment TextFragment, opacity f64) []PaintCommand {
	if fragment.decoration == '' || fragment.decoration == 'none' {
		return []PaintCommand{}
	}
	mut glyph_height := fragment.glyph_height
	mut font_ascent := fragment.font_ascent
	mut font_descent := fragment.font_descent
	mut font_x_height := fragment.font_x_height
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
		font_x_height = f64(metrics.x_height)
	}
	typographic_height := font_ascent + font_descent
	baseline := if fragment.baseline_set {
		fragment.baseline
	} else {
		font_ascent + (fragment.height - typographic_height) / 2.0
	}
	mut color := if fragment.decoration_color_set {
		fragment.decoration_color.serialize()
	} else {
		fragment.color.serialize()
	}
	css_thickness := if fragment.decoration_thickness_set || fragment.decoration_thickness > 0 {
		math.max(fragment.decoration_thickness, 1.0)
	} else {
		math.max(glyph_height * 0.1, 1.0)
	}
	mut thickness := int(math.round(css_thickness))
	mut style := if fragment.decoration_style == '' { 'solid' } else { fragment.decoration_style }
	mut underline_offset := fragment.text_underline_offset
	mut commands := []PaintCommand{}
	for input_line in fragment.decoration.fields() {
		mut line := input_line
		if line == 'spelling-error' {
			color = 'rgb(255 0 0)'
			thickness = 1
			style = 'wavy'
			line = 'underline'
			underline_offset = 0
		} else if line == 'grammar-error' {
			color = 'rgb(0 100 0)'
			thickness = 1
			style = 'wavy'
			line = 'underline'
			underline_offset = 0
		}
		if line == 'none' || line == 'blink' {
			return commands
		}
		mut line_y := 0.0
		match line {
			'underline' {
				position := if fragment.text_underline_position == 'under' {
					baseline + font_descent
				} else {
					baseline
				}
				line_y = fragment.y + position + underline_offset
			}
			'overline' {
				line_y = fragment.y + baseline - glyph_height
			}
			'line-through' {
				line_y = fragment.y + baseline - font_x_height * 0.5
			}
			else {
				continue
			}
		}
		start := painting.IntPoint{int(math.round(fragment.x)), int(math.round(line_y))}
		end := painting.IntPoint{int(math.round(fragment.x + fragment.width)), int(math.round(line_y))}
		append_text_decoration_style(mut commands, line, start, end, color, thickness, style, opacity)
	}
	return commands
}

fn decoration_commands(fragment TextFragment, opacity f64) []PaintCommand {
	return paint_text_decoration(fragment, opacity)
}

// The outside marker line for a `display: list-item` element. It hangs one glyph-width to the left
// of the content and shares the first content line's y/height when one exists.
fn list_marker_line(element &dom.Element, content_x f64, content_top f64, text_color css.Color, content_lines []TextLine, author_rules []&css.CSSRule) ?TextLine {
	display := css.cascaded_value_with_ua(element, css.property_id_from_string('display') or {
		return none
	}, author_rules)
	if display != 'list-item' {
		return none
	}
	marker := list_marker_text(element, author_rules)
	if marker == '' {
		return none
	}
	glyph := 0.5 * css.computed_font_size_px(element, author_rules)
	marker_width := f64(marker.runes().len) * glyph
	line_height := if content_lines.len > 0 {
		content_lines[0].height
	} else {
		css.computed_line_height_px(element, author_rules)
	}
	marker_y := if content_lines.len > 0 { content_lines[0].y } else { content_top }
	marker_x := content_x - marker_width - glyph // hang to the left, one glyph-width gap
	return TextLine{
		x: marker_x
		y: marker_y
		width: marker_width
		height: line_height
		fragments: [
			TextFragment{
				x: marker_x
				y: marker_y
				width: marker_width
				height: line_height
				text: marker
				color: text_color
				font_size: css.computed_font_size_px(element, author_rules)
			},
		]
	}
}

fn add_inside_list_marker(element &dom.Element, content_x f64, content_width f64, content_top f64, text_color css.Color, original_lines []TextLine, author_rules []&css.CSSRule) []TextLine {
	marker := list_marker_text(element, author_rules)
	if marker == '' {
		return original_lines
	}
	font_size := css.computed_font_size_px(element, author_rules)
	glyph := 0.5 * font_size
	marker_width := f64(marker.runes().len) * glyph
	advance := marker_width + glyph
	mut lines := original_lines.clone()
	if lines.len == 0 {
		line_height := css.computed_line_height_px(element, author_rules)
		return [
			TextLine{
				x: content_x
				y: content_top
				width: marker_width
				height: line_height
				fragments: [
					TextFragment{
						x: content_x
						y: content_top
						width: marker_width
						height: line_height
						text: marker
						color: text_color
						font_size: font_size
					},
				]
			},
		]
	}
	mut first := lines[0]
	align := css.cascaded_value_with_ua(element, css.property_id_from_string('text-align') or {
		return lines
	}, author_rules)
	new_width := first.width + advance
	new_x := aligned_line_x(content_x, content_width, new_width, align)
	text_shift := new_x + advance - first.x
	for index in 0 .. first.fragments.len {
		first.fragments[index].x += text_shift
	}
	first.fragments.prepend(TextFragment{
		x: new_x
		y: first.y
		width: marker_width
		height: first.height
		text: marker
		color: text_color
		font_size: font_size
	})
	first.x = new_x
	first.width = new_width
	lines[0] = first
	return lines
}

// Build the counter-style registry visible to the compatibility layout path. Ladybird gets these
// definitions from the document's counter-style cache; the V DOM boundary cannot own CSS values, so
// Layout performs the same ordered construction from the parsed UA and author rules here.
fn counter_style_registry(author_rules []&css.CSSRule) map[string]css.CounterStyle {
	mut registered := map[string]css.CounterStyle{}
	registered['decimal'] = css.CounterStyle.decimal()
	registered['disc'] = css.CounterStyle.disc()

	mut definitions := map[string]css.CounterStyleDefinition{}
	mut definition_order := []string{}
	for rule in css.user_agent_rules() {
		if counter_rule := rule.counter_style_rule_value() {
			if definition := css.CounterStyleDefinition.from_counter_style_rule(counter_rule, css.ComputationContext{}) {
				definitions[definition.name()] = definition
				definition_order << definition.name()
			}
		}
	}
	for rule in author_rules {
		if counter_rule := rule.counter_style_rule_value() {
			if definition := css.CounterStyleDefinition.from_counter_style_rule(counter_rule, css.ComputationContext{}) {
				if definition.name() !in definitions {
					definition_order << definition.name()
				}
				definitions[definition.name()] = definition
			}
		}
	}

	// Resolve extension chains in source order, then repeat so a forward reference sees the resolved
	// style on the following pass. CounterStyle's own fallback logic handles cycles and unknown names.
	for _ in 0 .. definition_order.len + 1 {
		for name in definition_order {
			registered[name] = css.CounterStyle.from_counter_style_definition(definitions[name], registered)
		}
	}
	return registered
}

// The marker string for a list item from its computed `list-style-type`. The geometric marker styles
// use their text equivalents in this compatibility display list; every counter style is formatted by
// the translated CSS CounterStyle algorithm, including its prefix, suffix, range, pad, and fallback.
fn list_marker_text(element &dom.Element, author_rules []&css.CSSRule) string {
	kind := css.cascaded_value_with_ua(element, css.property_id_from_string('list-style-type') or {
		return ''
	}, author_rules)
	if kind in ['disc', 'circle', 'square', 'none'] {
		return match kind {
			'disc' { '•' }
			'circle' { '◦' }
			'square' { '▪' }
			else { '' }
		}
		// none
	}
	// A quoted <string> is itself the marker string.
	if (kind.starts_with('"') && kind.ends_with('"')) || (kind.starts_with("'") && kind.ends_with("'")) {
		return kind[1..kind.len - 1]
	}
	// Counter styles: generate the representation and apply the style's prefix/suffix exactly as
	// ListItemMarkerBox::text() does upstream. Layout supplies its own visual gap, so trailing marker
	// whitespace is excluded from the measured text fragment.
	ordinal := list_item_ordinal(element, author_rules)
	registered := counter_style_registry(author_rules)
	resolved_name := match kind {
		'lower-latin' { 'lower-alpha' }
		'upper-latin' { 'upper-alpha' }
		else { kind }
	}
	if style := registered[resolved_name] {
		representation := css.generate_a_counter_representation(style, registered, i32(ordinal))
		return (style.prefix() + representation + style.suffix()).trim_space()
	}
	// Unknown counter styles fall back to decimal.
	return '${css.generate_a_counter_representation(none, registered, i32(ordinal))}.'
}

// The bijective base-26 alphabetic marker for `n` (1->a, 26->z, 27->aa, ...), in the given case.
// Falls back to the decimal for n < 1.
fn alphabetic_marker(n int, upper bool) string {
	if n < 1 {
		return n.str()
	}
	base := if upper { u8(`A`) } else { u8(`a`) }
	mut num := n
	mut out := []u8{}
	for num > 0 {
		num--
		out.prepend(base + u8(num % 26))
		num /= 26
	}
	return out.bytestr()
}

// The Roman-numeral marker for `n` (1->i, 4->iv, 9->ix, ...), in the given case. Falls back to the
// decimal for n outside 1..3999.
fn roman_marker(n int, upper bool) string {
	if n < 1 || n > 3999 {
		return n.str()
	}
	values := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	symbols := ['m', 'cm', 'd', 'cd', 'c', 'xc', 'l', 'xl', 'x', 'ix', 'v', 'iv', 'i']
	mut num := n
	mut out := ''
	for i, value in values {
		for num >= value {
			out += symbols[i]
			num -= value
		}
	}
	return if upper { out.to_upper() } else { out }
}

// The ordinal assigned to `element` by its list owner. An ordered list starts from its `start`
// attribute (or its item count when reversed), and an li `value` attribute resets the counter for
// that item and all items after it.
fn list_item_ordinal(element &dom.Element, author_rules []&css.CSSRule) int {
	parent := element.as_node().parent_element() or { return 1 }
	display_id := css.property_id_from_string('display') or { return 1 }
	mut item_count := 0
	for child in parent.as_node().children_as_vector() {
		if el := child.as_element() {
			if css.cascaded_value_with_ua(el, display_id, author_rules) == 'list-item' {
				item_count++
			}
		}
	}

	is_ordered := parent.local_name() == 'ol'
	is_reversed := is_ordered && parent.has_attribute('reversed')
	mut ordinal := if is_reversed { item_count } else { 1 }
	if is_ordered {
		if start := parent.get_attribute('start') {
			if parsed := parse_list_integer(start) {
				ordinal = parsed
			}
		}
	}
	step := if is_reversed { -1 } else { 1 }
	for child in parent.as_node().children_as_vector() {
		if el := child.as_element() {
			if css.cascaded_value_with_ua(el, display_id, author_rules) == 'list-item' {
				if el.local_name() == 'li' {
					if value := el.get_attribute('value') {
						if parsed := parse_list_integer(value) {
							ordinal = parsed
						}
					}
				}
				if el.as_node().is_same_node(element.as_node()) {
					return ordinal
				}
				ordinal += step
			}
		}
	}
	return 1
}

// Parse the signed decimal prefix accepted by HTML integer-valued attributes. Whitespace and a
// leading sign are allowed; a value without any digits is invalid.
fn parse_list_integer(value string) ?int {
	mut index := 0
	for index < value.len && value[index] in [` `, `\t`, `\n`, `\r`, `\f`] {
		index++
	}
	if index >= value.len {
		return none
	}
	mut sign := 1
	if value[index] == `-` {
		sign = -1
		index++
	} else if value[index] == `+` {
		index++
	}
	if index >= value.len || value[index] < `0` || value[index] > `9` {
		return none
	}
	mut result := 0
	for index < value.len && value[index] >= `0` && value[index] <= `9` {
		result = result * 10 + int(value[index] - `0`)
		index++
	}
	return sign * result
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
				.begin_opacity {
					content << '<g opacity="${fmt_px(operation.opacity)}">'
				}
				.end_opacity {
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

pub fn resolved_background_gradient_tiles(command PaintCommand) []painting.Rect {
	if !command.gradient_background_layer {
		return [painting.Rect{command.x, command.y, command.width, command.height}]
	}
	layer := command.image_computed_layer or { return []painting.Rect{} }
	resolved := painting.resolve_background_layer_without_intrinsic(painting.BackgroundLayerWithoutIntrinsicResolutionInput{
		layer: layer
		image_id: 'gradient'
		background_positioning_area: painting.Rect{command.x, command.y, command.width, command.height}
		resolution_context: command.image_resolution_context
	}) or { return []painting.Rect{} }
	return painting.background_tiles_limited(resolved, painting.Point{command.image_scroll_offset_x, command.image_scroll_offset_y}, painting.Point{command.image_viewport_offset_x, command.image_viewport_offset_y}, painting.Rect{command.image_clip_x, command.image_clip_y, command.image_clip_width, command.image_clip_height}, 4096)
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
			margin := command.blur * 2.0
			left := math.min(command.x, command.shadow_content_x) - margin
			top := math.min(command.y, command.shadow_content_y) - margin
			right := math.max(command.x + command.width, command.shadow_content_x + command.shadow_content_width) + margin
			bottom := math.max(command.y + command.height, command.shadow_content_y + command.shadow_content_height) + margin
			clip_id := 'outer-shadow-clip${defs.len}'
			outside_path := rounded_rect_svg_path(left, top, right - left, bottom - top, BoxRadii{})
			content_path := rounded_rect_svg_path(command.shadow_content_x, command.shadow_content_y, command.shadow_content_width, command.shadow_content_height, command.shadow_content_radii)
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
			content_path := rounded_rect_svg_path(command.shadow_content_x, command.shadow_content_y, command.shadow_content_width, command.shadow_content_height, command.shadow_content_radii)
			clip_path := rounded_rect_svg_path(command.shadow_content_x, command.shadow_content_y, command.shadow_content_width, command.shadow_content_height, command.shadow_clip_radii)
			content_clip_id := 'inner-shadow-content${defs.len}'
			defs << '<clipPath id="${content_clip_id}" clipPathUnits="userSpaceOnUse"><path d="${content_path}"/></clipPath>'
			scoped_clip_id := 'inner-shadow-scoped${defs.len}'
			defs << '<clipPath id="${scoped_clip_id}" clipPathUnits="userSpaceOnUse"><path d="${clip_path}"/></clipPath>'
			mut filter := ''
			if command.blur > 0 {
				filter_id := 'inner-shadow-blur${defs.len}'
				margin := command.blur * 2.0
				defs << '<filter id="${filter_id}" filterUnits="userSpaceOnUse" x="${fmt_px(command.shadow_content_x - margin)}" y="${fmt_px(command.shadow_content_y - margin)}" width="${fmt_px(command.shadow_content_width + margin * 2.0)}" height="${fmt_px(command.shadow_content_height + margin * 2.0)}"><feGaussianBlur stdDeviation="${fmt_px(f64(int(command.blur) / 2))}"/></filter>'
				filter = ' filter="url(#${filter_id})"'
			}
			outer_path := rounded_rect_svg_path(command.x, command.y, command.width, command.height, command.corner_radii)
			inner_path := if command.shadow_inner_width > 0 && command.shadow_inner_height > 0 {
				rounded_rect_svg_path(command.shadow_inner_x, command.shadow_inner_y, command.shadow_inner_width, command.shadow_inner_height, command.shadow_inner_radii)
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
					&& !box_radii_are_zero(command.image_clip_radii) {
					'<path d="${rounded_rect_svg_path(command.image_clip_x, command.image_clip_y, command.image_clip_width, command.image_clip_height, command.image_clip_radii)}"/>'
				} else if command.gradient_background_layer {
					'<rect x="${fmt_px(command.image_clip_x)}" y="${fmt_px(command.image_clip_y)}" width="${fmt_px(command.image_clip_width)}" height="${fmt_px(command.image_clip_height)}"/>'
				} else if rounded_polygon_points.len > 0 {
					'<polygon points="${rounded_polygon_points.join(' ')}"/>'
				} else {
					'<rect x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}"${corner}/>'
				}
				blend := if command.background_blend_mode == .normal {
					''
				} else {
					' style="mix-blend-mode:${background_blend_mode_css(command.background_blend_mode)}"'
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
			clip_id := 'imageclip${defs.len}'
			clip_shape := if !box_radii_are_zero(command.image_clip_radii) {
				'<path d="${rounded_rect_svg_path(command.image_clip_x, command.image_clip_y, command.image_clip_width, command.image_clip_height, command.image_clip_radii)}"/>'
			} else {
				'<rect x="${fmt_px(command.image_clip_x)}" y="${fmt_px(command.image_clip_y)}" width="${fmt_px(command.image_clip_width)}" height="${fmt_px(command.image_clip_height)}"/>'
			}
			defs << '<clipPath id="${clip_id}">${clip_shape}</clipPath>'
			aspect := if command.image_size.trim_space().to_lower() == 'cover' {
				'xMidYMid slice'
			} else if command.image_size.trim_space().to_lower() == 'contain' {
				'xMidYMid meet'
			} else {
				'xMinYMin meet'
			}
			blend := if command.background_blend_mode == .normal {
				''
			} else {
				' style="mix-blend-mode:${background_blend_mode_css(command.background_blend_mode)}"'
			}
			body << '<image href="${escape_xml(command.image_url)}" x="${fmt_px(command.x)}" y="${fmt_px(command.y)}" width="${fmt_px(command.width)}" height="${fmt_px(command.height)}" preserveAspectRatio="${aspect}" clip-path="url(#${clip_id})" opacity="${fmt_px(command.opacity)}"${blend} data-background-repeat="${escape_xml(command.image_repeat_x)} ${escape_xml(command.image_repeat_y)}" data-background-position="${escape_xml(command.image_position_x)} ${escape_xml(command.image_position_y)}"/>'
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
			path_matrix := normalized_affine(command.path_transform)
			mut fill := if command.color.len > 0 { command.color } else { 'none' }
			mut stroke := if command.stroke_color.len > 0 { command.stroke_color } else { 'none' }
			if gradient := command.fill_linear_gradient {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_linear_gradient_definition(id, gradient)
				fill = 'url(#${id})'
			} else if gradient := command.fill_radial_gradient {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_radial_gradient_definition(id, gradient)
				fill = 'url(#${id})'
			} else if pattern := command.fill_pattern {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_pattern_definition(id, pattern, 0)
				fill = 'url(#${id})'
			}
			if gradient := command.stroke_linear_gradient {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_linear_gradient_definition(id, gradient)
				stroke = 'url(#${id})'
			} else if gradient := command.stroke_radial_gradient {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_radial_gradient_definition(id, gradient)
				stroke = 'url(#${id})'
			} else if pattern := command.stroke_pattern {
				id := 'svg-paint${defs.len}'
				defs << retained_svg_pattern_definition(id, pattern, 0)
				stroke = 'url(#${id})'
			}
			fill_rule := if command.fill_even_odd { 'evenodd' } else { 'nonzero' }
			paint_order := if command.stroke_first { ' paint-order="stroke fill"' } else { '' }
			linecap := match command.stroke_linecap {
				1 { 'round' }
				2 { 'square' }
				else { 'butt' }
			}
			linejoin := match command.stroke_linejoin {
				1 { 'round' }
				2 { 'bevel' }
				else { 'miter' }
			}
			body << '<path d="${escape_xml(command.path)}" transform="matrix(${fmt_px(path_matrix[0])} ${fmt_px(path_matrix[1])} ${fmt_px(path_matrix[2])} ${fmt_px(path_matrix[3])} ${fmt_px(path_matrix[4])} ${fmt_px(path_matrix[5])})" fill="${fill}" fill-rule="${fill_rule}" fill-opacity="${fmt_px(command.opacity * command.fill_opacity)}" stroke="${stroke}" stroke-opacity="${fmt_px(command.opacity * command.stroke_opacity)}" stroke-width="${fmt_px(command.stroke_width)}" stroke-linecap="${linecap}" stroke-linejoin="${linejoin}" stroke-miterlimit="${fmt_px(command.stroke_miterlimit)}"${paint_order}/>'
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

// Stable insertion sort of `items` by z-index (preserving tree order among equal z-indexes).
fn stable_sort_by_z(items []BlockBox) []BlockBox {
	mut result := items.clone()
	for i := 1; i < result.len; i++ {
		mut j := i
		for j > 0 && result[j - 1].z_index > result[j].z_index {
			result[j - 1], result[j] = result[j], result[j - 1]
			j--
		}
	}
	return result
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

fn affine_is_identity(matrix [6]f64) bool {
	return normalized_affine(matrix) == affine_identity()
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

fn affine_in_translated_coordinate_frame(matrix [6]f64, dx f64, dy f64) [6]f64 {
	if affine_is_compact_identity(matrix) {
		return matrix
	}
	return multiply_affine(translated_affine(dx, dy), multiply_affine(matrix, translated_affine(-dx, -dy)))
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
	transformed.mask_clip = nested_viewport_clip(command.mask_clip, ancestor)
	return transformed
}

fn apply_ancestor_affine(box BlockBox, ancestor [6]f64) BlockBox {
	if affine_is_compact_identity(ancestor) {
		return box
	}
	mut transformed := box
	transformed.paint_transform = multiply_affine(ancestor, box.paint_transform)
	transformed.children = box.children.map(apply_ancestor_affine(it, ancestor))
	return transformed
}

// Return a copy of `box` with its own geometry, every descendant's, and its line boxes shifted by
// (`dx`, `dy`). Used to reposition a subtree after margin collapsing / positioning decides where its
// border box actually lands.
fn translate_block(box BlockBox, dx f64, dy f64) BlockBox {
	mut moved := box
	moved.x += dx
	moved.y += dy
	moved.paint_transform = affine_in_translated_coordinate_frame(box.paint_transform, dx, dy)
	moved.absolute_static_positions = translate_static_positions(box.absolute_static_positions, dx, dy)
	moved.fixed_static_positions = translate_static_positions(box.fixed_static_positions, dx, dy)
	moved.children = box.children.map(translate_block(it, dx, dy))
	moved.lines = box.lines.map(translate_line(it, dx, dy))
	return moved
}

fn translate_static_positions(positions map[i64]StaticPosition, dx f64, dy f64) map[i64]StaticPosition {
	mut translated := map[i64]StaticPosition{}
	for node_id, position in positions {
		translated[node_id] = StaticPosition{
			x: position.x + dx
			y: position.y + dy
			width: position.width
			height: position.height
			horizontal_alignment: position.horizontal_alignment
			vertical_alignment: position.vertical_alignment
			has_containing_block_rect: position.has_containing_block_rect
			containing_block_x: position.containing_block_x + dx
			containing_block_y: position.containing_block_y + dy
			containing_block_width: position.containing_block_width
			containing_block_height: position.containing_block_height
		}
	}
	return translated
}

fn merge_static_positions(mut target map[i64]StaticPosition, source map[i64]StaticPosition) {
	for node_id, position in source {
		target[node_id] = position
	}
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

// Collapse a set of adjoining vertical margins into one, per CSS 2.1 §8.3.1: the largest positive
// margin plus the most negative margin (so max positive when all positive; their difference when
// mixed; the most negative when all negative).
fn collapse_margins(margins []f64) f64 {
	mut max_positive := 0.0
	mut min_negative := 0.0
	for m in margins {
		if m > max_positive {
			max_positive = m
		}
		if m < min_negative {
			min_negative = m
		}
	}
	return max_positive + min_negative
}

// A length/percentage/calc() property resolved to px, or 0 when it's `auto`/absent/other. Percentages
// (and `%` inside a calc) resolve against `basis` (for margins and padding, the containing width).
//
// When the physical property is absent (no length/percentage/calc resolves), its CSS *logical*
// equivalent is tried (e.g. `padding-left` <- `padding-inline-start`), so the UA sheet's logical
// margins/padding (`p { margin-block: 1em }`, `ul { padding-inline-start: 40px }`, ...) take effect.
// This assumes a left-to-right, horizontal-tb writing mode (the only mode this engine supports).
fn used_length_or_zero(element &dom.Element, property_name string, basis f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string(property_name) or { return 0 }
	// If the physical property was never declared, defer to its CSS logical equivalent (once; a logical
	// property has no further mapping). The cascade always yields the initial value for an unset
	// property, so "declared?" must be asked explicitly rather than inferred from the resolved value.
	if !css.is_property_specified(element, id, author_rules) {
		if logical := logical_equivalent(element, property_name, author_rules) {
			return used_length_or_zero(element, logical, basis, author_rules)
		}
	}
	if px := css.computed_length_px(element, id, author_rules) {
		return px
	}
	if pct := css.computed_percentage(element, id, author_rules) {
		return basis * pct / 100.0
	}
	if calc := css.computed_calc_px(element, id, basis, author_rules) {
		return calc
	}
	return 0
}

// The CSS logical margin/padding property that maps to `physical` for the element's writing mode and
// direction, or none when `physical` has no logical counterpart.
fn logical_equivalent(element &dom.Element, physical string, author_rules []&css.CSSRule) ?string {
	separator := physical.index('-') or { return none }
	prefix := physical[..separator]
	if prefix !in ['margin', 'padding'] {
		return none
	}
	physical_side := physical[separator + 1..]
	writing_mode := css.cascaded_value_with_ua(element, css.property_id_from_string('writing-mode') or {
		return none
	}, author_rules)
	direction := css.cascaded_value_with_ua(element, css.property_id_from_string('direction') or {
		return none
	}, author_rules)
	mut inline_start := 'left'
	mut inline_end := 'right'
	mut block_start := 'top'
	mut block_end := 'bottom'
	if writing_mode in ['vertical-rl', 'sideways-rl'] {
		inline_start = 'top'
		inline_end = 'bottom'
		block_start = 'right'
		block_end = 'left'
	} else if writing_mode in ['vertical-lr', 'sideways-lr'] {
		inline_start = 'top'
		inline_end = 'bottom'
		block_start = 'left'
		block_end = 'right'
	}
	if direction == 'rtl' {
		inline_start, inline_end = inline_end, inline_start
	}
	return if physical_side == inline_start {
		'${prefix}-inline-start'
	} else if physical_side == inline_end {
		'${prefix}-inline-end'
	} else if physical_side == block_start {
		'${prefix}-block-start'
	} else if physical_side == block_end {
		'${prefix}-block-end'
	} else {
		none
	}
}

// The used border width for one side. Per spec the computed border width is 0 when the corresponding
// border-style is `none`/`hidden`; otherwise it's the border-width length, or the thin/medium/thick
// keyword scale (1/3/5 px).
fn used_border(element &dom.Element, side string, author_rules []&css.CSSRule) f64 {
	style_id := css.property_id_from_string('border-${side}-style') or { return 0 }
	style := css.cascaded_value_with_ua(element, style_id, author_rules)
	if style == 'none' || style == 'hidden' {
		return 0
	}
	width_id := css.property_id_from_string('border-${side}-width') or { return 0 }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	return match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'thin' { 1.0 }
		'thick' { 5.0 }
		else { 3.0 }
	}
	// 'medium' (the initial value) and any unresolved keyword
}

// Resolve each physical border color independently. Each property's initial value is
// `currentColor`, so falling back to the element's resolved text color preserves that behavior if
// a malformed value reaches this compatibility transport.
fn resolved_border_colors(element &dom.Element, fallback css.Color, author_rules []&css.CSSRule) BoxColors {
	return BoxColors{
		top: css.computed_color(element, .border_top_color, author_rules) or { fallback }
		right: css.computed_color(element, .border_right_color, author_rules) or { fallback }
		bottom: css.computed_color(element, .border_bottom_color, author_rules) or { fallback }
		left: css.computed_color(element, .border_left_color, author_rules) or { fallback }
	}
}

fn border_line_style_from_string(value string) painting.LineStyle {
	return match value.to_lower() {
		'none' { .none }
		'hidden' { .hidden }
		'dotted' { .dotted }
		'dashed' { .dashed }
		'double' { .double }
		'groove' { .groove }
		'ridge' { .ridge }
		'inset' { .inset }
		'outset' { .outset }
		else { .solid }
	}
}

fn resolved_border_styles(element &dom.Element, author_rules []&css.CSSRule) BoxBorderStyles {
	return BoxBorderStyles{
		top: border_line_style_from_string(css.cascaded_value_with_ua(element, .border_top_style, author_rules))
		right: border_line_style_from_string(css.cascaded_value_with_ua(element, .border_right_style, author_rules))
		bottom: border_line_style_from_string(css.cascaded_value_with_ua(element, .border_bottom_style, author_rules))
		left: border_line_style_from_string(css.cascaded_value_with_ua(element, .border_left_style, author_rules))
	}
}

// Older callers construct renderer boxes with only `border_color`. Treat an entirely empty color
// set as that legacy uniform color; translated layout paths always populate all four colors.
fn effective_border_colors(colors BoxColors, fallback css.Color) BoxColors {
	if colors.top.a == 0 && colors.right.a == 0 && colors.bottom.a == 0 && colors.left.a == 0 && fallback.a > 0 {
		return BoxColors{fallback, fallback, fallback, fallback}
	}
	return colors
}

fn border_colors_are_uniform(colors BoxColors) bool {
	return colors.top == colors.right && colors.top == colors.bottom && colors.top == colors.left
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
	height f64, opacity f64) {
	left := int(math.round(x))
	top := int(math.round(y))
	rect := painting.IntRect{
		x: left
		y: top
		width: int(math.round(x + width)) - left
		height: int(math.round(y + height)) - top
	}
	for display_command in painting.paint_all_borders(rect, painting_radii_from_transport(radii), painting_borders_from_transport(border, colors, styles)) {
		append_painting_display_command(mut commands, display_command, opacity)
	}
}

fn inflated_outline_corner(radius CornerRadius, horizontal f64, vertical f64) CornerRadius {
	return CornerRadius{
		x: if radius.x == 0 { 0.0 } else { math.max(0.0, radius.x + horizontal) }
		y: if radius.y == 0 { 0.0 } else { math.max(0.0, radius.y + vertical) }
	}
}

// Direct compatibility lowering of PaintableBox.cpp's outline phase. CSS resolves
// `outline-style:auto` before this point; BorderPainting owns all line-style dispatch.
fn append_translated_outline_commands(mut commands []PaintCommand, outline_width f64,
	outline_offset f64, outline_color css.Color, outline_style painting.LineStyle,
	border_radii BoxRadii, border_x f64, border_y f64, border_width f64, border_height f64,
	opacity f64) {
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
	for display_command in painting.paint_all_borders(outline_rect, painting_radii_from_transport(outline_radii), outline_borders.to_device_pixels(converter)) {
		append_painting_display_command(mut commands, display_command, opacity)
	}
}

fn append_square_border_commands(mut commands []PaintCommand, border BoxEdges, colors BoxColors,
	x f64, y f64, width f64, height f64, opacity f64) {
	append_translated_border_commands(mut commands, border, colors, solid_box_border_styles(), BoxRadii{}, x, y, width, height, opacity)
}

// The used outline width (px): 0 when `outline-style` is `none`/`hidden`; otherwise the outline-width
// length or the thin/medium/thick keyword scale (1/3/5 px), like a border.
fn used_outline_width(element &dom.Element, author_rules []&css.CSSRule) f64 {
	style_id := css.property_id_from_string('outline-style') or { return 0 }
	style := css.cascaded_value_with_ua(element, style_id, author_rules)
	if style == 'none' || style == 'hidden' {
		return 0
	}
	if style == 'auto' {
		return 2
	}
	width_id := css.property_id_from_string('outline-width') or { return 0 }
	if px := css.computed_length_px(element, width_id, author_rules) {
		return px
	}
	return match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'thin' { 1.0 }
		'thick' { 5.0 }
		else { 3.0 }
	}
	// 'medium' (the initial value)
}

// Whether a computed `display` value generates a block-level box in this engine. `none` and
// `contents` generate no box; inline-level values (inline / inline-block / inline-*) are skipped
// because there is no inline formatting context yet. Everything else (block, list-item, flow-root,
// and flex/grid/table, which are block-level in their parent's flow) is laid out as a block.
fn is_block_level_display(display string) bool {
	if display == 'none' || display == 'contents' {
		return false
	}
	return !display.starts_with('inline')
}

// The in-flow block-level element children of `node`, in document order. Text and other node types
// are skipped (no inline formatting context yet), as are elements whose computed `display` is `none`
// or inline-level, and absolutely positioned elements (out of flow — laid out separately against
// their containing block). So `<head>`/`<script>`/`<style>`, inline, and abspos elements don't flow.
fn block_child_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	mut elements := []&dom.Element{}
	collect_block_child_elements(node, author_rules, mut elements)
	return elements
}

fn collect_block_child_elements(node &dom.Node, author_rules []&css.CSSRule, mut elements []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		if element := child.as_element() {
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if display == 'none' {
				continue
			}
			if display == 'contents' {
				collect_block_child_elements(element.as_node(), author_rules, mut elements)
				continue
			}
			if is_absolutely_positioned(position_value(element, author_rules)) {
				// out of flow
				continue
			}
			if is_floating(element, author_rules) {
				// out of normal flow (placed separately at the container edge)
				continue
			}
			if is_block_level_display(display) {
				elements << element
			}
		}
	}
}

// Block-formatting-context participants in tree order, including floats. This is distinct from
// `block_child_elements`, whose callers explicitly want only in-flow blocks.
fn block_flow_child_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	mut elements := []&dom.Element{}
	collect_block_flow_child_elements(node, author_rules, mut elements)
	return elements
}

fn collect_block_flow_child_elements(node &dom.Node, author_rules []&css.CSSRule, mut elements []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		element := child.as_element() or { continue }
		display := css.cascaded_value_with_ua(element, display_id, author_rules)
		if display == 'none' {
			continue
		}
		if display == 'contents' {
			collect_block_flow_child_elements(element.as_node(), author_rules, mut elements)
			continue
		}
		if is_absolutely_positioned(position_value(element, author_rules)) {
			continue
		}
		if is_floating(element, author_rules) || is_block_level_display(display) {
			elements << element
		}
	}
}

// The BFC visits out-of-flow boxes at their tree-order opportunity even though they do not become
// flow children. Ladybird uses that visit to retain the current block cursor as their static
// position. Keep them in this traversal instead of recovering a position after flow layout.
fn block_flow_participants(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	mut elements := []&dom.Element{}
	collect_block_flow_participants(node, author_rules, mut elements)
	return elements
}

fn collect_block_flow_participants(node &dom.Node, author_rules []&css.CSSRule, mut elements []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		element := child.as_element() or { continue }
		display := css.cascaded_value_with_ua(element, display_id, author_rules)
		if display == 'none' {
			continue
		}
		if display == 'contents' {
			collect_block_flow_participants(element.as_node(), author_rules, mut elements)
			continue
		}
		if is_absolutely_positioned(position_value(element, author_rules))
			|| is_floating(element, author_rules) || is_block_level_display(display) {
			elements << element
		}
	}
}

// Whether `element` is a row flex container: `display: flex` with a `row` (or default) direction.
fn is_flex_row(element &dom.Element, author_rules []&css.CSSRule) bool {
	display_id := css.property_id_from_string('display') or { return false }
	if css.cascaded_value_with_ua(element, display_id, author_rules) != 'flex' {
		return false
	}
	dir_id := css.property_id_from_string('flex-direction') or { return true }
	dir := css.cascaded_value_with_ua(element, dir_id, author_rules)
	return dir == 'row' || dir == '' || dir == 'row-reverse'
}

// Whether `element` is a column flex container: `display: flex` with a `column` direction.
fn is_flex_column(element &dom.Element, author_rules []&css.CSSRule) bool {
	display_id := css.property_id_from_string('display') or { return false }
	if css.cascaded_value_with_ua(element, display_id, author_rules) != 'flex' {
		return false
	}
	dir_id := css.property_id_from_string('flex-direction') or { return false }
	dir := css.cascaded_value_with_ua(element, dir_id, author_rules)
	return dir == 'column' || dir == 'column-reverse'
}

fn flex_direction_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('flex-direction') or { return 'row' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' { 'row' } else { value }
}

fn flex_main_axis_is_reversed(element &dom.Element, author_rules []&css.CSSRule) bool {
	return flex_direction_value(element, author_rules).ends_with('-reverse')
}

// Whether `element` is a table container (`display: table`).
fn is_table(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('display') or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'table'
}

// The table rows (`display: table-row`) under `element`, in document order, flattening the row groups
// (`table-row-group`/`table-header-group`/`table-footer-group`, i.e. tbody/thead/tfoot).
fn table_rows(element &dom.Element, author_rules []&css.CSSRule) []&dom.Element {
	mut rows := []&dom.Element{}
	collect_table_rows(element.as_node(), author_rules, mut rows)
	return rows
}

fn collect_table_rows(node &dom.Node, author_rules []&css.CSSRule, mut rows []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		if el := child.as_element() {
			display := css.cascaded_value_with_ua(el, display_id, author_rules)
			if display == 'table-row' {
				rows << el
			} else if display in ['table-row-group', 'table-header-group', 'table-footer-group'] {
				collect_table_rows(el.as_node(), author_rules, mut rows) // flatten the group
			}
		}
	}
}

// The cells (`display: table-cell`) of a table row, in document order.
fn table_cells(row &dom.Element, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut cells := []&dom.Element{}
	for child in row.as_node().children_as_vector() {
		if el := child.as_element() {
			if css.cascaded_value_with_ua(el, display_id, author_rules) == 'table-cell' {
				cells << el
			}
		}
	}
	return cells
}

fn table_captions(element &dom.Element, side string, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	caption_side_id := css.property_id_from_string('caption-side') or { return []&dom.Element{} }
	mut captions := []&dom.Element{}
	for child_node in element.as_node().children_as_vector() {
		child := child_node.as_element() or { continue }
		if css.cascaded_value_with_ua(child, display_id, author_rules) != 'table-caption' {
			continue
		}
		value := css.cascaded_value_with_ua(child, caption_side_id, author_rules)
		resolved_side := if value == 'bottom' { 'bottom' } else { 'top' }
		if resolved_side == side {
			captions << child
		}
	}
	return captions
}

fn table_column_span(element &dom.Element) int {
	raw := element.get_attribute('span') or { return 1 }
	span := raw.int()
	return if span > 0 { span } else { 1 }
}

fn table_column_width(element &dom.Element, table_width f64, author_rules []&css.CSSRule) ?f64 {
	width_id := css.property_id_from_string('width') or { return none }
	if width := css.computed_length_px(element, width_id, author_rules) {
		return non_negative(width)
	}
	if percentage := css.computed_percentage(element, width_id, author_rules) {
		return non_negative(table_width * percentage / 100.0)
	}
	if attribute := element.get_attribute('width') {
		if attribute.ends_with('%') {
			return non_negative(table_width * attribute.trim_string_right('%').f64() / 100.0)
		}
		return non_negative(attribute.trim_string_right('px').f64())
	}
	return none
}

// Flatten <col> and <colgroup> inputs into one width constraint per represented column. A group's
// own width is divided across its span when it has no child columns.
fn table_column_constraints(table &dom.Element, table_width f64, author_rules []&css.CSSRule) []f64 {
	display_id := css.property_id_from_string('display') or { return []f64{} }
	mut constraints := []f64{}
	for child_node in table.as_node().children_as_vector() {
		child := child_node.as_element() or { continue }
		display := css.cascaded_value_with_ua(child, display_id, author_rules)
		if display == 'table-column' {
			width := table_column_width(child, table_width, author_rules) or { -1.0 }
			for _ in 0 .. table_column_span(child) {
				constraints << width
			}
		} else if display == 'table-column-group' {
			mut child_columns := []&dom.Element{}
			for column_node in child.as_node().children_as_vector() {
				column := column_node.as_element() or { continue }
				if css.cascaded_value_with_ua(column, display_id, author_rules) == 'table-column' {
					child_columns << column
				}
			}
			if child_columns.len > 0 {
				for column in child_columns {
					width := table_column_width(column, table_width, author_rules) or { -1.0 }
					for _ in 0 .. table_column_span(column) {
						constraints << width
					}
				}
			} else {
				span := table_column_span(child)
				group_width := table_column_width(child, table_width, author_rules)
				per_column := if width := group_width { width / f64(span) } else { -1.0 }
				for _ in 0 .. span {
					constraints << per_column
				}
			}
		}
	}
	return constraints
}

struct LegacyTableCellPlacement {
	element  &dom.Element = unsafe { nil }
	row      int
	column   int
	row_span int = 1
	col_span int = 1
}

fn positive_table_span(cell &dom.Element, attribute string) int {
	raw_value := cell.get_attribute(attribute) or { return 1 }
	value := raw_value.int()
	return if value > 0 { value } else { 1 }
}

fn legacy_table_cell_placements(rows []&dom.Element, author_rules []&css.CSSRule) ([]LegacyTableCellPlacement, int, int) {
	mut placements := []LegacyTableCellPlacement{}
	mut occupied_until_row := []int{}
	mut column_count := 0
	mut row_count := rows.len
	for row_index, row in rows {
		mut column := 0
		for cell in table_cells(row, author_rules) {
			for column < occupied_until_row.len && occupied_until_row[column] > row_index {
				column++
			}
			col_span := positive_table_span(cell, 'colspan')
			row_span := positive_table_span(cell, 'rowspan')
			for occupied_until_row.len < column + col_span {
				occupied_until_row << 0
			}
			// If a span intersects a row-spanning cell, advance until the whole requested range is free.
			for {
				mut range_is_free := true
				for candidate in column .. column + col_span {
					if candidate < occupied_until_row.len && occupied_until_row[candidate] > row_index {
						range_is_free = false
						break
					}
				}
				if range_is_free {
					break
				}
				column++
				for occupied_until_row.len < column + col_span {
					occupied_until_row << 0
				}
			}
			placements << LegacyTableCellPlacement{
				element: cell
				row: row_index
				column: column
				row_span: row_span
				col_span: col_span
			}
			for occupied_column in column .. column + col_span {
				occupied_until_row[occupied_column] = row_index + row_span
			}
			column += col_span
			if column > column_count {
				column_count = column
			}
			if row_index + row_span > row_count {
				row_count = row_index + row_span
			}
		}
	}
	return placements, column_count, row_count
}

fn legacy_table_border_spacing(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) (f64, f64) {
	if css.cascaded_value_with_ua(element, .border_collapse, author_rules) == 'collapse' {
		return 0.0, 0.0
	}
	tokens := split_top_level(css.cascaded_value_with_ua(element, .border_spacing, author_rules), ` `)
	if tokens.len == 0 {
		return 0.0, 0.0
	}
	horizontal := non_negative(resolve_length_token(element, tokens[0], containing_width, author_rules))
	vertical := if tokens.len > 1 {
		non_negative(resolve_length_token(element, tokens[1], containing_width, author_rules))
	} else {
		horizontal
	}
	return horizontal, vertical
}

fn legacy_table_intrinsic_width(element &dom.Element, containing_width f64, minimum bool, author_rules []&css.CSSRule) f64 {
	rows := table_rows(element, author_rules)
	placements, column_count, _ := legacy_table_cell_placements(rows, author_rules)
	if column_count == 0 {
		return 0
	}
	mut columns := []f64{len: column_count}
	for placement in placements {
		contribution := child_intrinsic_content_width(placement.element, author_rules, minimum) + horizontal_edges(placement.element, containing_width, author_rules)
		share := contribution / f64(placement.col_span)
		for column in placement.column .. placement.column + placement.col_span {
			if share > columns[column] {
				columns[column] = share
			}
		}
	}
	horizontal_spacing, _ := legacy_table_border_spacing(element, containing_width, author_rules)
	mut result := horizontal_spacing * f64(column_count + 1)
	for width in columns {
		result += width
	}
	return result
}

// Whether `element` is a grid container (`display: grid`).
fn is_grid(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('display') or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'grid'
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

fn grid_span_from_line(value string) ?int {
	if !value.starts_with('span ') {
		return none
	}
	for token in value['span '.len..].fields() {
		span := token.int()
		if span > 0 {
			return span
		}
	}
	return 1
}

fn resolve_explicit_grid_line(value string, track_count int) ?int {
	line := value.trim_space().int()
	if line > 0 {
		return line - 1
	}
	if line < 0 {
		return track_count + line + 1
	}
	return none
}

fn resolve_grid_line(value string, track_count int, line_names map[string][]int) ?int {
	if line := resolve_explicit_grid_line(value, track_count) {
		return line
	}
	fields := value.trim_space().fields()
	if fields.len == 0 || fields[0] == 'auto' || fields[0] == 'span' {
		return none
	}
	name := fields[0]
	if name !in line_names || line_names[name].len == 0 {
		return none
	}
	mut occurrence := 1
	if fields.len > 1 && fields[1].int() > 0 {
		occurrence = fields[1].int()
	}
	indices := line_names[name]
	selected_index := if occurrence <= indices.len {
		occurrence - 1
	} else {
		indices.len - 1
	}
	return indices[selected_index]
}

// Resolve an item's explicit integer or named grid lines and span. In-flow placement clamps the
// result to real tracks; abspos placement also preserves the special line after the final track,
// whose area is formed with the container's end padding edge.
fn grid_axis_placement(element &dom.Element, start_property string, end_property string, track_count int, line_names map[string][]int, clamp_to_tracks bool, author_rules []&css.CSSRule) LegacyGridAxisPlacement {
	start_id := css.property_id_from_string(start_property) or { return LegacyGridAxisPlacement{} }
	end_id := css.property_id_from_string(end_property) or { return LegacyGridAxisPlacement{} }
	start := css.cascaded_value_with_ua(element, start_id, author_rules)
	end := css.cascaded_value_with_ua(element, end_id, author_rules)
	start_span := grid_span_from_line(start)
	end_span := grid_span_from_line(end)
	start_line := resolve_grid_line(start, track_count, line_names)
	end_line := resolve_grid_line(end, track_count, line_names)
	mut span := end_span or { start_span or { 1 } }
	mut resolved_start := -1
	if first := start_line {
		resolved_start = first
		if last := end_line {
			if last != first {
				resolved_start = if first < last { first } else { last }
				span = if first < last { last - first } else { first - last }
			}
		}
	} else if last := end_line {
		resolved_start = last - span
	}
	if clamp_to_tracks && span > track_count {
		span = track_count
	}
	if clamp_to_tracks && resolved_start >= 0 {
		if resolved_start + span > track_count {
			resolved_start = track_count - span
		}
	}
	return LegacyGridAxisPlacement{
		start: resolved_start
		span: span
	}
}

fn grid_column_placement(element &dom.Element, track_count int, line_names map[string][]int, author_rules []&css.CSSRule) LegacyGridAxisPlacement {
	return grid_axis_placement(element, 'grid-column-start', 'grid-column-end', track_count, line_names, true, author_rules)
}

fn grid_abspos_column_placement(element &dom.Element, track_count int, line_names map[string][]int, author_rules []&css.CSSRule) LegacyGridAxisPlacement {
	return grid_axis_placement(element, 'grid-column-start', 'grid-column-end', track_count, line_names, false, author_rules)
}

fn grid_abspos_row_placement(element &dom.Element, track_count int, line_names map[string][]int, author_rules []&css.CSSRule) LegacyGridAxisPlacement {
	return grid_axis_placement(element, 'grid-row-start', 'grid-row-end', track_count, line_names, false, author_rules)
}

fn grid_repeat_minimum(token string, element &dom.Element, containing_width f64, author_rules []&css.CSSRule) f64 {
	trimmed := token.trim_space()
	if trimmed.starts_with('minmax(') && trimmed.ends_with(')') {
		parts := split_top_level(trimmed['minmax('.len..trimmed.len - 1], `,`)
		if parts.len > 0 {
			return grid_repeat_minimum(parts[0], element, containing_width, author_rules)
		}
	}
	if trimmed.starts_with('fit-content(') && trimmed.ends_with(')') {
		return resolve_length_token(element, trimmed['fit-content('.len..trimmed.len - 1], containing_width, author_rules)
	}
	if trimmed in ['auto', 'min-content', 'max-content'] || trimmed.ends_with('fr') {
		return 1.0
	}
	return resolve_length_token(element, trimmed, containing_width, author_rules)
}

fn expanded_grid_track_tokens(value string, element &dom.Element, containing_width f64, gap f64, author_rules []&css.CSSRule) []string {
	mut tokens := []string{}
	item_count := flex_item_elements(element.as_node(), author_rules).len
	for token in split_top_level(value.trim_space(), ` `) {
		if !token.starts_with('repeat(') || !token.ends_with(')') {
			tokens << token
			continue
		}
		parts := split_top_level(token['repeat('.len..token.len - 1], `,`)
		if parts.len < 2 {
			continue
		}
		group := split_top_level(parts[1], ` `)
		track_group := group.filter(!it.starts_with('['))
		mut count := parts[0].trim_space().int()
		if parts[0].trim_space() in ['auto-fit', 'auto-fill'] {
			mut group_minimum := 0.0
			for group_token in track_group {
				group_minimum += grid_repeat_minimum(group_token, element, containing_width, author_rules)
			}
			if track_group.len > 1 {
				group_minimum += f64(track_group.len - 1) * gap
			}
			count = if group_minimum > 0 {
				int((containing_width + gap) / (group_minimum + gap))
			} else {
				1
			}
			if count < 1 {
				count = 1
			}
			if parts[0].trim_space() == 'auto-fit' && item_count > 0 && count * track_group.len > item_count {
				count = int(math.ceil(f64(item_count) / f64(track_group.len)))
			}
		}
		for _ in 0 .. count {
			tokens << group
		}
	}
	return tokens
}

fn grid_line_names(value string, element &dom.Element, containing_width f64, gap f64, author_rules []&css.CSSRule) map[string][]int {
	mut names := map[string][]int{}
	mut line := 0
	for token in expanded_grid_track_tokens(value, element, containing_width, gap, author_rules) {
		if token.starts_with('[') && token.ends_with(']') {
			for name in token[1..token.len - 1].fields() {
				names[name] << line
			}
		} else {
			line++
		}
	}
	return names
}

struct LegacyGridTrackSizing {
mut:
	base         f64
	limit        f64
	flex         f64
	stretch_auto bool
}

fn legacy_grid_intrinsic_widths(element &dom.Element, track_count int, author_rules []&css.CSSRule) ([]f64, []f64) {
	mut minimums := []f64{len: track_count}
	mut maximums := []f64{len: track_count}
	if track_count == 0 {
		return minimums, maximums
	}
	for index, item in flex_item_elements(element.as_node(), author_rules) {
		column := index % track_count
		edges := horizontal_edges(item, 0, author_rules)
		minimum := intrinsic_content_width(item, author_rules, true) + edges
		maximum := intrinsic_content_width(item, author_rules, false) + edges
		if minimum > minimums[column] {
			minimums[column] = minimum
		}
		if maximum > maximums[column] {
			maximums[column] = maximum
		}
	}
	return minimums, maximums
}

fn legacy_grid_track_sizing(token string, index int, minimums []f64, maximums []f64, element &dom.Element, containing_width f64, author_rules []&css.CSSRule) LegacyGridTrackSizing {
	trimmed := token.trim_space()
	minimum := minimums[index]
	maximum := if maximums[index] > minimum { maximums[index] } else { minimum }
	if trimmed.ends_with('fr') {
		return LegacyGridTrackSizing{
			flex: trimmed[..trimmed.len - 2].f64()
		}
	}
	if trimmed == 'auto' {
		return LegacyGridTrackSizing{
			base: minimum
			limit: maximum
			stretch_auto: true
		}
	}
	if trimmed == 'min-content' {
		return LegacyGridTrackSizing{
			base: minimum
			limit: minimum
		}
	}
	if trimmed == 'max-content' {
		return LegacyGridTrackSizing{
			base: maximum
			limit: maximum
		}
	}
	if trimmed.starts_with('fit-content(') && trimmed.ends_with(')') {
		cap := resolve_length_token(element, trimmed['fit-content('.len..trimmed.len - 1], containing_width, author_rules)
		limit := if maximum < cap { maximum } else { cap }
		return LegacyGridTrackSizing{
			base: minimum
			limit: if limit > minimum { limit } else { minimum }
		}
	}
	if trimmed.starts_with('minmax(') && trimmed.ends_with(')') {
		parts := split_top_level(trimmed['minmax('.len..trimmed.len - 1], `,`)
		if parts.len == 2 {
			min_token := parts[0].trim_space()
			max_token := parts[1].trim_space()
			base := match min_token {
				'auto', 'min-content' { minimum }
				'max-content' { maximum }
				else { resolve_length_token(element, min_token, containing_width, author_rules) }
			}
			if max_token.ends_with('fr') {
				return LegacyGridTrackSizing{
					base: base
					limit: base
					flex: max_token[..max_token.len - 2].f64()
				}
			}
			mut limit := match max_token {
				'auto', 'max-content' { maximum }
				'min-content' { minimum }
				else { resolve_length_token(element, max_token, containing_width, author_rules) }
			}
			if limit < base {
				limit = base
			}
			return LegacyGridTrackSizing{
				base: base
				limit: limit
				stretch_auto: max_token == 'auto'
			}
		}
	}
	fixed := resolve_length_token(element, trimmed, containing_width, author_rules)
	return LegacyGridTrackSizing{
		base: fixed
		limit: fixed
	}
}

fn resolve_legacy_grid_tracks(tokens []string, minimums []f64, maximums []f64, element &dom.Element, available_size f64, gap f64, author_rules []&css.CSSRule) []f64 {
	mut tracks := []LegacyGridTrackSizing{}
	for index, token in tokens {
		tracks << legacy_grid_track_sizing(token, index, minimums, maximums, element, available_size, author_rules)
	}
	total_gaps := if tokens.len > 1 { f64(tokens.len - 1) * gap } else { 0.0 }
	mut free := available_size - total_gaps
	for track in tracks {
		free -= track.base
	}
	free = non_negative(free)
	// Grow intrinsic tracks equally until their finite limits are reached.
	mut growable := []int{}
	for index, track in tracks {
		if track.flex == 0 && track.limit > track.base {
			growable << index
		}
	}
	for free > 0.000001 && growable.len > 0 {
		share := free / f64(growable.len)
		mut spent := 0.0
		mut next := []int{}
		for index in growable {
			delta := if tracks[index].limit - tracks[index].base < share {
				tracks[index].limit - tracks[index].base
			} else {
				share
			}
			tracks[index].base += delta
			spent += delta
			if tracks[index].base + 0.000001 < tracks[index].limit {
				next << index
			}
		}
		if spent <= 0 {
			break
		}
		free -= spent
		growable = next.clone()
	}
	// Resolve flexible tracks, freezing any whose minimum exceeds its fraction of the flex space.
	mut flexible := []int{}
	mut flex_space := free
	for index, track in tracks {
		if track.flex > 0 {
			flexible << index
			flex_space += track.base
		}
	}
	for flexible.len > 0 {
		mut fraction_sum := 0.0
		for index in flexible {
			fraction_sum += tracks[index].flex
		}
		if fraction_sum <= 0 {
			break
		}
		fraction := flex_space / fraction_sum
		mut frozen := -1
		for index in flexible {
			if tracks[index].base > fraction * tracks[index].flex {
				frozen = index
				break
			}
		}
		if frozen < 0 {
			for index in flexible {
				tracks[index].base = fraction * tracks[index].flex
			}
			free = 0
			break
		}
		flex_space -= tracks[frozen].base
		flexible = flexible.filter(it != frozen)
	}
	if flexible.len == 0 {
		mut stretchable := []int{}
		for index, track in tracks {
			if track.stretch_auto {
				stretchable << index
			}
		}
		if free > 0 && stretchable.len > 0 {
			extra := free / f64(stretchable.len)
			for index in stretchable {
				tracks[index].base += extra
			}
		}
	}
	return tracks.map(it.base)
}

// Resolve the explicit column track list through the Grid track-sizing phases represented by this
// renderer transport: expand repeat()/auto-repeat, initialize fixed and intrinsic minima, grow
// intrinsic tracks to their limits, flex the remaining space, then stretch auto maxima.
fn parse_grid_tracks(value string, element &dom.Element, containing_width f64, gap f64, author_rules []&css.CSSRule) []f64 {
	v := value.trim_space()
	if v == '' || v == 'none' {
		return [containing_width]
	}
	tokens := expanded_grid_track_tokens(v, element, containing_width, gap, author_rules).filter(!it.starts_with('['))
	if tokens.len == 0 {
		return [containing_width]
	}
	minimums, maximums := legacy_grid_intrinsic_widths(element, tokens.len, author_rules)
	return resolve_legacy_grid_tracks(tokens, minimums, maximums, element, containing_width, gap, author_rules)
}

// Row tracks share the same sizing machinery as columns. The compatibility grid pass supplies its
// measured row contributions; explicit tracks are padded to the template's size, while additional
// auto-placed rows remain implicit `auto` tracks.
fn parse_grid_row_tracks(value string, element &dom.Element, containing_height f64, gap f64, natural_rows []f64, author_rules []&css.CSSRule) []f64 {
	v := value.trim_space()
	mut tokens := if v == '' || v == 'none' {
		[]string{}
	} else {
		expanded_grid_track_tokens(v, element, containing_height, gap, author_rules).filter(!it.starts_with('['))
	}
	track_count := if tokens.len > natural_rows.len {
		tokens.len
	} else if natural_rows.len > 0 {
		natural_rows.len
	} else {
		1
	}
	for tokens.len < track_count {
		tokens << 'auto'
	}
	mut minimums := []f64{len: track_count}
	mut maximums := []f64{len: track_count}
	for index in 0 .. natural_rows.len {
		if index >= track_count {
			break
		}
		minimums[index] = natural_rows[index]
		maximums[index] = natural_rows[index]
	}
	return resolve_legacy_grid_tracks(tokens, minimums, maximums, element, containing_height, gap, author_rules)
}

// The flex items of `node`: its in-flow element children (any display is blockified, so inline and
// floated children count too), excluding `display: none` and absolutely positioned elements.
fn flex_item_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	mut elements := []&dom.Element{}
	collect_flex_item_elements(node, author_rules, mut elements)
	return elements
}

fn collect_flex_item_elements(node &dom.Node, author_rules []&css.CSSRule, mut elements []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		if element := child.as_element() {
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if display == 'none' {
				continue
			}
			if display == 'contents' {
				collect_flex_item_elements(element.as_node(), author_rules, mut elements)
				continue
			}
			if is_absolutely_positioned(position_value(element, author_rules)) {
				// out of flow
				continue
			}
			elements << element
		}
	}
}

// Formatting contexts calculate static-position rectangles for their direct out-of-flow children.
// `display: contents` contributes its children at the same level in the generated layout tree.
fn positioned_child_elements(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	mut elements := []&dom.Element{}
	collect_positioned_child_elements(node, author_rules, mut elements)
	return elements
}

fn collect_positioned_child_elements(node &dom.Node, author_rules []&css.CSSRule, mut elements []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child_node in node.children_as_vector() {
		child := child_node.as_element() or { continue }
		display := css.cascaded_value_with_ua(child, display_id, author_rules)
		if display == 'none' {
			continue
		}
		if display == 'contents' {
			collect_positioned_child_elements(child.as_node(), author_rules, mut elements)
			continue
		}
		if is_absolutely_positioned(position_value(child, author_rules)) {
			elements << child
		}
	}
}

fn retain_static_position(child &dom.Element, position StaticPosition, mut absolute_positions map[i64]StaticPosition, mut fixed_positions map[i64]StaticPosition, author_rules []&css.CSSRule) {
	node_id := i64(child.as_node().unique_id())
	if position_value(child, author_rules) == 'fixed' {
		fixed_positions[node_id] = position
	} else {
		absolute_positions[node_id] = position
	}
}

fn static_position_alignment(value string) StaticPositionAlignment {
	return match value {
		'center' { .center }
		'flex-end', 'end', 'right', 'self-end' { .end }
		else { .start }
	}
}

fn flex_static_cross_alignment(element &dom.Element, container_alignment string, author_rules []&css.CSSRule) StaticPositionAlignment {
	id := css.property_id_from_string('align-self') or {
		return static_position_alignment(container_alignment)
	}
	value := css.cascaded_value_with_ua(element, id, author_rules)
	// FlexFormattingContext::alignment_for_item() inherits align-items only for align-self:auto.
	// In particular, explicit `normal` remains Normal and maps to the physical start edge.
	return static_position_alignment(if value == '' || value == 'auto' {
		container_alignment
	} else {
		value
	})
}

// FlexFormattingContext::is_direction_reverse(). RTL reverses a plain row rather than row-reverse;
// column-reverse remains reversed in either inline direction.
fn flex_static_direction_is_reversed(element &dom.Element, author_rules []&css.CSSRule) bool {
	direction := css.cascaded_value_with_ua(element, css.property_id_from_string('direction') or {
		return false
	}, author_rules)
	flex_direction := flex_direction_value(element, author_rules)
	if direction == 'rtl' {
		return flex_direction == 'column-reverse' || flex_direction == 'row'
	}
	return flex_direction == 'column-reverse' || flex_direction == 'row-reverse'
}

// The main-axis alignment of the flex static-position rectangle is not the ordinary multi-item
// justify offset: the abspos child is treated as the sole fixed-size flex item.
fn flex_static_main_alignment(element &dom.Element, author_rules []&css.CSSRule) StaticPositionAlignment {
	value := css.cascaded_value_with_ua(element, css.property_id_from_string('justify-content') or {
		return .start
	}, author_rules)
	reversed := flex_static_direction_is_reversed(element, author_rules)
	return match value {
		'start', 'left' { StaticPositionAlignment.start }
		'end', 'right' { StaticPositionAlignment.end }
		'flex-end' {
			if reversed { StaticPositionAlignment.start } else { StaticPositionAlignment.end }
		}
		'center', 'space-around', 'space-evenly' { StaticPositionAlignment.center }
		// normal, stretch, flex-start, and space-between use the main-start edge.
		else {
			if reversed { StaticPositionAlignment.end } else { StaticPositionAlignment.start }
		}
	}
}

fn retain_flex_static_positions(element &dom.Element, content_x f64, content_width f64, content_height f64, row_layout bool, mut absolute_positions map[i64]StaticPosition, mut fixed_positions map[i64]StaticPosition, author_rules []&css.CSSRule) {
	main_alignment := flex_static_main_alignment(element, author_rules)
	container_alignment := align_items_value(element, author_rules)
	for child in positioned_child_elements(element.as_node(), author_rules) {
		cross_alignment := flex_static_cross_alignment(child, container_alignment, author_rules)
		position := StaticPosition{
			x: content_x
			y: 0.0
			width: content_width
			height: content_height
			horizontal_alignment: if row_layout { main_alignment } else { cross_alignment }
			vertical_alignment: if row_layout { cross_alignment } else { main_alignment }
		}
		retain_static_position(child, position, mut absolute_positions, mut fixed_positions, author_rules)
	}
}

struct LegacyGridAxisRect {
	start f64
	size  f64
}

fn legacy_grid_track_range_size(tracks []f64, start int, span int, gap f64) f64 {
	mut size := gap * f64(if span > 0 { span - 1 } else { 0 })
	for index in start .. start + span {
		if index >= 0 && index < tracks.len {
			size += tracks[index]
		}
	}
	return size
}

fn legacy_grid_track_offset(tracks []f64, index int, gap f64) f64 {
	gap_count := if index <= 0 || tracks.len <= 1 {
		0
	} else if index < tracks.len {
		index
	} else {
		tracks.len - 1
	}
	mut offset := gap * f64(gap_count)
	for track_index in 0 .. index {
		if track_index < tracks.len {
			offset += tracks[track_index]
		}
	}
	return offset
}

// Float transport of grid_inline_content_geometry()/grid_block_content_geometry(). Distributed
// alignment can replace a smaller authored gap, then the remaining free space determines the lead.
fn legacy_grid_content_geometry(element &dom.Element, content_size f64, tracks []f64, computed_gap f64, horizontal bool, author_rules []&css.CSSRule) (f64, f64) {
	property := if horizontal { 'justify-content' } else { 'align-content' }
	value := css.cascaded_value_with_ua(element, css.property_id_from_string(property) or {
		return 0.0, computed_gap
	}, author_rules)
	mut tracks_size := 0.0
	for track in tracks {
		tracks_size += track
	}
	gap_count := if tracks.len > 0 { tracks.len - 1 } else { 0 }
	mut effective_gap := computed_gap
	if gap_count > 0 {
		total_gap_space := non_negative(content_size - tracks_size)
		distributed_gap := match value {
			'space-between' { total_gap_space / f64(gap_count) }
			'space-around' { total_gap_space / f64(gap_count + 1) }
			'space-evenly' { total_gap_space / f64(gap_count + 2) }
			else { 0.0 }
		}
		if distributed_gap > effective_gap {
			effective_gap = distributed_gap
		}
	}
	used_size := tracks_size + effective_gap * f64(gap_count)
	free_space := non_negative(content_size - used_size)
	mut leading := match value {
		'end', 'flex-end', 'right' { free_space }
		'center', 'space-around', 'space-evenly' { free_space / 2.0 }
		else { 0.0 }
	}
	if horizontal && css.cascaded_value_with_ua(element, css.property_id_from_string('direction') or {
		return leading, effective_gap
	}, author_rules) == 'rtl' {
		if value == 'left' {
			leading = free_space
		} else if value == 'right' {
			leading = 0.0
		}
	}
	return leading, effective_gap
}

fn legacy_grid_axis_rect(tracks []f64, placement LegacyGridAxisPlacement, padding_start f64, padding_end f64, content_size f64, leading f64, gap f64) LegacyGridAxisRect {
	if placement.start < 0 {
		return LegacyGridAxisRect{
			start: -padding_start
			size: padding_start + content_size + padding_end
		}
	}
	if placement.start >= tracks.len {
		return LegacyGridAxisRect{
			start: leading + legacy_grid_track_offset(tracks, tracks.len, gap)
			size: padding_end
		}
	}
	start := placement.start
	return LegacyGridAxisRect{
		start: leading + legacy_grid_track_offset(tracks, start, gap)
		size: legacy_grid_track_range_size(tracks, start, placement.span, gap)
	}
}

fn grid_static_self_alignment(element &dom.Element, self_property string, container_value string, author_rules []&css.CSSRule) StaticPositionAlignment {
	id := css.property_id_from_string(self_property) or {
		return static_position_alignment(container_value)
	}
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return static_position_alignment(if value == '' || value == 'auto' {
		container_value
	} else {
		value
	})
}

fn retain_grid_static_positions(element &dom.Element, content_x f64, content_width f64, content_height f64, padding BoxEdges, columns []f64, rows []f64, column_gap f64, row_gap f64, column_names map[string][]int, row_names map[string][]int, mut absolute_positions map[i64]StaticPosition, mut fixed_positions map[i64]StaticPosition, author_rules []&css.CSSRule) {
	column_leading, effective_column_gap := legacy_grid_content_geometry(element, content_width, columns, column_gap, true, author_rules)
	row_leading, effective_row_gap := legacy_grid_content_geometry(element, content_height, rows, row_gap, false, author_rules)
	container_justify := justify_items_value(element, author_rules)
	container_align := align_items_value(element, author_rules)
	grid_establishes_containing_block := is_positioned(position_value(element, author_rules))
	rtl := css.cascaded_value_with_ua(element, css.property_id_from_string('direction') or {
		return
	}, author_rules) == 'rtl'
	for child in positioned_child_elements(element.as_node(), author_rules) {
		mut position := StaticPosition{
			x: content_x
			y: 0.0
			width: content_width
			height: content_height
		}
		if grid_establishes_containing_block && position_value(child, author_rules) == 'absolute' {
			column_placement := grid_abspos_column_placement(child, columns.len, column_names, author_rules)
			row_placement := grid_abspos_row_placement(child, rows.len, row_names, author_rules)
			column_rect := legacy_grid_axis_rect(columns, column_placement, padding.left, padding.right, content_width, column_leading, effective_column_gap)
			row_rect := legacy_grid_axis_rect(rows, row_placement, padding.top, padding.bottom, content_height, row_leading, effective_row_gap)
			physical_column_start := if rtl && column_placement.start >= 0 {
				content_width - column_rect.start - column_rect.size
			} else {
				column_rect.start
			}
			position = StaticPosition{
				x: content_x + physical_column_start
				y: row_rect.start
				width: column_rect.size
				height: row_rect.size
				horizontal_alignment: grid_static_self_alignment(child, 'justify-self', container_justify, author_rules)
				vertical_alignment: grid_static_self_alignment(child, 'align-self', container_align, author_rules)
				has_containing_block_rect: true
				containing_block_x: content_x + physical_column_start
				containing_block_y: row_rect.start
				containing_block_width: column_rect.size
				containing_block_height: row_rect.size
			}
		}
		retain_static_position(child, position, mut absolute_positions, mut fixed_positions, author_rules)
	}
}

fn grid_position_with_containing_block_rect(position StaticPosition, x f64, y f64, width f64, height f64) StaticPosition {
	return StaticPosition{
		x: position.x
		y: position.y
		width: position.width
		height: position.height
		horizontal_alignment: position.horizontal_alignment
		vertical_alignment: position.vertical_alignment
		has_containing_block_rect: true
		containing_block_x: x
		containing_block_y: y
		containing_block_width: width
		containing_block_height: height
	}
}

// GridFormattingContext propagates an in-flow grid item's area to abspos descendants whose actual
// containing block is still the grid container. A nearer positioned descendant terminates the walk.
fn retain_grid_area_for_absolute_descendants(node &dom.Node, area_x f64, area_y f64, area_width f64, area_height f64, mut positions map[i64]StaticPosition, author_rules []&css.CSSRule) {
	display_id := css.property_id_from_string('display') or { return }
	for child_node in node.children_as_vector() {
		child := child_node.as_element() or { continue }
		display := css.cascaded_value_with_ua(child, display_id, author_rules)
		if display == 'none' {
			continue
		}
		if display == 'contents' {
			retain_grid_area_for_absolute_descendants(child.as_node(), area_x, area_y, area_width, area_height, mut positions, author_rules)
			continue
		}
		position_value_ := position_value(child, author_rules)
		if position_value_ == 'absolute' {
			node_id := i64(child.as_node().unique_id())
			if retained := positions[node_id] {
				positions[node_id] = grid_position_with_containing_block_rect(retained, area_x, area_y, area_width, area_height)
			}
			continue
		}
		if position_value_ == 'fixed' || is_positioned(position_value_) {
			continue
		}
		retain_grid_area_for_absolute_descendants(child.as_node(), area_x, area_y, area_width, area_height, mut positions, author_rules)
	}
}

// A flex item's flex base main size (content-box px): its `flex-basis` when that is a length/percentage
// (`0%` → 0), otherwise — for `auto`/`content` — the item's definite `width` if it has one, else its
// content size (max-content). A border-box basis is converted back to content space before the
// flexible-length algorithm runs.
fn flex_base_size(element &dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	border_padding := horizontal_border_padding(element, container_width, author_rules)
	border_box := box_sizing_is_border_box(element, author_rules)
	to_content_size := fn [border_box, border_padding] (specified f64) f64 {
		return non_negative(if border_box { specified - border_padding } else { specified })
	}
	basis_id := css.property_id_from_string('flex-basis') or {
		return flex_content_base(element, container_width, author_rules)
	}
	if px := css.computed_length_px(element, basis_id, author_rules) {
		return to_content_size(px)
	}
	if pct := css.computed_percentage(element, basis_id, author_rules) {
		return to_content_size(container_width * pct / 100.0)
	}
	// `flex-basis: auto` uses the item's definite width (if any); `content`/unresolved uses content.
	if css.cascaded_value_with_ua(element, basis_id, author_rules) == 'auto' && !size_is_auto(element, 'width', author_rules) {
		width_id := css.property_id_from_string('width') or {
			return flex_content_base(element, container_width, author_rules)
		}
		if wpx := css.computed_length_px(element, width_id, author_rules) {
			return to_content_size(wpx)
		}
		if wpct := css.computed_percentage(element, width_id, author_rules) {
			return to_content_size(container_width * wpct / 100.0)
		}
		if calc := css.computed_calc_px(element, width_id, container_width, author_rules) {
			return to_content_size(calc)
		}
	}
	return flex_content_base(element, container_width, author_rules)
}

// A flex item's content-based main size: its max-content, shrink-to-fit clamped to the container.
fn flex_content_base(element &dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	return shrink_to_fit(intrinsic_content_width(element, author_rules, true), intrinsic_content_width(element, author_rules, false), container_width)
}

// The `flex-grow` factor (default 0) and `flex-shrink` factor (default 1) of a flex item.
fn flex_grow_value(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('flex-grow') or { return 0.0 }
	return css.cascaded_value_with_ua(element, id, author_rules).f64()
}

fn flex_shrink_value(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('flex-shrink') or { return 1.0 }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' { 1.0 } else { value.f64() }
}

fn minimal_flex_item_is_scroll_container(element &dom.Element, author_rules []&css.CSSRule) bool {
	for axis in ['overflow-x', 'overflow-y'] {
		id := css.property_id_from_string(axis) or { continue }
		if css.cascaded_value_with_ua(element, id, author_rules) in ['auto', 'hidden', 'scroll'] {
			return true
		}
	}
	return false
}

fn flex_minimum_main_size(element &dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	border_padding := horizontal_border_padding(element, container_width, author_rules)
	border_box := box_sizing_is_border_box(element, author_rules)
	if explicit := resolve_size_constraint(element, 'min-width', container_width, border_padding, border_box, author_rules) {
		return explicit
	}
	min_id := css.property_id_from_string('min-width') or { return 0 }
	if css.cascaded_value_with_ua(element, min_id, author_rules) != 'auto' || minimal_flex_item_is_scroll_container(element, author_rules) {
		return 0
	}
	mut content_suggestion := intrinsic_content_width(element, author_rules, true)
	if !size_is_auto(element, 'width', author_rules) {
		width_id := css.property_id_from_string('width') or { return content_suggestion }
		mut specified := ?f64(none)
		if px := css.computed_length_px(element, width_id, author_rules) {
			specified = px
		} else if pct := css.computed_percentage(element, width_id, author_rules) {
			specified = container_width * pct / 100.0
		} else if calc := css.computed_calc_px(element, width_id, container_width, author_rules) {
			specified = calc
		}
		if value := specified {
			content_size := non_negative(if border_box { value - border_padding } else { value })
			if content_size < content_suggestion {
				content_suggestion = content_size
			}
		}
	}
	if maximum := resolve_size_constraint(element, 'max-width', container_width, border_padding, border_box, author_rules) {
		if maximum < content_suggestion {
			return maximum
		}
	}
	return content_suggestion
}

fn flex_maximum_main_size(element &dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	border_padding := horizontal_border_padding(element, container_width, author_rules)
	return resolve_size_constraint(element, 'max-width', container_width, border_padding, box_sizing_is_border_box(element, author_rules), author_rules) or { f64(1.7976931348623157e308) }
}

fn vertical_border_padding(box BlockBox) f64 {
	return box.border.top + box.border.bottom + box.padding.top + box.padding.bottom
}

fn flex_column_resolved_size(element &dom.Element, property_name string, container_height ?f64, border_padding f64, border_box bool, author_rules []&css.CSSRule) ?f64 {
	id := css.property_id_from_string(property_name) or { return none }
	mut specified := ?f64(none)
	if px := css.computed_length_px(element, id, author_rules) {
		specified = px
	} else if height := container_height {
		if percentage := css.computed_percentage(element, id, author_rules) {
			specified = height * percentage / 100.0
		} else if calc := css.computed_calc_px(element, id, height, author_rules) {
			specified = calc
		}
	}
	if value := specified {
		return non_negative(if border_box { value - border_padding } else { value })
	}
	return none
}

fn flex_column_base_size(element &dom.Element, natural_content_height f64, container_height ?f64, border_padding f64, border_box bool, author_rules []&css.CSSRule) f64 {
	if basis := flex_column_resolved_size(element, 'flex-basis', container_height, border_padding, border_box, author_rules) {
		return basis
	}
	basis_id := css.property_id_from_string('flex-basis') or { return natural_content_height }
	if css.cascaded_value_with_ua(element, basis_id, author_rules) == 'auto' {
		if height := flex_column_resolved_size(element, 'height', container_height, border_padding, border_box, author_rules) {
			return height
		}
	}
	return natural_content_height
}

fn flex_column_minimum_size(element &dom.Element, natural_content_height f64, container_height ?f64, border_padding f64, border_box bool, author_rules []&css.CSSRule) f64 {
	if explicit := flex_column_resolved_size(element, 'min-height', container_height, border_padding, border_box, author_rules) {
		return explicit
	}
	min_id := css.property_id_from_string('min-height') or { return 0 }
	if css.cascaded_value_with_ua(element, min_id, author_rules) != 'auto' || minimal_flex_item_is_scroll_container(element, author_rules) {
		return 0
	}
	mut content_suggestion := natural_content_height
	if preferred := flex_column_resolved_size(element, 'height', container_height, border_padding, border_box, author_rules) {
		if preferred < content_suggestion {
			content_suggestion = preferred
		}
	}
	if maximum := flex_column_resolved_size(element, 'max-height', container_height, border_padding, border_box, author_rules) {
		if maximum < content_suggestion {
			return maximum
		}
	}
	return content_suggestion
}

fn flex_column_maximum_size(element &dom.Element, container_height ?f64, border_padding f64, border_box bool, author_rules []&css.CSSRule) f64 {
	return flex_column_resolved_size(element, 'max-height', container_height, border_padding, border_box, author_rules) or { f64(1.7976931348623157e308) }
}

fn definite_content_height(element &dom.Element, border BoxEdges, padding BoxEdges, border_box bool, author_rules []&css.CSSRule) ?f64 {
	height_id := css.property_id_from_string('height') or { return none }
	if height := css.computed_length_px(element, height_id, author_rules) {
		return non_negative(if border_box {
			height - border.top - border.bottom - padding.top - padding.bottom
		} else {
			height
		})
	}
	return none
}

fn absolute_f64(value f64) f64 {
	return if value < 0 { -value } else { value }
}

// Resolve flexible lengths using the Flexbox freeze/violation loop. `free` is the content-space
// remainder after item bases, gaps, margins, borders, and padding have been subtracted.
fn resolve_flex_main_sizes(items []&dom.Element, bases []f64, free f64, container_width f64, author_rules []&css.CSSRule) []f64 {
	mut minimums := []f64{cap: items.len}
	mut maximums := []f64{cap: items.len}
	for item in items {
		minimums << flex_minimum_main_size(item, container_width, author_rules)
		maximums << flex_maximum_main_size(item, container_width, author_rules)
	}
	return resolve_flexible_content_sizes(items, bases, minimums, maximums, free, author_rules)
}

fn resolve_flexible_content_sizes(items []&dom.Element, bases []f64, minimums []f64, maximums []f64, free f64, author_rules []&css.CSSRule) []f64 {
	mut targets := bases.clone()
	mut frozen := []bool{len: items.len}
	mut hypotheticals := []f64{cap: items.len}
	mut hypothetical_sum := 0.0
	mut base_sum := 0.0
	for index in 0 .. items.len {
		hypothetical := non_negative(clamp_size(bases[index], minimums[index], maximums[index]))
		hypotheticals << hypothetical
		hypothetical_sum += hypothetical
		base_sum += bases[index]
	}
	content_capacity := base_sum + free
	use_grow_factor := hypothetical_sum < content_capacity
	for index, item in items {
		factor := if use_grow_factor {
			flex_grow_value(item, author_rules)
		} else {
			flex_shrink_value(item, author_rules)
		}
		if factor == 0 || (use_grow_factor && bases[index] > hypotheticals[index]) || (!use_grow_factor && bases[index] < hypotheticals[index]) {
			frozen[index] = true
			targets[index] = hypotheticals[index]
		}
	}
	calculate_free_space := fn [items, bases, content_capacity] (targets []f64, frozen []bool) f64 {
		mut occupied := 0.0
		for index in 0 .. items.len {
			occupied += if frozen[index] { targets[index] } else { bases[index] }
		}
		return content_capacity - occupied
	}
	initial_free_space := calculate_free_space(targets, frozen)
	for _ in 0 .. items.len + 1 {
		mut has_unfrozen_item := false
		for is_frozen in frozen {
			if !is_frozen {
				has_unfrozen_item = true
				break
			}
		}
		if !has_unfrozen_item {
			break
		}
		mut remaining_free_space := calculate_free_space(targets, frozen)
		mut factor_sum := 0.0
		for index, item in items {
			if !frozen[index] {
				factor_sum += if use_grow_factor {
					flex_grow_value(item, author_rules)
				} else {
					flex_shrink_value(item, author_rules)
				}
			}
		}
		if factor_sum < 1 {
			scaled_initial := initial_free_space * factor_sum
			if absolute_f64(scaled_initial) < absolute_f64(remaining_free_space) {
				remaining_free_space = scaled_initial
			}
		}
		if use_grow_factor {
			for index, item in items {
				if !frozen[index] {
					ratio := if factor_sum != 0 {
						flex_grow_value(item, author_rules) / factor_sum
					} else {
						0.0
					}
					targets[index] = bases[index] + remaining_free_space * ratio
				}
			}
		} else {
			mut scaled_shrink_sum := 0.0
			for index, item in items {
				if !frozen[index] {
					scaled_shrink_sum += flex_shrink_value(item, author_rules) * bases[index]
				}
			}
			for index, item in items {
				if !frozen[index] {
					scaled_factor := flex_shrink_value(item, author_rules) * bases[index]
					ratio := if scaled_shrink_sum != 0 {
						scaled_factor / scaled_shrink_sum
					} else {
						1.0
					}
					targets[index] = bases[index] - absolute_f64(remaining_free_space) * ratio
				}
			}
		}
		mut total_violation := 0.0
		mut min_violations := []bool{len: items.len}
		mut max_violations := []bool{len: items.len}
		for index in 0 .. items.len {
			if frozen[index] {
				continue
			}
			original := targets[index]
			targets[index] = non_negative(clamp_size(targets[index], minimums[index], maximums[index]))
			if targets[index] > original {
				min_violations[index] = true
			} else if targets[index] < original {
				max_violations[index] = true
			}
			total_violation += targets[index] - original
		}
		if absolute_f64(total_violation) < 0.000000001 {
			for index in 0 .. frozen.len {
				frozen[index] = true
			}
		} else if total_violation > 0 {
			for index in 0 .. frozen.len {
				if min_violations[index] {
					frozen[index] = true
				}
			}
		} else {
			for index in 0 .. frozen.len {
				if max_violations[index] {
					frozen[index] = true
				}
			}
		}
	}
	return targets
}

// Whether `element` is a multi-line flex container (`flex-wrap: wrap`/`wrap-reverse`).
fn flex_wraps(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('flex-wrap') or { return false }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return value == 'wrap' || value == 'wrap-reverse'
}

fn flex_cross_axis_is_reversed(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('flex-wrap') or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'wrap-reverse'
}

// Lay out one line of a row flex container: the line's items grow/shrink over its free space, pack
// along the main axis (with `gap_main`), justify-content distributes the leftover, and each item
// cross-aligns within `cross_arg` (or the line's tallest item when `cross_arg` < 0) at cross offset
// `cross_y`. Placed boxes are appended to `out`; returns the line's cross extent (its tallest item's
// margin box).
fn place_flex_line(element &dom.Element, line_items []&dom.Element, line_bases []f64, content_x f64, cross_y f64, width f64, gap_main f64, cross_arg f64, reverse_main bool, reverse_cross bool, author_rules []&css.CSSRule, mut out []BlockBox) f64 {
	mut total_used := if line_items.len > 1 { f64(line_items.len - 1) * gap_main } else { 0.0 }
	for i, item in line_items {
		total_used += line_bases[i] + horizontal_edges(item, width, author_rules)
	}
	finals := resolve_flex_main_sizes(line_items, line_bases, width - total_used, width, author_rules)
	mut item_boxes := []BlockBox{}
	mut tallest := 0.0
	for i, item in line_items {
		ib := layout_block_impl(item, content_x, 0.0, width, finals[i], author_rules)
		if ib.margin_box_height() > tallest {
			tallest = ib.margin_box_height()
		}
		item_boxes << ib
	}
	cross_size := if cross_arg >= 0.0 { cross_arg } else { tallest }
	mut occupied_main := if item_boxes.len > 1 { f64(item_boxes.len - 1) * gap_main } else { 0.0 }
	for item in item_boxes {
		occupied_main += item.margin_box_width()
	}
	leading, gap := justify_offsets(justify_content_value(element, author_rules), width - occupied_main, item_boxes.len)
	container_align := align_items_value(element, author_rules)
	mut main_cursor := 0.0
	for i, ib in item_boxes {
		if i > 0 {
			main_cursor += gap_main + gap
		}
		align := effective_align_self(line_items[i], container_align, author_rules)
		mut item := ib
		if align == 'stretch' && size_is_auto(line_items[i], 'height', author_rules) {
			item.height = flex_stretched_content_height(item, cross_size)
		}
		normal_cross := cross_axis_offset(align, cross_size, item.margin_box_height())
		cross := if reverse_cross {
			cross_size - normal_cross - item.margin_box_height()
		} else {
			normal_cross
		}
		main := if reverse_main {
			width - leading - main_cursor - item.margin_box_width()
		} else {
			leading + main_cursor
		}
		out << translate_block(item, main, cross_y + cross)
		main_cursor += item.margin_box_width()
	}
	return tallest
}

// The main-axis gap between flex items (a row's `column-gap`; the `gap` shorthand sets it), in px.
// `normal`/absent is 0.
fn flex_column_gap(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('column-gap') or { return 0 }
	return css.computed_length_px(element, id, author_rules) or { 0 }
}

// The main-axis gap for a column flex container (`row-gap`; the `gap` shorthand sets it), in px.
fn flex_row_gap(element &dom.Element, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('row-gap') or { return 0 }
	return css.computed_length_px(element, id, author_rules) or { 0 }
}

// The cascaded `justify-content` value, normalized (`normal` and absent behave as `flex-start`).
fn justify_content_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('justify-content') or { return 'flex-start' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'normal' { 'flex-start' } else { value }
}

// The main-axis distribution for `n` flex items given `free` px of leftover space: returns the leading
// offset before the first item and the gap added between adjacent items, so item `i` shifts by
// `leading + i*gap`. The `space-*` distributions only add space when there is free space (on overflow
// they pack at the start); `center`/`flex-end` shift by the raw free space (which may be negative).
fn justify_offsets(value string, free f64, n int) (f64, f64) {
	if n == 0 {
		return 0.0, 0.0
	}
	positive_free := if free > 0 { free } else { 0.0 }
	match value {
		'flex-end', 'end', 'right' {
			return free, 0.0
		}
		'center' {
			return free / 2.0, 0.0
		}
		'space-between' {
			if n > 1 {
				return 0.0, positive_free / f64(n - 1)
			}
			return 0.0, 0.0
		}
		'space-around' {
			gap := positive_free / f64(n)
			return gap / 2.0, gap
		}
		'space-evenly' {
			gap := positive_free / f64(n + 1)
			return gap, gap
		}
		else {}
	}
	// flex-start / start / normal
	return 0.0, 0.0
}

// The cascaded `align-items` value, normalized (`normal` and absent behave as `stretch`).
fn align_items_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('align-items') or { return 'stretch' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'normal' || value == 'legacy' { 'stretch' } else { value }
}

fn align_content_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('align-content') or { return 'stretch' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'normal' { 'stretch' } else { value }
}

// The effective cross-axis alignment for a flex item: its `align-self` unless that is `auto`/`normal`,
// in which case the container's `align-items` (`container_align`) applies.
fn effective_align_self(element &dom.Element, container_align string, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('align-self') or { return container_align }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'auto' || value == 'normal' { container_align } else { value }
}

fn justify_items_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('justify-items') or { return 'stretch' }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'normal' || value == 'legacy' { 'stretch' } else { value }
}

fn effective_justify_self(element &dom.Element, container_justify string, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('justify-self') or { return container_justify }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return if value == '' || value == 'auto' || value == 'normal' {
		container_justify
	} else {
		value
	}
}

// The cross-axis (vertical, for a row) offset that aligns an item whose margin box is `item_cross` px
// tall within a `cross_size` px line, per its resolved alignment. `stretch` (already resized to the
// line), `flex-start`, and `baseline` top-align (0).
fn cross_axis_offset(align string, cross_size f64, item_cross f64) f64 {
	return match align {
		'flex-end', 'end', 'right' { cross_size - item_cross }
		'center' { (cross_size - item_cross) / 2.0 }
		else { 0.0 }
	}
	// flex-start / start / stretch / baseline
}

// The content height that stretches a flex item's box to fill a `cross_size` px line: the line minus
// the item's vertical margins, borders, and padding (so its margin box becomes `cross_size`).
fn flex_stretched_content_height(box BlockBox, cross_size f64) f64 {
	v_edges := box.margin.top + box.margin.bottom + box.border.top + box.border.bottom + box.padding.top + box.padding.bottom
	return non_negative(cross_size - v_edges)
}

fn flex_stretched_content_width(box BlockBox, cross_size f64) f64 {
	h_edges := box.margin.left + box.margin.right + box.border.left + box.border.right + box.padding.left + box.padding.right
	return non_negative(cross_size - h_edges)
}

// Measure a column flex line's hypothetical cross size before align-content distributes the
// container width. Auto-width items use their shrink-to-fit width for this measurement; stretch is
// applied only after the final line width is known.
fn measure_flex_column_line_cross_size(items []&dom.Element, container_width f64, author_rules []&css.CSSRule) f64 {
	mut widest := 0.0
	for item in items {
		forced := if size_is_auto(item, 'width', author_rules) {
			?f64(flex_content_base(item, container_width, author_rules))
		} else {
			?f64(none)
		}
		box := layout_block_impl(item, 0, 0, container_width, forced, author_rules)
		if box.margin_box_width() > widest {
			widest = box.margin_box_width()
		}
	}
	return widest
}

// Resolve and place one vertical flex line. Returns the used main-axis extent of the line.
fn place_flex_column_line(container &dom.Element, items []&dom.Element, cross_x f64, cross_size f64, container_height ?f64, gap_main f64, reverse_main bool, reverse_cross bool, author_rules []&css.CSSRule, mut out []BlockBox) f64 {
	container_align := align_items_value(container, author_rules)
	mut item_boxes := []BlockBox{}
	mut aligns := []string{}
	mut bases := []f64{}
	mut minimums := []f64{}
	mut maximums := []f64{}
	mut main_edges := []f64{}
	for item in items {
		align := effective_align_self(item, container_align, author_rules)
		aligns << align
		forced_width := if size_is_auto(item, 'width', author_rules) {
			if align == 'stretch' {
				?f64(non_negative(cross_size - horizontal_edges(item, cross_size, author_rules)))
			} else {
				?f64(flex_content_base(item, cross_size, author_rules))
			}
		} else {
			?f64(none)
		}
		box := layout_block_impl(item, cross_x, 0, cross_size, forced_width, author_rules)
		border_padding := vertical_border_padding(box)
		item_border_box := box_sizing_is_border_box(item, author_rules)
		bases << flex_column_base_size(item, box.height, container_height, border_padding, item_border_box, author_rules)
		minimums << flex_column_minimum_size(item, box.height, container_height, border_padding, item_border_box, author_rules)
		maximums << flex_column_maximum_size(item, container_height, border_padding, item_border_box, author_rules)
		main_edges << box.margin_box_height() - box.height
		item_boxes << box
	}
	mut base_outer_total := if items.len > 1 { f64(items.len - 1) * gap_main } else { 0.0 }
	for index in 0 .. items.len {
		base_outer_total += bases[index] + main_edges[index]
	}
	mut targets := []f64{}
	if available_height := container_height {
		targets = resolve_flexible_content_sizes(items, bases, minimums, maximums, available_height - base_outer_total, author_rules)
	} else {
		for index in 0 .. bases.len {
			targets << non_negative(clamp_size(bases[index], minimums[index], maximums[index]))
		}
	}
	mut total_main := if items.len > 1 { f64(items.len - 1) * gap_main } else { 0.0 }
	for index in 0 .. item_boxes.len {
		mut item_box := item_boxes[index]
		item_box.height = targets[index]
		if aligns[index] == 'stretch' && size_is_auto(items[index], 'width', author_rules) {
			item_box.width = flex_stretched_content_width(item_box, cross_size)
		}
		item_boxes[index] = item_box
		total_main += item_box.margin_box_height()
	}
	main_size := container_height or { total_main }
	leading, gap := justify_offsets(justify_content_value(container, author_rules), main_size - total_main, item_boxes.len)
	mut cursor := 0.0
	for index, item_box in item_boxes {
		if index > 0 {
			cursor += gap_main + gap
		}
		normal_cross := cross_axis_offset(aligns[index], cross_size, item_box.margin_box_width())
		cross := if reverse_cross {
			cross_size - normal_cross - item_box.margin_box_width()
		} else {
			normal_cross
		}
		logical_main := leading + cursor
		main := if reverse_main {
			main_size - logical_main - item_box.margin_box_height()
		} else {
			logical_main
		}
		out << translate_block(item_box, cross, main)
		cursor += item_box.margin_box_height()
	}
	return main_size
}

// The flex container's cross size for aligning items: its explicit content-box height when set (box-
// sizing aware), otherwise the flowed content height (the tallest item).
fn align_cross_size(element &dom.Element, content_height f64, border BoxEdges, padding BoxEdges, border_box bool, author_rules []&css.CSSRule) f64 {
	height_id := css.property_id_from_string('height') or { return content_height }
	if px := css.computed_length_px(element, height_id, author_rules) {
		if border_box {
			return non_negative(px - border.top - border.bottom - padding.top - padding.bottom)
		}
		return px
	}
	return content_height
}

// The cascaded `float` value (`none` when absent); `is_floating` is float left/right.
fn float_side(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('float') or { return 'none' }
	return css.cascaded_value_with_ua(element, id, author_rules)
}

fn is_floating(element &dom.Element, author_rules []&css.CSSRule) bool {
	side := float_side(element, author_rules)
	return side == 'left' || side == 'right'
}

// The floated element children of `node`, in document order (skipping display:none). Absolutely
// positioned elements are handled elsewhere and take precedence over float.
fn float_children(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	mut elements := []&dom.Element{}
	collect_float_children(node, author_rules, mut elements)
	return elements
}

fn collect_float_children(node &dom.Node, author_rules []&css.CSSRule, mut elements []&dom.Element) {
	display_id := css.property_id_from_string('display') or { return }
	for child in node.children_as_vector() {
		if element := child.as_element() {
			display := css.cascaded_value_with_ua(element, display_id, author_rules)
			if display == 'none' {
				continue
			}
			if display == 'contents' {
				collect_float_children(element.as_node(), author_rules, mut elements)
				continue
			}
			if is_absolutely_positioned(position_value(element, author_rules)) {
				continue
			}
			if is_floating(element, author_rules) {
				elements << element
			}
		}
	}
}

// The y (local frame) an in-flow block must clear down to, given the current left/right float bottoms
// and the element's `clear` value: `left`/`right`/`both` clear the respective floats (0 = no clear).
fn clearance_bottom(element &dom.Element, left_floats_bottom f64, right_floats_bottom f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('clear') or { return 0.0 }
	return match css.cascaded_value_with_ua(element, id, author_rules) {
		'left' {
			left_floats_bottom
		}
		'right' {
			right_floats_bottom
		}
		'both' {
			if left_floats_bottom > right_floats_bottom {
				left_floats_bottom
			} else {
				right_floats_bottom
			}
		}
		else {
			0.0
		}
	}
}

fn has_non_none_clear(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('clear') or { return false }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	return value != '' && value != 'none'
}

fn is_self_collapsing_empty_block(element &dom.Element, box BlockBox, author_rules []&css.CSSRule) bool {
	if establishes_block_formatting_context(element, author_rules) || has_non_none_clear(element, author_rules) {
		return false
	}
	if box.border.top != 0 || box.border.bottom != 0 || box.padding.top != 0 || box.padding.bottom != 0 || box.height != 0 || box.lines.len != 0 {
		return false
	}
	return block_child_elements(element.as_node(), author_rules).len == 0
}

// Lay out a floated `element` at the local origin, sized shrink-to-fit when its width is auto (else
// per the box model), within a `content_width`-wide containing block. Returned box is placed later.
fn layout_float(element &dom.Element, content_width f64, author_rules []&css.CSSRule) BlockBox {
	available_width := if size_is_auto(element, 'width', author_rules) {
		edges := horizontal_edges(element, content_width, author_rules)
		fit := shrink_to_fit(intrinsic_content_width(element, author_rules, true), intrinsic_content_width(element, author_rules, false), non_negative(content_width - edges))
		fit + edges
	} else {
		content_width
	}
	return layout_block(element, 0.0, 0.0, available_width, author_rules)
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

// Place one floated box at the highest y at or below its normal-flow opportunity where its margin
// box fits between every overlapping earlier float.
fn place_float(element &dom.Element, minimum_y f64, content_x f64, content_width f64, bands []FloatBand, author_rules []&css.CSSRule) (BlockBox, FloatBand) {
	mut box := layout_float(element, content_width, author_rules)
	margin_box_width := box.margin_box_width()
	margin_box_height := box.margin_box_height()
	mut float_y := minimum_y
	mut available_left := content_x
	mut available_right := content_x + content_width
	for {
		available_left = content_x
		available_right = content_x + content_width
		mut next_y := f64(1.7976931348623157e308)
		for band in bands {
			if band.bottom <= float_y || band.top >= float_y + margin_box_height {
				continue
			}
			if band.is_left && band.inner_edge > available_left {
				available_left = band.inner_edge
			} else if !band.is_left && band.inner_edge < available_right {
				available_right = band.inner_edge
			}
			if band.bottom > float_y && band.bottom < next_y {
				next_y = band.bottom
			}
		}
		if margin_box_width <= available_right - available_left || next_y > 1.0e307 {
			break
		}
		float_y = next_y
	}
	// The provisional box's margin-box origin (floats establish a BFC, so no collapse-through).
	current_margin_x := box.x - box.padding.left - box.border.left - box.margin.left
	current_margin_y := box.y - box.padding.top - box.border.top - box.margin.top
	is_left := float_side(element, author_rules) == 'left'
	margin_left := if is_left { available_left } else { available_right - margin_box_width }
	box = translate_block(box, margin_left - current_margin_x, float_y - current_margin_y)
	band := FloatBand{
		is_left: is_left
		top: float_y
		bottom: float_y + margin_box_height
		inner_edge: if is_left { margin_left + margin_box_width } else { margin_left }
	}
	return box, band
}

// The horizontal bounds [left, right] available to a line box spanning [`y`, `y + line_height`],
// after subtracting floats whose bands overlap it.
fn line_bounds(y f64, line_height f64, bands []FloatBand, content_x f64, content_width f64) (f64, f64) {
	mut left := content_x
	mut right := content_x + content_width
	for band in bands {
		if band.top < y + line_height && band.bottom > y { // overlaps the line's band
			if band.is_left {
				if band.inner_edge > left {
					left = band.inner_edge
				}
			} else if band.inner_edge < right {
				right = band.inner_edge
			}
		}
	}
	return left, if right > left {
		right
	} else {
		left
	}
}

// The nearest float bottom strictly below `y` (so a line that can't fit beside a float can drop to
// clear it). Returns `y` when no float extends below.
fn next_float_bottom(y f64, bands []FloatBand) f64 {
	mut best := y
	for band in bands {
		if band.bottom > y && (best == y || band.bottom < best) {
			best = band.bottom
		}
	}
	return best
}

// Greedily break `words` into lines that fit `content_width`, returning the used content width of
// each line. Each glyph is `glyph_width` wide and inter-word spaces `space_width` (no real font
// metrics). A word that doesn't fit on the current line starts a new one; a word wider than the whole
// line still takes its own line (unbreakable — matching `overflow-wrap: normal`, it overflows rather
// than splitting mid-word). With no room to wrap (`content_width <= 0`) everything is one line.
fn wrap_line_widths(words []string, content_width f64, glyph_width f64, space_width f64) []f64 {
	if words.len == 0 {
		return []f64{}
	}
	mut widths := []f64{}
	mut line_width := 0.0
	mut started := false
	for word in words {
		word_width := f64(word.runes().len) * glyph_width
		if !started {
			line_width = word_width
			started = true
			continue
		}
		if content_width > 0 && line_width + space_width + word_width > content_width {
			widths << line_width
			line_width = word_width // the word starts a fresh line
		} else {
			line_width += space_width + word_width
		}
	}
	widths << line_width
	return widths
}

// The number of lines `words` wrap to (0 when empty).
fn wrapped_line_count(words []string, content_width f64, glyph_width f64, space_width f64) int {
	return wrap_line_widths(words, content_width, glyph_width, space_width).len
}

// Shrink-to-fit width: min(max(min-content, available), max-content) (CSS 2.1 §10.3.7).
fn shrink_to_fit(min_content f64, max_content f64, available f64) f64 {
	preferred := if available < max_content { available } else { max_content }
	return if preferred > min_content { preferred } else { min_content }
}

// Horizontal margins + borders + padding of `element` (auto margins count as 0; percentages resolve
// against `containing_width`).
fn horizontal_edges(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) f64 {
	return used_length_or_zero(element, 'margin-left', containing_width, author_rules) + used_length_or_zero(element, 'margin-right', containing_width, author_rules) + used_border(element, 'left', author_rules) + used_border(element, 'right', author_rules) + used_length_or_zero(element, 'padding-left', containing_width, author_rules) + used_length_or_zero(element, 'padding-right', containing_width, author_rules)
}

fn horizontal_border_padding(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) f64 {
	return used_border(element, 'left', author_rules) + used_border(element, 'right', author_rules) + used_length_or_zero(element, 'padding-left', containing_width, author_rules) + used_length_or_zero(element, 'padding-right', containing_width, author_rules)
}

// The intrinsic width of a block's inline (text) content: the widest single word (min-content) or the
// widest unbroken segment — words + spaces on one line (max-content). Words are measured with their
// own element's font.
fn inline_intrinsic_width(element &dom.Element, author_rules []&css.CSSRule, minimum bool) f64 {
	white_space := resolved_white_space_behavior(element, author_rules)
	segments := collect_inline_segments(element, white_space.preserves_newlines(), white_space.preserves_spaces(), 0.0, author_rules)
	mut widest := 0.0
	for segment in segments {
		if segment.len == 0 {
			continue
		}
		if minimum {
			for word in segment {
				if word.width > widest {
					widest = word.width
				}
			}
		} else {
			// max-content: the whole segment on one line (words + the spaces between them).
			mut total := segment[0].width
			for k := 1; k < segment.len; k++ {
				total += segment[k - 1].space_after + segment[k].width
			}
			if total > widest {
				widest = total
			}
		}
	}
	return widest
}

// The intrinsic *content* width of `element`: max-content (preferred, no wrapping) when `minimum` is
// false, min-content (narrowest without overflow) when true. A block with text measures its inline
// content; a block with block children takes the widest child's outer intrinsic width. A child with
// a definite length width contributes that (box-sizing aware); otherwise it recurses.
fn intrinsic_content_width(element &dom.Element, author_rules []&css.CSSRule, minimum bool) f64 {
	block_children := block_child_elements(element.as_node(), author_rules)
	if block_children.len == 0 {
		return inline_intrinsic_width(element, author_rules, minimum)
	}
	mut widest := 0.0
	for child in block_children {
		outer := horizontal_edges(child, 0.0, author_rules) + child_intrinsic_content_width(child, author_rules, minimum)
		if outer > widest {
			widest = outer
		}
	}
	return widest
}

// A child's contribution to its parent's intrinsic width: its definite length width if it has one
// (box-sizing aware), else its recursively computed intrinsic content width.
fn child_intrinsic_content_width(element &dom.Element, author_rules []&css.CSSRule, minimum bool) f64 {
	width_id := css.property_id_from_string('width') or {
		return intrinsic_content_width(element, author_rules, minimum)
	}
	if px := css.computed_length_px(element, width_id, author_rules) {
		if box_sizing_is_border_box(element, author_rules) {
			border_padding := used_border(element, 'left', author_rules) + used_border(element, 'right', author_rules) + used_length_or_zero(element, 'padding-left', 0.0, author_rules) + used_length_or_zero(element, 'padding-right', 0.0, author_rules)
			return non_negative(px - border_padding)
		}
		return px
	}
	return intrinsic_content_width(element, author_rules, minimum)
}

struct WhiteSpaceBehavior {
	collapse string
	wrap     string
	trim     string
}

fn white_space_behavior_from_longhands(collapse string, wrap string, trim string) WhiteSpaceBehavior {
	return WhiteSpaceBehavior{
		collapse: collapse
		wrap: wrap
		trim: trim
	}
}

// CSS correctly expands `white-space` into its longhands. Layout consumes the
// cascaded longhands so both shorthand and direct-longhand rules have identical
// observable behavior. (`white-space-trim` itself is not inherited.)
fn resolved_white_space_behavior(element &dom.Element, author_rules []&css.CSSRule) WhiteSpaceBehavior {
	collapse := css.cascaded_value_with_ua(element, .white_space_collapse, author_rules)
	wrap := css.cascaded_value_with_ua(element, .text_wrap_mode, author_rules)
	trim := css.cascaded_value_with_ua(element, .white_space_trim, author_rules)
	return white_space_behavior_from_longhands(collapse, wrap, trim)
}

fn (white_space WhiteSpaceBehavior) wraps() bool {
	return white_space.wrap != 'nowrap'
}

fn (white_space WhiteSpaceBehavior) preserves_spaces() bool {
	return white_space.collapse in ['preserve', 'preserve-spaces', 'break-spaces']
}

fn (white_space WhiteSpaceBehavior) preserves_newlines() bool {
	return white_space.collapse in ['preserve', 'preserve-breaks', 'break-spaces']
}

// A `letter-spacing`/`word-spacing` value resolved to px (may be negative). `normal` (the initial) and
// unresolved keywords give 0; lengths (incl. em/rem, resolved against the element's font) give px.
fn resolve_spacing(element &dom.Element, property_name string, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string(property_name) or { return 0 }
	return css.computed_length_px(element, id, author_rules) or { 0 }
}

// Resolve a single length/percentage TOKEN (px/em/rem/%, possibly negative) to px against `basis`
// (used for `%`). Returns 0 for an unrecognized token. Used for properties whose value-logic wraps
// the length in a composite type — text-indent, border-radius corners — that `computed_length_px`
// can't extract, so the cascaded string is parsed directly.
fn resolve_length_token(element &dom.Element, token string, basis f64, author_rules []&css.CSSRule) f64 {
	return css.resolve_length_percentage_text_px(element, token, basis, author_rules) or { 0.0 }
}

// The `text-indent` value resolved to px (may be negative). `%` is of the content width.
fn resolve_text_indent(element &dom.Element, content_width f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('text-indent') or { return 0 }
	return resolve_length_token(element, css.cascaded_value_with_ua(element, id, author_rules), content_width, author_rules)
}

fn resolve_text_decoration_thickness(element &dom.Element, font_size f64, author_rules []&css.CSSRule) f64 {
	id := css.property_id_from_string('text-decoration-thickness') or { return 0 }
	value := css.cascaded_value_with_ua(element, id, author_rules).trim_space()
	if value == '' || value == 'auto' || value == 'from-font' {
		return 0
	}
	return non_negative(resolve_length_token(element, value, font_size, author_rules))
}

fn resolve_corner_radius(element &dom.Element, property_name string, width f64, height f64, author_rules []&css.CSSRule) CornerRadius {
	id := css.property_id_from_string(property_name) or { return CornerRadius{} }
	tokens := split_top_level(css.cascaded_value_with_ua(element, id, author_rules), ` `)
	if tokens.len == 0 {
		return CornerRadius{}
	}
	x := non_negative(resolve_length_token(element, tokens[0], width, author_rules))
	y := if tokens.len > 1 {
		non_negative(resolve_length_token(element, tokens[1], height, author_rules))
	} else {
		non_negative(resolve_length_token(element, tokens[0], height, author_rules))
	}
	return CornerRadius{x, y}
}

fn scale_corner_radius(radius CornerRadius, factor f64) CornerRadius {
	return CornerRadius{radius.x * factor, radius.y * factor}
}

fn normalize_box_radii(radii BoxRadii, width f64, height f64) BoxRadii {
	mut factor := 1.0
	available_sizes := [width, width, height, height]
	radius_sums := [radii.top_left.x + radii.top_right.x, radii.bottom_left.x + radii.bottom_right.x,
		radii.top_left.y + radii.bottom_left.y, radii.top_right.y + radii.bottom_right.y]
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

fn resolve_box_radii(element &dom.Element, width f64, height f64, author_rules []&css.CSSRule) BoxRadii {
	return normalize_box_radii(BoxRadii{
		top_left: resolve_corner_radius(element, 'border-top-left-radius', width, height, author_rules)
		top_right: resolve_corner_radius(element, 'border-top-right-radius', width, height, author_rules)
		bottom_right: resolve_corner_radius(element, 'border-bottom-right-radius', width, height, author_rules)
		bottom_left: resolve_corner_radius(element, 'border-bottom-left-radius', width, height, author_rules)
	}, width, height)
}

// Split `s` on `sep`, keeping parenthesized groups (e.g. `rgb(0, 0, 0)`) intact and trimming/dropping
// empty pieces. Used to tokenize a `box-shadow` value without breaking its color function.
fn split_top_level(s string, sep u8) []string {
	mut tokens := []string{}
	mut depth := 0
	mut cur := []u8{}
	for c in s {
		if c == `(` {
			depth++
		} else if c == `)` && depth > 0 {
			depth--
		}
		if c == sep && depth == 0 {
			tokens << cur.bytestr().trim_space()
			cur = []u8{}
		} else {
			cur << c
		}
	}
	tokens << cur.bytestr().trim_space()
	return tokens.filter(it != '')
}

// Whether `token` is a length/number (starts with a digit or sign/dot) rather than a color (which
// starts with a letter or `#`). A clean discriminator for box-shadow's mixed token list.
fn is_length_token(token string) bool {
	if token.len == 0 {
		return false
	}
	c := token[0]
	return c == `-` || c == `+` || c == `.` || (c >= `0` && c <= `9`)
}

fn parse_box_shadow_part(element &dom.Element, value string, author_rules []&css.CSSRule) ?BoxShadow {
	inset := split_top_level(value, ` `).any(it == 'inset')
	mut lengths := []f64{}
	mut color := css.Color{0, 0, 0, 255}
	for token in split_top_level(value, ` `) {
		if is_length_token(token) {
			lengths << resolve_length_token(element, token, 0.0, author_rules)
		} else if parsed_color := css.parse_color_string(token) {
			color = parsed_color
		}
	}
	if lengths.len < 2 {
		return none
	}
	return BoxShadow{
		offset_x: lengths[0]
		offset_y: lengths[1]
		blur: if lengths.len > 2 { non_negative(lengths[2]) } else { 0.0 }
		spread: if lengths.len > 3 { lengths[3] } else { 0.0 }
		color: color
		inset: inset
	}
}

// Parse every outer shadow in `element`'s comma-separated `box-shadow` value.
fn parse_box_shadows(element &dom.Element, author_rules []&css.CSSRule) []BoxShadow {
	id := css.property_id_from_string('box-shadow') or { return []BoxShadow{} }
	value := css.cascaded_value_with_ua(element, id, author_rules).trim_space()
	if value == '' || value == 'none' {
		return []BoxShadow{}
	}
	mut shadows := []BoxShadow{}
	for part in split_top_level(value, `,`) {
		if shadow := parse_box_shadow_part(element, part, author_rules) {
			shadows << shadow
		}
	}
	return shadows
}

fn parse_box_shadow(element &dom.Element, author_rules []&css.CSSRule) ?BoxShadow {
	shadows := parse_box_shadows(element, author_rules)
	return if shadows.len > 0 { shadows[0] } else { none }
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

fn parse_gradient_stop_offset(token string) ?f64 {
	value := token.trim_space().to_lower()
	if value.ends_with('%') {
		return value[..value.len - 1].f64() / 100.0
	}
	if value == '0' {
		return 0.0
	}
	return none
}

// Parse color stops, including one- and two-position stops, then run CSS Images' fix-up algorithm:
// omitted first/last positions become 0/1, decreasing positions are clamped, and consecutive omitted
// positions are evenly distributed between their neighbors.
fn parse_gradient_stops(args []string) ?ParsedGradientStops {
	mut raw_colors := []css.Color{}
	mut raw_offsets := []f64{}
	for arg in args {
		tokens := split_top_level(arg, ` `)
		if tokens.len == 0 {
			continue
		}
		if c := css.parse_color_string(tokens[0]) {
			mut offsets := []f64{}
			for token in tokens[1..] {
				if offset := parse_gradient_stop_offset(token) {
					offsets << offset
				}
			}
			if offsets.len == 0 {
				raw_colors << c
				raw_offsets << -1.0
			} else {
				// A two-position color stop is equivalent to two stops with the same color.
				limit := if offsets.len > 2 { 2 } else { offsets.len }
				for offset in offsets[..limit] {
					raw_colors << c
					raw_offsets << offset
				}
			}
		}
	}
	if raw_colors.len < 2 {
		return none
	}
	if raw_offsets[0] < 0 {
		raw_offsets[0] = 0.0
	}
	if raw_offsets[raw_offsets.len - 1] < 0 {
		raw_offsets[raw_offsets.len - 1] = 1.0
	}
	mut previous := raw_offsets[0]
	for index := 1; index < raw_offsets.len; index++ {
		if raw_offsets[index] >= 0 {
			if raw_offsets[index] < previous {
				raw_offsets[index] = previous
			}
			previous = raw_offsets[index]
		}
	}
	mut index := 1
	for index < raw_offsets.len - 1 {
		if raw_offsets[index] >= 0 {
			index++
			continue
		}
		start := index - 1
		mut end := index + 1
		for end < raw_offsets.len && raw_offsets[end] < 0 {
			end++
		}
		step := (raw_offsets[end] - raw_offsets[start]) / f64(end - start)
		for missing := index; missing < end; missing++ {
			raw_offsets[missing] = raw_offsets[start] + step * f64(missing - start)
		}
		index = end
	}
	mut stops := []GradientStop{cap: raw_colors.len}
	for stop_index, color in raw_colors {
		stops << GradientStop{
			color: color
			offset: raw_offsets[stop_index]
		}
	}
	return ParsedGradientStops{
		colors: raw_colors
		stops: stops
	}
}

fn parse_gradient_angle(value string) ?f64 {
	v := value.trim_space().to_lower()
	if v.ends_with('deg') {
		return v[..v.len - 3].f64()
	}
	if v.ends_with('grad') {
		return v[..v.len - 4].f64() * 0.9
	}
	if v.ends_with('rad') {
		return v[..v.len - 3].f64() * 180.0 / math.pi
	}
	if v.ends_with('turn') {
		return v[..v.len - 4].f64() * 360.0
	}
	if v == '0' {
		return 0.0
	}
	return none
}

fn gradient_vector_from_delta(dx f64, dy f64) (f64, f64, f64, f64) {
	largest := math.max(math.abs(dx), math.abs(dy))
	if largest == 0 {
		return 0.0, 0.0, 0.0, 1.0
	}
	half_scale := 0.5 / largest
	return 0.5 - dx * half_scale, 0.5 - dy * half_scale, 0.5 + dx * half_scale, 0.5 + dy * half_scale
}

// Parse a `linear-gradient(...)` value, including side/corner directions, CSS angle units, and
// explicit/implicit color-stop positions.
fn parse_linear_gradient(value string) ?LinearGradient {
	v := value.trim_space()
	if !v.starts_with('linear-gradient(') || !v.ends_with(')') {
		return none
	}
	mut args := split_top_level(v['linear-gradient('.len..v.len - 1], `,`)
	if args.len < 2 {
		return none
	}
	// Direction (default top -> bottom).
	mut x1 := 0.0
	mut y1 := 0.0
	mut x2 := 0.0
	mut y2 := 1.0
	first := args[0].trim_space().to_lower()
	if first.starts_with('to ') {
		words := first['to '.len..].fields()
		mut dx := 0.0
		mut dy := 0.0
		if 'left' in words {
			dx = -1
		}
		if 'right' in words {
			dx = 1
		}
		if 'top' in words {
			dy = -1
		}
		if 'bottom' in words {
			dy = 1
		}
		if dy == 0 && dx != 0 {
			x1, y1, x2, y2 = if dx > 0 { 0.0, 0.0, 1.0, 0.0 } else { 1.0, 0.0, 0.0, 0.0 }
		} else if dx == 0 && dy != 0 {
			x1, y1, x2, y2 = if dy > 0 { 0.0, 0.0, 0.0, 1.0 } else { 0.0, 1.0, 0.0, 0.0 }
		} else {
			x1, y1, x2, y2 = gradient_vector_from_delta(dx, dy)
		}
		args = args[1..].clone()
	} else if degrees := parse_gradient_angle(first) {
		radians := degrees * math.pi / 180.0
		x1, y1, x2, y2 = gradient_vector_from_delta(math.sin(radians), -math.cos(radians))
		args = args[1..].clone()
	}
	parsed := parse_gradient_stops(args)?
	return LinearGradient{
		x1: x1
		y1: y1
		x2: x2
		y2: y2
		colors: parsed.colors
		stops: parsed.stops
	}
}

fn gradient_position_component(token string, horizontal bool) ?f64 {
	value := token.trim_space().to_lower()
	if percentage := parse_gradient_stop_offset(value) {
		return percentage
	}
	return match value {
		'left' {
			if horizontal {
				0.0
			} else {
				none
			}
		}
		'top' {
			if !horizontal {
				0.0
			} else {
				none
			}
		}
		'center' {
			0.5
		}
		'right' {
			if horizontal {
				1.0
			} else {
				none
			}
		}
		'bottom' {
			if !horizontal {
				1.0
			} else {
				none
			}
		}
		else {
			none
		}
	}
}

// Parse a `radial-gradient(...)` value, including shape, extent keyword, position, and color stops.
fn parse_radial_gradient(value string) ?LinearGradient {
	v := value.trim_space()
	if !v.starts_with('radial-gradient(') || !v.ends_with(')') {
		return none
	}
	mut args := split_top_level(v['radial-gradient('.len..v.len - 1], `,`)
	if args.len < 2 {
		return none
	}
	mut center_x := 0.5
	mut center_y := 0.5
	mut radius_x := 0.5
	mut radius_y := 0.5
	mut extent := 'farthest-corner'
	mut shape := 'ellipse'
	// If the first arg isn't a color, parse the shape/size/position configuration.
	first_tokens := split_top_level(args[0], ` `)
	mut first_is_color := false
	if first_tokens.len > 0 {
		if _ := css.parse_color_string(first_tokens[0]) {
			first_is_color = true
		}
	}
	if !first_is_color {
		mut at_index := -1
		for token_index, token in first_tokens {
			lower := token.to_lower()
			if lower == 'circle' || lower == 'ellipse' {
				shape = lower
			} else if lower in ['closest-side', 'farthest-side', 'closest-corner', 'farthest-corner'] {
				extent = lower
			} else if lower == 'at' {
				at_index = token_index
			}
		}
		if at_index >= 0 && at_index + 1 < first_tokens.len {
			position_tokens := first_tokens[at_index + 1..]
			if position_tokens.len == 1 {
				if parsed := gradient_position_component(position_tokens[0], true) {
					center_x = parsed
				}
			} else {
				if parsed := gradient_position_component(position_tokens[0], true) {
					center_x = parsed
				}
				if parsed := gradient_position_component(position_tokens[1], false) {
					center_y = parsed
				}
			}
		}
		if extent.starts_with('closest') {
			radius_x = math.min(center_x, 1.0 - center_x)
			radius_y = math.min(center_y, 1.0 - center_y)
		} else {
			radius_x = math.max(center_x, 1.0 - center_x)
			radius_y = math.max(center_y, 1.0 - center_y)
		}
		if shape == 'circle' {
			radius := if extent.contains('closest') {
				math.min(radius_x, radius_y)
			} else {
				math.max(radius_x, radius_y)
			}
			radius_x = radius
			radius_y = radius
		}
		args = args[1..].clone()
	}
	parsed := parse_gradient_stops(args)?
	return LinearGradient{
		colors: parsed.colors
		stops: parsed.stops
		radial: true
		kind: 'radial'
		center_x: center_x
		center_y: center_y
		radius_x: radius_x
		radius_y: radius_y
	}
}

fn parse_conic_gradient(value string) ?LinearGradient {
	v := value.trim_space()
	if !v.starts_with('conic-gradient(') || !v.ends_with(')') {
		return none
	}
	mut args := split_top_level(v['conic-gradient('.len..v.len - 1], `,`)
	if args.len < 2 {
		return none
	}
	mut center_x := 0.5
	mut center_y := 0.5
	mut start_degrees := 0.0
	first_tokens := split_top_level(args[0], ` `)
	mut first_is_color := false
	if first_tokens.len > 0 {
		if _ := css.parse_color_string(first_tokens[0]) {
			first_is_color = true
		}
	}
	if !first_is_color {
		mut token_index := 0
		for token_index < first_tokens.len {
			if first_tokens[token_index] == 'from' && token_index + 1 < first_tokens.len {
				start_degrees = parse_gradient_angle(first_tokens[token_index + 1]) or { 0.0 }
				token_index += 2
				continue
			}
			if first_tokens[token_index] == 'at' && token_index + 1 < first_tokens.len {
				center_x = gradient_position_component(first_tokens[token_index + 1], true) or {
					0.5
				}
				if token_index + 2 < first_tokens.len {
					center_y = gradient_position_component(first_tokens[token_index + 2], false) or {
						0.5
					}
				}
				break
			}
			token_index++
		}
		args = args[1..].clone()
	}
	parsed := parse_gradient_stops(args)?
	return LinearGradient{
		colors: parsed.colors
		stops: parsed.stops
		kind: 'conic'
		center_x: center_x
		center_y: center_y
		start_degrees: start_degrees
	}
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

pub fn gradient_color_at(gradient LinearGradient, position f64) css.Color {
	stops := gradient_stops_or_fallback(gradient)
	if stops.len == 0 {
		return css.Color{0, 0, 0, 0}
	}
	if stops.len == 1 {
		return stops[0].color
	}
	minimum := stops[0].offset
	maximum := stops[stops.len - 1].offset
	p := if position < minimum {
		minimum
	} else if position > maximum {
		maximum
	} else {
		position
	}
	mut right := 1
	for right < stops.len && stops[right].offset < p {
		right++
	}
	if right >= stops.len {
		return stops[stops.len - 1].color
	}
	left := stops[right - 1]
	next := stops[right]
	span := next.offset - left.offset
	t := if span > 0 { (p - left.offset) / span } else { 1.0 }
	method := gradient.interpolation_method or {
		css.ColorInterpolationMethod(css.RectangularColorSpace.srgb)
	}
	return css.interpolate_gradient_color(left.color, next.color, t, method)
}

// CoreGraphics only interpolates the component values supplied to CGGradient. Sample each
// resolved CSS stop span so the native one-draw gradient path retains Skia's premultiplied-alpha
// and non-sRGB interpolation semantics. Original stop boundaries are kept (including duplicate
// positions), so hard color transitions remain hard instead of being spread over a sample.
pub fn sampled_gradient_stops(gradient LinearGradient, subdivisions int) []GradientStop {
	source := gradient_stops_or_fallback(gradient)
	if source.len == 0 {
		return []
	}
	if source.len == 1 {
		return [GradientStop{source[0].color, 0.0}, GradientStop{source[0].color, 1.0}]
	}

	steps := math.max(subdivisions, 1)
	mut sampled := []GradientStop{cap: (source.len - 1) * steps + 2}
	sampled << GradientStop{
		color: gradient_color_at(gradient, 0.0)
		offset: 0.0
	}
	for index := 1; index < source.len; index++ {
		left := source[index - 1]
		right := source[index]
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
	return sampled
}

// The `linear-gradient`/`radial-gradient` background image of `element`, or none when background-image
// isn't a gradient.
fn parse_background_gradient(element &dom.Element, author_rules []&css.CSSRule) ?LinearGradient {
	id := css.property_id_from_string('background-image') or { return none }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	if g := parse_linear_gradient(value) {
		return g
	}
	if g := parse_radial_gradient(value) {
		return g
	}
	return parse_conic_gradient(value)
}

fn coordinated_background_value(element &dom.Element, property css.PropertyID, index int, fallback string, author_rules []&css.CSSRule) string {
	values := split_top_level(css.cascaded_value_with_ua(element, property, author_rules), `,`)
	if values.len == 0 {
		return fallback
	}
	return values[index % values.len]
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

// Resolve every non-gradient `<image>` layer into renderer-facing background metadata. Image bytes
// and intrinsic dimensions intentionally remain a renderer/resource-loader responsibility, just as
// they do in upstream Layout.
fn parse_background_image_layers(element &dom.Element, author_rules []&css.CSSRule) []BackgroundImageLayer {
	value := css.cascaded_value_with_ua(element, .background_image, author_rules)
	mut layers := []BackgroundImageLayer{}
	for index, item in split_top_level(value, `,`) {
		parsed := css.parse_css_image_value_logic(item) or { continue }
		if parsed !is css.ImageStyleValue {
			continue
		}
		source := parsed.url_.url()
		resolved_url := element.document().encoding_parse_and_serialize_url(source) or { source }
		repeat_x, repeat_y := parsed_background_repeat(coordinated_background_value(element, .background_repeat, index, 'repeat', author_rules))
		layers << BackgroundImageLayer{
			url: resolved_url
			repeat_x: repeat_x
			repeat_y: repeat_y
			size: coordinated_background_value(element, .background_size, index, 'auto', author_rules)
			position_x: coordinated_background_value(element, .background_position_x, index, '0%', author_rules)
			position_y: coordinated_background_value(element, .background_position_y, index, '0%', author_rules)
			origin: coordinated_background_value(element, .background_origin, index, 'padding-box', author_rules)
			clip: coordinated_background_value(element, .background_clip, index, 'border-box', author_rules)
			attachment: coordinated_background_value(element, .background_attachment, index, 'scroll', author_rules)
		}
	}
	return layers
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

fn inline_text_tokens(text string, preserve_spaces bool) []InlineTextToken {
	if !preserve_spaces {
		words := text.fields()
		mut collapsed := []InlineTextToken{}
		for index, word in words {
			collapsed << InlineTextToken{
				text: word
				separator: if index + 1 < words.len { ' ' } else { '' }
			}
		}
		return collapsed
	}
	mut tokens := []InlineTextToken{}
	mut word := ''
	mut whitespace := ''
	for character in text.runes() {
		piece := character.str()
		if piece in [' ', '\t', '\r', '\f'] {
			if word != '' {
				tokens << InlineTextToken{
					text: word
				}
				word = ''
			}
			whitespace += piece
			continue
		}
		if whitespace != '' {
			if tokens.len == 0 {
				tokens << InlineTextToken{
					text: ''
					separator: whitespace
				}
			} else {
				tokens[tokens.len - 1].separator = whitespace
			}
			whitespace = ''
		}
		word += piece
	}
	if word != '' {
		tokens << InlineTextToken{
			text: word
		}
	}
	if whitespace != '' {
		if tokens.len == 0 {
			tokens << InlineTextToken{
				text: ''
				separator: whitespace
			}
		} else {
			tokens[tokens.len - 1].separator = whitespace
		}
	}
	return tokens
}

fn inline_separator_width(separator string, space_width f64, tab_size f64) f64 {
	mut width := 0.0
	for character in separator.runes() {
		width += if character == `\t` { space_width * tab_size } else { space_width }
	}
	return width
}

fn collect_inline_segments(element &dom.Element, preserve_newlines bool, preserve_spaces bool, containing_width f64, author_rules []&css.CSSRule) [][]InlineWord {
	mut segments := [[]InlineWord{}]
	append_inline_words(element, preserve_newlines, preserve_spaces, containing_width, author_rules, mut segments)
	return segments
}

fn append_inline_words(element &dom.Element, preserve_newlines bool, preserve_spaces bool, containing_width f64, author_rules []&css.CSSRule, mut segments [][]InlineWord) {
	display_id := css.property_id_from_string('display') or { return }
	display := css.cascaded_value_with_ua(element, display_id, author_rules)
	font_size := css.computed_font_size_px(element, author_rules)
	line_height := css.computed_line_height_px(element, author_rules)
	color := css.computed_color(element, css.property_id_from_string('color') or { return }, author_rules) or { css.Color{0, 0, 0, 255} }
	// `text-transform` (inherited) upper/lower/capitalizes this element's own text runs.
	text_transform := css.cascaded_value_with_ua(element, css.property_id_from_string('text-transform') or {
		return
	}, author_rules)
	// `text-decoration-line` (inherited in this port's metadata, matching the decorating-box
	// propagation) underlines/strikes/overlines this element's text runs.
	decoration := css.cascaded_value_with_ua(element, css.property_id_from_string('text-decoration-line') or {
		return
	}, author_rules)
	decoration_color := css.computed_color(element, .text_decoration_color, author_rules) or {
		color
	}
	decoration_style := css.cascaded_value_with_ua(element, .text_decoration_style, author_rules)
	decoration_thickness := resolve_text_decoration_thickness(element, font_size, author_rules)
	// `letter-spacing`/`word-spacing` (both inherited, `normal` = 0): letter-spacing widens each glyph
	// advance; word-spacing widens the inter-word gap.
	letter_spacing := resolve_spacing(element, 'letter-spacing', author_rules)
	word_spacing := resolve_spacing(element, 'word-spacing', author_rules)
	font_weight := css.cascaded_value_with_ua(element, css.property_id_from_string('font-weight') or {
		return
	}, author_rules)
	font_style := css.cascaded_value_with_ua(element, css.property_id_from_string('font-style') or {
		return
	}, author_rules)
	font_family := css.cascaded_value_with_ua(element, css.property_id_from_string('font-family') or {
		return
	}, author_rules).to_lower()
	weight_number := font_weight.int()
	bold := font_weight in ['bold', 'bolder'] || weight_number >= 600
	italic := font_style == 'italic' || font_style.starts_with('oblique')
	mono := font_family.contains('monospace')
	font := &platform.Font{
		family: if mono { 'monospace' } else { 'sans-serif' }
		point_size: f32(font_size)
		weight: if bold { 700 } else { 400 }
	}
	space_advance := f64(platform.shape_text(0, f32(letter_spacing), ' ', font, .ltr).width())
	tab_size_value := css.cascaded_value_with_ua(element, css.property_id_from_string('tab-size') or {
		return
	}, author_rules)
	tab_size := if tab_size_value.f64() > 0 { tab_size_value.f64() } else { 8.0 }
	shape_as_run := letter_spacing == 0.0 && word_spacing == 0.0
	// Only inline-level elements generate inline decorating boxes here. The initial block passed to
	// this function already paints its background/border through BlockBox.
	is_inline := display == 'inline'
	inline_node_id := if is_inline { i64(element.as_node().unique_id()) } else { i64(0) }
	background_color := if is_inline {
		css.computed_color(element, css.property_id_from_string('background-color') or { return }, author_rules) or { css.Color{0, 0, 0, 0} }
	} else {
		css.Color{0, 0, 0, 0}
	}
	border := if is_inline {
		BoxEdges{
			top: used_border(element, 'top', author_rules)
			right: used_border(element, 'right', author_rules)
			bottom: used_border(element, 'bottom', author_rules)
			left: used_border(element, 'left', author_rules)
		}
	} else {
		BoxEdges{}
	}
	border_color := if is_inline {
		css.computed_color(element, css.property_id_from_string('border-top-color') or { return }, author_rules) or { color }
	} else {
		css.Color{0, 0, 0, 0}
	}
	border_colors := if is_inline {
		resolved_border_colors(element, color, author_rules)
	} else {
		BoxColors{}
	}
	border_styles := if is_inline {
		resolved_border_styles(element, author_rules)
	} else {
		solid_box_border_styles()
	}
	border_radii := if is_inline {
		resolve_box_radii(element, containing_width, line_height, author_rules)
	} else {
		BoxRadii{}
	}
	border_radius := border_radii.top_left.x
	mut shadow := ?BoxShadow(none)
	mut shadows := []BoxShadow{}
	if is_inline {
		shadows = parse_box_shadows(element, author_rules)
		if shadows.len > 0 {
			shadow = shadows[0]
		}
	}
	for child in element.as_node().children_as_vector() {
		if child.is_text() {
			data := unsafe { &dom.Text(child) }.data()
			text_run_id := i64(child.unique_id())
			parts := if preserve_newlines { data.split('\n') } else { [data] }
			for i, part in parts {
				if i > 0 {
					segments << []InlineWord{} // a preserved newline starts a new segment
				}
				tokens := inline_text_tokens(part, preserve_spaces)
				space_width := space_advance + word_spacing
				if !preserve_spaces && starts_with_collapsible_space(part) && segments[segments.len - 1].len > 0 {
					last_index := segments[segments.len - 1].len - 1
					segments[segments.len - 1][last_index].space_after = space_width
					segments[segments.len - 1][last_index].separator_after = ' '
				}
				for token in tokens {
					transformed := apply_text_transform(token.text, text_transform)
					separator_width := inline_separator_width(token.separator, space_width, tab_size)
					segments[segments.len - 1] << InlineWord{
						text: transformed
						width: f64(platform.shape_text(0, f32(letter_spacing), transformed, font, .ltr).width())
						space_after: separator_width
						separator_after: token.separator
						preserves_spaces: preserve_spaces
						height: line_height
						color: color
						font_size: font_size
						bold: bold
						italic: italic
						mono: mono
						text_run_id: text_run_id
						shape_as_run: shape_as_run
						inline_node_id: inline_node_id
						background_color: background_color
						border: border
						border_color: border_color
						border_colors: border_colors
						border_styles: border_styles
						border_radius: border_radius
						border_radii: border_radii
						shadow: shadow
						shadows: shadows.clone()
						decoration: decoration
						decoration_color: decoration_color
						decoration_color_set: true
						decoration_style: decoration_style
						decoration_thickness: decoration_thickness
					}
				}
				if !preserve_spaces && ends_with_collapsible_space(part) && segments[segments.len - 1].len > 0 {
					last_index := segments[segments.len - 1].len - 1
					segments[segments.len - 1][last_index].space_after = space_width
					segments[segments.len - 1][last_index].separator_after = ' '
				}
			}
		} else if el := child.as_element() {
			child_display := css.cascaded_value_with_ua(el, display_id, author_rules)
			if child_display == 'none' {
				continue
			}
			position := position_value(el, author_rules)
			if is_absolutely_positioned(position) {
				previous_sibling_id := if previous := el.as_node().previous_sibling() {
					i64(previous.unique_id())
				} else {
					i64(0)
				}
				segments[segments.len - 1] << InlineWord{
					positioned_node_id: i64(el.as_node().unique_id())
					positioned_fixed: position == 'fixed'
					positioned_block_outside: is_block_level_display(child_display)
					positioned_previous_sibling_id: previous_sibling_id
				}
				continue
			}
			if is_floating(el, author_rules) {
				// out of flow — its text is its own content, not the container's
				continue
			}
			if el.local_name() == 'br' {
				segments << []InlineWord{} // forced line break starts a new segment
			} else if child_display == 'inline-block' {
				// An atomic inline: lay the box out (auto width -> shrink to max-content) and add it as a
				// single item that occupies its margin box on the line.
				forced := if size_is_auto(el, 'width', author_rules) {
					?f64(intrinsic_content_width(el, author_rules, false))
				} else {
					?f64(none)
				}
				box := layout_block_impl(el, 0, 0, containing_width, forced, author_rules)
				segments[segments.len - 1] << InlineWord{
					width: box.margin_box_width()
					space_after: 0.0
					height: box.margin_box_height()
					color: color
					font_size: font_size
					bold: bold
					italic: italic
					mono: mono
					box: box
				}
			} else {
				append_inline_words(el, preserve_newlines, preserve_spaces, containing_width, author_rules, mut segments)
			}
		}
	}
}

fn is_collapsible_space(byte u8) bool {
	return byte in [` `, `\t`, `\n`, `\r`, `\f`]
}

fn starts_with_collapsible_space(text string) bool {
	return text.len > 0 && is_collapsible_space(text[0])
}

fn ends_with_collapsible_space(text string) bool {
	return text.len > 0 && is_collapsible_space(text[text.len - 1])
}

// Apply the CSS `text-transform` keywords to a rendered text run. Case mapping is followed by the
// optional full-width and full-size-kana transformations.
fn apply_text_transform(text string, transform string) string {
	keywords := transform.fields()
	mut result := if 'uppercase' in keywords {
		text.to_upper()
	} else if 'lowercase' in keywords {
		text.to_lower()
	} else if 'capitalize' in keywords {
		capitalize_first_letter(text)
	} else {
		text
	}
	if 'full-width' in keywords {
		result = full_width_text(result)
	}
	if 'full-size-kana' in keywords {
		result = full_size_kana_text(result)
	}
	return result
}

// Uppercase the first Unicode letter of `word`, leaving leading punctuation and the rest unchanged.
fn capitalize_first_letter(word string) string {
	if word.len == 0 {
		return word
	}
	runes := word.runes()
	for index, character in runes {
		if utf8.is_letter(character) {
			return runes[..index].string() + character.str().to_upper() + runes[index + 1..].string()
		}
	}
	return word
}

fn full_width_text(text string) string {
	mut result := []rune{}
	for character in text.runes() {
		if character == rune(0x20) {
			result << rune(0x3000)
		} else if character >= rune(0x21) && character <= rune(0x7e) {
			result << rune(0xff01 + int(character - rune(0x21)))
		} else {
			result << character
		}
	}
	return result.string()
}

fn full_size_kana_text(text string) string {
	mut result := []rune{}
	for character in text.runes() {
		result << match character {
			`ぁ` { `あ` }
			`ぃ` { `い` }
			`ぅ` { `う` }
			`ぇ` { `え` }
			`ぉ` { `お` }
			`っ` { `つ` }
			`ゃ` { `や` }
			`ゅ` { `ゆ` }
			`ょ` { `よ` }
			`ゎ` { `わ` }
			`ゕ` { `か` }
			`ゖ` { `け` }
			`ァ` { `ア` }
			`ィ` { `イ` }
			`ゥ` { `ウ` }
			`ェ` { `エ` }
			`ォ` { `オ` }
			`ッ` { `ツ` }
			`ャ` { `ヤ` }
			`ュ` { `ユ` }
			`ョ` { `ヨ` }
			`ヮ` { `ワ` }
			`ヵ` { `カ` }
			`ヶ` { `ケ` }
			`ㇰ` { `ク` }
			`ㇱ` { `シ` }
			`ㇲ` { `ス` }
			`ㇳ` { `ト` }
			`ㇴ` { `ヌ` }
			`ㇵ` { `ハ` }
			`ㇶ` { `ヒ` }
			`ㇷ` { `フ` }
			`ㇸ` { `ヘ` }
			`ㇹ` { `ホ` }
			`ㇺ` { `ム` }
			`ㇻ` { `ラ` }
			`ㇼ` { `リ` }
			`ㇽ` { `ル` }
			`ㇾ` { `レ` }
			`ㇿ` { `ロ` }
			else { character }
		}
	}
	return result.string()
}

// The `text-align`-adjusted left edge of a line whose content is `line_width` wide, within a content
// box that starts at `content_x` and is `content_width` wide. `center` centers it, `right`/`end` push
// it to the right edge; everything else (left/start/justify — no per-word justification yet) is left.
fn aligned_line_x(content_x f64, content_width f64, line_width f64, align string) f64 {
	return match align {
		'center' { content_x + (content_width - line_width) / 2.0 }
		'right', 'end' { content_x + content_width - line_width }
		else { content_x }
	}
}

// Lay out a block's inline (text) content as line boxes in a LOCAL frame (the first line's top at
// y = 0), to be translated to the content-box top by the caller. Content is split into segments at
// `<br>` (and, under `white-space: pre*`, at newlines); each segment wraps at word boundaries against
// `content_width` unless `white-space` forbids wrapping (`nowrap`/`pre`, in which case a segment is a
// single line). Every line is placed at `content_x` adjusted for `text-align`. An empty segment
// between breaks is still an (empty) line; truly empty content yields no lines.
//
// Line boxes flow around `float_bands`: each line uses the horizontal room left at its vertical
// position (offset past left floats, shortened by right floats), and a line whose first word can't
// fit beside a float drops below it.
//
// Each line carries shaped word fragments measured by the platform font contract; preserved-space
// modes retain their exact separators and tab advances. The base paragraph direction controls
// physical placement, while the renderer receives the logical run for its Unicode bidi shaper.
// Returns the text line boxes, atomic inline (`inline-block`) boxes, and the static positions retained
// for out-of-flow items. Geometry is in the content-box local vertical frame; the caller translates
// it to the final content-box top.
fn layout_inline_lines(element &dom.Element, content_x f64, content_width f64, float_bands []FloatBand, author_rules []&css.CSSRule) ([]TextLine, []BlockBox, map[i64]StaticPosition, map[i64]StaticPosition) {
	white_space := resolved_white_space_behavior(element, author_rules)

	raw_segments := collect_inline_segments(element, white_space.preserves_newlines(), white_space.preserves_spaces(), content_width, author_rules)
	mut positioned_requests := []InlineWord{}
	mut segments := [][]InlineWord{cap: raw_segments.len}
	mut has_inline_content := false
	for raw_segment in raw_segments {
		mut segment := []InlineWord{cap: raw_segment.len}
		for word in raw_segment {
			if word.positioned_node_id != 0 {
				positioned_requests << word
			} else {
				segment << word
				has_inline_content = true
			}
		}
		segments << segment
	}
	if !has_inline_content && positioned_requests.len == 0 {
		return []TextLine{}, []BlockBox{}, map[i64]StaticPosition{}, map[i64]StaticPosition{} // no inline content at all
	}
	if !has_inline_content {
		absolute_positions, fixed_positions := calculate_inline_static_positions(positioned_requests, content_x, []TextLine{}, []BlockBox{})
		return []TextLine{}, []BlockBox{}, absolute_positions, fixed_positions
	}

	block_line_height := css.computed_line_height_px(element, author_rules)
	align := css.cascaded_value_with_ua(element, css.property_id_from_string('text-align') or {
		return []TextLine{}, []BlockBox{}, map[i64]StaticPosition{}, map[i64]StaticPosition{}
	}, author_rules)
	direction := css.cascaded_value_with_ua(element, css.property_id_from_string('direction') or {
		return []TextLine{}, []BlockBox{}, map[i64]StaticPosition{}, map[i64]StaticPosition{}
	}, author_rules)
	rtl := direction == 'rtl'
	physical_align := if align == 'start' && rtl {
		'right'
	} else if align == 'end' && rtl {
		'left'
	} else {
		align
	}
	wraps := white_space.wraps()
	// `text-indent` (inherited) indents the start of the *first* line box (%: of the content width).
	text_indent := resolve_text_indent(element, content_width, author_rules)

	mut lines := []TextLine{}
	mut inline_boxes := []BlockBox{}
	mut y := 0.0
	mut first_line := true
	for segment in segments {
		if segment.len == 0 {
			mut left, right := line_bounds(y, block_line_height, float_bands, content_x, content_width)
			if first_line {
				left += text_indent
			}
			lines << TextLine{
				x: aligned_line_x(left, right - left, 0.0, physical_align)
				y: y
				width: 0.0
				height: block_line_height
			}
			first_line = false
			y += block_line_height
			continue
		}
		mut i := 0
		for i < segment.len {
			mut left, right := line_bounds(y, segment[i].height, float_bands, content_x, content_width)
			if first_line {
				left += text_indent // indent the first line's content start
			}
			// If the first word can't fit beside a float, drop the line below the nearest float.
			if wraps && segment[i].width > right - left {
				dropped := next_float_bottom(y, float_bands)
				if dropped > y {
					y = dropped
					continue
				}
			}
			available := right - left
			mut line_width := segment[i].width
			mut line_height := segment[i].height
			mut j := i + 1
			for j < segment.len {
				needed := segment[j - 1].space_after + segment[j].width
				if wraps && line_width + needed > available {
					break
				}
				line_width += needed
				if segment[j].height > line_height {
					line_height = segment[j].height
				}
				j++
			}
			if white_space.preserves_spaces() && j == segment.len {
				line_width += segment[j - 1].space_after
			}
			// `text-align: justify` spreads the slack across the word gaps of every line except the
			// last of a segment (and lines with a single word).
			is_last_line := j == segment.len
			mut extra_per_gap := 0.0
			if align == 'justify' && !is_last_line && j - i > 1 {
				extra_per_gap = (available - line_width) / f64(j - i - 1)
				if extra_per_gap < 0.0 {
					extra_per_gap = 0.0
				}
			}
			justified := extra_per_gap > 0.0
			line_x := aligned_line_x(left, right - left, line_width, physical_align)
			// Place logical fragments along the paragraph's physical inline direction.
			mut fragments := []TextFragment{}
			mut fragment_x := if rtl { line_x + line_width } else { line_x }
			for k := i; k < j; k++ {
				if rtl {
					fragment_x -= segment[k].width
				}
				if b := segment[k].box {
					// An atomic inline (inline-block): place its box (margin-box top-left at the item's
					// position, top-aligned to the line), painted as its own box rather than as text.
					inline_boxes << translate_block(b, fragment_x, y)
				} else {
					fragments << TextFragment{
						x: fragment_x
						y: y
						width: segment[k].width
						height: segment[k].height
						text: segment[k].text
						color: segment[k].color
						font_size: segment[k].font_size
						bold: segment[k].bold
						italic: segment[k].italic
						mono: segment[k].mono
						text_run_id: segment[k].text_run_id
						shape_as_run: segment[k].shape_as_run && !justified
						separator_after: segment[k].separator_after
						separator_width_after: segment[k].space_after
						preserves_spaces: segment[k].preserves_spaces
						rtl: rtl
						inline_node_id: segment[k].inline_node_id
						background_color: segment[k].background_color
						border: segment[k].border
						border_color: segment[k].border_color
						border_colors: segment[k].border_colors
						border_styles: segment[k].border_styles
						border_radius: segment[k].border_radius
						border_radii: segment[k].border_radii
						shadow: segment[k].shadow
						shadows: segment[k].shadows.clone()
						decoration: segment[k].decoration
						decoration_color: segment[k].decoration_color
						decoration_color_set: segment[k].decoration_color_set
						decoration_style: segment[k].decoration_style
						decoration_thickness: segment[k].decoration_thickness
					}
				}
				if rtl {
					fragment_x -= segment[k].space_after
					if k < j - 1 {
						fragment_x -= extra_per_gap
					}
				} else {
					fragment_x += segment[k].width + segment[k].space_after
					if k < j - 1 {
						fragment_x += extra_per_gap
					}
				}
			}
			lines << TextLine{
				x: line_x
				y: y
				width: if justified { available } else { line_width }
				height: line_height
				fragments: fragments
			}
			first_line = false
			i = j
			y += line_height
		}
	}
	absolute_static_positions, fixed_static_positions := calculate_inline_static_positions(positioned_requests, content_x, lines, inline_boxes)
	return lines, inline_boxes, absolute_static_positions, fixed_static_positions
}

// InlineFormattingContext::calculate_static_position_rect(): find the last line fragment generated
// by an abspos box's immediate previous sibling. A block-outside box starts below it; an
// inline-outside box starts at its top-right corner. The out-of-flow marker itself never participates
// in line width, wrapping, alignment, or line-height.
fn calculate_inline_static_positions(requests []InlineWord, content_x f64, lines []TextLine, inline_boxes []BlockBox) (map[i64]StaticPosition, map[i64]StaticPosition) {
	mut absolute_positions := map[i64]StaticPosition{}
	mut fixed_positions := map[i64]StaticPosition{}
	for request in requests {
		mut found := false
		mut fragment_x := 0.0
		mut fragment_y := 0.0
		mut fragment_width := 0.0
		mut fragment_height := 0.0
		if request.positioned_previous_sibling_id != 0 {
			for line in lines {
				for fragment in line.fragments {
					if fragment.text_run_id == request.positioned_previous_sibling_id
						|| fragment.inline_node_id == request.positioned_previous_sibling_id {
						found = true
						fragment_x = fragment.x
						fragment_y = fragment.y
						fragment_width = fragment.width
						fragment_height = fragment.height
					}
				}
			}
			for box in inline_boxes {
				if box.node_id == request.positioned_previous_sibling_id {
					found = true
					fragment_x = box.x - box.padding.left - box.border.left - box.margin.left
					fragment_y = box.y - box.padding.top - box.border.top - box.margin.top
					fragment_width = box.margin_box_width()
					fragment_height = box.margin_box_height()
				}
			}
		}
		position := if found {
			if request.positioned_block_outside {
				StaticPosition{
					x: content_x
					y: fragment_y + fragment_height
				}
			} else {
				StaticPosition{
					x: fragment_x + fragment_width
					y: fragment_y
				}
			}
		} else {
			StaticPosition{
				x: content_x
				y: 0.0
			}
		}
		if request.positioned_fixed {
			fixed_positions[request.positioned_node_id] = position
		} else {
			absolute_positions[request.positioned_node_id] = position
		}
	}
	return absolute_positions, fixed_positions
}

// Whether `element` uses the border-box box model (specified width/height include padding+border)
// rather than the default content-box.
fn box_sizing_is_border_box(element &dom.Element, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string('box-sizing') or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'border-box'
}

// The used *content* width for `element` in a containing block `containing_width` px wide. A length
// or percentage sets the width per the box model: content-box uses it directly; border-box subtracts
// the horizontal border+padding (`border_padding_lr`). The intrinsic keywords resolve to the element's
// min/max-content (fit-content shrinks to fit the available space). `auto` fills the space left after
// the horizontal margins, border, and padding. All results are clamped at 0.
fn used_content_width(element &dom.Element, containing_width f64, margins_lr f64, border_padding_lr f64, border_box bool, author_rules []&css.CSSRule) f64 {
	width_id := css.property_id_from_string('width') or {
		return non_negative(containing_width - margins_lr - border_padding_lr)
	}
	match css.cascaded_value_with_ua(element, width_id, author_rules) {
		'max-content' {
			return intrinsic_content_width(element, author_rules, false)
		}
		'min-content' {
			return intrinsic_content_width(element, author_rules, true)
		}
		'fit-content' {
			available := non_negative(containing_width - margins_lr - border_padding_lr)
			return shrink_to_fit(intrinsic_content_width(element, author_rules, true), intrinsic_content_width(element, author_rules, false), available)
		}
		else {}
	}
	if px := css.computed_length_px(element, width_id, author_rules) {
		return non_negative(if border_box { px - border_padding_lr } else { px })
	}
	if pct := css.computed_percentage(element, width_id, author_rules) {
		specified := containing_width * pct / 100.0
		return non_negative(if border_box { specified - border_padding_lr } else { specified })
	}
	// A calc() width, resolving any `%` inside against the containing width.
	if calc := css.computed_calc_px(element, width_id, containing_width, author_rules) {
		return non_negative(if border_box { calc - border_padding_lr } else { calc })
	}
	return non_negative(containing_width - margins_lr - border_padding_lr)
}

// Resolve a min-/max-size property to a *content-space* px constraint, or none when it imposes no
// limit (`none`/`auto`/unset, or a percentage with no basis). `basis` is the containing measure for
// percentages (none to skip them, as for heights with no definite containing height); border-box
// subtracts the relevant border+padding (`border_padding`), matching how width/height are treated.
fn resolve_size_constraint(element &dom.Element, property_name string, basis ?f64, border_padding f64, border_box bool, author_rules []&css.CSSRule) ?f64 {
	id := css.property_id_from_string(property_name) or { return none }
	if px := css.computed_length_px(element, id, author_rules) {
		return non_negative(if border_box { px - border_padding } else { px })
	}
	if b := basis {
		if pct := css.computed_percentage(element, id, author_rules) {
			specified := b * pct / 100.0
			return non_negative(if border_box { specified - border_padding } else { specified })
		}
	}
	return none
}

// Clamp a used size by its min/max constraints (CSS 2.1 §10.4/§10.7): apply max first, then min, so
// min wins when the two cross. `max` is none when there is no upper limit.
fn clamp_size(value f64, min f64, max ?f64) f64 {
	mut v := value
	if m := max {
		if v > m {
			v = m
		}
	}
	if v < min {
		v = min
	}
	return v
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

// Whether `element` establishes a new block formatting context, in which case its margins do not
// collapse with its in-flow children. Detects `display: flow-root`, absolute/fixed positioning,
// floats, inline-blocks, table cells, the document root, and a non-visible `overflow` on either axis
// (`hidden`/`scroll`/`auto`/`clip`).
fn establishes_block_formatting_context(element &dom.Element, author_rules []&css.CSSRule) bool {
	if parent := element.as_node().parent_node() {
		if parent.is_document() {
			return true
		}
	}
	if is_absolutely_positioned(position_value(element, author_rules)) {
		return true
	}
	if is_floating(element, author_rules) {
		return true
	}
	display_id := css.property_id_from_string('display') or { return false }
	display := css.cascaded_value_with_ua(element, display_id, author_rules)
	if display in ['flow-root', 'flex', 'inline-flex', 'table', 'inline-table', 'table-cell', 'grid',
		'inline-grid', 'inline-block'] {
		return true // flow-root / flex / table / grid establish an independent formatting context
	}
	for axis in ['overflow-x', 'overflow-y'] {
		id := css.property_id_from_string(axis) or { continue }
		value := css.cascaded_value_with_ua(element, id, author_rules)
		if value != 'visible' && value != '' {
			return true
		}
	}
	return false
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

// The cascaded `position` value (`static` when absent).
fn position_value(element &dom.Element, author_rules []&css.CSSRule) string {
	id := css.property_id_from_string('position') or { return 'static' }
	return css.cascaded_value_with_ua(element, id, author_rules)
}

// Absolute and fixed positioning are both out of flow. Fixed descendants are hoisted to the
// document element and laid out against the initial containing block; absolute descendants stay in
// the scope of their nearest positioned ancestor.
fn is_absolutely_positioned(position string) bool {
	return position == 'absolute' || position == 'fixed'
}

// Positioned = anything but `static`; a positioned box is a containing block for abspos descendants.
fn is_positioned(position string) bool {
	return position != 'static' && position != ''
}

// Whether a size property (width/height) has no definite value (`auto`/absent/unresolvable).
fn size_is_auto(element &dom.Element, property_name string, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string(property_name) or { return true }
	if _ := css.computed_length_px(element, id, author_rules) {
		return false
	}
	if _ := css.computed_percentage(element, id, author_rules) {
		return false
	}
	return true
}

// Collect the absolutely positioned elements whose nearest positioned ancestor is `node` — i.e. walk
// `node`'s descendants but do not descend past any positioned box (which is itself a containing block
// and lays out its own abspos descendants). Skips `display: none` subtrees.
fn collect_abspos_in_scope(node &dom.Node, include_fixed bool, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut result := []&dom.Element{}
	for child_node in node.children_as_vector() {
		child := child_node.as_element() or { continue }
		display := css.cascaded_value_with_ua(child, display_id, author_rules)
		if display == 'none' {
			continue
		}
		if display == 'contents' {
			result << collect_abspos_in_scope(child.as_node(), include_fixed, author_rules)
			continue
		}
		position := position_value(child, author_rules)
		if position == 'fixed' {
			if include_fixed {
				result << child
			}
		} else if position == 'absolute' {
			result << child // belongs to this scope; its own abspos descendants are handled when it lays out
		} else if is_positioned(position) {
			// a positioned (e.g. relative) box establishes its own scope — skip its subtree
			continue
		} else {
			result << collect_abspos_in_scope(child.as_node(), include_fixed, author_rules)
		}
	}
	return result
}

fn collect_fixed_descendants(node &dom.Node, author_rules []&css.CSSRule) []&dom.Element {
	display_id := css.property_id_from_string('display') or { return []&dom.Element{} }
	mut result := []&dom.Element{}
	for child_node in node.children_as_vector() {
		child := child_node.as_element() or { continue }
		if css.cascaded_value_with_ua(child, display_id, author_rules) == 'none' {
			continue
		}
		if position_value(child, author_rules) == 'fixed' {
			result << child
		}
		// Fixed positioning is viewport-relative even through positioned and out-of-flow ancestors.
		result << collect_fixed_descendants(child.as_node(), author_rules)
	}
	return result
}

fn initial_containing_block(element &dom.Element, fallback_width f64, fallback_height f64) PositionedContainingBlock {
	viewport := element.document().viewport_rect()
	return PositionedContainingBlock{
		x: viewport.x
		y: viewport.y
		width: if viewport.width > 0 { viewport.width } else { fallback_width }
		height: if viewport.height > 0 { viewport.height } else { fallback_height }
	}
}

// Lay out an absolutely positioned `element` against its containing block `cb` (CSS 2.1 §9.6/§10.3.7/
// §10.6.4). The element's own content (and nested abspos) is laid out via layout_block with a
// containing width chosen so the normal width algorithm yields the abspos width; the result is then
// translated to the position implied by the insets.
//
// `static_position` is the retained margin-box origin from the formatting context in which this box
// occurred. It can differ from the actual containing block's origin after crossing static ancestors.
fn layout_absolute(element &dom.Element, cb PositionedContainingBlock, static_position StaticPosition, author_rules []&css.CSSRule) BlockBox {
	left := offset_length(element, 'left', cb.width, author_rules)
	right := offset_length(element, 'right', cb.width, author_rules)
	top := offset_length(element, 'top', cb.height, author_rules)
	bottom := offset_length(element, 'bottom', cb.height, author_rules)
	width_auto := size_is_auto(element, 'width', author_rules)
	height_auto := size_is_auto(element, 'height', author_rules)

	// Choose the containing width fed to layout_block so its width algorithm produces the abspos width.
	// width:auto between both left and right fills the gap; width:auto otherwise is shrink-to-fit (the
	// content's min/max-content clamped to the space left after insets and edges); a definite width
	// resolves against the containing block.
	available_width := if !width_auto {
		cb.width
	} else if left != none && right != none {
		non_negative(cb.width - left - right)
	} else {
		edges := horizontal_edges(element, cb.width, author_rules)
		available_content := non_negative(cb.width - left or { 0.0 } - right or { 0.0 } - edges)
		fit := shrink_to_fit(intrinsic_content_width(element, author_rules, true), intrinsic_content_width(element, author_rules, false), available_content)
		fit + edges
	}
	mut box := layout_block(element, 0.0, 0.0, available_width, author_rules)
	// The ordinary block pass has no definite containing-height input. Abspos layout does, so resolve
	// percentage/calc heights against the selected (for grid, possibly per-item) containing rectangle.
	if !height_auto {
		height_id := css.property_id_from_string('height') or { return BlockBox{} }
		resolved_height := if percentage := css.computed_percentage(element, height_id, author_rules) {
			?f64(cb.height * percentage / 100.0)
		} else if calc := css.computed_calc_px(element, height_id, cb.height, author_rules) {
			?f64(calc)
		} else {
			?f64(none)
		}
		if specified_height := resolved_height {
			border_padding := box.border.top + box.border.bottom + box.padding.top + box.padding.bottom
			border_box := box_sizing_is_border_box(element, author_rules)
			content_height := non_negative(if border_box {
				specified_height - border_padding
			} else {
				specified_height
			})
			minimum := resolve_size_constraint(element, 'min-height', cb.height, border_padding, border_box, author_rules) or { 0.0 }
			maximum := resolve_size_constraint(element, 'max-height', cb.height, border_padding, border_box, author_rules)
			box.height = clamp_size(content_height, minimum, maximum)
		}
	}

	// CSS 2 absolute positioning: auto margins are zero unless both opposing insets and the size are
	// definite. In that fully constrained case, equal auto margins center the margin box; a single
	// auto margin absorbs the remaining space.
	margin_left_auto := margin_is_auto(element, 'margin-left', author_rules)
	margin_right_auto := margin_is_auto(element, 'margin-right', author_rules)
	mut used_margin_left := if margin_left_auto { 0.0 } else { box.margin.left }
	mut used_margin_right := if margin_right_auto { 0.0 } else { box.margin.right }
	if !width_auto {
		if used_left := left {
			if used_right := right {
				remaining_for_margins := cb.width - used_left - used_right - box.border_box().width
				if margin_left_auto && margin_right_auto {
					used_margin_left = remaining_for_margins / 2.0
					used_margin_right = remaining_for_margins / 2.0
				} else if margin_left_auto {
					used_margin_left = remaining_for_margins - used_margin_right
				} else if margin_right_auto {
					used_margin_right = remaining_for_margins - used_margin_left
				}
			}
		}
	}

	// height:auto with both top and bottom set fills the gap between them.
	if height_auto {
		if t := top {
			if b := bottom {
				border_padding_tb := box.border.top + box.border.bottom + box.padding.top + box.padding.bottom
				box.height = non_negative(cb.height - t - b - box.margin.top - box.margin.bottom - border_padding_tb)
			}
		}
	}
	margin_top_auto := margin_is_auto(element, 'margin-top', author_rules)
	margin_bottom_auto := margin_is_auto(element, 'margin-bottom', author_rules)
	mut used_margin_top := if margin_top_auto { 0.0 } else { box.margin.top }
	mut used_margin_bottom := if margin_bottom_auto { 0.0 } else { box.margin.bottom }
	if !height_auto {
		if used_top := top {
			if used_bottom := bottom {
				remaining_for_margins := cb.height - used_top - used_bottom - box.border_box().height
				if margin_top_auto && margin_bottom_auto {
					used_margin_top = remaining_for_margins / 2.0
					used_margin_bottom = remaining_for_margins / 2.0
				} else if margin_top_auto {
					used_margin_top = remaining_for_margins - used_margin_bottom
				} else if margin_bottom_auto {
					used_margin_bottom = remaining_for_margins - used_margin_top
				}
			}
		}
	}
	box.margin = BoxEdges{
		top: used_margin_top
		right: used_margin_right
		bottom: used_margin_bottom
		left: used_margin_left
	}

	margin_box_width := box.margin_box_width()
	margin_box_height := box.margin_box_height()
	aligned_static_position := static_position.aligned_for_margin_box(margin_box_width, margin_box_height)
	margin_x := if l := left {
		cb.x + l
	} else if r := right {
		cb.x + cb.width - r - margin_box_width
	} else {
		aligned_static_position.x
	}
	margin_y := if t := top {
		cb.y + t
	} else if b := bottom {
		cb.y + cb.height - b - margin_box_height
	} else {
		aligned_static_position.y
	}
	// The provisional box's margin-box origin (it was laid out at (0,0), and abspos establishes a BFC
	// so no margin collapsed through — its margin-box origin is exactly (0,0)).
	current_margin_x := box.x - box.padding.left - box.border.left - box.margin.left
	current_margin_y := box.y - box.padding.top - box.border.top - box.margin.top
	return translate_block(box, margin_x - current_margin_x, margin_y - current_margin_y)
}

// An inset property (top/right/bottom/left) resolved to px, or none when `auto`/absent. Percentages
// resolve against `basis` (none to skip them). Unlike sizes, insets may be negative — no clamping.
fn offset_length(element &dom.Element, property_name string, basis ?f64, author_rules []&css.CSSRule) ?f64 {
	id := css.property_id_from_string(property_name) or { return none }
	if px := css.computed_length_px(element, id, author_rules) {
		return px
	}
	if b := basis {
		if pct := css.computed_percentage(element, id, author_rules) {
			return b * pct / 100.0
		}
	}
	return none
}

// The relative-positioning offset (dx, dy) for `element`: 0 unless `position: relative`. Then `left`
// (else `-right`) offsets horizontally and `top` (else `-bottom`) vertically, relative to the box's
// normal-flow position — without affecting siblings (CSS 2.1 §9.4.3). Percentage insets resolve
// against the containing block's width for left/right; top/bottom percentages need its height, which
// isn't tracked, so they're treated as auto.
fn relative_offset(element &dom.Element, containing_width f64, author_rules []&css.CSSRule) (f64, f64) {
	position_id := css.property_id_from_string('position') or { return 0.0, 0.0 }
	if css.cascaded_value_with_ua(element, position_id, author_rules) != 'relative' {
		return 0.0, 0.0
	}
	dx := if left := offset_length(element, 'left', containing_width, author_rules) {
		left
	} else if right := offset_length(element, 'right', containing_width, author_rules) {
		-right
	} else {
		0.0
	}
	dy := if top := offset_length(element, 'top', none, author_rules) {
		top
	} else if bottom := offset_length(element, 'bottom', none, author_rules) {
		-bottom
	} else {
		0.0
	}
	return dx, dy
}

// A context-free absolute px token retained for compatibility tests. Composite CSS values use
// resolve_length_token(), which has the element and percentage basis required for relative units.
fn parse_px_length(token string) f64 {
	trimmed := token.trim_space()
	if trimmed.ends_with('px') {
		return trimmed[..trimmed.len - 2].trim_space().f64()
	}
	if trimmed == '0' {
		return 0.0
	}
	return 0.0
}

fn parse_transform_length(element &dom.Element, token string, percentage_basis f64, author_rules []&css.CSSRule) f64 {
	return css.resolve_length_percentage_text_px(element, token, percentage_basis, author_rules) or {
		0.0
	}
}

// Compatibility helper used by focused parsing tests. Actual box painting carries the complete
// matrix from `resolved_transform_matrix()` rather than folding translation into layout geometry.
fn transform_translate(element &dom.Element, reference_width f64, reference_height f64, author_rules []&css.CSSRule) (f64, f64) {
	id := css.property_id_from_string('transform') or { return 0.0, 0.0 }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	matrix := css.resolve_transform_2d_matrix(element, value, reference_width, reference_height, author_rules) or { return 0.0, 0.0 }
	return matrix[4], matrix[5]
}

fn transform_origin_component(element &dom.Element, token string, basis f64, horizontal bool, author_rules []&css.CSSRule) f64 {
	keyword := token.trim_space().to_lower()
	if horizontal {
		if keyword == 'left' {
			return 0.0
		}
		if keyword == 'center' {
			return basis / 2.0
		}
		if keyword == 'right' {
			return basis
		}
	} else {
		if keyword == 'top' {
			return 0.0
		}
		if keyword == 'center' {
			return basis / 2.0
		}
		if keyword == 'bottom' {
			return basis
		}
	}
	return parse_transform_length(element, token, basis, author_rules)
}

fn resolved_transform_origin(element &dom.Element, width f64, height f64, author_rules []&css.CSSRule) (f64, f64) {
	id := css.property_id_from_string('transform-origin') or { return width / 2.0, height / 2.0 }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	mut tokens := split_top_level(value, ` `)
	if tokens.len == 0 {
		return width / 2.0, height / 2.0
	}
	if tokens.len == 1 {
		if tokens[0].to_lower() in ['top', 'bottom'] {
			tokens = ['center', tokens[0]]
		} else {
			tokens << 'center'
		}
	}
	// CSS accepts vertical/horizontal keywords in either order.
	if tokens[0].to_lower() in ['top', 'bottom'] || tokens[1].to_lower() in ['left', 'right'] {
		tokens[0], tokens[1] = tokens[1], tokens[0]
	}
	return transform_origin_component(element, tokens[0], width, true, author_rules), transform_origin_component(element, tokens[1], height, false, author_rules)
}

fn resolved_transform_matrix(element &dom.Element, border_left f64, border_top f64, border_width f64, border_height f64, author_rules []&css.CSSRule) [6]f64 {
	id := css.property_id_from_string('transform') or { return [6]f64{} }
	value := css.cascaded_value_with_ua(element, id, author_rules)
	if value == '' || value == 'none' {
		return [6]f64{}
	}
	matrix := css.resolve_transform_2d_matrix(element, value, border_width, border_height, author_rules) or { return [6]f64{} }
	origin_x, origin_y := resolved_transform_origin(element, border_width, border_height, author_rules)
	return affine_around_origin(matrix, border_left + origin_x, border_top + origin_y)
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

// Whether a margin property's cascaded value is the keyword `auto`.
fn margin_is_auto(element &dom.Element, property_name string, author_rules []&css.CSSRule) bool {
	id := css.property_id_from_string(property_name) or { return false }
	return css.cascaded_value_with_ua(element, id, author_rules) == 'auto'
}

// Resolve the used left/right margins, distributing the horizontal space left over after the border
// box and the fixed (non-auto) margins to any `auto` margins (CSS 2.1 §10.3.3): both `auto` centers
// the box; a single `auto` margin absorbs the whole remainder (so margin-left:auto right-aligns);
// none `auto` leaves the fixed values (any over-constraint notionally lands on margin-right, which
// isn't rendered here). Overflow (negative space) spills onto the right margin in LTR.
fn resolve_horizontal_auto_margins(containing_width f64, border_box_width f64, left_fixed f64, right_fixed f64, left_auto bool, right_auto bool) (f64, f64) {
	space := containing_width - border_box_width - left_fixed - right_fixed
	if left_auto && right_auto {
		if space > 0 {
			return space / 2, space / 2
		}
		return 0.0, space
	}
	if left_auto {
		return space, right_fixed
	}
	if right_auto {
		return left_fixed, space
	}
	return left_fixed, right_fixed
}

// Lay out `element` and its block descendants. `x`/`y` is the top-left of this box's *margin box*;
// the returned box's content origin is inset by its margin, border, and padding. Children stack
// vertically within the content box, each advancing the cursor by its own margin-box height; the
// parent's content height is that stacked total unless it declares an explicit height.
// Lay out `element` as a block box within a containing block `containing_width` px wide, at
// margin-box origin (`x`, `y`).
pub fn layout_block(element &dom.Element, x f64, y f64, containing_width f64, author_rules []&css.CSSRule) BlockBox {
	return layout_block_impl(element, x, y, containing_width, none, author_rules)
}

// Core block layout. When `forced_content_width` is set it overrides the computed content width —
// used to give a flex item its shrink-to-fit main size instead of filling the line.
fn layout_block_impl(element &dom.Element, x f64, y f64, containing_width f64, forced_content_width ?f64, author_rules []&css.CSSRule) BlockBox {
	border := BoxEdges{
		top: used_border(element, 'top', author_rules)
		right: used_border(element, 'right', author_rules)
		bottom: used_border(element, 'bottom', author_rules)
		left: used_border(element, 'left', author_rules)
	}
	padding := BoxEdges{
		top: used_length_or_zero(element, 'padding-top', containing_width, author_rules)
		right: used_length_or_zero(element, 'padding-right', containing_width, author_rules)
		bottom: used_length_or_zero(element, 'padding-bottom', containing_width, author_rules)
		left: used_length_or_zero(element, 'padding-left', containing_width, author_rules)
	}
	border_box := box_sizing_is_border_box(element, author_rules)
	border_padding_lr := border.left + border.right + padding.left + padding.right

	// Vertical margins resolve directly (auto -> 0). Horizontal margins may be `auto`, which absorbs
	// leftover space once the width is known (below).
	margin_top := used_length_or_zero(element, 'margin-top', containing_width, author_rules)
	margin_bottom := used_length_or_zero(element, 'margin-bottom', containing_width, author_rules)
	margin_left_auto := margin_is_auto(element, 'margin-left', author_rules)
	margin_right_auto := margin_is_auto(element, 'margin-right', author_rules)
	margin_left_fixed := used_length_or_zero(element, 'margin-left', containing_width, author_rules)
	margin_right_fixed := used_length_or_zero(element, 'margin-right', containing_width, author_rules)

	// Used content width: `auto` margins count as 0 while the width fills; then clamp by min/max.
	// A flex item passes a forced width (its shrink-to-fit / main size) that overrides the box model.
	tentative_width := if fw := forced_content_width {
		fw
	} else if is_table(element, author_rules) && size_is_auto(element, 'width', author_rules) {
		available := non_negative(containing_width - margin_left_fixed - margin_right_fixed - border_padding_lr)
		shrink_to_fit(legacy_table_intrinsic_width(element, available, true, author_rules), legacy_table_intrinsic_width(element, available, false, author_rules), available)
	} else {
		used_content_width(element, containing_width, margin_left_fixed + margin_right_fixed, border_padding_lr, border_box, author_rules)
	}
	min_width := resolve_size_constraint(element, 'min-width', containing_width, border_padding_lr, border_box, author_rules) or { 0.0 }
	max_width := resolve_size_constraint(element, 'max-width', containing_width, border_padding_lr, border_box, author_rules)
	width := clamp_size(tentative_width, min_width, max_width)

	// Distribute leftover horizontal space to `auto` margins (centering / one-sided absorb).
	margin_left, margin_right := resolve_horizontal_auto_margins(containing_width, width + border_padding_lr, margin_left_fixed, margin_right_fixed, margin_left_auto, margin_right_auto)
	margin := BoxEdges{
		top: margin_top
		right: margin_right
		bottom: margin_bottom
		left: margin_left
	}

	// Relative positioning offsets this box (and its subtree) from the normal-flow position without
	// affecting siblings: the flow uses the un-offset metrics; the offset rides along here and through
	// the child translate below.
	rel_x, rel_y := relative_offset(element, containing_width, author_rules)
	content_x := x + margin.left + border.left + padding.left + rel_x

	// Whether this box's top/bottom margins can collapse with a first/last child's. They can't when a
	// border or padding separates them, nor when the box establishes a block formatting context (its
	// children's margins are contained rather than collapsing through). The document element is
	// detected from its DOM parent, so detached elements retain ordinary block margin behavior.
	establishes_bfc := establishes_block_formatting_context(element, author_rules)
	top_adjoins := !establishes_bfc && border.top == 0.0 && padding.top == 0.0
	// Whether the last child's bottom margin stays inside this box's content (rather than collapsing
	// out): true when bottom border/padding separates them, or when the box establishes a BFC.
	bottom_margin_contained := establishes_bfc || border.bottom != 0.0 || padding.bottom != 0.0

	// Floats are placed when their tree-order opportunity is reached in the block pass. Their bands
	// then affect only following clearance and inline layout, and their bottoms determine BFC height.
	mut placed_floats := []BlockBox{}
	mut float_bands := []FloatBand{}
	mut left_floats_bottom := 0.0
	mut right_floats_bottom := 0.0

	// Lay children out in a LOCAL frame whose origin is this box's content-box top-left. Vertical
	// margins collapse (CSS 2.1 §8.3.1) using each child's OUTER (collapsed) margins: between siblings
	// the gap is collapse(prev outer bottom, this outer top); a first child whose top edge adjoins the
	// parent contributes its outer top margin to the parent instead of pushing itself down. Children
	// are laid out provisionally (border-box top at their own outer top margin) and translated into
	// place; the whole set is shifted to the real content-box top once the parent's outer top margin
	// is known.
	mut local_children := []BlockBox{}
	mut local_lines := []TextLine{}
	mut local_absolute_static_positions := map[i64]StaticPosition{}
	mut local_fixed_static_positions := map[i64]StaticPosition{}
	mut legacy_grid_columns := []f64{}
	mut legacy_grid_rows := []f64{}
	mut legacy_grid_column_gap := 0.0
	mut legacy_grid_row_gap := 0.0
	mut legacy_grid_column_names := map[string][]int{}
	mut legacy_grid_row_names := map[string][]int{}
	mut content_height := 0.0
	mut first_child_outer_top := 0.0
	mut last_child_outer_bottom := 0.0
	mut has_children := false

	if is_flex_row(element, author_rules) {
		// FLEX (row): items flow along the main axis; with flex-wrap they break onto multiple lines. Per
		// line the items grow/shrink over the line's free space, justify-content distributes the
		// leftover, gap spaces items, and align-items/self cross-align; lines stack in the cross axis
		// (row-gap between them). Flex containers establish a formatting context (no margin collapse).
		wrap := flex_wraps(element, author_rules)
		reverse_main := flex_main_axis_is_reversed(element, author_rules)
		reverse_cross := flex_cross_axis_is_reversed(element, author_rules)
		gap_main := flex_column_gap(element, author_rules)
		gap_cross := flex_row_gap(element, author_rules)
		items := flex_item_elements(element.as_node(), author_rules)
		mut bases := []f64{}
		mut edges := []f64{}
		for item in items {
			bases << flex_base_size(item, width, author_rules)
			edges << horizontal_edges(item, width, author_rules)
		}
		// Group items into flex lines (a single line when nowrap): pack items until the next would
		// overflow the main size, then break.
		mut lines_idx := [][]int{}
		mut cur := []int{}
		mut used := 0.0
		for i in 0 .. items.len {
			item_outer := bases[i] + edges[i]
			gap := if cur.len > 0 { gap_main } else { 0.0 }
			if wrap && cur.len > 0 && used + gap + item_outer > width {
				lines_idx << cur
				cur = [i]
				used = item_outer
			} else {
				cur << i
				used += gap + item_outer
			}
		}
		if cur.len > 0 {
			lines_idx << cur
		}
		definite_cross_size := definite_content_height(element, border, padding, border_box, author_rules)
		mut line_cross_sizes := []f64{}
		mut natural_cross_total := if lines_idx.len > 1 {
			f64(lines_idx.len - 1) * gap_cross
		} else {
			0.0
		}
		// Measure each line before align-content distributes the container's cross-space.
		for line in lines_idx {
			line_items := line.map(items[it])
			line_bases := line.map(bases[it])
			mut measured_children := []BlockBox{}
			line_size := place_flex_line(element, line_items, line_bases, content_x, 0, width, gap_main, -1.0, reverse_main, false, author_rules, mut measured_children)
			line_cross_sizes << line_size
			natural_cross_total += line_size
		}
		cross_size := definite_cross_size or { natural_cross_total }
		free_cross_space := cross_size - natural_cross_total
		alignment := align_content_value(element, author_rules)
		mut leading_cross := 0.0
		mut distributed_cross_gap := 0.0
		if wrap && alignment == 'stretch' && free_cross_space > 0 && line_cross_sizes.len > 0 {
			extra_per_line := free_cross_space / f64(line_cross_sizes.len)
			for index in 0 .. line_cross_sizes.len {
				line_cross_sizes[index] += extra_per_line
			}
		} else if wrap {
			leading_cross, distributed_cross_gap = justify_offsets(alignment, free_cross_space, line_cross_sizes.len)
		}
		// A nowrap flex line always fills the container cross-size. Wrapped lines use their measured or
		// align-content-stretched size and are positioned from the logical cross-start.
		if !wrap && line_cross_sizes.len == 1 {
			line_cross_sizes[0] = cross_size
		}
		mut logical_cross := leading_cross
		for line_index, line in lines_idx {
			if line_index > 0 {
				logical_cross += gap_cross + distributed_cross_gap
			}
			line_items := line.map(items[it])
			line_bases := line.map(bases[it])
			line_size := line_cross_sizes[line_index]
			physical_cross := if reverse_cross {
				cross_size - logical_cross - line_size
			} else {
				logical_cross
			}
			place_flex_line(element, line_items, line_bases, content_x, physical_cross, width, gap_main, line_size, reverse_main, reverse_cross, author_rules, mut local_children)
			logical_cross += line_size
		}
		content_height = cross_size
		has_children = items.len > 0
	} else if is_flex_column(element, author_rules) {
		// FLEX (column): form vertical lines against a definite height, resolve flexible lengths per
		// line, and distribute the lines across the horizontal cross axis. A container without wrapping
		// (or without a definite height) has one line filling the container width.
		gap_main := flex_row_gap(element, author_rules)
		gap_cross := flex_column_gap(element, author_rules)
		reverse_main := flex_main_axis_is_reversed(element, author_rules)
		reverse_cross := flex_cross_axis_is_reversed(element, author_rules)
		items := flex_item_elements(element.as_node(), author_rules)
		container_height := definite_content_height(element, border, padding, border_box, author_rules)
		wrap := flex_wraps(element, author_rules) && container_height != none
		// Measure hypothetical main sizes for line breaking.
		mut break_sizes := []f64{}
		for item in items {
			forced := if size_is_auto(item, 'width', author_rules) {
				?f64(flex_content_base(item, width, author_rules))
			} else {
				?f64(none)
			}
			item_box := layout_block_impl(item, 0, 0, width, forced, author_rules)
			border_padding := vertical_border_padding(item_box)
			item_border_box := box_sizing_is_border_box(item, author_rules)
			basis := flex_column_base_size(item, item_box.height, container_height, border_padding, item_border_box, author_rules)
			minimum := flex_column_minimum_size(item, item_box.height, container_height, border_padding, item_border_box, author_rules)
			maximum := flex_column_maximum_size(item, container_height, border_padding, item_border_box, author_rules)
			break_sizes << non_negative(clamp_size(basis, minimum, maximum)) + item_box.margin_box_height() - item_box.height
		}
		mut lines_idx := [][]int{}
		mut current_line := []int{}
		mut used_main := 0.0
		available_main := container_height or { 0.0 }
		for index, break_size in break_sizes {
			line_gap := if current_line.len > 0 { gap_main } else { 0.0 }
			if wrap && current_line.len > 0 && used_main + line_gap + break_size > available_main {
				lines_idx << current_line
				current_line = [index]
				used_main = break_size
			} else {
				current_line << index
				used_main += line_gap + break_size
			}
		}
		if current_line.len > 0 {
			lines_idx << current_line
		}
		mut line_cross_sizes := []f64{}
		mut natural_cross_total := if lines_idx.len > 1 {
			f64(lines_idx.len - 1) * gap_cross
		} else {
			0.0
		}
		for line in lines_idx {
			line_items := line.map(items[it])
			line_cross := measure_flex_column_line_cross_size(line_items, width, author_rules)
			line_cross_sizes << line_cross
			natural_cross_total += line_cross
		}
		free_cross_space := width - natural_cross_total
		alignment := align_content_value(element, author_rules)
		mut leading_cross := 0.0
		mut distributed_cross_gap := 0.0
		if wrap && alignment == 'stretch' && free_cross_space > 0 && line_cross_sizes.len > 0 {
			extra_per_line := free_cross_space / f64(line_cross_sizes.len)
			for index in 0 .. line_cross_sizes.len {
				line_cross_sizes[index] += extra_per_line
			}
		} else if wrap {
			leading_cross, distributed_cross_gap = justify_offsets(alignment, free_cross_space, line_cross_sizes.len)
		}
		if !wrap && line_cross_sizes.len == 1 {
			line_cross_sizes[0] = width
		}
		mut logical_cross := leading_cross
		mut used_line_main := 0.0
		for line_index, line in lines_idx {
			if line_index > 0 {
				logical_cross += gap_cross + distributed_cross_gap
			}
			line_size := line_cross_sizes[line_index]
			physical_cross := if reverse_cross {
				width - logical_cross - line_size
			} else {
				logical_cross
			}
			line_items := line.map(items[it])
			line_main := place_flex_column_line(element, line_items, content_x + physical_cross, line_size, container_height, gap_main, reverse_main, reverse_cross, author_rules, mut local_children)
			if line_main > used_line_main {
				used_line_main = line_main
			}
			logical_cross += line_size
		}
		content_height = container_height or { used_line_main }
		has_children = items.len > 0
	} else if is_table(element, author_rules) {
		// TABLE: arrange cells in a grid. Rows come from the row groups (tbody/thead/tfoot) flattened;
		// each column's width is content-proportional, scaled to fill the table's content width; each
		// cell is laid out at its column width and a row's height is its tallest cell. Cells become the
		// table box's children (rows/column boxes aren't materialized). Colspan and rowspan reserve their
		// covered grid slots before column and row sizing.
		rows := table_rows(element, author_rules)
		placements, n_cols, n_rows := legacy_table_cell_placements(rows, author_rules)
		horizontal_spacing, vertical_spacing := legacy_table_border_spacing(element, width, author_rules)
		mut table_cursor := 0.0
		for caption in table_captions(element, 'top', author_rules) {
			caption_box := layout_block_impl(caption, content_x, 0, width, none, author_rules)
			local_children << translate_block(caption_box, 0, table_cursor)
			table_cursor += caption_box.margin_box_height()
		}
		if n_cols > 0 {
			// Content-based width contribution: a spanning cell contributes an equal share to each track.
			mut col_widths := []f64{}
			for _ in 0 .. n_cols {
				col_widths << 0.0
			}
			for placement in placements {
				outer := intrinsic_content_width(placement.element, author_rules, false) + horizontal_edges(placement.element, width, author_rules)
				share := outer / f64(placement.col_span)
				for column in placement.column .. placement.column + placement.col_span {
					if share > col_widths[column] {
						col_widths[column] = share
					}
				}
			}
			// Honor explicit <col>/<colgroup> widths first, then distribute the remaining width across
			// unconstrained tracks in proportion to their intrinsic contribution.
			constraints := table_column_constraints(element, width, author_rules)
			mut fixed_width := 0.0
			mut flexible_content_sum := 0.0
			mut flexible_count := 0
			for column in 0 .. n_cols {
				constraint := if column < constraints.len { constraints[column] } else { -1.0 }
				if constraint >= 0 {
					fixed_width += constraint
				} else {
					flexible_content_sum += col_widths[column]
					flexible_count++
				}
			}
			assignable_width := non_negative(width - horizontal_spacing * f64(n_cols + 1))
			remaining_width := non_negative(assignable_width - fixed_width)
			mut final_widths := []f64{}
			for column in 0 .. n_cols {
				constraint := if column < constraints.len { constraints[column] } else { -1.0 }
				if constraint >= 0 {
					final_widths << constraint
				} else if flexible_content_sum > 0 {
					final_widths << col_widths[column] * remaining_width / flexible_content_sum
				} else if flexible_count > 0 {
					final_widths << remaining_width / f64(flexible_count)
				} else {
					final_widths << 0.0
				}
			}
			mut col_x := []f64{}
			mut acc := horizontal_spacing
			for w in final_widths {
				col_x << acc
				acc += w + horizontal_spacing
			}
			// Lay cells at their spanned width. Single-row cells establish the initial row heights;
			// spanning cells then distribute any height deficit equally across the covered rows.
			mut cell_boxes := []BlockBox{}
			mut row_heights := []f64{len: n_rows}
			for placement in placements {
				mut spanned_width := 0.0
				for column in placement.column .. placement.column + placement.col_span {
					spanned_width += final_widths[column]
				}
				cell_content_width := non_negative(spanned_width - horizontal_edges(placement.element, width, author_rules))
				cell_box := layout_block_impl(placement.element, 0, 0, width, cell_content_width, author_rules)
				if placement.row_span == 1 && cell_box.margin_box_height() > row_heights[placement.row] {
					row_heights[placement.row] = cell_box.margin_box_height()
				}
				cell_boxes << cell_box
			}
			for index, placement in placements {
				if placement.row_span == 1 {
					continue
				}
				mut covered_height := 0.0
				for row in placement.row .. placement.row + placement.row_span {
					covered_height += row_heights[row]
				}
				deficit := cell_boxes[index].margin_box_height() - covered_height
				if deficit > 0 {
					extra_per_row := deficit / f64(placement.row_span)
					for row in placement.row .. placement.row + placement.row_span {
						row_heights[row] += extra_per_row
					}
				}
			}
			mut row_offsets := []f64{}
			mut row_cursor := vertical_spacing
			for row_height in row_heights {
				row_offsets << row_cursor
				row_cursor += row_height + vertical_spacing
			}
			for index, cell_box in cell_boxes {
				placement := placements[index]
				mut stretched_cell := cell_box
				mut spanned_row_height := 0.0
				for row in placement.row .. placement.row + placement.row_span {
					spanned_row_height += row_heights[row]
				}
				if stretched_cell.margin_box_height() < spanned_row_height {
					stretched_cell.height += spanned_row_height - stretched_cell.margin_box_height()
				}
				local_children << translate_block(stretched_cell, content_x + col_x[placement.column], table_cursor + row_offsets[placement.row])
			}
			table_cursor += row_cursor
		}
		for caption in table_captions(element, 'bottom', author_rules) {
			caption_box := layout_block_impl(caption, content_x, 0, width, none, author_rules)
			local_children << translate_block(caption_box, 0, table_cursor)
			table_cursor += caption_box.margin_box_height()
		}
		content_height = table_cursor
		has_children = local_children.len > 0
	} else if is_grid(element, author_rules) {
		// GRID: resolve the column tracks (grid-template-columns, with fr units) and auto-place items in
		// row-major order; an item spanning several columns (grid-column: span N / a / b) occupies that
		// many tracks and wraps to the next row when it doesn't fit. A row's height is its tallest item;
		// column-gap/row-gap separate the tracks. Items are sized to their (spanned) columns and become
		// the grid box's children. Explicit integer column lines are occupied before auto-flow items.
		// Explicit row tracks and named areas are resolved below alongside the row placement pass.
		gap_col := flex_column_gap(element, author_rules)
		gap_row := flex_row_gap(element, author_rules)
		template := css.cascaded_value_with_ua(element, css.property_id_from_string('grid-template-columns') or {
			return BlockBox{}
		}, author_rules)
		col_widths := parse_grid_tracks(template, element, width, gap_col, author_rules)
		n_cols := col_widths.len
		column_line_names := grid_line_names(template, element, width, gap_col, author_rules)
		legacy_grid_columns = col_widths.clone()
		legacy_grid_column_gap = gap_col
		legacy_grid_row_gap = gap_row
		legacy_grid_column_names = column_line_names.clone()
		mut col_x := []f64{}
		mut xacc := 0.0
		for w in col_widths {
			col_x << xacc
			xacc += w + gap_col
		}
		items := flex_item_elements(element.as_node(), author_rules)
		// Place definite-column items first, then scan the row-major auto-placement cursor around their
		// occupied cells. This preserves DOM order in the resulting child list while matching grid's
		// placement priority.
		mut placements := []GridPlacement{len: items.len}
		mut column_specs := []LegacyGridAxisPlacement{cap: items.len}
		for item in items {
			column_specs << grid_column_placement(item, n_cols, column_line_names, author_rules)
		}
		// Share the typed OccupationGrid coordinate encoding used by the native
		// Grid formatting path. The compatibility renderer must not format a new
		// string for every placement probe either.
		mut occupied := map[u64]bool{}
		mut n_rows := 0
		for index, spec in column_specs {
			if spec.start < 0 {
				continue
			}
			mut row := 0
			for {
				mut fits := true
				for column in spec.start .. spec.start + spec.span {
					if occupied[grid_cell_key(row, column)] {
						fits = false
						break
					}
				}
				if fits {
					break
				}
				row++
			}
			placements[index] = GridPlacement{
				col: spec.start
				row: row
				span: spec.span
			}
			for column in spec.start .. spec.start + spec.span {
				occupied[grid_cell_key(row, column)] = true
			}
			if row + 1 > n_rows {
				n_rows = row + 1
			}
		}
		mut cur_col := 0
		mut cur_row := 0
		for index, spec in column_specs {
			if placements[index].col >= 0 {
				continue
			}
			for {
				if cur_col + spec.span > n_cols {
					cur_col = 0
					cur_row++
				}
				mut fits := true
				for column in cur_col .. cur_col + spec.span {
					if occupied[grid_cell_key(cur_row, column)] {
						fits = false
						break
					}
				}
				if fits {
					break
				}
				cur_col++
			}
			placements[index] = GridPlacement{
				col: cur_col
				row: cur_row
				span: spec.span
			}
			for column in cur_col .. cur_col + spec.span {
				occupied[grid_cell_key(cur_row, column)] = true
			}
			cur_col += spec.span
			if cur_row + 1 > n_rows {
				n_rows = cur_row + 1
			}
		}
		// Lay each item out within its spanned columns. The cell width, rather than the whole grid width,
		// is its containing block, which also makes auto margins absorb only the cell's free space.
		mut item_boxes := []BlockBox{}
		mut cell_widths := []f64{}
		mut inline_alignments := []string{}
		mut block_alignments := []string{}
		mut row_heights := []f64{len: n_rows}
		container_justify := justify_items_value(element, author_rules)
		container_align := align_items_value(element, author_rules)
		for i, item in items {
			p := placements[i]
			mut spanned := f64(p.span - 1) * gap_col
			for c := p.col; c < p.col + p.span; c++ {
				spanned += col_widths[c]
			}
			inline_alignment := effective_justify_self(item, container_justify, author_rules)
			block_alignment := effective_align_self(item, container_align, author_rules)
			forced := if size_is_auto(item, 'width', author_rules) {
				if inline_alignment == 'stretch' {
					?f64(non_negative(spanned - horizontal_edges(item, spanned, author_rules)))
				} else {
					?f64(flex_content_base(item, spanned, author_rules))
				}
			} else {
				?f64(none)
			}
			cb := layout_block_impl(item, 0, 0, spanned, forced, author_rules)
			if cb.margin_box_height() > row_heights[p.row] {
				row_heights[p.row] = cb.margin_box_height()
			}
			item_boxes << cb
			cell_widths << spanned
			inline_alignments << inline_alignment
			block_alignments << block_alignment
		}
		row_template := css.cascaded_value_with_ua(element, css.property_id_from_string('grid-template-rows') or {
			return BlockBox{}
		}, author_rules)
		mut natural_row_extent := gap_row * f64(if row_heights.len > 0 {
			row_heights.len - 1
		} else {
			0
		})
		for row_height in row_heights {
			natural_row_extent += row_height
		}
		row_basis := definite_content_height(element, border, padding, border_box, author_rules) or {
			natural_row_extent
		}
		row_heights = parse_grid_row_tracks(row_template, element, row_basis, gap_row, row_heights, author_rules)
		legacy_grid_rows = row_heights.clone()
		legacy_grid_row_names = grid_line_names(row_template, element, row_basis, gap_row, author_rules)
		mut row_y := []f64{}
		mut yacc := 0.0
		for r in 0 .. row_heights.len {
			row_y << yacc
			yacc += row_heights[r] + if r < row_heights.len - 1 { gap_row } else { 0.0 }
		}
		// Stretch auto-sized items, then align each margin box inside its grid area.
		for i, original_box in item_boxes {
			p := placements[i]
			mut cb := original_box
			if block_alignments[i] == 'stretch' && size_is_auto(items[i], 'height', author_rules) {
				cb.height = flex_stretched_content_height(cb, row_heights[p.row])
			}
			inline_offset := if margin_is_auto(items[i], 'margin-left', author_rules) || margin_is_auto(items[i], 'margin-right', author_rules) {
				0.0
			} else {
				cross_axis_offset(inline_alignments[i], cell_widths[i], cb.margin_box_width())
			}
			block_offset := cross_axis_offset(block_alignments[i], row_heights[p.row], cb.margin_box_height())
			mut placed_box := translate_block(cb, content_x + col_x[p.col] + inline_offset, row_y[p.row] + block_offset)
			if is_positioned(position_value(element, author_rules)) {
				// As in get_grid_area_rect(), a descendant's containing rectangle reaches the
				// following grid line, including the following gutter except at the final line.
				area_width := cell_widths[i] + if p.col + p.span < n_cols { gap_col } else { 0.0 }
				area_height := row_heights[p.row] + if p.row + 1 < row_heights.len {
					gap_row
				} else {
					0.0
				}
				retain_grid_area_for_absolute_descendants(items[i].as_node(), content_x + col_x[p.col], row_y[p.row], area_width, area_height, mut placed_box.absolute_static_positions, author_rules)
			}
			local_children << placed_box
		}
		content_height = yacc
		has_children = item_boxes.len > 0
	} else {
		// BLOCK FLOW: lay children out in a LOCAL frame whose origin is this box's content-box top-left.
		// Vertical margins collapse (CSS 2.1 §8.3.1) using the complete adjoining margin chain. Empty
		// self-collapsing blocks extend that chain instead of advancing the block cursor.
		mut flow_bottom := 0.0 // border-box bottom of the last placed child, in the local frame
		mut pending_margins := []f64{}
		mut leading_margins := []f64{}
		mut has_non_self_collapsing_child := false
		flow_children := block_flow_child_elements(element.as_node(), author_rules)
		flow_participants := if flow_children.len > 0 {
			block_flow_participants(element.as_node(), author_rules)
		} else {
			[]&dom.Element{}
		}
		for child in flow_participants {
			child_position := position_value(child, author_rules)
			if is_absolutely_positioned(child_position) {
				// BlockFormattingContext::layout_block_level_box() stores the BFC's current
				// border-box cursor before returning for an out-of-flow child. Pending adjoining
				// margins deliberately do not move this position.
				static_position := StaticPosition{
					x: content_x
					y: if has_non_self_collapsing_child { flow_bottom } else { 0.0 }
				}
				if child_position == 'fixed' {
					local_fixed_static_positions[i64(child.as_node().unique_id())] = static_position
				} else {
					local_absolute_static_positions[i64(child.as_node().unique_id())] = static_position
				}
				continue
			}
			if is_floating(child, author_rules) {
				minimum_float_y := if has_non_self_collapsing_child { flow_bottom } else { 0.0 }
				placed_float, band := place_float(child, minimum_float_y, content_x, width, float_bands, author_rules)
				placed_floats << placed_float
				float_bands << band
				if band.is_left {
					if band.bottom > left_floats_bottom {
						left_floats_bottom = band.bottom
					}
				} else if band.bottom > right_floats_bottom {
					right_floats_bottom = band.bottom
				}
				continue
			}
			mut cb := layout_block(child, content_x, 0.0, width, author_rules)
			self_collapsing := is_self_collapsing_empty_block(child, cb, author_rules)
			mut adjoining := pending_margins.clone()
			adjoining << cb.outer_top_margin
			mut desired_border_top := if has_non_self_collapsing_child {
				flow_bottom + collapse_margins(adjoining)
			} else if top_adjoins {
				0.0 // first child's top margin collapses through into this box's outer top margin
			} else {
				collapse_margins(adjoining) // separated by border/padding: margins stay inside
			}
			// `clear` moves the child below the relevant floats.
			clear_bottom := clearance_bottom(child, left_floats_bottom, right_floats_bottom, author_rules)
			if clear_bottom > desired_border_top {
				desired_border_top = clear_bottom
			}
			cb = translate_block(cb, 0.0, desired_border_top - cb.outer_top_margin)
			child_border_bottom := desired_border_top + cb.border.top + cb.padding.top + cb.height + cb.padding.bottom + cb.border.bottom
			if !has_non_self_collapsing_child {
				leading_margins << cb.outer_top_margin
				if self_collapsing {
					leading_margins << cb.outer_bottom_margin
				} else {
					first_child_outer_top = collapse_margins(leading_margins)
				}
			}
			if self_collapsing {
				pending_margins << cb.outer_top_margin
				pending_margins << cb.outer_bottom_margin
			} else {
				flow_bottom = child_border_bottom
				pending_margins = [cb.outer_bottom_margin]
				has_non_self_collapsing_child = true
			}
			has_children = true
			local_children << cb
		}
		if has_children {
			if !has_non_self_collapsing_child {
				first_child_outer_top = collapse_margins(leading_margins)
			}
			last_child_outer_bottom = collapse_margins(pending_margins)
		}

		// Auto content height: from the content-box top (local 0) to the last child's border-box bottom,
		// plus that child's outer bottom margin only when it stays inside the box. A box with no block
		// children lays out inline line boxes (also in the local frame).
		if has_children {
			content_height = if bottom_margin_contained {
				flow_bottom + last_child_outer_bottom
			} else {
				flow_bottom
			}
		} else {
			lines, inline_boxes, inline_absolute_static_positions, inline_fixed_static_positions := layout_inline_lines(element, content_x, width, float_bands, author_rules)
			local_lines = lines.clone()
			local_absolute_static_positions = inline_absolute_static_positions.clone()
			local_fixed_static_positions = inline_fixed_static_positions.clone()
			// Atomic inline (inline-block) boxes join the children so they are painted and measured.
			local_children << inline_boxes
			for line in local_lines {
				if line.y + line.height > content_height {
					content_height = line.y + line.height
				}
			}
		}
	}
	// A box that establishes a BFC grows to contain its floats (the `overflow:hidden`/`flow-root`
	// clearfix). Otherwise floats can overflow the box's bottom.
	if establishes_bfc {
		if left_floats_bottom > content_height {
			content_height = left_floats_bottom
		}
		if right_floats_bottom > content_height {
			content_height = right_floats_bottom
		}
	}

	// An explicit height sets the content height (content-box) or the border-box height (border-box,
	// so subtract the vertical border+padding); `auto` uses the flowed content height.
	border_padding_tb := border.top + border.bottom + padding.top + padding.bottom
	height_id := css.property_id_from_string('height') or { return BlockBox{} }
	mut height_is_auto := true
	tentative_height := if px := css.computed_length_px(element, height_id, author_rules) {
		height_is_auto = false
		if border_box {
			non_negative(px - border_padding_tb)
		} else {
			px
		}
	} else {
		content_height
	}
	// Clamp the height by min-height/max-height. Percentages need a definite containing height we
	// don't track, so only length constraints apply here (basis none).
	min_height := resolve_size_constraint(element, 'min-height', none, border_padding_tb, border_box, author_rules) or { 0.0 }
	max_height := resolve_size_constraint(element, 'max-height', none, border_padding_tb, border_box, author_rules)
	height := clamp_size(tentative_height, min_height, max_height)

	// FlexFormattingContext::parent_context_did_dimension_child_root_box() records the full content
	// rectangle for each direct abspos child only after the container has its final used size. The
	// rectangle's alignment is resolved later, once the child's margin-box size is known.
	if is_flex_row(element, author_rules) {
		retain_flex_static_positions(element, content_x, width, height, true, mut local_absolute_static_positions, mut local_fixed_static_positions, author_rules)
	} else if is_flex_column(element, author_rules) {
		retain_flex_static_positions(element, content_x, width, height, false, mut local_absolute_static_positions, mut local_fixed_static_positions, author_rules)
	} else if is_grid(element, author_rules) {
		// GridFormattingContext::calculate_static_position_rect() uses the grid content box when the
		// grid container is not itself the abspos containing block. Positioned grids replace this with
		// per-item grid-area rectangles in the separate containing-block resolution step.
		retain_grid_static_positions(element, content_x, width, height, padding, legacy_grid_columns, legacy_grid_rows, legacy_grid_column_gap, legacy_grid_row_gap, legacy_grid_column_names, legacy_grid_row_names, mut local_absolute_static_positions, mut local_fixed_static_positions, author_rules)
	}

	// This box's collapsed outer margins (propagated to the parent). The top collapses with the first
	// child's outer top margin when the top edges adjoin; the bottom collapses with the last child's
	// outer bottom margin when the bottom edges adjoin (no bottom border/padding AND auto height).
	bottom_adjoins := !bottom_margin_contained && height_is_auto && has_children
	outer_top_margin := if top_adjoins && has_children {
		collapse_margins([margin.top, first_child_outer_top])
	} else {
		margin.top
	}
	outer_bottom_margin := if bottom_adjoins {
		collapse_margins([margin.bottom, last_child_outer_bottom])
	} else {
		margin.bottom
	}

	// Place this box: its border-box top is `y` plus its collapsed outer top margin (plus any relative
	// offset, which doesn't participate in the flow computed above). Shift the
	// children from the local frame (content-box top = 0) to the real content-box top.
	content_top := y + outer_top_margin + border.top + padding.top + rel_y
	mut children := local_children.map(translate_block(it, 0.0, content_top))
	// Floats (also laid out in the local frame) join the children, shifted to the content-box top.
	for placed_float in placed_floats {
		children << translate_block(placed_float, 0.0, content_top)
	}
	lines := local_lines.map(translate_line(it, 0.0, content_top))
	mut absolute_static_positions := translate_static_positions(local_absolute_static_positions, 0.0, content_top)
	mut fixed_static_positions := translate_static_positions(local_fixed_static_positions, 0.0, content_top)
	for child in children {
		merge_static_positions(mut absolute_static_positions, child.absolute_static_positions)
		merge_static_positions(mut fixed_static_positions, child.fixed_static_positions)
	}

	// If this box is positioned, it is the containing block for its abspos descendants: lay them out
	// against its padding box (using its final, offset content origin). Their flow siblings above are
	// unaffected because abspos elements were excluded from the flow.
	position := position_value(element, author_rules)
	is_document_element := element.is_document_element()
	if is_positioned(position) || is_document_element {
		this_cb := PositionedContainingBlock{
			x: content_x - padding.left
			y: content_top - padding.top
			width: width + padding.left + padding.right
			height: height + padding.top + padding.bottom
		}
		scope_cb := if is_document_element && !is_positioned(position) {
			initial_containing_block(element, containing_width, height)
		} else {
			this_cb
		}
		include_fixed := !element.as_node().root().is_document()
		for abspos in collect_abspos_in_scope(element.as_node(), include_fixed, author_rules) {
			abspos_position := position_value(abspos, author_rules)
			static_position := if abspos_position == 'fixed' {
				fixed_static_positions[i64(abspos.as_node().unique_id())] or {
					StaticPosition{
						x: content_x
						y: content_top
					}
				}
			} else {
				absolute_static_positions[i64(abspos.as_node().unique_id())] or {
					StaticPosition{
						x: content_x
						y: content_top
					}
				}
			}
			target_cb := if abspos_position == 'fixed' {
				initial_containing_block(abspos, scope_cb.width, scope_cb.height)
			} else if static_position.has_containing_block_rect {
				PositionedContainingBlock{
					x: static_position.containing_block_x
					y: static_position.containing_block_y
					width: static_position.containing_block_width
					height: static_position.containing_block_height
				}
			} else {
				scope_cb
			}
			absolute_box := layout_absolute(abspos, target_cb, static_position, author_rules)
			merge_static_positions(mut fixed_static_positions, absolute_box.fixed_static_positions)
			children << absolute_box
		}
	}
	if is_document_element {
		viewport_cb := initial_containing_block(element, containing_width, height)
		for fixed in collect_fixed_descendants(element.as_node(), author_rules) {
			static_position := fixed_static_positions[i64(fixed.as_node().unique_id())] or {
				StaticPosition{
					x: content_x
					y: content_top
				}
			}
			fixed_box := layout_absolute(fixed, viewport_cb, static_position, author_rules)
			merge_static_positions(mut fixed_static_positions, fixed_box.fixed_static_positions)
			children << fixed_box
		}
	}

	// z-index applies only to positioned boxes. A non-auto z-index, fixed/sticky positioning,
	// opacity, or a transform establishes a stacking context for the paint-order collector.
	positioned := is_positioned(position)
	z_index_value := css.cascaded_value_with_ua(element, css.property_id_from_string('z-index') or {
		return BlockBox{}
	}, author_rules)
	z_index := if positioned && z_index_value != 'auto' {
		z_index_value.int()
	} else {
		0
	}

	// Computed colors for the display list: background-color (default transparent) and text color
	// (default black).
	background_color := css.computed_color(element, css.property_id_from_string('background-color') or {
		return BlockBox{}
	}, author_rules) or { css.Color{0, 0, 0, 0} }
	text_color := css.computed_color(element, css.property_id_from_string('color') or {
		return BlockBox{}
	}, author_rules) or { css.Color{0, 0, 0, 255} }
	// Each border side resolves independently; the compatibility `border_color` field retains the
	// top side for callers that predate the four-side transport.
	border_colors := resolved_border_colors(element, text_color, author_rules)
	border_color := border_colors.top
	border_styles := resolved_border_styles(element, author_rules)
	// Opacity (0..1) — this box's own; the display list accumulates it down the tree.
	mut opacity := css.cascaded_value_with_ua(element, css.property_id_from_string('opacity') or {
		return BlockBox{}
	}, author_rules).f64()
	if opacity < 0.0 {
		opacity = 0.0
	} else if opacity > 1.0 {
		opacity = 1.0
	}
	transform_value := css.cascaded_value_with_ua(element, css.property_id_from_string('transform') or {
		return BlockBox{}
	}, author_rules)
	stacking_context := (positioned && z_index_value != 'auto') || position in ['fixed', 'sticky'] || opacity < 1.0 || (transform_value != '' && transform_value != 'none')
	// `visibility` (inherited): a hidden box still occupies space but paints nothing.
	visible := css.cascaded_value_with_ua(element, css.property_id_from_string('visibility') or {
		return BlockBox{}
	}, author_rules) == 'visible'
	pointer_events_enabled := css.cascaded_value_with_ua(element, css.property_id_from_string('pointer-events') or {
		return BlockBox{}
	}, author_rules) != 'none'

	// A `display: list-item` box gets a marker (bullet or ordinal) hanging to the left of its content.
	mut lines_with_marker := lines.clone()
	list_position := css.cascaded_value_with_ua(element, css.property_id_from_string('list-style-position') or {
		return BlockBox{}
	}, author_rules)
	if list_position == 'inside' {
		lines_with_marker = add_inside_list_marker(element, content_x, width, content_top, text_color, lines_with_marker, author_rules)
	} else if marker_line := list_marker_line(element, content_x, content_top, text_color, lines_with_marker, author_rules) {
		lines_with_marker.prepend(marker_line)
	}

	// Resolve all four elliptical radii and apply CSS's overlap-reduction factor.
	border_box_width := width + padding.left + padding.right + border.left + border.right
	border_box_height := height + padding.top + padding.bottom + border.top + border.bottom
	border_radii := resolve_box_radii(element, border_box_width, border_box_height, author_rules)
	border_radius := border_radii.top_left.x
	paint_transform := resolved_transform_matrix(element, content_x - padding.left - border.left, content_top - padding.top - border.top, border_box_width, border_box_height, author_rules)
	if !affine_is_compact_identity(paint_transform) {
		children = children.map(apply_ancestor_affine(it, paint_transform))
	}

	// Outline (painted outside the border box, no effect on layout): width, offset, and color
	// (outline-color defaults to `currentColor`, which resolves to the text color).
	outline_style_value := css.cascaded_value_with_ua(element, .outline_style, author_rules)
	outline_width := used_outline_width(element, author_rules)
	outline_style := if outline_style_value == 'auto' {
		painting.LineStyle.solid
	} else {
		border_line_style_from_string(outline_style_value)
	}
	outline_offset := css.computed_length_px(element, css.property_id_from_string('outline-offset') or {
		return BlockBox{}
	}, author_rules) or { 0.0 }
	outline_color := if outline_style_value == 'auto' {
		css.SystemColor.accent_color(.light)
	} else {
		css.computed_color(element, css.property_id_from_string('outline-color') or {
			return BlockBox{}
		}, author_rules) or { text_color }
	}
	// Outer box shadows, painted behind the box in list order.
	mut shadow := ?BoxShadow(none)
	shadows := parse_box_shadows(element, author_rules)
	if shadows.len > 0 {
		shadow = shadows[0]
	}
	// A linear-gradient background image (painted over the background color).
	mut background_gradient := ?LinearGradient(none)
	if g := parse_background_gradient(element, author_rules) {
		background_gradient = g
	}
	background_images := parse_background_image_layers(element, author_rules)

	return BlockBox{
		tag_name: element.local_name()
		x: content_x
		y: content_top
		width: width
		height: height
		margin: margin
		border: border
		padding: padding
		outer_top_margin: outer_top_margin
		outer_bottom_margin: outer_bottom_margin
		z_index: z_index
		positioned: positioned
		absolutely_positioned: is_absolutely_positioned(position)
		stacking_context: stacking_context
		background_color: background_color
		text_color: text_color
		border_color: border_color
		border_colors: border_colors
		border_styles: border_styles
		border_radius: border_radius
		border_radii: border_radii
		outline_width: outline_width
		outline_offset: outline_offset
		outline_color: outline_color
		outline_style: outline_style
		shadow: shadow
		shadows: shadows
		background_gradient: background_gradient
		background_images: background_images
		opacity: opacity
		visible: visible
		pointer_events_enabled: pointer_events_enabled
		node_id: i64(element.as_node().unique_id())
		absolute_static_positions: if is_positioned(position) || is_document_element {
			map[i64]StaticPosition{}
		} else {
			absolute_static_positions
		}
		fixed_static_positions: if is_document_element {
			map[i64]StaticPosition{}
		} else {
			fixed_static_positions
		}
		children: children
		lines: lines_with_marker
		own_paint_transform: paint_transform
		paint_transform: paint_transform
	}
}
