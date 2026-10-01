module libjs

@[heap]
struct ReflectCallLog {
mut:
	events []string
}

fn reflect_call_body(mut vm VM, construct_call bool, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [construct_call] (mut vm VM) !Value {
		if construct_call { return reflect_construct(mut vm) }
		return reflect_apply(mut vm)
	}, 2, PropertyName.from_str('reflectCall'), none)
	return call(mut vm, Value.from_object(function.object), js_null(), arguments)
}

fn test_reflect_apply_validates_callable_before_list_reads_and_forwards_original_receiver() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReflectCallLog{}
	mut list := Object.create(vm.realm(), none)
	list.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut log] (mut vm VM) !Value {
		log.events << 'length'
		return Value.from_i32(2)
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	for index in 0 .. 2 {
		list.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(u32(index)), fn [index, mut log] (mut vm VM) !Value {
			log.events << index.str()
			return Value.from_i32(index + 20)
		}, unsafe { nil }, 0, vm.realm().function_prototype)
	}
	if _ := reflect_call_body(mut vm, false, [Value.from_i32(42),
		js_undefined(), Value.from_object(list)])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '42 is not a function'
	}
	assert log.events.len == 0
	for receiver in [js_undefined(), js_null(), Value.from_i32(42),
		Value.from_object(list)] {
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [receiver, mut log] (mut vm VM) !Value {
			log.events << 'call'
			assert same_value(vm.this_value(), receiver)
			assert vm.argument_count() == 2 && vm.argument(0).number == 20
				&& vm.argument(1).number == 21
			return Value.from_i32(77)
		}, 2, PropertyName.from_str('callback'), none)
		result := reflect_call_body(mut vm, false, [
			Value.from_object(function.object),
			receiver,
			Value.from_object(list),
		])!
		assert result.number == 77
		assert log.events == ['length', '0', '1', 'call']
		log.events.clear()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_reflect_apply_propagates_list_and_call_errors_and_supports_bound_targets() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert vm.this_value().number == 42 && vm.argument_count() == 2
		assert vm.argument(0).number == 1 && vm.argument(1).number == 2
		return throw_completion(Value.from_i32(77))
	}, 2, PropertyName.from_str('callback'), none)
	bound := BoundFunction.create(vm.realm(), function.object, Value.from_i32(42), [
		Value.from_i32(1),
	])
	mut list := Object.create(vm.realm(), none)
	list.define_direct_property(PropertyName.from_str('length'), Value.from_i32(1), 7)
	list.define_direct_property(PropertyName.from_number(0), Value.from_i32(2), 7)
	if _ := reflect_call_body(mut vm, false, [Value.from_object(bound.object),
		js_null(), Value.from_object(list)])
	{
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	list.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	if _ := reflect_call_body(mut vm, false, [Value.from_object(function.object),
		js_null(), Value.from_object(list)])
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	for value in [js_null(), js_undefined(), Value.from_string(vm.create_string_from_str('12'))] {
		if _ := reflect_call_body(mut vm, false, [Value.from_object(function.object),
			js_null(), value])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == '${value.str()} is not an object'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_reflect_construct_validates_target_then_present_new_target_before_array_like_reads() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReflectCallLog{}
	mut list := Object.create(vm.realm(), none)
	list.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut log] (mut vm VM) !Value {
		log.events << 'length'
		return Value.from_i32(0)
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	constructor := vm.realm().boolean_constructor_record()
	for arguments in [[Value.from_i32(42), Value.from_object(list),
		js_null()],
		[Value.from_object(constructor), Value.from_object(list),
			js_undefined()],
		[Value.from_object(constructor), Value.from_object(list),
			Value.from_i32(7)]] {
		if _ := reflect_call_body(mut vm, true, arguments) {
			assert false
		} else {
			value := if arguments[0].is_object() { arguments[2] } else { arguments[0] }
			assert thrown_value(err).as_object().error_message()?.str() == '${value.str()} is not a constructor'
		}
	}
	assert log.events.len == 0
	result := reflect_call_body(mut vm, true, [Value.from_object(constructor),
		Value.from_object(list)])!.as_object()
	assert !result.boolean_object?.value
	assert voidptr(result.prototype?) == voidptr(vm.realm().boolean_prototype_record())
	assert log.events == ['length']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_reflect_construct_preserves_explicit_new_target_and_nested_bound_construction() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	mut log := &ReflectCallLog{}
	prototype := Object.create(foreign, none)
	new_constructor := NativeFunction.create_constructor(mut vm, local, local.function_prototype, fn (mut vm VM) !Value {
		panic('new target is not called')
	}, fn (mut vm VM, new_target &Object) !&Object {
		panic('new target is not constructed')
	}, 0, PropertyName.from_str('NewTarget'))
	mut new_object := new_constructor.object
	new_object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(prototype), 7)
	target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype, fn (mut vm VM) !Value {
		panic('Reflect.construct does not call target')
	}, fn [foreign, new_object, mut log] (mut vm VM, new_target &Object) !&Object {
		log.events << 'construct'
		assert voidptr(vm.realm()) == voidptr(foreign) && voidptr(new_target) == voidptr(new_object)
		assert vm.argument_count() == 3
		assert vm.argument(0).number == 1 && vm.argument(1).number == 2
			&& vm.argument(2).number == 3
		return BooleanObject.create_with_prototype(foreign, true, new_target.get(mut vm,
			PropertyName.from_str('prototype'))!.as_object()).object
	}, 3, PropertyName.from_str('Target'))
	bound := BoundFunction.create(local, target.object, js_null(), [
		Value.from_i32(1)])
	nested := BoundFunction.create(local, bound.object, js_null(), [
		Value.from_i32(2)])
	mut list := Object.create(local, none)
	list.define_direct_property(PropertyName.from_str('length'), Value.from_i32(1), 7)
	list.define_direct_property(PropertyName.from_number(0), Value.from_i32(3), 7)
	result := reflect_call_body(mut vm, true, [Value.from_object(nested.object),
		Value.from_object(list), Value.from_object(new_object)])!.as_object()
	assert result.boolean_object?.value && voidptr(result.prototype?) == voidptr(prototype)
	assert log.events == ['construct']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
