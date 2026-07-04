module css

import math

// Computed/used-value resolution of a calc() tree, ported from the C++
// simplify_a_calculation_tree + CalculationResult evaluation. Given a
// CalculationResolutionContext (length-resolution context for relative units, and an
// optional percentage basis), resolve_calc_node evaluates the tree to a single value
// expressed in the result's canonical unit (px for lengths, degrees for angles, seconds
// for times, hertz for frequencies, dppx for resolutions, fr for flexes, raw for numbers
// and percentages), together with the resulting NumericType.

// A resolved value: a number in the canonical unit of `type_`.
struct CalcResult {
	value f64
	type_ NumericType
}

fn resolve_calc_node(node CalcNode, ctx CalculationResolutionContext) ?CalcResult {
	match node {
		CalcNumeric {
			return resolve_calc_leaf(node, ctx)
		}
		CalcSum {
			mut accumulated := resolve_calc_node(node.children[0], ctx) or { return none }
			for index := 1; index < node.children.len; index++ {
				addend := resolve_calc_node(node.children[index], ctx) or { return none }
				accumulated = calc_result_add(accumulated, addend) or { return none }
			}
			return accumulated
		}
		CalcProduct {
			mut accumulated := resolve_calc_node(node.children[0], ctx) or { return none }
			for index := 1; index < node.children.len; index++ {
				factor := resolve_calc_node(node.children[index], ctx) or { return none }
				accumulated = calc_result_multiply(accumulated, factor) or { return none }
			}
			return accumulated
		}
		CalcNegate {
			child := resolve_calc_node(node.children[0], ctx) or { return none }
			return CalcResult{
				value: -child.value
				type_: child.type_
			}
		}
		CalcInvert {
			child := resolve_calc_node(node.children[0], ctx) or { return none }
			return CalcResult{
				value: 1.0 / child.value
				type_: child.type_.inverted()
			}
		}
		CalcFunction {
			return resolve_calc_function(node, ctx)
		}
	}
	return none
}

// A key identifying a type's canonical unit, if it is a single resolvable unit (or a
// number/percentage). Two values may only be added when their keys match.
fn calc_canonical_key(numeric_type NumericType) ?string {
	if numeric_type.matches_number(none) {
		return 'number'
	}
	if numeric_type.matches_percentage() {
		return 'percent'
	}
	if numeric_type.matches_length(ValueType.length) {
		return 'length'
	}
	if numeric_type.matches_angle(ValueType.angle) {
		return 'angle'
	}
	if numeric_type.matches_time(ValueType.time) {
		return 'time'
	}
	if numeric_type.matches_frequency(ValueType.frequency) {
		return 'frequency'
	}
	if numeric_type.matches_resolution(ValueType.resolution) {
		return 'resolution'
	}
	if numeric_type.matches_flex(ValueType.flex) {
		return 'flex'
	}
	return none
}

fn calc_result_add(a CalcResult, b CalcResult) ?CalcResult {
	// Values can only be added when they resolve to the same canonical unit.
	key_a := calc_canonical_key(a.type_) or { return none }
	key_b := calc_canonical_key(b.type_) or { return none }
	if key_a != key_b {
		return none
	}
	new_type := a.type_.added_to(b.type_) or { return none }
	return CalcResult{
		value: a.value + b.value
		type_: new_type
	}
}

fn calc_result_multiply(a CalcResult, b CalcResult) ?CalcResult {
	new_type := a.type_.multiplied_by(b.type_) or { return none }
	return CalcResult{
		value: a.value * b.value
		type_: new_type
	}
}

fn resolve_calc_leaf(leaf CalcNumeric, ctx CalculationResolutionContext) ?CalcResult {
	match leaf.kind {
		.number {
			return CalcResult{
				value: leaf.value
				type_: leaf.type_
			}
		}
		.percentage {
			// Resolve against the basis if one is available; otherwise stay a raw percentage.
			if resolved := resolve_calc_percentage_against_basis(leaf.value, ctx) {
				return resolved
			}
			return CalcResult{
				value: leaf.value
				type_: leaf.type_
			}
		}
		.length {
			unit := string_to_length_unit(leaf.unit) or { return none }
			length := Length.new(leaf.value, unit)
			pixels := if length.is_absolute() {
				length.absolute_length_to_px_without_rounding()
			} else {
				length.to_px_without_rounding(ctx.length_resolution_context)
			}
			return CalcResult{
				value: pixels
				type_: leaf.type_
			}
		}
		.angle {
			unit := string_to_angle_unit(leaf.unit) or { return none }
			return CalcResult{
				value: Angle.new(leaf.value, unit).to_degrees()
				type_: leaf.type_
			}
		}
		.time {
			unit := string_to_time_unit(leaf.unit) or { return none }
			return CalcResult{
				value: Time.new(leaf.value, unit).to_seconds()
				type_: leaf.type_
			}
		}
		.frequency {
			unit := string_to_frequency_unit(leaf.unit) or { return none }
			return CalcResult{
				value: Frequency.new(leaf.value, unit).to_hertz()
				type_: leaf.type_
			}
		}
		.resolution {
			unit := string_to_resolution_unit(leaf.unit) or { return none }
			return CalcResult{
				value: Resolution.new(leaf.value, unit).to_dots_per_pixel()
				type_: leaf.type_
			}
		}
		.flex {
			unit := string_to_flex_unit(leaf.unit) or { return none }
			return CalcResult{
				value: Flex.new(leaf.value, unit).to_fr()
				type_: leaf.type_
			}
		}
	}
}

fn resolve_calc_percentage_against_basis(value f64, ctx CalculationResolutionContext) ?CalcResult {
	if basis := ctx.percentage_basis_length() {
		return CalcResult{
			value: basis.percentage_of(Percentage.new(value)).to_px_without_rounding(ctx.length_resolution_context)
			type_: NumericType.with_type(.length, 1)
		}
	}
	if basis := ctx.percentage_basis_angle() {
		return CalcResult{
			value: basis.percentage_of(Percentage.new(value)).to_degrees()
			type_: NumericType.with_type(.angle, 1)
		}
	}
	if basis := ctx.percentage_basis_time() {
		return CalcResult{
			value: basis.percentage_of(Percentage.new(value)).to_seconds()
			type_: NumericType.with_type(.time, 1)
		}
	}
	if basis := ctx.percentage_basis_frequency() {
		return CalcResult{
			value: basis.percentage_of(Percentage.new(value)).to_hertz()
			type_: NumericType.with_type(.frequency, 1)
		}
	}
	if basis := ctx.percentage_basis_number() {
		return CalcResult{
			value: basis.value() * Percentage.new(value).as_fraction()
			type_: NumericType.new()
		}
	}
	return none
}

fn resolve_calc_function(node CalcFunction, ctx CalculationResolutionContext) ?CalcResult {
	mut results := []CalcResult{}
	for child in node.children {
		results << (resolve_calc_node(child, ctx) or { return none })
	}
	match node.name {
		'min' {
			mut minimum := results[0].value
			for index := 1; index < results.len; index++ {
				if results[index].value < minimum {
					minimum = results[index].value
				}
			}
			return CalcResult{
				value: minimum
				type_: results[0].type_
			}
		}
		'max' {
			mut maximum := results[0].value
			for index := 1; index < results.len; index++ {
				if results[index].value > maximum {
					maximum = results[index].value
				}
			}
			return CalcResult{
				value: maximum
				type_: results[0].type_
			}
		}
		'clamp' {
			minimum := results[0].value
			central := results[1].value
			maximum := results[2].value
			mut clamped := central
			if clamped > maximum {
				clamped = maximum
			}
			if clamped < minimum {
				clamped = minimum
			}
			return CalcResult{
				value: clamped
				type_: results[0].type_
			}
		}
		'hypot' {
			mut sum_of_squares := 0.0
			for result in results {
				sum_of_squares += result.value * result.value
			}
			return CalcResult{
				value: math.sqrt(sum_of_squares)
				type_: results[0].type_
			}
		}
		'abs' {
			return CalcResult{
				value: math.abs(results[0].value)
				type_: results[0].type_
			}
		}
		'sign' {
			return CalcResult{
				value: calc_sign_of(results[0].value)
				type_: NumericType.new()
			}
		}
		'sin' {
			return calc_number_result(math.sin(calc_to_radians(results[0])))
		}
		'cos' {
			return calc_number_result(math.cos(calc_to_radians(results[0])))
		}
		'tan' {
			return calc_number_result(math.tan(calc_to_radians(results[0])))
		}
		'asin' {
			return calc_arc_result(math.asin(results[0].value), -90, 90)
		}
		'acos' {
			return calc_arc_result(math.acos(results[0].value), 0, 180)
		}
		'atan' {
			return calc_arc_result(math.atan(results[0].value), -90, 90)
		}
		'atan2' {
			return CalcResult{
				value: calc_radians_to_degrees(math.atan2(results[0].value, results[1].value))
				type_: NumericType.with_type(.angle, 1)
			}
		}
		'pow' {
			return calc_number_result(math.pow(results[0].value, results[1].value))
		}
		'sqrt' {
			return calc_number_result(math.sqrt(results[0].value))
		}
		'exp' {
			return calc_number_result(math.exp(results[0].value))
		}
		'log' {
			base := if results.len == 2 { results[1].value } else { math.e }
			return calc_number_result(math.log(results[0].value) / math.log(base))
		}
		'mod' {
			return calc_mod_or_rem(results[0], results[1], false)
		}
		'rem' {
			return calc_mod_or_rem(results[0], results[1], true)
		}
		'round' {
			return calc_round(node.strategy, results[0], results[1])
		}
		else {
			return none
		}
	}
}

fn calc_number_result(value f64) CalcResult {
	return CalcResult{
		value: value
		type_: NumericType.new()
	}
}

fn calc_sign_of(value f64) f64 {
	if math.is_nan(value) {
		return math.nan()
	}
	if value < 0 {
		return -1
	}
	if value > 0 {
		return 1
	}
	return 0
}

// The radians for sin/cos/tan: an angle resolves to degrees (convert), a number is radians.
fn calc_to_radians(result CalcResult) f64 {
	if result.type_.matches_angle(none) {
		return result.value * math.pi / 180.0
	}
	return result.value
}

fn calc_radians_to_degrees(radians f64) f64 {
	return radians * 180.0 / math.pi
}

fn calc_arc_result(radians f64, min_degrees f64, max_degrees f64) CalcResult {
	mut degrees := calc_radians_to_degrees(radians)
	for degrees < min_degrees {
		degrees += 360
	}
	for degrees > max_degrees {
		degrees -= 360
	}
	return CalcResult{
		value: degrees
		type_: NumericType.with_type(.angle, 1)
	}
}

fn calc_mod_or_rem(numerator CalcResult, divisor CalcResult, is_rem bool) CalcResult {
	value := if is_rem {
		math.fmod(numerator.value, divisor.value)
	} else {
		numerator.value - divisor.value * math.floor(numerator.value / divisor.value)
	}
	return CalcResult{
		value: value
		type_: numerator.type_
	}
}

fn calc_round(strategy string, a CalcResult, b CalcResult) CalcResult {
	value := a.value
	interval := b.value
	numeric_type := a.type_

	// https://drafts.csswg.org/css-values-4/#round-infinities
	if interval == 0 || (math.is_inf(value, 0) && math.is_inf(interval, 0)) {
		return CalcResult{
			value: math.nan()
			type_: numeric_type
		}
	}
	if math.is_inf(value, 0) && !math.is_inf(interval, 0) {
		return CalcResult{
			value: value
			type_: numeric_type
		}
	}
	if !math.is_inf(value, 0) && math.is_inf(interval, 0) {
		mut result := 0.0
		if strategy == 'up' && value > 0 {
			result = math.inf(1)
		} else if strategy == 'down' && value < 0 {
			result = math.inf(-1)
		}
		return CalcResult{
			value: result
			type_: numeric_type
		}
	}

	if math.fmod(value, interval) == 0 {
		return a
	}

	lower := math.floor(value / interval) * interval
	upper := math.ceil(value / interval) * interval
	rounded := match strategy {
		'up' {
			upper
		}
		'down' {
			lower
		}
		'to-zero' {
			if math.abs(upper) < math.abs(lower) { upper } else { lower }
		}
		else {
			// nearest: closest of lower/upper, ties go to upper.
			if math.abs(upper - value) <= math.abs(lower - value) { upper } else { lower }
		}
	}
	return CalcResult{
		value: rounded
		type_: numeric_type
	}
}
