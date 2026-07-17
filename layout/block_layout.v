module layout

import css

// First slices of the block layout algorithm (Layout/BlockFormattingContext.cpp + FormattingContext.cpp):
// resolve a box's used box-model edges from its computed style, and compute the used width of a
// normal-flow block-level box per CSS 2.1 §10.3.3 (including auto width / auto margins).
//
// DEFERRED: min/max-width clamping, replaced/inline/float/abspos width, over-constrained resolution
// direction (assumes LTR, drops margin-right), border-width vs border-style interaction, and vertical
// layout (heights + child stacking) — later slices.

fn css_px(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(value)
}

// Whether `property_id`'s computed value is the `auto` keyword.
fn property_is_auto(computed &css.ComputedProperties, property_id css.PropertyID) bool {
	value := computed.property(property_id, .yes) or { return false }
	return value.css_text.trim_space().to_lower() == 'auto'
}

// The used border width for one side: 0 if that side's border-style is none/hidden (CSS 2.1 §8.5.3),
// otherwise the resolved border-width.
fn resolve_used_border_width(computed &css.ComputedProperties, width_property css.PropertyID, style_property css.PropertyID, containing_block_width f64) f64 {
	style_value := computed.property(style_property, .yes) or { return 0.0 }
	style_keyword := style_value.css_text.trim_space().to_lower()
	if style_keyword == 'none' || style_keyword == 'hidden' {
		return 0.0
	}
	return computed.length_percentage_to_px(width_property, containing_block_width) or { 0.0 }
}

// Resolve the used margin/border/padding edges from `computed` into `used_values`. `containing_block_width`
// is the percentage basis. `auto` margins resolve to 0 here (compute_block_used_width may reassign them).
fn resolve_box_model_edges(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64) {
	used_values.padding_left = css_px(computed.length_percentage_to_px(.padding_left, containing_block_width) or {
		0.0
	})
	used_values.padding_right = css_px(computed.length_percentage_to_px(.padding_right, containing_block_width) or {
		0.0
	})
	used_values.padding_top = css_px(computed.length_percentage_to_px(.padding_top, containing_block_width) or {
		0.0
	})
	used_values.padding_bottom = css_px(computed.length_percentage_to_px(.padding_bottom, containing_block_width) or {
		0.0
	})

	// CSS 2.1 §8.5.3: the used border width is 0 when the border style is none or hidden.
	used_values.border_left = css_px(resolve_used_border_width(computed, .border_left_width,
		.border_left_style, containing_block_width))
	used_values.border_right = css_px(resolve_used_border_width(computed, .border_right_width,
		.border_right_style, containing_block_width))
	used_values.border_top = css_px(resolve_used_border_width(computed, .border_top_width, .border_top_style,
		containing_block_width))
	used_values.border_bottom = css_px(resolve_used_border_width(computed, .border_bottom_width,
		.border_bottom_style, containing_block_width))

	// auto margins resolve to 0 for now (width computation reassigns them for centering).
	used_values.margin_left = css_px(computed.length_percentage_to_px(.margin_left, containing_block_width) or {
		0.0
	})
	used_values.margin_right = css_px(computed.length_percentage_to_px(.margin_right, containing_block_width) or {
		0.0
	})
	used_values.margin_top = css_px(computed.length_percentage_to_px(.margin_top, containing_block_width) or {
		0.0
	})
	used_values.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom, containing_block_width) or {
		0.0
	})
}

// CSS 2.1 §10.3.3: compute the used content width (and resolve auto margins) of a normal-flow block-level
// box, given its containing block's width. Assumes resolve_box_model_edges already ran.
fn compute_block_used_width(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64) {
	// Non-content horizontal edges (border + padding).
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() +
		used_values.padding_right.to_double() + used_values.border_right.to_double()

	width_is_auto := property_is_auto(computed, .width)
	margin_left_auto := property_is_auto(computed, .margin_left)
	margin_right_auto := property_is_auto(computed, .margin_right)

	// §10.3.3 tentative content width.
	mut width := 0.0
	if width_is_auto {
		// auto width fills the containing block; auto margins are treated as 0.
		margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
		margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
		width = containing_block_width - margin_left - margin_right - edges
		if width < 0.0 {
			width = 0.0
		}
		if margin_left_auto {
			used_values.margin_left = css_px(0.0)
		}
		if margin_right_auto {
			used_values.margin_right = css_px(0.0)
		}
	} else {
		width = computed.length_percentage_to_px(.width, containing_block_width) or { 0.0 }
	}

	// §10.4: clamp to [min-width, max-width].
	clamped := clamp_to_min_max(computed, .min_width, .max_width, width, containing_block_width)
	used_values.set_content_width(css_px(clamped))

	// Resolve auto margins against the used (now definite) width — for an explicit width, or an auto width
	// that clamping shrank below the fill.
	if !width_is_auto || clamped != width {
		resolve_auto_margins(computed, mut used_values, containing_block_width, clamped)
	}
}

// Resolve auto left/right margins to absorb the remaining inline space (centering when both are auto),
// given a definite content `width` (CSS 2.1 §10.3.3).
fn resolve_auto_margins(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64, width f64) {
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() +
		used_values.padding_right.to_double() + used_values.border_right.to_double()
	margin_left_auto := property_is_auto(computed, .margin_left)
	margin_right_auto := property_is_auto(computed, .margin_right)
	fixed_margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
	fixed_margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
	remaining := containing_block_width - width - edges - fixed_margin_left - fixed_margin_right

	if margin_left_auto && margin_right_auto {
		half := remaining / 2.0
		used_values.margin_left = css_px(half)
		used_values.margin_right = css_px(half)
	} else if margin_left_auto {
		used_values.margin_left = css_px(remaining)
	} else if margin_right_auto {
		used_values.margin_right = css_px(remaining)
	}
	// FIXME: over-constrained (no auto) — CSS 2.1 ignores margin-right in LTR; not adjusted here.
}

// Clamp `value` to [min, max] resolved from `min_property`/`max_property` (CSS 2.1 §10.4/§10.7). A `none`
// max (or a keyword/auto min/max) does not constrain; min defaults to 0.
fn clamp_to_min_max(computed &css.ComputedProperties, min_property css.PropertyID, max_property css.PropertyID, value f64, percentage_basis f64) f64 {
	mut result := value
	if max := computed.length_percentage_to_px(max_property, percentage_basis) {
		if result > max {
			result = max
		}
	}
	min := computed.length_percentage_to_px(min_property, percentage_basis) or { 0.0 }
	if result < min {
		result = min
	}
	return result
}

// Lay out `box` and its block-level descendants in normal flow (a first slice of
// BlockFormattingContext::run + FormattingContext block layout), writing geometry into `state`:
// resolve the box's width, lay out each block child top-to-bottom, then compute the box's height.
// `containing_block_width` is the content width of the box's containing block.
//
// DEFERRED: inline/flex/grid/table/replaced/float/abspos content, margin collapsing, min/max sizing,
// percentage heights (need a definite CB height), and writing modes.
pub fn layout_block_flow(mut state LayoutState, box &NodeWithStyle, containing_block_width f64) {
	computed := box.computed_values()
	mut used_values := state.get_mutable(box)
	resolve_box_model_edges(computed, mut used_values, containing_block_width)
	compute_block_used_width(computed, mut used_values, containing_block_width)
	content_width := used_values.content_width().to_double()

	// Lay out block children top-to-bottom, stacking their margin boxes.
	mut cursor_y := 0.0
	box_as_node := unsafe { &Node(box) }
	for child_node in box_as_node.children() {
		child := child_node.as_node_with_style() or { continue }
		layout_block_flow(mut state, child, content_width)

		mut child_used_values := state.get_mutable(child)
		// The child's content-area top-left within this box's content area: indented by the child's own
		// left/top edges, and offset vertically by the running cursor.
		content_x := child_used_values.margin_left.to_double() + child_used_values.border_left.to_double() +
			child_used_values.padding_left.to_double()
		content_y := cursor_y + child_used_values.margin_top.to_double() +
			child_used_values.border_top.to_double() + child_used_values.padding_top.to_double()
		child_used_values.set_content_offset(css.CSSPixelPoint.from_values(content_x, content_y))
		child_used_values.set_containing_block_used_values(used_values)

		cursor_y += child_used_values.margin_box_height().to_double()
	}

	// Height (CSS 2.1 §10.6): auto height is the accumulated children; a definite (absolute) height is used.
	mut height := if property_is_auto(computed, .height) {
		cursor_y
	} else {
		// FIXME: percentage heights need a definite containing-block height; basis 0 here.
		computed.length_percentage_to_px(.height, 0.0) or { cursor_y }
	}
	// §10.7: clamp to [min-height, max-height].
	height = clamp_to_min_max(computed, .min_height, .max_height, height, 0.0)
	used_values.set_content_height(css_px(height))
}
