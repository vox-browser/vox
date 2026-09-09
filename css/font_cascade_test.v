module css

import dom

fn test_system_ui_generic_font_family_list_parses() {
	parsed := parse_css_value_logic(.font_family, 'system-ui, sans-serif') or {
		panic('failed to parse a valid generic font-family list')
	}
	assert parsed is StyleValueList
	list := parsed as StyleValueList
	assert list.values().len == 2
	assert list.values()[0].serialize(.normal) == 'system-ui'
	assert list.values()[1].serialize(.normal) == 'sans-serif'
}

fn test_font_cascade_selects_unicode_range_then_fallback() {
	mut list := FontCascadeList.create()
	list.add(PlatformFont{
		typeface: PlatformTypeface{
			family_name: 'Latin A'
		}
	}, [UnicodeRange{ start: u32(`A`), end: u32(`A`) }])
	list.add(PlatformFont{
		typeface: PlatformTypeface{
			family_name: 'Unrestricted'
		}
	}, [])
	assert list.font_for_code_point(u32(`A`)).typeface.family_name == 'Latin A'
	assert list.font_for_code_point(u32(`B`)).typeface.family_name == 'Unrestricted'

	mut ranged_only := FontCascadeList.create()
	ranged_only.add(PlatformFont{
		typeface: PlatformTypeface{
			family_name: 'Latin A'
		}
	}, [UnicodeRange{ start: u32(`A`), end: u32(`A`) }])
	ranged_only.set_last_resort_font(PlatformFont{
		typeface: PlatformTypeface{
			family_name: 'Last resort'
		}
	})
	assert ranged_only.font_for_code_point(u32(`B`)).typeface.family_name == 'Last resort'
}

fn test_computed_font_list_uses_computed_font_properties_and_caches_result() {
	mut computed := ComputedProperties.new()
	computed.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'serif, monospace'
	})
	computed.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '20px'
	})
	computed.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{
		css_text: '700'
	})
	computer := FontComputer.create()
	first_list := computed.computed_font_list(computer)
	second_list := computed.computed_font_list(computer)
	assert voidptr(first_list) == voidptr(second_list)
	assert !first_list.is_empty()
	font := computed.first_available_computed_font(computer)
	assert font.point_size == 15
	assert font.variations.weight == 700
	$if macos {
		assert font.typeface.family_name == 'Serif'
	}
}
