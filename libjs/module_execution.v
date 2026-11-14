// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ModuleEnvironment.cpp: modules own a declarative environment whose
// this binding is undefined, including calls nested inside module functions.
@[heap]
pub struct ModuleEnvironment {
	DeclarativeEnvironment
mut:
	imports []ModuleImportBinding
}

fn ModuleEnvironment.create(realm &Realm) &ModuleEnvironment {
	return &ModuleEnvironment{DeclarativeEnvironment: DeclarativeEnvironment{
		kind: .module
		outer: Environment(realm.global_environment_record())
		declarative: true
	}}
}

pub fn (environment &ModuleEnvironment) has_this_binding() bool { return true }
pub fn (environment &ModuleEnvironment) get_this_binding(mut vm VM) !Value { return js_undefined() }

enum ModuleExecutionStatus { unlinked linking linked evaluating evaluated }

fn (mut module_record SourceTextModule) compile_module(mut vm VM) !&Executable {
	if executable := module_record.module_executable { return executable }
	if module_record.module_starting_line == 0 { return error('Module starting line must be positive') }
	if module_record.has_top_level_await() {
		return vm.throw_error(.internal_error, 'LibJS top-level await execution is not translated yet')
	}
	program := module_record.parsed.program.kind.program_data or { return error('Missing module program') }
	mut body := []Statement{}
	mut default_expression := ?&Statement(none)
	for statement in program.scope.children {
		if statement.kind.tag == .import_stmt { continue }
		if statement.kind.tag != .export_stmt { body << statement; continue }
		export := statement.kind.export_data or { return error('Missing export declaration') }
		if child := export.statement {
			if export.is_default_export && child.kind.tag == .expression_stmt {
				default_expression = child
				// Retain its original position among other author statements.
				body << statement
			} else { body << *child }
		}
	}
	mut generator := BytecodeGenerator{
		executable: &Executable{
			name: utf16_string(module_record.module_filename)
			registers_and_locals_count: reserved_register_count
			source_code: SourceCode.create(utf16_string(module_record.module_filename), utf16_string(module_record.parsed.source_text))
			parsed_source: module_record.parsed
			starting_line: module_record.module_starting_line
		}
		strict: true
		starting_line: module_record.module_starting_line
		range: module_record.parsed.program.range
	}
	for statement in body { generator.collect_vars(&statement)! }
	generator.lexical_declarations(body, true)!
	if default_expression != none {
		generator.executable.global_bindings << GlobalBinding{name:utf16_string('*default*'),is_lexical:true,is_constant:true}
	}
	// SourceTextModule::InitializeEnvironment creates functions during linking,
	// before ExecuteModule runs any author statements.
	generator.initialize_functions(body)
	generator.emit(Instruction{op:.end, lhs:generator.constant(js_undefined())})
	module_record.module_body_start = u32(generator.executable.instructions.len)
	generator.clear_completion()
	for statement in body {
		if statement.kind.tag == .export_stmt {
			child := default_expression or { return error('Missing default export expression') }
			generator.range = child.range
			expression := child.kind.expression or { return error('Missing default expression') }
			value := if expression.kind.tag == .function_expr && module_record.parsed.function_table.get(expression.kind.function_id).name == none {
				dst := generator.temporary()
				generator.emit(Instruction{op:.new_function_with_name,dst:dst,identifier:expression.kind.function_id.id,lhs:generator.constant(Value.from_string(vm.create_string_from_str('default')))})
				dst
			} else { generator.expression(mut vm, expression)! }
			generator.emit(Instruction{op:.initialize_binding, lhs:value, identifier:generator.identifier(utf16_string('*default*')),strict:true})
		} else { generator.statement(mut vm, &statement)! }
	}
	generator.emit(Instruction{op:.end,lhs:generator.constant(js_undefined())})
	generator.executable.bytecode_length = u32(generator.executable.instructions.len)
	generator.executable.validate(0)!
	module_record.module_executable = generator.executable
	return generator.executable
}

fn (mut module_record SourceTextModule) run_module_frame(mut vm VM, executable &Executable, start u32, limits ExecutionLimits) ! {
	environment := module_record.module_environment or { return error('Module has no environment') }
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut context := stack.allocate(executable.registers_and_locals_count, executable.constants, 0) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	context.realm = module_record.module_realm
	context.executable = executable
	context.script_or_module = ScriptOrModule.from_module(Module(&module_record))
	context.lexical_environment = Environment(environment)
	context.variable_environment = context.lexical_environment
	vm.push_execution_context_checked(mut context)!
	defer { vm.pop_execution_context(); vm.finish_execution_generation() }
	vm.run_executable(mut context, executable, start, limits)!
}

fn (mut module_record SourceTextModule) initialize_module_environment(mut vm VM, executable &Executable) ! {
	mut environment := ModuleEnvironment.create(module_record.module_realm)
	for binding in executable.global_bindings {
		if binding.is_constant { environment.create_immutable_binding(mut vm, binding.name, true)! }
		else { environment.create_mutable_binding(mut vm, binding.name, false)! }
		if !binding.is_lexical { environment.initialize_binding(mut vm, binding.name, js_undefined(), .normal)! }
	}
	module_record.module_environment = environment
	module_record.initialize_module_imports(mut vm, mut environment)!
	module_record.run_module_frame(mut vm, executable, 0, ExecutionLimits{max_instructions:1000000}) or {
		module_record.module_environment = none
		return err
	}
}

pub fn (mut module_record SourceTextModule) evaluate(mut vm VM) !&PromiseCapability {
	return module_record.evaluate_with_limits(mut vm, ExecutionLimits{max_instructions:1000000})
}

pub fn (mut module_record SourceTextModule) evaluate_with_limits(mut vm VM, limits ExecutionLimits) !&PromiseCapability {
	return module_record.evaluate_module_graph(mut vm,limits)
}

// Read an explicit local export; export_value also follows imported aliases,
// re-exports and namespace exports without materializing binding snapshots.
pub fn (module_record &SourceTextModule) local_export_value(mut vm VM, name string) !Value {
	mut environment := module_record.module_environment or { return vm.throw_error(.reference_error, 'Module has no environment') }
	program := module_record.parsed.program.kind.program_data or { return error('Missing module program') }
	for statement in program.scope.children {
		if statement.kind.tag != .export_stmt { continue }
		export := statement.kind.export_data or { continue }
		if export.module_request != none { continue }
		for entry in export.entries {
			if (entry.export_name or { continue }).str() == name {
				return environment.get_binding_value(mut vm, entry.local_or_import_name or { continue }, true)
			}
		}
	}
	return vm.throw_error(.syntax_error, 'Module has no local export named ${name}')
}
