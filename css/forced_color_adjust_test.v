module css

import dom

fn test_forced_color_adjust_inherits_and_interpolates_discretely() {
	assert typed_style_value_logic_from_dom(computed_interpolation_property_initial_value(.forced_color_adjust)) != none
	assert is_inherited_property(.forced_color_adjust)
	assert animation_type_from_longhand_property(.forced_color_adjust) == .discrete
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div') or { panic(err) }
	from := parse_css_value(ParsingParams{},'auto',.forced_color_adjust) or { panic('from') }
	to := parse_css_value(ParsingParams{},'none',.forced_color_adjust) or { panic('to') }
	assert interpolate_property(element,.forced_color_adjust,from,to,0.3,.yes)?.css_text == 'auto'
	assert interpolate_property(element,.forced_color_adjust,from,to,0.6,.yes)?.css_text == 'none'
	assert parse_css_value_logic(.forced_color_adjust,'blue') == none
}
