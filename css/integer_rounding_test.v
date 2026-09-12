module css

import math

fn integer_rounding_resolved_value(text string, property PropertyID) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	typed := typed_style_value_logic_from_dom(value) or { return none }
	return typed.serialize(.resolved_value)
}

fn test_css_integer_rounding_ties_toward_positive_infinity() {
	assert round_to_nearest_integer(2.5) == 3
	assert round_to_nearest_integer(-2.5) == -2
	assert round_to_nearest_integer(-2.51) == -3
	assert round_to_nearest_integer(-2.49) == -2
}

fn test_css_integer_rounding_censors_non_finite_values() {
	assert round_to_nearest_integer(math.nan()) == 0
	assert round_to_nearest_integer(math.inf(1)) == 2147483647
	assert round_to_nearest_integer(math.inf(-1)) == -2147483647 - 1
}

fn test_calculated_integers_clamp_to_signed_32_bit_range() {
	assert integer_rounding_resolved_value('calc(infinity)', PropertyID.z_index)? == '2147483647'
	assert integer_rounding_resolved_value('calc(-infinity)', PropertyID.z_index)? == '-2147483648'
	assert integer_rounding_resolved_value('calc(infinity)', PropertyID.column_count)? == '2147483647'
}

fn test_literal_integers_clamp_to_signed_32_bit_range_at_parse_time() {
	positive := parse_css_value_logic(.z_index, '999999999999999999999') or {
		panic('failed to parse positive integer')
	}
	negative := parse_css_value_logic(.z_index, '-999999999999999999999') or {
		panic('failed to parse negative integer')
	}
	assert positive is IntegerStyleValue
	assert negative is IntegerStyleValue
	assert positive.serialize(.normal) == '2147483647'
	assert negative.serialize(.normal) == '-2147483648'
	assert IntegerStyleValue.create(9999999999).integer() == 2147483647
	assert IntegerOrCalculated.from_integer(-9999999999).value() == -2147483648
}
