module css

// Validates shorthand serialization (the ported `default_serialize` plus the
// border-family short form) and that the serialized css_text re-parses to the
// same text (round-trip stability).

fn serialize_of(text string, property PropertyID) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	return value.css_text
}

fn roundtrips(text string, property PropertyID) bool {
	first := serialize_of(text, property) or { return false }
	second := serialize_of(first, property) or { return false }
	return first == second
}

fn test_all_equal_longhands_collapse_to_single_value() {
	// When all longhands are equal the shorthand serializes as a single value
	// (upstream default_serialize behaviour).
	assert serialize_of('5px', PropertyID.margin)? == '5px'
	assert serialize_of('2px', PropertyID.border_width)? == '2px'
	assert serialize_of('red', PropertyID.border_color)? == 'red'
	assert serialize_of('auto', PropertyID.overflow)? == 'auto'
	assert serialize_of('10px', PropertyID.gap)? == '10px'
}

fn test_uneven_box_values_are_not_collapsed() {
	// Ladybird does not do CSS shortest-form (4->2->1); uneven values stay full.
	assert serialize_of('1px 2px', PropertyID.margin)? == '1px 2px 1px 2px'
	assert serialize_of('1px 2px 3px 4px', PropertyID.padding)? == '1px 2px 3px 4px'
}

fn test_border_family_short_form() {
	assert serialize_of('1px solid red', PropertyID.border)? == '1px solid red'
	assert serialize_of('2px dashed blue', PropertyID.border_top)? == '2px dashed blue'
	assert serialize_of('1px solid red', PropertyID.border_block)? == '1px solid red'
	// Longhands equal to their initial value are omitted.
	assert serialize_of('solid', PropertyID.border)? == 'solid'
	assert serialize_of('1px', PropertyID.border)? == '1px'
}

fn test_serialization_round_trips() {
	assert roundtrips('5px', PropertyID.margin)
	assert roundtrips('1px 2px', PropertyID.padding)
	assert roundtrips('auto', PropertyID.overflow)
	assert roundtrips('1px solid red', PropertyID.border)
	assert roundtrips('2px dashed blue', PropertyID.border_top)
	assert roundtrips('thick dotted', PropertyID.border_inline)
}
