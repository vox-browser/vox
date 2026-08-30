module layout

import css
import svg

// Translation of Ladybird's Layout::LayoutState + LayoutState::UsedValues (Layout/LayoutState.h) — the
// per-box geometry produced by a formatting context: content size, offset within the containing block,
// and the used margin/border/padding/inset. The persistent Box holds no geometry; a formatting context
// reads/writes UsedValues in a LayoutState and commits them to paintables at the end.
//
// Border-collapse, paintable materialization, and relative-position resolution
// are translated in the sections below as their dependent painting types become
// available in the V port.

// https://www.w3.org/TR/css-sizing-3/#available — a size can be constrained to min-/max-content.
pub enum SizeConstraint {
	none
	min_content
	max_content
}

@[heap]
pub struct UsedValues {
pub mut:
	node_                         &NodeWithStyle = unsafe { nil }
	containing_block_used_values_ ?&UsedValues
	content_width_                CSSPixels
	content_height_               CSSPixels
	has_definite_width_           bool
	has_definite_height_          bool
	width_constraint              SizeConstraint = .none
	height_constraint             SizeConstraint = .none
	// Offset from the top-left of the containing block's content area to this box's content area.
	offset css.CSSPixelPoint
	// Used values of the box-model edges.
	margin_left    CSSPixels
	margin_right   CSSPixels
	margin_top     CSSPixels
	margin_bottom  CSSPixels
	border_left    CSSPixels
	border_right   CSSPixels
	border_top     CSSPixels
	border_bottom  CSSPixels
	padding_left   CSSPixels
	padding_right  CSSPixels
	padding_top    CSSPixels
	padding_bottom CSSPixels
	inset_left     CSSPixels
	inset_right    CSSPixels
	inset_top      CSSPixels
	inset_bottom   CSSPixels
	// Flex/Grid call FormattingContext::compute_inset() with the resolved
	// item's containing-area size. Preserve that explicit percentage basis for
	// the final relative-inset pass instead of substituting the parent box.
	relative_inset_basis_width_   ?CSSPixels
	relative_inset_basis_height_  ?CSSPixels
	line_boxes                    []LineBox
	containing_line_box_fragment  ?LineBoxFragmentCoordinate
	static_position_rect_         ?StaticPositionRect
	abspos_containing_block_rect_ ?css.CSSPixelRect
	computed_svg_path_            ?svg.Path
	has_computed_svg_transforms_  bool
	svg_viewbox_transform_        svg.AffineTransform
	svg_transform_                svg.AffineTransform
	svg_text_                     string
	svg_rendering_disabled_       bool
	use_collapsing_borders_model_ bool
	scrollable_overflow_rect_     ?css.CSSPixelRect
	has_scrollable_overflow_      bool
}

pub fn (u &UsedValues) node() &NodeWithStyle {
	return u.node_
}

pub fn (u &UsedValues) containing_block_used_values() ?&UsedValues {
	return u.containing_block_used_values_
}

pub fn (u &UsedValues) use_collapsing_borders_model() bool {
	return u.use_collapsing_borders_model_
}

pub fn (u &UsedValues) scrollable_overflow_rect() ?css.CSSPixelRect {
	return u.scrollable_overflow_rect_
}

pub fn (u &UsedValues) has_scrollable_overflow() bool {
	return u.has_scrollable_overflow_
}

pub fn (mut u UsedValues) set_containing_block_used_values(containing_block ?&UsedValues) {
	u.containing_block_used_values_ = containing_block
}

// LayoutState::UsedValues::set_node(). Resolve every generally-definite size
// before a formatting context runs. Formatting-context-specific definiteness
// is still established later by set_content_width()/set_content_height(), as
// in LibWeb.
fn (mut u UsedValues) set_node(node &NodeWithStyle, containing_block_used_values ?&UsedValues) {
	u.node_ = node
	u.containing_block_used_values_ = containing_block_used_values
	computed := node.computed_values()

	min_width := resolve_definite_size(node, computed, computed.size_value(.min_width),
		containing_block_used_values, true, u)
	max_width := resolve_definite_size(node, computed, computed.size_value(.max_width),
		containing_block_used_values, true, u)
	min_height := resolve_definite_size(node, computed, computed.size_value(.min_height),
		containing_block_used_values, false, u)
	max_height := resolve_definite_size(node, computed, computed.size_value(.max_height),
		containing_block_used_values, false, u)

	if width := resolve_definite_size(node, computed, computed.size_value(.width),
		containing_block_used_values, true, u)
	{
		u.content_width_ = clamp_to_max_dimension_value(width)
		u.has_definite_width_ = true
		if minimum := min_width {
			if u.content_width_.raw_value() < minimum.raw_value() {
				u.content_width_ = clamp_to_max_dimension_value(minimum)
			}
		}
		if maximum := max_width {
			if u.content_width_.raw_value() > maximum.raw_value() {
				u.content_width_ = clamp_to_max_dimension_value(maximum)
			}
		}
	}
	if height := resolve_definite_size(node, computed, computed.size_value(.height),
		containing_block_used_values, false, u)
	{
		u.content_height_ = clamp_to_max_dimension_value(height)
		u.has_definite_height_ = true
		if minimum := min_height {
			if u.content_height_.raw_value() < minimum.raw_value() {
				u.content_height_ = clamp_to_max_dimension_value(minimum)
			}
		}
		if maximum := max_height {
			if u.content_height_.raw_value() > maximum.raw_value() {
				u.content_height_ = clamp_to_max_dimension_value(maximum)
			}
		}
	}
}

fn resolve_definite_size(node &NodeWithStyle, computed &css.ComputedProperties, size css.Size, containing_block_used_values ?&UsedValues, width bool, used_values &UsedValues) ?CSSPixels {
	containing_block_has_definite_size := if containing_block := containing_block_used_values {
		if width {
			containing_block.has_definite_width()
		} else {
			containing_block.has_definite_height()
		}
	} else {
		false
	}

	if size.is_auto() {
		parent := unsafe { &Node(node) }.parent() or { return none }
		if width && !unsafe { &Node(node) }.is_floating()
			&& !unsafe { &Node(node) }.is_absolutely_positioned()
			&& computed.display().is_block_outside() && !parent.is_floating()
			&& (parent.display().is_flow_root_inside() || parent.display().is_flow_inside()) {
			if containing_block := containing_block_used_values {
				if containing_block_has_definite_size {
					available_width := containing_block.content_width().to_double()
					resolved := available_width - used_values.margin_left.to_double() -
						used_values.margin_right.to_double() -
						used_values.padding_left.to_double() -
						used_values.padding_right.to_double() -
						used_values.border_left.to_double() - used_values.border_right.to_double()
					return clamp_to_max_dimension_value(CSSPixels.nearest_value_for(resolved))
				}
			}
		}
		return none
	}

	if !size.is_length() && !size.is_percentage() && !size.is_calculated() {
		return none
	}
	if size.contains_percentage() && !containing_block_has_definite_size {
		return none
	}
	mut context := css.LengthResolutionContext.for_document(node.document())
	font_size := CSSPixels.nearest_value_for(computed.resolved_font_size_px())
	font_metrics := layout_font_metrics_for_node(node)
	context.font_metrics.font_size = font_size
	context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(font_metrics.x_height))
	context.font_metrics.cap_height = font_size.scaled(0.75)
	context.font_metrics.zero_advance =
		CSSPixels.nearest_value_for(f64(font_metrics.advance_of_ascii_zero))
	context.font_metrics.line_height = computed.line_height()
	reference_value := if containing_block := containing_block_used_values {
		if width { containing_block.content_width() } else { containing_block.content_height() }
	} else {
		CSSPixels.new(0)
	}
	resolved := size.to_px(context, reference_value)
	return clamp_to_max_dimension_value(adjust_size_for_box_sizing(computed, size, resolved, width,
		containing_block_used_values, context))
}

fn adjust_size_for_box_sizing(computed &css.ComputedProperties, computed_size css.Size, unadjusted CSSPixels, width bool, containing_block_used_values ?&UsedValues, context css.LengthResolutionContext) CSSPixels {
	if computed.box_sizing() == .content_box || computed_size.is_auto() {
		return unadjusted
	}
	containing_block_width := if containing_block := containing_block_used_values {
		containing_block.content_width()
	} else {
		CSSPixels.new(0)
	}
	mut border_and_padding := CSSPixels.new(0)
	if width {
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed,
			.border_left_width, .border_left_style, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .padding_left,
			none, containing_block_width, context, false))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed,
			.border_right_width, .border_right_style, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed,
			.padding_right, none, containing_block_width, context, false))
	} else {
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed,
			.border_top_width, .border_top_style, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .padding_top,
			none, containing_block_width, context, false))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed,
			.border_bottom_width, .border_bottom_style, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed,
			.padding_bottom, none, containing_block_width, context, false))
	}
	return unadjusted.minus(border_and_padding)
}

fn resolve_computed_edge(computed &css.ComputedProperties, property_id css.PropertyID, style_property_id ?css.PropertyID, containing_block_width CSSPixels, context css.LengthResolutionContext, is_border bool) CSSPixels {
	if is_border {
		style_id := style_property_id or { return CSSPixels.new(0) }
		style := computed.property(style_id, .yes) or { return CSSPixels.new(0) }
		if style.css_text.trim_space().to_lower() in ['none', 'hidden'] {
			return CSSPixels.new(0)
		}
	}
	size := computed.size_value(property_id)
	if !size.is_length() && !size.is_percentage() && !size.is_calculated() {
		return CSSPixels.new(0)
	}
	return size.to_px(context, containing_block_width)
}

// --- Content size ---

pub fn (u &UsedValues) content_width() CSSPixels {
	return u.content_width_
}

pub fn (u &UsedValues) content_height() CSSPixels {
	return u.content_height_
}

pub fn (mut u UsedValues) set_content_width(width CSSPixels) {
	u.content_width_ = if width.raw_value() < 0 {
		CSSPixels.new(0)
	} else {
		clamp_to_max_dimension_value(width)
	}
	u.has_definite_width_ = true
}

pub fn (mut u UsedValues) set_content_height(height CSSPixels) {
	u.content_height_ = if height.raw_value() < 0 {
		CSSPixels.new(0)
	} else {
		clamp_to_max_dimension_value(height)
	}
}

pub fn (u &UsedValues) content_size() css.CSSPixelSize {
	return css.CSSPixelSize.from_values(u.content_width_.to_double(), u.content_height_.to_double())
}

pub fn (mut u UsedValues) set_indefinite_content_width() {
	u.has_definite_width_ = false
}

pub fn (mut u UsedValues) set_indefinite_content_height() {
	u.has_definite_height_ = false
}

pub fn (mut u UsedValues) set_has_definite_width(has_definite_width bool) {
	u.has_definite_width_ = has_definite_width
}

pub fn (mut u UsedValues) set_has_definite_height(has_definite_height bool) {
	u.has_definite_height_ = has_definite_height
}

// A size is definite only if flagged AND not under a min-/max-content constraint.
pub fn (u &UsedValues) has_definite_width() bool {
	return u.has_definite_width_ && u.width_constraint == .none
}

pub fn (u &UsedValues) has_definite_height() bool {
	return u.has_definite_height_ && u.height_constraint == .none
}

fn (u &UsedValues) available_width_inside() AvailableSize {
	return match u.width_constraint {
		.min_content {
			AvailableSize.make_min_content()
		}
		.max_content {
			AvailableSize.make_max_content()
		}
		.none {
			if u.has_definite_width() {
				AvailableSize.make_definite(u.content_width_)
			} else {
				AvailableSize.make_indefinite()
			}
		}
	}
}

fn (u &UsedValues) available_height_inside() AvailableSize {
	return match u.height_constraint {
		.min_content {
			AvailableSize.make_min_content()
		}
		.max_content {
			AvailableSize.make_max_content()
		}
		.none {
			if u.has_definite_height() {
				AvailableSize.make_definite(u.content_height_)
			} else {
				AvailableSize.make_indefinite()
			}
		}
	}
}

pub fn (u &UsedValues) available_inner_space_or_constraints_from(outer_space AvailableSpace) AvailableSpace {
	mut width := u.available_width_inside()
	mut height := u.available_height_inside()
	if width.is_indefinite() && outer_space.width.is_intrinsic_sizing_constraint() {
		width = outer_space.width
	}
	if height.is_indefinite() && outer_space.height.is_intrinsic_sizing_constraint() {
		height = outer_space.height
	}
	return AvailableSpace.new(width, height)
}

// --- Offset ---

pub fn (mut u UsedValues) set_content_offset(new_offset css.CSSPixelPoint) {
	u.offset = new_offset
}

pub fn (mut u UsedValues) set_content_x(x CSSPixels) {
	u.offset = css.CSSPixelPoint.from_values(x.to_double(), u.offset.y().to_double())
}

pub fn (mut u UsedValues) set_content_y(y CSSPixels) {
	u.offset = css.CSSPixelPoint.from_values(u.offset.x().to_double(), y.to_double())
}

// Offset from the viewport's top-left to this box's content area (sum of offsets up the containing-block chain).
pub fn (u &UsedValues) cumulative_offset() css.CSSPixelPoint {
	if containing_block := u.containing_block_used_values_ {
		return css_pixel_point_add(containing_block.cumulative_offset(), u.offset)
	}
	return u.offset
}

pub fn (mut u UsedValues) set_static_position_rect(position StaticPositionRect) {
	u.static_position_rect_ = position
}

pub fn (mut u UsedValues) set_abspos_containing_block_rect(rect css.CSSPixelRect) {
	u.abspos_containing_block_rect_ = rect
}

pub fn (u &UsedValues) abspos_containing_block_rect() ?css.CSSPixelRect {
	return u.abspos_containing_block_rect_
}

pub fn (u &UsedValues) static_position() css.CSSPixelPoint {
	position := u.static_position_rect_ or { return css.CSSPixelPoint{} }
	return position.aligned_position_for_box_with_size(css.CSSPixelSize.new(u.margin_box_width(),
		u.margin_box_height()))
}

// SVGGraphicsPaintable::ComputedTransforms and the path materialized by
// SVGFormattingContext. Painting consumes the same state instead of reparsing
// geometry independently.
pub fn (mut u UsedValues) set_computed_svg_path(path svg.Path) {
	u.computed_svg_path_ = path
}

pub fn (u &UsedValues) computed_svg_path() ?svg.Path {
	return u.computed_svg_path_
}

pub fn (mut u UsedValues) set_computed_svg_transforms(viewbox_transform svg.AffineTransform, svg_transform svg.AffineTransform) {
	u.has_computed_svg_transforms_ = true
	u.svg_viewbox_transform_ = viewbox_transform
	u.svg_transform_ = svg_transform
}

pub fn (u &UsedValues) has_computed_svg_transforms() bool {
	return u.has_computed_svg_transforms_
}

pub fn (u &UsedValues) svg_viewbox_transform() svg.AffineTransform {
	return u.svg_viewbox_transform_
}

pub fn (u &UsedValues) svg_transform() svg.AffineTransform {
	return u.svg_transform_
}

pub fn (mut u UsedValues) set_svg_text(text string) {
	u.svg_text_ = text
}

pub fn (mut u UsedValues) set_svg_rendering_disabled(disabled bool) {
	u.svg_rendering_disabled_ = disabled
}

pub fn (u &UsedValues) svg_rendering_disabled() bool {
	return u.svg_rendering_disabled_
}

pub fn (u &UsedValues) svg_text() string {
	return u.svg_text_
}

// --- Margin box (margin + border + padding + content) ---

pub fn (u &UsedValues) margin_box_left() CSSPixels {
	return css_pixels_sum([u.margin_left, u.border_left, u.padding_left])
}

pub fn (u &UsedValues) margin_box_right() CSSPixels {
	return css_pixels_sum([u.margin_right, u.border_right, u.padding_right])
}

pub fn (u &UsedValues) margin_box_top() CSSPixels {
	return css_pixels_sum([u.margin_top, u.border_top, u.padding_top])
}

pub fn (u &UsedValues) margin_box_bottom() CSSPixels {
	return css_pixels_sum([u.margin_bottom, u.border_bottom, u.padding_bottom])
}

pub fn (u &UsedValues) margin_box_width() CSSPixels {
	return css_pixels_sum([u.margin_box_left(), u.content_width_, u.margin_box_right()])
}

pub fn (u &UsedValues) margin_box_height() CSSPixels {
	return css_pixels_sum([u.margin_box_top(), u.content_height_, u.margin_box_bottom()])
}

// --- Border box (border + padding + content) ---

pub fn (u &UsedValues) border_box_left() CSSPixels {
	return css_pixels_sum([u.border_left, u.padding_left])
}

pub fn (u &UsedValues) border_box_right() CSSPixels {
	return css_pixels_sum([u.border_right, u.padding_right])
}

pub fn (u &UsedValues) border_box_top() CSSPixels {
	return css_pixels_sum([u.border_top, u.padding_top])
}

pub fn (u &UsedValues) border_box_bottom() CSSPixels {
	return css_pixels_sum([u.border_bottom, u.padding_bottom])
}

pub fn (u &UsedValues) border_box_width() CSSPixels {
	return css_pixels_sum([u.border_box_left(), u.content_width_, u.border_box_right()])
}

pub fn (u &UsedValues) border_box_height() CSSPixels {
	return css_pixels_sum([u.border_box_top(), u.content_height_, u.border_box_bottom()])
}

// --- LayoutState ---

// Sparse, index-based two-level page table from LayoutState.h. Layout state is
// rebuilt on each pass, so pages are allocated only on the first write while
// lookup remains O(1) without hashing.
const layout_state_page_bits = u32(4)
const layout_state_page_size = u32(1) << layout_state_page_bits
const layout_state_page_mask = layout_state_page_size - 1

@[heap]
struct UsedValuesPage {
mut:
	entries []?&UsedValues
}

fn UsedValuesPage.new() &UsedValuesPage {
	return &UsedValuesPage{
		entries: []?&UsedValues{len: int(layout_state_page_size), init: none}
	}
}

@[heap]
struct UsedValuesPagedStore {
mut:
	pages []?&UsedValuesPage
}

fn (mut store UsedValuesPagedStore) ensure_capacity(count u32) {
	required_page_count := int((count + layout_state_page_size - 1) >> layout_state_page_bits)
	for store.pages.len < required_page_count {
		store.pages << none
	}
}

fn (store &UsedValuesPagedStore) get(index u32) ?&UsedValues {
	page_index := int(index >> layout_state_page_bits)
	if page_index >= store.pages.len {
		return none
	}
	page := store.pages[page_index] or { return none }
	return page.entries[int(index & layout_state_page_mask)] or { return none }
}

fn (mut store UsedValuesPagedStore) allocate(index u32) &UsedValues {
	page_index := int(index >> layout_state_page_bits)
	if page_index >= store.pages.len {
		store.ensure_capacity(index + 1)
	}
	mut page := store.pages[page_index] or {
		new_page := UsedValuesPage.new()
		store.pages[page_index] = new_page
		new_page
	}
	entry := &UsedValues{}
	page.entries[int(index & layout_state_page_mask)] = entry
	return entry
}

fn (store &UsedValuesPagedStore) for_each(callback fn (&UsedValues)) {
	for maybe_page in store.pages {
		page := maybe_page or { continue }
		for maybe_entry in page.entries {
			entry := maybe_entry or { continue }
			callback(entry)
		}
	}
}

@[heap]
pub struct LayoutState {
pub mut:
	used_values_store UsedValuesPagedStore
	subtree_root      ?&NodeWithStyle
}

pub fn LayoutState.new() &LayoutState {
	return &LayoutState{}
}

pub fn LayoutState.new_for_subtree(subtree_root &NodeWithStyle) &LayoutState {
	return &LayoutState{
		subtree_root: subtree_root
	}
}

pub fn (mut state LayoutState) ensure_capacity(node_count u32) {
	state.used_values_store.ensure_capacity(node_count)
}

// The UsedValues for `node`, creating an empty one on first access (Layout::LayoutState::get_mutable).
pub fn (mut state LayoutState) get_mutable(node &NodeWithStyle) &UsedValues {
	return state.ensure_used_values_for(node)
}

pub fn (mut state LayoutState) get(node &NodeWithStyle) &UsedValues {
	return state.ensure_used_values_for(node)
}

// LayoutState::populate_node_from(). Intrinsic sizing and partial subtree
// layout need the already-resolved geometry of an ancestor without making
// that ancestor part of the throwaway subtree. Keep the copied node and box
// metrics, but sever its containing-block pointer exactly like LibWeb does.
pub fn (mut state LayoutState) populate_node_from(mut source LayoutState, node &NodeWithStyle) &UsedValues {
	index := node.layout_index()
	if state.used_values_store.get(index) != none {
		panic('VERIFY(!m_used_values_store.get(index))')
	}
	source_values := source.get(node)
	mut values := state.used_values_store.allocate(index)
	values.node_ = source_values.node_
	values.content_width_ = source_values.content_width_
	values.content_height_ = source_values.content_height_
	values.has_definite_width_ = source_values.has_definite_width_
	values.has_definite_height_ = source_values.has_definite_height_
	values.width_constraint = source_values.width_constraint
	values.height_constraint = source_values.height_constraint
	values.offset = source_values.offset
	values.margin_left = source_values.margin_left
	values.margin_right = source_values.margin_right
	values.margin_top = source_values.margin_top
	values.margin_bottom = source_values.margin_bottom
	values.border_left = source_values.border_left
	values.border_right = source_values.border_right
	values.border_top = source_values.border_top
	values.border_bottom = source_values.border_bottom
	values.padding_left = source_values.padding_left
	values.padding_right = source_values.padding_right
	values.padding_top = source_values.padding_top
	values.padding_bottom = source_values.padding_bottom
	values.inset_left = source_values.inset_left
	values.inset_right = source_values.inset_right
	values.inset_top = source_values.inset_top
	values.inset_bottom = source_values.inset_bottom
	values.line_boxes = source_values.line_boxes.clone()
	values.containing_line_box_fragment = source_values.containing_line_box_fragment
	values.static_position_rect_ = source_values.static_position_rect_
	values.abspos_containing_block_rect_ = source_values.abspos_containing_block_rect_
	values.computed_svg_path_ = source_values.computed_svg_path_
	values.has_computed_svg_transforms_ = source_values.has_computed_svg_transforms_
	values.svg_viewbox_transform_ = source_values.svg_viewbox_transform_
	values.svg_transform_ = source_values.svg_transform_
	values.svg_text_ = source_values.svg_text_
	values.svg_rendering_disabled_ = source_values.svg_rendering_disabled_
	values.containing_block_used_values_ = none
	return values
}

fn (mut state LayoutState) ensure_used_values_for(node &NodeWithStyle) &UsedValues {
	index := node.layout_index()
	if used_values := state.used_values_store.get(index) {
		return used_values
	}
	node_as_node := unsafe { &Node(node) }
	if subtree_root := state.subtree_root {
		root_as_node := unsafe { &Node(subtree_root) }
		if voidptr(subtree_root) != voidptr(node)
			&& !root_as_node.is_inclusive_ancestor_of(node_as_node) {
			panic('LayoutState subtree root ${layout_debug_class_name(root_as_node)} <${layout_debug_tag(root_as_node)}> does not contain ${layout_debug_class_name(node_as_node)} <${layout_debug_tag(node_as_node)}>')
		}
	}
	mut containing_block_used_values := ?&UsedValues(none)
	if subtree_root := state.subtree_root {
		if voidptr(subtree_root) == voidptr(node) {
			if containing_block := node_as_node.containing_block() {
				if containing_block_node := unsafe { &Node(containing_block) }.as_node_with_style() {
					containing_block_used_values = state.try_get(containing_block_node)
				}
			}
		} else if !node_as_node.is_viewport() {
			containing_block := node_as_node.containing_block() or {
				panic('VERIFY(node.containing_block())')
			}
			containing_block_node := unsafe { &Node(containing_block) }.as_node_with_style() or {
				panic('containing block must have style')
			}
			containing_block_used_values = state.ensure_used_values_for(containing_block_node)
		}
	} else if !node_as_node.is_viewport() {
		if containing_block := node_as_node.containing_block() {
			containing_block_node := unsafe { &Node(containing_block) }.as_node_with_style() or {
				panic('containing block must have style')
			}
			containing_block_used_values = state.ensure_used_values_for(containing_block_node)
		}
	}
	mut used_values := state.used_values_store.allocate(index)
	used_values.set_node(node, containing_block_used_values)
	return used_values
}

// The UsedValues for `node`, or none if it has none yet (Layout::LayoutState::try_get_mutable).
pub fn (state &LayoutState) try_get(node &NodeWithStyle) ?&UsedValues {
	return state.used_values_store.get(node.layout_index())
}

pub fn (state &LayoutState) try_get_mutable(node &NodeWithStyle) ?&UsedValues {
	return state.used_values_store.get(node.layout_index())
}

// --- CSSPixels helpers (the port's CSSPixels has no arithmetic operators) ---

fn css_pixels_sum(values []CSSPixels) CSSPixels {
	mut total := 0.0
	for value in values {
		total += value.to_double()
	}
	return CSSPixels.nearest_value_for(total)
}

fn css_pixel_point_add(a css.CSSPixelPoint, b css.CSSPixelPoint) css.CSSPixelPoint {
	return css.CSSPixelPoint.from_values(a.x().to_double() + b.x().to_double(), a.y().to_double() +
		b.y().to_double())
}

pub fn clamp_to_max_dimension_value(value CSSPixels) CSSPixels {
	if value.might_be_saturated() {
		return CSSPixels.nearest_value_for(f64(css.css_pixels_max_dimension_value))
	}
	return value
}
