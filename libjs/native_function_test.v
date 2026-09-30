module libjs

fn native_sum(mut vm VM) !Value {
	mut result := Value.from_i32(0)
	for i in 0 .. vm.argument_count() {
		result = add(mut vm, result, vm.argument(i))!
	}
	assert vm.argument(vm.argument_count()).is_undefined()
	return result
}

fn native_failure(mut vm VM) !Value {
	return vm.throw_error(.type_error, 'Native failure')
}

fn test_native_functions_define_metadata_with_upstream_property_attributes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	initial_native_count := vm.native_function_count()
	for name, expected in {
		'plain': 'get plain'
		'':      'get '
	} {
		function := NativeFunction.create_raw(mut vm, vm.realm(), none, native_sum, 2,
			PropertyName.from_str(name), 'get')
		value := Value.from_object(function.object)
		assert value.is_function()
		assert typeof_value(value) == 'function'
		assert function.is_strict_mode()
		assert !function.has_constructor()
		assert function.initial_name()?.str() == expected
		for key in ['name', 'length'] {
			descriptor := function.object.internal_get_own_property(PropertyName.from_str(key))?
			assert !descriptor.writable? && !descriptor.enumerable? && descriptor.configurable?
		}
		assert function.object.get(PropertyName.from_str('name')).as_string().str() == expected
		assert function.object.get(PropertyName.from_str('length')).number == 2
	}
	assert vm.native_function_count() == initial_native_count + 1
	for description, expected in {
		'key': '[key]'
		'':    '[]'
	} {
		function := NativeFunction.create(mut vm, vm.realm(), none, native_sum, 0, PropertyName.from_symbol(Symbol.create(utf16_string(description),
			.unique)), none)
		assert function.object.get(PropertyName.from_str('name')).as_string().str() == expected
	}
	anonymous := NativeFunction.create(mut vm, vm.realm(), none, native_sum, 0, PropertyName.from_symbol(Symbol.create(none,
		.unique)), none)
	assert anonymous.object.get(PropertyName.from_str('name')).as_string().is_empty()
	private := NativeFunction.create(mut vm, vm.realm(), none, native_sum, 0, PrivateName{
		unique_id:   1
		description: utf16_string('#method')
	}, none)
	assert private.object.get(PropertyName.from_str('name')).as_string().str() == '#method'
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(PropertyName.from_str('inherited'), Value.from_i32(42))
	with_prototype := NativeFunction.create_raw(mut vm, vm.realm(), prototype, native_sum, 0,
		PropertyName.from_str('sum'), none)
	assert with_prototype.object.get(PropertyName.from_str('inherited')).number == 42
}

fn test_native_calls_install_arguments_this_realm_and_restore_caller_environment() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut caller := vm.running_execution_context()
	caller.lexical_environment = Environment(vm.realm().global_environment_record())
	caller.variable_environment = caller.lexical_environment
	private := PrivateEnvironment.create(mut vm, none)
	caller.private_environment = private
	foreign := create_simple_execution_context(mut vm)
	foreign_realm := foreign.realm?
	vm.pop_execution_context()
	lexical := caller.lexical_environment?
	variable := caller.variable_environment?
	function := NativeFunction.create(mut vm, foreign_realm, none, fn [foreign_realm, private, lexical, variable] (mut vm VM) !Value {
		frame := vm.running_execution_context()
		assert vm.realm() == foreign_realm
		assert vm.active_function_object() != none
		assert (frame.private_environment or { panic('missing environment') }) == private
		assert (frame.lexical_environment or { panic('missing environment') }) == lexical
		assert (frame.variable_environment or { panic('missing environment') }) == variable
		assert frame.script_or_module.is_empty()
		assert vm.argument_count() == 2
		assert frame.passed_argument_count == 2
		assert vm.this_value().number == 41
		assert vm.argument(0).number == 1
		assert vm.argument(1).number == 2
		assert vm.argument(2).is_undefined()
		return add(mut vm, vm.this_value(), vm.argument(0))
	}, 2, PropertyName.from_str('foreign'), none)
	assert call(mut vm, Value.from_object(function.object), Value.from_i32(41), [
		Value.from_i32(1),
		Value.from_i32(2),
	])!.number == 42
	assert vm.running_execution_context() == base
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
	assert vm.realm() == base.realm?
	assert vm.running_execution_context().private_environment? == private
}

fn test_capturing_and_raw_native_functions_share_call_and_job_paths() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for raw in [false, true] {
		function := if raw {
			NativeFunction.create_raw(mut vm, vm.realm(), none, native_sum, 0,
				PropertyName.from_str('sum'), none)
		} else {
			NativeFunction.create(mut vm, vm.realm(), none, native_sum, 0,
				PropertyName.from_str('sum'), none)
		}
		value := Value.from_object(function.object)
		assert call(mut vm, value, js_undefined(), []Value{})!.number == 0
		assert call(mut vm, value, js_undefined(), [Value.from_i32(20),
			Value.from_i32(22)])!.number == 42
		mut job := make_job_callback(value.as_function())
		assert call_job_callback(mut vm, mut job, js_null(), [
			Value.from_i32(42),
		])!.number == 42
		assert vm.interpreter_stack().depth() == 0
	}
	for n in [40, 41] {
		function := NativeFunction.create(mut vm, vm.realm(), none, fn [n] (mut vm VM) !Value {
			return Value.from_i32(n + 1)
		}, 0, PropertyName.from_str('captured'), none)
		assert call(mut vm, Value.from_object(function.object), js_undefined(), []Value{})!.number ==
			n + 1
	}
}

fn test_native_call_errors_restore_frames_and_reject_non_callable_values() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := NativeFunction.create_raw(mut vm, vm.realm(), none, native_failure, 0,
		PropertyName.from_str('hostThrow'), none)
	if _ := call(mut vm, Value.from_object(function.object), js_undefined(), []Value{}) {
		assert false
	} else {
		object := thrown_value(err).as_object()
		assert object.error_message()? == 'Native failure'
		assert object.error_data?.stack_string(false).contains('hostThrow')
	}
	assert vm.running_execution_context() == base
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
	for value in [js_null(), js_undefined(), Value.from_i32(42),
		Value.from_object(Object.create(vm.realm(), none))] {
		if _ := call(mut vm, value, js_undefined(), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	mut stack := vm.interpreter_stack()
	stack.limit = 0
	if _ := call(mut vm, Value.from_object(function.object), js_undefined(), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == ErrorType.call_stack_size_exceeded.message()
	}
	assert vm.running_execution_context() == base
	assert vm.interpreter_stack().depth() == 0
}
