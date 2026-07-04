module css

// Validates the calc()/min()/max()/clamp() parser: that supported math functions
// parse for the appropriate value types, that type-invalid expressions are rejected,
// and that the serialized css_text re-parses to the same text (round-trip stability).
// Simplification is a deliberate boundary, so `calc(1px + 2px)` stays `calc(1px + 2px)`.

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
	// A relative length keeps the constant part folded but stays otherwise symbolic.
	assert calc_value('calc(1px + 2px + 3em)', PropertyID.width)? == 'calc(3px + 3em)'
}

fn test_min_max_clamp() {
	// All-constant, single-unit functions fold to a value.
	assert calc_value('min(10px, 20px)', PropertyID.width)? == 'calc(10px)'
	assert calc_value('clamp(5px, 50px, 10px)', PropertyID.width)? == 'calc(10px)'
	// Relative units are not canonical, so these stay symbolic.
	assert calc_value('max(1em, 2em)', PropertyID.width)? == 'max(1em, 2em)'
	assert calc_value('clamp(1px, 5vw, 10px)', PropertyID.width)? == 'clamp(1px, 5vw, 10px)'
	// A percentage mixed with lengths cannot be folded without a basis.
	assert calc_value('clamp(10px, 50%, 90px)', PropertyID.width)? == 'clamp(10px, 50%, 90px)'
}

fn test_nested_and_precedence() {
	// `*`/`/` bind tighter than `+`/`-`; parenthesised groups and nested functions fold.
	assert calc_value('calc((1px + 2px) * 3)', PropertyID.width)? == 'calc(9px)'
	assert calc_value('calc(2 * (3px + 4px) - 1px)', PropertyID.width)? == 'calc(13px)'
	assert calc_value('min(10px, max(2px, 5px))', PropertyID.width)? == 'calc(5px)'
}

fn test_calc_number_and_angle() {
	assert calc_value('calc(1 + 2)', PropertyID.opacity)? == 'calc(3)'
	assert calc_value('calc(90deg / 2)', PropertyID.rotate)? == 'calc(45deg)'
	// Numeric constants fold to their value.
	assert calc_value('sqrt(16)', PropertyID.opacity)? == 'calc(4)'
	assert calc_value('sin(90deg)', PropertyID.opacity)? == 'calc(1)'
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
