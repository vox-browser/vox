module css

fn test_function_style_value_serializes_and_compares_name_and_value() {
	value := FunctionStyleValue.create('example', StyleValue(NumberStyleValue.create(2.5)))
	assert value.name() == 'example'
	assert value.value() == StyleValue(NumberStyleValue.create(2.5))
	assert value.serialize(.normal) == 'example(2.5)'
	assert value.properties_equal(FunctionStyleValue.create('example', StyleValue(NumberStyleValue.create(2.5))))
	assert !value.properties_equal(FunctionStyleValue.create('other', StyleValue(NumberStyleValue.create(2.5))))
}

fn test_function_style_value_delegates_absolutization_and_computational_independence() {
	font_size := CSSPixels.nearest_value_for(16)
	font_metrics := LengthFontMetrics.new(font_size, CSSPixels.nearest_value_for(8), CSSPixels.nearest_value_for(12), CSSPixels.nearest_value_for(8), CSSPixels.nearest_value_for(19.2))
	context := ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: font_metrics
			root_font_metrics: font_metrics
		}
	}
	relative := StyleValue(FunctionStyleValue.create('example', StyleValue(LengthStyleValue.create(Length.new(2, .em)))))
	absolutized := relative.absolutized(context)
	assert absolutized.serialize(.normal) == 'example(32px)'
	assert !relative.is_computationally_independent()

	absolute := StyleValue(FunctionStyleValue.create('example', StyleValue(LengthStyleValue.create(Length.make_px(2)))))
	assert absolute.is_computationally_independent()
}

fn test_function_style_value_interpolates_and_composites_its_argument() {
	from := StyleValue(FunctionStyleValue.create('example', StyleValue(NumberStyleValue.create(2))))
	to := StyleValue(FunctionStyleValue.create('example', StyleValue(NumberStyleValue.create(6))))
	context := InterpolationCalculationContext{
		property: .opacity
	}
	interpolated := interpolate_style_value(context, from, to, 0.25, .no) or {
		panic('function interpolation failed')
	}
	assert interpolated.serialize(.normal) == 'example(3)'

	composited := composite_style_value(.opacity, from, to, .add) or {
		panic('function composition failed')
	}
	assert composited.serialize(.normal) == 'example(8)'

	different_name := StyleValue(FunctionStyleValue.create('other', StyleValue(NumberStyleValue.create(6))))
	assert interpolate_style_value(context, from, different_name, 0.25, .no) == none
	assert composite_style_value(.opacity, from, different_name, .add) == none
}
