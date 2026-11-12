module css

import dom

fn column_rule_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_column_rule_property_metadata() {
	assert property_id_from_string('column-rule-color')? == .column_rule_color
	assert property_id_from_string('COLUMN-RULE-STYLE')? == .column_rule_style
	assert property_id_from_string('column-rule-width')? == .column_rule_width
	assert property_id_from_string('column-rule')? == .column_rule
	assert string_from_property_id(.column_rule_color) == 'column-rule-color'
	assert property_initial_value_string(.column_rule_color) == 'currentColor'
	assert property_initial_value_string(.column_rule_style) == 'none'
	assert property_initial_value_string(.column_rule_width) == 'medium'
	assert generated_longhands_for_shorthand(.column_rule) == [
		PropertyID.column_rule_width,
		.column_rule_style,
		.column_rule_color,
	]
	assert generated_shorthands_for_longhand(.column_rule_width) == [
		PropertyID.all,
		.column_rule,
	]
	assert PropertyID.column_rule_color in generated_expanded_longhands_for_shorthand(.all)
	assert property_accepts_type(.column_rule_color, .color)
	assert property_accepts_type(.column_rule_width, .length)
	assert property_accepts_length(.column_rule_width, Length.make_px(10))
	assert !property_accepts_length(.column_rule_width, Length.make_px(-1))
	assert property_accepts_keyword(.column_rule_style, .dotted)
	assert property_accepts_keyword(.column_rule_width, .thick)
	assert !property_affects_layout(.column_rule)
	assert !property_affects_layout(.column_rule_width)
	assert generated_property_needs_layout_node_for_resolved_value(.column_rule_color)
	assert number_of_longhand_properties == 388
	assert last_longhand_property_id() == .webkit_font_smoothing
}

fn test_column_rule_longhand_parsing() {
	for value in ['currentcolor', 'red', 'rgb(1 2 3)'] {
		assert column_rule_serialization(.column_rule_color, value) != none, value
	}
	for value in ['none', 'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset',
		'outset'] {
		assert column_rule_serialization(.column_rule_style, value)? == value, value
	}
	assert column_rule_serialization(.column_rule_width, 'thin')? == 'thin'
	assert column_rule_serialization(.column_rule_width, 'medium')? == 'medium'
	assert column_rule_serialization(.column_rule_width, 'thick')? == 'thick'
	assert column_rule_serialization(.column_rule_width, '0')? == '0px'
	assert column_rule_serialization(.column_rule_width, '10px')? == '10px'
	assert column_rule_serialization(.column_rule_width, 'calc(10px + .5em)')? == 'calc(0.5em + 10px)'

	for invalid in ['', 'auto', '10', '-20px', '30%'] {
		assert column_rule_serialization(.column_rule_width, invalid) == none, invalid
	}
	for invalid in ['', 'auto', 'reverse', 'solid dashed'] {
		assert column_rule_serialization(.column_rule_style, invalid) == none, invalid
	}
}

fn test_column_rule_shorthand_parsing_and_serialization() {
	assert column_rule_serialization(.column_rule, 'medium dotted green')? == 'dotted green'
	assert column_rule_serialization(.column_rule, '100px')? == '100px'
	assert column_rule_serialization(.column_rule, 'blue')? == 'blue'
	assert column_rule_serialization(.column_rule, 'dotted')? == 'dotted'
	assert column_rule_serialization(.column_rule, '1px solid red')? == '1px solid red'
	assert column_rule_serialization(.column_rule, 'currentcolor hidden medium')? == 'hidden'
	assert column_rule_serialization(.column_rule, 'currentcolor none medium')? == 'medium'

	for invalid in ['', 'reverse', '10', 'solid dashed', '1px 2px', 'red medium green',
		'inherit solid'] {
		assert column_rule_serialization(.column_rule, invalid) == none, invalid
	}
}

fn test_column_rule_computed_values_resolve_width_style_and_current_color() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'color: rgb(1 2 3); font-size: 40px; column-rule-width: calc(10px + .5em); column-rule-style: hidden; column-rule-color: currentcolor')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.column_rule_width, .no) or { panic('missing width') }).css_text == '30px'
	values := resolve_computed_values_for_document(computed, document)
	assert values.column_rule_width().to_double() == 30
	assert values.column_rule_style() == .hidden
	assert values.column_rule_color() == Color{1, 2, 3, 255}

	element.set_attribute_value('style', 'column-rule: 10px none red')
	none_style := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	none_values := resolve_computed_values_for_document(none_style, document)
	assert none_values.column_rule_width().to_double() == 10
	assert none_values.column_rule_style() == .none_
	assert none_values.column_rule_color() == Color{255, 0, 0, 255}
}

fn test_column_rule_longhands_reassemble_as_shorthand() {
	rules := parse_css_stylesheet_contents_with_parser('a { column-rule-width: 2px; column-rule-style: solid; column-rule-color: rgb(1 2 3); }', map[string]bool{})
	assert rules.len == 1
	declaration := rules[0].declaration or { panic('missing declaration') }
	assert declaration.serialized() == 'column-rule: 2px solid rgb(1, 2, 3);'
}
