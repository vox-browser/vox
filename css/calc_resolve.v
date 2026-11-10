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

// CSS comparison functions order negative zero before positive zero.
// NaN propagation is handled by the caller before comparing numeric values.
fn calc_comparison_less_than(left f64, right f64) bool {
	return left < right || (left == 0 && right == 0 && math.signbit(left) && !math.signbit(right))
}

fn resolve_calc_node(node CalcNode, calculation_context CalculationContext, ctx CalculationResolutionContext) ?CalcResult {
	match node {
		CalcNumeric {
			return resolve_calc_leaf(node, calculation_context, ctx)
		}
		CalcTreeCounting {
			abstract_element := ctx.abstract_element or { return none }
			return CalcResult{
				value: f64(node.style_value.resolve_for_dom_abstract_element(&abstract_element))
				type_: NumericType.new()
			}
		}
		CalcAnchor {
			return resolve_calc_anchor(node, calculation_context, ctx)
		}
		CalcAnchorSize {
			return resolve_calc_anchor_size(node, calculation_context, ctx)
		}
		CalcChannel {
			for channel in ctx.relative_color_channels {
				if channel.name == node.name {
					return CalcResult{
						value: channel.value
						type_: NumericType.new()
					}
				}
			}
			return none
		}
		CalcSum {
			mut accumulated := resolve_calc_node(node.children[0], calculation_context, ctx) or {
				return none
			}
			for index := 1; index < node.children.len; index++ {
				addend := resolve_calc_node(node.children[index], calculation_context, ctx) or {
					return none
				}
				accumulated = calc_result_add(accumulated, addend) or { return none }
			}
			return accumulated
		}
		CalcProduct {
			mut accumulated := resolve_calc_node(node.children[0], calculation_context, ctx) or {
				return none
			}
			for index := 1; index < node.children.len; index++ {
				factor := resolve_calc_node(node.children[index], calculation_context, ctx) or {
					return none
				}
				accumulated = calc_result_multiply(accumulated, factor) or { return none }
			}
			return accumulated
		}
		CalcNegate {
			child := resolve_calc_node(node.children[0], calculation_context, ctx) or { return none }
			return CalcResult{
				value: -child.value
				type_: child.type_
			}
		}
		CalcInvert {
			child := resolve_calc_node(node.children[0], calculation_context, ctx) or { return none }
			return CalcResult{
				value: 1.0 / child.value
				type_: child.type_.inverted()
			}
		}
		CalcFunction {
			return resolve_calc_function(node, calculation_context, ctx)
		}
		CalcRandom {
			return resolve_calc_random(node, calculation_context, ctx)
		}
	}
	return none
}

fn resolve_calc_anchor_size(node CalcAnchorSize, calculation_context CalculationContext, ctx CalculationResolutionContext) ?CalcResult {
	resolver := ctx.anchor_size_resolver or { return none }
	if resolved := resolver(ctx.anchor_resolver_context, node.style_value) {
		return CalcResult{value: resolved.to_double(), type_: NumericType.with_type(.length, 1)}
	}
	fallback := node.style_value.fallback_value() or { return none }
	return match fallback {
		AnchorSizeStyleValue { resolve_calc_anchor_size(CalcAnchorSize{style_value:fallback}, calculation_context, ctx) }
		LengthStyleValue { CalcResult{value:fallback.length().to_px_without_rounding(ctx.length_resolution_context), type_:NumericType.with_type(.length,1)} }
		PercentageStyleValue { resolve_calc_percentage_against_basis(fallback.percentage().value(),ctx) }
		CalculatedStyleValue { if fallback.node.len == 1 { resolve_calc_node(fallback.node[0],fallback.calculation_context,ctx) } else { none } }
		else { none }
	}
}

fn resolve_calc_anchor(node CalcAnchor, calculation_context CalculationContext, ctx CalculationResolutionContext) ?CalcResult {
	resolver := ctx.anchor_resolver or { return none }
	if resolved := resolver(ctx.anchor_resolver_context, node.style_value) {
		return CalcResult{
			value: resolved.to_double()
			type_: NumericType.with_type(.length, 1)
		}
	}

	fallback := node.style_value.fallback_value() or { return none }
	return match fallback {
		AnchorStyleValue {
			resolve_calc_anchor(CalcAnchor{
				style_value: fallback
			}, calculation_context, ctx)
		}
		LengthStyleValue {
			CalcResult{
				value: fallback.length().to_px_without_rounding(ctx.length_resolution_context)
				type_: NumericType.with_type(.length, 1)
			}
		}
		PercentageStyleValue {
			resolve_calc_percentage_against_basis(fallback.percentage().value(), ctx)
		}
		CalculatedStyleValue {
			if fallback.node.len != 1 {
				none
			} else {
				resolve_calc_node(fallback.node[0], fallback.calculation_context, ctx)
			}
		}
		else { none }
	}
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

fn resolve_calc_leaf(leaf CalcNumeric, calculation_context CalculationContext, ctx CalculationResolutionContext) ?CalcResult {
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
			// C++ leaves percentages symbolic when their calculation context associates
			// them with another type but no basis is available yet.
			if calculation_context.percentages_resolve_as != none {
				return none
			}
			return CalcResult{
				value: leaf.value
				type_: NumericType.with_type(.percent, 1)
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

fn resolve_calc_function(node CalcFunction, calculation_context CalculationContext, ctx CalculationResolutionContext) ?CalcResult {
	// sign() is the one type-changing function that operates directly on any numeric
	// leaf, including an unresolved percentage or non-canonical dimension. This mirrors
	// SignCalculationNode::run_operation_if_possible rather than forcing it through the
	// canonical-unit path used by min()/abs()/round()/etc.
	if node.name == 'sign' {
		child := node.children[0]
		if child is CalcNumeric {
			return_type := NumericType.new().made_consistent_with(child.type_) or { return none }
			return CalcResult{
				value: calc_sign_of(child.value)
				type_: return_type
			}
		}
	}

	mut results := []CalcResult{}
	for child in node.children {
		results << (resolve_calc_node(child, calculation_context, ctx) or { return none })
	}
	match node.name {
		'progress' {
			calc_consistent_results_type(results) or { return none }
			return CalcResult{value:(results[0].value-results[1].value)/(results[2].value-results[1].value),type_:NumericType.new()}
		}
		'min' {
			consistent_type := calc_consistent_results_type(results) or { return none }
			mut minimum := results[0].value
			for index := 1; index < results.len; index++ {
				// CSS Values requires any operation with a NaN argument to produce NaN.
				// Ordinary floating-point comparisons would otherwise silently retain the
				// first finite operand.
				if math.is_nan(minimum) || math.is_nan(results[index].value) {
					minimum = math.nan()
					continue
				}
				if calc_comparison_less_than(results[index].value, minimum) {
					minimum = results[index].value
				}
			}
			return CalcResult{
				value: minimum
				type_: consistent_type
			}
		}
		'max' {
			consistent_type := calc_consistent_results_type(results) or { return none }
			mut maximum := results[0].value
			for index := 1; index < results.len; index++ {
				if math.is_nan(maximum) || math.is_nan(results[index].value) {
					maximum = math.nan()
					continue
				}
				if calc_comparison_less_than(maximum, results[index].value) {
					maximum = results[index].value
				}
			}
			return CalcResult{
				value: maximum
				type_: consistent_type
			}
		}
		'clamp' {
			consistent_type := calc_consistent_results_type(results) or { return none }
			minimum := results[0].value
			central := results[1].value
			maximum := results[2].value
			if math.is_nan(minimum) || math.is_nan(central) || math.is_nan(maximum) {
				return CalcResult{
					value: math.nan()
					type_: consistent_type
				}
			}
			mut clamped := central
			if calc_comparison_less_than(maximum, clamped) {
				clamped = maximum
			}
			if calc_comparison_less_than(clamped, minimum) {
				clamped = minimum
			}
			return CalcResult{
				value: clamped
				type_: consistent_type
			}
		}
		'hypot' {
			consistent_type := calc_consistent_results_type(results) or { return none }
			mut sum_of_squares := 0.0
			for result in results {
				sum_of_squares += result.value * result.value
			}
			return CalcResult{
				value: math.sqrt(sum_of_squares)
				type_: consistent_type
			}
		}
		'abs' {
			return CalcResult{
				value: math.abs(results[0].value)
				type_: results[0].type_
			}
		}
		'sign' {
			return_type := NumericType.new().made_consistent_with(results[0].type_) or {
				return none
			}
			return CalcResult{
				value: calc_sign_of(results[0].value)
				type_: return_type
			}
		}
		'sin' {
			return calc_number_result_consistent(math.sin(calc_to_radians(results[0])), results[0].type_)
		}
		'cos' {
			return calc_number_result_consistent(math.cos(calc_to_radians(results[0])), results[0].type_)
		}
		'tan' {
			return calc_number_result_consistent(math.tan(calc_to_radians(results[0])), results[0].type_)
		}
		'asin' {
			return calc_arc_result(math.asin(results[0].value), -90, 90, results[0].type_)
		}
		'acos' {
			return calc_arc_result(math.acos(results[0].value), 0, 180, results[0].type_)
		}
		'atan' {
			return calc_arc_result(math.atan(results[0].value), -90, 90, results[0].type_)
		}
		'atan2' {
			input_type := results[0].type_.consistent_type(results[1].type_) or { return none }
			return_type := NumericType.with_type(.angle, 1).made_consistent_with(input_type) or {
				return none
			}
			mut degrees := calc_radians_to_degrees(math.atan2(results[0].value, results[1].value))
			// atan2()'s CSS range is (-180deg, 180deg], so the IEEE -180deg
			// result (notably from atan2(-0, -1)) is represented as +180deg.
			for degrees <= -180 {
				degrees += 360
			}
			for degrees > 180 {
				degrees -= 360
			}
			return CalcResult{
				value: degrees
				type_: return_type
			}
		}
		'pow' {
			consistent_type := results[0].type_.consistent_type(results[1].type_) or {
				return none
			}
			return CalcResult{
				value: math.pow(results[0].value, results[1].value)
				type_: consistent_type
			}
		}
		'sqrt' {
			return calc_number_result_consistent(math.sqrt(results[0].value), results[0].type_)
		}
		'exp' {
			return calc_number_result_consistent(math.exp(results[0].value), results[0].type_)
		}
		'log' {
			base := if results.len == 2 { results[1].value } else { math.e }
			return calc_number_result_consistent(math.log(results[0].value) / math.log(base), results[0].type_)
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

// https://drafts.csswg.org/css-values-5/#random-evaluation
fn resolve_calc_random(node CalcRandom, calculation_context CalculationContext, ctx CalculationResolutionContext) ?CalcResult {
	mut sharing := node.sharing
	if !sharing.is_fixed() {
		if ctx.abstract_element == none {
			return none
		}
		absolutized := sharing.absolutized(ComputationContext{
			length_resolution_context: ctx.length_resolution_context
			abstract_element: ctx.abstract_element
		})
		if absolutized is RandomValueSharingStyleValue {
			sharing = absolutized
		} else {
			return none
		}
	}

	minimum := resolve_calc_node(node.children[0], calculation_context, ctx) or { return none }
	maximum_result := resolve_calc_node(node.children[1], calculation_context, ctx) or { return none }
	mut minimum_value := minimum.value
	mut maximum_value := maximum_result.value
	mut step_value := 0.0
	if node.children.len == 3 {
		step := resolve_calc_node(node.children[2], calculation_context, ctx) or { return none }
		step_value = step.value
	}
	result_type := calc_consistent_calc_children_type(node.children) or { return none }

	if maximum_value < minimum_value {
		maximum_value = minimum_value
	}
	if math.is_inf(minimum_value, 0) {
		return CalcResult{
			value: math.inf(1)
			type_: result_type
		}
	}
	if math.is_inf(maximum_value, 0) {
		return CalcResult{
			value: math.nan()
			type_: result_type
		}
	}
	if math.is_inf(step_value, 0) {
		return CalcResult{
			value: minimum_value
			type_: result_type
		}
	}
	if math.is_nan(minimum_value) || math.is_nan(maximum_value) || math.is_nan(step_value) {
		return CalcResult{
			value: math.nan()
			type_: result_type
		}
	}

	random_base_value := sharing.random_base_value()
	// AK::NumericLimits<float>::epsilon() * 1000.
	has_step := step_value > 1.1920928955078125e-4
	if !has_step {
		return CalcResult{
			value: minimum_value + random_base_value * (maximum_value - minimum_value)
			type_: result_type
		}
	}

	epsilon := step_value / 1000.0
	mut n := math.floor((maximum_value - minimum_value) / step_value)
	if math.abs(maximum_value - (n * step_value + minimum_value)) > epsilon
		&& math.abs(maximum_value - ((n + 1) * step_value + minimum_value)) < epsilon {
		n++
	}
	step_index := math.floor((n + 1) * random_base_value)
	value := minimum_value + step_index * step_value
	if step_index == n && math.abs(maximum_value - value) < epsilon {
		return CalcResult{
			value: maximum_value
			type_: result_type
		}
	}
	return CalcResult{
		value: value
		type_: result_type
	}
}

fn calc_number_result_consistent(value f64, input_type NumericType) ?CalcResult {
	return_type := NumericType.new().made_consistent_with(input_type) or { return none }
	return CalcResult{
		value: value
		type_: return_type
	}
}

fn calc_consistent_results_type(results []CalcResult) ?NumericType {
	mut result := results[0].type_
	for index := 1; index < results.len; index++ {
		result = result.consistent_type(results[index].type_) or { return none }
	}
	return result
}

fn calc_consistent_calc_children_type(children []CalcNode) ?NumericType {
	mut result := children[0].numeric_type() or { return none }
	for index := 1; index < children.len; index++ {
		child_type := children[index].numeric_type() or { return none }
		result = result.consistent_type(child_type) or { return none }
	}
	return result
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
	// FloatExtractor::sign in the C++ implementation distinguishes 0- from 0+.
	return math.copysign(0.0, value)
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

fn calc_arc_result(radians f64, min_degrees f64, max_degrees f64, input_type NumericType) ?CalcResult {
	mut degrees := calc_radians_to_degrees(radians)
	for degrees < min_degrees {
		degrees += 360
	}
	for degrees > max_degrees {
		degrees -= 360
	}
	return_type := NumericType.with_type(.angle, 1).made_consistent_with(input_type) or {
		return none
	}
	return CalcResult{
		value: degrees
		type_: return_type
	}
}

fn calc_mod_or_rem(numerator CalcResult, divisor CalcResult, is_rem bool) ?CalcResult {
	// Unlike round(), mod()/rem() require the two resolved arguments to have the
	// same type, not merely types that can be made consistent.
	if numerator.type_ != divisor.type_ {
		return none
	}
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

fn calc_round(strategy string, a CalcResult, b CalcResult) ?CalcResult {
	value := a.value
	interval := b.value
	numeric_type := a.type_.made_consistent_with(b.type_) or { return none }

	// https://drafts.csswg.org/css-values-4/#round-infinities
	if interval == 0 || (math.is_inf(value, 0) && math.is_inf(interval, 0)) {
		return CalcResult{
			value: math.nan()
			type_: numeric_type
		}
	}
	if math.is_inf(value, 0) && !math.is_inf(interval, 0) && !math.is_nan(interval) {
		return CalcResult{
			value: value
			type_: numeric_type
		}
	}
	if !math.is_inf(value, 0) && !math.is_nan(value) && math.is_inf(interval, 0) {
		zero_with_value_sign := math.copysign(0.0, value)
		result := match strategy {
			'up' {
				if value > 0 { math.inf(1) } else { zero_with_value_sign }
			}
			'down' {
				if value < 0 { math.inf(-1) } else { zero_with_value_sign }
			}
			else {
				// nearest and to-zero both preserve whether A is 0- or 0+.
				zero_with_value_sign
			}
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
