module css

fn test_conditional_rules_can_create_function_declarations() {
	mut parser := RuleSelectorParser.create(ParsingParams{
		rule_context: [.function_rule]
	}, '@media all { result: 12px; --local: red }', 'utf-8')
	mut input := parser.token_stream
	raw_rule := parser.parse_a_rule(mut input, .yes) or { panic('failed to parse raw media rule') }
	media_rule := parser.convert_to_rule(raw_rule, .yes, .function_rule) or {
		panic('failed to convert media rule')
	}

	children := media_rule.css_rules() or { panic('missing media children') }
	assert children.length() == 1
	declarations := children.item(0) or { panic('missing declarations') }
	assert declarations.type_ == .function_declarations
	assert declarations.css_text() == 'result: 12px; --local: red;'
}

fn test_conditional_rules_keep_style_declarations_in_style_contexts() {
	mut parser := RuleSelectorParser.create(ParsingParams{
		rule_context: [.style]
	}, '@media all { color: red }', 'utf-8')
	mut input := parser.token_stream
	raw_rule := parser.parse_a_rule(mut input, .yes) or { panic('failed to parse raw media rule') }
	media_rule := parser.convert_to_rule(raw_rule, .yes, .style) or {
		panic('failed to convert media rule')
	}

	children := media_rule.css_rules() or { panic('missing media children') }
	declarations := children.item(0) or { panic('missing declarations') }
	assert declarations.type_ == .nested_declarations
}
