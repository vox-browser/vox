module layout

// LayoutInline::ComputeInitialShouldCreateBoxFragment(). Culled inline boxes
// leave text snapping relative to the line; an inline with box decoration or
// spacing establishes its own paint origin.
fn chromium_inline_needs_paint_box(node &Node, used &UsedValues) bool {
	style := node.computed_values()
	return used.margin_left.raw_value() != 0 || used.margin_right.raw_value() != 0
		|| used.margin_top.raw_value() != 0 || used.margin_bottom.raw_value() != 0
		|| used.padding_left.raw_value() != 0 || used.padding_right.raw_value() != 0
		|| used.padding_top.raw_value() != 0 || used.padding_bottom.raw_value() != 0
		|| used.border_left.raw_value() != 0 || used.border_right.raw_value() != 0
		|| used.border_top.raw_value() != 0 || used.border_bottom.raw_value() != 0
		|| style.background_color().a != 0
		|| style.background_layers().any(it.image != '' && it.image != 'none')
		|| style.box_shadow().len > 0 || style.outline_style() != .none_
		|| node.establishes_stacking_context()
}
