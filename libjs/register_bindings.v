module libjs

// Parser scope analysis marks uncaptured bindings that cannot be observed by
// eval or with. Complex parameter lists stay on their existing environment
// path; lexical_registers.v describes the let/const bindings. local_operands.v
// reads a local in place unless later argument/RHS evaluation might assign it.
struct FunctionRegisterBinding {
	name            Utf16String
	slot            u32
	local_type      int
	local_index     u32
	parameter_index int = -1
	lexical         bool
	constant        bool
}

$if test {
	__global register_bindings_disabled_for_test bool
	__global register_bindings_legacy_scope_for_test bool
	pub fn set_register_bindings_for_testing(enabled bool) {
		register_bindings_disabled_for_test = !enabled
	}
	// Restore the earlier scope (no arrows, no nested declarations) for A/B checks.
	pub fn set_register_bindings_legacy_scope_for_testing(enabled bool) {
		register_bindings_legacy_scope_for_test = enabled
	}
	fn has_hoisted_function_names(function &ECMAScriptFunction) bool {
		scope := function.data.body.kind.scope or { return false }
		data := scope.function_scope_data or { return false }
		return data.functions_to_initialize.len > 0 || scope.annexb_function_names.len > 0
	}
}

fn (mut function ECMAScriptFunction) prepare_register_bindings(mut generator BytecodeGenerator, exclusions LexicalRegisterExclusions) {
	function.register_bindings = []FunctionRegisterBinding{}
	$if test {
		if register_bindings_disabled_for_test { return }
	}
	// An async function's await copies its whole initialized frame, local slots
	// included. A generator's first suspension precedes frame initialization,
	// whose copy drops local slots, so generators keep environment bindings.
	if function.source.parsed_source == unsafe { nil } || function.data.kind !in [.normal, .async_kind] {
		return
	}
	$if test {
		if register_bindings_legacy_scope_for_test && (function.data.is_arrow_function
			|| has_hoisted_function_names(function)) {
			return
		}
	}
	scope := function.data.body.kind.scope or { return }
	// Complex parameter lists and observable arguments keep parameters and vars
	// in the environment; the body's own let/const bindings can still be slots.
	if function.data.simple_parameters() && function.arguments_are_unobservable(scope) {
		function.prepare_parameter_and_var_registers(scope)
	}
	generator.register_bindings = function.register_bindings.clone()
	generator.add_lexical_registers(&function.data.body, scope, exclusions)
	if generator.register_bindings.len == 0 { return }
	generator.lexical_initialized = []bool{len: generator.register_bindings.len}
	generator.variable_positions = []int{len: scope.local_variables.len, init: -1}
	for position, binding in generator.register_bindings {
		if binding.local_type == 2 && binding.local_index < u32(scope.local_variables.len) {
			generator.variable_positions[binding.local_index] = position
		}
	}
	generator.executable.local_index_base = reserved_register_count
	for binding in generator.register_bindings {
		generator.executable.local_variable_names << binding.name
	}
	generator.executable.registers_and_locals_count += u32(generator.register_bindings.len)
}

fn (mut function ECMAScriptFunction) prepare_parameter_and_var_registers(scope &ScopeData) {
	data := scope.function_scope_data or { return }
	// Arrow functions and functions with nested declarations keep their
	// uncaptured parameters and vars in registers, as upstream LibJS does. A
	// hoisted function declaration (or Annex B block function) shares its name's
	// environment binding, so that name stays in the environment.
	mut hoisted := []Utf16String{}
	for function_to_initialize in data.functions_to_initialize {
		if function_to_initialize.child_index < 0 || function_to_initialize.child_index >= scope.children.len { return }
		declaration := scope.children[function_to_initialize.child_index]
		name := declaration.kind.func_name or { return }
		hoisted << name.name
	}
	for name in scope.annexb_function_names { hoisted << name }
	// Duplicate parameter names share a binding; leave their ordered overwrite
	// semantics in the environment path.
	mut names := []Utf16String{}
	for parameter in function.data.parameters {
		if parameter.binding is IdentifierBinding {
			name := parameter.binding.identifier.name
			if names.any(it == name) { return }
			names << name
		} else {
			return
		}
	}
	for index, parameter in function.data.parameters {
		if parameter.binding is IdentifierBinding {
			identifier := parameter.binding.identifier
			if identifier.local_type != 1 || identifier.is_inside_scope_with_eval { continue }
			if hoisted.any(it == identifier.name) { continue }
			function.register_bindings << FunctionRegisterBinding{
				name:            identifier.name
				slot:            u32(function.register_bindings.len)
				local_type:      1
				local_index:     identifier.local_index
				parameter_index: index
			}
		}
	}
	for index, variable in scope.local_variables {
		if variable.kind != .var_kind { continue }
		// A var initialization must name a function-scope declaration, rather
		// than a nested lexical/catch binding with the same spelling.
		if !data.vars_to_initialize.any(it.name == variable.name && !it.is_function_name) {
			continue
		}
		if hoisted.any(it == variable.name) { continue }
		function.register_bindings << FunctionRegisterBinding{
			name:        variable.name
			slot:        u32(function.register_bindings.len)
			local_type:  2
			local_index: u32(index)
		}
	}
}

fn (function &ECMAScriptFunction) parameter_in_register(index int) bool {
	return function.register_bindings.any(it.parameter_index == index)
}

fn (function &ECMAScriptFunction) variable_in_register(name Utf16String) bool {
	if use_register_call_metadata() {
		if found := function.indexed_register_name(name) { return found }
	}
	return function.register_bindings.any(it.name == name)
}

fn (generator &BytecodeGenerator) variable_register(name Utf16String) ?Operand {
	for binding in generator.register_bindings {
		if binding.name == name && !binding.lexical { return Operand.local(binding.slot) }
	}
	return none
}

fn (mut generator BytecodeGenerator) identifier_register(identifier &Identifier) ?Operand {
	return generator.identifier_register_access(identifier, false)
}

// A lexical register read or written before its initialization, or a const
// assignment, rejects the binding; compile() then compiles the function again.
fn (mut generator BytecodeGenerator) identifier_register_access(identifier &Identifier, write bool) ?Operand {
	position := generator.identifier_register_position(identifier) or { return none }
	binding := generator.register_bindings[position]
	if binding.lexical && (!generator.lexical_initialized[position] || (write && binding.constant))
		&& binding.local_index !in generator.rejected_lexicals {
		generator.rejected_lexicals << binding.local_index
	}
	return Operand.local(binding.slot)
}

fn (generator &BytecodeGenerator) identifier_register_position(identifier &Identifier) ?int {
	if identifier.is_inside_scope_with_eval { return none }
	if identifier.local_type == 2 {
		if identifier.local_index >= u32(generator.variable_positions.len) { return none }
		position := generator.variable_positions[identifier.local_index]
		if position < 0 || generator.register_bindings[position].name != identifier.name { return none }
		return position
	}
	for position, binding in generator.register_bindings {
		if identifier.local_type == binding.local_type && identifier.local_index == binding.local_index
			&& identifier.name == binding.name {
			return position
		}
	}
	return none
}

fn (mut generator BytecodeGenerator) expression_register(expression &Expression) ?Operand {
	if expression.kind.tag != .identifier_expr { return none }
	return generator.identifier_register(expression.kind.identifier or { return none })
}

fn (mut generator BytecodeGenerator) assignment_register(expression &Expression) ?Operand {
	if expression.kind.tag != .identifier_expr { return none }
	return generator.identifier_register_access(expression.kind.identifier or { return none }, true)
}

fn (mut generator BytecodeGenerator) load_identifier(expression &Expression, dst Operand) ! {
	if local := generator.expression_register(expression) {
		generator.emit(Instruction{ op: .mov, dst: dst, lhs: local })
	} else {
		generator.emit(Instruction{
			op:         .get_binding
			dst:        dst
			identifier: generator.identifier(identifier_name(expression)!)
			strict:     generator.strict
		})
	}
}

fn (mut generator BytecodeGenerator) store_identifier(expression &Expression, value Operand) ! {
	if local := generator.assignment_register(expression) {
		generator.emit(Instruction{ op: .mov, dst: local, lhs: value })
	} else {
		generator.emit(Instruction{
			op:         .set_binding
			lhs:        value
			identifier: generator.identifier(identifier_name(expression)!)
			strict:     generator.strict
		})
	}
}
