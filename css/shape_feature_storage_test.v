module css

import platform

fn test_shape_feature_output_owns_generated_tags_after_workspace_reuse() {
	key := FontFeatureValueKey{type_: .character_variant, name: 'owned-variant'}
	data := FontFeatureData{
		font_variant_alternates: FontVariantAlternates{font_feature_value_entries: [key]}
	}
	mut input := platform.new_arena('temporary font feature values')
	entry := input.enter()
	mut values := map[string][]u32{}
	values[font_feature_value_key_id(key)] = [u32(37), 11]
	input.leave(entry)
	features := data.to_shape_features(values)
	input.release()
	for _ in 0 .. 32 {
		_ = FontFeatureData{text_rendering: .optimizespeed}.to_shape_features(map[string][]u32{})
	}
	assert_shape_feature_sequence(features, ['liga', 'clig', 'cv37', 'kern'], [u32(1), 1, 11, 1])
}

fn test_shape_feature_selection_retains_only_output_storage() {
	data := FontFeatureData{}
	values := map[string][]u32{}
	tags := ['liga', 'clig', 'kern']
	settings := [u32(1), 1, 1]
	mut storage := platform.new_arena('font feature output budget')
	entry := storage.enter()
	before := storage.usage().used
	for _ in 0 .. 128 {
		features := data.to_shape_features(values)
		assert_shape_feature_sequence(features, tags, settings)
	}
	growth := storage.usage().used - before
	storage.leave(entry)
	$if prealloc { assert growth <= 128 * 256, '${growth} bytes for 128 three-feature results' }
	storage.release()
}
