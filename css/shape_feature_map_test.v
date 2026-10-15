module css

fn assert_shape_feature_sequence(actual ShapeFeatures, tags []string, values []u32) {
	assert actual.len == tags.len
	assert tags.len == values.len
	for index, feature in actual {
		assert feature.tag == tags[index]
		assert feature.value == values[index]
	}
}

fn test_shape_features_keep_default_and_optimize_speed_feature_order() {
	defaults := FontFeatureData{}.to_shape_features(map[string][]u32{})
	assert_shape_feature_sequence(defaults, ['liga', 'clig', 'kern'], [u32(1), 1, 1])
	speed := FontFeatureData{text_rendering: .optimizespeed}.to_shape_features(map[string][]u32{})
	assert_shape_feature_sequence(speed, ['liga', 'clig', 'dlig', 'hlig', 'calt', 'kern'],
		[u32(0), 0, 0, 0, 0, 0])
}

fn test_shape_features_explicit_settings_override_variants_without_reordering_or_input_mutation() {
	data := FontFeatureData{
		font_variant_ligatures: FontVariantLigatures{none_: true}
		font_variant_position: .super
		font_variant_caps: .all_small_caps
		font_variant_numeric: FontVariantNumeric{
			figure: .oldstyle_nums
			spacing: .tabular_nums
			fraction: .stacked_fractions
			ordinal: true
			slashed_zero: true
		}
		font_variant_east_asian: FontVariantEastAsian{variant: .jis04, width: .full_width, ruby: true}
		font_kerning: .none_
		font_feature_settings: {
			'liga': u32(7)
			'kern': 9
			'c2sc': 0
			'zero': 11
			'TEST': 42
			'bad': 333
			'FIVES': 444
		}
	}
	original := data.font_feature_settings.clone()
	features := data.to_shape_features(map[string][]u32{})
	assert_shape_feature_sequence(features,
		['liga', 'clig', 'dlig', 'hlig', 'calt', 'sups', 'c2sc', 'smcp',
		 'onum', 'tnum', 'afrc', 'ordn', 'zero', 'jp04', 'fwid', 'ruby', 'kern', 'TEST'],
		[u32(7), 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 11, 1, 1, 1, 9, 42])
	assert data.font_feature_settings == original
	assert data.font_feature_settings['bad'] == 333
	assert data.font_feature_settings['FIVES'] == 444
}

fn test_shape_features_preserve_named_alternates_explicit_precedence_and_value_inputs() {
	styles := FontFeatureValueKey{type_: .styleset, name: 'chosen-styles'}
	variant := FontFeatureValueKey{type_: .character_variant, name: 'chosen-variant'}
	mut named_values := map[string][]u32{}
	named_values[font_feature_value_key_id(styles)] = [u32(1), 99, 100, 0, 1]
	named_values[font_feature_value_key_id(variant)] = [u32(27), 5]
	data := FontFeatureData{
		font_variant_alternates: FontVariantAlternates{
			historical_forms: true
			font_feature_value_entries: [styles, variant]
		}
		font_feature_settings: {'hist': u32(0), 'ss01': 0, 'cv27': 17, 'NEW4': 23}
	}
	original_settings := data.font_feature_settings.clone()
	features := data.to_shape_features(named_values)
	assert_shape_feature_sequence(features,
		['liga', 'clig', 'hist', 'ss01', 'ss99', 'cv27', 'kern', 'NEW4'],
		[u32(1), 1, 0, 0, 1, 17, 1, 23])
	assert data.font_feature_settings == original_settings
	assert named_values[font_feature_value_key_id(styles)] == [u32(1), 99, 100, 0, 1]
	assert named_values[font_feature_value_key_id(variant)] == [u32(27), 5]
}

fn test_shape_feature_results_keep_independent_storage_after_input_edits_and_collection() {
	tag := ['TE', 'ST'].join('')
	mut data := FontFeatureData{font_feature_settings: {tag: u32(7)}}
	original := data.font_feature_settings.clone()
	mut first := data.to_shape_features(map[string][]u32{})
	assert data.font_feature_settings == original
	data.font_feature_settings[tag] = 23
	second := data.to_shape_features(map[string][]u32{})
	first[0].tag = 'EDIT'
	first[0].value = 99
	data.font_feature_settings.clear()
	for _ in 0 .. 3 { gc_collect() }
	assert_shape_feature_sequence(first, ['EDIT', 'clig', 'kern', 'TEST'], [u32(99), 1, 1, 7])
	assert_shape_feature_sequence(second, ['liga', 'clig', 'kern', 'TEST'], [u32(1), 1, 1, 23])
	third := data.to_shape_features(map[string][]u32{})
	assert_shape_feature_sequence(third, ['liga', 'clig', 'kern'], [u32(1), 1, 1])
	assert data.font_feature_settings.len == 0
}
