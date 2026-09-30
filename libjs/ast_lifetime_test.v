module libjs

fn test_retained_ast_children_survive_nested_functions_and_later_parses() {
	parsed := parse_source('function outer(x) { const f = y => x + y; return f(123); }\nfunction later() { return "saved"; }', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	for _ in 0 .. 10 {
		assert !parse_source('function other() { return 987; }', .script).has_errors()
	}
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('BinaryExpression (+)'), ast_text
	assert ast_text.contains('Identifier "x"'), ast_text
	assert ast_text.contains('Identifier "y"'), ast_text
	assert ast_text.contains('NumericLiteral 123'), ast_text
	assert ast_text.contains('StringLiteral "saved"'), ast_text
	assert !ast_text.contains('987'), ast_text
}

fn test_retained_class_method_ast_keeps_identifier_and_call_children() {
	parsed := parse_source('var C = class MyClass { method() { return MyClass; } };\nfunction uses_class() { class Foo { method() { return new Foo(); } } return new Foo(); }', .script)
	assert !parsed.has_errors(), '${parsed.diagnostics}'
	ast_text := parsed.dump_ast()!
	assert ast_text.contains('Identifier "MyClass"'), ast_text
	assert ast_text.contains('Identifier "Foo"'), ast_text
	assert ast_text.contains('NewExpression'), ast_text
}

fn test_tagged_template_wrapping_retains_the_previous_expression_without_a_cycle() {
	for text in ['class Foo extends Bar`hello` {}', 'const value = first`x``y`;'] {
		parsed := parse_source(text, .script)
		assert !parsed.has_errors(), '${parsed.diagnostics}'
		ast_text := parsed.dump_ast()!
		assert ast_text.contains('TaggedTemplateLiteral'), ast_text
		assert ast_text.contains('Identifier'), ast_text
	}
}
