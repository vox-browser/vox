module css

fn dynamic_shape_tag_records(seed int) ShapeFeatures {
	return [
		ShapeFeature{tag: 'F${seed:03}', value: u32(seed)},
		ShapeFeature{tag: 'G${seed:03}', value: u32(seed + 1)},
	]
}

fn retained_shape_tag_records_after_source_clear(seed int) ShapeFeatures {
	mut source := dynamic_shape_tag_records(seed)
	result := owned_shape_features(source)
	for index in 0 .. source.len {
		source[index].tag = 'DROP'
		source[index].value = 0
	}
	source.clear()
	return result
}

fn shape_tag_fixture_font(seed int) PlatformFont {
	return PlatformFont{
		typeface: &PlatformTypeface{family_name: 'Owned immutable feature tags'}
		point_size: 12
		features: dynamic_shape_tag_records(seed)
	}
}

fn retained_shape_tag_font_after_source_clear(seed int) PlatformFont {
	mut source := shape_tag_fixture_font(seed)
	result := owned_platform_font(&source)
	for index in 0 .. source.features.len {
		source.features[index].tag = 'DROP'
		source.features[index].value = 0
	}
	source.features.clear()
	return result
}

fn test_owned_shape_tags_survive_dynamic_source_replacement_scope_exit_and_collection() {
	features := retained_shape_tag_records_after_source_clear(7)
	for _ in 0 .. 3 { gc_collect() }
	assert features.len == 2
	assert features[0].tag == 'F007'
	assert features[0].value == 7
	assert features[1].tag == 'G007'
	assert features[1].value == 8
}

fn test_owned_shape_tag_record_edits_are_independent_in_both_directions() {
	mut source := dynamic_shape_tag_records(12)
	mut copy := owned_shape_features(source)
	copy[0].tag = 'COPY'
	copy[0].value = 91
	source[1].tag = 'SRCE'
	source[1].value = 42
	assert source.len == 2
	assert copy.len == 2
	assert source[0].tag == 'F012'
	assert source[0].value == 12
	assert copy[1].tag == 'G012'
	assert copy[1].value == 13
	for _ in 0 .. 3 { gc_collect() }
	assert copy[0].tag == 'COPY'
	assert copy[0].value == 91
	assert source[1].tag == 'SRCE'
	assert source[1].value == 42
}

fn test_owned_platform_font_keeps_feature_tags_after_source_scope_and_later_edits() {
	mut font := retained_shape_tag_font_after_source_clear(21)
	copy := owned_platform_font(&font)
	font.features[0].tag = 'FONT'
	font.features[0].value = 77
	font.features[1].tag = 'EDIT'
	for _ in 0 .. 3 { gc_collect() }
	assert copy.typeface.family_name == 'Owned immutable feature tags'
	assert copy.point_size == 12
	assert copy.variations.weight == 400
	assert copy.features.len == 2
	assert copy.features[0].tag == 'F021'
	assert copy.features[0].value == 21
	assert copy.features[1].tag == 'G021'
	assert copy.features[1].value == 22
	assert font.features[0].tag == 'FONT'
	assert font.features[1].tag == 'EDIT'
}

fn test_cascade_feature_tag_storage_stays_independent_across_extend_invisible_and_last_resort() {
	mut source := shape_tag_fixture_font(31)
	mut first := FontCascadeList.create()
	first.add(source, [])
	mut second := FontCascadeList.create()
	second.extend(first)
	second.set_last_resort_font(source)
	invisible := second.font_with_visibility(&source, true)
	for index in 0 .. source.features.len {
		source.features[index].tag = 'DROP'
		source.features[index].value = 0
	}
	source.features.clear()
	mut selected := unsafe { &PlatformFont(second.font_for_code_point(u32(`A`))) }
	selected.features[0].tag = 'COPY'
	selected.features[0].value = 99
	for _ in 0 .. 3 { gc_collect() }
	assert first.fonts[0].font.features[0].tag == 'F031'
	assert first.fonts[0].font.features[0].value == 31
	assert first.fonts[0].font.features[1].tag == 'G031'
	assert second.fonts[0].font.features[0].tag == 'COPY'
	assert second.fonts[0].font.features[0].value == 99
	assert second.fonts[0].font.features[1].tag == 'G031'
	assert second.last_resort_font.features[0].tag == 'F031'
	assert second.last_resort_font.features[0].value == 31
	assert invisible.is_invisible
	assert invisible.features[0].tag == 'F031'
	assert invisible.features[0].value == 31
	assert invisible.features[1].tag == 'G031'
}
