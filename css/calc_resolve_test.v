module css

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

fn approx(a f64, b f64) bool {
	d := a - b
	return (if d < 0 { -d } else { d }) < 0.0001
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

fn test_resolve_stepped_functions() {
	empty := CalculationResolutionContext{}
	assert approx(resolved_px('abs(-5px)', empty)?, 5)
	assert approx(resolved_px('mod(5px, 3px)', empty)?, 2)
	assert approx(resolved_px('rem(5px, 3px)', empty)?, 2)
	assert approx(resolved_px('round(4.6px, 1px)', empty)?, 5)
	assert approx(resolved_px('round(down, 4.6px, 1px)', empty)?, 4)
	assert approx(resolved_px('round(up, 4.2px, 1px)', empty)?, 5)
	assert approx(resolved_px('round(to-zero, -4.6px, 1px)', empty)?, -4)
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
	assert approx(resolved_degrees('calc(45deg * 2)')?, 90)
}
