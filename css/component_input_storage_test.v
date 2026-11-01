module css

import platform

fn test_streamed_component_input_keeps_owned_nested_values_and_unterminated_rule_eof() {
	mut source_arena := platform.new_arena('component lookahead source')
	entry := source_arena.enter()
	source := '.first{--nested:fn([one], "日本語");width:calc(10px + 2em)}.last{height:17px'.clone()
	source_arena.leave(entry)
	mut array_parser := RuleSelectorParser.create(ParsingParams{},source,'utf-8')
	expected := array_parser.parse_as_css_stylesheet(none,none)
	actual := parse_css_stylesheet_with_parser(source,none)
	source_arena.release()
	assert actual.css_rules().rules.len == 2
	for index in 0 .. 2 {
		assert actual.css_rules().rules[index].css_text() == expected.css_rules().rules[index].css_text()
	}
	mut declaration := actual.css_rules().rules[0].style() or { panic('missing first declaration') }
	assert declaration.get_property_value('--nested') == 'fn([one], "日本語")'
	assert declaration.get_property_value('width') == 'calc(10px + 2em)'
	assert actual.css_rules().rules[1].style()?.get_property_value('height') == '17px'
	declaration.set_property('--nested','fn([two], "Ещё")','') or { panic(err) }
	assert declaration.get_property_value('--nested') == 'fn([two], "Ещё")'
	assert expected.css_rules().rules[0].style()?.get_property_value('--nested') == 'fn([one], "日本語")'
}
