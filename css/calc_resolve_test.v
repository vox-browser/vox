module css

import dom
import math

// Validates computed/used-value resolution of calc() trees: each supported math function
// and operator is evaluated against a CalculationResolutionContext and checked for the
// correct numeric result (in canonical units: px for lengths, degrees for angles).
fn parse_calc_style_value(text string) ?CalculatedStyleValue {
	mut parser := Parser.from_css_text(text)
	mut tokens := ComponentValueStream.new(parser.component_values)
	value := parse_calculated_value(mut tokens) or { return none }
	if value is CalculatedStyleValue {
		return value
	}
	return none
}

fn resolved_px(text string, context CalculationResolutionContext) ?f64 {
	calc := parse_calc_style_value(text) or { return none }
	length := calc.resolve_length(context) or { return none }
	return length.absolute_length_to_px_without_rounding()
}

fn resolved_number(text string) ?f64 {
	calc := parse_calc_style_value(text) or { return none }
	return calc.resolve_number(CalculationResolutionContext{})
}

fn resolved_degrees(text string) ?f64 {
	calc := parse_calc_style_value(text) or { return none }
	angle := calc.resolve_angle(CalculationResolutionContext{}) or { return none }
	return angle.to_degrees()
}

fn test_anchor_functions_are_typed_length_leaves_in_calculations() {
	parsed := parse_css_value_logic(.top, 'calc(anchor(--card bottom) + 10px)') or {
		panic('anchor() did not parse in calc()')
	}
	assert parsed is CalculatedStyleValue
	calculated := parsed as CalculatedStyleValue
	assert calculated.serialize(.normal) == 'calc(10px + anchor(--card bottom))'
	assert calculated.numeric_type()?.matches_length(.length)
	assert calculated.resolve_length(CalculationResolutionContext{}) == none
	assert parse_css_value_logic(.width, 'calc(anchor(--card bottom) + 10px)') == none
}

fn approx(a f64, b f64) bool {
	d := a - b
	return (if d < 0 {
		-d
	} else {
		d
	}) < 0.0001
}

fn test_resolve_arithmetic() {
	empty := CalculationResolutionContext{}
	assert approx(resolved_px('calc(1px + 2px)', empty)?, 3)
	assert approx(resolved_px('calc(10px - 4px)', empty)?, 6)
	assert approx(resolved_px('calc(2 * 3px)', empty)?, 6)
	assert approx(resolved_px('calc(12px / 4)', empty)?, 3)
	assert approx(resolved_px('calc((1px + 2px) * 3)', empty)?, 9)
}

fn test_resolve_comparison_functions() {
	empty := CalculationResolutionContext{}
	assert approx(resolved_px('min(10px, 20px)', empty)?, 10)
	assert approx(resolved_px('max(10px, 20px)', empty)?, 20)
	// clamp(min, central, max): 50 clamped to [5, 10] -> 10.
	assert approx(resolved_px('clamp(5px, 50px, 10px)', empty)?, 10)
	assert approx(resolved_px('clamp(5px, 2px, 10px)', empty)?, 5)
	assert approx(resolved_px('hypot(3px, 4px)', empty)?, 5)
}

fn test_comparison_functions_propagate_nan_before_top_level_censoring() {
	// Keep the NaN behind a relative unit so parse-time simplification cannot fold the
	// whole function. This exercises the computed/used-value resolver directly.
	for text in ['min(1em, NaN * 1em)', 'max(1em, NaN * 1em)'] {
		calculated := parse_calc_style_value(text)?
		result := resolve_calc_node(calculated.node[0], calculated.calculation_context, CalculationResolutionContext{})?
		assert math.is_nan(result.value)
		// The public top-level result follows CSS Values and censors NaN to zero.
		assert approx(calculated.resolve_length(CalculationResolutionContext{})?.absolute_length_to_px_without_rounding(), 0)
	}
}

fn test_resolve_stepped_functions() {
	empty := CalculationResolutionContext{}
	assert approx(resolved_px('abs(-5px)', empty)?, 5)
	assert approx(resolved_px('mod(5px, 3px)', empty)?, 2)
	assert approx(resolved_px('rem(5px, 3px)', empty)?, 2)
	assert approx(resolved_px('round(4.6px, 1px)', empty)?, 5)
	assert approx(resolved_px('round(down, 4.6px, 1px)', empty)?, 4)
	assert approx(resolved_px('round(up, 4.2px, 1px)', empty)?, 5)
	assert approx(resolved_px('round(to-zero, -4.6px, 1px)', empty)?, -4)
	// mod()'s parameter-validation rule is `same`, not `consistent`: a percentage argument
	// does not unify with a length one, so the function is rejected while parsing.
	assert parse_calc_style_value('mod(10px, 3%)') == none
	assert parse_calc_style_value('rem(10px, 3%)') == none
	// Arguments that share a type are still accepted when they are not canonical.
	assert parse_calc_style_value('mod(5em, 3em)') != none
	assert parse_calc_style_value('rem(10%, 3%)') != none
}

fn test_random_function_parsing_and_fixed_evaluation() {
	// The generated C++ parser only enables random() while parsing a property.
	assert parse_calc_style_value('random(0px, 10px)') == none

	value := parse_css_value_logic(.width, 'random(fixed 0.25, 10px, 50px)')?
	assert value is CalculatedStyleValue
	calculated := value as CalculatedStyleValue
	assert calculated.serialize(.normal) == 'random(fixed 0.25, 10px, 50px)'
	assert approx(calculated.resolve_length(CalculationResolutionContext{})?.absolute_length_to_px_without_rounding(), 20)

	stepped_value := parse_css_value_logic(.order, 'random(fixed 0.75, 0, 10, 3)')?
	assert stepped_value is CalculatedStyleValue
	assert approx((stepped_value as CalculatedStyleValue).resolve_number(CalculationResolutionContext{})?, 9)
}

fn test_random_function_value_sharing_and_validation() {
	auto_value := parse_css_value_logic(.width, 'random(0px, 10px)')?
	assert auto_value is CalculatedStyleValue
	auto_calculated := auto_value as CalculatedStyleValue
	assert auto_calculated.serialize(.normal) == 'random(0px, 10px)'
	assert auto_calculated.node.len == 1
	auto_node := auto_calculated.node[0]
	assert auto_node is CalcRandom
	assert (auto_node as CalcRandom).sharing.name()? == 'width 1'

	named_value := parse_css_value_logic(.width, 'random(element-shared --sample, 0px, 10px)')?
	assert named_value is CalculatedStyleValue
	assert (named_value as CalculatedStyleValue).serialize(.normal) == 'random(--sample element-shared, 0px, 10px)'

	assert parse_css_value_logic(.width, 'random(fixed 1, 0px, 10px)') == none
	assert parse_css_value_logic(.width, 'random(auto --sample, 0px, 10px)') == none
	assert parse_css_value_logic(.width, 'random(0px, 10deg)') == none
}

fn test_random_function_absolutization_reuses_the_upstream_cache_key() {
	document := dom.Document.create(dom.url_about_blank())
	first_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	second_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}

	first_value := parse_css_value_logic(.width, 'random(0px, 100px)')?
	second_value := parse_css_value_logic(.width, 'random(0px, 100px)')?
	first_computed := first_value.absolutized(ComputationContext{
		abstract_element: dom.AbstractElement.new(first_element, none)
	})
	second_computed := second_value.absolutized(ComputationContext{
		abstract_element: dom.AbstractElement.new(first_element, none)
	})
	assert first_computed.serialize(.normal) == second_computed.serialize(.normal)

	first_shared := parse_css_value_logic(.width, 'random(--document-value element-shared, 0px, 100px)')?
	second_shared := parse_css_value_logic(.width, 'random(--document-value element-shared, 0px, 100px)')?
	first_shared_computed := first_shared.absolutized(ComputationContext{
		abstract_element: dom.AbstractElement.new(first_element, none)
	})
	second_shared_computed := second_shared.absolutized(ComputationContext{
		abstract_element: dom.AbstractElement.new(second_element, none)
	})
	assert first_shared_computed.serialize(.normal) == second_shared_computed.serialize(.normal)
}

fn test_resolve_percentage_against_basis() {
	// calc(100% - 10px) with a 200px basis resolves to 190px.
	basis := CalculationResolutionContext{
		percentage_basis: CalculationPercentageBasis(Length.make_px(200))
	}
	assert approx(resolved_px('calc(100% - 10px)', basis)?, 190)
	assert approx(resolved_px('calc(50% + 20px)', basis)?, 120)
	// Without a basis the mixed calc cannot resolve to a length.
	assert resolved_px('calc(100% - 10px)', CalculationResolutionContext{}) == none
}

fn test_percentage_from_literal_and_calculated_style_values() {
	literal := StyleValue(PercentageStyleValue.create(Percentage.new(25)))
	assert Percentage.from_style_value_logic(literal).value() == 25

	calculated := parse_calc_style_value('calc(50% / 2)') or {
		panic('percentage calculation did not parse')
	}
	assert Percentage.from_style_value_logic(StyleValue(calculated)).value() == 25
}

fn test_absolutized_uses_computation_context_and_preserves_typed_tree() {
	value := parse_calc_style_value('calc(1em + 2px)')?
	font_size := CSSPixels.new(20)
	computed := value.absolutized(ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: LengthFontMetrics.new(font_size, CSSPixels.new(10), CSSPixels.new(14), CSSPixels.new(10), CSSPixels.new(24))
			root_font_metrics: LengthFontMetrics.default()
		}
	})
	assert computed is CalculatedStyleValue
	assert computed.serialize(.normal) == 'calc(22px)'
	assert (computed as CalculatedStyleValue).node.len == 1

	mixed_zero := parse_calc_style_value('calc(25% + 0em)')?
	absolutized_mixed := mixed_zero.absolutized(ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: LengthFontMetrics.new(font_size, CSSPixels.new(10), CSSPixels.new(14), CSSPixels.new(10), CSSPixels.new(24))
			root_font_metrics: LengthFontMetrics.default()
		}
	})
	assert absolutized_mixed is PercentageStyleValue
	assert absolutized_mixed.serialize(.normal) == '25%'

	grid_value := parse_css_value_logic(.grid_template_columns, 'calc(1em + 2px)')?
	assert grid_value is GridTrackSizeListStyleValue
	absolutized_grid := StyleValue(grid_value.absolutized(ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: LengthFontMetrics.new(font_size, CSSPixels.new(10), CSSPixels.new(14), CSSPixels.new(10), CSSPixels.new(24))
			root_font_metrics: LengthFontMetrics.default()
		}
	}))
	assert absolutized_grid is GridTrackSizeListStyleValue
	assert absolutized_grid.serialize(.normal) == 'calc(22px)'
}

fn test_grid_repeat_accepts_and_absolutizes_calculated_integer_counts() {
	value := parse_css_value_logic(.grid_template_columns, 'repeat(calc(1 + 3 * sign(100em - 1px)), 150px)') or {
		panic('calculated repeat count did not parse')
	}
	assert value is GridTrackSizeListStyleValue
	assert value.serialize(.normal).starts_with('repeat(calc(')
	font_size := CSSPixels.new(16)
	computed := value.absolutized(ComputationContext{
		length_resolution_context: LengthResolutionContext{
			font_metrics: LengthFontMetrics.new(font_size, CSSPixels.new(8), CSSPixels.new(12), CSSPixels.new(8), CSSPixels.new(19))
			root_font_metrics: LengthFontMetrics.default()
		}
	})
	assert computed.serialize(.normal) == 'repeat(calc(4), 150px)'
	computed_list := (computed as GridTrackSizeListStyleValue).grid_track_size_list()
	assert computed_list.track_list()[0].repeat().repeat_count() == 4
}

fn test_grid_tracks_accept_calculated_flex_values() {
	value := parse_css_value_logic(.grid_template_columns, 'calc(1fr) calc(2 * 1fr)') or {
		panic('calculated flex tracks did not parse')
	}
	assert value is GridTrackSizeListStyleValue
	assert value.serialize(.normal) == 'calc(1fr) calc(2fr)'
	tracks := (value as GridTrackSizeListStyleValue).grid_track_size_list().track_list()
	assert tracks.len == 2
	assert tracks[0].grid_size().is_flexible_length()
	assert tracks[0].grid_size().flex_factor() == 1
	assert tracks[1].grid_size().flex_factor() == 2
	assert parse_css_value_logic(.grid_template_columns, 'calc(-1fr)') == none
}

fn test_resolve_numbers() {
	assert approx(resolved_number('calc(1 + 2)')?, 3)
	assert approx(resolved_number('sqrt(16)')?, 4)
	assert approx(resolved_number('pow(2, 3)')?, 8)
	assert approx(resolved_number('exp(0)')?, 1)
	assert approx(resolved_number('log(8, 2)')?, 3)
	assert approx(resolved_number('sign(-3px)')?, -1)
	assert approx(resolved_number('sign(4px)')?, 1)
	assert approx(resolved_number('min(3, 7, 1)')?, 1)
}

fn test_property_calculation_context_and_top_level_range_clamping() {
	opacity := parse_css_value_logic(.opacity, 'calc(2)')?
	assert opacity is CalculatedStyleValue
	opacity_calc := opacity as CalculatedStyleValue
	number_range := opacity_calc.calculation_context.accepted_type_ranges[.number] or {
		panic('opacity calculation context is missing its number range')
	}
	assert number_range.min == 0
	assert number_range.max == 1
	assert approx(opacity_calc.resolve_number(CalculationResolutionContext{})?, 1)

	font_weight := parse_css_value_logic(.font_weight, 'calc(-50)')?
	assert font_weight is CalculatedStyleValue
	assert approx((font_weight as CalculatedStyleValue).resolve_number(CalculationResolutionContext{})?, 1)

	column_count := parse_css_value_logic(.column_count, 'calc(0)')?
	assert column_count is CalculatedStyleValue
	column_calc := column_count as CalculatedStyleValue
	assert column_calc.calculation_context.resolve_numbers_as_integers
	assert column_calc.resolve_integer(CalculationResolutionContext{})? == 1

	width := parse_css_value_logic(.width, 'calc(50%)')?
	assert width is CalculatedStyleValue
	width_calc := width as CalculatedStyleValue
	assert width_calc.calculation_context.percentages_resolve_as? == .length
	width_type := width_calc.numeric_type()?
	assert width_type.matches_length(.length)
	assert width_type.percent_hint? == .length
	// Without a percentage basis this dimension-associated percentage remains
	// unresolved; with a basis it resolves in the canonical length unit.
	assert width_calc.resolve_length(CalculationResolutionContext{}) == none
	assert approx(width_calc.resolve_length(CalculationResolutionContext{
		percentage_basis: CalculationPercentageBasis(Length.make_px(200))
	})?.absolute_length_to_px_without_rounding(), 100)
}

fn test_value_parsing_context_stack_controls_nested_calculations() {
	// Function contexts override the outer property context. Filter amounts use
	// the same ranges as C++, so a calculated opacity is clamped at one.
	filter_value := parse_css_value_logic(.filter, 'opacity(calc(2))') or {
		panic('calculated filter amount did not parse')
	}
	assert filter_value is FilterValueListStyleValue
	operations := (filter_value as FilterValueListStyleValue).filter_value_list()
	assert operations.len == 1
	assert operations[0] is FilterOperationColor
	amount := (operations[0] as FilterOperationColor).amount
	assert amount is CalculatedStyleValue
	amount_calc := amount as CalculatedStyleValue
	amount_range := amount_calc.calculation_context.accepted_type_ranges[.number] or {
		panic('filter function calculation range was not inherited from its function context')
	}
	assert amount_range.min == 0
	assert amount_range.max == 1
	assert approx(amount_calc.resolve_number(CalculationResolutionContext{})?, 1)

	// C++ permits calculated cubic-bezier coordinates and attaches the [0, 1]
	// X-coordinate range instead of rejecting non-literal coordinates.
	mut easing_parser := Parser.from_css_text('cubic-bezier(calc(2), 0, calc(-1), 1)')
	mut easing_tokens := ComponentValueStream.new(easing_parser.component_values)
	easing_value := easing_parser.parse_easing_value(mut easing_tokens) or {
		panic('calculated cubic-bezier coordinates did not parse')
	}
	assert easing_value is EasingStyleValue
	bezier := (easing_value as EasingStyleValue).function()
	assert bezier is EasingCubicBezier
	x1 := bezier.x1
	x2 := bezier.x2
	assert x1 is CalculatedStyleValue
	assert x2 is CalculatedStyleValue
	x1_range := (x1 as CalculatedStyleValue).calculation_context.accepted_type_ranges[.number] or {
		panic('first cubic-bezier X coordinate has no calculation range')
	}
	x2_range := (x2 as CalculatedStyleValue).calculation_context.accepted_type_ranges[.number] or {
		panic('second cubic-bezier X coordinate has no calculation range')
	}
	assert x1_range.max == 1
	assert x2_range.min == 0

	// An angular color-stop percentage inside calc() resolves as an angle only
	// because AngularColorStopList is the nearest active special context.
	assert parse_css_value_logic(.background_image, 'conic-gradient(red calc(25%), blue)') != none
}

fn test_resolve_trig_and_constants() {
	assert approx(resolved_number('sin(90deg)')?, 1)
	assert approx(resolved_number('cos(0)')?, 1)
	// sin() of a bare number interprets it as radians.
	assert approx(resolved_number('sin(0)')?, 0)
	assert approx(resolved_number('calc(pi)')?, 3.141592653589793)
	assert approx(resolved_number('calc(e)')?, 2.718281828459045)
	// Inverse trig returns degrees.
	assert approx(resolved_degrees('asin(1)')?, 90)
	assert approx(resolved_degrees('atan2(1, 1)')?, 45)
	assert approx(resolved_degrees('atan2(-0, -1)')?, 180)
	assert approx(resolved_degrees('calc(45deg * 2)')?, 90)
}

fn test_sign_and_round_preserve_negative_zero_like_upstream() {
	assert math.signbit(resolved_number('sign(-0)')?)
	assert !math.signbit(resolved_number('sign(0)')?)
	assert math.signbit(resolved_number('round(-0, infinity)')?)
	assert !math.signbit(resolved_number('round(0, infinity)')?)
}

fn test_compute_opacity_uses_the_retained_typed_value() {
	for input, expected in {
		'2':         1.0
		'-1':        0.0
		'25%':       0.25
		'calc(2)':   1.0
		'calc(25%)': 0.25
	} {
		parsed := parse_css_value(ParsingParams{}, input, .opacity) or { panic('parse ${input}') }
		computed := StyleComputer.compute_opacity(parsed)
		typed := typed_style_value_logic_from_dom(computed) or { panic('lost typed ${input}') }
		assert typed is NumberStyleValue
		assert approx((typed as NumberStyleValue).number(), expected)
	}
}
