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

fn test_literal_payloads_keep_their_own_data_after_parser_frames_are_reused() {
	parsed := parse_source('const re=/persistent/g;const t=tag`first\${42}last`;class C{#key;read(){return this.#key}}', .script)
	assert !parsed.has_errors()
	before := parsed.dump_ast()!
	for _ in 0 .. 30 {
		assert !parse_source('const re=/noise/i;const t=tag`other\${1}tail`;class D{#noise;read(){return this.#noise}}', .script).has_errors()
	}
	after := parsed.dump_ast()!
	assert after == before
	assert after.contains('persistent') && after.contains('first') && after.contains('#key')
	assert !after.contains('noise')
}

fn test_retained_regexp_literal_can_compile_after_its_defining_call_returns() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function make(){return ()=>/persistent/g.test("persistent")};make()', vm.realm(), 'retained-literal.js', unsafe { nil })!
	function := vm.run(mut script)!
	for _ in 0 .. 30 { assert !parse_source('(()=>/noise/i.test(`other`))()', .script).has_errors() }
	assert call(mut vm, function, js_undefined(), [])!.as_bool()
}
