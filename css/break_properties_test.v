module css

import dom

fn break_property_serialization(property_id PropertyID, text string) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_break_property_metadata() {
	assert property_id_from_string('break-after')? == .break_after
	assert property_id_from_string('BREAK-BEFORE')? == .break_before
	assert property_id_from_string('break-inside')? == .break_inside
	assert string_from_property_id(.break_after) == 'break-after'
	assert property_initial_value_string(.break_after) == 'auto'
	assert property_initial_value_string(.break_before) == 'auto'
	assert property_initial_value_string(.break_inside) == 'auto'
	assert property_affects_layout(.break_after)
	assert property_affects_layout(.break_before)
	assert property_affects_layout(.break_inside)
	assert generated_shorthands_for_longhand(.break_after) == [PropertyID.all]
	assert PropertyID.break_inside in generated_expanded_longhands_for_shorthand(.all)
	assert number_of_longhand_properties == 362
	assert last_longhand_property_id() == .webkit_font_smoothing
}

fn test_break_between_property_parsing() {
	for property_id in [PropertyID.break_after, .break_before] {
		for value in ['auto', 'avoid', 'avoid-page', 'page', 'left', 'right', 'recto', 'verso',
			'avoid-column', 'column', 'avoid-region', 'region'] {
			assert break_property_serialization(property_id, value)? == value, '${property_id}: ${value}'
		}
		for invalid in ['', 'none', 'avoid region', 'always'] {
			assert break_property_serialization(property_id, invalid) == none, '${property_id}: ${invalid}'
		}
	}
}

fn test_break_inside_property_parsing() {
	for value in ['auto', 'avoid', 'avoid-page', 'avoid-column', 'avoid-region'] {
		assert break_property_serialization(.break_inside, value)? == value, value
	}
	for invalid in ['', 'region', 'page', 'auto avoid'] {
		assert break_property_serialization(.break_inside, invalid) == none, invalid
	}
}

fn test_break_properties_retain_typed_computed_values() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'break-before: recto; break-after: avoid-column; break-inside: avoid-page')
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.break_before, .no) or { panic('missing break-before') }).css_text == 'recto'
	assert (computed.property(.break_after, .no) or { panic('missing break-after') }).css_text == 'avoid-column'
	assert (computed.property(.break_inside, .no) or { panic('missing break-inside') }).css_text == 'avoid-page'
	values := resolve_computed_values(computed)
	assert values.break_before() == .recto
	assert values.break_after() == .avoid_column
	assert values.break_inside() == .avoid_page
}
