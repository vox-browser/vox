module layout

import css
import svg

fn test_svg_length_value_from_scalar_style_values() {
	number := css.StyleValue(css.NumberStyleValue.create(-2.5))
	assert svg_length_value_from_style_value(number)? == svg.SvgLengthValue.number(-2.5)

	percentage := css.StyleValue(css.PercentageStyleValue.create(css.Percentage.new(37.5)))
	assert svg_length_value_from_style_value(percentage)? == svg.SvgLengthValue.percentage(37.5)

	length := css.StyleValue(css.LengthStyleValue.create(css.Length.new(2, .em)))
	assert svg_length_value_from_style_value(length)? == svg.SvgLengthValue.length(2, .ems)

	quarter_millimetres := css.StyleValue(css.LengthStyleValue.create(css.Length.new(3, .q)))
	assert svg_length_value_from_style_value(quarter_millimetres)? == svg.SvgLengthValue.length(3, .q)
}

fn test_svg_length_value_rejects_non_scalar_style_values() {
	auto := css.StyleValue(css.KeywordStyleValue.create(.auto))
	assert svg_length_value_from_style_value(auto) == none
}
