module css

fn test_function_rule_exposes_signature_and_serializes_cssom() {
	length_type := SyntaxNode.create_type('length')
	mode_type := SyntaxNode.create_alternatives([
		SyntaxNode.create_type('length'),
		SyntaxNode.create_ident('auto', false),
	])
	rule := CSSRule.create_function(CSSRuleList.create_empty(), '--scale', [
		FunctionParameterInternal{
			name: '--x'
			type_: length_type
			default_value: parse_component_values_for_value_logic('10px')
		},
		FunctionParameterInternal{
			name: '--mode'
			type_: mode_type
		},
	], SyntaxNode.create_type('number'))

	assert rule.type_ == .function_rule
	assert rule.type_for_bindings() == 0
	assert rule.class_name() == 'CSSFunctionRule'
	assert rule.function_rule_name() == '--scale'
	assert rule.function_return_type_string() == '<number>'
	parameters := rule.get_function_parameters()
	assert parameters.len == 2
	assert parameters[0].name == '--x'
	assert parameters[0].type_ == '<length>'
	assert parameters[0].default_value or { '' } == '10px'
	assert parameters[1].type_ == '<length> | auto'
	assert parameters[1].default_value == none
	assert rule.css_text() == '@function --scale(--x <length>: 10px, --mode type(<length> | auto)) returns <number> { }'
}

fn test_function_rule_omits_universal_types_from_serialization() {
	rule := CSSRule.create_function(CSSRuleList.create_empty(), '--identity', [
		FunctionParameterInternal{
			name: '--value'
			type_: SyntaxNode.create_universal()
		},
	], SyntaxNode.create_universal())

	assert rule.get_function_parameters()[0].type_ == '*'
	assert rule.function_return_type_string() == '*'
	assert rule.css_text() == '@function --identity(--value) { }'
}
