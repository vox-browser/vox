module css

fn parsed_property_text(property PropertyID, text string) ?string {
	value := parse_css_value(ParsingParams{}, text, property) or { return none }
	return value.css_text
}

fn computed_position_area_text(text string) ?string {
	parsed := parse_css_value(ParsingParams{}, text, .position_area) or { return none }
	return StyleComputer.compute_position_area(parsed).css_text
}

fn test_position_area_validates_axes_and_canonicalizes_axis_order() {
	assert parsed_property_text(.position_area, 'left top')? == 'left top'
	assert parsed_property_text(.position_area, 'top left')? == 'left top'
	assert parsed_property_text(.position_area, 'inline-end block-start')? == 'block-start inline-end'
	assert parsed_property_text(.position_area, 'center left')? == 'left center'

	assert parsed_property_text(.position_area, 'left right') == none
	assert parsed_property_text(.position_area, 'top bottom') == none
	assert parsed_property_text(.position_area, 'block-start block-end') == none
	assert parsed_property_text(.position_area, 'left top center') == none
}

fn test_position_area_omits_implied_span_all() {
	assert parsed_property_text(.position_area, 'left span-all')? == 'left'
	assert parsed_property_text(.position_area, 'span-all top')? == 'top'
	assert parsed_property_text(.position_area, 'start span-all')? == 'start span-all'
}

fn test_position_area_computed_value_uses_short_logical_keywords() {
	assert computed_position_area_text('block-start inline-end')? == 'start end'
	assert computed_position_area_text('self-block-end self-inline-start')? == 'self-end self-start'
	assert computed_position_area_text('span-all start')? == 'inline-start'
	assert computed_position_area_text('end span-all')? == 'block-end'
	assert computed_position_area_text('left top')? == 'left top'
}

fn test_position_try_tactics_reject_duplicates_and_preserve_grammar_order() {
	assert parsed_property_text(.position_try_fallbacks, 'flip-inline flip-block')? == 'flip-inline flip-block'
	assert parsed_property_text(.position_try_fallbacks, '--fallback flip-start flip-block')? == '--fallback flip-start flip-block'
	assert parsed_property_text(.position_try_fallbacks, 'flip-start --fallback')? == '--fallback flip-start'
	assert parsed_property_text(.position_try_fallbacks, 'left top, --fallback flip-inline')? == 'left top, --fallback flip-inline'

	assert parsed_property_text(.position_try_fallbacks, 'flip-block flip-block') == none
	assert parsed_property_text(.position_try_fallbacks, 'flip-inline flip-inline') == none
	assert parsed_property_text(.position_try_fallbacks, 'flip-start flip-start') == none
}
