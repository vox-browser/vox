module css

fn calc_size_serialization(property PropertyID, text string) ?string {
	value := parse_css_value_logic(property, text) or { return none }
	return value.serialize(.normal)
}

fn test_calc_size_parses_keyword_bases_allowed_by_the_property() {
	assert calc_size_serialization(.width, 'calc-size(auto, size)')? == 'calc-size(auto, size)'
	assert calc_size_serialization(.min_height, 'calc-size(auto, size)')? == 'calc-size(auto, size)'
	assert calc_size_serialization(.max_width, 'calc-size(auto, size)') == none
	assert calc_size_serialization(.width, 'calc-size(none, size)') == none
	assert calc_size_serialization(.max_height, 'calc-size(max-content, size)')? == 'calc-size(max-content, size)'
	assert calc_size_serialization(.inline_size, 'calc-size(max-content, size)')? == 'calc-size(max-content, size)'
	assert calc_size_serialization(.width, 'calc-size(stretch, size)')? == 'calc-size(stretch, size)'
	assert calc_size_serialization(.flex_basis, 'calc-size(content, size)')? == 'calc-size(content, size)'
	assert calc_size_serialization(.width, 'calc-size(content, size)') == none
}

fn test_calc_size_serializes_its_arguments_as_bare_calculations() {
	assert calc_size_serialization(.height, 'calc-size(min-content, size * 2)')? == 'calc-size(min-content, 2 * size)'
	assert calc_size_serialization(.max_width, 'calc-size(max-content, size / 2)')? == 'calc-size(max-content, 0.5 * size)'
	assert calc_size_serialization(.width, 'calc-size(any, 25em)')? == 'calc-size(any, 25em)'
	assert calc_size_serialization(.width, 'calc-size(any, 50px + 30%)')? == 'calc-size(any, 30% + 50px)'
	assert calc_size_serialization(.width, 'calc-size(calc-size(any, 30px), size)')? == 'calc-size(calc-size(any, 30px), size)'
	assert calc_size_serialization(.width, 'calc-size(10px, sign(size) * size)') != none
	assert calc_size_serialization(.width, 'calc-size(0px, 0px)')? == 'calc-size(0px, 0px)'
}

fn test_calc_size_rejects_misplaced_size_keywords_and_functions() {
	for text in ['calc-size(any, size)', 'calc-size(any, fit-content)', 'size', 'sign(size)',
		'calc(50px * sign(size))', 'calc(calc-size(auto, size))', 'calc-size(30px)',
		'calc-size(any)', 'calc-size(size)', 'calc-size(any, calc-size(any, 10px))',
		'min(calc-size(auto, 0px), calc-size(auto, size))', 'calc-size(0, 0px)',
		'calc-size(0px, 0)'] {
		assert calc_size_serialization(.width, text) == none, text
	}
}

fn calc_size_value(text string) FunctionStyleValue {
	value := parse_css_value_logic(.width, text) or { panic(text) }
	return value as FunctionStyleValue
}

fn test_calc_size_acts_as_its_basis() {
	assert Size.from_style_value(StyleValue(calc_size_value('calc-size(auto, size)'))).is_auto()
	assert !Size.from_style_value(StyleValue(calc_size_value('calc-size(auto, size)'))).is_plain_auto()
	assert Size.from_style_value(StyleValue(calc_size_value('calc-size(min-content, size)'))).is_min_content()
	assert Size.from_style_value(StyleValue(calc_size_value('calc-size(calc-size(max-content, 30px), size)'))).is_max_content()
	assert Size.from_style_value(StyleValue(calc_size_value('calc-size(stretch, size / 2)'))).is_stretch()
	calculated := Size.from_style_value(StyleValue(calc_size_value('calc-size(83px, size * 3)')))
	assert calculated.is_calculated()
	assert calculated.calc_size() != none
	assert calculated.to_px(LengthResolutionContext{}, CSSPixels.new(500)).to_double() == 249
	percentage := Size.from_style_value(StyleValue(calc_size_value('calc-size(any, 31%)')))
	assert percentage.is_calculated()
	assert percentage.contains_percentage()
	assert percentage.to_px(LengthResolutionContext{}, CSSPixels.new(500)).to_double() == 155
	nested := Size.from_style_value(StyleValue(calc_size_value('calc-size(calc-size(any, 30px), size + 10px)')))
	assert nested.to_px(LengthResolutionContext{}, CSSPixels.new(500)).to_double() == 40
	assert Size.from_style_value(StyleValue(KeywordStyleValue.create(.auto))).is_plain_auto()
}

fn test_calc_size_resolves_keyword_bases_against_their_used_size() {
	context := LengthResolutionContext{}
	assert resolve_calc_size(calc_size_value('calc-size(min-content, size / 2)'), 500, 400, context)? == 200
	assert resolve_calc_size(calc_size_value('calc-size(fit-content, size / 4 + 30px)'), 500, 500, context)? == 155
	// Percentages resolve against the percentage basis, or against zero when it is indefinite.
	assert resolve_calc_size(calc_size_value('calc-size(stretch, size / 2 - 10%)'), 500, 500, context)? == 200
	assert resolve_calc_size(calc_size_value('calc-size(auto, size + 10%)'), none, 80, context)? == 80
	assert resolve_calc_size(calc_size_value('calc-size(calc-size(min-content, size), size)'), 500, 400, context)? == 400
	assert resolve_calc_size(calc_size_value('calc-size(any, 357px)'), 500, 999, context)? == 357
}

fn interpolated_calc_size(property PropertyID, from string, to string, delta f64, allow_keywords bool) ?string {
	a := parse_css_value_logic(property, from) or { return none }
	b := parse_css_value_logic(property, to) or { return none }
	result := combine_calc_size(property, a, b, allow_keywords, fn [delta] (x CalcNode, y CalcNode) CalcNode {
		return CalcNode(CalcSum{
			children: [CalcNode(CalcProduct{
				children: [x, calc_canonical_leaf(.number, 1 - delta)]
			}), CalcNode(CalcProduct{
				children: [y, calc_canonical_leaf(.number, delta)]
			})]
		})
	})?
	return result.serialize(.normal)
}

fn test_calc_size_interpolates_keywords_with_lengths_only_when_allowed() {
	assert interpolated_calc_size(.max_width, 'fit-content', '50px', 0.3, true)? == 'calc-size(fit-content, 15px + (0.7 * size))'
	assert interpolated_calc_size(.max_width, 'fit-content', '50px', 0, true)? == 'calc-size(fit-content, 0px + (1 * size))'
	assert interpolated_calc_size(.max_width, 'fit-content', '50px', 1.5, true)? == 'calc-size(fit-content, 75px + (-0.5 * size))'
	assert interpolated_calc_size(.height, 'auto', '50px', 0.25, false) == none
	// Two keywords never interpolate this way.
	assert interpolated_calc_size(.height, 'auto', 'auto', 0.25, true) == none
	assert interpolated_calc_size(.height, 'min-content', 'calc-size(any, 50px)', 0.5, false)? == 'calc-size(min-content, 25px + (0.5 * size))'
}

fn test_calc_size_interpolation_prepares_calculation_bases() {
	// A <calc-sum> basis without a percentage is substituted, leaving any.
	assert interpolated_calc_size(.height, 'calc-size(37px, 200px)', 'calc-size(37px, size * 2 + 3% + 17px)', 0.25, false)? == 'calc-size(any, 0.75% + 172.75px)'
	// A percentage basis becomes 100% after being de-percentified.
	assert interpolated_calc_size(.height, 'calc-size(50%, size)', 'calc-size(50px, size)', 0.25, false)? == 'calc-size(100%, 12.5px + (0.375 * size))'
	// Incompatible bases do not interpolate.
	assert interpolated_calc_size(.height, 'calc-size(calc-size(auto, size / 2), size * 2)', 'calc-size(12.5%, size * 4)', 0.25, false) == none
	assert interpolated_calc_size(.height, 'calc-size(auto, size)', 'calc-size(min-content, size)', 0.5, false) == none
}

fn test_calc_size_retains_the_calculation_it_acts_as() {
	value := parse_css_value_logic(.width, 'calc-size(calc-size(any, 30px), size + 10px)') or { panic('parse') }
	equivalent := calc_size_retained_equivalent(value) or { panic('equivalent') }
	assert (equivalent.resolve_length(CalculationResolutionContext{}) or { panic('resolve') }).absolute_length_to_px_without_rounding() == 40
	assert value.serialize(.normal) == 'calc-size(calc-size(any, 30px), 10px + size)'
	keyword := parse_css_value_logic(.width, 'calc-size(auto, size)') or { panic('parse') }
	list := (keyword as FunctionStyleValue).value() as StyleValueList
	assert list.values().len == 2
}

fn test_calc_size_interpolation_refuses_exponential_substitution() {
	mut nested := 'auto'
	for _ in 0 .. 20 {
		nested = 'calc-size(${nested}, size / 2 + size / 2)'
	}
	// https://github.com/w3c/csswg-drafts/issues/10369
	assert interpolated_calc_size(.height, nested, 'calc-size(auto, size * 3)', 0.5, false) == none
	mut shallow := 'auto'
	for _ in 0 .. 4 {
		shallow = 'calc-size(${shallow}, size / 2 + size / 2)'
	}
	assert interpolated_calc_size(.height, shallow, 'calc-size(auto, size * 3)', 0.5, false) != none
}

fn test_calc_size_interpolated_percentage_basis_acts_as_its_calculation() {
	a := parse_css_value_logic(.width, 'calc-size(50%, size)') or { panic('from') }
	b := parse_css_value_logic(.width, 'calc-size(60px, size)') or { panic('to') }
	for delta, expected in {0.0: 100.0, 0.5: 80.0, 1.0: 60.0} {
		result := combine_calc_size(.width, a, b, false, fn [delta] (x CalcNode, y CalcNode) CalcNode {
			return CalcNode(CalcSum{
				children: [CalcNode(CalcProduct{
					children: [x, calc_canonical_leaf(.number, 1 - delta)]
				}), CalcNode(CalcProduct{
					children: [y, calc_canonical_leaf(.number, delta)]
				})]
			})
		}) or { panic('combine') }
		size := Size.from_style_value(result)
		assert size.is_calculated()
		assert size.to_px(LengthResolutionContext{}, CSSPixels.new(200)).to_double() == expected, '${delta}'
	}
}
