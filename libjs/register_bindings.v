module libjs

// Parser scope analysis marks uncaptured bindings that cannot be observed by
// eval or with. Keep lexical/TDZ bindings and complex parameter lists on their
// existing environment paths. Local reads still copy into a temporary so later
// argument/RHS evaluation cannot change an earlier read.
struct FunctionRegisterBinding {
	name            Utf16String
	slot            u32
	local_type      int
	local_index     u32
	parameter_index int = -1
}

$if test {
	__global register_bindings_disabled_for_test bool
	pub fn set_register_bindings_for_testing(enabled bool) {
		register_bindings_disabled_for_test = !enabled
	}
}

fn (mut function ECMAScriptFunction) prepare_register_bindings(mut generator BytecodeGenerator) {
	function.register_bindings = []FunctionRegisterBinding{}
	$if test {
		if register_bindings_disabled_for_test { return }
	}
	if function.source.parsed_source == unsafe { nil } || !function.data.simple_parameters()
		|| function.data.kind != .normal || function.data.is_arrow_function {
		return
	}
	scope := function.data.body.kind.scope or { return }
	if !function.arguments_are_unobservable(scope) { return }
	data := scope.function_scope_data or { return }
	if data.functions_to_initialize.len > 0 || scope.annexb_function_names.len > 0 { return }
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
		function.register_bindings << FunctionRegisterBinding{
			name:        variable.name
			slot:        u32(function.register_bindings.len)
			local_type:  2
			local_index: u32(index)
		}
	}
	if function.register_bindings.len == 0 { return }
	generator.register_bindings = function.register_bindings
	generator.executable.local_index_base = reserved_register_count
	for binding in function.register_bindings {
		generator.executable.local_variable_names << binding.name
	}
	generator.executable.registers_and_locals_count += u32(function.register_bindings.len)
}

fn (function &ECMAScriptFunction) parameter_in_register(index int) bool {
	return function.register_bindings.any(it.parameter_index == index)
}

fn (function &ECMAScriptFunction) variable_in_register(name Utf16String) bool {
	return function.register_bindings.any(it.name == name)
}

fn (generator &BytecodeGenerator) variable_register(name Utf16String) ?Operand {
	for binding in generator.register_bindings {
		if binding.name == name { return Operand.local(binding.slot) }
	}
	return none
}

fn (generator &BytecodeGenerator) identifier_register(identifier &Identifier) ?Operand {
	if identifier.is_inside_scope_with_eval { return none }
	for binding in generator.register_bindings {
		if identifier.local_type == binding.local_type && identifier.local_index == binding.local_index
			&& identifier.name == binding.name {
			return Operand.local(binding.slot)
		}
	}
	return none
}

fn (generator &BytecodeGenerator) expression_register(expression &Expression) ?Operand {
	if expression.kind.tag != .identifier_expr { return none }
	return generator.identifier_register(expression.kind.identifier or { return none })
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
	if local := generator.expression_register(expression) {
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
