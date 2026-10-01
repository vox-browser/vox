module libjs

fn constructor_test_boolean_prototype(realm &Realm) &Object {
	return realm.boolean_prototype_record()
}

fn constructor_test_callable(mut vm VM) !Value {
	return js_undefined()
}

fn test_function_realm_follows_native_and_nested_bound_targets_and_current_realm_fallback() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	target := NativeFunction.create(mut vm, foreign, foreign.function_prototype,
		constructor_test_callable, 0, PropertyName.from_str('Foreign'), none)
	bound := BoundFunction.create(local, target.object, js_null(), []Value{})
	nested := BoundFunction.create(local, bound.object, js_null(), []Value{})
	for function in [target.object, bound.object, nested.object] {
		assert get_function_realm(mut vm, function)! == foreign
	}
	assert get_function_realm(mut vm, local.function_prototype_record())! == local
	// Function.prototype has no [[Realm]], even when owned by a foreign realm.
	assert get_function_realm(mut vm, foreign.function_prototype_record())! == local
	assert vm.running_execution_context() == base
}

@[heap]
struct PrototypeReads {
mut:
	count int
}

fn test_constructor_prototype_observes_get_once_and_uses_the_constructor_realm_only_for_non_objects() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	custom := Object.create(local, none)
	for value in [Value.from_object(custom), js_null(), js_undefined(), Value.from_bool(false),
		Value.from_i32(42), Value.from_string(vm.create_string_from_str('prototype'))] {
		mut reads := &PrototypeReads{}
		function := NativeFunction.create(mut vm, foreign, foreign.function_prototype,
			constructor_test_callable, 0, PropertyName.from_str('Foreign'), none)
		mut object := function.object
		object.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [mut reads, value, foreign] (mut vm VM) !Value {
			reads.count++
			assert vm.realm() == foreign
			return value
		}, unsafe { nil }, attribute_configurable, foreign.function_prototype)
		prototype := get_prototype_from_constructor(mut vm, object, constructor_test_boolean_prototype)!
		assert prototype == if value.is_object() { custom } else { foreign.boolean_prototype_record() }
		assert reads.count == 1
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	target := NativeFunction.create(mut vm, foreign, foreign.function_prototype,
		constructor_test_callable, 0, PropertyName.from_str('Foreign'), none)
	bound := BoundFunction.create(local, target.object, js_null(), []Value{})
	assert get_prototype_from_constructor(mut vm, bound.object, constructor_test_boolean_prototype)! == foreign.boolean_prototype_record()
}

fn test_constructor_prototype_propagates_access_errors_before_intrinsic_fallback() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		constructor_test_callable, 0, PropertyName.from_str('Bad'), none)
	mut object := function.object
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('prototype'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	if _ := get_prototype_from_constructor(mut vm, object, fn (realm &Realm) &Object {
		assert false, 'fallback must not run after an abrupt Get'
		return realm.boolean_prototype_record()
	}) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
