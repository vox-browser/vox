module css

import dom

fn container_property_serialization(text string, property_id PropertyID) ?string {
	value := parse_css_value_logic(property_id, text) or { return none }
	return value.serialize(.normal)
}

fn test_container_property_metadata_and_shorthand_relationships() {
	assert (property_id_from_string('container') or { panic('missing container') }) == .container
	assert (property_id_from_string('CONTAINER-NAME') or { panic('missing container-name') }) == .container_name
	assert string_from_property_id(.container_name) == 'container-name'
	assert property_initial_value_string(.container) == 'none'
	assert property_initial_value_string(.container_name) == 'none'
	assert property_multiplicity(.container_name) == .list
	assert property_accepts_type(.container_name, .custom_ident)
	assert property_accepts_keyword(.container_name, .none_)
	assert property_accepts_custom_ident(.container_name, 'card')
	for excluded in ['none', 'and', 'not', 'or'] {
		assert !property_accepts_custom_ident(.container_name, excluded)
	}
	assert generated_longhands_for_shorthand(.container) == [
		PropertyID.container_name,
		.container_type,
	]
	assert generated_expanded_longhands_for_shorthand(.container) == [
		PropertyID.container_name,
		.container_type,
	]
	assert generated_shorthands_for_longhand(.container_name) == [PropertyID.all, .container]
	assert generated_shorthands_for_longhand(.container_type) == [PropertyID.all, .container]
	assert PropertyID.container_name in generated_longhands_for_shorthand(.all)
	assert number_of_longhand_properties == 364
	assert last_longhand_property_id() == .webkit_font_smoothing
}

fn test_container_name_and_container_shorthand_parsing() {
	assert container_property_serialization('none', .container_name)? == 'none'
	assert container_property_serialization('card', .container_name)? == 'card'
	assert container_property_serialization('card sidebar', .container_name)? == 'card sidebar'
	assert container_property_serialization('card', .container)? == 'card'
	assert container_property_serialization('size', .container)? == 'size'
	assert container_property_serialization('card / size', .container)? == 'card / size'
	assert container_property_serialization('card sidebar / inline-size scroll-state', .container)? == 'card sidebar / inline-size scroll-state'
	assert container_property_serialization('none / inline-size', .container)? == 'none / inline-size'

	for invalid in ['', 'none card', 'card none', 'and', 'card and', '/ size', 'card /',
		'card / normal size', 'card / size / scroll-state'] {
		assert container_property_serialization(invalid, .container) == none, invalid
	}
	for invalid in ['', 'none card', 'card none', 'and', 'card and', 'card / size'] {
		assert container_property_serialization(invalid, .container_name) == none, invalid
	}
}

fn test_container_names_propagate_into_computed_values() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	element.set_attribute_value('style', 'container: card sidebar / inline-size')
	style_computer := StyleComputer.new(document)
	computed := style_computer.compute_style(dom.AbstractElement.new(element, none))

	assert (computed.property(.container_name, .no) or { panic('missing container-name') }).css_text == 'card sidebar'
	assert computed.container_name() == ['card', 'sidebar']
	assert computed.container_type().is_inline_size_container
	values := resolve_computed_values(computed)
	assert values.container_name() == ['card', 'sidebar']
	assert values.container_type().is_inline_size_container
}

fn test_container_longhands_reassemble_as_the_shorthand() {
	rules := parse_css_stylesheet_contents_with_parser('a { container-name: card sidebar; container-type: size; }', map[string]bool{})
	assert rules.len == 1
	declaration := rules[0].declaration or { panic('missing declaration') }
	assert declaration.serialized() == 'container: card sidebar / size;'
}
