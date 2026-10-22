module css

import dom

fn test_cssom_builder_retains_only_final_longhand_records() {
	value := dom_style_value_from_value_logic(parse_css_value_logic(.color, 'red')?)
	mut input := []StyleProperty{cap: 4096}
	for _ in 0 .. 4096 {
		input << StyleProperty{ property_id: .color, value: value }
	}
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		before := document.native_storage().arena.usage().used
		actual := CSSStyleProperties.create_from_declarations(input, map[string]StyleProperty{})
		growth := document.native_storage().arena.usage().used - before
		assert growth < 8192, '${growth} retained for one final property'
		assert actual.properties.len == 1
		assert actual.get_property_value('color') == 'red'
		assert voidptr(actual.properties[0].style_value?) == voidptr(value)
		owner.finish()
		document.release_native_storage()
	}
}

fn test_cssom_builder_matches_specified_order_and_shorthand_importance() {
	mut input := []StyleProperty{}
	for index, source in ['1px 2px', '3px 4px', '5px 6px'] {
		input << StyleProperty{
			property_id: .margin
			important:   if index == 1 { Important.yes } else { Important.no }
			value:       dom_style_value_from_value_logic(parse_css_value_logic(.margin, source)?)
		}
		input << StyleProperty{
			property_id: .color
			value:       dom_style_value_from_value_logic(parse_css_value_logic(.color, 'red')?)
		}
	}
	for property, source in {
		PropertyID.border:     '1px solid blue'
		PropertyID.background: 'url("icon.svg") red'
		PropertyID.padding:    'var(--edges, 1px 2px)'
	} {
		mut value := dom_style_value_from_value_logic(parse_css_value_logic(property, source)?)
		value.base_url = 'https://example.test/theme.css'
		input << StyleProperty{ property_id: property, value: value }
	}
	expected := css_style_properties_to_cssom_properties(convert_declarations_to_specified_order(input))
	mut actual := CSSStyleProperties.create_from_declarations(input, map[string]StyleProperty{})
	assert actual.properties.len == expected.len
	for index, property in actual.properties {
		assert property.name == expected[index].name
		assert property.value == expected[index].value
		assert property.important == expected[index].important
		assert (property.style_value?.base_url or { '' }) == (expected[index].style_value?.base_url or { '' })
	}
	assert actual.get_property_value('margin-top') == '3px'
	assert actual.get_property_priority('margin-left') == 'important'
	actual.set_the_declarations(input, map[string]StyleProperty{})
	assert actual.properties.len == expected.len
	for index, property in actual.properties {
		assert property.name == expected[index].name
		assert property.value == expected[index].value
		assert property.important == expected[index].important
	}
}
