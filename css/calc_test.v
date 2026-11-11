module css

// Validates the calc()/min()/max()/clamp() parser: that supported math functions
// parse for the appropriate value types, that type-invalid expressions are rejected,
// and that the serialized css_text re-parses to the same text (round-trip stability).
// Parsing performs the same context-free simplification as C++; computed-value
// absolutization additionally resolves relative units with its computation context.

fn calc_value(text string, property PropertyID) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	return value.css_text
}

fn calc_roundtrips(text string, property PropertyID) bool {
	first := calc_value(text, property) or { return false }
	second := calc_value(first, property) or { return false }
	return first == second
}

fn test_calc_lengths_parse() {
	// Constant sub-expressions are folded at parse time (matching upstream), so an
	// all-constant length calc collapses to a single value.
	assert calc_value('calc(1px + 2px)', PropertyID.width)? == 'calc(3px)'
	assert calc_value('calc(2 * 3px)', PropertyID.width)? == 'calc(6px)'
	assert calc_value('calc(10px / 2)', PropertyID.width)? == 'calc(5px)'
	// Absolute units are converted to the canonical unit (px) before folding.
	assert calc_value('calc(90deg + 90deg)', PropertyID.rotate)? == 'calc(180deg)'
}

fn test_calc_length_percentage_mix() {
	// A mixed length+percentage calc is valid for <length-percentage> properties and stays
	// symbolic (it can only be resolved with a percentage basis).
	assert calc_value('calc(100% - 10px)', PropertyID.width)? == 'calc(100% - 10px)'
	assert calc_value('calc(50% + 20px)', PropertyID.margin_left)? == 'calc(50% + 20px)'
	// Scalar multiplication preserves a percentage even though its contextual
	// NumericType is length-hinted.
	assert calc_value('calc(0.5 * 50% + 5px)', PropertyID.width)? == 'calc(25% + 5px)'
	// A relative length keeps the constant part folded but stays otherwise symbolic.
	assert calc_value('calc(1px + 2px + 3em)', PropertyID.width)? == 'calc(3em + 3px)'
}

fn test_min_max_clamp() {
	// All-constant, single-unit functions fold to a value.
	assert calc_value('min(10px, 20px)', PropertyID.width)? == 'calc(10px)'
	assert calc_value('clamp(5px, 50px, 10px)', PropertyID.width)? == 'calc(10px)'
	// Same-unit relative values can still be compared without a font context.
	assert calc_value('max(1em, 2em)', PropertyID.width)? == 'calc(2em)'
	// Comparable children are partially reduced when another unit prevents a full fold.
	assert calc_value('min(3em, 1em, 10px)', PropertyID.width)? == 'min(1em, 10px)'
	assert calc_value('clamp(1px, 5vw, 10px)', PropertyID.width)? == 'clamp(1px, 5vw, 10px)'
	// A percentage mixed with lengths cannot be folded without a basis.
	assert calc_value('clamp(10px, 50%, 90px)', PropertyID.width)? == 'clamp(10px, 50%, 90px)'
	// Percentages associated with a dimension are not compared until the basis is known.
	assert calc_value('min(20%, 10%)', PropertyID.width)? == 'min(20%, 10%)'
}

fn test_nested_and_precedence() {
	// `*`/`/` bind tighter than `+`/`-`; parenthesised groups and nested functions fold.
	assert calc_value('calc((1px + 2px) * 3)', PropertyID.width)? == 'calc(9px)'
	assert calc_value('calc(2 * (3px + 4px) - 1px)', PropertyID.width)? == 'calc(13px)'
	assert calc_value('min(10px, max(2px, 5px))', PropertyID.width)? == 'calc(5px)'
	// The C++ simplifier distributes a number over an all-numeric sum, leaving only
	// context-dependent relative units for computed-value resolution.
	assert calc_value('calc(2 * (1em + 3px))', PropertyID.width)? == 'calc(2em + 6px)'
}

fn test_calc_serialization_sorting_and_non_finite_results() {
	// Calculation children serialize in number/percentage/unit order, independent of
	// their source order.
	assert calc_value('calc(1px + 10% + 1em)', PropertyID.width)? == 'calc(10% + 1em + 1px)'

	// Any NaN argument propagates through comparison functions. Top-level censoring to
	// zero happens only when the value is resolved for a property.
	assert calc_value('min(NaN, 1)', PropertyID.opacity)? == 'calc(NaN)'
	assert calc_value('max(1, NaN)', PropertyID.opacity)? == 'calc(NaN)'
	assert calc_value('clamp(0, NaN, 1)', PropertyID.opacity)? == 'calc(NaN)'
	assert calc_value('round(NaN, infinity)', PropertyID.opacity)? == 'calc(NaN)'
}

fn test_calc_number_and_angle() {
	assert calc_value('calc(1 + 2)', PropertyID.opacity)? == 'calc(3)'
	assert calc_value('calc(90deg / 2)', PropertyID.rotate)? == 'calc(45deg)'
	// Numeric constants fold to their value.
	assert calc_value('sqrt(16)', PropertyID.opacity)? == 'calc(4)'
	assert calc_value('sin(90deg)', PropertyID.opacity)? == 'calc(1)'
	// sign() operates on the raw numeric leaf even when a percentage is associated
	// with another type, then preserves that contextual type through simplification.
	assert calc_value('calc(sign(10%) * 1px)', PropertyID.width)? == 'calc(1px)'
	assert calc_value('calc(sign(-10%) * 1px)', PropertyID.width)? == 'calc(-1px)'
}

fn test_type_invalid_calc_is_rejected() {
	// length + number is not addable.
	assert calc_value('calc(1px + 1)', PropertyID.width) == none
	// length * length is length², which is not a <length>.
	assert calc_value('calc(1px * 2px)', PropertyID.width) == none
	// A non-numeric operand is invalid.
	assert calc_value('calc(red)', PropertyID.width) == none
	// A number-typed calc does not satisfy a <length> property.
	assert calc_value('calc(1 + 2)', PropertyID.width) == none
}

fn test_calc_round_trips() {
	assert calc_roundtrips('calc(1px + 2px)', PropertyID.width)
	assert calc_roundtrips('calc(100% - 10px)', PropertyID.width)
	assert calc_roundtrips('calc((1px + 2px) * 3)', PropertyID.width)
	assert calc_roundtrips('min(50%, 100px)', PropertyID.width)
	assert calc_roundtrips('clamp(10px, 50%, 90px)', PropertyID.width)
	assert calc_roundtrips('calc(90deg / 2)', PropertyID.rotate)
	assert calc_roundtrips('calc(1 + 2)', PropertyID.opacity)
}

fn test_nested_calc_operator_nodes_are_parenthesised() {
	// "Serialize a calculation tree" wraps every nested Sum, Product, Negate, and Invert in
	// parentheses; only the root of the math function and its comma-separated arguments are
	// emitted bare. Dropping those parentheses would re-associate the expression, so this is
	// what keeps a serialization re-parseable as the same tree.
	assert calc_value('calc(1em + 2 * 3vw)', PropertyID.width)? == 'calc(1em + (2 * 3vw))'
	assert calc_value('calc(1em * 2 + 3px)', PropertyID.width)? == 'calc(3px + (2 * 1em))'
	assert calc_value('calc(1px - 1em * 2)', PropertyID.width)? == 'calc(1px - (2 * 1em))'
	assert calc_value('calc(1px + 1em * 2 + 3%)', PropertyID.width)? == 'calc(3% + 1px + (2 * 1em))'
	assert calc_value('calc(1px / (1em / 1vw))', PropertyID.width)? == 'calc(1px / (1em / 1vw))'
	assert calc_value('calc(1em + 1px * sibling-index())', PropertyID.width)? == 'calc(1em + (1px * sibling-index()))'
	// A math function's arguments are the other place that omits the outer parentheses.
	assert calc_value('min(1px, 2em * 3)', PropertyID.width)? == 'min(1px, 3 * 2em)'
	assert calc_value('max(1em, calc(2vw + 1px))', PropertyID.width)? == 'max(1em, 1px + 2vw)'
	// A flattened product keeps its inverted factors inline; only a nested tree is wrapped.
	assert calc_value('calc(1em * (1px / 1em))', PropertyID.width)? == 'calc(1em * 1px / 1em)'
	assert calc_roundtrips('calc(1px / (1em / 1vw))', PropertyID.width)
	assert calc_roundtrips('calc(1em + 2 * 3vw)', PropertyID.width)
}

fn test_non_finite_leaf_serialization_is_type_specific() {
	// Only a <number> spells its non-finite values as keywords. A percentage or dimension
	// leaf prints the raw number, so it serializes as `infpx`/`inf%` - except at the root of
	// a math function, where "serialize a math function" restores the typed keyword form.
	assert calc_value('calc(infinity * 1px)', PropertyID.width)? == 'calc(infinity * 1px)'
	assert calc_value('calc(1px * infinity)', PropertyID.width)? == 'calc(infinity * 1px)'
	assert calc_value('calc(1em + infinity * 1px)', PropertyID.width)? == 'calc(1em + infpx)'
	assert calc_value('calc(1em + NaN * 1px)', PropertyID.width)? == 'calc(1em + nanpx)'
	assert calc_value('calc(1em + -infinity * 1px)', PropertyID.width)? == 'calc(1em - infpx)'
	assert calc_value('hypot(1em, -infinity * 1px)', PropertyID.width)? == 'hypot(1em, -infpx)'
	assert calc_value('calc(1em + 100% * infinity)', PropertyID.width)? == 'calc(inf% + 1em)'
	// A non-canonical leaf is not folded, so its keyword survives as a product factor.
	assert calc_value('calc(infinity * 1em)', PropertyID.width)? == 'calc(infinity * 1em)'
	assert calc_value('calc(1em + infinity * 1em)', PropertyID.width)? == 'calc(1em + (infinity * 1em))'
}

fn test_sign_folds_any_numeric_leaf() {
	// sign() reads its child's raw value instead of requiring a canonical unit, because the
	// sign of a value does not depend on the unit it is written in.
	assert calc_value('calc(sign(1em) * 1px)', PropertyID.width)? == 'calc(1px)'
	assert calc_value('calc(sign(-1em) * 1px)', PropertyID.width)? == 'calc(-1px)'
	assert calc_value('calc(sign(1vw) * 1px)', PropertyID.width)? == 'calc(1px)'
	assert calc_value('calc(1px * sign(1s))', PropertyID.width)? == 'calc(1px)'
	// abs() does need a canonical unit, so it stays symbolic for the same argument.
	assert calc_value('calc(abs(1em) + 1px)', PropertyID.width)? == 'calc(1px + abs(1em))'
	// A non-numeric child cannot be folded either way.
	assert calc_value('calc(sign(1em + 1px) * 1px)', PropertyID.width)? == 'calc(1px * sign(1em + 1px))'
}

fn test_mod_and_rem_accept_consistent_length_percentage_types() {
	// mod()/rem() now use the same consistent-type rule as min()/round().
	assert calc_value('mod(1em, 3%)', PropertyID.width)? == 'mod(1em, 3%)'
	assert calc_value('rem(50%, 2em)', PropertyID.width)? == 'rem(50%, 2em)'
	assert calc_value('mod(10%, 3%)', PropertyID.width)? == 'mod(10%, 3%)'
	assert calc_value('mod(1em, 3px)', PropertyID.width)? == 'mod(1em, 3px)'
	assert calc_value('min(1em, 50%)', PropertyID.width)? == 'min(1em, 50%)'
	assert calc_value('round(50%, 2em)', PropertyID.width)? == 'round(nearest, 50%, 2em)'
}

fn calc_resolved_value(text string, property PropertyID) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	typed := typed_style_value_logic_from_dom(value) or { return none }
	return typed.serialize(.resolved_value)
}

fn test_numeric_root_is_clamped_and_censored_for_resolved_values() {
	// "Serialize a math function" step 1: a numeric root serialized for a computed value or
	// later is clamped to the range its property accepts, has NaN censored to zero, and is
	// then serialized as an ordinary value - which drops the calc() wrapper entirely.
	assert calc_resolved_value('calc(50%)', PropertyID.width)? == '50%'
	assert calc_resolved_value('calc(-50%)', PropertyID.width)? == '0%'
	assert calc_resolved_value('calc(NaN * 1%)', PropertyID.width)? == '0%'
	assert calc_resolved_value('calc(NaN * 1px)', PropertyID.letter_spacing)? == '0px'
	assert calc_resolved_value('calc(2)', PropertyID.opacity)? == '1'
	assert calc_resolved_value('calc(-3)', PropertyID.opacity)? == '0'
	assert calc_resolved_value('calc(NaN)', PropertyID.opacity)? == '0'
	assert calc_resolved_value('calc(-2)', PropertyID.flex_grow)? == '0'
	// CSS rounds exact halves toward positive infinity before clamping.
	assert calc_resolved_value('calc(2.5)', PropertyID.z_index)? == '3'
	assert calc_resolved_value('calc(-2.5)', PropertyID.z_index)? == '-2'
	assert calc_resolved_value('calc(NaN)', PropertyID.z_index)? == '0'
	// A property whose range permits them keeps out-of-gamut percentages as written.
	assert calc_resolved_value('calc(-50%)', PropertyID.background_position_x)? == '-50%'
	assert calc_resolved_value('calc(150%)', PropertyID.background_position_x)? == '150%'
	// A non-numeric root keeps its calc() wrapper and is not clamped.
	assert calc_resolved_value('calc(50% + 1px)', PropertyID.width)? == 'calc(50% + 1px)'
	// The specified-value serialization is unaffected by any of this.
	assert calc_value('calc(-50%)', PropertyID.width)? == 'calc(-50%)'
	assert calc_value('calc(2)', PropertyID.opacity)? == 'calc(2)'
}
