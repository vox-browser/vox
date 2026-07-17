module layout

import css

// Translation of Ladybird's Layout::LayoutState + LayoutState::UsedValues (Layout/LayoutState.h) — the
// per-box geometry produced by a formatting context: content size, offset within the containing block,
// and the used margin/border/padding/inset. The persistent Box holds no geometry; a formatting context
// reads/writes UsedValues in a LayoutState and commits them to paintables at the end.
//
// Simplifications: C++ LayoutState uses a paged Node->UsedValues store; this port uses a map keyed by
// node pointer identity. Border-collapse (border_*_collapsed) is not modelled yet — the plain border_*
// used value is returned. materialize_from_paintable / resolve_relative_positions (painting boundary) are
// deferred.

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
}

pub fn (u &UsedValues) node() &NodeWithStyle {
	return u.node_
}

pub fn (u &UsedValues) containing_block_used_values() ?&UsedValues {
	return u.containing_block_used_values_
}

pub fn (mut u UsedValues) set_containing_block_used_values(containing_block ?&UsedValues) {
	u.containing_block_used_values_ = containing_block
}

// --- Content size ---

pub fn (u &UsedValues) content_width() CSSPixels {
	return u.content_width_
}

pub fn (u &UsedValues) content_height() CSSPixels {
	return u.content_height_
}

pub fn (mut u UsedValues) set_content_width(width CSSPixels) {
	u.content_width_ = width
	u.has_definite_width_ = true
}

pub fn (mut u UsedValues) set_content_height(height CSSPixels) {
	u.content_height_ = height
	u.has_definite_height_ = true
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

@[heap]
pub struct LayoutState {
pub mut:
	// Node -> UsedValues, keyed by the NodeWithStyle's pointer identity.
	used_values_per_node map[u64]&UsedValues
}

pub fn LayoutState.new() &LayoutState {
	return &LayoutState{
		used_values_per_node: map[u64]&UsedValues{}
	}
}

fn layout_state_key(node &NodeWithStyle) u64 {
	return u64(voidptr(node))
}

// The UsedValues for `node`, creating an empty one on first access (Layout::LayoutState::get_mutable).
pub fn (mut state LayoutState) get_mutable(node &NodeWithStyle) &UsedValues {
	key := layout_state_key(node)
	if used_values := state.used_values_per_node[key] {
		return used_values
	}
	used_values := &UsedValues{
		node_: node
	}
	state.used_values_per_node[key] = used_values
	return used_values
}

// The UsedValues for `node`, or none if it has none yet (Layout::LayoutState::try_get_mutable).
pub fn (state &LayoutState) try_get(node &NodeWithStyle) ?&UsedValues {
	return state.used_values_per_node[layout_state_key(node)] or { return none }
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
