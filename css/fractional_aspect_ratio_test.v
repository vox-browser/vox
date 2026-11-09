module css

fn test_fractional_ratios_preserve_precision_until_the_final_layout_dimension() {
	for values in [[1.6, 1.0, 320.0, 200.0], [0.00025, 0.0001, 100.0, 40.0],
		[1.5, 1.0, 300.0, 200.0], [16.0, 10.0, 320.0, 200.0]] {
		ratio := CSSPixelFraction.from_values(values[0], values[1])
		height := CSSPixels.nearest_value_for(values[2]).divided_by_fraction(ratio)
		assert height == CSSPixels.nearest_value_for(values[3])
	}
	assert CSSPixelFraction.from_values(1e-100, 1.0).numerator().raw_value() != 0
	assert CSSPixelFraction.from_values(1.0, 1e-100).denominator().raw_value() != 0
	assert CSSPixelFraction.from_values(1e-100, 1e-100).to_double() == 1
}
