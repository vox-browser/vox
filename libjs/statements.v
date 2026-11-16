module libjs

// Statement parsing: if, for, while, switch, try, etc.
//
// Translated from statements.rs.

// Used locally during for-statement parsing before converting to ast ForInit.
type LocalForInit = LocalForInitDeclaration | LocalForInitExpression

struct LocalForInitDeclaration {
	statement Statement
}

struct LocalForInitExpression {
	expression Expression
}

fn (mut p Parser) parse_statement(allow_labelled_function bool) Statement {
	if !p.enter_recursion() {
		return p.statement(p.position(), StatementKind{ tag: .error_stmt })
	}
	defer {
		p.leave_recursion()
	}
	start := p.position()
	tt := p.current_token_type()

	return match tt {
		.curly_open {
			p.parse_block_statement()
		}
		.return_kw {
			p.parse_return_statement()
		}
		.var_kw {
			p.parse_variable_declaration(false)
		}
		.for_kw {
			p.parse_for_statement()
		}
		.if_kw {
			p.parse_if_statement()
		}
		.throw_kw {
			p.parse_throw_statement()
		}
		.try_kw {
			p.parse_try_statement()
		}
		.break_kw {
			p.parse_break_statement()
		}
		.continue_kw {
			p.parse_continue_statement()
		}
		.switch_kw {
			p.parse_switch_statement()
		}
		.do_kw {
			p.parse_do_while_statement()
		}
		.while_kw {
			p.parse_while_statement()
		}
		.with_kw {
			if p.flags.strict_mode {
				p.syntax_error("'with' statement not allowed in strict mode")
			}
			p.parse_with_statement()
		}
		.debugger {
			p.parse_debugger_statement()
		}
		.semicolon {
			p.consume()
			p.statement(start, StatementKind{
				tag: .empty
			})
		}
		.slash, .slash_equals {
			forced_token := p.lexer.force_slash_as_regex()
			p.current_token = forced_token
			p.parse_expression_statement()
		}
		else {
			if p.match_invalid_escaped_keyword() {
				p.syntax_error('Keyword must not contain escaped characters')
			}
			if p.match_identifier_name() {
				if labelled := p.try_parse_labelled_statement(allow_labelled_function) {
					return labelled
				}
			}
			if p.match_expression() {
				p.parse_expression_statement()
			} else {
				p.expected('statement')
				p.consume()
				p.statement(start, StatementKind{
					tag: .empty
				})
			}
		}
	}
}

fn (mut p Parser) parse_block_statement() Statement {
	start := p.position()
	p.consume_token(.curly_open)

	p.scope_collector.open_block_scope()

	mut children := []Statement{}

	for !p.match_token(.curly_close) && !p.done() {
		if p.match_declaration() {
			children << p.parse_declaration()
		} else {
			children << p.parse_statement(true)
		}
	}

	p.consume_token(.curly_close)
	scope := ScopeData.shared_with_children(children)
	p.scope_collector.set_scope_node(scope)
	p.scope_collector.close_scope()
	return p.statement(start, StatementKind{
		tag:   .block
		scope: scope
	})
}

fn (mut p Parser) parse_expression_statement() Statement {
	start := p.position()

	if p.match_token(.async) {
		lookahead := p.next_token()
		if lookahead.token_type == .function_kw && !lookahead.trivia_has_line_terminator {
			p.syntax_error('Async function declaration not allowed in single-statement context')
		}
	} else if p.match_token(.function_kw) || p.match_token(.class_kw) {
		name := p.current_token.token_type.name()
		p.syntax_error('${name} declaration not allowed in single-statement context')
	} else if p.match_token(.let_kw) && p.next_token().token_type == .bracket_open {
		p.syntax_error('let followed by [ is not allowed in single-statement context')
	}

	expression := p.parse_expression_any()
	p.consume_or_insert_semicolon()
	return p.statement(start, StatementKind{
		tag:        .expression_stmt
		expression: &expression
	})
}

// https://tc39.es/ecma262/#sec-return-statement
fn (mut p Parser) parse_return_statement() Statement {
	start := p.position()
	if !p.flags.in_function_context {
		p.syntax_error("'return' not allowed outside of a function")
	}
	p.consume_token(.return_kw)

	// [no LineTerminator here]
	if p.current_token.trivia_has_line_terminator {
		return p.statement(start, StatementKind{
			tag: .return_stmt
		})
	}
	if p.match_token(.semicolon) || p.match_token(.curly_close) || p.done() {
		p.consume_or_insert_semicolon()
		return p.statement(start, StatementKind{
			tag: .return_stmt
		})
	}

	argument := p.parse_expression_any()
	p.consume_or_insert_semicolon()
	return p.statement(start, StatementKind{
		tag:        .return_stmt
		return_arg: &argument
	})
}

// https://tc39.es/ecma262/#sec-throw-statement
fn (mut p Parser) parse_throw_statement() Statement {
	start := p.position()
	p.consume_token(.throw_kw)

	if p.current_token.trivia_has_line_terminator {
		p.syntax_error("No line break is allowed between 'throw' and its expression")
	}

	argument := p.parse_expression_any()
	p.consume_or_insert_semicolon()
	return p.statement(start, StatementKind{
		tag:        .throw_stmt
		throw_expr: &argument
	})
}

// https://tc39.es/ecma262/#sec-break-statement
fn (mut p Parser) parse_break_statement() Statement {
	start := p.position()
	p.consume_token(.break_kw)

	mut label := ?Utf16String(none)
	if p.match_token(.semicolon) {
		p.consume()
	} else if !p.current_token.trivia_has_line_terminator && !p.match_token(.curly_close)
		&& !p.done() && p.match_identifier() {
		lbl_token := p.consume()
		label_value := Utf16String.from_slice(p.token_value(lbl_token))

		label_key := label_value.str()
		if label_key !in p.labels_in_scope {
			label_str := string_from_utf16_lossy(label_value.data)
			p.syntax_error("Label '${label_str}' not found")
		}

		p.consume_or_insert_semicolon()
		label = label_value
	} else {
		p.consume_or_insert_semicolon()
	}

	if label == none && !p.flags.in_break_context {
		p.syntax_error("Unlabeled 'break' not allowed outside of a loop or switch statement")
	}

	return p.statement(start, StatementKind{
		tag:          .break_stmt
		target_label: label
	})
}

// https://tc39.es/ecma262/#sec-continue-statement
fn (mut p Parser) parse_continue_statement() Statement {
	start := p.position()
	if !p.flags.in_continue_context {
		p.syntax_error("'continue' not allowed outside of a loop")
	}
	p.consume_token(.continue_kw)

	mut label := ?Utf16String(none)
	if p.match_token(.semicolon) {
		// no label
	} else if !p.current_token.trivia_has_line_terminator && !p.match_token(.curly_close)
		&& !p.done() && p.match_identifier() {
		label_line := p.current_token.line_number
		label_col := p.current_token.line_column
		lbl_token := p.consume()
		label_value := Utf16String.from_slice(p.token_value(lbl_token))

		label_key := label_value.str()
		if label_key in p.labels_in_scope {
			p.labels_in_scope[label_key] = LabelValue{
				has_continue: true
				line:         label_line
				col:          label_col
			}
		} else {
			label_str := string_from_utf16_lossy(label_value.data)
			p.syntax_error("Label '${label_str}' not found or invalid")
		}

		label = label_value
	}

	p.consume_or_insert_semicolon()

	return p.statement(start, StatementKind{
		tag:          .continue_stmt
		target_label: label
	})
}

fn (mut p Parser) parse_debugger_statement() Statement {
	start := p.position()
	p.consume_token(.debugger)
	p.consume_or_insert_semicolon()
	return p.statement(start, StatementKind{
		tag: .debugger_stmt
	})
}

fn (mut p Parser) parse_if_statement() Statement {
	start := p.position()
	p.consume_token(.if_kw)
	p.consume_token(.paren_open)
	predicate := p.parse_expression_any()
	p.consume_token(.paren_close)

	consequent := if !p.flags.strict_mode && p.match_token(.function_kw) {
		p.parse_function_declaration_as_block_statement(start)
	} else {
		p.parse_statement(false)
	}

	mut alternate := ?&Statement(none)
	if p.match_token(.else_kw) {
		p.consume()
		if !p.flags.strict_mode && p.match_token(.function_kw) {
			mut alt := p.parse_function_declaration_as_block_statement(start)
			alternate = &alt
		} else {
			mut alt := p.parse_statement(false)
			alternate = &alt
		}
	}

	return p.statement(start, StatementKind{
		tag:        .if_stmt
		test:       &predicate
		consequent: &consequent
		alternate:  alternate
	})
}

// Annex B: Parse a function declaration as if wrapped in a synthetic block.
fn (mut p Parser) parse_function_declaration_as_block_statement(if_start Position) Statement {
	start := if_start
	p.scope_collector.open_block_scope()
	declaration := p.parse_function_declaration()
	scope := ScopeData.shared_with_children([declaration])
	p.scope_collector.set_scope_node(scope)
	p.scope_collector.close_scope()
	return p.statement(start, StatementKind{
		tag:   .block
		scope: scope
	})
}

// Parse a statement in a loop body context (break and continue allowed).
fn (mut p Parser) parse_loop_body() Statement {
	break_before := p.flags.in_break_context
	continue_before := p.flags.in_continue_context
	p.flags.in_break_context = true
	p.flags.in_continue_context = true
	body := p.parse_statement(false)
	p.flags.in_break_context = break_before
	p.flags.in_continue_context = continue_before
	return body
}

fn (mut p Parser) parse_while_statement() Statement {
	start := p.position()
	p.consume_token(.while_kw)
	p.consume_token(.paren_open)
	test := p.parse_expression_any()
	p.consume_token(.paren_close)

	body := p.parse_loop_body()

	return p.statement(start, StatementKind{
		tag:  .while_stmt
		test: &test
		body: &body
	})
}

fn (mut p Parser) parse_do_while_statement() Statement {
	start := p.position()
	p.consume_token(.do_kw)

	body := p.parse_loop_body()

	p.consume_token(.while_kw)
	p.consume_token(.paren_open)
	test := p.parse_expression_any()
	p.consume_token(.paren_close)

	// Since ES 2015 a missing semicolon is inserted here.
	p.eat(.semicolon)

	return p.statement(start, StatementKind{
		tag:  .do_while
		test: &test
		body: &body
	})
}

// https://tc39.es/ecma262/#sec-for-statement
// https://tc39.es/ecma262/#sec-for-in-and-for-of-statements
fn (mut p Parser) parse_for_statement() Statement {
	start := p.position()
	p.consume_token(.for_kw)

	// Open for-loop scope (for let/const/using declarations).
	p.scope_collector.open_for_loop_scope()

	is_await := if p.match_token(.await_kw) {
		if !p.flags.await_expression_is_valid {
			p.syntax_error('for-await-of not allowed outside of async context')
		}
		p.consume()
		p.scope_collector.set_contains_await_expression()
		true
	} else {
		false
	}

	p.consume_token(.paren_open)

	if p.match_token(.semicolon) && !is_await {
		p.consume()
		result := p.parse_standard_for_loop(start, none)
		return p.close_for_loop_scope(start, result)
	}

	init_start := p.position()
	init_starts_with_async_keyword := p.match_token(.async)
	is_var_init := p.match_token(.var_kw)
	is_using := p.match_for_using_declaration()
	is_let := p.match_token(.let_kw) && (p.flags.strict_mode || p.try_match_let_declaration())
	is_declaration := is_var_init || is_using || is_let || p.match_token(.const_kw)
	init := if is_using {
		LocalForInit(LocalForInitDeclaration{
			statement: p.parse_using_declaration(true)
		})
	} else if is_declaration {
		LocalForInit(LocalForInitDeclaration{
			statement: p.parse_variable_declaration(true)
		})
	} else {
		forbidden := ForbiddenTokens.with_in()
		LocalForInit(LocalForInitExpression{
			expression: p.parse_expression(precedence_comma, .right, forbidden)
		})
	}

	// Check for in
	if p.match_token(.in_kw) && !is_await {
		// C++ captures ForInStatement position at the `in` keyword.
		forin_start := p.position()
		if is_using {
			p.syntax_error('Using declaration not allowed in for-in loop')
		} else if is_declaration {
			if p.for_loop_declaration_count > 1 {
				p.syntax_error('Multiple declarations not allowed in for..in/of')
			}
			if p.for_loop_declaration_has_init {
				if !(p.for_loop_declaration_is_var && p.for_loop_declaration_count == 1
					&& !p.flags.strict_mode) {
					p.syntax_error('Variable initializer not allowed in for..in/of')
				}
			}
		} else {
			p.validate_for_in_of_lhs(init)
		}
		p.consume()
		rhs := p.parse_expression_any()
		p.consume_token(.paren_close)

		body := p.parse_loop_body()

		lhs := p.synthesize_for_in_of_lhs(init, init_start)
		result := p.statement(forin_start, StatementKind{
			tag:            .for_in_of
			for_in_of_kind: .for_in
			for_in_of_lhs:  lhs
			rhs:            &rhs
			body:           &body
		})
		return p.close_for_loop_scope(start, result)
	}

	// Check for of (keyword must not contain escapes)
	if p.match_identifier_name() {
		value := p.token_original_value(p.current_token)
		if utf16_equals(value, utf16('of')) {
			// C++ captures ForOfStatement position at the `of` keyword.
			forof_start := p.position()
			if is_declaration {
				if p.for_loop_declaration_count > 1 {
					p.syntax_error('Multiple declarations not allowed in for..in/of')
				}
				if p.for_loop_declaration_has_init {
					p.syntax_error('Variable initializer not allowed in for..of')
				}
			} else {
				p.validate_for_in_of_lhs(init)
				if !is_await && init_starts_with_async_keyword {
					if init is LocalForInitExpression {
						if id := init.expression.kind.identifier {
							if utf16_equals(id.name.data, utf16('async')) {
								p.syntax_error('For-of statement may not use async as its assignment target')
							}
						}
					}
				}
				// Check for 'let' as first token in for-of LHS
				match init {
					LocalForInitExpression {
						if init.expression.kind.tag == .member {
							if obj := init.expression.kind.object {
								if obj.kind.tag == .identifier_expr {
									if id := obj.kind.identifier {
										if utf16_equals(id.name.data, utf16('let')) {
											p.syntax_error('For of statement may not start with let.')
										}
									}
								}
							}
						}
					}
					else {}
				}
			}
			p.consume()
			rhs := p.parse_assignment_expression()
			p.consume_token(.paren_close)

			body := p.parse_loop_body()

			lhs := p.synthesize_for_in_of_lhs(init, init_start)
			for_of_kind := if is_await { ForInOfKind.for_await_of } else { ForInOfKind.for_of }
			result := p.statement(forof_start, StatementKind{
				tag:            .for_in_of
				for_in_of_kind: for_of_kind
				for_in_of_lhs:  lhs
				rhs:            &rhs
				body:           &body
			})
			return p.close_for_loop_scope(start, result)
		}
	}

	// Standard for loop — const requires initializer.
	if is_await {
		p.syntax_error("for-await-of statement must use 'of'")
	}
	match init {
		LocalForInitDeclaration {
			if init.statement.kind.tag == .variable_declaration
				&& init.statement.kind.decl_kind == .const_kind {
				for d in init.statement.kind.declarations {
					if d.init == none {
						p.syntax_error('Missing initializer in const declaration')
					}
				}
			}
		}
		else {}
	}

	p.consume_token(.semicolon)
	for_init := match init {
		LocalForInitDeclaration {
			?ForInit(ForInitDeclaration{
				statement: &init.statement
			})
		}
		LocalForInitExpression {
			?ForInit(ForInitExpression{
				expression: &init.expression
			})
		}
	}

	result := p.parse_standard_for_loop(start, for_init)
	return p.close_for_loop_scope(start, result)
}

// Close the for-loop scope and wrap the for-loop statement in a Block with scope data.
fn (mut p Parser) close_for_loop_scope(start Position, inner Statement) Statement {
	scope := ScopeData.shared_with_children([inner])
	p.scope_collector.set_scope_node(scope)
	p.scope_collector.close_scope()
	return p.statement(start, StatementKind{
		tag:   .block
		scope: scope
	})
}

fn (mut p Parser) parse_standard_for_loop(start Position, init ?ForInit) Statement {
	mut test := ?&Expression(none)
	if !p.match_token(.semicolon) {
		mut test_expr := p.parse_expression_any()
		test = &test_expr
	}
	p.consume_token(.semicolon)

	mut update := ?&Expression(none)
	if !p.match_token(.paren_close) {
		mut upd_expr := p.parse_expression_any()
		update = &upd_expr
	}
	p.consume_token(.paren_close)

	body := p.parse_loop_body()

	return p.statement(start, StatementKind{
		tag:      .for_stmt
		for_init: init
		test:     test
		update:   update
		body:     &body
	})
}

// https://tc39.es/ecma262/#sec-with-statement
fn (mut p Parser) parse_with_statement() Statement {
	start := p.position()
	p.consume_token(.with_kw)
	p.consume_token(.paren_open)
	object := p.parse_expression_any()
	p.consume_token(.paren_close)
	p.scope_collector.open_with_scope()
	body := p.parse_statement(false)
	p.scope_collector.close_scope()
	return p.statement(start, StatementKind{
		tag:    .with_stmt
		object: &object
		body:   &body
	})
}

// https://tc39.es/ecma262/#sec-switch-statement
fn (mut p Parser) parse_switch_statement() Statement {
	start := p.position()
	p.consume_token(.switch_kw)
	p.consume_token(.paren_open)
	discriminant := p.parse_expression_any()
	p.consume_token(.paren_close)

	p.consume_token(.curly_open)

	p.scope_collector.open_block_scope()

	break_before := p.flags.in_break_context
	p.flags.in_break_context = true

	mut cases := []SwitchCase{}
	mut has_default := false
	for !p.match_token(.curly_close) && !p.done() {
		case_ := p.parse_switch_case()
		if case_.test == none {
			if has_default {
				p.syntax_error("Multiple 'default' clauses in switch statement")
			}
			has_default = true
		}
		cases << case_
	}

	p.flags.in_break_context = break_before

	p.consume_token(.curly_close)

	scope := ScopeData.new_shared()
	p.scope_collector.set_scope_node(scope)
	p.scope_collector.close_scope()

	return p.statement(start, StatementKind{
		tag:         .switch_stmt
		switch_data: &SwitchStatementData{
			scope:        scope
			discriminant: discriminant
			cases:        cases
		}
	})
}

fn (mut p Parser) parse_switch_case() SwitchCase {
	start := p.position()
	mut test := ?Expression(none)
	if p.match_token(.case_kw) {
		p.consume()
		test = p.parse_expression_any()
	} else if p.match_token(.default_kw) {
		p.consume()
	} else {
		p.expected("'case' or 'default'")
	}

	p.consume_token(.colon)

	mut children := []Statement{}
	for !p.match_token(.curly_close) && !p.match_token(.case_kw) && !p.match_token(.default_kw)
		&& !p.done() {
		if p.match_declaration() {
			children << p.parse_declaration()
		} else {
			children << p.parse_statement(true)
		}
	}

	return SwitchCase{
		range: p.range_from(start)
		scope: ScopeData.shared_with_children(children)
		test:  test
	}
}

// https://tc39.es/ecma262/#sec-try-statement
fn (mut p Parser) parse_try_statement() Statement {
	start := p.position()
	p.consume_token(.try_kw)

	block := p.parse_block_statement()

	mut handler := ?CatchClause(none)
	if p.match_token(.catch_kw) {
		handler = p.parse_catch_clause()
	}

	mut finalizer := ?Statement(none)
	if p.match_token(.finally_kw) {
		p.consume()
		finalizer = p.parse_block_statement()
	}

	if handler == none && finalizer == none {
		p.syntax_error('try statement must have a catch or finally clause')
	}

	return p.statement(start, StatementKind{
		tag:      .try_stmt
		try_data: &TryStatementData{
			block:     block
			handler:   handler
			finalizer: finalizer
		}
	})
}

// https://tc39.es/ecma262/#sec-try-statement
fn (mut p Parser) parse_catch_clause() CatchClause {
	start := p.position()
	p.consume_token(.catch_kw)

	p.scope_collector.open_catch_scope()

	mut parameter := ?CatchBinding(none)
	mut catch_names := []Utf16String{}
	if p.match_token(.paren_open) {
		p.consume()
		if p.match_token(.curly_open) || p.match_token(.bracket_open) {
			pattern := p.parse_binding_pattern()
			bound_names := p.pattern_bound_names.clone()
			p.pattern_bound_names = []BoundName{}
			for bn in bound_names {
				p.check_identifier_name_for_assignment_validity(bn.name.data, false)
				catch_names << bn.name.clone()
			}
			mut bound_name_slices := [][]u16{cap: bound_names.len}
			for bn in bound_names {
				bound_name_slices << bn.name.data
			}
			p.scope_collector.add_catch_parameter_pattern(bound_name_slices)
			for bn in bound_names {
				p.scope_collector.register_identifier(bn.identifier, bn.name.data, none)
			}
			parameter = CatchBindingPattern{
				pattern: pattern
			}
		} else if p.match_identifier() {
			parameter_start := p.position()
			param_token := p.consume()
			value := p.token_value(param_token).clone()
			p.check_identifier_name_for_assignment_validity(value, false)
			id := Identifier.new(p.range_from(parameter_start),
				Utf16String.from_slice(value.clone()))
			p.scope_collector.register_identifier(id, value.clone(), none)
			p.scope_collector.add_catch_parameter_identifier(value, id)
			catch_names << id.name.clone()
			parameter = CatchBindingIdentifier{
				identifier: id
			}
		} else {
			p.expected('catch parameter')
		}
		p.consume_token(.paren_close)
	}

	body := p.parse_block_statement()
	if catch_names.len > 0 {
		if scope := body.kind.scope {
			mut lexical_names := map[string]bool{}
			for child in scope.children {
				match child.kind.tag {
					.variable_declaration, .using_declaration {
						if child.kind.tag == .using_declaration || child.kind.decl_kind != .var_kind {
							for declaration in child.kind.declarations {
								collect_binding_names_from_target(declaration.target, mut lexical_names)
							}
						}
					}
					.function_declaration {
						if name := child.kind.func_name { lexical_names[name.name.str()] = true }
					}
					.class_declaration {
						if data := child.kind.class_data {
							if name := data.name { lexical_names[name.name.str()] = true }
						}
					}
					else {}
				}
			}
			for name in catch_names {
				if name.str() in lexical_names {
					p.syntax_error("Identifier '${name.str()}' already declared as catch parameter")
				}
			}
		}
	}

	p.scope_collector.close_scope()

	return CatchClause{
		range:     p.range_from(start)
		parameter: parameter
		body:      body
	}
}

// https://tc39.es/ecma262/#sec-labelled-statements
fn (mut p Parser) try_parse_labelled_statement(allow_labelled_function bool) ?Statement {
	start := p.position()

	if !p.match_identifier_name() {
		return none
	}

	p.save_state()
	lbl_token := p.consume()
	label := Utf16String.from_slice(p.token_value(lbl_token))

	if !p.match_token(.colon) {
		p.load_state()
		return none
	}
	p.discard_saved_state()
	p.consume() // consume :

	if is_unconditional_reserved_word(label.data) {
		p.syntax_error('Reserved word cannot be used as a label')
	}

	if p.flags.strict_mode && (utf16_equals(label.data, utf16('let'))
		|| is_strict_reserved_word(label.data)) {
		p.syntax_error('Strict mode reserved word is not allowed in label')
	}
	if p.flags.in_generator_function_context && utf16_equals(label.data, utf16('yield')) {
		p.syntax_error("'yield' label is not allowed in generator function context")
	}
	if p.flags.await_expression_is_valid && utf16_equals(label.data, utf16('await')) {
		p.syntax_error("'await' label is not allowed in async function context")
	}

	label_key := label.str()
	if label_key in p.labels_in_scope {
		label_str := string_from_utf16_lossy(label.data)
		p.syntax_error("Label '${label_str}' has already been declared")
	}

	if p.match_token(.function_kw) && (!allow_labelled_function || p.flags.strict_mode) {
		p.syntax_error('Not allowed to declare a function here')
	}
	if p.match_token(.async) {
		next := p.next_token()
		if next.token_type == .function_kw && !next.trivia_has_line_terminator {
			p.syntax_error('Async functions cannot be defined in labelled statements')
		}
	}

	p.labels_in_scope[label_key] = LabelValue{}

	break_before := p.flags.in_break_context
	p.flags.in_break_context = true

	body_starts_iteration := p.match_iteration_start()
	p.last_inner_label_is_iteration = false
	body := if p.match_token(.function_kw) {
		function_start := p.position()
		fn_decl := p.parse_function_declaration()
		if fn_decl.kind.tag == .function_declaration {
			if name := fn_decl.kind.func_name {
				p.scope_collector.check_labelled_function_declaration(name.name.data,
					function_start.line, function_start.column)
			}
			match fn_decl.kind.func_kind {
				.generator, .async_generator {
					p.syntax_error('Generator functions cannot be defined in labelled statements')
				}
				.async_kind {
					p.syntax_error('Async functions cannot be defined in labelled statements')
				}
				else {}
			}
		}
		fn_decl
	} else {
		p.parse_statement(allow_labelled_function)
	}

	is_iteration := body_starts_iteration || p.last_inner_label_is_iteration
	if !is_iteration {
		if label_key in p.labels_in_scope {
			lv := p.labels_in_scope[label_key]
			if lv.has_continue {
				p.syntax_error_at('labelled continue statement cannot use non iterating statement',
					lv.line, lv.col)
			}
		}
	}

	p.labels_in_scope.delete(label_key)
	p.flags.in_break_context = break_before
	p.last_inner_label_is_iteration = is_iteration

	return p.statement(start, StatementKind{
		tag:           .labelled
		label:         label
		labelled_item: &body
	})
}

fn (mut p Parser) match_for_using_declaration() bool {
	if !p.match_token(.identifier) {
		return false
	}
	if !utf16_equals(p.token_value(p.current_token), utf16('using')) {
		return false
	}
	next := p.next_token()
	if next.trivia_has_line_terminator {
		return false
	}
	if next.token_type == .identifier {
		next_val := p.token_original_value(next)
		if utf16_equals(next_val, utf16('of')) {
			return false
		}
	}
	return p.token_is_identifier(next)
}

// Validate that an expression-form LHS is valid for for-in/for-of.
fn (mut p Parser) validate_for_in_of_lhs(init LocalForInit) {
	match init {
		LocalForInitExpression {
			expression := init.expression
			if !is_identifier_expression(expression) && !is_member_expression(expression)
				&& !is_call_expression(expression) && !is_object_expression(expression)
				&& !is_array_expression(expression) {
				p.syntax_error('Invalid left-hand side in for-loop')
			}
		}
		else {}
	}
}

// Convert a LocalForInit into a ForInOfLhs.
fn (mut p Parser) synthesize_for_in_of_lhs(init LocalForInit, init_start Position) ForInOfLhs {
	match init {
		LocalForInitDeclaration {
			return ForInOfLhsDeclaration{
				statement: &init.statement
			}
		}
		LocalForInitExpression {
			expression := init.expression
			if is_array_expression(expression) || is_object_expression(expression) {
				if pattern := p.synthesize_binding_pattern(init_start) {
					for bn in p.pattern_bound_names {
						p.scope_collector.register_identifier(bn.identifier, bn.name.data, none)
					}
					p.pattern_bound_names = []BoundName{}
					return ForInOfLhsPattern{
						pattern: pattern
					}
				} else {
					return ForInOfLhsExpression{
						expression: &expression
					}
				}
			} else {
				return ForInOfLhsExpression{
					expression: &expression
				}
			}
		}
	}
}
