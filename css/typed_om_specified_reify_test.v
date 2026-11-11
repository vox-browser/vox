module css

fn reified_math_sum_values(property string, text string) []CSSNumericValue {
	values := CSSStyleValue.parse_a_css_style_value(property, text, false) or { panic('${err}') }
	numeric := values[0].numeric_value_ or { panic('${property}: ${text} did not reify as a numeric value') }
	if numeric is CSSMathSum {
		return numeric.values().values()
	}
	panic('${property}: ${text} did not reify as a CSSMathSum')
}

fn test_specified_calculations_reify_as_math_sums() {
	// A calc() that simplifies to one value still reifies as a math expression.
	single := reified_math_sum_values('column-count', 'calc(2 + 3)')
	assert single.len == 1
	assert single[0] is CSSUnitValue
	assert (single[0] as CSSUnitValue).value() == 5
	assert reified_math_sum_values('bottom', 'calc(0% + 0%)').len == 1
	mixed := reified_math_sum_values('bottom', 'calc(0px + 0em)')
	assert mixed.len == 2
}

fn test_out_of_range_unit_values_store_their_wrapped_calculation() {
	property := PropertyNameAndID.from_name('column-count') or { panic('column-count') }
	value := MutableStylePropertyMapValue(CSSStyleValue.from_numeric(CSSNumericValue(CSSUnitValue.create(0, 'number'))))
	internal := create_an_internal_representation(property, value) or { panic('${err}') }
	assert serialized_text_for_internal_representation(value, internal) or { panic('${err}') } == 'calc(0)'
	in_range := MutableStylePropertyMapValue(CSSStyleValue.from_numeric(CSSNumericValue(CSSUnitValue.create(3, 'number'))))
	in_range_internal := create_an_internal_representation(property, in_range) or { panic('${err}') }
	assert serialized_text_for_internal_representation(in_range, in_range_internal) or { panic('${err}') } == '3'
	wrapped := reified_math_sum_values('column-count', 'calc(0)')
	assert wrapped.len == 1
}

fn typed_om_accepts(property string, value CSSStyleValue) bool {
	name := PropertyNameAndID.from_name(property) or { panic(property) }
	_ := value.create_an_internal_representation(name, .yes) or { return false }
	return true
}

fn test_keywords_and_numbers_follow_the_property_grammar() {
	for pair in [['font-style', 'italic'], ['font-variant-numeric', 'tabular-nums'], ['container-name', 'my-container'],
		['clip-path', 'border-box'], ['animation-timing-function', 'step-start']] {
		keyword := CSSKeywordValue.construct_impl(pair[1]) or { panic('${err}') }
		assert typed_om_accepts(pair[0], CSSStyleValue.from_keyword(keyword)), '${pair}'
	}
	bogus := CSSKeywordValue.construct_impl('bogus-keyword') or { panic('${err}') }
	assert !typed_om_accepts('font-style', CSSStyleValue.from_keyword(bogus))
	number := CSSStyleValue.from_numeric(CSSNumericValue(CSSUnitValue.create(3, 'number')))
	percent := CSSStyleValue.from_numeric(CSSNumericValue(CSSUnitValue.create(50, 'percent')))
	assert !typed_om_accepts('counter-increment', number)
	assert !typed_om_accepts('font-feature-settings', number)
	assert typed_om_accepts('opacity', number)
	assert typed_om_accepts('fill-opacity', percent)
	assert typed_om_accepts('column-count', number)
	assert !typed_om_accepts('shape-image-threshold', percent)
	opacity := PropertyNameAndID.from_name('opacity') or { panic('opacity') }
	negative := CSSUnitValue.create(-3.14, 'number').create_an_internal_representation(opacity, .yes) or { panic('${err}') }
	assert negative is NumberStyleValue
}

fn test_specified_opacity_percentages_stay_percentages() {
	values := CSSStyleValue.parse_a_css_style_value('opacity', '50%', false) or { panic('${err}') }
	numeric := values[0].numeric_value_ or { panic('opacity percentage did not reify') }
	assert numeric is CSSUnitValue
	assert (numeric as CSSUnitValue).unit() == 'percent'
}

fn test_uniform_box_side_shorthands_reify_as_their_value() {
	values := CSSStyleValue.parse_a_css_style_value('margin-block', '10px', false) or { panic('${err}') }
	numeric := values[0].numeric_value_ or { panic('margin-block did not reify as a length') }
	assert numeric is CSSUnitValue
	grid := CSSStyleValue.parse_a_css_style_value('grid-area', 'a', false) or { panic('${err}') }
	assert grid[0].keyword_value_ == none
	assert grid[0].numeric_value_ == none
}
