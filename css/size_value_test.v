module css

fn parsed_size(property_id PropertyID, text string) Size {
	value := parse_css_value_logic(property_id, text) or { panic('could not parse ${text}') }
	return Size.from_style_value(value)
}

fn test_size_from_style_value_converts_keywords() {
	assert parsed_size(.width, 'auto').is_auto()
	assert parsed_size(.width, 'min-content').is_min_content()
	assert parsed_size(.width, 'max-content').is_max_content()
	assert parsed_size(.max_width, 'none').is_none()
}

fn test_size_from_style_value_converts_scalar_sizes() {
	length := parsed_size(.width, '12px')
	assert length.is_length()
	assert length.length() == Length.make_px(12)

	percentage := parsed_size(.width, '37.5%')
	assert percentage.is_percentage()
	assert percentage.percentage() == Percentage.new(37.5)

	calculated := parsed_size(.width, 'calc(10px + 5%)')
	assert calculated.is_calculated()
	assert calculated.contains_percentage()
}

fn test_size_from_style_value_converts_fit_content() {
	parsed_keyword := parse_css_value_logic(.width, 'fit-content') or { panic('missing fit-content') }
	assert parsed_keyword is KeywordStyleValue
	assert parsed_keyword.to_keyword() == .fit_content
	keyword := parsed_size(.width, 'fit-content')
	assert keyword.is_fit_content()
	assert keyword.fit_content_available_space() == none
	assert keyword.serialize(.normal) == 'fit-content'

	parsed_function := parse_css_value_logic(.width, 'fit-content(25%)') or {
		panic('missing fit-content function')
	}
	assert parsed_function is FunctionStyleValue
	assert (parsed_function as FunctionStyleValue).name() == 'fit-content'
	function := Size.from_style_value(parsed_function)
	assert function.is_fit_content()
	available_space := function.fit_content_available_space() or { panic('missing available space') }
	assert available_space.is_percentage()
	assert available_space.percentage() == Percentage.new(25)
	assert function.serialize(.normal) == 'fit-content(25%)'
}

fn test_cssom_size_conversion_uses_keyword_and_generic_fit_content_values() {
	bare := style_value_logic_from_dom(.width, cssom_style_value_for_size(Size.make_fit_content_without_available_space())) or {
		panic('bare fit-content did not round-trip through CSSOM')
	}
	assert bare is KeywordStyleValue
	assert bare.to_keyword() == .fit_content

	with_space := style_value_logic_from_dom(.width, cssom_style_value_for_size(Size.make_fit_content(LengthPercentage.from_percentage(Percentage.new(30))))) or {
		panic('fit-content function did not round-trip through CSSOM')
	}
	assert with_space is FunctionStyleValue
	assert (with_space as FunctionStyleValue).name() == 'fit-content'
	assert with_space.serialize(.normal) == 'fit-content(30%)'
}

fn test_size_from_style_value_defers_anchor_size() {
	anchor := parsed_size(.width, 'anchor-size(width, 10px)')
	assert anchor.is_none()
}
