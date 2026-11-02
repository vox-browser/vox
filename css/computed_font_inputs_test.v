module css

import dom

fn test_computed_font_reuse_checks_every_font_input_and_keeps_nonfont_changes_independent() {
	computer := FontComputer.create()
	mut previous := ComputedProperties.new()
	previous.set_property_without_modifying_flags(.font_family, &dom.StyleValue{css_text: 'sans-serif'})
	previous.set_property_without_modifying_flags(.font_size, &dom.StyleValue{css_text: '16px'})
	list := previous.computed_font_list(computer)
	expected_font_inputs := [PropertyID.font_family, .font_size, .font_style, .font_weight,
		.font_width, .font_variation_settings, .font_optical_sizing, .font_feature_settings,
		.font_variant_alternates, .font_variant_caps, .font_variant_east_asian,
		.font_variant_emoji, .font_variant_ligatures, .font_variant_numeric,
		.font_variant_position, .font_kerning, .text_rendering, .font_synthesis_weight,
		.font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position]
	// Exercise the whole longhand space, rather than just the fast-path list.
	// Each changed font input must reject reuse; other properties keep their
	// independent style invalidation without discarding this font cascade.
	for id in computed_interpolation_longhand_property_ids() {
		mut next := &ComputedProperties{...previous, property_store_: previous.clone_raw_property_store()}
		next.set_property_without_modifying_flags(id, &dom.StyleValue{css_text: 'different input'})
		reused := next.reuse_unchanged_font_cache(previous, computer)
		assert reused == (id !in expected_font_inputs), string_from_property_id(id)
		if reused { assert voidptr(next.computed_font_list(computer)) == voidptr(list) }
	}
}

fn test_computed_font_input_comparison_observes_animated_values_and_in_place_changes() {
	mut previous := ComputedProperties.new()
	mut next := ComputedProperties.new()
	previous.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: '400'})
	next.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{css_text: '400'})
	assert computed_font_inputs_match(previous, next)
	next.set_animated_property(.font_weight, &dom.StyleValue{css_text: '700'}, .no, .no)
	assert !computed_font_inputs_match(previous, next)
	next.remove_animated_property(.font_weight)
	assert computed_font_inputs_match(previous, next)
	mut mutable_value := next.property(.font_weight, .no) or { panic('missing font weight') }
	mutable_value.css_text = '500'
	assert !computed_font_inputs_match(previous, next)
}

fn test_font_input_property_index_outlives_the_document_that_first_requests_it() {
	old_index := unsafe { computed_font_input_property_ids }
	computed_font_input_property_ids = []PropertyID{}
	defer { computed_font_input_property_ids = unsafe { old_index } }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	ids := computed_font_input_properties()
	scope.finish()
	document.finalize()
	document.release_native_storage()
	mut expected := []PropertyID{}
	for id in computed_interpolation_longhand_property_ids() {
		if property_affects_computed_font_list(id) { expected << id }
	}
	assert ids == expected
	assert ids.len == 21
	assert computed_font_input_properties() == expected
}
