module libjs

fn test_bound_functions_capture_arguments_receiver_and_target_prototype() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	target := NativeFunction.create(mut vm, vm.realm(), prototype, fn (mut vm VM) !Value {
		assert vm.this_value().number == 7
		assert vm.argument_count() == 4
		assert vm.argument(0).number == 1 && vm.argument(1).number == 2
		assert vm.argument(2).number == 3 && vm.argument(3).number == 4
		assert vm.argument(4).is_undefined()
		return Value.from_i32(42)
	}, 4, PropertyName.from_str('target'), none)
	mut arguments := [Value.from_i32(1), Value.from_i32(2)]
	bound := BoundFunction.create(vm.realm(), target.object, Value.from_i32(7), arguments)
	arguments[0] = Value.from_i32(99)
	assert bound.object.internal_get_prototype_of()? == prototype
	assert bound.realm() == none
	assert bound.name_for_call_stack().str() == 'target'
	assert bound.object.own_property_keys().len == 0
	assert Value.from_object(bound.object).is_function()
	assert call(mut vm, Value.from_object(bound.object), js_null(), [
		Value.from_i32(3),
		Value.from_i32(4),
	])!.number == 42
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_nested_bound_functions_prepend_inner_arguments_and_keep_the_first_receiver() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	foreign := create_simple_execution_context(mut vm)
	foreign_realm := foreign.realm?
	vm.pop_execution_context()
	target := NativeFunction.create(mut vm, foreign_realm, none, fn [foreign_realm] (mut vm VM) !Value {
		assert vm.realm() == foreign_realm
		assert vm.this_value().number == 7
		assert vm.argument_count() == 3
		assert vm.argument(0).number == 1 && vm.argument(1).number == 2
			&& vm.argument(2).number == 3
		return Value.from_i32(42)
	}, 3, PropertyName.from_str('target'), none)
	first := BoundFunction.create(vm.realm(), target.object, Value.from_i32(7), [
		Value.from_i32(1),
	])
	second := BoundFunction.create(vm.realm(), first.object, Value.from_i32(99), [
		Value.from_i32(2),
	])
	assert call(mut vm, Value.from_object(second.object), Value.from_i32(100), [
		Value.from_i32(3),
	])!.number == 42
	assert vm.running_execution_context() == base && vm.realm() == base.realm?
	assert vm.interpreter_stack().depth() == 0
}

fn test_bound_native_failure_and_stack_exhaustion_restore_the_callers_state() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	target := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return vm.throw_error(.type_error, 'Bound target failure')
	}, 0, PropertyName.from_str('target'), none)
	bound := BoundFunction.create(vm.realm(), target.object, js_null(), [
		Value.from_i32(1),
	])
	if _ := call(mut vm, Value.from_object(bound.object), js_undefined(), []Value{}) {
		assert false
	} else {
		error_object := thrown_value(err).as_object()
		assert error_object.error_message()? == 'Bound target failure'
		assert error_object.error_data?.stack_string(false).contains('target')
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	mut stack := vm.interpreter_stack()
	stack.limit = 0
	if _ := call(mut vm, Value.from_object(bound.object), js_undefined(), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()? == ErrorType.call_stack_size_exceeded.message()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
