module layout

import css

fn flex_stretch_basis_is_definite(used &UsedValues, width bool) bool {
	containing := used.containing_block_used_values() or { return false }
	return if width { containing.has_definite_width() } else { containing.has_definite_height() }
}

// CSS Sizing: stretch fits the margin box, regardless of box-sizing. Auto
// margins contribute zero; computed margins are used before margin collapse.
fn stretch_fit_content_size(node &Node, used &UsedValues, available CSSPixels, width bool) CSSPixels {
	computed := node.computed_values()
	mut space := available
	if node.is_absolutely_positioned() {
		for side in if width { [css.PropertyID.left, .right] } else { [css.PropertyID.top, .bottom] } {
			space = space.minus(css_px(computed.length_percentage_to_px(side, available.to_double()) or { 0 }))
		}
		first_inset := if width { css.PropertyID.left } else { css.PropertyID.top }
		last_inset := if width { css.PropertyID.right } else { css.PropertyID.bottom }
		if property_is_auto(computed, first_inset) && property_is_auto(computed, last_inset) {
			if containing := used.containing_block_used_values_ {
				position := used.static_position()
				point := if width { position.x() } else { position.y() }
				padding := if width { containing.padding_left } else { containing.padding_top }
				extent := if width { used.margin_box_width() } else { used.margin_box_height() }
				mut starts_low := if containing.node_ != unsafe { nil } {
					absolute_axis_starts_low(unsafe { &Node(containing.node_) }, width)
				} else { true }
				if rectangle := used.static_position_rect() {
					alignment := if width { rectangle.horizontal_alignment } else { rectangle.vertical_alignment }
					if alignment == .start { starts_low = true }
					if alignment == .end { starts_low = false }
				}
				offset := if starts_low { point.plus(padding) } else { available.minus(padding).minus(point).minus(extent) }
				space = space.minus(offset)
			}
		}
	}
	start := if width { css.PropertyID.margin_left } else { css.PropertyID.margin_top }
	end := if width { css.PropertyID.margin_right } else { css.PropertyID.margin_bottom }
	mut first := if width { used.margin_left } else { used.margin_top }
	mut last := if width { used.margin_right } else { used.margin_bottom }
	if containing := used.containing_block_used_values_ {
		basis := containing.content_width().to_double()
		first = css_px(computed.length_percentage_to_px(start, basis) or { 0 })
		last = css_px(computed.length_percentage_to_px(end, basis) or { 0 })
	}
	if property_is_auto(computed, start) { first = CSSPixels.new(0) }
	if property_is_auto(computed, end) { last = CSSPixels.new(0) }
	// CSS Sizing 3 4.2 simulates parent margin collapse in the containing
	// block's block axis, even when another condition prevents real collapse.
	if node.is_in_flow() && !node.is_floating() && node.display().is_block_outside() {
		if containing := used.containing_block_used_values_ {
			parent := containing.node_
			if parent != unsafe { nil } {
				parent_node := unsafe { &Node(parent) }
				if width == (parent.computed_values().writing_mode() != .horizontal_tb)
					&& parent_node.display().is_flow_inside() && !creates_block_formatting_context(parent) {
					first_edge := if width { containing.border_left.plus(containing.padding_left) } else { containing.border_top.plus(containing.padding_top) }
					last_edge := if width { containing.border_right.plus(containing.padding_right) } else { containing.border_bottom.plus(containing.padding_bottom) }
					if first_edge.raw_value() == 0 { first = CSSPixels.new(0) }
					if last_edge.raw_value() == 0 { last = CSSPixels.new(0) }
				}
			}
		}
	}
	edges := if width {
		used.border_left.plus(used.padding_left).plus(used.padding_right).plus(used.border_right)
	} else {
		used.border_top.plus(used.padding_top).plus(used.padding_bottom).plus(used.border_bottom)
	}
	return css_pixels_max(CSSPixels.new(0), space.minus(first).minus(last).minus(edges))
}

fn replaced_stretch_fit_content_size(node &Node, available CSSPixels, model ReplacedBoxModel, width bool) CSSPixels {
	mut edges := UsedValues{}
	resolve_box_model_edges(node.computed_values(), mut edges, model.percentage_basis.to_double())
	return stretch_fit_content_size(node, edges, available, width)
}

// A flex item's stretch constraints use its final line, while percentages
// still resolve against the flex container. Re-resolve the preferred size so
// a clamp made before line collection cannot hide a larger authored size.
fn flex_cross_size_with_stretch_constraints(mut state LayoutState, node &Node, used &UsedValues, percentage_basis CSSPixels, line_size CSSPixels, width bool) ?CSSPixels {
	computed := node.computed_values()
	if !computed.size_value(if width { .min_width } else { .min_height }).is_stretch()
		&& !computed.size_value(if width { .max_width } else { .max_height }).is_stretch() {
		return none
	}
	preferred := computed.size_value(if width { .width } else { .height })
	if preferred.is_stretch() { return none }
	value := resolve_layout_content_size(node, preferred, percentage_basis, used, width) or {
		box := node.as_box() or { return none }
		if width { calculate_max_content_width(mut state, box) }
		else { calculate_max_content_height(mut state, box, used.content_width()) }
	}
	return clamp_layout_content_size_with_stretch_basis(node, value, percentage_basis, line_size, used, width)
}
