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

fn test_box_values_collapse_to_shortest_form() {
	// Positional-value-list shorthands collapse 4->2->1 (upstream
	// serialize_a_positional_value_list); uneven values stay full.
	assert serialize_of('1px 2px', PropertyID.margin)? == '1px 2px'
	assert serialize_of('1px 2px 1px 2px', PropertyID.margin)? == '1px 2px'
	assert serialize_of('1px 2px 3px 4px', PropertyID.padding)? == '1px 2px 3px 4px'
	assert serialize_of('1px 2px 3px', PropertyID.padding)? == '1px 2px 3px'
	assert serialize_of('round bevel', PropertyID.corner_shape)? == 'round bevel'
	assert serialize_of('normal 20px', PropertyID.gap)? == 'normal 20px'
}

fn test_border_family_short_form() {
	assert serialize_of('1px solid red', PropertyID.border)? == '1px solid red'
	assert serialize_of('2px dashed blue', PropertyID.border_top)? == '2px dashed blue'
	assert serialize_of('1px solid red', PropertyID.border_block)? == '1px solid red'
	// Longhands equal to their initial value are omitted.
	assert serialize_of('solid', PropertyID.border)? == 'solid'
	assert serialize_of('1px', PropertyID.border)? == '1px'
}

fn test_special_shorthand_serialization() {
	// grid-line: `<start> [/ <end>]`.
	assert serialize_of('1 / 3', PropertyID.grid_column)? == '1 / 3'
	assert serialize_of('span 2 / span 3', PropertyID.grid_row)? == 'span 2 / span 3'
	// flex: grow shrink basis.
	assert serialize_of('1 0 auto', PropertyID.flex)? == '1 0 auto'
	// border-radius: `<h> [/ <v>]`.
	assert serialize_of('10px / 20px', PropertyID.border_radius)? == '10px / 20px'
	assert serialize_of('5px', PropertyID.border_radius)? == '5px'
	// font: reordered canonical form with `/ line-height`.
	assert serialize_of('12px serif', PropertyID.font)? == '12px serif'
	assert serialize_of('italic bold 14px/1.4 serif', PropertyID.font)? == 'italic bold 14px / 1.4 serif'
	// url() function form keeps the unquoted value.
	assert serialize_of('url("a.png")', PropertyID.background_image)? == 'url("a.png")'
	// all-omitted fallback: flex-flow with both initial serializes the first longhand.
	assert serialize_of('row nowrap', PropertyID.flex_flow)? == 'row'
}

fn test_serialization_round_trips() {
	assert roundtrips('5px', PropertyID.margin)
	assert roundtrips('1px 2px', PropertyID.padding)
	assert roundtrips('auto', PropertyID.overflow)
	assert roundtrips('1px solid red', PropertyID.border)
	assert roundtrips('2px dashed blue', PropertyID.border_top)
	assert roundtrips('thick dotted', PropertyID.border_inline)
	assert roundtrips('1 / 3', PropertyID.grid_column)
	assert roundtrips('1 0 auto', PropertyID.flex)
	assert roundtrips('10px / 20px', PropertyID.border_radius)
	assert roundtrips('italic bold 14px/1.4 serif', PropertyID.font)
	assert roundtrips('url("a.png") no-repeat center', PropertyID.background)
	assert roundtrips('row nowrap', PropertyID.flex_flow)
}
