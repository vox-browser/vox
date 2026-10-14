module css

fn test_length_wrapper_defaults_are_zero_length_or_absent_auto_values() {
	zero := LengthPercentage{}
	assert zero.is_length()
	assert zero.to_px(LengthResolutionContext.default(), CSSPixels.new(100)) == CSSPixels.new(0)
	assert zero.serialize(.normal) == '0px'
	auto := LengthPercentageOrAuto{}
	assert auto.is_auto()
	assert auto.length_percentage_ == none
	size := Size{}
	assert size.is_auto()
	assert size.length_percentage_ == none
}

fn test_length_wrapper_conversion_retains_explicit_length_percentage_and_calculation() {
	for input, expected in {
		'12px':            f64(12)
		'20%':             f64(20)
		'calc(10px + 5%)': f64(15)
	} {
		parsed := parse_css_value_logic(.width, input) or { panic('could not parse ${input}') }
		value := LengthPercentage.from_style_value_logic(parsed)
		assert value.to_px(LengthResolutionContext.default(), CSSPixels.new(100)).to_double() == expected
	}
}

fn test_absent_optional_lengths_stay_auto_in_default_boxes_and_arrays() {
	context := LengthResolutionContext.default()
	box := LengthBox{}
	for value in [LengthPercentageOrAuto{}, LengthPercentageOrAuto.make_auto(),
		box.top(), box.right(), box.bottom(), box.left()] {
		assert value.is_auto()
		assert !value.is_length()
		assert !value.is_percentage()
		assert !value.is_calculated()
		assert !value.contains_percentage()
		assert value.serialize(.normal) == 'auto'
		assert value.resolved_or_auto(context, CSSPixels.new(300)).is_auto()
		assert value.to_px_or_zero(context, CSSPixels.new(300)).raw_value() == 0
	}
	values := []LengthPercentageOrAuto{len: 8}
	for value in values {
		assert value.is_auto()
	}
}

fn test_optional_length_reset_keeps_retained_values_alive_and_defaults_independent() {
	mut values := []LengthPercentageOrAuto{len: 4}
	values[0] = LengthPercentageOrAuto.from_length(Length.make_px(12))
	values[1] = LengthPercentageOrAuto.from_percentage(Percentage.new(25))
	calculated := parse_css_value_logic(.width, 'calc(5px + 10%)') or {
		panic('missing calculation')
	}
	values[2] = LengthPercentageOrAuto.from_style_value_logic(calculated)
	box := LengthBox{
		left_: values[0]
	}
	percentage := values[1]
	calculation := values[2]
	assert box.top().is_auto() && box.right().is_auto() && box.bottom().is_auto()
	assert values[3].is_auto()
	values[0].length_percentage_ = none
	values[1] = LengthPercentageOrAuto.make_auto()
	values[2] = LengthPercentageOrAuto{}
	gc_collect()
	for value in values {
		assert value.is_auto()
	}
	context := LengthResolutionContext.default()
	reference := CSSPixels.new(200)
	assert box.left().to_px_or_zero(context, reference).to_double() == 12
	assert percentage.is_percentage()
	assert percentage.to_px_or_zero(context, reference).to_double() == 50
	assert calculation.is_calculated()
	assert calculation.to_px_or_zero(context, reference).to_double() == 25
}

fn test_optional_length_dom_and_typed_conversions_keep_auto_and_explicit_values() {
	context := LengthResolutionContext.default()
	for input, expected in {
		'auto':            f64(0)
		'12px':            f64(12)
		'25%':             f64(50)
		'calc(5px + 10%)': f64(25)
	} {
		parsed := parse_css_value_logic(.width, input) or { panic('could not parse ${input}') }
		typed_value := LengthPercentageOrAuto.from_style_value_logic(parsed)
		dom_value :=
			LengthPercentageOrAuto.from_style_value(dom_style_value_from_value_logic(parsed))
		assert typed_value.is_auto() == (input == 'auto')
		assert dom_value.is_auto() == typed_value.is_auto()
		assert typed_value.to_px_or_zero(context, CSSPixels.new(200)).to_double() == expected
		assert dom_value.to_px_or_zero(context, CSSPixels.new(200)).to_double() == expected
	}
}
