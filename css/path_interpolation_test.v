module css

fn test_path_shapes_interpolate_compatible_segments_and_extrapolate_coordinates() {
	for example in [
		['path("M 10 10 L 20 20 Z")', 'path("M 50 50 L 60 60 Z")', '-0.3', 'path("M -2 -2 L 8 8 Z")'],
		['path("m 50 60 h 20")', 'path("m 10 140 h 260")', '0.5', 'path("M 30 100 H 170")'],
		['path("M 5 5 A 10 20 0 0 0 15 -15")', 'path("M 15 15 A 20 30 0 0 0 5 -25")', '0.5', 'path("M 10 10 A 15 25 0 0 0 10 -20")'],
		['path("M 50 60 H 70")', 'path("M 10 140 H 270") margin-box', '0.5', 'path("M 30 100 H 170")'],
	] {
		a := parse_css_value_logic(.shape_outside, example[0]) or { panic('first shape') }
		b := parse_css_value_logic(.shape_outside, example[1]) or { panic('second shape') }
		expected := parse_css_value_logic(.shape_outside, example[3]) or { panic('expected shape') }
		value := interpolate_style_value(InterpolationCalculationContext.for_property(.shape_outside), a, b, example[2].f64(), .no) or { panic('path interpolation') }
		assert value.serialize(.normal) == expected.serialize(.normal)
	}
	a := parse_css_value_logic(.shape_outside, 'path("M 10 10 L 20 20")') or { panic('line') }
	b := parse_css_value_logic(.shape_outside, 'path("M 10 10 H 20")') or { panic('horizontal line') }
	assert interpolate_style_value(InterpolationCalculationContext.for_property(.shape_outside), a, b, 0.5, .no) == none
	c := parse_css_value_logic(.shape_outside, 'path("M 10 10 H 20") border-box') or { panic('border shape') }
	d := parse_css_value_logic(.shape_outside, 'path("M 20 20 H 40") padding-box') or { panic('padding shape') }
	assert interpolate_style_value(InterpolationCalculationContext.for_property(.shape_outside), c, d, 0.5, .no) == none
}
