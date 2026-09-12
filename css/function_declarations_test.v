module css

fn test_function_declarations_expose_descriptors_as_a_rule() {
	parsed := parse_css_descriptor_declaration_block(ParsingParams{}, .function_rule, 'result: var(--value); --value: 12px')
	descriptors := CSSFunctionDescriptors.create(parsed)
	declarations := CSSRule.create_function_declarations(descriptors)

	assert declarations.type_ == .function_declarations
	assert declarations.class_name() == 'CSSFunctionDeclarations'
	assert declarations.css_text() == 'result: var(--value); --value: 12px;'
	style := declarations.function_declarations_style() or { panic('missing descriptor style') }
	assert style == descriptors
	assert style.base.parent_rule or { panic('missing parent rule') } == declarations
}

fn test_function_rule_serializes_function_declaration_children() {
	descriptors := CSSFunctionDescriptors.create(parse_css_descriptor_declaration_block(ParsingParams{}, .function_rule, 'result: 24px'))
	declarations := CSSRule.create_function_declarations(descriptors)
	function_rule := CSSRule.create_function(CSSRuleList.create([declarations]), '--size', []FunctionParameterInternal{}, SyntaxNode.create_universal())

	assert declarations.parent_rule or { panic('missing function parent') } == function_rule
	assert function_rule.css_text() == '@function --size() { result: 24px; }'
}
