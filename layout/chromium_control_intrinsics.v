module layout

import math

// Blink's LayoutBox::{TextArea,TextField}IntrinsicInlineSize. Round only
// after multiplying the raw font advance, rather than multiplying CSS `ch`.
fn chromium_control_intrinsic_inline_size(node &Node, columns int, textarea bool) CSSPixels {
	scale := node.document().layout_coordinate_scale()
	average, maximum := node.first_available_font().form_control_character_widths(scale)
	mut width := average * f32(columns)
	if !textarea && maximum > average {
		width += maximum - average
	}
	mut result := CSSPixels.nearest_value_for(math.ceil(f64(width)) * scale)
	values := node.computed_values()
	block_overflow := if values.writing_mode() == .horizontal_tb {
		values.overflow_y()
	} else {
		values.overflow_x()
	}
	if textarea && block_overflow in [.auto_, .scroll] {
		result = result.plus(chromium_control_scrollbar_thickness(node))
	}
	return result
}

// ScrollbarThemeMac's overlay track box. Intrinsic textarea sizing reserves
// this space even when its empty editor does not currently need a scrollbar.
fn chromium_control_scrollbar_thickness(node &Node) CSSPixels {
	width := node.computed_values().scrollbar_width()
	thickness := match width {
		.none_ { 0.0 }
		.thin { 14.0 }
		.auto_ { 16.0 }
	}
	return CSSPixels.nearest_value_for(thickness * node.document().layout_coordinate_scale())
}
