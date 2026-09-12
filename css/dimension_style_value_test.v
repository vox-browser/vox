module css

fn test_dimension_style_value_tokenize_preserves_percentage_token_kind() {
	percentage := DimensionStyleValue(PercentageStyleValue.create(Percentage.new(25)))
	percentage_tokens := percentage.tokenize()
	assert percentage_tokens.len == 1
	assert percentage_tokens[0].is(.percentage)
	assert percentage_tokens[0].token().percentage() == 25

	length := DimensionStyleValue(LengthStyleValue.create(Length.make_px(12)))
	length_tokens := length.tokenize()
	assert length_tokens.len == 1
	assert length_tokens[0].is(.dimension)
	assert length_tokens[0].token().dimension_value() == 12
	assert length_tokens[0].token().dimension_unit() == 'px'
}
