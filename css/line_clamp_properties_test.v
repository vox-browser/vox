module css

import dom

fn line_clamp_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_line_clamp_metadata_and_parsing() {
	assert property_id_from_string('line-clamp')? == .line_clamp
	assert property_id_from_string('-WEBKIT-LINE-CLAMP')? == .webkit_line_clamp
	assert property_id_from_string('block-ellipsis')? == .block_ellipsis
	assert property_id_from_string('continue')? == .continue_
	assert property_id_from_string('max-lines')? == .max_lines
	assert property_id_from_string('-webkit-box-orient')? == .webkit_box_orient
	assert property_initial_value_string(.line_clamp) == 'none'
	assert property_initial_value_string(.webkit_line_clamp) == 'none'
	assert property_initial_value_string(.block_ellipsis) == 'no-ellipsis'
	assert property_initial_value_string(.continue_) == 'auto'
	assert property_initial_value_string(.max_lines) == 'none'
	assert property_initial_value_string(.webkit_box_orient) == 'horizontal'
	assert is_inherited_property(.block_ellipsis)
	assert !is_inherited_property(.continue_)
	assert property_affects_layout(.line_clamp)
	assert property_affects_layout(.webkit_line_clamp)
	assert generated_longhands_for_shorthand(.line_clamp) == [PropertyID.max_lines, .block_ellipsis,
		.continue_]
	assert generated_longhands_for_shorthand(.webkit_line_clamp) == [
		PropertyID.max_lines,
		.block_ellipsis,
		.continue_,
	]
	assert generated_shorthands_for_longhand(.max_lines) == [PropertyID.all, .line_clamp,
		.webkit_line_clamp]
	assert number_of_longhand_properties == 364

	valid := {
		'none':                  'none'
		'1':                     '1'
		'6':                     '6'
		'auto':                  'auto'
		'"more"':                '"more"'
		'7 no-ellipsis':         '7 no-ellipsis'
		'8 auto':                '8'
		'9 "more"':              '9 "more"'
		'no-ellipsis 10':        '10 no-ellipsis'
		'auto 11':               '11'
		'"more" 12':             '12 "more"'
		'1 -webkit-legacy':      '1 -webkit-legacy'
		'auto -webkit-legacy':   'auto -webkit-legacy'
		'3 auto -webkit-legacy': '3 -webkit-legacy'
	}
	for input, expected in valid {
		assert line_clamp_serialization(.line_clamp, input)? == expected, input
	}
	for invalid in ['0', '-5', 'none 2', 'none no-ellipsis', '3 none', '3 auto no-ellipsis',
		'-webkit-legacy', '0 -webkit-legacy'] {
		assert line_clamp_serialization(.line_clamp, invalid) == none, invalid
	}
	assert line_clamp_serialization(.webkit_line_clamp, 'none')? == 'none'
	assert line_clamp_serialization(.webkit_line_clamp, '1')? == '1'
	assert line_clamp_serialization(.webkit_line_clamp, '6')? == '6'
	for invalid in ['auto', '0', '-1', '1 no-ellipsis', '1 -webkit-legacy'] {
		assert line_clamp_serialization(.webkit_line_clamp, invalid) == none, invalid
	}
	for value in ['none', '1'] {
		assert line_clamp_serialization(.max_lines, value)? == value
	}
	assert line_clamp_serialization(.max_lines, '0') == none
	for value in ['no-ellipsis', 'auto', '"continued"'] {
		assert line_clamp_serialization(.block_ellipsis, value)? == value
	}
	assert line_clamp_serialization(.block_ellipsis, 'invalid') == none
	for value in ['auto', 'collapse', 'discard', '-webkit-legacy'] {
		assert line_clamp_serialization(.continue_, value)? == value
	}
	assert line_clamp_serialization(.continue_, 'invalid') == none
	for value in ['horizontal', 'vertical'] {
		assert line_clamp_serialization(.webkit_box_orient, value)? == value
	}
}

fn test_line_clamp_cssom_expansion_and_serialization() {
	mut declaration := CSSStyleProperties.create()
	declaration.set_property('-webkit-line-clamp', '4', '')!
	assert declaration.get_property_value('-webkit-line-clamp') == '4'
	assert declaration.get_property_value('max-lines') == '4'
	assert declaration.get_property_value('block-ellipsis') == 'auto'
	assert declaration.get_property_value('continue') == '-webkit-legacy'

	declaration.set_property('-webkit-line-clamp', 'none', '')!
	assert declaration.get_property_value('-webkit-line-clamp') == 'none'
	assert declaration.get_property_value('max-lines') == 'none'
	assert declaration.get_property_value('block-ellipsis') == 'no-ellipsis'
	assert declaration.get_property_value('continue') == 'auto'
	assert declaration.css_text() == 'line-clamp: none;'
}

fn test_line_clamp_computed_values_and_legacy_display_transformation() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 3')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	values := resolve_computed_values(computed)
	assert computed.display() == Display.from_short(.flow_root)
	assert computed.display_before_box_type_transformation() == Display.from_outside_inside(.block, .webkit_box)
	assert values.display() == Display.from_short(.flow_root)
	assert values.effective_flex_direction() == .column
	assert values.max_lines()? == 3
	assert values.block_ellipsis().type_ == .auto_
	assert values.continue_value() == .webkit_legacy
	assert values.webkit_box_orient() == .vertical

	element.set_attribute_value('style', 'display: -webkit-box; -webkit-box-orient: horizontal; -webkit-line-clamp: 3')
	horizontal := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	horizontal_values := resolve_computed_values(horizontal)
	assert horizontal.display() == Display.from_outside_inside(.block, .webkit_box)
	assert horizontal_values.effective_flex_direction() == .row
}
