// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ECMAScriptFunctionObject.cpp::FunctionDeclarationInstantiation and the
// upstream bytecode parameter initialization. Non-simple lists initialize in
// order with all names initially in the TDZ. A separate body environment keeps
// body var/functions invisible to closures created by parameter expressions.
fn (data &JsFunctionData) simple_parameters() bool {
	for parameter in data.parameters {
		if parameter.binding !is IdentifierBinding || parameter.default_value != none || parameter.is_rest { return false }
	}
	return true
}

fn parameter_bound_names(parameter FunctionParameter) []Utf16String {
	if parameter.binding is IdentifierBinding { return [parameter.binding.identifier.name] }
	mut names := []Utf16String{}
	collect_pattern_names((parameter.binding as BindingPatternBinding).pattern, mut names)
	return names
}

fn (mut generator BytecodeGenerator) initialize_function_parameters(mut vm VM, data &JsFunctionData) ! {
	for index, parameter in data.parameters {
		value := generator.temporary()
		generator.emit(Instruction{op: if parameter.is_rest { OpCode.get_rest_arguments } else { OpCode.get_argument }, dst: value, identifier: u32(index)})
		if initializer := parameter.default_value {
			missing := generator.temporary()
			generator.emit(Instruction{op: .strict_equals, dst: missing, lhs: value, rhs: generator.constant(js_undefined())})
			skip := generator.emit(Instruction{op: .jump_if_false, lhs: missing})
			mut initial := Operand{}
			if initializer.kind.tag == .function_expr && parameter.binding is IdentifierBinding
				&& generator.executable.parsed_source.function_table.get(initializer.kind.function_id).name == none {
				name := parameter.binding.identifier.name
				initial = generator.temporary()
				generator.emit(Instruction{op: .new_function_with_name, dst: initial, identifier: initializer.kind.function_id.id, lhs: generator.constant(Value.from_string(vm.create_string(name)))})
			} else { initial = generator.expression(mut vm, &initializer)! }
			generator.emit(Instruction{op: .mov, dst: value, lhs: initial})
			generator.patch(skip)
		}
		if parameter.binding is IdentifierBinding {
			generator.store_declared_binding(parameter.binding.identifier.name, value, true)
		} else {
			generator.binding_pattern(mut vm, (parameter.binding as BindingPatternBinding).pattern, value, true)!
		}
	}
	generator.emit(Instruction{op: .enter_function_body})
}

fn enter_function_body(mut vm VM, mut frame ExecutionContext, executable &Executable) ! {
	mut parameters := frame.lexical_environment or { return error('Missing parameter environment') }
	mut body := DeclarativeEnvironment.create(parameters)
	for binding in executable.global_bindings {
		mut value := js_undefined()
		has, _ := parameters.has_binding(mut vm, binding.name)!
		if has { value = parameters.get_binding_value(mut vm, binding.name, false)! }
		body.create_mutable_binding(mut vm, binding.name, false)!
		body.initialize_binding(mut vm, binding.name, value, .normal)!
	}
	frame.lexical_environment = Environment(body)
	frame.variable_environment = Environment(body)
}
