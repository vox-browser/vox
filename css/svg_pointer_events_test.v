module css

fn test_svg_pointer_events_parse_serialize_and_compute_every_value() {
	for text, expected in {
		'auto':           'auto_'
		'none':           'none_'
		'all':            'all'
		'bounding-box':   'bounding_box'
		'visiblePainted': 'visible_painted'
		'visibleFill':    'visible_fill'
		'visibleStroke':  'visible_stroke'
		'visible':        'visible'
		'painted':        'painted'
		'fill':           'fill'
		'stroke':         'stroke'
	} {
		value := parse_css_value(ParsingParams{}, text, .pointer_events) or { panic('pointer-events: ' + text) }
		assert value.css_text == text.to_lower()
		mut computed := ComputedProperties.new()
		computed.set_property(.pointer_events, value, .no, .no)
		assert computed.pointer_events().str() == expected, text
	}
}

fn test_svg_pointer_events_keywords_round_trip_without_affecting_other_properties() {
	for text in ['bounding-box', 'visiblepainted', 'visiblefill', 'visiblestroke', 'painted'] {
		keyword := keyword_from_string(text.to_upper()) or { panic(text) }
		assert string_from_keyword(keyword) == text
		assert parse_css_value(ParsingParams{}, text, .visibility) == none
	}
}

fn test_svg_pointer_events_reject_invalid_values() {
	for text in ['visible-painted', 'boundingbox', 'painted stroke', 'visible fill', 'all none',
		'0', '"fill"'] {
		assert parse_css_value(ParsingParams{}, text, .pointer_events) == none, text
	}
}
