module css

import dom

$if gcboehm ? {
	fn C.GC_gcollect()
	fn C.GC_get_total_bytes() uint
}

fn font_normal_parse(property PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property) or { panic('invalid font fixture') }
}

fn test_font_normal_variation_resolution_keeps_typed_and_bridge_reads_allocation_free() {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	typed := font_normal_parse(.font_variation_settings, 'normal')
	bridge := &dom.StyleValue{ css_text: ' \tNoRmAl\n' }
	for normal in [typed, bridge] {
		style.set_property(.font_variation_settings, normal, .no, .no)
		apply_resolved_font_variation_settings(style, mut values)
		mut before := uint(0)
		$if gcboehm ? {
			C.GC_gcollect()
			before = C.GC_get_total_bytes()
		}
		for _ in 0 .. 1024 {
			apply_resolved_font_variation_settings(style, mut values)
		}
		mut allocated := uint(0)
		$if gcboehm ? {
			allocated = C.GC_get_total_bytes() - before
		}
		assert allocated == 0
		assert style.font_variation_storage_ == unsafe { nil }
	}
}

fn test_font_normal_variation_live_resolution_clears_map_and_preserves_old_snapshots() {
	mut style := computed_properties_with_initial_values()
	variation := font_normal_parse(.font_variation_settings, '"wght" 610, "wdth" 87.5')
	style.set_property(.font_variation_settings, variation, .no, .no)
	_ = resolve_computed_values(style)
	values := unsafe { &ComputedValues(style) }
	mut snapshot := values.font_variation_settings()
	assert snapshot['wght'] == 610 && snapshot['wdth'] == 87.5
	snapshot['wght'] = 200
	assert values.font_variation_settings()['wght'] == 610
	style.set_property(.font_variation_settings, &dom.StyleValue{ css_text: 'normal' }, .no, .no)
	_ = resolve_computed_values(style)
	assert style.font_variation_storage_ == unsafe { nil }
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
	}
	assert snapshot['wght'] == 200 && snapshot['wdth'] == 87.5
	style.set_property(.font_variation_settings, variation, .no, .no)
	_ = resolve_computed_values(style)
	assert values.font_variation_settings()['wght'] == 610
}

fn test_font_normal_variation_respects_animation_transition_and_important_precedence() {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	normal := font_normal_parse(.font_variation_settings, 'normal')
	variation := font_normal_parse(.font_variation_settings, '"wght" 720')
	style.set_property(.font_variation_settings, normal, .no, .yes)
	style.set_animated_property(.font_variation_settings, variation, .no, .no)
	apply_resolved_font_variation_settings(style, mut values)
	assert style.font_variation_storage_ == unsafe { nil }
	style.set_animated_property(.font_variation_settings, variation, .yes, .no)
	apply_resolved_font_variation_settings(style, mut values)
	assert style.font_variation_storage_.values['wght'] == 720
	style.remove_animated_property(.font_variation_settings)
	apply_resolved_font_variation_settings(style, mut values)
	assert style.font_variation_storage_ == unsafe { nil }
	style.set_property(.font_variation_settings, variation, .no, .no)
	style.set_animated_property(.font_variation_settings, normal, .no, .no)
	apply_resolved_font_variation_settings(style, mut values)
	assert style.font_variation_storage_ == unsafe { nil }
}

fn test_font_feature_direct_map_preserves_narrowing_duplicate_order_and_snapshot_ownership() {
	mut style := computed_properties_with_initial_values()
	mut typed := dom_style_value_from_value_logic(StyleValue(StyleValueList.create([
		StyleValue(OpenTypeTaggedStyleValue.create(.font_feature_settings, 'liga', StyleValue(IntegerStyleValue.create(257)))),
		StyleValue(OpenTypeTaggedStyleValue.create(.font_feature_settings, 'kern', StyleValue(IntegerStyleValue.create(-1)))),
		StyleValue(StringStyleValue.create('ignored')),
		StyleValue(OpenTypeTaggedStyleValue.create(.font_feature_settings, 'liga', StyleValue(IntegerStyleValue.create(258)))),
	], .comma, .no)))
	typed.css_text = 'normal'
	style.set_property(.font_feature_settings, typed, .no, .no)
	mut data := style.font_feature_data()
	assert data.font_feature_settings.len == 2
	assert data.font_feature_settings['liga'] == 2
	assert data.font_feature_settings['kern'] == 255
	mut public_snapshot := style.font_feature_settings()
	public_snapshot['liga'] = 9
	data.font_feature_settings['kern'] = 17
	assert style.font_feature_settings()['liga'] == 2
	assert style.font_feature_data().font_feature_settings['kern'] == 255
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
	}
	assert public_snapshot['liga'] == 9 && data.font_feature_settings['kern'] == 17
}

fn test_font_feature_direct_map_retains_bridge_fallback_variants_and_animated_precedence() {
	mut style := computed_properties_with_initial_values()
	style.set_property(.font_variant_caps, font_normal_parse(.font_variant_caps, 'small-caps'), .no, .no)
	style.set_property(.font_kerning, font_normal_parse(.font_kerning, 'none'), .no, .no)
	style.set_property(.text_rendering, font_normal_parse(.text_rendering, 'optimizeSpeed'), .no, .no)
	style.set_property(.font_feature_settings, &dom.StyleValue{ css_text: '"liga" 3, "kern" 0, "liga" 5' }, .no, .no)
	data := style.font_feature_data()
	assert data.font_feature_settings.len == 2
	assert data.font_feature_settings['liga'] == 5 && data.font_feature_settings['kern'] == 0
	assert data.font_variant_caps == .small_caps
	assert data.font_kerning == .none_
	assert data.text_rendering == .optimizespeed
	normal := font_normal_parse(.font_feature_settings, 'normal')
	animated := font_normal_parse(.font_feature_settings, '"liga" 7')
	style.set_property(.font_feature_settings, normal, .no, .yes)
	style.set_animated_property(.font_feature_settings, animated, .no, .no)
	assert style.font_feature_data().font_feature_settings.len == 0
	style.set_animated_property(.font_feature_settings, animated, .yes, .no)
	assert style.font_feature_data().font_feature_settings['liga'] == 7
	style.remove_animated_property(.font_feature_settings)
	style.set_property(.font_feature_settings, &dom.StyleValue{ css_text: 'unrecognized invalid font feature' }, .no, .no)
	assert style.font_feature_data().font_feature_settings.len == 0
	style.set_property(.font_feature_settings, &dom.StyleValue{ css_text: '\t NORMAL ' }, .no, .no)
	assert style.font_feature_data().font_feature_settings.len == 0
	assert data.font_feature_settings['liga'] == 5
}
