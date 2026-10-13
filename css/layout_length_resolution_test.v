module css

import dom

fn test_layout_lengths_resolve_absolute_units_and_percentages_without_font_state() {
	mut style := ComputedProperties.new()
	style.set_property(.padding_left, &dom.StyleValue{css_text: '12pt'}, .no, .no)
	style.set_property(.width, &dom.StyleValue{css_text: '20%'}, .no, .no)
	values := resolve_computed_values(style)
	assert values.length_percentage_to_px(.padding_left, 100) or { -1 } == 16
	assert values.length_percentage_to_px(.width, 200) or { -1 } == 40
	assert values.length_percentage_to_px(.width, 300) or { -1 } == 60
}
