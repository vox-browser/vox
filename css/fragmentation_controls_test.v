module css

import dom

fn fragmentation_control_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_fragmentation_control_metadata_and_parsing() {
	assert property_id_from_string('box-decoration-break')? == .box_decoration_break
	assert property_id_from_string('COLUMN-FILL')? == .column_fill
	assert string_from_property_id(.box_decoration_break) == 'box-decoration-break'
	assert property_initial_value_string(.box_decoration_break) == 'slice'
	assert property_initial_value_string(.column_fill) == 'balance'
	assert property_affects_layout(.box_decoration_break)
	assert property_affects_layout(.column_fill)
	assert generated_shorthands_for_longhand(.box_decoration_break) == [
		PropertyID.all,
	]
	assert PropertyID.column_fill in generated_expanded_longhands_for_shorthand(.all)
	assert number_of_longhand_properties == 360

	assert fragmentation_control_serialization(.box_decoration_break, 'slice')? == 'slice'
	assert fragmentation_control_serialization(.box_decoration_break, 'clone')? == 'clone'
	assert fragmentation_control_serialization(.box_decoration_break, 'auto') == none
	assert fragmentation_control_serialization(.box_decoration_break, 'slice clone') == none
	for value in ['auto', 'balance', 'balance-all'] {
		assert fragmentation_control_serialization(.column_fill, value)? == value, value
	}
	assert fragmentation_control_serialization(.column_fill, 'none') == none
	assert fragmentation_control_serialization(.column_fill, 'auto balance') == none
}

fn test_fragmentation_controls_retain_typed_computed_values() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'box-decoration-break: clone; column-fill: balance-all')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.box_decoration_break, .no) or { panic('missing box-decoration-break') }).css_text == 'clone'
	assert (computed.property(.column_fill, .no) or { panic('missing column-fill') }).css_text == 'balance-all'
	values := resolve_computed_values(computed)
	assert values.box_decoration_break() == .clone
	assert values.column_fill() == .balance_all
}
