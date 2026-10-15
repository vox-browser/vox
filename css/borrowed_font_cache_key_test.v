module css

$if gcboehm ? { fn C.GC_gcollect() }

fn borrowed_font_key_id(families []string, variations map[string]f64, features FontFeatureData) string {
	return ComputedFontCacheKey{
		font_family: families.clone()
		font_optical_sizing: .auto_
		font_size: CSSPixels.new(16)
		font_slope: 0
		font_weight: 400
		font_width: Percentage{ value_: 100 }
		font_variation_settings: variations.clone()
		font_feature_data: features
	}.id()
}

fn test_computed_font_cache_hits_keep_identical_keys_and_leave_borrowed_inputs_untouched() {
	mut computer := FontComputer.create()
	families := ['SerenitySans', 'serif']
	variations := {'wdth': 110.0, 'wght': 450.0}
	features := FontFeatureData{ font_feature_settings: {'liga': u32(1)} }
	id := borrowed_font_key_id(families, variations, features)
	cached := FontCascadeList.create()
	computer.computed_font_cache[id] = cached
	for _ in 0 .. 32 {
		hit := computer.compute_font_for_style_values(families, CSSPixels.new(16), 0, 400,
			Percentage{ value_: 100 }, .auto_, variations, features)
		assert voidptr(hit) == voidptr(cached)
	}
	assert computer.computed_font_cache.len == 1
	assert families == ['SerenitySans', 'serif']
	assert variations == {'wdth': 110.0, 'wght': 450.0}
	assert features.font_feature_settings == {'liga': u32(1)}
	$if gcboehm ? { C.GC_gcollect() }
	assert voidptr(computer.computed_font_cache[id] or { panic('missing cache entry') }) == voidptr(cached)
}

fn test_computed_font_cache_miss_owns_key_and_cascade_after_input_changes_and_collection() {
	mut computer := FontComputer.create()
	mut families := ['serif']
	mut variations := {'wdth': 110.0}
	features := FontFeatureData{ font_feature_settings: {'liga': u32(1)} }
	id := borrowed_font_key_id(families, variations, features)
	first := computer.compute_font_for_style_values(families, CSSPixels.new(16), 0, 400,
		Percentage{ value_: 100 }, .auto_, variations, features)
	assert first.last_resort_font != unsafe { nil }
	assert first.last_resort_font.variations.axes['wdth'] == 110
	families[0] = 'monospace'
	variations['wdth'] = 130
	variations.clear()
	$if gcboehm ? { C.GC_gcollect() }
	assert computer.computed_font_cache.len == 1
	assert voidptr(computer.computed_font_cache[id] or { panic('original key was lost') }) == voidptr(first)
	assert first.last_resort_font.variations.axes['wdth'] == 110
	hit := computer.compute_font_for_style_values(['serif'], CSSPixels.new(16), 0, 400,
		Percentage{ value_: 100 }, .auto_, {'wdth': 110.0}, features)
	assert voidptr(hit) == voidptr(first)
}

fn test_computed_font_cache_empty_axes_hit_survives_collection_and_owning_key_edits() {
	mut computer := FontComputer.create()
	families := ['serif']
	variations := map[string]f64{}
	features := FontFeatureData{}
	id := borrowed_font_key_id(families, variations, features)
	cached := FontCascadeList.create()
	computer.computed_font_cache[id] = cached
	mut independent_key := ComputedFontCacheKey{
		font_family: families.clone()
		font_variation_settings: variations.clone()
	}
	independent_key.font_family[0] = 'monospace'
	independent_key.font_variation_settings['wdth'] = 200
	$if gcboehm ? { C.GC_gcollect() }
	hit := computer.compute_font_for_style_values(families, CSSPixels.new(16), 0, 400,
		Percentage{ value_: 100 }, .auto_, variations, features)
	assert voidptr(hit) == voidptr(cached)
	assert families == ['serif']
	assert variations.len == 0
	assert computer.computed_font_cache.len == 1
}
