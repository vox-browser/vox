module css

fn ratio_computation_context(font_size f64, root_font_size f64) ComputationContext {
	return ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: LengthFontMetrics.new(CSSPixels.nearest_value_for(font_size), CSSPixels.nearest_value_for(font_size / 2), CSSPixels.nearest_value_for(font_size * 0.7), CSSPixels.nearest_value_for(font_size / 2), CSSPixels.nearest_value_for(font_size * 1.2))
			root_font_metrics: LengthFontMetrics.new(CSSPixels.nearest_value_for(root_font_size), CSSPixels.nearest_value_for(root_font_size / 2), CSSPixels.nearest_value_for(root_font_size * 0.7), CSSPixels.nearest_value_for(root_font_size / 2), CSSPixels.nearest_value_for(root_font_size * 1.2))
		}
	}
}

fn test_ratio_preserves_calculated_components_until_absolutization() {
	parsed := parse_css_value_logic(.aspect_ratio, 'calc(6em / 1px) / calc(3rem / 1px)') or {
		panic('calculated ratio did not parse')
	}
	assert parsed is RatioStyleValue
	specified := parsed as RatioStyleValue
	assert specified.numerator() is CalculatedStyleValue
	assert specified.denominator() is CalculatedStyleValue
	assert specified.serialize(.normal) == 'calc(6em / 1px) / calc(3rem / 1px)'

	computed_value := specified.absolutized(ratio_computation_context(16, 16))
	assert computed_value is RatioStyleValue
	computed := computed_value as RatioStyleValue
	assert computed.serialize(.normal) == '96 / 48'
	assert computed.resolved() == Ratio.new(96, 48)
}

fn test_ratio_calculated_components_use_non_negative_range() {
	parsed := parse_css_value_logic(.aspect_ratio, 'calc(-1) / 1') or {
		panic('clamped calculated ratio did not parse')
	}
	assert parsed is RatioStyleValue
	computed := (parsed as RatioStyleValue).absolutized(ComputationContext{})
	assert computed is RatioStyleValue
	assert (computed as RatioStyleValue).resolved().numerator() == 0
}

fn test_ratio_absolutization_preserves_already_absolute_value() {
	ratio := RatioStyleValue.create(Ratio.new(16, 9))
	computed := ratio.absolutized(ComputationContext{})
	assert computed == StyleValue(ratio)
	assert ratio.tokenize().len == 5
}

fn test_media_ratio_resolution_uses_its_length_context() {
	mut parser := Parser.from_css_text('calc(6em / 1px) / calc(3rem / 1px)')
	mut tokens := ComponentValueStream.new(parser.component_values)
	parsed := parser.parse_media_feature_value('aspect-ratio', mut tokens) or {
		panic('calculated media ratio did not parse')
	}
	feature_value := media_feature_value_from_style_value('aspect-ratio', parsed)
	context := ratio_computation_context(20, 10).length_resolution_context
	assert query_feature_numeric_value(feature_value, context)? == 4
}
