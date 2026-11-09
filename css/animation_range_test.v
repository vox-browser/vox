module css

import dom

fn test_animation_range_grammar_lists_and_named_default_offsets() {
	for source, expected in {
		'0px 50vw': '0px 50vw'
		'normal normal': 'normal'
		'10%': '10%'
		'10% 10%': '10% 10%'
		'entry 0%': 'entry'
		'entry 10%': 'entry 10%'
		'entry exit': 'entry exit'
		'entry 10% 90%': 'entry 10% 90%'
		'ENTRY 10% EXIT 90%': 'entry 10% exit 90%'
		'contain, exit-crossing': 'contain, exit-crossing'
		'normal, -20px 120%': 'normal, -20px 120%'
	} {
		value := parse_css_value_logic(.animation_range, source) or { panic(source) }
		assert value.serialize(.normal) == expected, source
	}
	for property in [PropertyID.animation_range, .animation_range_start, .animation_range_end] {
		for source in ['', ',', '10%,', ', 10%', 'auto', 'none', '1', '1s', '"entry"', 'entry unknown', 'cover 0% 10% 20%', '0px / 10px'] {
			assert parse_css_value_logic(property, source) == none, source
		}
		assert parse_css_value_logic(property, 'calc(100% - 20px)') != none
	}
	assert parse_css_value_logic(.animation_range_start, 'exit 100%')?.serialize(.normal) == 'exit 100%'
	assert parse_css_value_logic(.animation_range_end, 'exit 100%')?.serialize(.normal) == 'exit'
	assert parse_css_value_logic(.animation_range_start, 'entry 0%')?.serialize(.normal) == 'entry'
	assert parse_css_value_logic(.animation_range_end, 'entry 0%')?.serialize(.normal) == 'entry 0%'
	assert parse_css_value_logic(.animation_range_start, '0px 50vw') == none
}

fn test_animation_range_declaration_expansion_reset_and_reconstruction() {
	rules := parse_css_stylesheet_contents_with_parser('.x { animation-range: entry 10%, 0px 50vw; }', map[string]bool{})
	mut declaration := rules[0].style() or { panic('declaration') }
	assert declaration.get_property_value('animation-range-start') == 'entry 10%, 0px'
	assert declaration.get_property_value('animation-range-end') == 'entry, 50vw'
	assert declaration.get_property_value('animation-range') == 'entry 10%, 0px 50vw'
	declaration.set_property('animation-range-end', 'normal', '')!
	assert declaration.get_property_value('animation-range') == ''
	declaration.set_property('animation-range', '20% 80%', '')!
	declaration.set_property('animation', 'slide 2s linear', '')!
	assert declaration.get_property_value('animation-range-start') == 'normal'
	assert declaration.get_property_value('animation-range-end') == 'normal'
	assert declaration.get_property_value('animation') == '2s linear slide'
	declaration.set_property('animation-range', 'entry', '')!
	assert declaration.get_property_value('animation') == ''
}

fn test_animation_range_metadata_keeps_longhand_storage_contiguous() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing property') }
		assert int(property) == int(first_longhand_property_id()) + index
	}
	for property in [PropertyID.animation_range_start, .animation_range_end] {
		assert property_id_from_string(string_from_property_id(property))? == property
		assert property_initial_value_string(property) == 'normal'
		assert !is_inherited_property(property)
		assert !is_animatable_property(property)
		assert !property_affects_layout(property)
		assert property_multiplicity(property) == .coordinating_list
		assert property in generated_expanded_longhands_for_shorthand(.all)
		assert property in generated_expanded_longhands_for_shorthand(.animation)
		assert generated_shorthands_for_longhand(property) == [PropertyID.animation, .animation_range, .all]
	}
}

fn test_animation_range_computes_viewport_lengths_and_preserves_percentages() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{width: 800, height: 600})
	add_document_author_style_sheet(document, '.target { animation-range: 2em 50vw, entry calc(100% - 20px) exit; font-size: 10px; }')
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('class', 'target')
	mut computer := StyleComputer.new(document)
	style := computer.compute_style(dom.AbstractElement.new(element, none))
	assert (style.property(.animation_range_start, .yes) or { panic('start') }).css_text == '20px, entry calc(100% - 20px)'
	assert (style.property(.animation_range_end, .yes) or { panic('end') }).css_text == '400px, exit'
}

fn test_animation_range_default_end_percentage_is_omitted_in_shorthand() {
	value := parse_css_value_logic(.animation_range, '0% 100%') or { panic('range') }
	assert value.serialize(.normal) == '0%'
}
