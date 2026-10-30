module css

import dom

fn test_font_synthesis_shorthand_parses_and_serializes_its_longhands() {
	assert number_of_longhand_properties == int(last_longhand_property_id()) - int(first_longhand_property_id()) + 1
	for index in 0 .. number_of_longhand_properties {
		property := property_id_from_longhand_index(index) or { panic('missing longhand ${index}') }
		assert property == unsafe { PropertyID(index + int(first_longhand_property_id())) }
	}
	for raw, expected in {
		'none':                             'none'
		'weight':                           'weight'
		'style weight':                     'weight style'
		'small-caps position':              'small-caps position'
		'position style weight small-caps': 'weight style small-caps position'
	} {
		value := parse_css_value_logic(.font_synthesis, raw) or { panic(raw) }
		assert value is ShorthandStyleValue
		assert value.serialize(.normal) == expected
	}
	for raw in ['', 'auto', 'none none', 'none weight', 'style none', 'style style', 'position, style',
		'weight unknown', '1', '"none"'] {
		assert parse_css_value_logic(.font_synthesis, raw) == none, raw
	}
	for property in font_synthesis_longhands {
		assert is_inherited_property(property)
		assert property_initial_value_string(property) == 'auto'
		assert parse_css_value_logic(property, 'auto') != none
		assert parse_css_value_logic(property, 'none') != none
		assert parse_css_value_logic(property, 'weight') == none
	}
	assert parse_css_value_logic(.font_synthesis_style, 'oblique-only') != none
	assert parse_css_value_logic(.font_synthesis_weight, 'oblique-only') == none
}

fn test_font_synthesis_declarations_expand_reset_and_reconstruct() {
	rules := parse_css_stylesheet_contents_with_parser('.x{font-synthesis:none}', map[string]bool{})
	mut declaration := rules[0].style() or { panic('declaration missing') }
	for name in ['weight', 'style', 'small-caps', 'position'] {
		assert declaration.get_property_value('font-synthesis-' + name) == 'none'
	}
	assert declaration.get_property_value('font-synthesis') == 'none'
	declaration.set_property('font-synthesis', 'style weight', '')!
	assert declaration.get_property_value('font-synthesis') == 'weight style'
	assert declaration.get_property_value('font-synthesis-small-caps') == 'none'
	declaration.set_property('font-synthesis-style', 'oblique-only', '')!
	assert declaration.get_property_value('font-synthesis') == ''
}

fn font_synthesis_test_style() &ComputedProperties {
	mut style := ComputedProperties.new()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{ css_text: 'Arial' })
	style.set_property_without_modifying_flags(.font_size, &dom.StyleValue{ css_text: '20px' })
	style.set_property_without_modifying_flags(.font_style, &dom.StyleValue{ css_text: 'italic' })
	return style
}

fn test_font_synthesis_cache_keeps_modes_and_retained_font_snapshots_distinct() {
	mut computer := FontComputer.create()
	mut style := font_synthesis_test_style()
	automatic := style.computed_font_list(computer)
	old_font := automatic.font_for_code_point(u32(`A`)).font_for_rendering()
	assert old_font.font_synthesis_disabled == 0
	style.set_property_without_modifying_flags(.font_synthesis_style, &dom.StyleValue{ css_text: 'none' })
	without_style := style.computed_font_list(computer)
	assert voidptr(without_style) != voidptr(automatic)
	assert without_style.font_for_code_point(u32(`A`)).font_for_rendering().font_synthesis_disabled == 2
	assert old_font.font_synthesis_disabled == 0
	style.set_property_without_modifying_flags(.font_synthesis_weight, &dom.StyleValue{ css_text: 'none' })
	assert style.computed_font_list(computer).font_for_code_point(u32(`A`)).font_synthesis_disabled == 3
	mut equivalent := font_synthesis_test_style()
	equivalent.set_property_without_modifying_flags(.font_synthesis_style, &dom.StyleValue{ css_text: 'none' })
	assert voidptr(equivalent.computed_font_list(computer)) == voidptr(without_style)
	mut previous := font_synthesis_test_style()
	_ = previous.computed_font_list(computer)
	assert !equivalent.reuse_unchanged_font_cache(previous, computer)
	style.set_property_without_modifying_flags(.font_synthesis_style, &dom.StyleValue{ css_text: 'auto' })
	style.set_property_without_modifying_flags(.font_synthesis_weight, &dom.StyleValue{ css_text: 'auto' })
	assert voidptr(style.computed_font_list(computer)) == voidptr(automatic)
}

fn test_font_synthesis_oblique_only_does_not_manufacture_italic() {
	mut style := font_synthesis_test_style()
	style.set_property_without_modifying_flags(.font_synthesis_style, &dom.StyleValue{ css_text: 'oblique-only' })
	assert style.disabled_font_synthesis() == 2
	style.set_property_without_modifying_flags(.font_style, &dom.StyleValue{ css_text: 'oblique 12deg' })
	assert style.disabled_font_synthesis() == 0
}

fn test_font_synthesis_survives_device_coordinate_projection() {
	mut computer := FontComputer.create()
	mut style := font_synthesis_test_style()
	style.set_property_without_modifying_flags(.font_synthesis_style, &dom.StyleValue{ css_text: 'none' })
	source := style.computed_font_list(computer).fonts[0].font
	projected := device_layout_font(source, 2, 40)
	assert projected.font_synthesis_disabled == 2
	assert device_layout_font_matches_projection(&source, &projected, 2, 40)
	changed := PlatformFont{ ...projected, font_synthesis_disabled: 0 }
	assert !device_layout_font_matches_projection(&source, &changed, 2, 40)
}
