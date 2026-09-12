module css

fn test_length_or_auto_from_style_value_preserves_auto() {
	auto := StyleValue(KeywordStyleValue.create(.auto))
	assert LengthOrAuto.from_style_value_logic(auto, none).is_auto()

	dom_auto := dom_style_value_from_value_logic(auto)
	assert LengthOrAuto.from_style_value(dom_auto, none).is_auto()
}

fn test_length_or_auto_from_style_value_converts_lengths_and_percentages() {
	length := StyleValue(LengthStyleValue.create(Length.new(2.5, .em)))
	converted_length := LengthOrAuto.from_style_value_logic(length, none)
	assert converted_length.is_length()
	assert converted_length.length() or { Length.make_px(0) } == Length.new(2.5, .em)

	percentage := StyleValue(PercentageStyleValue.create(Percentage.new(25)))
	converted_percentage := LengthOrAuto.from_style_value_logic(percentage, Length.make_px(200))
	assert converted_percentage.is_length()
	assert converted_percentage.length() or { Length.make_px(0) } == Length.make_px(50)

	dom_percentage := dom_style_value_from_value_logic(percentage)
	dom_converted := LengthOrAuto.from_style_value(dom_percentage, Length.make_px(320))
	assert dom_converted.length() or { Length.make_px(0) } == Length.make_px(80)
}
