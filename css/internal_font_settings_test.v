module css

import dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
}

fn internal_font_settings_style() &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'serif'
	})
	return style
}

fn internal_font_settings_parse(property PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property) or { panic('invalid setting') }
}

fn test_internal_normal_font_settings_reads_allocate_nothing_for_typed_and_bridge_values() {
	computer := FontComputer.create()
	mut style := internal_font_settings_style()
	typed := internal_font_settings_parse(.font_variation_settings, 'normal')
	for normal in [typed, &dom.StyleValue{
		css_text: ' \tNoRmAl\n'
	}] {
		style.set_property_without_modifying_flags(.font_variation_settings, normal)
		style.set_property_without_modifying_flags(.font_feature_settings, normal)
		_ = computer.variation_settings_for_computation(style)
		_ = computer.feature_data_for_computation(style)
		gc_collect()
		mut before := usize(0)
		$if gcboehm ? { before = C.GC_get_total_bytes() }
		mut count := 0
		for _ in 0 .. 1024 {
			variations := computer.variation_settings_for_computation(style)
			features := computer.feature_data_for_computation(style)
			count += variations.len + features.font_feature_settings.len + 1
		}
		mut allocated := usize(0)
		$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
		assert allocated == 0
		assert count == 1024
	}
	assert computer.normal_variation_settings_.len == 0
	assert computer.normal_feature_settings_.len == 0
}

fn test_internal_normal_maps_never_alias_public_mutable_snapshots() {
	computer := FontComputer.create()
	style := internal_font_settings_style()
	mut public_variations := style.font_variation_settings()
	mut public_features := style.font_feature_data()
	mut public_narrow_features := style.font_feature_settings()
	public_variations['wght'] = 900
	public_features.font_feature_settings['liga'] = 7
	public_narrow_features['kern'] = 9
	gc_collect()
	assert computer.variation_settings_for_computation(style).len == 0
	assert computer.feature_data_for_computation(style).font_feature_settings.len == 0
	assert computer.normal_variation_settings_.len == 0
	assert computer.normal_feature_settings_.len == 0
	assert public_variations['wght'] == 900
	assert public_features.font_feature_settings['liga'] == 7
	assert public_narrow_features['kern'] == 9
}

fn test_internal_non_normal_maps_keep_duplicate_conversion_and_independent_storage() {
	computer := FontComputer.create()
	mut style := internal_font_settings_style()
	style.set_property_without_modifying_flags(.font_variation_settings, &dom.StyleValue{
		css_text: '"wght" 450, "wdth" 87.5'
	})
	style.set_property_without_modifying_flags(.font_feature_settings, &dom.StyleValue{
		css_text: '"liga" 257, "kern" 0, "liga" 258'
	})
	style.set_property_without_modifying_flags(.font_variant_caps, internal_font_settings_parse(.font_variant_caps,
		'small-caps'))
	mut variations := computer.variation_settings_for_computation(style)
	mut features := computer.feature_data_for_computation(style)
	assert variations == style.font_variation_settings()
	assert features.font_feature_settings == style.font_feature_data().font_feature_settings
	assert features.font_feature_settings['liga'] == 2
	assert features.font_feature_settings['kern'] == 0
	assert features.font_variant_caps == .small_caps
	// Deliberately mutate these returned maps without cloning: the following
	// assertions verify their storage is independent of the immutable owners.
	unsafe {
		variations['wght'] = 900
		features.font_feature_settings['liga'] = 9
	}
	gc_collect()
	assert computer.variation_settings_for_computation(style)['wght'] == 450
	assert computer.feature_data_for_computation(style).font_feature_settings['liga'] == 2
	assert computer.normal_variation_settings_.len == 0
	assert computer.normal_feature_settings_.len == 0
}

fn test_internal_settings_follow_typed_payloads_and_animated_important_precedence() {
	computer := FontComputer.create()
	mut style := internal_font_settings_style()
	normal := internal_font_settings_parse(.font_variation_settings, 'normal')
	mut axes := internal_font_settings_parse(.font_variation_settings, '"wght" 620')
	axes.css_text = 'normal'
	style.set_property(.font_variation_settings, axes, .no, .no)
	assert computer.variation_settings_for_computation(style)['wght'] == 620
	mut features := internal_font_settings_parse(.font_feature_settings, '"liga" 7')
	features.css_text = 'normal'
	style.set_property(.font_feature_settings, features, .no, .no)
	assert computer.feature_data_for_computation(style).font_feature_settings['liga'] == 7
	style.set_property(.font_variation_settings, normal, .no, .yes)
	style.set_animated_property(.font_variation_settings, axes, .no, .no)
	assert computer.variation_settings_for_computation(style).len == 0
	style.set_animated_property(.font_variation_settings, axes, .yes, .no)
	assert computer.variation_settings_for_computation(style)['wght'] == 620
	style.remove_animated_property(.font_variation_settings)
	assert computer.variation_settings_for_computation(style).len == 0
	style.set_property(.font_feature_settings, normal, .no, .yes)
	style.set_animated_property(.font_feature_settings, features, .no, .no)
	assert computer.feature_data_for_computation(style).font_feature_settings.len == 0
	style.set_animated_property(.font_feature_settings, features, .yes, .no)
	assert computer.feature_data_for_computation(style).font_feature_settings['liga'] == 7
}

fn test_internal_normal_settings_use_identical_cascade_keys_and_survive_environment_changes() {
	mut computer := FontComputer.create()
	mut style := internal_font_settings_style()
	first := style.computed_font_list(computer)
	legacy := computer.compute_font_for_style_values(['serif'], style.font_size(),
		style.font_slope(), style.font_weight(), style.font_width(), style.font_optical_sizing(),
		style.font_variation_settings(), style.font_feature_data())
	assert voidptr(first) == voidptr(legacy)
	old_font := first.font_for_code_point(u32(`A`))
	computer.clear_computed_font_cache('serif')
	fresh := style.computed_font_list(computer)
	assert voidptr(fresh) != voidptr(first)
	gc_collect()
	assert first.font_for_code_point(u32(`A`)).point_size == old_font.point_size
	assert fresh.font_for_code_point(u32(`A`)).point_size == old_font.point_size
	assert computer.normal_variation_settings_.len == 0
	assert computer.normal_feature_settings_.len == 0
}
