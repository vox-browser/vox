module libjs


// =============================================================================
// Helper
// =============================================================================

fn parse_script(source string) (Statement, Parser) {
	src := utf16(source)
	mut parser := Parser.new(src, .script)
	program := parser.parse_program(false)
	parser.scope_collector.analyze(false)
	return program, parser
}

// =============================================================================
// 1. Lexer tests
// =============================================================================

fn test_lexer_simple_expression() {
	src := utf16('1 + 2')
	mut lexer := Lexer.new(src, 1, 0)

	t1 := lexer.next()
	assert t1.token_type == .numeric_literal

	t2 := lexer.next()
	assert t2.token_type == .plus

	t3 := lexer.next()
	assert t3.token_type == .numeric_literal

	t4 := lexer.next()
	assert t4.token_type == .eof
}

fn test_lexer_keywords_vs_identifiers() {
	src := utf16('let foo if bar')
	mut lexer := Lexer.new(src, 1, 0)

	t1 := lexer.next()
	assert t1.token_type == .let_kw

	t2 := lexer.next()
	assert t2.token_type == .identifier

	t3 := lexer.next()
	assert t3.token_type == .if_kw

	t4 := lexer.next()
	assert t4.token_type == .identifier

	t5 := lexer.next()
	assert t5.token_type == .eof
}

fn test_lexer_string_and_numeric_literals() {
	src := utf16('"hello" 42 3.14')
	mut lexer := Lexer.new(src, 1, 0)

	t1 := lexer.next()
	assert t1.token_type == .string_literal

	t2 := lexer.next()
	assert t2.token_type == .numeric_literal

	t3 := lexer.next()
	assert t3.token_type == .numeric_literal

	t4 := lexer.next()
	assert t4.token_type == .eof
}

fn test_lexer_operators_and_punctuation() {
	src := utf16('=> === !== { } ( )')
	mut lexer := Lexer.new(src, 1, 0)

	t1 := lexer.next()
	assert t1.token_type == .arrow

	t2 := lexer.next()
	assert t2.token_type == .equals_equals_equals

	t3 := lexer.next()
	assert t3.token_type == .exclamation_mark_equals_equals

	t4 := lexer.next()
	assert t4.token_type == .curly_open

	t5 := lexer.next()
	assert t5.token_type == .curly_close

	t6 := lexer.next()
	assert t6.token_type == .paren_open

	t7 := lexer.next()
	assert t7.token_type == .paren_close

	t8 := lexer.next()
	assert t8.token_type == .eof
}

fn test_lexer_eof_on_empty() {
	src := utf16('')
	mut lexer := Lexer.new(src, 1, 0)

	t := lexer.next()
	assert t.token_type == .eof
}

// =============================================================================
// 2. Parser tests
// =============================================================================

fn test_parse_numeric_literal() {
	program, _ := parse_script('42;')
	assert program.kind.tag == .program

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	stmt := children[0]
	assert stmt.kind.tag == .expression_stmt

	expr := stmt.kind.expression or { panic('no expression') }
	assert expr.kind.tag == .numeric_literal
	assert expr.kind.numeric_value == 42.0
}

fn test_parse_string_literal() {
	program, _ := parse_script('"hello";')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	stmt := children[0]
	assert stmt.kind.tag == .expression_stmt

	expr := stmt.kind.expression or { panic('no expression') }
	assert expr.kind.tag == .string_literal
	assert expr.kind.string_value.str() == 'hello'
}

fn test_parse_boolean_true() {
	program, _ := parse_script('true;')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	expr := children[0].kind.expression or { panic('') }
	assert expr.kind.tag == .boolean_literal
	assert expr.kind.bool_value == true
}

fn test_parse_boolean_false() {
	program, _ := parse_script('false;')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	expr := children[0].kind.expression or { panic('') }
	assert expr.kind.tag == .boolean_literal
	assert expr.kind.bool_value == false
}

fn test_parse_null_literal() {
	program, _ := parse_script('null;')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	expr := children[0].kind.expression or { panic('') }
	assert expr.kind.tag == .null_literal
}

fn test_parse_variable_declarations() {
	program, _ := parse_script('let x = 1; const y = 2; var z = 3;')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 3

	// let
	assert children[0].kind.tag == .variable_declaration
	assert children[0].kind.decl_kind == .let_kind

	// const
	assert children[1].kind.tag == .variable_declaration
	assert children[1].kind.decl_kind == .const_kind

	// var
	assert children[2].kind.tag == .variable_declaration
	assert children[2].kind.decl_kind == .var_kind
}

fn test_parse_binary_expression_precedence() {
	// 1 + 2 * 3  should parse as  1 + (2 * 3)
	program, _ := parse_script('1 + 2 * 3;')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	expr := children[0].kind.expression or { panic('') }
	assert expr.kind.tag == .binary

	// lhs is 1 (numeric)
	lhs := expr.kind.lhs or { panic('no lhs') }
	assert lhs.kind.tag == .numeric_literal
	assert lhs.kind.numeric_value == 1.0

	// rhs is 2 * 3 (another binary)
	rhs := expr.kind.rhs or { panic('no rhs') }
	assert rhs.kind.tag == .binary

	rhs_lhs := rhs.kind.lhs or { panic('') }
	assert rhs_lhs.kind.numeric_value == 2.0
	rhs_rhs := rhs.kind.rhs or { panic('') }
	assert rhs_rhs.kind.numeric_value == 3.0
}

fn test_parse_function_declaration() {
	program, parser := parse_script('function foo(a, b) { return a + b; }')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	stmt := children[0]
	assert stmt.kind.tag == .function_declaration

	fname := stmt.kind.func_name or { panic('no func_name') }
	assert fname.name.str() == 'foo'

	func_data := parser.function_table.get(stmt.kind.function_id)
	assert func_data.parameters.len == 2
	assert func_data.is_arrow_function == false
}

fn test_parse_arrow_function() {
	program, parser := parse_script('const f = (x) => x + 1;')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1
	assert children[0].kind.tag == .variable_declaration

	decl := children[0].kind.declarations[0]
	init := decl.init or { panic('no init') }
	assert init.kind.tag == .function_expr

	func_data := parser.function_table.get(init.kind.function_id)
	assert func_data.is_arrow_function == true
	assert func_data.parameters.len == 1
}

fn test_parse_if_else() {
	program, _ := parse_script('if (true) { 1; } else { 2; }')

	pd := program.kind.program_data or { panic('no program_data') }
	children := pd.scope.children
	assert children.len == 1

	stmt := children[0]
	assert stmt.kind.tag == .if_stmt

	// test expression
	test_expr := stmt.kind.test or { panic('no test') }
	assert test_expr.kind.tag == .boolean_literal

	// consequent
	consequent := stmt.kind.consequent or { panic('no consequent') }
	assert consequent.kind.tag == .block

	// alternate
	alternate := stmt.kind.alternate or { panic('no alternate') }
	assert alternate.kind.tag == .block
}

fn test_parse_for_loops() {
	// classic for — may be wrapped in a block scope
	p1, _ := parse_script('for (var i = 0; i < 10; i++) {}')
	pd1 := p1.kind.program_data or { panic('') }
	top1 := pd1.scope.children[0]
	if top1.kind.tag == .block {
		scope1 := top1.kind.scope or { panic('') }
		mut found_for := false
		for c in scope1.children {
			if c.kind.tag == .for_stmt {
				found_for = true
			}
		}
		assert found_for
	} else {
		assert top1.kind.tag == .for_stmt
	}

	// for-in
	p2, _ := parse_script('for (var k in obj) {}')
	pd2 := p2.kind.program_data or { panic('') }
	top2 := pd2.scope.children[0]
	if top2.kind.tag == .block {
		scope2 := top2.kind.scope or { panic('') }
		mut found := false
		for c in scope2.children {
			if c.kind.tag == .for_in_of {
				found = true
			}
		}
		assert found
	} else {
		assert top2.kind.tag == .for_in_of
	}

	// for-of
	p3, _ := parse_script('for (var v of arr) {}')
	pd3 := p3.kind.program_data or { panic('') }
	top3 := pd3.scope.children[0]
	if top3.kind.tag == .block {
		scope3 := top3.kind.scope or { panic('') }
		mut found := false
		for c in scope3.children {
			if c.kind.tag == .for_in_of {
				found = true
			}
		}
		assert found
	} else {
		assert top3.kind.tag == .for_in_of
	}
}

fn test_parse_class_declaration() {
	program, parser := parse_script('class Foo { constructor(x) { this.x = x; } }')

	pd := program.kind.program_data or { panic('') }
	children := pd.scope.children
	assert children.len == 1
	assert children[0].kind.tag == .class_declaration

	cdata := children[0].kind.class_data or { panic('no class_data') }
	assert cdata.name != none
}

fn test_parse_error_unterminated_string() {
	src := utf16('"hello')
	mut parser := Parser.new(src, .script)
	_ := parser.parse_program(false)
	assert parser.has_errors() == true
}

fn test_parse_nested_scopes() {
	program, _ := parse_script('{ let x = 1; { let y = 2; } }')

	pd := program.kind.program_data or { panic('') }
	children := pd.scope.children
	assert children.len == 1
	assert children[0].kind.tag == .block

	scope := children[0].kind.scope or { panic('no scope') }
	// inner block creates child with its own scope
	assert scope.children.len >= 2 // let x = 1, and inner block
}

// =============================================================================
// 3. AST dump snapshot tests
// =============================================================================

fn test_dump_variable_declaration() {
	program, parser := parse_script('let x = 42;')
	output := dump_program_to_string(&program, &parser.function_table)
	assert output.contains('VariableDeclaration')
	assert output.contains('NumericLiteral')
}

fn test_dump_function_declaration() {
	program, parser := parse_script('function greet(name) { return name; }')
	output := dump_program_to_string(&program, &parser.function_table)
	assert output.contains('FunctionDeclaration')
	assert output.contains('greet')
	assert output.contains('name')
}

fn test_dump_binary_expression() {
	program, parser := parse_script('1 + 2;')
	output := dump_program_to_string(&program, &parser.function_table)
	assert output.contains('BinaryExpression')
	assert output.contains('NumericLiteral')
}
