module css

import dom
import platform

fn test_ui_sans_serif_does_not_terminate_chromium_macos_font_fallback() {
	expected := if platform.system_font_matching_supported() { 'ui-sans-serif' } else { 'SansSerif' }
	assert platform_generic_font_name_boundary('ui-sans-serif', .chromium) == expected
	assert platform_generic_font_name_boundary('UI-SANS-SERIF', .chromium) == expected
	assert platform_generic_font_name_boundary('ui-sans-serif', .libweb) == 'SansSerif'
	assert platform_generic_font_name_boundary('sans-serif', .chromium) == 'SansSerif'
}

fn test_unavailable_ui_sans_serif_cascades_to_the_authored_fallback() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	computer := FontComputer.create_for_document(document)
	for weight in [400, 600, 700] {
		mut system := ComputedProperties.new()
		system.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'sans-serif'})
		system.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: weight.str()})
		mut generic := ComputedProperties.new()
		generic.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'ui-sans-serif, sans-serif'})
		generic.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: weight.str()})
		expected := system.first_available_computed_font(computer)
		actual := generic.first_available_computed_font(computer)
		assert actual.typeface.family_name == expected.typeface.family_name
		assert actual.typeface.source_path == expected.typeface.source_path
		assert actual.variations.weight == expected.variations.weight
		assert actual.typeface.family_name == 'SansSerif'
	}
}

fn test_apple_system_alias_is_selected_after_unavailable_ui_families() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	computer := FontComputer.create_for_document(document)
	for weight in [400, 600, 700] {
		mut system := ComputedProperties.new()
		system.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'system-ui'})
		system.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: weight.str()})
		expected := system.first_available_computed_font(computer)
		for family in ['-apple-system, sans-serif', '-apple-system-body, ui-sans-serif, -apple-system, "system-ui", "Segoe UI", Helvetica, Arial, sans-serif'] {
			mut computed := ComputedProperties.new()
			computed.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: family})
			computed.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: weight.str()})
			actual := computed.first_available_computed_font(computer)
			assert actual.typeface.family_name == expected.typeface.family_name
			assert actual.typeface.source_path == expected.typeface.source_path
			assert actual.variations.weight == expected.variations.weight
		}
	}
}
