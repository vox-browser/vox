module libjs

fn instance_test_target(mut vm VM, prototype &Object) &Object {
	function := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return js_undefined()
	}, 0, PropertyName.from_str('target'), none)
	mut object := function.object
	object.create_data_property(PropertyName.from_str('prototype'), Value.from_object(prototype))
	return object
}

fn test_ordinary_has_instance_walks_prototypes_and_rejects_missing_function_prototypes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	target := instance_test_target(mut vm, prototype)
	parent := Object.create(vm.realm(), prototype)
	child := Object.create(vm.realm(), parent)
	assert ordinary_has_instance(mut vm, Value.from_object(child), Value.from_object(target))!.to_boolean()
	assert !ordinary_has_instance(mut vm, Value.from_object(prototype), Value.from_object(target))!.to_boolean()
	assert !ordinary_has_instance(mut vm, Value.from_i32(42), Value.from_object(target))!.to_boolean()
	assert !ordinary_has_instance(mut vm, Value.from_object(child), Value.from_i32(42))!.to_boolean()
	mut function := target
	function.define_direct_property(PropertyName.from_str('prototype'), js_null(), 7)
	if _ := ordinary_has_instance(mut vm, Value.from_object(child), Value.from_object(target)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_instanceof_custom_handlers_keep_target_receiver_and_boolean_conversion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut target := Object.create(vm.realm(), none)
	for result in [js_undefined(), Value.from_i32(0), Value.from_i32(42),
		Value.from_object(target)] {
		method := NativeFunction.create(mut vm, vm.realm(), none, fn [target, result] (mut vm VM) !Value {
			assert vm.this_value().as_object() == target
			assert vm.argument_count() == 1 && vm.argument(0).number == 7
			return result
		}, 1, PropertyName.from_str('handler'), none)
		target.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_has_instance()),
			Value.from_object(method.object), 7)
		assert instance_of(mut vm, Value.from_i32(7), Value.from_object(target))!.to_boolean() == result.to_boolean()
	}
	for invalid in [js_null(), js_undefined(), Value.from_i32(42)] {
		if _ := instance_of(mut vm, Value.from_i32(7), invalid) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_instanceof_accessor_errors_propagate_and_bound_targets_use_their_own_handler() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut target := instance_test_target(mut vm, prototype)
	key := PropertyName.from_symbol(vm.well_known_symbol_has_instance())
	target.define_native_accessor(mut vm, vm.realm(), key, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, attribute_configurable, none)
	bound := BoundFunction.create(vm.realm(), target, js_null(), []Value{})
	if _ := ordinary_has_instance(mut vm, Value.from_i32(7), Value.from_object(bound.object)) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	method := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return vm.argument(0)
	}, 1, key, none)
	target.define_direct_property(key, Value.from_object(method.object), 7)
	assert ordinary_has_instance(mut vm, Value.from_i32(7), Value.from_object(bound.object))!.to_boolean()
	target.define_direct_property(key, Value.from_i32(42), 7)
	if _ := instance_of(mut vm, js_null(), Value.from_object(target)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_no_handler_instanceof_branch_retains_the_pinned_upstream_operand_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	target := instance_test_target(mut vm, prototype)
	instance := Object.create(vm.realm(), prototype)
	assert ordinary_has_instance(mut vm, Value.from_object(instance), Value.from_object(target))!.to_boolean()
	assert !instance_of(mut vm, Value.from_object(instance), Value.from_object(target))!.to_boolean()
}
