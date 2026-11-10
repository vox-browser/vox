module libjs

// Declaration parsing: variables, functions, classes, imports, exports.
//
// Translated from declarations.rs.

fn expression_into_identifier(expression Expression) &Identifier {
	if id := expression.kind.identifier {
		return id
	}
	panic('expected Identifier expression')
}

// Extract bound names from a declaration for export statements.
fn get_declaration_export_names(stmt &Statement) []Utf16String {
	match stmt.kind.tag {
		.variable_declaration {
			mut names := []Utf16String{}
			for declaration in stmt.kind.declarations {
				collect_declarator_names(declaration.target, mut names)
			}
			return names
		}
		.using_declaration {
			mut names := []Utf16String{}
			for declaration in stmt.kind.declarations {
				match declaration.target {
					IdentifierVarTarget {
						names << declaration.target.identifier.name.clone()
					}
					else {}
				}
			}
			return names
		}
		.function_declaration {
			if name := stmt.kind.func_name {
				return [name.name.clone()]
			}
			return []Utf16String{}
		}
		.class_declaration {
			if cd := stmt.kind.class_data {
				if name := cd.name {
					return [name.name.clone()]
				}
			}
			return []Utf16String{}
		}
		else {
			return []Utf16String{}
		}
	}
}

fn collect_declarator_names(target VariableDeclaratorTarget, mut names []Utf16String) {
	match target {
		IdentifierVarTarget {
			names << target.identifier.name.clone()
		}
		BindingPatternVarTarget {
			collect_pattern_names(target.pattern, mut names)
		}
	}
}

fn collect_pattern_names(pat BindingPattern, mut names []Utf16String) {
	for entry in pat.entries {
		match entry.alias.kind {
			.identifier_kind {
				if id := entry.alias.identifier {
					names << id.name.clone()
				}
			}
			.binding_pattern_kind {
				if nested := entry.alias.binding_pattern {
					collect_pattern_names(nested, mut names)
				}
			}
			else {}
		}

		if entry.alias.kind == .none_kind {
			if entry.name.kind == .identifier_kind {
				if id := entry.name.identifier {
					names << id.name.clone()
				}
			}
		}
	}
}

fn (mut p Parser) parse_declaration() Statement {
	if p.match_token(.async) {
		next := p.next_token()
		if next.token_type == .function_kw && !next.trivia_has_line_terminator {
			return p.parse_function_declaration()
		}
	}

	return match p.current_token_type() {
		.function_kw {
			p.parse_function_declaration()
		}
		.class_kw {
			p.parse_class_declaration()
		}
		.let_kw, .const_kw {
			p.parse_variable_declaration(false)
		}
		else {
			if p.match_token(.identifier)
				&& utf16_equals(p.token_value(p.current_token), utf16('using')) {
				if !p.scope_collector.can_have_using_declaration() {
					p.syntax_error("'using' not allowed outside of block, for loop or function")
				}
				p.parse_using_declaration(false)
			} else {
				p.expected('declaration')
				start := p.position()
				p.consume()
				p.statement(start, StatementKind.empty())
			}
		}
	}
}

// https://tc39.es/ecma262/#sec-variable-statement
// https://tc39.es/ecma262/#sec-let-and-const-declarations
fn (mut p Parser) parse_variable_declaration(is_for_loop bool) Statement {
	start := p.position()
	declaration_line := p.current_token.line_number
	declaration_column := p.current_token.line_column

	kind := match p.current_token_type() {
		.var_kw {
			DeclarationKind.var_kind
		}
		.let_kw {
			DeclarationKind.let_kind
		}
		.const_kw {
			DeclarationKind.const_kind
		}
		else {
			p.expected('variable declaration keyword')
			DeclarationKind.var_kind
		}
	}

	p.consume()

	mut declarators := []VariableDeclarator{}
	mut any_init := false

	for {
		declaration_start := p.position()

		target := if p.match_identifier() {
			token := p.consume()
			value := p.token_value(token).clone()
			p.check_identifier_name_for_assignment_validity(value, false)
			if kind != .var_kind && utf16_equals(value, utf16('let')) {
				p.syntax_error("Lexical binding may not be called 'let'")
			}
			id := p.make_identifier(declaration_start, Utf16String.from_slice(value.clone()))

			if kind == .var_kind {
				p.scope_collector.add_var_declaration(value.clone(), id, declaration_line,
					declaration_column, true)
			} else {
				p.scope_collector.add_lexical_declaration(value.clone(), declaration_line,
					declaration_column)
				p.scope_collector.register_identifier(id, value, int(kind))
			}

			VariableDeclaratorTarget(IdentifierVarTarget{
				identifier: id
			})
		} else if p.match_token(.curly_open) || p.match_token(.bracket_open) {
			pat := p.parse_binding_pattern()
			bound_names := p.pattern_bound_names.clone()
			p.pattern_bound_names = []BoundName{}

			for bn in bound_names {
				p.check_identifier_name_for_assignment_validity(bn.name.data, false)
				if kind != .var_kind && utf16_equals(bn.name.data, utf16('let')) {
					p.syntax_error("Lexical binding may not be called 'let'")
				}
			}

			if kind != .var_kind {
				mut seen := map[string]bool{}
				for bn in bound_names {
					key := bn.name.str()
					if key in seen {
						p.syntax_error('Duplicate parameter names in bindings')
					}
					seen[key] = true
				}
			}

			// Register bound names with scope collector.
			if kind == .var_kind {
				for bn in bound_names {
					p.scope_collector.add_var_declaration(bn.name.data.clone(), bn.identifier,
						declaration_line, declaration_column, true)
				}
			} else {
				for bn in bound_names {
					p.scope_collector.add_lexical_declaration(bn.name.data.clone(),
						declaration_line, declaration_column)
					p.scope_collector.register_identifier(bn.identifier, bn.name.data, int(kind))
				}
			}

			VariableDeclaratorTarget(BindingPatternVarTarget{
				pattern: pat
			})
		} else {
			p.expected('identifier or a binding pattern')
			p.consume()
			id := p.make_identifier(declaration_start, Utf16String{})
			VariableDeclaratorTarget(IdentifierVarTarget{
				identifier: id
			})
		}

		mut init := ?Expression(none)
		if p.match_token(.equals) {
			p.consume()
			any_init = true
			forbidden := if is_for_loop {
				ForbiddenTokens.with_in()
			} else {
				ForbiddenTokens{}
			}
			init = p.parse_expression(precedence_assignment, .right, forbidden)
		}

		declarators << VariableDeclarator{
			range:  p.range_from(start)
			target: target
			init:   init
		}

		if !p.match_token(.comma) {
			break
		}
		p.consume()
	}

	if !is_for_loop {
		p.consume_or_insert_semicolon()
	}

	if is_for_loop {
		p.for_loop_declaration_count = declarators.len
		p.for_loop_declaration_has_init = any_init
		p.for_loop_declaration_is_var = kind == .var_kind
	}

	return p.statement(start, StatementKind{
		tag:          .variable_declaration
		decl_kind:    kind
		declarations: declarators
	})
}

// https://tc39.es/proposal-explicit-resource-management/
fn (mut p Parser) parse_using_declaration(is_for_loop bool) Statement {
	start := p.position()
	declaration_line := p.current_token.line_number
	declaration_column := p.current_token.line_column
	p.consume() // consume 'using'

	mut declarators := []VariableDeclarator{}

	for {
		declaration_start := p.position()

		if !p.match_identifier() {
			p.expected('identifier')
			break
		}
		token := p.consume()
		name := p.token_value(token).clone()

		p.check_identifier_name_for_assignment_validity(name, false)
		if utf16_equals(name, utf16('let')) {
			p.syntax_error("Lexical binding may not be called 'let'")
		}

		id := p.make_identifier(declaration_start, Utf16String.from_slice(name.clone()))

		p.scope_collector.add_lexical_declaration(name.clone(), declaration_line,
			declaration_column)
		p.scope_collector.register_identifier(id, name, none)

		mut init := ?Expression(none)
		if p.match_token(.equals) {
			p.consume()
			if is_for_loop {
				init = p.parse_expression(precedence_assignment, .right, ForbiddenTokens.with_in())
			} else {
				init = p.parse_assignment_expression()
			}
		} else if !is_for_loop {
			p.consume_token(.equals)
		}

		declarators << VariableDeclarator{
			range:  p.range_from(start)
			target: IdentifierVarTarget{
				identifier: id
			}
			init:   init
		}

		if p.match_token(.comma) {
			p.consume()
			continue
		}
		break
	}

	if !is_for_loop {
		p.consume_or_insert_semicolon()
	}

	if is_for_loop {
		any_init := declarators.any(it.init != none)
		p.for_loop_declaration_count = declarators.len
		p.for_loop_declaration_has_init = any_init
	}

	return p.statement(start, StatementKind{
		tag:          .using_declaration
		declarations: declarators
	})
}

// https://tc39.es/ecma262/#sec-function-definitions
fn (mut p Parser) parse_function_declaration() Statement {
	start := p.position()
	declaration_line := p.current_token.line_number
	declaration_column := p.current_token.line_column

	saved_might_need_arguments := p.flags.function_might_need_arguments_object
	p.flags.function_might_need_arguments_object = false

	is_async := p.eat(.async)
	p.consume_token(.function_kw)
	is_generator := p.eat(.asterisk)
	kind := FunctionKind.from_async_generator(is_async, is_generator)

	// Parse function name.
	mut name := ?&Identifier(none)
	mut fn_name := Utf16String{}
	if p.has_default_export_name && !p.match_identifier() {
		default_name := Utf16String.from_slice(utf16('*default*'))
		p.last_function_name = default_name.clone()
		name = p.make_identifier(start, default_name.clone())
		fn_name = default_name
	} else if p.match_identifier() {
		token := p.consume()
		value := Utf16String.from_slice(p.token_value(token))
		p.last_function_name = value.clone()
		name = p.make_identifier(start, value.clone())
		fn_name = value
	} else {
		p.last_function_name = Utf16String{}
	}
	p.last_function_kind = kind

	// Register function declaration in parent scope.
	p.scope_collector.add_function_declaration(fn_name, name, kind, p.flags.strict_mode,
		declaration_line, declaration_column)

	fn_name_for_scope := if fn_name.data.len > 0 {
		?Utf16String(fn_name)
	} else {
		?Utf16String(none)
	}
	p.scope_collector.open_function_scope(fn_name_for_scope)
	p.scope_collector.set_is_function_declaration()

	fd := p.parse_function_common(name, fn_name, kind, is_async, is_generator, start,
		saved_might_need_arguments)
	decl_name := fd.name
	decl_kind := fd.kind
	function_id := p.function_table.insert(fd)
	return p.statement(start, StatementKind{
		tag:         .function_declaration
		function_id: function_id
		func_name:   decl_name
		func_kind:   decl_kind
		is_hoisted:  false
	})
}

// https://tc39.es/ecma262/#sec-function-definitions
fn (mut p Parser) parse_function_expression() Expression {
	start := p.position()

	saved_might_need_arguments := p.flags.function_might_need_arguments_object
	p.flags.function_might_need_arguments_object = false

	is_async := p.eat(.async)
	p.consume_token(.function_kw)
	is_generator := p.eat(.asterisk)
	kind := FunctionKind.from_async_generator(is_async, is_generator)

	mut fn_name_value := Utf16String{}
	mut name := ?&Identifier(none)
	if p.match_identifier() {
		token := p.consume()
		fn_name_value = Utf16String.from_slice(p.token_value(token))
		name = p.make_identifier(start, fn_name_value.clone())
	} else if p.match_token(.yield_kw) || p.match_token(.await_kw) {
		token := p.consume()
		fn_name_value = Utf16String.from_slice(p.token_value(token))
		name = p.make_identifier(start, fn_name_value.clone())
	}

	// Register the function expression name in the outer scope.
	if kind == .generator && utf16_equals(fn_name_value.data, utf16('yield')) {
		p.syntax_error("'yield' is not allowed as a generator function expression name")
	}

	if n := name {
		p.scope_collector.register_identifier(n, fn_name_value.data, none)
	}

	// Open function scope.
	fn_name_for_scope := if fn_name_value.data.len > 0 {
		?Utf16String(fn_name_value)
	} else {
		?Utf16String(none)
	}
	p.scope_collector.open_function_scope(fn_name_for_scope)

	fd := p.parse_function_common(name, fn_name_value, kind, is_async, is_generator, start,
		saved_might_need_arguments)
	function_id := p.function_table.insert(fd)
	return p.expression(start, ExpressionKind{
		tag:         .function_expr
		function_id: function_id
	})
}

// Shared logic for parsing formal parameters, function body, and constructing FunctionData.
fn (mut p Parser) parse_function_common(name ?&Identifier, fn_name Utf16String, kind FunctionKind, is_async bool, is_generator bool, start Position, saved_might_need_arguments bool) JsFunctionData {
	// Validate name against async generator and class static init restrictions.
	if name != none {
		if kind == .async_generator && (utf16_equals(fn_name.data, utf16('await'))
			|| utf16_equals(fn_name.data, utf16('yield'))) {
			name_str := string_from_utf16_lossy(fn_name.data)
			p.syntax_error("async generator function is not allowed to be called '${name_str}'")
		}
		if p.flags.in_class_static_init_block && is_async
			&& utf16_equals(fn_name.data, utf16('await')) {
			p.syntax_error("'await' is a reserved word")
		}
	}

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
	p.flags.allow_super_constructor_call = false
	p.flags.allow_super_property_lookup = false

	saved_pattern_bound_names := p.pattern_bound_names.clone()
	p.pattern_bound_names = []BoundName{}

	parsed := p.parse_formal_parameters()
	p.register_function_parameters_with_scope(parsed.parameters, parsed.parameter_info)

	p.flags.in_generator_function_context = in_generator_before
	p.flags.await_expression_is_valid = await_before

	body, has_use_strict, mut insights := p.parse_function_body(is_async, is_generator,
		parsed.is_simple)
	p.flags.allow_super_constructor_call = saved_allow_super_call
	p.flags.allow_super_property_lookup = saved_allow_super_lookup

	p.scope_collector.close_scope()
	p.pattern_bound_names = saved_pattern_bound_names

	if name != none {
		p.check_identifier_name_for_assignment_validity(fn_name.data, has_use_strict)
	}
	parameters_are_strict := p.flags.strict_mode || has_use_strict
	if parameters_are_strict || kind != .normal {
		p.check_parameters_post_body(parsed.parameter_info, parameters_are_strict, kind)
	}
	p.flags.in_class_static_init_block = saved_static_init
	p.flags.in_class_field_initializer = saved_field_init
	p.flags.new_target_is_valid = saved_new_target

	insights.might_need_arguments_object = p.flags.function_might_need_arguments_object
	p.flags.function_might_need_arguments_object = saved_might_need_arguments

	return JsFunctionData{
		name:              name
		source_text_start: start.offset
		source_text_end:   p.source_text_end_offset()
		body:              body
		parameters:        parsed.parameters
		function_length:   parsed.function_length
		kind:              kind
		is_strict_mode:    p.flags.strict_mode || has_use_strict
		is_arrow_function: false
		parsing_insights:  insights
	}
}

// https://tc39.es/ecma262/#sec-class-definitions
fn (mut p Parser) parse_class_expression(expect_name bool) Expression {
	start := p.position()

	strict_before := p.flags.strict_mode
	p.flags.strict_mode = true

	p.consume_token(.class_kw)

	mut name_id := ?&Identifier(none)
	mut name_value := Utf16String{}
	if expect_name || p.match_identifier() {
		if p.match_identifier() {
			token := p.consume()
			value := Utf16String.from_slice(p.token_value(token))
			p.last_class_name = value.clone()
			name_id = p.make_identifier(start, value.clone())
			name_value = value
		} else if expect_name {
			p.expected('class name')
			p.last_class_name = Utf16String{}
		} else {
			p.last_class_name = Utf16String{}
		}
	} else {
		p.last_class_name = Utf16String{}
	}

	saved_class_name := p.last_class_name.clone()

	class_name_for_scope := if name_value.data.len > 0 {
		?Utf16String(name_value)
	} else {
		?Utf16String(none)
	}
	p.scope_collector.open_class_declaration_scope(class_name_for_scope)

	if name_id != none {
		p.check_identifier_name_for_assignment_validity(name_value.data, true)
		if p.flags.in_class_static_init_block && utf16_equals(name_value.data, utf16('await')) {
			p.syntax_error("Identifier must not be a reserved word in modules ('await')")
		}
	}

	mut super_class := ?Expression(none)
	if p.match_token(.extends_kw) {
		p.consume()
		heritage_start := p.position()
		expression := p.parse_expression_any()
		if expression.range.start.offset == heritage_start.offset
			&& expression.kind.tag == .function_expr
			&& p.function_table.get(expression.kind.function_id).is_arrow_function {
			p.syntax_error('Arrow function is not allowed in class heritage')
		}
		super_class = expression
	}

	p.consume_token(.curly_open)
	mut elements := []ClassElementNode{}
	mut constructor := ?Expression(none)
	mut found_private_names := map[string]FoundPrivateName{}

	p.referenced_private_names_stack << map[string]bool{}

	saved_class_has_super := p.class_has_super_class
	p.class_has_super_class = super_class != none
	p.class_scope_depth += 1

	for !p.match_token(.curly_close) && !p.done() {
		if p.match_token(.semicolon) {
			p.consume()
			continue
		}

		element, maybe_ctor := p.parse_class_element(start, mut found_private_names)
		if maybe_ctor != none {
			if constructor != none {
				p.syntax_error('Classes may not have more than one constructor')
			}
			constructor = maybe_ctor
		} else if elem := element {
			elements << elem
		}
	}

	p.consume_token(.curly_close)
	p.class_scope_depth -= 1
	p.class_has_super_class = saved_class_has_super

	// AllPrivateNamesValid
	if p.referenced_private_names_stack.len > 0 {
		referenced := p.referenced_private_names_stack.pop()
		for ref_name, _ in referenced {
			if ref_name in found_private_names {
				continue
			}
			if p.referenced_private_names_stack.len > 0 {
				last_idx := p.referenced_private_names_stack.len - 1
				p.referenced_private_names_stack[last_idx][ref_name] = true
			} else {
				p.syntax_error("Reference to undeclared private field or method '${ref_name}'")
			}
		}
	}
	p.flags.strict_mode = strict_before

	p.scope_collector.close_scope()

	if constructor == none {
		constructor = p.synthesize_default_constructor(start, name_value, super_class != none)
	}

	p.last_class_name = saved_class_name

	return p.expression(start, ExpressionKind{
		tag:        .class_expr
		class_data: &ClassData{
			name:              name_id
			source_text_start: start.offset
			source_text_end:   p.source_text_end_offset()
			constructor:       constructor
			super_class:       super_class
			elements:          elements
		}
	})
}

fn (mut p Parser) parse_class_declaration() Statement {
	start := p.position()
	class_expression := p.parse_class_expression(true)
	// Convert the class expression into a class declaration.
	if class_expression.kind.tag == .class_expr {
		if cd := class_expression.kind.class_data {
			if name_ident := cd.name {
				p.scope_collector.add_lexical_declaration(name_ident.name.data.clone(), start.line,
					start.column)
				p.scope_collector.register_identifier(name_ident, name_ident.name.data, none)
			}
			return p.statement(start, StatementKind{
				tag:        .class_declaration
				class_data: cd
			})
		}
	}
	panic('parse_class_expression must return ExpressionKind.class_expr')
}

fn (mut p Parser) synthesize_default_constructor(start Position, class_name Utf16String, has_super bool) Expression {
	mut ctor_name := ?&Identifier(none)
	if class_name.data.len > 0 {
		ctor_name = p.make_identifier(start, class_name)
	}

	if has_super {
		arguments_name := Utf16String.from_slice(utf16('args'))

		arguments_ref := Identifier.new(p.range_from(start), arguments_name.clone())
		arguments_expression := p.expression(start, ExpressionKind.identifier_kind(arguments_ref))

		super_call := p.expression(start, ExpressionKind{
			tag:             .super_call
			super_call_data: &SuperCallData{
				arguments:    [
					CallArgument{
						value:     arguments_expression
						is_spread: true
					},
				]
				is_synthetic: true
			}
		})
		mut return_stmt := p.statement(start, StatementKind{
			tag:        .return_stmt
			return_arg: &super_call
		})
		body := p.statement(start, StatementKind{
			tag:   .block
			scope: ScopeData.shared_with_children([return_stmt])
		})

		arguments_binding := Identifier.new(p.range_from(start), arguments_name)
		parameters := [
			FunctionParameter{
				binding: IdentifierBinding{
					identifier: arguments_binding
				}
				is_rest: true
			},
		]

		function_id := p.function_table.insert(JsFunctionData{
			name:              ctor_name
			source_text_start: start.offset
			source_text_end:   p.source_text_end_offset()
			body:              body
			parameters:        parameters
			function_length:   0
			kind:              .normal
			is_strict_mode:    true
			is_arrow_function: false
			parsing_insights:  FunctionParsingInsights{
				uses_this:                  true
				uses_this_from_environment: true
			}
		})
		return p.expression(start, ExpressionKind{
			tag:         .function_expr
			function_id: function_id
		})
	} else {
		body := p.statement(start, StatementKind{
			tag:   .block
			scope: ScopeData.shared_with_children([]Statement{})
		})

		function_id := p.function_table.insert(JsFunctionData{
			name:              ctor_name
			source_text_start: start.offset
			source_text_end:   p.source_text_end_offset()
			body:              body
			parameters:        []FunctionParameter{}
			function_length:   0
			kind:              .normal
			is_strict_mode:    true
			is_arrow_function: false
			parsing_insights:  FunctionParsingInsights{
				uses_this:                  true
				uses_this_from_environment: true
			}
		})
		return p.expression(start, ExpressionKind{
			tag:         .function_expr
			function_id: function_id
		})
	}
}

// Helper struct to track found private names in a class body.
struct FoundPrivateName {
mut:
	kind      ?ClassMethodKind
	is_static bool
}

fn (mut p Parser) parse_class_element(class_start Position, mut found_private_names map[string]FoundPrivateName) (?ClassElementNode, ?Expression) {
	// Check for static keyword.
	mut is_static := if p.match_identifier()
		&& utf16_equals(p.token_original_value(p.current_token), utf16('static')) {
		p.consume()
		// ClassStaticBlock : `static` `{` ClassStaticBlockBody `}`
		if p.match_token(.curly_open) {
			static_start := p.position()
			p.consume() // consume '{'
			saved_flags := p.flags
			p.flags.in_break_context = false
			p.flags.in_continue_context = false
			p.flags.in_function_context = false
			p.flags.in_generator_function_context = false
			p.flags.await_expression_is_valid = false
			p.flags.in_class_field_initializer = true
			p.flags.in_class_static_init_block = true
			p.flags.new_target_is_valid = true
			p.flags.allow_super_property_lookup = true
			p.scope_collector.open_static_init_scope()
			children := p.parse_statement_list(false)
			p.flags = saved_flags
			p.consume_token(.curly_close)
			scope := ScopeData.shared_with_children(children)
			p.scope_collector.set_scope_node(scope)
			p.scope_collector.close_scope()
			body := p.statement(class_start, StatementKind{
				tag:            .function_body
				scope:          scope
				in_strict_mode: p.flags.strict_mode
			})
			return ClassElementNode{
				range: p.range_from(static_start)
				kind:  ClassElementStaticInit{
					body: body
				}
			}, none
		}
		true
	} else {
		false
	}

	mut is_async := false
	mut is_generator := false
	mut is_getter := false
	mut is_setter := false
	function_start := p.position()

	// Check modifiers.
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
				&& next.token_type != .curly_close && next.token_type != .semicolon
				&& next.token_type != .equals {
				is_async = true
				p.consume()
			}
		}
	}

	if p.match_token(.asterisk) {
		is_generator = true
		p.consume()
	}

	// If we consumed a modifier but the next token can't start a property key, it was the name.
	mut key := PropertyKey{}
	if (is_static || is_async || is_getter || is_setter)
		&& (p.match_token(.semicolon) || p.match_token(.equals)
		|| p.match_token(.paren_open) || p.match_token(.curly_close)) {
		mut modifier_name := []u16{}
		if is_async {
			is_async = false
			modifier_name = utf16('async').clone()
		} else if is_getter {
			is_getter = false
			modifier_name = utf16('get').clone()
		} else if is_setter {
			is_setter = false
			modifier_name = utf16('set').clone()
		} else {
			is_static = false
			modifier_name = utf16('static').clone()
		}
		key_expression := p.expression(class_start, ExpressionKind{
			tag:          .string_literal
			string_value: Utf16String.from_slice(modifier_name)
		})
		key = PropertyKey{
			expression:    key_expression
			name:          Utf16String.from_slice(modifier_name)
			is_proto:      false
			is_computed:   false
			is_identifier: false
		}
	} else {
		key = p.parse_property_key()
	}

	// Static prototype check.
	if is_static {
		if kn := key.name {
			if utf16_equals(kn.data, utf16('prototype')) {
				p.syntax_error("Classes may not have a static property named 'prototype'")
			}
		}
	}

	// Private name duplicate check.
	is_private := if kn := key.name { kn.data.len > 0 && kn.data[0] == ch(`#`) } else { false }
	if is_private {
		name_key := if kn := key.name { kn.str() } else { '' }
		mut current_kind := ?ClassMethodKind(none)
		if is_getter {
			current_kind = .getter
		} else if is_setter {
			current_kind = .setter
		}
		is_accessor := is_getter || is_setter
		if is_accessor {
			if name_key in found_private_names {
				existing := found_private_names[name_key]
				mut is_error := false
				if existing_kind := existing.kind {
					if existing.is_static != is_static || existing_kind == .method {
						is_error = true
					} else if ck := current_kind {
						if existing_kind == ck {
							is_error = true
						}
					}
				} else {
					is_error = true
				}
				if is_error {
					p.syntax_error("Duplicate private field or method named '${name_key}'")
				}
			}
			found_private_names[name_key] = FoundPrivateName{
				kind:      current_kind
				is_static: is_static
			}
		} else {
			if name_key in found_private_names {
				p.syntax_error("Duplicate private field or method named '${name_key}'")
			}
			found_private_names[name_key] = FoundPrivateName{
				kind:      current_kind
				is_static: is_static
			}
		}
	}

	if p.match_token(.paren_open) {
		ctor_name := utf16('constructor')
		is_constructor := !is_static && !is_getter && !is_setter
			&& if kn := key.name { utf16_equals(kn.data, ctor_name) } else { false }

		if is_constructor {
			if is_getter || is_setter {
				p.syntax_error('Class constructor may not be an accessor')
			}
			if is_generator {
				p.syntax_error('Class constructor may not be a generator')
			}
			if is_async {
				p.syntax_error('Class constructor may not be async')
			}
		}

		method_kind := if is_constructor {
			MethodKind.constructor
		} else if is_getter {
			MethodKind.getter
		} else if is_setter {
			MethodKind.setter
		} else {
			MethodKind.normal
		}
		function := p.parse_method_definition(is_async, is_generator, method_kind, function_start)
		class_method_kind := if is_getter {
			ClassMethodKind.getter
		} else if is_setter {
			ClassMethodKind.setter
		} else {
			ClassMethodKind.method
		}

		if is_constructor {
			return none, function
		}

		return ClassElementNode{
			range: p.range_from(class_start)
			kind:  ClassElementMethod{
				key:         key.expression
				function:    function
				method_kind: class_method_kind
				is_static:   is_static
			}
		}, none
	}

	// Field definition: constructor name check.
	if kn := key.name {
		if utf16_equals(kn.data, utf16('constructor')) {
			p.syntax_error("Class cannot have field named 'constructor'")
		}
	}

	mut init := ?Expression(none)
	if p.match_token(.equals) {
		p.consume()
		saved_await := p.flags.await_expression_is_valid
		saved_field_init := p.flags.in_class_field_initializer
		saved_super_lookup := p.flags.allow_super_property_lookup
		p.flags.await_expression_is_valid = false
		p.flags.in_class_field_initializer = true
		p.flags.allow_super_property_lookup = true
		p.scope_collector.open_class_field_scope()
		init = p.parse_assignment_expression()
		p.scope_collector.close_scope()
		p.flags.await_expression_is_valid = saved_await
		p.flags.in_class_field_initializer = saved_field_init
		p.flags.allow_super_property_lookup = saved_super_lookup
	}

	p.consume_or_insert_semicolon()
	return ClassElementNode{
		range: p.range_from(class_start)
		kind:  ClassElementField{
			key:         key.expression
			initializer: init
			is_static:   is_static
		}
	}, none
}

// https://tc39.es/ecma262/#sec-function-definitions-static-semantics-early-errors
fn (mut p Parser) parse_function_body(is_async bool, is_generator bool, is_simple bool) (Statement, bool, FunctionParsingInsights) {
	p.consume_token(.curly_open)
	start := p.position()

	in_function_before := p.flags.in_function_context
	in_generator_before := p.flags.in_generator_function_context
	await_before := p.flags.await_expression_is_valid
	formal_parameter_before := p.flags.in_formal_parameter_context
	mut old_labels := p.labels_in_scope.move()
	p.labels_in_scope = map[string]LabelValue{}
	p.flags.in_function_context = true
	p.flags.in_generator_function_context = is_generator
	p.flags.await_expression_is_valid = is_async
	p.flags.in_formal_parameter_context = false

	has_use_strict, mut children := p.parse_directive()
	body_is_strict := has_use_strict || p.flags.strict_mode

	strict_before := p.flags.strict_mode
	if has_use_strict {
		p.flags.strict_mode = true
		if !is_simple {
			p.syntax_error("Illegal 'use strict' directive in function with non-simple parameter list")
		}
	}

	children << p.parse_statement_list(true)

	p.flags.strict_mode = strict_before
	p.flags.in_function_context = in_function_before
	p.flags.in_generator_function_context = in_generator_before
	p.flags.await_expression_is_valid = await_before
	p.flags.in_formal_parameter_context = formal_parameter_before
	p.labels_in_scope = old_labels.move()

	// Read scope analysis flags before the function scope is closed.
	insights := FunctionParsingInsights{
		contains_direct_call_to_eval: p.scope_collector.contains_direct_call_to_eval()
		uses_this:                    p.scope_collector.uses_this()
		uses_this_from_environment:   p.scope_collector.uses_this_from_environment()
	}

	p.consume_token(.curly_close)

	scope := ScopeData.shared_with_children(children)
	p.scope_collector.set_scope_node(scope)

	body := p.statement(start, StatementKind{
		tag:            .function_body
		scope:          scope
		in_strict_mode: body_is_strict
	})

	return body, has_use_strict, insights
}

// https://tc39.es/ecma262/#sec-function-definitions
fn (mut p Parser) parse_formal_parameters() ParsedParameters {
	p.consume_token(.paren_open)
	result := p.parse_formal_parameters_impl(false)
	p.consume_token(.paren_close)
	return result
}

fn (mut p Parser) parse_formal_parameters_impl(is_arrow bool) ParsedParameters {
	saved_formal_parameter_ctx := p.flags.in_formal_parameter_context
	p.flags.in_formal_parameter_context = true

	saved_pattern_bound_names := p.pattern_bound_names.clone()
	p.pattern_bound_names = []BoundName{}

	if p.match_token(.paren_close) {
		p.flags.in_formal_parameter_context = saved_formal_parameter_ctx
		p.pattern_bound_names = saved_pattern_bound_names
		return ParsedParameters{
			parameters:      []FunctionParameter{}
			function_length: 0
			parameter_info:  []ParamInfo{}
			is_simple:       true
		}
	}

	mut parameters := []FunctionParameter{}
	mut function_length := 0
	mut has_seen_default := false
	mut has_seen_rest := false
	mut parameter_info := []ParamInfo{}

	formal_parameters_start := p.position()

	for {
		rest := p.eat(.triple_dot)
		if rest {
			has_seen_rest = true
		}

		mut binding := FunctionParameterBinding(IdentifierBinding{})
		if p.match_identifier() || p.match_token(.await_kw) || p.match_token(.yield_kw) {
			if p.current_token_type() == .await_kw && (p.program_type == .module
				|| p.flags.await_expression_is_valid
				|| p.flags.in_class_static_init_block) {
				p.syntax_error("'await' is not allowed as an identifier in this context")
			}
			if p.current_token_type() == .yield_kw
				&& (p.flags.strict_mode || p.flags.in_generator_function_context) {
				p.syntax_error("'yield' is not allowed as an identifier in this context")
			}
			token := p.consume()
			value := Utf16String.from_slice(p.token_value(token))
			p.check_identifier_name_for_assignment_validity(value.data, false)

			id := Identifier.new(p.range_from(formal_parameters_start), value.clone())
			parameter_info << ParamInfo{
				name:            value
				is_rest:         rest
				is_from_pattern: false
				identifier:      id
			}
			binding = IdentifierBinding{
				identifier: id
			}
		} else if p.match_token(.curly_open) || p.match_token(.bracket_open) {
			pat := p.parse_binding_pattern()
			for bn in p.pattern_bound_names {
				parameter_info << ParamInfo{
					name:            bn.name.clone()
					is_rest:         rest
					is_from_pattern: true
					identifier:      bn.identifier
				}
			}
			p.pattern_bound_names = []BoundName{}
			binding = BindingPatternBinding{
				pattern: pat
			}
		} else {
			p.expected('parameter name')
			p.consume()
			id := Identifier.new(p.range_from(formal_parameters_start), Utf16String{})
			binding = IdentifierBinding{
				identifier: id
			}
		}

		mut default_value := ?Expression(none)
		if !rest && p.match_token(.equals) {
			p.consume()
			has_seen_default = true
			saved_in_function := p.flags.in_function_context
			p.flags.in_function_context = true
			default_value = p.parse_expression(precedence_assignment, .right,
				ForbiddenTokens.with_in())
			p.flags.in_function_context = saved_in_function
		}

		if !rest && !has_seen_default && default_value == none {
			function_length += 1
		}

		parameters << FunctionParameter{
			binding:       binding
			default_value: default_value
			is_rest:       rest
		}

		if rest || !p.match_token(.comma) {
			break
		}
		p.consume()

		if p.match_token(.paren_close) {
			break
		}
	}

	p.flags.in_formal_parameter_context = saved_formal_parameter_ctx
	p.pattern_bound_names = saved_pattern_bound_names

	has_binding_pattern := parameters.any(fn (fp FunctionParameter) bool {
		return fp.binding is BindingPatternBinding
	})
	is_simple := !has_seen_default && !has_seen_rest && !has_binding_pattern
	if !is_arrow && (p.flags.strict_mode || !is_simple) {
		p.check_unique_formal_parameters(parameter_info)
	}
	return ParsedParameters{
		parameters:      parameters
		function_length: function_length
		parameter_info:  parameter_info
		is_simple:       is_simple
	}
}

// https://tc39.es/ecma262/#sec-destructuring-binding-patterns
fn (mut p Parser) parse_binding_pattern() BindingPattern {
	if !p.enter_recursion() {
		return BindingPattern{
			kind: .object
		}
	}
	defer {
		p.leave_recursion()
	}
	is_object := p.match_token(.curly_open)
	is_array := p.match_token(.bracket_open)
	if !is_object && !is_array {
		return BindingPattern{
			kind: .object
		}
	}
	outer_pattern_start := p.binding_pattern_start
	p.binding_pattern_start = p.position()
	p.consume()

	kind := if is_object { BindingPatternKind.object } else { BindingPatternKind.array }
	closing_token := if is_object { TokenType.curly_close } else { TokenType.bracket_close }
	mut entries := []BindingEntry{}

	for !p.match_token(closing_token) && !p.done() {
		// Array elision: bare comma.
		if !is_object && p.match_token(.comma) {
			p.consume()
			entries << BindingEntry{
				is_rest: false
			}
			continue
		}

		is_rest := p.eat(.triple_dot)

		mut entry_name := BindingEntryName{}
		mut entry_alias := BindingEntryAlias{}

		if is_object {
			if p.allow_member_expressions && is_rest {
				expression := p.parse_expression(precedence_assignment, .right, ForbiddenTokens{}.forbid([
					TokenType.equals,
				]))
				if is_member_expression(expression) {
					entry_alias = BindingEntryAlias{
						kind:       .member_expression_kind
						expression: expression
					}
				} else if is_identifier_expression(expression) {
					mut id := expression_into_identifier(expression)
					entry_name = BindingEntryName{
						kind:       .identifier_kind
						identifier: id
					}
				} else {
					p.syntax_error('Invalid destructuring assignment target')
					break
				}
			} else {
				mut needs_alias := false
				mut entry_name_value := Utf16String{}
				mut entry_is_keyword := false

				if p.match_identifier_name() || p.match_token(.string_literal)
					|| p.match_token(.numeric_literal) || p.match_token(.big_int_literal) {
					entry_start := p.position()

					if p.match_token(.string_literal) || p.match_token(.numeric_literal) {
						needs_alias = true
					}

					entry_is_keyword = p.current_token.token_type.is_identifier_name()
						&& !p.match_identifier()

					if p.match_token(.string_literal) {
						token := p.consume_property_key_token()
						value, _ := p.parse_string_value(token)
						mut id := p.make_identifier(entry_start, value)
						p.scope_collector.register_identifier(id, id.name.data, none)
						entry_name = BindingEntryName{
							kind:       .identifier_kind
							identifier: id
						}
					} else if p.match_token(.big_int_literal) {
						token := p.consume_property_key_token()
						value := p.token_value(token)
						name_value := if value.len > 0 && value[value.len - 1] == ch(`n`) {
							value[..value.len - 1].clone()
						} else {
							value.clone()
						}
						mut id := p.make_identifier(entry_start, Utf16String.from_slice(name_value))
						p.scope_collector.register_identifier(id, id.name.data, none)
						entry_name = BindingEntryName{
							kind:       .identifier_kind
							identifier: id
						}
					} else {
						token := p.consume_property_key_token()
						value := p.token_value(token).clone()
						entry_name_value = Utf16String.from_slice(value.clone())
						mut id := p.make_identifier(entry_start, Utf16String.from_slice(value))
						p.scope_collector.register_identifier(id, id.name.data, none)
						entry_name = BindingEntryName{
							kind:       .identifier_kind
							identifier: id
						}
					}
				} else if p.match_token(.bracket_open) {
					p.consume()
					expression := p.parse_expression_any()
					entry_name = BindingEntryName{
						kind:       .expression_kind
						expression: expression
					}
					p.consume_token(.bracket_close)
				} else {
					p.expected('identifier or computed property name')
					break
				}

				if !is_rest && p.match_token(.colon) {
					p.consume()
					if p.allow_member_expressions {
						expression_start := p.position()
						expression := p.parse_expression(precedence_assignment, .right, ForbiddenTokens{}.forbid([
							TokenType.equals,
						]))
						if is_parenthesized_object_or_array_expression(expression, expression_start) {
							p.syntax_error('Invalid destructuring assignment target')
							break
						} else if is_object_expression(expression)
							|| is_array_expression(expression) {
							if pattern := p.synthesize_binding_pattern(expression.range.start) {
								entry_alias = BindingEntryAlias{
									kind:            .binding_pattern_kind
									binding_pattern: pattern
								}
							}
						} else if is_member_expression(expression) {
							entry_alias = BindingEntryAlias{
								kind:       .member_expression_kind
								expression: expression
							}
						} else if is_identifier_expression(expression) {
							entry_alias = BindingEntryAlias{
								kind:       .identifier_kind
								identifier: expression_into_identifier(expression)
							}
						} else {
							p.syntax_error('Invalid destructuring assignment target')
							break
						}
					} else if p.match_token(.curly_open) || p.match_token(.bracket_open) {
						nested := p.parse_binding_pattern()
						entry_alias = BindingEntryAlias{
							kind:            .binding_pattern_kind
							binding_pattern: nested
						}
					} else if p.match_identifier_name() {
						alias_start := p.position()
						token := p.consume()
						value := p.token_value(token).clone()
						mut id := p.make_identifier(alias_start,
							Utf16String.from_slice(value.clone()))
						p.pattern_bound_names << BoundName{
							name:       Utf16String.from_slice(value)
							identifier: id
						}
						entry_alias = BindingEntryAlias{
							kind:       .identifier_kind
							identifier: id
						}
					} else {
						p.expected('identifier or binding pattern')
						break
					}
				} else if needs_alias {
					p.expected('alias for string or numeric literal name')
					break
				} else if entry_name_value.data.len > 0 {
					// Shorthand: name is the bound identifier.
					if entry_is_keyword {
						p.syntax_error('Binding pattern target may not be a reserved word')
					}
					if entry_name.kind == .identifier_kind {
						if id := entry_name.identifier {
							p.pattern_bound_names << BoundName{
								name:       entry_name_value
								identifier: id
							}
						}
					}
				}
			}
		} else if p.allow_member_expressions {
			expression_start := p.position()
			expression := p.parse_expression(precedence_assignment, .right, ForbiddenTokens{}.forbid([
				TokenType.equals,
			]))
			if is_parenthesized_object_or_array_expression(expression, expression_start) {
				p.syntax_error('Invalid destructuring assignment target')
				break
			} else if is_object_expression(expression) || is_array_expression(expression) {
				if pattern := p.synthesize_binding_pattern(expression.range.start) {
					entry_alias = BindingEntryAlias{
						kind:            .binding_pattern_kind
						binding_pattern: pattern
					}
				}
			} else if is_member_expression(expression) {
				entry_alias = BindingEntryAlias{
					kind:       .member_expression_kind
					expression: expression
				}
			} else if is_identifier_expression(expression) {
				mut id := expression_into_identifier(expression)
				p.pattern_bound_names << BoundName{
					name:       id.name.clone()
					identifier: id
				}
				entry_alias = BindingEntryAlias{
					kind:       .identifier_kind
					identifier: id
				}
			} else {
				p.syntax_error('Invalid destructuring assignment target')
				break
			}
		} else if p.match_token(.curly_open) || p.match_token(.bracket_open) {
			nested := p.parse_binding_pattern()
			entry_alias = BindingEntryAlias{
				kind:            .binding_pattern_kind
				binding_pattern: nested
			}
		} else if p.match_identifier_name() {
			alias_start := p.position()
			token := p.consume()
			value := p.token_value(token).clone()
			mut id := p.make_identifier(alias_start, Utf16String.from_slice(value.clone()))
			p.pattern_bound_names << BoundName{
				name:       Utf16String.from_slice(value)
				identifier: id
			}
			entry_alias = BindingEntryAlias{
				kind:       .identifier_kind
				identifier: id
			}
		} else {
			p.expected('identifier or binding pattern')
			break
		}

		mut initializer := ?Expression(none)
		mut has_initializer := false
		if p.match_token(.equals) {
			if is_rest {
				p.syntax_error('Unexpected initializer after rest element')
			}
			p.consume()
			initializer = p.parse_assignment_expression()
			has_initializer = true
		}

		entries << BindingEntry{
			name:                entry_name
			alias:               entry_alias
			initializer:         initializer
			has_initializer:     has_initializer
			has_name_expression: entry_name.kind == .expression_kind
			is_rest:             is_rest
		}

		if is_rest {
			if p.match_token(.comma) {
				p.syntax_error('Rest element may not be followed by a comma')
				p.consume()
			}
			break
		}

		if p.match_token(.comma) {
			p.consume()
		} else if is_object && !p.match_token(closing_token) {
			p.consume_token(.comma)
		}
	}

	// Consume trailing commas for arrays.
	if !is_object {
		for p.match_token(.comma) {
			p.consume()
		}
	}

	p.consume_token(closing_token)
	p.binding_pattern_start = outer_pattern_start
	return BindingPattern{
		kind:    kind
		entries: entries
	}
}

// https://tc39.es/ecma262/#sec-imports
fn (mut p Parser) parse_import_statement() Statement {
	start := p.position()
	p.consume_token(.import_kw)

	if p.program_type != .module {
		p.syntax_error("Cannot use 'import' outside a module")
	}

	if p.match_token(.string_literal) {
		module_specifier := p.consume_module_specifier()
		attributes := p.parse_with_clause()
		p.consume_or_insert_semicolon()
		return p.statement(start, StatementKind{
			tag:         .import_stmt
			import_data: ImportStatementData{
				module_request: ModuleRequest{
					module_specifier: module_specifier
					attributes:       attributes
				}
				entries:        []ImportEntry{}
			}
		})
	}

	mut entries := []ImportEntry{}
	mut continue_parsing := true

	if p.match_imported_binding() {
		token := p.consume()
		local_name := Utf16String.from_slice(p.token_value(token))
		entries << ImportEntry{
			import_name: Utf16String.from_slice(utf16('default'))
			local_name:  local_name
		}
		if p.match_token(.comma) {
			p.consume()
		} else {
			continue_parsing = false
		}
	}

	if continue_parsing {
		if p.match_token(.asterisk) {
			// NameSpaceImport: * as ImportedBinding
			p.consume()
			if !p.match_as() {
				p.expected("'as'")
			}
			p.consume() // consume 'as'
			if p.match_imported_binding() {
				token := p.consume()
				namespace_name := Utf16String.from_slice(p.token_value(token))
				entries << ImportEntry{
					local_name: namespace_name
				}
			} else {
				p.expected('identifier')
			}
		} else if p.match_token(.curly_open) {
			// NamedImports: { ImportSpecifier, ... }
			p.consume()
			for !p.done() && !p.match_token(.curly_close) {
				if p.match_identifier_name() {
					require_as := !p.match_imported_binding()
					name_pos := p.position()
					token := p.consume()
					name := p.token_value(token).clone()

					if p.match_as() {
						p.consume() // consume 'as'
						alias_token := p.consume_identifier()
						alias := p.token_value(alias_token).clone()
						p.check_identifier_name_for_assignment_validity(alias, false)
						entries << ImportEntry{
							import_name: Utf16String.from_slice(name)
							local_name:  Utf16String.from_slice(alias)
						}
					} else if require_as {
						name_str := string_from_utf16_lossy(name)
						p.syntax_error_at_position("Unexpected reserved word '${name_str}'",
							name_pos)
					} else {
						p.check_identifier_name_for_assignment_validity(name, false)
						name_u := Utf16String.from_slice(name)
						entries << ImportEntry{
							import_name: name_u.clone()
							local_name:  name_u
						}
					}
				} else if p.match_token(.string_literal) {
					token := p.consume()
					name, _ := p.parse_string_value(token)
					if name.data.len > 0 {
						last := name.data[name.data.len - 1]
						if last >= 0xD800 && last <= 0xDBFF {
							p.syntax_error('StringValue ending with unpaired high surrogate')
						}
					}

					if !p.match_as() {
						p.expected("'as'")
					}
					p.consume() // consume 'as'

					alias_token := p.consume_identifier()
					alias := p.token_value(alias_token).clone()
					p.check_identifier_name_for_assignment_validity(alias, false)
					entries << ImportEntry{
						import_name: name
						local_name:  Utf16String.from_slice(alias)
					}
				} else {
					p.expected('identifier')
					break
				}

				if !p.match_token(.comma) {
					break
				}
				p.consume()
			}
			p.consume_token(.curly_close)
		} else {
			p.expected('import clauses')
		}
	}

	if !p.match_from() {
		p.expected("'from'")
	}
	p.consume() // consume 'from'

	module_specifier := p.consume_module_specifier()
	attributes := p.parse_with_clause()
	p.consume_or_insert_semicolon()
	for entry in entries {
		p.scope_collector.add_import_binding(entry.local_name.data, start.line, start.column)
	}

	return p.statement(start, StatementKind{
		tag:         .import_stmt
		import_data: ImportStatementData{
			module_request: ModuleRequest{
				module_specifier: module_specifier
				attributes:       attributes
			}
			entries:        entries
		}
	})
}

// https://tc39.es/ecma262/#sec-exports
fn (mut p Parser) parse_export_statement() Statement {
	start := p.position()
	p.consume_token(.export_kw)

	if p.program_type != .module {
		p.syntax_error("Cannot use 'export' outside a module")
	}

	mut entries := []ExportEntry{}
	mut export_statement := ?&Statement(none)
	mut is_default := false
	mut from_specifier := ?Utf16String(none)

	if p.match_token(.default_kw) {
		is_default = true
		p.consume()

		mut local_name := ?Utf16String(none)

		matches_function := p.match_function_declaration_for_export()

		if matches_function != .no {
			has_default_name := matches_function == .without_name
			mut declaration := p.parse_function_declaration_for_export(has_default_name)
			if !has_default_name {
				if declaration.kind.tag == .function_declaration {
					if fn_name := declaration.kind.func_name {
						local_name = fn_name.name.clone()
					}
				}
			}
			export_statement = &declaration
		} else if p.match_token(.class_kw) {
			next := p.next_token()
			if next.token_type != .curly_open && next.token_type != .extends_kw {
				mut declaration := p.parse_class_declaration()
				if declaration.kind.tag == .class_declaration {
					if cd := declaration.kind.class_data {
						if name_id := cd.name {
							local_name = name_id.name.clone()
						}
					}
				}
				export_statement = &declaration
			} else {
				mut expression := p.parse_assignment_expression()
				expression_range := expression.range
				mut expr_stmt := Statement.new(expression_range, StatementKind{
					tag:        .expression_stmt
					expression: &expression
				})
				export_statement = &expr_stmt
			}
		} else if p.match_expression() {
			mut special_case_declaration_without_name := p.match_token(.class_kw)
				|| p.match_token(.function_kw)
			if !special_case_declaration_without_name && p.match_token(.async) {
				next2 := p.next_token()
				special_case_declaration_without_name = next2.token_type == .function_kw
					&& !next2.trivia_has_line_terminator
			}
			mut expression := p.parse_assignment_expression()
			if !special_case_declaration_without_name {
				p.consume_or_insert_semicolon()
			}
			expression_range := expression.range
			mut expr_stmt := Statement.new(expression_range, StatementKind{
				tag:        .expression_stmt
				expression: &expression
			})
			export_statement = &expr_stmt
		} else {
			p.expected('declaration or assignment expression')
		}

		if local_name == none {
			local_name = Utf16String.from_slice(utf16('*default*'))
		}

		entries << ExportEntry{
			kind:                 .named_export
			export_name:          Utf16String.from_slice(utf16('default'))
			local_or_import_name: local_name
		}
	} else {
		// Non-default export.
		mut check_for_from := FromSpecifier.not_allowed

		if p.match_token(.asterisk) {
			p.consume()
			if p.match_as() {
				p.consume() // consume 'as'
				exported_name, _ := p.parse_module_export_name()
				entries << ExportEntry{
					kind:        .module_request_all
					export_name: exported_name
				}
			} else {
				entries << ExportEntry{
					kind: .module_request_all_but_default
				}
			}
			check_for_from = .required
		} else if p.match_declaration() {
			mut declaration := p.parse_declaration()
			names := get_declaration_export_names(&declaration)
			for name in names {
				entries << ExportEntry{
					kind:                 .named_export
					export_name:          name.clone()
					local_or_import_name: name
				}
			}
			export_statement = &declaration
		} else if p.match_token(.var_kw) {
			mut var_declaration := p.parse_variable_declaration(false)
			names := get_declaration_export_names(&var_declaration)
			for name in names {
				entries << ExportEntry{
					kind:                 .named_export
					export_name:          name.clone()
					local_or_import_name: name
				}
			}
			export_statement = &var_declaration
		} else if p.match_token(.curly_open) {
			p.consume()
			check_for_from = .optional

			for !p.done() && !p.match_token(.curly_close) {
				identifier, was_string := p.parse_module_export_name()
				if was_string {
					check_for_from = .required
				}

				if p.match_as() {
					p.consume() // consume 'as'
					export_name, _ := p.parse_module_export_name()
					entries << ExportEntry{
						kind:                 .named_export
						export_name:          export_name
						local_or_import_name: identifier
					}
				} else {
					entries << ExportEntry{
						kind:                 .named_export
						export_name:          identifier.clone()
						local_or_import_name: identifier
					}
				}

				if !p.match_token(.comma) {
					break
				}
				p.consume()
			}

			if entries.len == 0 {
				entries << ExportEntry{
					kind: .empty_named_export
				}
			}

			p.consume_token(.curly_close)
		} else {
			p.syntax_error("Unexpected token 'export'")
		}

		if check_for_from != .not_allowed && p.match_from() {
			p.consume() // consume 'from'
			from_specifier = p.consume_module_specifier()
		} else if check_for_from == .required {
			p.expected("'from'")
		}

		if from_specifier == none && check_for_from != .not_allowed {
			p.consume_or_insert_semicolon()
		}
	}

	mut module_request := ?ModuleRequest(none)
	if specifier := from_specifier {
		attributes := p.parse_with_clause()
		p.consume_or_insert_semicolon()
		module_request = ModuleRequest{
			module_specifier: specifier
			attributes:       attributes
		}
	}

	// Check for duplicate exported names.
	for entry in entries {
		if en := entry.export_name {
			en_key := en.str()
			if en_key in p.exported_names {
				name_str := string_from_utf16_lossy(en.data)
				p.syntax_error_at_position("Duplicate export with name: '${name_str}'", start)
			}
			p.exported_names[en_key] = true
		}
	}

	return p.statement(start, StatementKind{
		tag:         .export_stmt
		export_data: ExportStatementData{
			statement:         export_statement
			entries:           entries
			is_default_export: is_default
			module_request:    module_request
		}
	})
}

fn (p &Parser) match_imported_binding() bool {
	return p.match_identifier() || p.match_token(.yield_kw) || p.match_token(.await_kw)
}

fn (p &Parser) match_as() bool {
	return p.match_token(.identifier)
		&& utf16_equals(p.token_original_value(p.current_token), utf16('as'))
}

fn (p &Parser) match_from() bool {
	return p.match_token(.identifier)
		&& utf16_equals(p.token_original_value(p.current_token), utf16('from'))
}

fn (mut p Parser) consume_module_specifier() Utf16String {
	if !p.match_token(.string_literal) {
		p.expected('module specifier (string)')
		return Utf16String.from_slice(utf16('!!invalid!!'))
	}
	token := p.consume()
	value, _ := p.parse_string_value(token)
	return value
}

fn (mut p Parser) parse_module_export_name() (Utf16String, bool) {
	if p.match_identifier_name() {
		token := p.consume()
		return Utf16String.from_slice(p.token_value(token)), false
	} else if p.match_token(.string_literal) {
		token := p.consume()
		value, _ := p.parse_string_value(token)
		if value.data.len > 0 {
			last := value.data[value.data.len - 1]
			if last >= 0xD800 && last <= 0xDBFF {
				p.syntax_error('StringValue ending with unpaired high surrogate')
			}
		}
		return value, true
	} else {
		p.expected('export specifier (string or identifier)')
		return Utf16String{}, false
	}
}

// https://tc39.es/ecma262/#sec-imports
fn (mut p Parser) parse_with_clause() []ImportAttribute {
	if !p.match_token(.with_kw) {
		return []ImportAttribute{}
	}
	p.consume()
	p.consume_token(.curly_open)

	mut attributes := []ImportAttribute{}
	for !p.done() && !p.match_token(.curly_close) {
		key := if p.match_token(.string_literal) {
			token := p.consume()
			value, _ := p.parse_string_value(token)
			value
		} else if p.match_identifier_name() {
			token := p.consume()
			Utf16String.from_slice(p.token_value(token))
		} else {
			p.expected('identifier or string as attribute key')
			p.consume()
			continue
		}

		p.consume_token(.colon)

		if p.match_token(.string_literal) {
			token := p.consume()
			value, _ := p.parse_string_value(token)
			for attribute in attributes {
				if attribute.key == key {
					p.syntax_error('Duplicate import attribute key')
					break
				}
			}
			attributes << ImportAttribute{
				key:   key
				value: value
			}
		} else {
			p.expected('string as attribute value')
			p.consume()
		}

		if p.match_token(.comma) {
			p.consume()
		} else {
			break
		}
	}
	p.consume_token(.curly_close)
	return attributes
}

enum MatchesFunctionDeclarationResult {
	no
	yes
	without_name
}

fn (mut p Parser) match_function_declaration_for_export() MatchesFunctionDeclarationResult {
	if p.match_token(.function_kw) {
		next := p.next_token()
		if next.token_type == .asterisk {
			p.save_state()
			p.consume() // function
			p.consume() // *
			result := if p.match_token(.paren_open) {
				MatchesFunctionDeclarationResult.without_name
			} else {
				MatchesFunctionDeclarationResult.yes
			}
			p.load_state()
			return result
		}
		return if next.token_type == .paren_open {
			MatchesFunctionDeclarationResult.without_name
		} else {
			MatchesFunctionDeclarationResult.yes
		}
	}

	if p.match_token(.async) {
		next := p.next_token()
		if next.token_type != .function_kw || next.trivia_has_line_terminator {
			return .no
		}
		p.save_state()
		p.consume() // async
		p.consume() // function
		if p.match_token(.asterisk) {
			p.consume() // *
		}
		result := if p.match_token(.paren_open) {
			MatchesFunctionDeclarationResult.without_name
		} else {
			MatchesFunctionDeclarationResult.yes
		}
		p.load_state()
		return result
	}

	return .no
}

fn (mut p Parser) parse_function_declaration_for_export(has_default_name bool) Statement {
	if has_default_name {
		p.has_default_export_name = true
		result := p.parse_function_declaration()
		p.has_default_export_name = false
		return result
	} else {
		return p.parse_function_declaration()
	}
}

enum FromSpecifier {
	not_allowed
	optional
	required
}
