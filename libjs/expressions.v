module libjs

// Expression parsing: primary, secondary (binary/postfix), unary, and
// precedence climbing.
//
// Translated from expressions.rs.

enum EscapeMode {
	// Tagged template literals: invalid escapes produce `undefined` cooked value.
	tagged_template
	// String literals: invalid escapes emit syntax errors, legacy octals are tracked.
	string_literal
}

fn (mut p Parser) match_expression() bool {
	return match p.current_token_type() {
		.bool_literal, .numeric_literal, .big_int_literal, .string_literal, .null_literal,
		.regex_literal, .template_literal_start, .this_kw, .super_kw, .new_kw, .class_kw,
		.function_kw, .paren_open, .curly_open, .bracket_open, .private_identifier, .slash,
		.slash_equals {
			true
		}
		.async, .yield_kw, .await_kw {
			true
		}
		.import_kw {
			next := p.next_token()
			next.token_type == .paren_open || next.token_type == .period
		}
		else {
			if p.match_identifier() {
				true
			} else {
				p.match_unary_prefixed_expression()
			}
		}
	}
}

fn (p &Parser) match_unary_prefixed_expression() bool {
	if p.flags.await_expression_is_valid && p.match_token(.await_kw) {
		return true
	}
	return match p.current_token_type() {
		.plus_plus, .minus_minus, .exclamation_mark, .tilde, .plus, .minus, .typeof_kw, .void_kw,
		.delete_kw {
			true
		}
		else {
			false
		}
	}
}

fn (p &Parser) match_secondary_expression(forbidden &ForbiddenTokens) bool {
	tt := p.current_token_type()
	if !forbidden.allows(tt) {
		return false
	}
	return match tt {
		.period, .bracket_open, .paren_open, .question_mark_period {
			true
		}
		.plus_plus, .minus_minus {
			!p.current_token.trivia_has_line_terminator
		}
		.double_asterisk, .asterisk, .slash, .percent, .plus, .minus, .shift_left, .shift_right,
		.unsigned_shift_right, .less_than, .less_than_equals, .greater_than, .greater_than_equals,
		.in_kw, .instanceof_kw, .equals_equals, .exclamation_mark_equals, .equals_equals_equals,
		.exclamation_mark_equals_equals, .ampersand, .caret, .pipe, .double_question_mark,
		.double_ampersand, .double_pipe {
			true
		}
		.question_mark {
			true
		}
		.equals, .plus_equals, .minus_equals, .double_asterisk_equals, .asterisk_equals,
		.slash_equals, .percent_equals, .shift_left_equals, .shift_right_equals,
		.unsigned_shift_right_equals, .ampersand_equals, .caret_equals, .pipe_equals,
		.double_ampersand_equals, .double_pipe_equals, .double_question_mark_equals {
			true
		}
		else {
			false
		}
	}
}

fn (mut p Parser) parse_expression_any() Expression {
	return p.parse_expression(precedence_comma, .right, ForbiddenTokens{})
}

fn (mut p Parser) parse_assignment_expression() Expression {
	return p.parse_expression(precedence_assignment, .right, ForbiddenTokens{})
}

fn (mut p Parser) parse_expression(min_precedence int, associativity Associativity, forbidden ForbiddenTokens) Expression {
	if !p.enter_recursion() {
		return p.expression(p.position(), ExpressionKind.error())
	}
	defer {
		p.leave_recursion()
	}
	if p.match_unary_prefixed_expression() {
		start := p.position()
		expression := p.parse_unary_prefixed_expression()

		// https://tc39.es/ecma262/#sec-exp-operator
		// UnaryExpression cannot be the base of `**`, only UpdateExpression can.
		if p.match_token(.double_asterisk) && !is_update_expression(expression) {
			p.syntax_error("Unparenthesized unary expression can't appear on the left-hand side of '**'")
		}

		return p.continue_parse_expression(start, expression, min_precedence, associativity,
			forbidden)
	}

	lhs_start := p.position()
	p.last_primary_was_parenthesized = false
	expression, should_continue := p.parse_primary_expression(min_precedence, forbidden)

	// Check for freestanding `arguments` references after parse_primary_expression.
	if expression.kind.tag == .identifier_expr {
		if id := expression.kind.identifier {
			if utf16_equals(id.name.data, utf16('arguments')) && !p.flags.strict_mode
				&& !p.scope_collector.has_declaration_in_current_function(id.name.data) {
				p.scope_collector.set_contains_access_to_arguments_object_in_non_strict_mode()
			}
		}
	}

	if !should_continue {
		// Yield/Await expressions don't participate in secondary expression
		// parsing but do participate in comma expressions.
		return p.parse_comma_expression(lhs_start, expression, min_precedence, forbidden)
	}

	expression2 := p.parse_tagged_template_literals(lhs_start, expression)

	return p.continue_parse_expression(lhs_start, expression2, min_precedence, associativity,
		forbidden)
}

fn (mut p Parser) continue_parse_expression(lhs_start Position, expression_ Expression, min_precedence int, associativity Associativity, forbidden_ ForbiddenTokens) Expression {
	original_forbidden := forbidden_
	mut forbidden := forbidden_
	mut expression := expression_
	mut lhs_is_parenthesized := p.last_primary_was_parenthesized
	p.last_primary_was_parenthesized = false
	for p.match_secondary_expression(&forbidden) {
		new_precedence := operator_precedence(p.current_token_type())
		if new_precedence < min_precedence {
			break
		}
		if new_precedence == min_precedence && associativity == .left {
			break
		}

		result_expr, result_forbidden := p.parse_secondary_expression(expression, new_precedence,
			original_forbidden, lhs_is_parenthesized)
		lhs_is_parenthesized = false
		expression = result_expr
		forbidden = forbidden.merge(result_forbidden)

		// Tagged template literals bind tighter than any operator.
		if !is_update_expression(expression) {
			expression = p.parse_tagged_template_literals(lhs_start, expression)
		}
	}

	return p.parse_comma_expression(lhs_start, expression, min_precedence, forbidden)
}

fn (mut p Parser) parse_comma_expression(start Position, expression Expression, min_precedence int, forbidden ForbiddenTokens) Expression {
	if min_precedence <= 1 && p.match_token(.comma) && forbidden.allows(.comma) {
		mut expressions := [expression]
		for p.match_token(.comma) {
			p.consume()
			expressions << p.parse_assignment_expression()
		}
		return p.expression(start, ExpressionKind{
			tag:         .sequence
			expressions: expressions
		})
	}
	return expression
}

// Parse a primary expression (literal, identifier, `this`, etc.).
// Returns `(expression, should_continue)` — `false` means the caller
// should not attempt to parse a secondary expression (e.g. arrow).
fn (mut p Parser) parse_primary_expression(min_precedence int, forbidden ForbiddenTokens) (Expression, bool) {
	start := p.position()
	token := p.current_token

	match token.token_type {
		.paren_open {
			paren_start := p.position()
			p.consume_token(.paren_open)
			if arrow := p.try_parse_arrow_function_expression_impl(true, false, paren_start,
				forbidden)
			{
				return arrow, false
			}
			if p.match_token(.paren_close) {
				p.syntax_error('Unexpected token )')
				p.consume()
				return p.expression(start, ExpressionKind.error()), true
			}
			expression := p.parse_expression_any()
			p.consume_token(.paren_close)
			p.last_primary_was_parenthesized = true
			return expression, true
		}
		.this_kw {
			p.consume()
			p.scope_collector.set_uses_this()
			return p.expression(start, ExpressionKind{
				tag: .this_expr
			}), true
		}
		.class_kw {
			expression := p.parse_class_expression(false)
			return expression, true
		}
		.super_kw {
			p.consume()
			after_super := p.position()
			if p.scope_collector.has_current_scope() {
				p.scope_collector.set_uses_new_target()
			}
			if p.match_token(.paren_open) {
				if !p.flags.allow_super_constructor_call {
					p.syntax_error("'super' keyword unexpected here")
				}
				call_arguments := p.parse_arguments()
				return p.expression(after_super, ExpressionKind{
					tag:             .super_call
					super_call_data: &SuperCallData{
						arguments:    call_arguments
						is_synthetic: false
					}
				}), true
			} else if p.match_token(.period) || p.match_token(.bracket_open) {
				if !p.flags.allow_super_property_lookup {
					p.syntax_error("'super' keyword unexpected here")
				}
				return p.expression(start, ExpressionKind{
					tag: .super_expr
				}), true
			} else {
				p.syntax_error("'super' keyword unexpected here")
				return p.expression(start, ExpressionKind{
					tag: .super_expr
				}), true
			}
		}
		.numeric_literal {
			num_token := p.consume_and_validate_numeric_literal()
			value_str := p.token_value(num_token)
			value := parse_numeric_value(value_str)
			return p.expression(start, ExpressionKind{
				tag:           .numeric_literal
				numeric_value: value
			}), true
		}
		.big_int_literal {
			bi_token := p.consume()
			value := p.token_value(bi_token)
			mut value_utf8 := []u8{cap: value.len}
			for c in value {
				assert c < 128, 'BigIntLiteral should only contain ASCII characters'
				value_utf8 << u8(c)
			}
			return p.expression(start, ExpressionKind{
				tag:           .big_int_literal
				big_int_value: value_utf8.bytestr()
			}), true
		}
		.bool_literal {
			bl_token := p.consume()
			value := p.token_value(bl_token)
			is_true := utf16_equals(value, utf16('true'))
			return p.expression(start, ExpressionKind{
				tag:        .boolean_literal
				bool_value: is_true
			}), true
		}
		.string_literal {
			str_token := p.consume()
			after_string := p.position()
			str_value, has_octal := p.parse_string_value(str_token)
			if has_octal {
				if p.flags.strict_mode {
					p.syntax_error('Octal escape sequence in string literal not allowed in strict mode')
				} else {
					p.flags.string_legacy_octal_escape_sequence_in_scope = true
				}
			}
			return p.expression(after_string, ExpressionKind{
				tag:          .string_literal
				string_value: str_value
			}), true
		}
		.null_literal {
			p.consume()
			return p.expression(start, ExpressionKind{
				tag: .null_literal
			}), true
		}
		.curly_open {
			expression := p.parse_object_expression()
			return expression, true
		}
		.bracket_open {
			expression := p.parse_array_expression()
			return expression, true
		}
		.function_kw {
			expression := p.parse_function_expression()
			return expression, true
		}
		.async {
			next := p.next_token()
			if next.token_type == .function_kw && !next.trivia_has_line_terminator {
				expression := p.parse_function_expression()
				return expression, true
			}
			if arrow := p.try_parse_arrow_function_expression(next.token_type == .paren_open, true,
				forbidden)
			{
				return arrow, false
			}
			async_token := p.consume_and_check_identifier()
			value := p.token_value(async_token).clone()
			id := p.make_identifier(start, Utf16String.from_slice(value))
			p.scope_collector.register_identifier(id, value, none)
			return p.expression(start, ExpressionKind.identifier_kind(id)), true
		}
		.template_literal_start {
			expression := p.parse_template_literal(false)
			return expression, true
		}
		.new_kw {
			expression := p.parse_new_expression()
			return expression, true
		}
		.import_kw {
			p.consume()
			if p.match_token(.period) {
				p.consume()
				meta_token := p.current_token
				p.consume_token(.identifier)
				meta_utf16 := [u16(ch(`m`)), ch(`e`), ch(`t`),
					ch(`a`)]
				if !utf16_equals(p.token_original_value(meta_token), meta_utf16) {
					p.syntax_error("Expected 'meta' after 'import.'")
				}
				if p.program_type != .module {
					p.syntax_error('import.meta is only allowed in modules')
				}
				return p.expression(start, ExpressionKind{
					tag:                .meta_property
					meta_property_type: .import_meta
				}), true
			} else if p.match_token(.paren_open) {
				p.consume()
				specifier := p.parse_assignment_expression()
				mut has_options := false
				mut options_expr := Expression{}
				if p.match_token(.comma) {
					p.consume()
					if !p.match_token(.paren_close) {
						opts := p.parse_assignment_expression()
						has_options = true
						options_expr = opts
						if p.match_token(.comma) {
							p.consume()
						}
					}
				}
				p.consume_token(.paren_close)
				return p.expression(start, ExpressionKind{
					tag:       .import_call
					specifier: &specifier
					options:   if has_options { &options_expr } else { none }
				}), true
			} else {
				p.expected("'.' or '('")
				return p.expression(start, ExpressionKind.error()), true
			}
		}
		.yield_kw {
			if p.flags.in_generator_function_context && min_precedence <= 3 {
				expression := p.parse_yield_expression(forbidden)
				return expression, false
			}
			// Fall through to identifier handling below
			return p.parse_primary_expression_identifier(start, forbidden)
		}
		.await_kw {
			// Fall through to identifier handling below
			return p.parse_primary_expression_identifier(start, forbidden)
		}
		.private_identifier {
			id := p.parse_private_identifier(start)
			return p.expression(start, ExpressionKind{
				tag:                .private_identifier_expr
				private_identifier: id
			}), true
		}
		.regex_literal {
			regex_token := p.consume()
			return p.parse_regex_literal(start, regex_token), true
		}
		.slash, .slash_equals {
			forced_token := p.lexer.force_slash_as_regex()
			p.current_token = forced_token
			regex_token := p.consume()
			return p.parse_regex_literal(start, regex_token), true
		}
		else {
			return p.parse_primary_expression_identifier(start, forbidden)
		}
	}
}

// Helper for the default/fallthrough case in parse_primary_expression.
fn (mut p Parser) parse_primary_expression_identifier(start Position, forbidden ForbiddenTokens) (Expression, bool) {
	if p.match_identifier() || p.match_token(.await_kw) || p.match_token(.yield_kw) {
		if arrow := p.try_parse_arrow_function_expression(false, false, forbidden) {
			return arrow, false
		}
		if p.match_token(.await_kw) && (p.program_type == .module
			|| p.flags.await_expression_is_valid
			|| p.flags.in_class_static_init_block) {
			p.syntax_error("'await' is not allowed as an identifier in this context")
		}
		if p.match_token(.yield_kw)
			&& (p.flags.strict_mode || p.flags.in_generator_function_context) {
			p.syntax_error("'yield' is not allowed as an identifier in this context")
		}
		id_token := p.consume_and_check_identifier()
		value := p.token_value(id_token).clone()
		id := p.make_identifier(start, Utf16String.from_slice(value.clone()))
		p.scope_collector.register_identifier(id, value, none)
		return p.expression(start, ExpressionKind.identifier_kind(id)), true
	} else if p.match_token(.escaped_keyword) {
		p.syntax_error('Keyword must not contain escaped characters')
		id_token := p.consume_and_check_identifier()
		value := p.token_value(id_token).clone()
		id := p.make_identifier(start, Utf16String.from_slice(value.clone()))
		p.scope_collector.register_identifier(id, value, none)
		return p.expression(start, ExpressionKind.identifier_kind(id)), true
	} else {
		p.expected('primary expression')
		p.consume()
		return p.expression(start, ExpressionKind.error()), true
	}
}

fn (mut p Parser) parse_regex_literal(start Position, token Token) Expression {
	value := p.token_value(token)
	pattern := if value.len >= 2 {
		value[1..value.len - 1].clone()
	} else {
		value.clone()
	}
	flags := if p.match_token(.regex_flags) {
		ftok := p.consume()
		p.token_value(ftok).clone()
	} else {
		[]u16{}
	}
	p.validate_regex_flags(flags)
	_ = p.compile_regex_pattern(pattern, flags)
	return p.expression(start, ExpressionKind{
		tag:         .regexp_literal
		regexp_data: RegExpLiteralData{
			pattern: Utf16String.from_slice(pattern)
			flags:   Utf16String.from_slice(flags)
		}
	})
}

fn (mut p Parser) parse_secondary_expression(lhs Expression, min_precedence int, forbidden ForbiddenTokens, lhs_is_parenthesized bool) (Expression, ForbiddenTokens) {
	start := p.position()
	tt := p.current_token_type()

	match tt {
		// === Binary operators ===
		.plus, .minus, .asterisk, .slash, .percent, .double_asterisk, .shift_left, .shift_right,
		.unsigned_shift_right, .ampersand, .caret, .pipe, .less_than, .less_than_equals,
		.greater_than, .greater_than_equals, .equals_equals, .exclamation_mark_equals,
		.equals_equals_equals, .exclamation_mark_equals_equals, .in_kw, .instanceof_kw {
			op := token_to_binary_op(tt)
			p.consume()
			rhs := p.parse_expression(min_precedence, operator_associativity(tt), forbidden)
			return p.expression(start, ExpressionKind{
				tag:       .binary
				binary_op: op
				lhs:       &lhs
				rhs:       &rhs
			}), ForbiddenTokens{}
		}
		// === Logical operators ===
		.double_ampersand {
			p.consume()
			new_forbidden := forbidden.forbid([TokenType.double_question_mark])
			rhs := p.parse_expression(min_precedence, .left, new_forbidden)
			return p.expression(start, ExpressionKind{
				tag:        .logical
				logical_op: .and_op
				lhs:        &lhs
				rhs:        &rhs
			}), new_forbidden
		}
		.double_pipe {
			p.consume()
			new_forbidden := forbidden.forbid([TokenType.double_question_mark])
			rhs := p.parse_expression(min_precedence, .left, new_forbidden)
			return p.expression(start, ExpressionKind{
				tag:        .logical
				logical_op: .or_op
				lhs:        &lhs
				rhs:        &rhs
			}), new_forbidden
		}
		.double_question_mark {
			p.consume()
			new_forbidden := forbidden.forbid([TokenType.double_ampersand, .double_pipe])
			rhs := p.parse_expression(min_precedence, .left, new_forbidden)
			return p.expression(start, ExpressionKind{
				tag:        .logical
				logical_op: .nullish_coalescing
				lhs:        &lhs
				rhs:        &rhs
			}), new_forbidden
		}
		// === Assignment ===
		.equals, .plus_equals, .minus_equals, .double_asterisk_equals, .asterisk_equals,
		.slash_equals, .percent_equals, .shift_left_equals, .shift_right_equals,
		.unsigned_shift_right_equals, .ampersand_equals, .caret_equals, .pipe_equals,
		.double_ampersand_equals, .double_pipe_equals, .double_question_mark_equals {
			op := token_to_assignment_op(tt)
			if op == .assignment && (is_object_expression(lhs) || is_array_expression(lhs))
				&& !lhs_is_parenthesized {
				saved_bound_names := p.pattern_bound_names.clone()
				p.pattern_bound_names = []BoundName{}
				if pattern := p.synthesize_binding_pattern(lhs.range.start) {
					// Register synthesized identifiers with the scope collector.
					for bn in p.pattern_bound_names {
						p.scope_collector.register_identifier(bn.identifier, bn.name.data, none)
					}
					p.pattern_bound_names = saved_bound_names
					p.consume()
					rhs := p.parse_expression(min_precedence, .right, forbidden)
					return p.expression(start, ExpressionKind{
						tag:                  .assignment
						assignment_op:        op
						lhs_is_parenthesized: lhs_is_parenthesized
						assignment_lhs:       AssignmentLhsPattern{
							pattern: pattern
						}
						rhs:                  &rhs
					}), ForbiddenTokens{}
				} else {
					p.pattern_bound_names = saved_bound_names
				}
			}
			allow_call := tt != .double_ampersand_equals && tt != .double_pipe_equals
				&& tt != .double_question_mark_equals
			if !is_simple_assignment_target(lhs, allow_call) {
				p.syntax_error('Invalid left-hand side in assignment')
			}
			if lhs.kind.tag == .identifier_expr {
				if id := lhs.kind.identifier {
					p.check_identifier_name_for_assignment_validity(id.name.data, false)
				}
			}
			p.consume()
			rhs := p.parse_expression(min_precedence, .right, forbidden)
			return p.expression(start, ExpressionKind{
				tag:                  .assignment
				assignment_op:        op
				lhs_is_parenthesized: lhs_is_parenthesized
				assignment_lhs:       AssignmentLhsExpression{
					expression: &lhs
				}
				rhs:                  &rhs
			}), ForbiddenTokens{}
		}
		// === Ternary ===
		.question_mark {
			p.consume()
			consequent := p.parse_assignment_expression()
			p.consume_token(.colon)
			alternate := p.parse_expression(precedence_assignment, .right, forbidden)
			return p.expression(start, ExpressionKind{
				tag:            .conditional
				test:           &lhs
				consequent:     &consequent
				alternate_expr: &alternate
			}), ForbiddenTokens{}
		}
		// === Member access ===
		.period {
			p.consume()
			property_start := p.position()
			if p.match_token(.private_identifier) {
				id := p.parse_private_identifier(property_start)
				property := p.expression(property_start, ExpressionKind{
					tag:                .private_identifier_expr
					private_identifier: id
				})
				return p.expression(start, ExpressionKind{
					tag:      .member
					object:   &lhs
					property: &property
					computed: false
				}), ForbiddenTokens{}
			} else if p.match_identifier_name() {
				mem_token := p.consume()
				value := p.token_value(mem_token).clone()
				property := p.expression(property_start, ExpressionKind.identifier_kind(p.make_identifier(property_start,
					Utf16String.from_slice(value))))
				return p.expression(start, ExpressionKind{
					tag:      .member
					object:   &lhs
					property: &property
					computed: false
				}), ForbiddenTokens{}
			} else {
				p.expected('property name')
				return lhs, ForbiddenTokens{}
			}
		}
		// === Computed member access ===
		.bracket_open {
			p.consume()
			property := p.parse_expression_any()
			p.consume_token(.bracket_close)
			return p.expression(start, ExpressionKind{
				tag:      .member
				object:   &lhs
				property: &property
				computed: true
			}), ForbiddenTokens{}
		}
		// === Call ===
		.paren_open {
			expression := p.parse_call_expression(lhs)
			return expression, ForbiddenTokens{}
		}
		// === Optional chaining ===
		.question_mark_period {
			chain := p.parse_optional_chain(start, lhs)
			return chain, ForbiddenTokens{}
		}
		// === Postfix ===
		.plus_plus {
			if !is_simple_assignment_target(lhs, true) {
				p.syntax_error('Invalid left-hand side in postfix operation')
			}
			if lhs.kind.tag == .identifier_expr {
				if id := lhs.kind.identifier {
					p.check_identifier_name_for_assignment_validity(id.name.data, false)
				}
			}
			p.consume()
			return p.expression(start, ExpressionKind{
				tag:       .update
				update_op: .increment
				argument:  &lhs
				prefixed:  false
			}), ForbiddenTokens{}
		}
		.minus_minus {
			if !is_simple_assignment_target(lhs, true) {
				p.syntax_error('Invalid left-hand side in postfix operation')
			}
			if lhs.kind.tag == .identifier_expr {
				if id := lhs.kind.identifier {
					p.check_identifier_name_for_assignment_validity(id.name.data, false)
				}
			}
			p.consume()
			return p.expression(start, ExpressionKind{
				tag:       .update
				update_op: .decrement
				argument:  &lhs
				prefixed:  false
			}), ForbiddenTokens{}
		}
		else {
			p.expected('secondary expression')
			return lhs, ForbiddenTokens{}
		}
	}
}

fn (mut p Parser) parse_unary_prefixed_expression() Expression {
	start := p.position()
	tt := p.current_token_type()

	match tt {
		.await_kw {
			return p.parse_await_expression()
		}
		.plus_plus {
			p.consume()
			expression := p.parse_expression(precedence_unary, .right, ForbiddenTokens{})
			if !is_simple_assignment_target(expression, true) {
				p.syntax_error('Invalid left-hand side in prefix operation')
			}
			if expression.kind.tag == .identifier_expr {
				if id := expression.kind.identifier {
					p.check_identifier_name_for_assignment_validity(id.name.data, false)
				}
			}
			return p.expression(start, ExpressionKind{
				tag:       .update
				update_op: .increment
				argument:  &expression
				prefixed:  true
			})
		}
		.minus_minus {
			p.consume()
			expression := p.parse_expression(precedence_unary, .right, ForbiddenTokens{})
			if !is_simple_assignment_target(expression, true) {
				p.syntax_error('Invalid left-hand side in prefix operation')
			}
			if expression.kind.tag == .identifier_expr {
				if id := expression.kind.identifier {
					p.check_identifier_name_for_assignment_validity(id.name.data, false)
				}
			}
			return p.expression(start, ExpressionKind{
				tag:       .update
				update_op: .decrement
				argument:  &expression
				prefixed:  true
			})
		}
		.exclamation_mark, .tilde, .plus, .minus, .typeof_kw, .void_kw {
			op := match tt {
				.exclamation_mark { UnaryOp.not_op }
				.tilde { UnaryOp.bitwise_not }
				.plus { UnaryOp.plus }
				.minus { UnaryOp.minus }
				.typeof_kw { UnaryOp.typeof_op }
				else { UnaryOp.void_op }
			}

			p.consume()
			expression := p.parse_expression(precedence_unary, .right, ForbiddenTokens{})
			return p.expression(start, ExpressionKind{
				tag:      .unary
				unary_op: op
				operand:  &expression
			})
		}
		.delete_kw {
			p.consume()
			rhs_start := p.position()
			expression := p.parse_expression(precedence_unary, .right, ForbiddenTokens{})
			if p.flags.strict_mode && is_identifier_expression(expression) {
				p.syntax_error_at('Delete of an unqualified identifier in strict mode.',
					rhs_start.line, rhs_start.column)
			}
			if expression.kind.tag == .member {
				if prop := expression.kind.property {
					if prop.kind.tag == .private_identifier_expr {
						p.syntax_error('Private fields cannot be deleted')
					}
				}
			}
			return p.expression(start, ExpressionKind{
				tag:      .unary
				unary_op: .delete_op
				operand:  &expression
			})
		}
		else {
			p.expected('unary expression')
			p.consume()
			return p.expression(start, ExpressionKind.error())
		}
	}
}

// Parse a `new` expression, handling `new.target` and nested `new` calls.
fn (mut p Parser) parse_new_expression() Expression {
	start := p.position()
	p.consume_token(.new_kw)

	if p.match_token(.period) {
		p.consume()
		target_token := p.current_token
		p.consume_token(.identifier)
		if !utf16_equals(p.token_original_value(target_token), utf16('target')) {
			p.syntax_error("Expected 'target' after 'new.'")
		}
		if !p.flags.new_target_is_valid && !p.in_eval_function_context {
			p.syntax_error("'new.target' not allowed outside of a function")
		}
		if p.scope_collector.has_current_scope() {
			p.scope_collector.set_uses_new_target()
		}
		return p.expression(start, ExpressionKind{
			tag:                .meta_property
			meta_property_type: .new_target
		})
	}

	callee_starts_with_grouping_paren := p.match_token(.paren_open)
	callee := if p.match_token(.new_kw) {
		p.parse_new_expression()
	} else {
		forbidden := ForbiddenTokens{}.forbid([TokenType.paren_open, .question_mark_period])
		p.parse_expression(precedence_member, .right, forbidden)
	}

	if callee.kind.tag == .import_call && !callee_starts_with_grouping_paren {
		p.syntax_error('Cannot call new on dynamic import')
	}

	if p.match_token(.paren_open) {
		call_arguments := p.parse_arguments()
		return p.expression(start, ExpressionKind{
			tag:       .new_expr
			call_data: &CallExpressionData{
				callee:    callee
				arguments: call_arguments
			}
		})
	} else {
		return p.expression(start, ExpressionKind{
			tag:       .new_expr
			call_data: &CallExpressionData{
				callee: callee
			}
		})
	}
}

// Parse a call expression `callee(arguments...)`.
fn (mut p Parser) parse_call_expression(callee Expression) Expression {
	start := p.position()
	call_arguments := p.parse_arguments()
	// Check for direct call to eval.
	if callee.kind.tag == .identifier_expr {
		if id := callee.kind.identifier {
			if utf16_equals(id.name.data, utf16('eval')) {
				p.scope_collector.set_contains_direct_call_to_eval()
				p.scope_collector.set_uses_this()
			}
		}
	}
	return p.expression(start, ExpressionKind{
		tag:       .call
		call_data: &CallExpressionData{
			callee:    callee
			arguments: call_arguments
		}
	})
}

fn (mut p Parser) parse_arguments() []CallArgument {
	p.consume_token(.paren_open)
	mut call_arguments := []CallArgument{}

	for !p.match_token(.paren_close) && !p.done() {
		is_spread := p.eat(.triple_dot)
		value := p.parse_assignment_expression()
		call_arguments << CallArgument{
			value:     value
			is_spread: is_spread
		}
		if !p.match_token(.comma) {
			break
		}
		p.consume()
	}

	p.consume_token(.paren_close)
	return call_arguments
}

// Parse an optional chaining expression (`a?.b`, `a?.[x]`, `a?.()`).
fn (mut p Parser) parse_optional_chain(start Position, base Expression) Expression {
	mut references := []OptionalChainReference{}

	for {
		if p.match_token(.question_mark_period) {
			p.consume()
			match p.current_token_type() {
				.paren_open {
					call_arguments := p.parse_arguments()
					references << OptionalChainCall{
						arguments: call_arguments
						mode:      .optional
					}
				}
				.bracket_open {
					p.consume()
					expression := p.parse_expression_any()
					p.consume_token(.bracket_close)
					references << OptionalChainComputedRef{
						expression: expression
						mode:       .optional
					}
				}
				.private_identifier {
					property_start := p.position()
					id := p.parse_private_identifier(property_start)
					references << OptionalChainPrivateMemberRef{
						private_identifier: id
						mode:               .optional
					}
				}
				.template_literal_start {
					p.syntax_error('Invalid tagged template literal after ?.')
					break
				}
				else {
					if p.match_identifier_name() {
						property_start := p.position()
						mem_token := p.consume()
						value := p.token_value(mem_token).clone()
						references << OptionalChainMemberRef{
							identifier: p.make_identifier(property_start,
								Utf16String.from_slice(value))
							mode:       .optional
						}
					} else {
						p.syntax_error('Invalid optional chain reference after ?.')
						break
					}
				}
			}
		} else if p.match_token(.paren_open) {
			call_arguments := p.parse_arguments()
			references << OptionalChainCall{
				arguments: call_arguments
				mode:      .not_optional
			}
		} else if p.match_token(.period) {
			p.consume()
			if p.match_token(.private_identifier) {
				property_start := p.position()
				id := p.parse_private_identifier(property_start)
				references << OptionalChainPrivateMemberRef{
					private_identifier: id
					mode:               .not_optional
				}
			} else if p.match_identifier_name() {
				property_start := p.position()
				mem_token := p.consume()
				value := p.token_value(mem_token).clone()
				references << OptionalChainMemberRef{
					identifier: p.make_identifier(property_start, Utf16String.from_slice(value))
					mode:       .not_optional
				}
			} else {
				p.expected('an identifier')
				break
			}
		} else if p.match_token(.template_literal_start) {
			p.syntax_error('Invalid tagged template literal after optional chain')
			break
		} else if p.match_token(.bracket_open) {
			p.consume()
			expression := p.parse_expression_any()
			p.consume_token(.bracket_close)
			references << OptionalChainComputedRef{
				expression: expression
				mode:       .not_optional
			}
		} else {
			break
		}

		if p.done() {
			break
		}
	}

	return p.expression(start, ExpressionKind{
		tag:        .optional_chain
		base:       &base
		references: references
	})
}

// Parse a `yield` or `yield*` expression.
fn (mut p Parser) parse_yield_expression(forbidden ForbiddenTokens) Expression {
	start := p.position()

	if p.flags.in_formal_parameter_context {
		p.syntax_error("'Yield' expression is not allowed in formal parameters of generator function")
	}

	p.consume_token(.yield_kw)

	if p.current_token.trivia_has_line_terminator {
		return p.expression(start, ExpressionKind{
			tag:           .yield_expr
			is_yield_from: false
		})
	}

	is_yield_from := p.match_token(.asterisk)
	if is_yield_from {
		p.consume()
	}

	if is_yield_from || p.match_expression() || p.match_token(.class_kw) {
		// YieldExpression forwards its surrounding In grammar parameter.
		argument := p.parse_expression(precedence_assignment, .right, forbidden)
		return p.expression(start, ExpressionKind{
			tag:           .yield_expr
			argument:      &argument
			is_yield_from: is_yield_from
		})
	} else {
		return p.expression(start, ExpressionKind{
			tag:           .yield_expr
			is_yield_from: false
		})
	}
}

// Parse an `await` expression.
fn (mut p Parser) parse_await_expression() Expression {
	start := p.position()

	if p.flags.in_formal_parameter_context {
		p.syntax_error("'Await' expression is not allowed in formal parameters of an async function")
	}

	p.consume_token(.await_kw)
	argument := p.parse_expression(precedence_unary, .right, ForbiddenTokens{})
	p.scope_collector.set_contains_await_expression()
	return p.expression(start, ExpressionKind{
		tag:     .await_expr
		operand: &argument
	})
}

fn (mut p Parser) parse_object_expression() Expression {
	start := p.position()
	p.consume_token(.curly_open)

	mut properties := []ObjectProperty{}
	mut has_proto_setter := false
	for !p.match_token(.curly_close) && !p.done() {
		if p.match_token(.triple_dot) {
			p.consume()
			expression := p.parse_assignment_expression()
			properties << ObjectProperty{
				range:         p.range_from(start)
				property_type: .spread
				key:           expression
				is_computed:   false
			}
		} else {
			property := p.parse_object_property(start)
			if property.property_type == .proto_setter {
				if has_proto_setter {
					p.syntax_error('Duplicate __proto__ fields are not allowed in object expressions')
				}
				has_proto_setter = true
			}
			properties << property
		}

		if !p.match_token(.comma) {
			break
		}
		p.consume()
	}

	p.consume_token(.curly_close)
	return p.expression(start, ExpressionKind{
		tag:               .object_expr
		object_properties: properties
	})
}

fn (mut p Parser) parse_object_property(obj_start Position) ObjectProperty {
	start := p.position()
	mut is_getter := false
	mut is_setter := false
	mut is_async := false
	mut is_generator := false

	if p.match_identifier_name() {
		value := p.token_original_value(p.current_token).clone()
		if utf16_equals(value, utf16('get')) && p.match_property_key_ahead() {
			is_getter = true
			p.consume()
		} else if utf16_equals(value, utf16('set')) && p.match_property_key_ahead() {
			is_setter = true
			p.consume()
		} else if utf16_equals(value, utf16('async')) {
			next := p.next_token()
			if !next.trivia_has_line_terminator && next.token_type != .paren_open
				&& next.token_type != .colon && next.token_type != .comma
				&& next.token_type != .curly_close {
				is_async = true
				p.consume()
				if p.match_token(.asterisk) {
					is_generator = true
					p.consume()
				}
			}
		}
	}

	if !is_getter && !is_setter && !is_async && p.match_token(.asterisk) {
		is_generator = true
		p.consume()
	}

	pk := p.parse_property_key()
	key := pk.expression
	key_value := pk.name
	is_proto := pk.is_proto
	is_computed := pk.is_computed
	is_identifier := pk.is_identifier

	// Private names are not allowed in object literals.
	if key.kind.tag == .private_identifier_expr {
		p.syntax_error('Private field or method is not allowed in object literal')
	}

	if p.match_token(.paren_open) {
		method_kind := if is_getter {
			MethodKind.getter
		} else if is_setter {
			MethodKind.setter
		} else {
			MethodKind.normal
		}
		function := p.parse_method_definition(is_async, is_generator, method_kind, start)
		property_type := if is_getter {
			ObjectPropertyType.getter
		} else if is_setter {
			ObjectPropertyType.setter
		} else {
			ObjectPropertyType.key_value
		}
		return ObjectProperty{
			range:         p.range_from(obj_start)
			property_type: property_type
			key:           key
			value:         function
			is_method:     true
			is_computed:   is_computed
		}
	}

	// async modifier requires a method (must have parens)
	if is_async {
		p.syntax_error('Expected function after async keyword')
	}

	if is_getter || is_setter {
		method_kind := if is_getter { MethodKind.getter } else { MethodKind.setter }
		function := p.parse_method_definition(false, false, method_kind, start)
		property_type := if is_getter {
			ObjectPropertyType.getter
		} else {
			ObjectPropertyType.setter
		}
		return ObjectProperty{
			range:         p.range_from(obj_start)
			property_type: property_type
			key:           key
			value:         function
			is_method:     true
			is_computed:   is_computed
		}
	}

	if p.match_token(.colon) {
		p.consume()
		value := p.parse_assignment_expression()
		property_type := if is_proto {
			ObjectPropertyType.proto_setter
		} else {
			ObjectPropertyType.key_value
		}
		return ObjectProperty{
			range:         p.range_from(obj_start)
			property_type: property_type
			key:           key
			value:         value
			is_method:     false
			is_computed:   is_computed
		}
	}

	// CoverInitializedName: { x = y }
	if p.match_token(.equals) && is_identifier {
		if kv := key_value {
			id := p.make_identifier(obj_start, kv.clone())
			p.scope_collector.register_identifier(id, id.name.data, none)
			value := p.expression(obj_start, ExpressionKind.identifier_kind(id))
			p.consume() // consume '='
			p.syntax_error('Invalid property in object literal')
			saved_scope_state := p.scope_collector.save_state()
			_ = p.parse_assignment_expression()
			p.scope_collector.load_state(saved_scope_state)
			return ObjectProperty{
				range:         p.range_from(obj_start)
				property_type: .key_value
				key:           key
				value:         value
				is_method:     false
				is_computed:   false
			}
		}
	}

	// Shorthand property: { x }
	if is_identifier {
		if kv := key_value {
			if p.flags.strict_mode && is_strict_reserved_word(kv.data) {
				name_str := string_from_utf16_lossy(kv.data)
				p.syntax_error("'${name_str}' is a reserved keyword")
			}
			id := p.make_identifier(obj_start, kv)
			p.scope_collector.register_identifier(id, id.name.data, none)
			value := p.expression(obj_start, ExpressionKind.identifier_kind(id))
			return ObjectProperty{
				range:         p.range_from(obj_start)
				property_type: .key_value
				key:           key
				value:         value
				is_method:     false
				is_computed:   false
			}
		}
	}

	p.expected("':' or '('")
	return ObjectProperty{
		range:         p.range_from(obj_start)
		property_type: .key_value
		key:           key
		is_method:     false
		is_computed:   is_computed
	}
}

fn (mut p Parser) match_property_key_ahead() bool {
	next := p.next_token()
	return match next.token_type {
		.bracket_open, .string_literal, .numeric_literal, .big_int_literal, .private_identifier {
			true
		}
		else {
			next.token_type.is_identifier_name()
		}
	}
}

fn (mut p Parser) parse_property_key() PropertyKey {
	proto_name := utf16('__proto__')
	start := p.position()
	match p.current_token_type() {
		.bracket_open {
			p.consume()
			expression := p.parse_assignment_expression()
			p.consume_token(.bracket_close)
			return PropertyKey{
				expression:  expression
				is_computed: true
			}
		}
		.string_literal {
			str_token := p.consume_property_key_token()
			after_string := p.position()
			str_value, has_octal := p.parse_string_value(str_token)
			if has_octal {
				if p.flags.strict_mode {
					p.syntax_error('Octal escape sequence in string literal not allowed in strict mode')
				} else {
					p.flags.string_legacy_octal_escape_sequence_in_scope = true
				}
			}
			is_proto := utf16_equals(str_value.data, proto_name)
			expression := p.expression(after_string, ExpressionKind{
				tag:          .string_literal
				string_value: str_value.clone()
			})
			return PropertyKey{
				expression: expression
				name:       str_value
				is_proto:   is_proto
			}
		}
		.numeric_literal {
			num_token := p.consume_and_validate_numeric_literal()
			value_str := p.token_value(num_token)
			value := parse_numeric_value(value_str)
			expression := p.expression(start, ExpressionKind{
				tag:           .numeric_literal
				numeric_value: value
			})
			return PropertyKey{
				expression: expression
			}
		}
		.big_int_literal {
			bi_token := p.consume()
			value := p.token_value(bi_token)
			mut value_utf8 := []u8{cap: value.len}
			for c in value {
				assert c < 128, 'BigIntLiteral should only contain ASCII characters'
				value_utf8 << u8(c)
			}
			expression := p.expression(start, ExpressionKind{
				tag:           .big_int_literal
				big_int_value: value_utf8.bytestr()
			})
			return PropertyKey{
				expression: expression
			}
		}
		.private_identifier {
			pi_token := p.consume()
			value := Utf16String.from_slice(p.token_value(pi_token))
			if utf16_equals(value.data, utf16('#constructor')) {
				p.syntax_error("Private property with name '#constructor' is not allowed")
			}
			key_start := start
			expression := p.expression(key_start, ExpressionKind{
				tag:                .private_identifier_expr
				private_identifier: PrivateIdentifier{
					range: p.range_from(key_start)
					name:  value.clone()
				}
			})
			return PropertyKey{
				expression: expression
				name:       value
			}
		}
		else {
			if p.match_identifier_name() {
				is_ident := p.match_identifier()
				id_token := p.consume_property_key_token()
				value := Utf16String.from_slice(p.token_value(id_token))
				is_proto := utf16_equals(value.data, proto_name)
				key_start := start
				expression := p.expression(key_start, ExpressionKind{
					tag:          .string_literal
					string_value: value.clone()
				})
				return PropertyKey{
					expression:    expression
					name:          value
					is_proto:      is_proto
					is_identifier: is_ident
				}
			} else {
				p.expected('property key')
				p.consume_property_key_token()
				expression := p.expression(start, ExpressionKind{
					tag:          .string_literal
					string_value: Utf16String.new()
				})
				return PropertyKey{
					expression: expression
				}
			}
		}
	}
}

fn (mut p Parser) parse_array_expression() Expression {
	start := p.position()
	p.consume_token(.bracket_open)

	mut elements := []?Expression{}
	for !p.match_token(.bracket_close) && !p.done() {
		if p.match_token(.comma) {
			elements << ?Expression(none)
			p.consume()
			continue
		}
		if p.match_token(.triple_dot) {
			p.consume()
			expression := p.parse_assignment_expression()
			// C++ uses the array's rule_start ([ position) for SpreadExpression.
			elements << ?Expression(p.expression(start, ExpressionKind{
				tag:     .spread
				operand: &expression
			}))
		} else {
			elements << ?Expression(p.parse_assignment_expression())
		}
		if !p.match_token(.comma) {
			break
		}
		p.consume()
	}

	p.consume_token(.bracket_close)
	return p.expression(start, ExpressionKind{
		tag:            .array_expr
		array_elements: elements
	})
}

// Consume any tagged template literals following an expression.
fn (mut p Parser) parse_tagged_template_literals(tag_start Position, expression_ Expression) Expression {
	mut expression := expression_
	for p.match_token(.template_literal_start) {
		template := p.parse_template_literal(true)
		expression = p.expression(tag_start, ExpressionKind{
			tag:                   .tagged_template_literal
			tag_expr:              &Expression{
				...expression
			}
			template_literal_expr: &template
		})
	}
	return expression
}

fn (mut p Parser) parse_template_literal(is_tagged bool) Expression {
	start := p.position()
	p.consume_token(.template_literal_start)

	mut expressions := []Expression{}
	mut raw_strings := []Utf16String{}

	needs_leading_empty := !p.match_token(.template_literal_string)
	if needs_leading_empty {
		if is_tagged {
			raw_strings << Utf16String.new()
		}
		expressions << p.expression(start, ExpressionKind{
			tag:          .string_literal
			string_value: Utf16String.new()
		})
	}

	for {
		if p.match_token(.template_literal_end) {
			p.consume()
			break
		}
		if p.match_token(.template_literal_string) {
			tpl_token := p.consume()
			string_pos := p.position()
			raw := p.token_value(tpl_token).clone()
			if is_tagged {
				raw_value := raw_template_value(raw)
				raw_strings << raw_value
				cooked := p.process_template_escape_sequences(raw)
				if cooked_val := cooked {
					expressions << p.expression(string_pos, ExpressionKind{
						tag:          .string_literal
						string_value: cooked_val
					})
				} else {
					// C++ uses rule_start (template literal start) for NullLiteral.
					expressions << p.expression(start, ExpressionKind{
						tag: .null_literal
					})
				}
			} else {
				value, has_octal := p.process_escape_sequences(raw)
				if has_octal {
					p.syntax_error('Octal escape sequence not allowed in template literal')
				}
				expressions << p.expression(string_pos, ExpressionKind{
					tag:          .string_literal
					string_value: value
				})
			}
		} else if p.match_token(.template_literal_expr_start) {
			p.consume()
			expression := p.parse_expression_any()
			expressions << expression
			p.consume_token(.template_literal_expr_end)
			// After an expression, if no template string follows, insert empty.
			if !p.match_token(.template_literal_string) {
				expressions << p.expression(start, ExpressionKind{
					tag:          .string_literal
					string_value: Utf16String.new()
				})
				if is_tagged {
					raw_strings << Utf16String.new()
				}
			}
		} else if p.done() {
			p.expected('template literal end')
			break
		} else {
			p.consume()
		}
	}

	return p.expression(start, ExpressionKind{
		tag:           .template_literal
		template_data: TemplateLiteralData{
			expressions: expressions
			raw_strings: raw_strings
		}
	})
}

fn (p &Parser) process_template_escape_sequences(raw []u16) ?Utf16String {
	result := process_escape_sequences_impl(raw, .tagged_template)
	if result.failed {
		return none
	}
	return result.value
}

// Parse a string literal token's value, processing escape sequences.
// Returns `(value, has_legacy_octal)`.
fn (mut p Parser) parse_string_value(token Token) (Utf16String, bool) {
	raw := p.token_value(token).clone()
	if raw.len < 2 {
		return Utf16String.new(), false
	}
	return p.process_escape_sequences(raw[1..raw.len - 1])
}

fn (mut p Parser) process_escape_sequences(inner []u16) (Utf16String, bool) {
	result := process_escape_sequences_impl(inner, .string_literal)
	if result.malformed_hex {
		p.syntax_error('Malformed hexadecimal escape sequence')
	}
	if result.malformed_unicode {
		p.syntax_error('Malformed unicode escape sequence')
	}
	return result.value, result.has_legacy_octal
}

struct EscapeResult {
mut:
	value             Utf16String
	has_legacy_octal  bool
	failed            bool
	malformed_hex     bool
	malformed_unicode bool
}

// Unified escape sequence processor for both string and template literals.
fn process_escape_sequences_impl(input []u16, mode EscapeMode) EscapeResult {
	mut result := Utf16String{
		data: []u16{cap: input.len}
	}
	mut has_legacy_octal := false
	mut malformed_hex := false
	mut malformed_unicode := false
	mut i := 0

	n_ch := ch(`n`)
	r_ch := ch(`r`)
	t_ch := ch(`t`)
	b_ch := ch(`b`)
	f_ch := ch(`f`)
	v_ch := ch(`v`)
	zero := ch(`0`)
	one := ch(`1`)
	seven := ch(`7`)
	eight := ch(`8`)
	nine := ch(`9`)
	x_ch := ch(`x`)
	u_ch := ch(`u`)
	lf := ch(`\n`)
	cr := ch(`\r`)
	ls := u16(0x2028)
	ps := u16(0x2029)

	for i < input.len {
		if input[i] == u16(`\\`) && i + 1 < input.len {
			i++
			c := input[i]
			if c == n_ch {
				result.data << ch(`\n`)
			} else if c == r_ch {
				result.data << ch(`\r`)
			} else if c == t_ch {
				result.data << ch(`\t`)
			} else if c == b_ch {
				result.data << u16(8)
			} else if c == f_ch {
				result.data << u16(12)
			} else if c == v_ch {
				result.data << u16(11)
			} else if c == zero {
				if mode == .tagged_template {
					if i + 1 < input.len && (is_octal_char(input[i + 1])
						|| input[i + 1] == eight || input[i + 1] == nine) {
						return EscapeResult{
							value:  result
							failed: true
						}
					}
					result.data << u16(0)
				} else if i + 1 < input.len && is_octal_char(input[i + 1]) {
					has_legacy_octal = true
					val, consumed := parse_octal_escape(input, i)
					result.data << val
					i += consumed
				} else if i + 1 < input.len && (input[i + 1] == eight || input[i + 1] == nine) {
					has_legacy_octal = true
					result.data << u16(0)
				} else {
					result.data << u16(0)
				}
			} else if c >= one && c <= seven {
				if mode == .tagged_template {
					return EscapeResult{
						value:  result
						failed: true
					}
				}
				has_legacy_octal = true
				val, consumed := parse_octal_escape(input, i)
				result.data << val
				i += consumed
			} else if c == eight || c == nine {
				if mode == .tagged_template {
					return EscapeResult{
						value:  result
						failed: true
					}
				}
				has_legacy_octal = true
				result.data << input[i]
			} else if c == x_ch {
				if advance, hex_ch := parse_hex_escape(input, i) {
					result.data << hex_ch
					i += advance
				} else if mode == .tagged_template {
					return EscapeResult{
						value:  result
						failed: true
					}
				} else {
					malformed_hex = true
					result.data << input[i]
				}
			} else if c == u_ch {
				if advance, code_point := parse_unicode_escape(input, i) {
					push_code_point(mut result.data, code_point)
					i += advance
				} else if mode == .tagged_template {
					return EscapeResult{
						value:  result
						failed: true
					}
				} else {
					malformed_unicode = true
					result.data << input[i]
				}
			} else if c == lf {
				// line continuation
			} else if c == cr {
				if i + 1 < input.len && input[i + 1] == lf {
					i++
				}
			} else if c == ls || c == ps {
				// skip LS/PS
			} else {
				result.data << c
			}
		} else if input[i] == ch(`\r`) {
			// Normalize \r\n and bare \r to \n per spec (12.9.6).
			result.data << ch(`\n`)
			if i + 1 < input.len && input[i + 1] == ch(`\n`) {
				i++
			}
		} else {
			result.data << input[i]
		}
		i++
	}
	return EscapeResult{
		value:             result
		has_legacy_octal:  has_legacy_octal
		malformed_hex:     malformed_hex
		malformed_unicode: malformed_unicode
	}
}

// Try to parse an arrow function expression. Returns none on failure.
fn (mut p Parser) try_parse_arrow_function_expression(expect_parens bool, is_async bool, forbidden ForbiddenTokens) ?Expression {
	return p.try_parse_arrow_function_expression_impl(expect_parens, is_async, p.position(),
		forbidden)
}

fn (mut p Parser) try_parse_arrow_function_expression_impl(expect_parens bool, is_async bool, source_start_override Position, forbidden ForbiddenTokens) ?Expression {
	start := source_start_override

	if !expect_parens && !is_async {
		if !p.match_identifier() && !p.match_token(.await_kw) && !p.match_token(.yield_kw) {
			return none
		}
		next := p.next_token()
		if next.token_type != .arrow || next.trivia_has_line_terminator {
			return none
		}
	}

	saved_pattern_bound_names := p.pattern_bound_names.clone()
	p.pattern_bound_names = []BoundName{}

	p.save_state()

	saved_formal_parameter_ctx := p.flags.in_formal_parameter_context
	p.flags.in_formal_parameter_context = false

	if is_async {
		p.consume() // consume 'async'
		if p.current_token.trivia_has_line_terminator {
			p.pattern_bound_names = saved_pattern_bound_names
			p.load_state()
			return none
		}
		if expect_parens {
			p.consume_token(.paren_open)
		}
	}

	// Open function scope before parsing parameters.
	p.scope_collector.open_function_scope(none)
	p.scope_collector.set_is_arrow_function()

	saved_await := p.flags.await_expression_is_valid
	saved_static_init := p.flags.in_class_static_init_block
	if is_async {
		p.flags.await_expression_is_valid = true
	}

	mut parsed := ParsedParameters{}

	if expect_parens {
		previous_errors := p.errors.len
		parsed = p.parse_formal_parameters_impl(true)
		if p.errors.len > previous_errors {
			p.pattern_bound_names = saved_pattern_bound_names
			p.load_state()
			return none
		}
		if !p.match_token(.paren_close) {
			p.pattern_bound_names = saved_pattern_bound_names
			p.load_state()
			return none
		}
		p.consume() // consume ')'
	} else if p.match_identifier() || p.match_token(.await_kw) {
		param_token := p.consume()
		value := p.token_value(param_token).clone()
		if utf16_equals(value, utf16('await'))
			&& (is_async || p.program_type == .module || p.flags.in_class_static_init_block) {
			p.syntax_error("'await' is a reserved identifier in async functions")
		}
		binding := Identifier.new(p.range_from(start), Utf16String.from_slice(value.clone()))
		parsed = ParsedParameters{
			parameters:      [
				FunctionParameter{
					binding: IdentifierBinding{
						identifier: binding
					}
				},
			]
			function_length: 1
			parameter_info:  [
				ParamInfo{
					name:       Utf16String.from_slice(value)
					identifier: binding
				},
			]
			is_simple:       true
		}
	} else {
		p.flags.await_expression_is_valid = saved_await
		p.pattern_bound_names = saved_pattern_bound_names
		p.load_state()
		return none
	}

	// Restore await flag during arrow-check.
	p.flags.await_expression_is_valid = saved_await

	// [no LineTerminator here] before `=>`
	if !p.match_token(.arrow) || p.current_token.trivia_has_line_terminator {
		p.pattern_bound_names = saved_pattern_bound_names
		p.load_state()
		return none
	}
	p.consume() // consume =>

	p.discard_saved_state()

	parameters := parsed.parameters
	function_length := parsed.function_length
	parameter_info := parsed.parameter_info
	is_simple := parsed.is_simple

	// Arrow functions always reject duplicate parameter names.
	p.check_arrow_duplicate_parameters(parameter_info)

	p.register_function_parameters_with_scope(parameters, parameter_info)

	fn_kind := if is_async { FunctionKind.async_kind } else { FunctionKind.normal }
	src_start := source_start_override.offset

	// Set context flags for the arrow body.
	saved_await_body := p.flags.await_expression_is_valid
	p.flags.await_expression_is_valid = is_async
	p.flags.in_class_static_init_block = false

	if p.match_token(.curly_open) {
		body, has_use_strict, insights := p.parse_function_body(is_async, false, is_simple)

		p.scope_collector.close_scope()
		p.pattern_bound_names = saved_pattern_bound_names

		if has_use_strict || fn_kind != .normal {
			p.check_parameters_post_body(parameter_info, has_use_strict, fn_kind)
		}

		p.flags.await_expression_is_valid = saved_await_body
		p.flags.in_class_static_init_block = saved_static_init
		p.flags.in_formal_parameter_context = saved_formal_parameter_ctx
		function_id := p.function_table.insert(JsFunctionData{
			source_text_start: src_start
			source_text_end:   p.source_text_end_offset()
			body:              body
			parameters:        parameters
			function_length:   function_length
			kind:              fn_kind
			is_strict_mode:    p.flags.strict_mode || has_use_strict
			is_arrow_function: true
			parsing_insights:  insights
		})
		return p.expression(start, ExpressionKind{
			tag:         .function_expr
			function_id: function_id
		})
	} else {
		// C++ uses rule_start (function start) for ReturnStatement and FunctionBody.
		body_forbidden := if saved_formal_parameter_ctx { ForbiddenTokens{} } else { forbidden }
		expression := p.parse_expression(precedence_assignment, .right, body_forbidden)
		return_statement := Statement.new(p.range_from(start), StatementKind{
			tag:        .return_stmt
			return_arg: &expression
		})
		scope := ScopeData.shared_with_children([return_statement])
		p.scope_collector.set_scope_node(scope)
		body := Statement.new(p.range_from(start), StatementKind{
			tag:            .function_body
			scope:          scope
			in_strict_mode: p.flags.strict_mode
		})

		insights := FunctionParsingInsights{
			contains_direct_call_to_eval: p.scope_collector.contains_direct_call_to_eval()
			uses_this_from_environment:   p.scope_collector.uses_this_from_environment()
		}

		p.scope_collector.close_scope()
		p.pattern_bound_names = saved_pattern_bound_names

		p.flags.await_expression_is_valid = saved_await_body
		p.flags.in_class_static_init_block = saved_static_init
		p.flags.in_formal_parameter_context = saved_formal_parameter_ctx
		function_id := p.function_table.insert(JsFunctionData{
			source_text_start: src_start
			source_text_end:   p.source_text_end_offset()
			body:              body
			parameters:        parameters
			function_length:   function_length
			kind:              fn_kind
			is_strict_mode:    p.flags.strict_mode
			is_arrow_function: true
			parsing_insights:  insights
		})
		return p.expression(start, ExpressionKind{
			tag:         .function_expr
			function_id: function_id
		})
	}
}

fn (mut p Parser) parse_method_definition(is_async bool, is_generator bool, method_kind MethodKind, function_start Position) Expression {
	start := function_start

	saved_might_need_arguments := p.flags.function_might_need_arguments_object
	p.flags.function_might_need_arguments_object = false

	fn_kind := FunctionKind.from_async_generator(is_async, is_generator)

	// Open function scope for method.
	p.scope_collector.open_function_scope(none)

	in_generator_before := p.flags.in_generator_function_context
	await_before := p.flags.await_expression_is_valid
	saved_static_init := p.flags.in_class_static_init_block
	saved_field_init := p.flags.in_class_field_initializer
	saved_new_target := p.flags.new_target_is_valid
	saved_allow_super_call := p.flags.allow_super_constructor_call
	saved_allow_super_lookup := p.flags.allow_super_property_lookup
	p.flags.in_generator_function_context = is_generator
	p.flags.await_expression_is_valid = is_async
	p.flags.in_class_static_init_block = false
	p.flags.in_class_field_initializer = false
	p.flags.new_target_is_valid = true
	p.flags.allow_super_constructor_call = method_kind == .constructor && p.class_has_super_class
	p.flags.allow_super_property_lookup = true

	saved_pattern_bound_names := p.pattern_bound_names.clone()
	p.pattern_bound_names = []BoundName{}

	parsed := p.parse_formal_parameters()
	p.check_unique_formal_parameters(parsed.parameter_info)

	p.register_function_parameters_with_scope(parsed.parameters, parsed.parameter_info)

	if method_kind == .getter && parsed.parameters.len > 0 {
		p.syntax_error('Getter function must have no arguments')
	}
	if method_kind == .setter && (parsed.parameters.len != 1
		|| (parsed.parameters.len > 0 && parsed.parameters[0].is_rest)) {
		p.syntax_error('Setter function must have one argument')
	}

	p.flags.in_generator_function_context = in_generator_before
	p.flags.await_expression_is_valid = await_before

	body, has_use_strict, mut insights := p.parse_function_body(is_async, is_generator,
		parsed.is_simple)
	p.flags.allow_super_constructor_call = saved_allow_super_call
	p.flags.allow_super_property_lookup = saved_allow_super_lookup

	p.scope_collector.close_scope()
	p.pattern_bound_names = saved_pattern_bound_names

	p.flags.in_class_static_init_block = saved_static_init
	p.flags.in_class_field_initializer = saved_field_init
	p.flags.new_target_is_valid = saved_new_target

	parameters_are_strict := p.flags.strict_mode || has_use_strict
	if parameters_are_strict || fn_kind != .normal {
		p.check_parameters_post_body(parsed.parameter_info, parameters_are_strict, fn_kind)
	}

	insights.might_need_arguments_object = p.flags.function_might_need_arguments_object
	p.flags.function_might_need_arguments_object = saved_might_need_arguments

	// Class constructors always need a function environment for `this` binding.
	if method_kind == .constructor {
		insights.uses_this = true
		insights.uses_this_from_environment = true
	}

	function_id := p.function_table.insert(JsFunctionData{
		source_text_start: function_start.offset
		source_text_end:   p.source_text_end_offset()
		body:              body
		parameters:        parsed.parameters
		function_length:   parsed.function_length
		kind:              fn_kind
		is_strict_mode:    p.flags.strict_mode || has_use_strict
		parsing_insights:  insights
	})
	return p.expression(start, ExpressionKind{
		tag:         .function_expr
		function_id: function_id
	})
}

// === Helper functions ===

fn hex_digit(c u16) ?u16 {
	if c >= 0x30 && c <= 0x39 {
		return c - 0x30
	}
	if c >= 0x41 && c <= 0x46 {
		return c - 0x41 + 10
	}
	if c >= 0x61 && c <= 0x66 {
		return c - 0x61 + 10
	}
	return none
}

fn is_octal_char(c u16) bool {
	return c >= ch(`0`) && c <= ch(`7`)
}

fn parse_octal_escape(inner []u16, i int) (u16, int) {
	first := u32(inner[i] - ch(`0`))
	mut value := first
	mut consumed := 0

	if i + 1 < inner.len && is_octal_char(inner[i + 1]) {
		value = value * 8 + u32(inner[i + 1] - ch(`0`))
		consumed = 1

		if i + 2 < inner.len && is_octal_char(inner[i + 2]) && first <= 3 {
			value = value * 8 + u32(inner[i + 2] - ch(`0`))
			consumed = 2
		}
	}
	return u16(value), consumed
}

fn parse_hex_escape(raw []u16, i int) ?(int, u16) {
	if i + 2 >= raw.len {
		return none
	}
	high := hex_digit(raw[i + 1]) or { return none }
	low := hex_digit(raw[i + 2]) or { return none }
	return 2, high * 16 + low
}

fn parse_unicode_escape(raw []u16, i int) ?(int, u32) {
	if i + 1 >= raw.len {
		return none
	}
	if raw[i + 1] == ch(`{`) {
		mut j := i + 2
		mut value := u32(0)
		mut digits := 0
		for j < raw.len && raw[j] != ch(`}`) {
			d := hex_digit(raw[j]) or { return none }
			value = value * 16 + u32(d)
			if value > 0x10FFFF {
				return none
			}
			digits++
			j++
		}
		if j >= raw.len || digits == 0 {
			return none
		}
		return j - i, value
	} else {
		if i + 4 >= raw.len {
			return none
		}
		d0 := u32(hex_digit(raw[i + 1]) or { return none })
		d1 := u32(hex_digit(raw[i + 2]) or { return none })
		d2 := u32(hex_digit(raw[i + 3]) or { return none })
		d3 := u32(hex_digit(raw[i + 4]) or { return none })
		return 4, (d0 << 12) | (d1 << 8) | (d2 << 4) | d3
	}
}

fn push_code_point(mut result []u16, code_point u32) {
	if code_point > 0xFFFF {
		adjusted := code_point - 0x10000
		result << u16(0xD800 | ((adjusted >> 10) & 0x3FF))
		result << u16(0xDC00 | (adjusted & 0x3FF))
	} else {
		result << u16(code_point)
	}
}

fn raw_template_value(raw []u16) Utf16String {
	mut result := Utf16String{
		data: []u16{cap: raw.len}
	}
	mut i := 0
	for i < raw.len {
		if raw[i] == ch(`\r`) {
			result.data << ch(`\n`)
			if i + 1 < raw.len && raw[i + 1] == ch(`\n`) {
				i++
			}
		} else {
			result.data << raw[i]
		}
		i++
	}
	return result
}

fn token_to_binary_op(tt TokenType) BinaryOp {
	return match tt {
		.plus { .addition }
		.minus { .subtraction }
		.asterisk { .multiplication }
		.slash { .division }
		.percent { .modulo }
		.double_asterisk { .exponentiation }
		.equals_equals_equals { .strictly_equals }
		.exclamation_mark_equals_equals { .strictly_inequals }
		.equals_equals { .loosely_equals }
		.exclamation_mark_equals { .loosely_inequals }
		.greater_than { .greater_than }
		.greater_than_equals { .greater_than_equals }
		.less_than { .less_than }
		.less_than_equals { .less_than_equals }
		.ampersand { .bitwise_and }
		.pipe { .bitwise_or }
		.caret { .bitwise_xor }
		.shift_left { .left_shift }
		.shift_right { .right_shift }
		.unsigned_shift_right { .unsigned_right_shift }
		.in_kw { .in_op }
		.instanceof_kw { .instance_of }
		else { .addition }
	}
}

fn token_to_assignment_op(tt TokenType) AssignmentOp {
	return match tt {
		.equals { .assignment }
		.plus_equals { .addition_assignment }
		.minus_equals { .subtraction_assignment }
		.asterisk_equals { .multiplication_assignment }
		.slash_equals { .division_assignment }
		.percent_equals { .modulo_assignment }
		.double_asterisk_equals { .exponentiation_assignment }
		.ampersand_equals { .bitwise_and_assignment }
		.pipe_equals { .bitwise_or_assignment }
		.caret_equals { .bitwise_xor_assignment }
		.shift_left_equals { .left_shift_assignment }
		.shift_right_equals { .right_shift_assignment }
		.unsigned_shift_right_equals { .unsigned_right_shift_assignment }
		.double_ampersand_equals { .and_assignment }
		.double_pipe_equals { .or_assignment }
		.double_question_mark_equals { .nullish_assignment }
		else { .assignment }
	}
}

fn parse_numeric_value(value []u16) f64 {
	// Filter underscores and convert to ASCII string.
	mut buf := []u8{cap: value.len}
	for c in value {
		if c != u16(`_`) {
			buf << u8(c)
		}
	}
	s := buf.bytestr()

	if s.starts_with('0x') || s.starts_with('0X') {
		return parse_integer_with_radix(s[2..], 16)
	} else if s.starts_with('0o') || s.starts_with('0O') {
		return parse_integer_with_radix(s[2..], 8)
	} else if s.starts_with('0b') || s.starts_with('0B') {
		return parse_integer_with_radix(s[2..], 2)
	} else if s.len > 1 && s[0] == `0` && s[1] >= `0` && s[1] <= `9` {
		digits := s[1..]
		mut all_octal := true
		for b in digits.bytes() {
			if b < `0` || b > `7` {
				all_octal = false
				break
			}
		}
		if all_octal {
			return parse_integer_with_radix(digits, 8)
		}
		return s.f64()
	} else {
		return s.f64()
	}
}

fn parse_integer_with_radix(digits string, radix u32) f64 {
	mut result := f64(0)
	for c in digits.bytes() {
		mut d := u32(0)
		if c >= `0` && c <= `9` {
			d = u32(c - `0`)
		} else if c >= `a` && c <= `f` {
			d = u32(c - `a` + 10)
		} else if c >= `A` && c <= `F` {
			d = u32(c - `A` + 10)
		} else {
			continue
		}
		result = result * f64(radix) + f64(d)
	}
	return result
}
