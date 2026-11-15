// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ClassDefinitionEvaluation creates one lexical private-name identity per
// evaluation. Methods and initializer closures capture that environment.
fn enter_class_private_environment(mut vm VM, executable &Executable, instruction Instruction) ! {
	mut frame := vm.running_execution_context()
	mut lexical := frame.lexical_environment or { return error('Class has no lexical scope') }
	if mut lexical is DeclarativeEnvironment {
		if lexical.restores_private_environment { return error('Class scope already has a private environment') }
		mut environment := PrivateEnvironment.create(mut vm, frame.private_environment)
		for operand in instruction.arguments {
			value := frame.values[operand.slot(executable, frame.argument_count, false)!]
			if !value.is_string() { return error('Private name must be a string') }
			environment.add_private_name(value.as_string().utf16)
		}
		lexical.restores_private_environment = true
		lexical.outer_private_environment = frame.private_environment
		frame.private_environment = environment
		return
	}
	return error('Class requires a declarative lexical scope')
}

fn resolve_class_private_name(mut vm VM, value Value) !PrivateName {
	if value.is_string() {
		if environment := vm.running_execution_context().private_environment {
			if environment.contains_private_identifier(value.as_string().utf16) {
				return environment.resolve_private_identifier(value.as_string().utf16)
			}
		}
	}
	return vm.throw_error(.reference_error, 'Private identifier has no matching environment')
}

fn record_private_class_method(mut vm VM, target Value, name Value, method Value, kind u32, is_static bool) ! {
	key := resolve_class_private_name(mut vm, name)!
	mut function := target.as_function()
	if mut function is BaseClassFunction {
		mut elements := if is_static { function.static_private_methods } else { function.instance_private_methods }
		if kind == 0 {
			elements << PrivateElement{key: key, kind: .method, value: method}
		} else {
			mut accessor := &Accessor(unsafe { nil })
			for element in elements {
				if element.key == key && element.kind == .accessor { accessor = element.value.as_accessor() }
			}
			if accessor == unsafe { nil } {
				accessor = Accessor.create(none, none, none)
				elements << PrivateElement{key: key, kind: .accessor, value: Value.from_accessor(accessor)}
			}
			if kind == 1 { accessor.set_getter(method.as_object()) } else { accessor.set_setter(method.as_object()) }
		}
		if is_static { function.static_private_methods = elements } else { function.instance_private_methods = elements }
		return
	}
	return vm.throw_error(.internal_error, 'Private method definition requires a class')
}

fn initialize_class_private_methods(mut vm VM, mut object Object, elements []PrivateElement) ! {
	for element in elements {
		vm.consume_execution_budget()!
		object.private_method_or_accessor_add(mut vm, element)!
	}
}

fn member_property_opcode(expression &Expression, ordinary OpCode) OpCode {
	if property := expression.kind.property {
		if property.kind.tag == .private_identifier_expr {
			return if ordinary == .put_property { OpCode.put_private } else { OpCode.get_private }
		}
	}
	return ordinary
}
