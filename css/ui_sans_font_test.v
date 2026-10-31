module css

import dom
import platform

fn test_ui_sans_serif_uses_the_system_ui_font_for_the_chromium_policy() {
	assert platform_generic_font_name_boundary('ui-sans-serif', .chromium) ==
		platform_generic_font_name_boundary('system-ui', .chromium)
	assert platform_generic_font_name_boundary('UI-SANS-SERIF', .chromium) ==
		platform_generic_font_name_boundary('system-ui', .chromium)
	assert platform_generic_font_name_boundary('ui-sans-serif', .libweb) == 'SansSerif'
	assert platform_generic_font_name_boundary('sans-serif', .chromium) == 'SansSerif'
}

fn test_ui_sans_serif_cascade_selects_the_same_face_as_system_ui() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	computer := FontComputer.create_for_document(document)
	for weight in [400, 600, 700] {
		mut system := ComputedProperties.new()
		system.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'system-ui'})
		system.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: weight.str()})
		mut generic := ComputedProperties.new()
		generic.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'ui-sans-serif, sans-serif'})
		generic.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: weight.str()})
		expected := system.first_available_computed_font(computer)
		actual := generic.first_available_computed_font(computer)
		assert actual.typeface.family_name == expected.typeface.family_name
		assert actual.typeface.source_path == expected.typeface.source_path
		assert actual.variations.weight == expected.variations.weight
		if platform.system_font_matching_supported() {
			assert actual.typeface.family_name == 'SystemUi'
		}
	}
}
