module css

fn test_function_rule_parses_signatures_descriptors_and_conditionals() {
	rule := parse_css_rule_with_params(ParsingParams{}, '@function --scale(--amount <number>: 2, --fallback: 10px) returns type(<length> | auto) { --local: 6px; @media all { result: calc(var(--local) * var(--amount)); } result: var(--fallback); }') or {
		panic('failed to parse function rule')
	}

	assert rule.type_ == .function_rule
	assert rule.function_rule_name() == '--scale'
	assert rule.function_return_type_string() == '<length> | auto'
	parameters := rule.get_function_parameters()
	assert parameters.len == 2
	assert parameters[0].name == '--amount'
	assert parameters[0].type_ == '<number>'
	assert parameters[0].default_value or { '' } == '2'
	assert parameters[1].name == '--fallback'
	assert parameters[1].type_ == '*'
	assert parameters[1].default_value or { '' } == '10px'

	children := rule.css_rules() or { panic('missing function children') }
	assert children.length() == 3
	assert (children.item(0) or { panic('missing declarations') }).type_ == .function_declarations
	media := children.item(1) or { panic('missing media rule') }
	assert media.type_ == .media
	media_children := media.css_rules() or { panic('missing media children') }
	assert (media_children.item(0) or { panic('missing conditional declarations') }).type_ == .function_declarations
	assert (children.item(2) or { panic('missing trailing declarations') }).type_ == .function_declarations
	assert rule.css_text() == '@function --scale(--amount <number>: 2, --fallback: 10px) returns type(<length> | auto) { --local: 6px; @media all {\n  result: calc(var(--local) * var(--amount));\n} result: var(--fallback); }'
}

fn test_function_rule_rejects_invalid_preludes() {
	invalid_rules := [
		'@function foo() {}',
		'@function --() {}',
		'@function --foo {}',
		'@function --foo(--x, nope) {}',
		'@function --foo(--x <dino>) {}',
		'@function --foo(--x <length>: 10deg) {}',
		'@function --foo() returns {}',
		'@function --foo() trailing {}',
		'@function --foo();',
	]
	for source in invalid_rules {
		assert parse_css_rule_with_params(ParsingParams{}, source) == none, source
	}
}

fn test_function_rule_rejects_non_conditional_child_rules() {
	rule := parse_css_rule_with_params(ParsingParams{}, '@function --foo() { @layer nested { result: bad; } @supports (display: block) { result: good; } }') or {
		panic('failed to parse function rule')
	}
	children := rule.css_rules() or { panic('missing function children') }

	assert children.length() == 1
	assert (children.item(0) or { panic('missing supports rule') }).type_ == .supports
}
