module css

import dom

fn pending_font_style() &ComputedProperties {
	mut style := ComputedProperties.new()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'Pending'
	})
	style.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '16px'
	})
	return style
}

fn test_pending_font_cascade_is_reused_for_unchanged_style() {
	mut computer := FontComputer.create()
	face := FontFaceObject.construct_impl('Pending',
		FontFaceSource.from_string('url("pending.ttf")'), FontFaceDescriptors{})
	computer.register_font_face(face)
	mut previous := pending_font_style()
	previous_list := previous.computed_font_list(computer)
	assert previous_list.pending_faces.len == 1
	mut next := pending_font_style()
	assert !previous_list.equals(next.computed_font_list(computer))
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns(dom.namespace_html_uri, 'div')!
	abstract_element := dom.AbstractElement.new(element, none)
	invalidation := compute_required_invalidation(previous, next, computer, none, abstract_element)
	assert !invalidation.needs_relayout()
	assert voidptr(next.computed_font_list(computer)) == voidptr(previous_list)
	// The lower-level pending-cascade comparison keeps its upstream behavior.
	assert !previous_list.equals(previous_list)
}

fn test_font_cache_reuse_rejects_changed_inputs_and_environment() {
	mut computer := FontComputer.create()
	mut previous := pending_font_style()
	_ = previous.computed_font_list(computer)
	for property_id, text in {
		PropertyID.font_size:   '20px'
		.font_weight:           '700'
		.font_optical_sizing:   'none'
		.font_feature_settings: '"liga" 0'
		.font_variant_caps:     'small-caps'
		.font_kerning:          'none'
		.text_rendering:        'optimizeSpeed'
	} {
		mut changed := pending_font_style()
		changed.set_property_without_modifying_flags(property_id, &dom.StyleValue{
			css_text: text
		})
		assert !changed.reuse_unchanged_font_cache(previous, computer)
	}
	mut next := pending_font_style()
	computer.clear_computed_font_cache('Pending')
	assert !next.reuse_unchanged_font_cache(previous, computer)
	other_computer := FontComputer.create()
	assert !next.reuse_unchanged_font_cache(previous, other_computer)
}

fn test_font_feature_mutations_clear_the_cached_cascade() {
	computer := FontComputer.create()
	mut style := pending_font_style()
	for property_id in [PropertyID.font_optical_sizing, .font_feature_settings, .font_variant_caps,
		.font_variant_emoji, .font_kerning, .text_rendering] {
		_ = style.computed_font_list(computer)
		style.set_property_without_modifying_flags(property_id,
			&dom.StyleValue{
			css_text: 'normal'
		})
		assert style.cached_computed_font_list() == none
	}
}
