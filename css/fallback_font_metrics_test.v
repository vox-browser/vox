module css

import platform

fn test_generic_length_metrics_keep_the_exact_face_metrics_and_existing_size_formulas() {
	for size in [0.0, 0.25, 13.25, 16.0, 41.125] {
		pixels := CSSPixels.nearest_value_for(size)
		actual := computed_interpolation_font_metrics_for_size(pixels)
		font := platform.Font{ family: 'sans-serif', point_size: f32(pixels.to_double()) }
		expected := font.pixel_metrics()
		ratio := pixels.to_double() / 16
		assert actual.font_size == pixels
		assert actual.x_height == CSSPixels.nearest_value_for(f64(expected.x_height))
		assert actual.zero_advance == CSSPixels.nearest_value_for(f64(expected.advance_of_ascii_zero))
		assert actual.cap_height == CSSPixels.nearest_value_for(12 * ratio)
		assert actual.line_height == CSSPixels.nearest_value_for(19.2 * ratio)
		assert computed_interpolation_font_metrics_for_size(pixels) == actual
	}
}

fn test_generic_length_metrics_remain_usable_after_temporary_storage_is_reused() {
	size := CSSPixels.nearest_value_for(23.375)
	first := computed_interpolation_font_metrics_for_size(size)
	for index in 0 .. 12 {
		_ = platform.fallback_font_pixel_metrics(f32(index) + 8.5)
	}
	second := computed_interpolation_font_metrics_for_size(size)
	assert first == second
	assert second.font_size == size
	assert second.x_height.to_double() > 0
	assert second.zero_advance.to_double() > 0
}
