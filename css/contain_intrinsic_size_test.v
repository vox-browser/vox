module css

import dom

fn contain_intrinsic_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_contain_intrinsic_property_metadata_and_shorthand_relationships() {
	assert property_id_from_string('contain-intrinsic-width')? == .contain_intrinsic_width
	assert property_id_from_string('CONTAIN-INTRINSIC-HEIGHT')? == .contain_intrinsic_height
	assert property_id_from_string('contain-intrinsic-block-size')? == .contain_intrinsic_block_size
	assert property_id_from_string('contain-intrinsic-inline-size')? == .contain_intrinsic_inline_size
	assert property_id_from_string('contain-intrinsic-size')? == .contain_intrinsic_size
	assert string_from_property_id(.contain_intrinsic_width) == 'contain-intrinsic-width'
	assert property_initial_value_string(.contain_intrinsic_width) == 'none'
	assert property_initial_value_string(.contain_intrinsic_height) == 'none'
	assert generated_longhands_for_shorthand(.contain_intrinsic_size) == [
		PropertyID.contain_intrinsic_width,
		.contain_intrinsic_height,
	]
	assert generated_shorthands_for_longhand(.contain_intrinsic_width) == [
		PropertyID.all,
		.contain_intrinsic_size,
	]
	assert PropertyID.contain_intrinsic_width in generated_expanded_longhands_for_shorthand(.all)
	assert property_is_logical_alias(.contain_intrinsic_block_size)
	assert property_is_logical_alias(.contain_intrinsic_inline_size)
	assert map_logical_alias_to_physical_property(.contain_intrinsic_block_size, LogicalAliasMappingContext{}) == .contain_intrinsic_height
	assert map_logical_alias_to_physical_property(.contain_intrinsic_inline_size, LogicalAliasMappingContext{}) == .contain_intrinsic_width
	assert map_logical_alias_to_physical_property(.contain_intrinsic_block_size, LogicalAliasMappingContext{
		writing_mode: .vertical_rl
	}) == .contain_intrinsic_width
}

fn test_contain_intrinsic_longhand_parsing() {
	assert contain_intrinsic_serialization(.contain_intrinsic_width, 'none')? == 'none'
	assert contain_intrinsic_serialization(.contain_intrinsic_width, '100px')? == '100px'
	assert contain_intrinsic_serialization(.contain_intrinsic_width, 'auto 100px')? == 'auto 100px'
	assert contain_intrinsic_serialization(.contain_intrinsic_width, 'auto none')? == 'auto none'
	assert contain_intrinsic_serialization(.contain_intrinsic_height, '10em')? == '10em'
	assert contain_intrinsic_serialization(.contain_intrinsic_width, 'calc(1em + 4px)')? == 'calc(1em + 4px)'
	assert contain_intrinsic_serialization(.contain_intrinsic_height, 'auto calc(10px * 2)')? == 'auto calc(20px)'

	for invalid in ['', '-5px', 'auto', '50%', 'calc(50%)', 'from-element',
		'from-element 100px', 'auto from-element 100px', '100px 200px'] {
		assert contain_intrinsic_serialization(.contain_intrinsic_width, invalid) == none, invalid
	}
}

fn test_contain_intrinsic_shorthand_parsing_and_serialization() {
	assert contain_intrinsic_serialization(.contain_intrinsic_size, '111px 222px')? == '111px 222px'
	assert contain_intrinsic_serialization(.contain_intrinsic_size, '111px')? == '111px'
	assert contain_intrinsic_serialization(.contain_intrinsic_size, 'auto 111px auto 222px')? == 'auto 111px auto 222px'
	assert contain_intrinsic_serialization(.contain_intrinsic_size, 'none none')? == 'none'
	assert contain_intrinsic_serialization(.contain_intrinsic_size, '1px none')? == '1px none'
	assert contain_intrinsic_serialization(.contain_intrinsic_size, 'none 1px')? == 'none 1px'

	for invalid in ['', 'auto', '1px 2px 3px', 'from-element 111px',
		'auto 1px 2px auto'] {
		assert contain_intrinsic_serialization(.contain_intrinsic_size, invalid) == none, invalid
	}
}

fn test_contain_intrinsic_values_compute_lengths_and_logical_aliases() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'font-size: 16px; contain-intrinsic-size: 7em auto calc(10px * 2); contain-intrinsic-block-size: 30px')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))

	assert (computed.property(.contain_intrinsic_width, .no) or { panic('missing width') }).css_text == '112px'
	assert (computed.property(.contain_intrinsic_height, .no) or { panic('missing height') }).css_text == '30px'
	width := computed.contain_intrinsic_width()
	height := computed.contain_intrinsic_height()
	assert !width.has_auto
	assert width.has_length
	assert width.length.to_double() == 112
	assert !height.has_auto
	assert height.has_length
	assert height.length.to_double() == 30

	element.set_attribute_value('style', 'contain-intrinsic-height: auto none; contain-intrinsic-width: auto 32px')
	auto_computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	auto_height := auto_computed.contain_intrinsic_height()
	auto_width := auto_computed.contain_intrinsic_width()
	assert auto_height.has_auto
	assert !auto_height.has_length
	assert auto_width.has_auto
	assert auto_width.has_length
	assert auto_width.length.to_double() == 32
}

fn test_contain_intrinsic_longhands_reassemble_as_shorthand() {
	rules := parse_css_stylesheet_contents_with_parser('a { contain-intrinsic-width: 111px; contain-intrinsic-height: 222px; }', map[string]bool{})
	assert rules.len == 1
	declaration := rules[0].declaration or { panic('missing declaration') }
	assert declaration.serialized() == 'contain-intrinsic-size: 111px 222px;'
}
