module layout

import css

fn fixed_point_sum_boundary_values() []int {
	return [CSSPixels.min().raw_value(), CSSPixels.min().raw_value() + 1, -2147483584, -1000001,
		-129, -128, -127, -65, -64, -63, -1, 0, 1, 63, 64, 65, 127, 128, 129, 1000001, 2147483583,
		CSSPixels.max().raw_value() - 1, CSSPixels.max().raw_value()]
}

fn test_fixed_point_pair_and_point_sums_match_float_reference_at_boundaries() {
	values := fixed_point_sum_boundary_values()
	for a_raw in values {
		for b_raw in values {
			a := CSSPixels.from_raw(a_raw)
			b := CSSPixels.from_raw(b_raw)
			expected := CSSPixels.nearest_value_for(a.to_double() + b.to_double())
			assert css_pixels_sum2(a, b) == expected
			point := css_pixel_point_add(css.CSSPixelPoint.new(a, b), css.CSSPixelPoint.new(b, a))
			assert point.x() == expected
			assert point.y() == expected
		}
	}
}

fn test_fixed_point_multi_operand_sums_clamp_after_cancellation() {
	max := CSSPixels.max()
	min := CSSPixels.min()
	zero := CSSPixels.from_raw(0)
	assert css_pixels_sum3(max, max, min).raw_value() == max.raw_value() - 1
	assert css_pixels_sum3(min, min, max) == min
	assert css_pixels_sum3(max, CSSPixels.from_raw(1), min).raw_value() == 0
	assert css_pixels_sum5(max, max, min, min, zero).raw_value() == -2
	assert css_pixels_sum5(min, min, max, max, CSSPixels.from_raw(2)).raw_value() == 0
	assert css_pixels_sum5(max, max, max, max, max) == max
	assert css_pixels_sum5(min, min, min, min, min) == min
	assert css_pixels_sum5(CSSPixels.from_raw(1), CSSPixels.from_raw(3), CSSPixels.from_raw(-5),
		CSSPixels.from_raw(7), CSSPixels.from_raw(-8)).raw_value() == -2
}

fn test_fixed_point_multi_operand_sums_match_previous_float_path() {
	mut bits := u64(0xe5b6e3aa2e47fd91)
	for _ in 0 .. 8192 {
		mut values := []CSSPixels{cap: 5}
		for _ in 0 .. 5 {
			bits = bits * u64(6364136223846793005) + u64(1442695040888963407)
			values << CSSPixels.from_raw(int(u32(bits >> 32)))
		}
		a, b, c, d, e := values[0], values[1], values[2], values[3], values[4]
		assert css_pixels_sum3(a, b, c) == CSSPixels.nearest_value_for(a.to_double() +
			b.to_double() + c.to_double())
		assert css_pixels_sum5(a, b, c, d, e) == CSSPixels.nearest_value_for(a.to_double() +
			b.to_double() + c.to_double() + d.to_double() + e.to_double())
	}
}

fn test_fixed_point_point_axes_saturate_independently() {
	a := css.CSSPixelPoint.new(CSSPixels.max(), CSSPixels.from_raw(1))
	b := css.CSSPixelPoint.new(CSSPixels.from_raw(1), CSSPixels.min())
	result := css_pixel_point_add(a, b)
	assert result.x() == CSSPixels.max()
	assert result.y().raw_value() == CSSPixels.min().raw_value() + 1
	assert css_pixel_point_add(css.CSSPixelPoint.new(CSSPixels.min(), CSSPixels.max()), css.CSSPixelPoint.new(CSSPixels.max(),
		CSSPixels.min())) == css.CSSPixelPoint.new(CSSPixels.from_raw(-1), CSSPixels.from_raw(-1))
}
