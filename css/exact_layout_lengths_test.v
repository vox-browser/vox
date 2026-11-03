module css

import dom
import math

fn test_exact_layout_lengths_preserve_every_sampled_fixed_point_value_and_both_policies() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	mut style := computed_properties_with_initial_values()
	style.subject_element_ = element
	for chromium in [false, true] {
		if chromium { document.set_font_rendering_policy(.chromium) }
		for raw in [css_pixels_raw_min, css_pixels_raw_min + 1, -8193, -64, -1, 0, 1,
			63, 64, 8193, css_pixels_raw_max - 1, css_pixels_raw_max] {
			length := Length.make_px(f64(raw) / f64(css_pixels_fixed_point_denominator))
			assert style.absolute_layout_length_to_px(length) == CSSPixels.from_raw(raw)
		}
	}
}

fn test_fractional_layout_lengths_keep_the_document_rounding_policy() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div')!
	mut style := computed_properties_with_initial_values()
	style.subject_element_ = element
	for value in [f64(-2.5), -1.5, -0.5, 0.5, 1.5, 2.5] {
		length := Length.make_px(value / 64)
		assert style.absolute_layout_length_to_px(length) == CSSPixels.nearest_value_for(length.value_)
	}
	document.set_font_rendering_policy(.chromium)
	for value in [f64(-2.5), -1.5, -0.5, 0.5, 1.5, 2.5] {
		length := Length.make_px(value / 64)
		assert style.absolute_layout_length_to_px(length) == CSSPixels.truncated_value_for(length.value_)
	}
}

fn test_absolute_zero_units_keep_positive_and_negative_zero_results() {
	style := computed_properties_with_initial_values()
	for unit in [LengthUnit.px, .cm, .mm, .q, .in_, .pt, .pc] {
		for zero in [f64(0), math.f64_from_bits(u64(1) << 63)] {
			assert style.absolute_layout_length_to_px(Length.new(zero, unit)) == CSSPixels.from_raw(0)
		}
	}
}

fn test_nonfinite_and_out_of_range_lengths_keep_saturation_and_nan_behavior() {
	style := computed_properties_with_initial_values()
	for value in [math.inf(1), math.inf(-1), math.f64_from_bits(u64(0x7ff8000000001234)),
		1.0e308, -1.0e308, (f64(css_pixels_raw_max) + 1) / 64,
		(f64(css_pixels_raw_min) - 1) / 64] {
		length := Length.make_px(value)
		assert style.absolute_layout_length_to_px(length) == length.absolute_length_to_px()
	}
}

fn test_absolute_length_zero_shortcut_preserves_randomized_float_inputs() {
	style := computed_properties_with_initial_values()
	mut bits := u64(0x37a920a71bb84d13)
	for _ in 0 .. 8192 {
		bits = bits * u64(6364136223846793005) + u64(1442695040888963407)
		length := Length.make_px(math.f64_from_bits(bits))
		assert style.absolute_layout_length_to_px(length) == CSSPixels.nearest_value_for(length.value_)
	}
}
