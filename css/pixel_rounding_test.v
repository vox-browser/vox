module css

import math

#include <fenv.h>

fn C.fegetround() int
fn C.fesetround(int) int

fn test_css_pixel_nearest_rounds_halfway_raw_units_to_even() {
	inputs := [f64(-3.5), -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5]
	expected := [-4, -2, -2, 0, 0, 2, 2, 4]
	for i, raw in inputs {
		assert CSSPixels.nearest_value_for(raw / 64).raw_value_ == expected[i]
	}
	// Check the representable values immediately on each side of a tie.
	for raw in [f64(0.5), 1.5, 2.5, 3.5, 100.5, 2147483646.5] {
		tie := raw / 64
		bits := math.f64_bits(tie)
		assert CSSPixels.nearest_value_for(math.f64_from_bits(bits - 1)).raw_value_ == int(raw)
		assert CSSPixels.nearest_value_for(math.f64_from_bits(bits + 1)).raw_value_ == int(raw) + 1
		assert CSSPixels.nearest_value_for(-math.f64_from_bits(bits - 1)).raw_value_ == -int(raw)
		assert CSSPixels.nearest_value_for(-math.f64_from_bits(bits + 1)).raw_value_ == -int(raw) - 1
	}
}

fn test_css_pixel_nearest_preserves_saturation_and_nonfinite_values() {
	for value in [math.inf(1), 1.0e308, f64(css_pixels_raw_max) / 64,
		(f64(css_pixels_raw_max) + 0.5) / 64] {
		assert CSSPixels.nearest_value_for(value) == CSSPixels.max()
	}
	for value in [math.inf(-1), -1.0e308, f64(css_pixels_raw_min) / 64,
		(f64(css_pixels_raw_min) - 0.5) / 64] {
		assert CSSPixels.nearest_value_for(value) == CSSPixels.min()
	}
	assert CSSPixels.nearest_value_for((f64(css_pixels_raw_max) - 0.5) / 64).raw_value_ == css_pixels_raw_max - 1
	assert CSSPixels.nearest_value_for((f64(css_pixels_raw_min) + 0.5) / 64) == CSSPixels.min()
	for bits in [u64(0), u64(1) << 63, u64(1), (u64(1) << 63) | 1,
		u64(0x7ff8000000000000), u64(0xfff8000000000000), u64(0x7ff8000000001234)] {
		assert CSSPixels.nearest_value_for(math.f64_from_bits(bits)).raw_value_ == 0
	}
}

fn test_css_pixel_nearest_matches_portable_rounding_across_float_bit_patterns() {
	mut bits := u64(0x239c107c91f473ab)
	for _ in 0 .. 8192 {
		bits = bits * u64(6364136223846793005) + u64(1442695040888963407)
		value := math.f64_from_bits(bits)
		if math.is_nan(value) {
			assert CSSPixels.nearest_value_for(value).raw_value_ == 0
			continue
		}
		rounded := math.round_to_even(value * 64)
		expected := if rounded >= f64(css_pixels_raw_max) { css_pixels_raw_max }
			else if rounded <= f64(css_pixels_raw_min) { css_pixels_raw_min }
			else { int(rounded) }
		assert CSSPixels.nearest_value_for(value).raw_value_ == expected
	}
}

fn test_css_pixel_nearest_ignores_ambient_rounding_direction() {
	previous := C.fegetround()
	assert previous != -1
	defer { C.fesetround(previous) }
	inputs := [f64(-3.5), -2.5, -1.5, -0.5, 0.5, 1.5, 2.5, 3.5]
	expected := [-4, -2, -2, 0, 0, 2, 2, 4]
	for mode in [int(C.FE_TONEAREST), int(C.FE_DOWNWARD), int(C.FE_UPWARD), int(C.FE_TOWARDZERO)] {
		assert C.fesetround(mode) == 0
		for i, raw in inputs {
			assert CSSPixels.nearest_value_for(raw / 64).raw_value_ == expected[i]
		}
	}
}
