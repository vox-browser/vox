module css

import math

// Legacy cross-fade keeps both image branches in its typed graph. Image-set
// nesting restrictions apply through every wrapper, including light-dark().
fn (mut parser Parser) parse_webkit_cross_fade_image(component ComponentValue, allow_image_set bool) ?StyleValue {
	arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(component.function().value)
	if arguments.len != 3 { return none }
	mut values := []StyleValue{}
	for argument in arguments[..2] {
		mut tokens := ComponentValueStream.new(argument)
		if none_value := parser.parse_all_as_single_keyword_value(mut tokens,.none_) {
			values << none_value
		} else {
			image := parser.parse_image_value_allowing_image_set(mut tokens,allow_image_set) or { return none }
			values << style_value_from_css_image_source_for_value_logic(image)
		}
		tokens.consume_whitespace()
		if tokens.has_more_tokens() { return none }
	}
	mut tokens := ComponentValueStream.new(arguments[2])
	mut number_tokens := tokens.clone()
	if number := parser.parse_number_value(mut number_tokens) {
		values << number
		tokens = number_tokens
	} else {
		values << parser.parse_percentage_value(mut tokens) or { return none }
	}
	tokens.consume_whitespace()
	if tokens.has_more_tokens() { return none }
	return StyleValue(FunctionStyleValue.create('-webkit-cross-fade',StyleValue(StyleValueList.create(values,.comma,.no))))
}

fn compute_webkit_cross_fade(value StyleValue, context ComputationContext) StyleValue {
	if value is StyleValueList && value.values_.len == 3 {
		weight := value.values_[2]
		raw := if weight is PercentageStyleValue { weight.percentage().as_fraction() }
			else if weight is NumberStyleValue { weight.number() }
			else if weight is CalculatedStyleValue {
				if percentage := weight.resolve_percentage(CalculationResolutionContext.from_computation_context(context,none)) { percentage.as_fraction() }
				else { weight.resolve_number(CalculationResolutionContext.from_computation_context(context,none)) or { 0.0 } }
			} else { 0.0 }
		return StyleValue(StyleValueList.create([value.values_[0],value.values_[1],StyleValue(NumberStyleValue.create(math.max(0,math.min(1,raw))))],.comma,.no))
	}
	return value
}
