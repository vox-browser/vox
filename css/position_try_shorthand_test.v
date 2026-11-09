module css

fn test_position_try_shorthand_parses_serializes_and_expands() {
	for text, expected in {'flip-inline':'flip-inline','flip-y':'flip-y','most-height none':'most-height none',
		'normal none':'none','normal --foo':'--foo','most-width flip-y flip-x, --foo, --bar':'most-width flip-y flip-x, --foo, --bar'} {
		parsed := parse_css_value_logic(.position_try,text) or { panic(text) }
		assert parsed.serialize(.normal) == expected,parsed.serialize(.normal)
		mut declaration := CSSStyleProperties.create()
		declaration.set_property('position-try',text,'')!
		assert declaration.get_property_value('position-try') == expected
		assert declaration.get_property_value('position-try-order') == if text.starts_with('most-') { text.split(' ')[0] } else { 'normal' }
	}
	for text in ['normal --foo, most-width --bar','none normal','flip-block most-height','most-height, flip-start','flip-x flip-x'] {
		assert parse_css_value_logic(.position_try,text) == none,text
	}
}
