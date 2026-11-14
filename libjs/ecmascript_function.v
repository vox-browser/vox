module libjs

// Runtime/ECMAScriptFunctionObject.cpp: ordinary calls retain their defining
// environment and allocate an independent interpreter frame. Executables use
// this port's instruction-index ABI rather than upstream inline frames.
@[heap]
struct ECMAScriptFunction {
	object &Object
	realm_ &Realm
	data &JsFunctionData
	source &Executable
	environment ?Environment
	private_environment ?&PrivateEnvironment
	script_or_module ScriptOrModule
	inferred_name ?Utf16String
mut:
	executable ?&Executable
}

fn create_ecmascript_function(mut vm VM, source &Executable, index u32, named_expression bool, inferred_name ?Utf16String) !&Object {
	data := source.parsed_source.function_table.get(FunctionId{id: index})
	if data.kind != .normal { return error('LibJS async and generator functions are not translated yet') }
	realm := vm.realm()
	mut object := Object.create(realm, realm.function_prototype)
	object.class_name = 'Function'
	mut environment := vm.running_execution_context().lexical_environment
	// Named function expressions have a private immutable self binding.
	mut named := ?&DeclarativeEnvironment(none)
	if named_expression {
		name := data.name or { return error('Missing named expression') }
		mut scope := DeclarativeEnvironment.create(environment)
		scope.create_immutable_binding(mut vm, name.name, false)!
		environment = Environment(scope)
		named = scope
	}
	function := &ECMAScriptFunction{
		object: object
		realm_: realm
		data: data
		source: source
		environment: environment
		private_environment: vm.running_execution_context().private_environment
		script_or_module: vm.running_execution_context().script_or_module
		inferred_name: inferred_name
	}
	object.callable = FunctionObject(function)
	if !data.is_arrow_function { object.constructor = ConstructorFunction(function) }
	object.set_function_length(f64(data.function_length))
	object.set_function_name(mut vm, PropertyName.from_utf16(function.name_for_call_stack()), none)
	units := utf16(source.parsed_source.source_text)
	object.function_source_text = utf16_string_from_code_units(units[int(data.source_text_start)..int(data.source_text_end)])
	if scope := named {
		mut binding := scope
		binding.initialize_binding(mut vm, data.name or { panic('missing function name') }.name, Value.from_object(object), .normal)!
	}
	if !data.is_arrow_function {
		mut prototype := Object.create(realm, realm.object_prototype)
		prototype.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(object), attribute_writable | attribute_configurable)
		object.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype), attribute_writable)
	}
	return object
}

fn (function &ECMAScriptFunction) name_for_call_stack() Utf16String {
	if name := function.data.name {
		return if name.name.str() == '*default*' { utf16_string('default') } else { name.name }
	}
	return function.inferred_name or { Utf16String.new() }
}

fn (function &ECMAScriptFunction) realm() ?&Realm { return function.realm_ }

fn (mut function ECMAScriptFunction) compile(mut vm VM) !&Executable {
	if executable := function.executable { return executable }
	mut generator := BytecodeGenerator{
		executable: &Executable{
			name: function.name_for_call_stack()
			registers_and_locals_count: reserved_register_count
			source_code: function.source.source_code
			parsed_source: function.source.parsed_source
			starting_line: function.source.starting_line
		}
		strict: function.data.is_strict_mode
		starting_line: function.source.starting_line
		range: function.data.body.range
		function_body: true
	}
	for parameter in function.data.parameters {
		if parameter.binding !is IdentifierBinding || parameter.default_value != none || parameter.is_rest {
			return generator.unsupported('non-simple function parameters')
		}
	}
	generator.collect_vars(&function.data.body)!
	scope := function.data.body.kind.scope or { return error('Missing function body') }
	generator.lexical_declarations(scope.children, false)!
	generator.initialize_functions(scope.children)
	for statement in scope.children { generator.statement(mut vm, &statement)! }
	generator.emit(Instruction{op: .end, lhs: generator.constant(js_undefined())})
	generator.executable.bytecode_length = u32(generator.executable.instructions.len)
	generator.executable.validate(0)!
	function.executable = generator.executable
	return generator.executable
}

fn (mut function ECMAScriptFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	executable := function.compile(mut vm)!
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut frame := stack.allocate(executable.registers_and_locals_count, executable.constants, u32(arguments.len)) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	mut environment := FunctionEnvironment.create(function.environment)
	environment.set_function_object(FunctionObject(&function))
	frame.function = FunctionObject(&function)
	frame.realm = function.realm_
	frame.script_or_module = function.script_or_module
	frame.private_environment = function.private_environment
	frame.lexical_environment = Environment(environment)
	frame.variable_environment = Environment(environment)
	frame.passed_argument_count = u32(arguments.len)
	for index, argument in arguments { frame.set_argument(u32(index), argument) }
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	if function.data.is_arrow_function {
		environment.set_this_binding_status(.lexical)
	} else {
		bound_this := if function.data.is_strict_mode || this_value.is_object() {
			this_value
		} else if this_value.is_nullish() {
			Value.from_object(function.realm_.global_environment_record().global_this_value)
		} else {
			Value.from_object(this_value.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!)
		}
		environment.bind_this_value(mut vm, bound_this)!
		frame.this_value = bound_this
	}
	for index, parameter in function.data.parameters {
		binding := parameter.binding as IdentifierBinding
		name := binding.identifier.name
		value := if index < arguments.len { arguments[index] } else { js_undefined() }
		if !environment.has_binding_named(name) { environment.create_mutable_binding(mut vm, name, false)!
			environment.initialize_binding(mut vm, name, value, .normal)!
		} else { environment.set_mutable_binding(mut vm, name, value, false)! }
	}
	for binding in executable.global_bindings {
		if !environment.has_binding_named(binding.name) {
			environment.create_mutable_binding(mut vm, binding.name, false)!
			environment.initialize_binding(mut vm, binding.name, js_undefined(), .normal)!
		}
	}
	return vm.run_executable(mut frame, executable, 0, ExecutionLimits{})
}

fn (mut function ECMAScriptFunction) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	prototype := new_target.get(mut vm, PropertyName.from_str('prototype'))!
	object := Object.create(function.realm_, if prototype.is_object() { prototype.as_object() } else { function.realm_.object_prototype_record() })
	value := function.internal_call(mut vm, Value.from_object(object), arguments)!
	return if value.is_object() { value.as_object() } else { object }
}
