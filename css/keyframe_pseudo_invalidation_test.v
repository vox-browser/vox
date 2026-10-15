module css

import dom

fn keyframe_pseudo_test_element(document &dom.Document) &dom.Element {
	return document.create_element('div') or { panic(err) }
}

fn keyframe_pseudo_test_style(name string) &dom.CSSComputedProperties_ {
	mut computed := computed_properties_with_initial_values()
	value := parse_css_value_logic(.animation_name, name) or { panic(err) }
	computed.set_property(.animation_name, dom_style_value_from_value_logic(value), .no, .no)
	return computed_properties_to_dom(computed)
}

fn test_keyframe_lookup_keeps_base_names_without_pseudo_records() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := keyframe_pseudo_test_element(document)
	assert !element_or_pseudo_references_animation_name(element, 'fade')
	element.set_computed_properties(none, keyframe_pseudo_test_style('other, "fade"'))
	assert element.pseudo_element_record_count() == 0
	assert element_or_pseudo_references_animation_name(element, 'fade')
	assert element_or_pseudo_references_animation_name(element, 'other')
	assert !element_or_pseudo_references_animation_name(element, 'Fade')
}

fn test_keyframe_lookup_keeps_unlaid_out_high_pseudo_styles() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := keyframe_pseudo_test_element(document)
	pseudo := int(dom.PseudoElement.known_pseudo_element_count) - 1
	element.set_computed_properties(pseudo, keyframe_pseudo_test_style('fade'))
	assert !element.has_pseudo_elements()
	gc_collect()
	assert element_or_pseudo_references_animation_name(element, 'fade')
	assert !element_or_pseudo_references_animation_name(element, 'other')
}

fn test_keyframe_lookup_follows_cleared_and_reused_pseudo_records() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := keyframe_pseudo_test_element(document)
	pseudo := int(dom.PseudoElement.before)
	element.set_computed_properties(pseudo, keyframe_pseudo_test_style('fade'))
	assert element_or_pseudo_references_animation_name(element, 'fade')
	element.set_computed_properties(pseudo, none)
	assert element.pseudo_element_record_count() == 1
	assert !element_or_pseudo_references_animation_name(element, 'fade')
	element.set_computed_properties(pseudo, keyframe_pseudo_test_style('replacement'))
	gc_collect()
	assert !element_or_pseudo_references_animation_name(element, 'fade')
	assert element_or_pseudo_references_animation_name(element, 'replacement')
}
