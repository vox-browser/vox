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

// Parser::parse_value_for_property() tries <integer>/<number> before <length>
// "so that 0 is not interpreted as a <length> in case both are allowed". The
// custom parsers for these properties have to keep that order.
fn test_unitless_zero_stays_a_number_when_the_property_accepts_numbers() {
	assert serialize_of('0', PropertyID.line_height)? == '0'
	assert serialize_of('0.0', PropertyID.line_height)? == '0'
	assert serialize_of('-0', PropertyID.line_height)? == '0'
	assert serialize_of('0', PropertyID.tab_size)? == '0'
	assert serialize_of('0', PropertyID.border_image_outset)? == '0'
	assert serialize_of('0', PropertyID.border_image_width)? == '0'
	// An explicit unit still produces a length.
	assert serialize_of('0px', PropertyID.line_height)? == '0px'
	assert serialize_of('0px', PropertyID.tab_size)? == '0px'
	assert serialize_of('0px', PropertyID.border_image_outset)? == '0px'
	// A property with no <number> in its valid types keeps the zero length.
	assert serialize_of('0', PropertyID.width)? == '0px'
	assert serialize_of('0', PropertyID.border_top_width)? == '0px'
	assert serialize_of('0', PropertyID.margin_left)? == '0px'
	// The border-image shorthand carries the numeric outset through.
	assert serialize_of('none', PropertyID.border_image)? == 'none 100% / 1 / 0 stretch'
}

// Every component is checked against the property's declared range, so a
// negative line-height, border width or outline width is not a valid value.
fn test_declared_ranges_reject_negative_lengths() {
	assert serialize_of('-1', PropertyID.line_height) == none
	assert serialize_of('-1px', PropertyID.line_height) == none
	assert serialize_of('-1px', PropertyID.border_top_width) == none
	assert serialize_of('-1px', PropertyID.border_left_width) == none
	assert serialize_of('-1px', PropertyID.border_block_start_width) == none
	assert serialize_of('-1px', PropertyID.outline_width) == none
	assert serialize_of('-1px solid', PropertyID.outline) == none
	assert serialize_of('-1px solid red', PropertyID.border) == none
	assert serialize_of('12px/-1 serif', PropertyID.font) == none
	// The valid neighbours still parse.
	assert serialize_of('1px', PropertyID.border_top_width)? == '1px'
	assert serialize_of('thin', PropertyID.outline_width)? == 'thin'
	assert serialize_of('12px/0 serif', PropertyID.font)? == '12px / 0 serif'
}

// ShorthandStyleValue::serialize(): `white-space` collapses back to its legacy
// keyword when white-space-trim is `none` and the collapse/wrap pair matches.
fn test_white_space_serializes_back_to_its_legacy_keyword() {
	assert serialize_of('normal', PropertyID.white_space)? == 'normal'
	assert serialize_of('pre', PropertyID.white_space)? == 'pre'
	assert serialize_of('pre-wrap', PropertyID.white_space)? == 'pre-wrap'
	assert serialize_of('pre-line', PropertyID.white_space)? == 'pre-line'
	assert serialize_of('nowrap', PropertyID.white_space)? == 'nowrap'
	assert serialize_of('break-spaces', PropertyID.white_space)? == 'break-spaces'
}

fn declaration_block_text(declarations string) ?string {
	rules := parse_css_stylesheet_contents_with_parser('a { ${declarations} }', map[string]bool{})
	if rules.len < 1 {
		return none
	}
	declaration := rules[0].declaration or { return none }
	return declaration.serialized()
}

// ShorthandStyleValue::serialize() reaches each longhand by property id, not by
// position. Properties.json lists a shorthand's longhands alphabetically, so
// `grid-row` is `[grid-row-end, grid-row-start]` - the reverse of the order they
// serialize in. Reassembling a shorthand from separate longhand declarations
// used that metadata order and produced `grid-row: 2 / 1`.
fn test_grid_line_shorthands_reassemble_in_serialization_order() {
	assert declaration_block_text('grid-row-start: 1; grid-row-end: 2')? == 'grid-row: 1 / 2;'
	assert declaration_block_text('grid-row-end: 2; grid-row-start: 1')? == 'grid-row: 1 / 2;'
	assert declaration_block_text('grid-column-start: 1; grid-column-end: 3')? == 'grid-column: 1 / 3;'
	// An `auto` end line is omitted.
	assert declaration_block_text('grid-row-start: span 2; grid-row-end: auto')? == 'grid-row: span 2;'
	assert declaration_block_text('grid-row-start: 1; grid-row-end: 2; grid-column-start: 3; grid-column-end: 4')? ==
		'grid-area: 1 / 3 / 2 / 4;'
	// The directly parsed shorthand keeps working.
	assert serialize_of('1 / 2', PropertyID.grid_row)? == '1 / 2'
	assert serialize_of('1 / 2 / 3 / 4', PropertyID.grid_area)? == '1 / 2 / 3 / 4'
}

// "`border` only has a reasonable value if all four sides are the same." When a
// nested width, style or colour is not uniform the shorthand serializes as the
// empty string and the declaration block falls back to the nested shorthands.
fn test_border_shorthand_requires_uniform_sides() {
	assert declaration_block_text('border: 1px solid red')? ==
		'border: 1px solid red;'
	assert declaration_block_text('border: 1px solid red; border-top-color: blue')? ==
		'border-width: 1px; border-style: solid; border-color: blue red red; border-image: none 100% / 1 / 0 stretch;'
	assert declaration_block_text('border: 1px solid red; border-top-width: 2px')? ==
		'border-width: 2px 1px 1px; border-style: solid; border-color: red; border-image: none 100% / 1 / 0 stretch;'
	assert declaration_block_text('border: 1px solid red; border-top-style: dashed')? ==
		'border-width: 1px; border-style: dashed solid solid; border-color: red; border-image: none 100% / 1 / 0 stretch;'
	// A per-side border shorthand still collapses.
	assert declaration_block_text('border-top-width: 1px; border-top-style: solid; border-top-color: red')? ==
		'border-top: 1px solid red;'
}

// text-decoration prints only what differs from the default, in the fixed order
// line, thickness, style, colour - and prints the line when all are default.
fn test_text_decoration_serializes_in_its_own_order() {
	assert declaration_block_text('text-decoration-line: none; text-decoration-style: solid; text-decoration-color: currentcolor; text-decoration-thickness: auto')? ==
		'text-decoration: none;'
	assert declaration_block_text('text-decoration-line: underline; text-decoration-style: solid; text-decoration-color: red; text-decoration-thickness: auto')? ==
		'text-decoration: underline red;'
	assert serialize_of('underline dotted red', PropertyID.text_decoration)? == 'underline dotted red'
}
