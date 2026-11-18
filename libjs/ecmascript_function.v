module libjs

const function_prototype_key = PropertyName.from_str('prototype')
const function_constructor_key = PropertyName.from_str('constructor')
const default_export_identifier = utf16_string('*default*')
const default_export_name = utf16_string('default')

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
	register_bindings []FunctionRegisterBinding
	executable ?&Executable
	field_initializer_name ?PropertyName
}

fn create_ecmascript_function(mut vm VM, source &Executable, index u32, named_expression bool, inferred_name ?Utf16String, ordinary bool) !&Object {
	data := source.parsed_source.function_table.get(FunctionId{id: index})
	return create_ecmascript_function_data(mut vm, source, data, named_expression, inferred_name, ordinary)
}

fn create_ecmascript_function_data(mut vm VM, source &Executable, data &JsFunctionData, named_expression bool, inferred_name ?Utf16String, ordinary bool) !&Object {
	return create_ecmascript_function_in_environment(mut vm, source, data, named_expression, inferred_name, ordinary,
		vm.current_context().lexical_environment, vm.current_context().private_environment, vm.current_context().script_or_module)
}

fn create_ecmascript_function_in_environment(mut vm VM, source &Executable, data &JsFunctionData, named_expression bool, inferred_name ?Utf16String, ordinary bool,
	defining_environment ?Environment, private_environment ?&PrivateEnvironment, script_or_module ScriptOrModule) !&Object {
	vm.expose_current_call_environment()
	realm := vm.realm()
	function_prototype := match data.kind {
		.normal { realm.function_prototype }
		.async_kind { realm.async_function_prototype }
		.generator { realm.generator_function_prototype }
		.async_generator { realm.async_generator_function_prototype }
	}
	mut object := Object.create(realm, function_prototype)
	object.class_name = 'Function'
	mut environment := defining_environment
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
		private_environment: private_environment
		script_or_module: script_or_module
		inferred_name: inferred_name
	}
	object.callable = FunctionObject(function)
	if ordinary && !data.is_arrow_function && data.kind == .normal { object.constructor = ConstructorFunction(function) }
	object.set_function_length(f64(data.function_length))
	object.set_function_name_text(mut vm, function.name_for_call_stack())
	code := source.source_code or { return error('Function executable is missing its source code') }
	units := code.code.as_slice()
	if data.source_text_start > data.source_text_end || data.source_text_end > u32(units.len) {
		return error('Function source range is out of bounds')
	}
	// The callable retains the immutable SourceCode through its executable.
	// Function.prototype.toString creates an owned primitive from this view.
	object.function_source_text = Utf16String{data: units[int(data.source_text_start)..int(data.source_text_end)]}
	if scope := named {
		mut binding := scope
		binding.initialize_binding(mut vm, data.name or { panic('missing function name') }.name, Value.from_object(object), .normal)!
	}
	if ordinary && !data.is_arrow_function && data.kind == .normal {
		mut prototype := Object.create(realm, realm.object_prototype)
		prototype.define_direct_property(function_constructor_key, Value.from_object(object), attribute_writable | attribute_configurable)
		object.define_direct_property(function_prototype_key, Value.from_object(prototype), attribute_writable)
	} else if data.kind in [.generator, .async_generator] {
		// Generator methods also own a prototype, but have no [[Construct]].
		parent := if data.kind == .generator { realm.generator_prototype } else { realm.async_generator_prototype }
		object.define_direct_property(function_prototype_key, Value.from_object(Object.create(realm, parent)), attribute_writable)
	}
	return object
}

fn (function &ECMAScriptFunction) name_for_call_stack() Utf16String {
	if name := function.data.name {
		return if name.name == default_export_identifier { default_export_name } else { name.name }
	}
	return function.inferred_name or { Utf16String.new() }
}

fn (function &ECMAScriptFunction) realm() ?&Realm { return function.realm_ }

fn (mut function ECMAScriptFunction) compile(mut vm VM) !&Executable {
	if executable := function.executable { return executable }
	if cached := function.cached_function_compilation() {
		function.executable = cached.executable
		function.register_bindings = cached.register_bindings
		return cached.executable
	}
	mut generator := BytecodeGenerator{
		executable: &Executable{
			name: function.name_for_call_stack()
			registers_and_locals_count: reserved_register_count
			source_code: function.source.source_code
			parsed_source: function.source.parsed_source
			starting_line: function.source.starting_line
			native_cache_scope: 'function:${function.data.source_text_start}:${function.data.source_text_end}:${function.data.is_strict_mode}:${function.data.is_arrow_function}'
		}
		strict: function.data.is_strict_mode
		starting_line: function.source.starting_line
		range: function.data.body.range
		function_body: true
		generator_function: function.data.kind == .generator
	}
	function.prepare_register_bindings(mut generator)
	if function.data.body.kind.tag == .class_field_initializer {
		expression := function.data.body.kind.expression or { return error('Missing field initializer') }
		mut value := Operand{}
		if expression.kind.tag == .function_expr && generator.executable.parsed_source.function_table.get(expression.kind.function_id).name == none {
			value = generator.temporary()
			key := (function.field_initializer_name or { return error('Missing initializer field name') }).to_value(mut vm)
			generator.emit(Instruction{op: .new_function_with_name, dst: value, lhs: generator.constant(key), identifier: expression.kind.function_id.id})
		} else { value = generator.expression(mut vm, expression)! }
		generator.emit(Instruction{op: .end, lhs: value})
	} else {
		generator.collect_vars(&function.data.body)!
		if !function.data.simple_parameters() { generator.initialize_function_parameters(mut vm, function.data)! }
		scope := function.data.body.kind.scope or { return error('Missing function body') }
		generator.lexical_declarations(scope.children, false)!
		generator.initialize_functions(scope.children)
		if function.data.kind == .generator { generator.emit(Instruction{op: .generator_start}) }
		for statement in scope.children { generator.statement(mut vm, &statement)! }
		generator.emit(Instruction{op: .end, lhs: generator.constant(js_undefined())})
	}
	generator.executable.bytecode_length = u32(generator.executable.instructions.len)
	generator.executable.validate(0)!
	function.executable = generator.executable
	function.remember_function_compilation(generator.executable)
	return generator.executable
}

fn (mut function ECMAScriptFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	if function.data.kind == .async_kind { return function.call_async(mut vm, this_value, arguments) }
	return function.call_with_new_target(mut vm, this_value, arguments, js_undefined(), none)
}

fn (mut function ECMAScriptFunction) call_with_new_target(mut vm VM, this_value Value, arguments []Value, new_target Value, class_constructor ?&BaseClassFunction) !Value {
	return function.call_body(mut vm, this_value, arguments, new_target, class_constructor, none)
}

fn (mut function ECMAScriptFunction) call_body(mut vm VM, this_value Value, arguments []Value, new_target Value, class_constructor ?&BaseClassFunction, async_execution ?&AsyncExecution) !Value {
	if function.data.kind == .async_generator { return error('LibJS async generator execution is not translated yet') }
	simple_parameters := function.data.simple_parameters()
	executable := function.compile(mut vm)!
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	mut frame := (if function.data.kind == .normal && async_execution == none {
		stack.allocate_reusable(executable.registers_and_locals_count, executable.constants, u32(arguments.len))
	} else { stack.allocate(executable.registers_and_locals_count, executable.constants, u32(arguments.len)) }) or {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	defer { stack.deallocate(mark) }
	mut environment := vm.obtain_call_environment(mut frame, function.environment)
	environment.set_function_object(FunctionObject(&function))
	environment.set_new_target(new_target)
	environment.class_constructor = class_constructor
	environment.home_object = function.object.home_object
	frame.function = FunctionObject(&function)
	frame.realm = function.realm_
	frame.script_or_module = function.script_or_module
	frame.private_environment = function.private_environment
	frame.lexical_environment = Environment(environment)
	frame.variable_environment = Environment(environment)
	frame.passed_argument_count = u32(arguments.len)
	frame.async_execution = async_execution
	if function.data.kind == .generator {
		frame.generator_execution = &GeneratorExecution{function: &function, realm: function.realm_, state: .executing}
	}
	frame.copy_call_arguments(arguments)
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_current_context() }
	if function.data.is_arrow_function {
		environment.set_this_binding_status(.lexical)
	} else if !(if constructor := class_constructor { constructor.derived } else { false }) {
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
		if function.parameter_in_register(index) {
			value := if index < arguments.len { arguments[index] } else { js_undefined() }
			for binding in function.register_bindings {
				if binding.parameter_index == index { frame.values[executable.local_index_base + binding.slot] = value }
			}
			continue
		}
		for name in parameter_bound_names(parameter) {
			if !environment.has_binding_named(name) { environment.create_mutable_binding(mut vm, name, false)! }
			if simple_parameters {
				value := if index < arguments.len { arguments[index] } else { js_undefined() }
				binding_index := environment.find_binding_index(name)
				if environment.bindings[binding_index].initialized { environment.set_mutable_binding(mut vm, name, value, false)! }
				else { environment.initialize_binding(mut vm, name, value, .normal)! }
			}
		}
	}
	if function.needs_arguments_binding() {
		object := create_arguments_object(mut vm, &function, environment, arguments)!
		name := utf16_string('arguments')
		if function.data.is_strict_mode {
			environment.create_immutable_binding(mut vm, name, false)!
		} else { environment.create_mutable_binding(mut vm, name, false)! }
		environment.initialize_binding(mut vm, name, Value.from_object(object), .normal)!
	}
	for binding in if simple_parameters { executable.global_bindings } else { []GlobalBinding{} } {
		if function.variable_in_register(binding.name) { continue }
		if !environment.has_binding_named(binding.name) {
			environment.create_mutable_binding(mut vm, binding.name, false)!
			environment.initialize_binding(mut vm, binding.name, js_undefined(), .normal)!
		}
	}
	returned := vm.run_executable(mut frame, executable, 0, ExecutionLimits{})!
	if frame.yield_is_await { return js_special_empty_value() }
	if constructor := class_constructor {
		if constructor.derived {
			if returned.is_object() { return returned }
			if !returned.is_undefined() { return vm.throw_error(.type_error, 'Derived constructor returned a non-object value') }
			return environment.get_this_binding(mut vm)
		}
	}
	return returned
}

fn (mut function ECMAScriptFunction) internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object {
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object { return realm.object_prototype_record() })!
	object := Object.create(function.realm_, prototype)
	value := function.call_with_new_target(mut vm, Value.from_object(object), arguments, Value.from_object(new_target), none)!
	return if value.is_object() { value.as_object() } else { object }
}
