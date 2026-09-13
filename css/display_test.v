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

fn test_display_keyword_typed_om_values_use_display_internal_representation() {
	property := PropertyNameAndID.from_name('display') or { panic('missing display property') }
	for keyword in ['none', 'block', 'inline-flex', 'table-row', 'math'] {
		internal := CSSKeywordValue.create(keyword).create_an_internal_representation(property, .yes) or {
			panic('display keyword ${keyword} was rejected')
		}
		assert internal is DisplayStyleValue
		assert internal.serialize(.normal) == Display.from_keyword(keyword_from_string(keyword) or {
			panic('missing keyword ${keyword}')
		}).to_string()
	}
}

fn test_display_none_from_typed_om_survives_computed_style_storage() {
	mut declaration := CSSStyleProperties.create()
	mut style_map := MutableStylePropertyMap.create(declaration)
	style_map.set('display', [MutableStylePropertyMapValue(CSSStyleValue.from_keyword(
		CSSKeywordValue.create('none'),
	))])!
	stored := declaration_style_properties(declaration)
	assert stored.len == 1
	internal := style_value_logic_from_dom(.display, stored[0].value) or {
		panic('stored display value was not typed')
	}
	assert internal is DisplayStyleValue
	mut computed := computed_properties_with_initial_values()
	computed.set_property(.display, stored[0].value, .no, .no)

	assert computed.display().is_none()
}
