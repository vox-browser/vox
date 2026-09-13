module css

fn test_short_math_display_is_inline_and_uses_short_serialization() {
	display := Display.from_short(.math)

	assert display.is_inline_outside()
	assert display.is_math_inside()
	assert display.to_string() == 'math'
	assert Display.from_outside_inside(.block, .math).to_string() == 'block math'
}

fn test_parsed_math_display_serializes_as_math() {
	parsed := parse_css_value_logic(.display, 'math') or { panic('display: math did not parse') }
	assert parsed is DisplayStyleValue
	assert parsed.serialize(.normal) == 'math'
}

struct DisplayReificationCase {
	source   string
	kind     CSSStyleValueKind
	expected string
}

fn test_display_typed_om_reification_uses_keywords_when_possible() {
	cases := [
		DisplayReificationCase{'none', .keyword, 'none'},
		DisplayReificationCase{'block', .keyword, 'block'},
		DisplayReificationCase{'inline', .keyword, 'inline'},
		DisplayReificationCase{'inline-flex', .keyword, 'inline-flex'},
		DisplayReificationCase{'table-row', .keyword, 'table-row'},
		DisplayReificationCase{'table-cell', .keyword, 'table-cell'},
		DisplayReificationCase{'inline math', .keyword, 'math'},
		DisplayReificationCase{'block flow', .keyword, 'block'},
		DisplayReificationCase{'block flex', .keyword, 'flex'},
		DisplayReificationCase{'inline flow list-item', .style, 'inline list-item'},
	]
	for case in cases {
		reified := CSSStyleValue.parse('display', case.source) or {
			panic('display: ${case.source} did not parse')
		}
		assert reified.kind_ == case.kind
		assert reified.to_string() or { panic('${err}') } == case.expected
	}
}
