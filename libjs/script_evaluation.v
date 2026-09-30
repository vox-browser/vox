module libjs

// Script.cpp::global_declaration_instantiation, for the declarations supported
// by the compiler. All conflicts are checked before any global binding is made.
pub fn (script &Script) global_declaration_instantiation(mut vm VM, executable &Executable) ! {
	mut environment := script.realm.global_environment_record()
	for binding in executable.global_bindings {
		if environment.has_lexical_declaration(binding.name) {
			return vm.throw_error_type(.syntax_error, .top_level_variable_already_declared,
				binding.name.str())
		}
		if binding.is_lexical {
			if environment.has_restricted_global_property(binding.name) {
				return vm.throw_error_type(.syntax_error, .restricted_global_property,
					binding.name.str())
			}
		} else if !environment.can_declare_global_var(binding.name) {
			return vm.throw_error_type(.type_error, .cannot_declare_global_variable,
				binding.name.str())
		}
	}
	for binding in executable.global_bindings {
		if binding.is_lexical {
			if binding.is_constant {
				environment.create_immutable_binding(mut vm, binding.name, true)!
			} else {
				environment.create_mutable_binding(mut vm, binding.name, false)!
			}
		}
	}
	for binding in executable.global_bindings {
		if !binding.is_lexical {
			environment.create_global_var_binding(mut vm, binding.name, false)!
		}
	}
}

// Interpreter.cpp::VM::run / ScriptEvaluation. Compilation precedes instantiation
// here so unsupported programs cannot partially mutate the global environment.
pub fn (mut vm VM) run(mut script Script) !Value {
	return vm.run_with_limits(mut script, ExecutionLimits{})
}

pub fn (mut vm VM) run_with_limits(mut script Script, limits ExecutionLimits) !Value {
	executable := script.compile(mut vm)!
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut context := stack.allocate(executable.registers_and_locals_count, executable.constants, 0) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	context.realm = script.realm
	context.executable = executable
	context.script_or_module = ScriptOrModule.from_script(&script)
	context.lexical_environment = Environment(script.realm.global_environment_record())
	context.variable_environment = context.lexical_environment
	vm.push_execution_context_checked(mut context)!
	defer {
		vm.pop_execution_context()
		vm.finish_execution_generation()
	}
	script.global_declaration_instantiation(mut vm, executable)!
	value := vm.run_executable(mut context, executable, 0, limits)!
	return if value.is_special_empty_value() { js_undefined() } else { value }
}
