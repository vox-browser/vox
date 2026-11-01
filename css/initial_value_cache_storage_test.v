module css

import dom
import platform

fn test_initial_value_cache_retains_cold_values_across_scratch_reuse() {
	ids := [PropertyID.color, .font_size, .display, .margin_top, .background_image,
		.transform, .border_top_style, .animation_name]
	mut values := []&dom.StyleValue{len: ids.len, init: unsafe { nil }}
	for index, id in ids {
		scratch := platform.begin_thread_scratch('cold initial property value')
		values[index] = computed_interpolation_property_initial_value(id)
		scratch.finish()
	}
	for _ in 0 .. 16 {
		scratch := platform.begin_thread_scratch('overwrite initial property caller')
		_ = []u8{len: 128 * 1024, init: 0xa5}
		scratch.finish()
	}
	for index, id in ids {
		actual := typed_style_value_logic_from_dom(values[index]) or { panic('missing initial value') }
		oracle := parse_css_value_logic(id, property_initial_value_string(id)) or { panic('invalid initial value') }
		assert actual.equals(oracle), string_from_property_id(id)
		assert voidptr(computed_interpolation_property_initial_value(id)) == voidptr(values[index])
	}
}

fn test_warm_initial_values_leave_a_callers_active_arena_unchanged() {
	mut expected := []&dom.StyleValue{len: number_of_longhand_properties, init: unsafe { nil }}
	for index in 0 .. number_of_longhand_properties {
		id := property_id_from_longhand_index(index) or { panic('missing longhand') }
		expected[index] = computed_interpolation_property_initial_value(id)
	}
	scratch := platform.begin_thread_scratch('warm initial property values')
	before := platform.thread_arena_usage().used
	for index in 0 .. number_of_longhand_properties {
		id := property_id_from_longhand_index(index) or { panic('missing longhand') }
		assert voidptr(computed_interpolation_property_initial_value(id)) == voidptr(expected[index])
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	scratch.finish()
}
