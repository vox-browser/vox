module css

fn test_integer_interpolation_rounds_between_its_endpoints() {
	context := InterpolationCalculationContext{}
	result := interpolate_style_value_impl(context, StyleValue(IntegerStyleValue.create(10)),
		StyleValue(IntegerStyleValue.create(20)), 0.5, .no) or { panic('not interpolated') }
	assert result.serialize(.normal) == '15'
}

fn test_integer_interpolation_extrapolates_and_honors_accepted_ranges() {
	mut context := InterpolationCalculationContext{}
	below := interpolate_style_value_impl(context, StyleValue(IntegerStyleValue.create(-2)),
		StyleValue(IntegerStyleValue.create(5)), -0.3, .no) or { panic('not interpolated') }
	assert below.serialize(.normal) == '-4'
	context.accepted_type_ranges[.integer] = AcceptedTypeRange{
		min: 1
		max: 100
	}
	clamped := interpolate_style_value_impl(context, StyleValue(IntegerStyleValue.create(10)),
		StyleValue(IntegerStyleValue.create(20)), -3, .no) or { panic('not interpolated') }
	assert clamped.serialize(.normal) == '1'
}
