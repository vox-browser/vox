module libjs

fn bound_construction_call(mut vm VM) !Value {
	return vm.argument(0)
}

fn test_nested_bound_construction_forwards_arguments_and_substitutes_matching_new_targets() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
		bound_construction_call, fn [foreign] (mut vm VM, new_target &Object) !&Object {
			assert vm.realm() == foreign
			assert vm.execution_context_stack().len == 2 && vm.interpreter_stack().depth() == 1
			assert vm.running_execution_context().this_value == none
			assert vm.argument_count() == 3
			assert vm.argument(0).number == 1 && vm.argument(1).number == 2 && vm.argument(2).number == 3
			mut result := Object.create(foreign, none)
			result.define_direct_property(PropertyName.from_str('newTarget'), Value.from_object(new_target), 7)
			return result
		}, 3, PropertyName.from_str('Build'))
	first := BoundFunction.create(local, target.object, Value.from_i32(99), [Value.from_i32(1)])
	second := BoundFunction.create(local, first.object, js_null(), [Value.from_i32(2)])
	assert first.has_constructor() && second.has_constructor()
	assert Value.from_object(second.object).is_constructor()
	assert first.object.own_property_keys().len == 0
	other := NativeFunction.create_constructor(mut vm, local, local.function_prototype,
		bound_construction_call, fn (mut vm VM, new_target &Object) !&Object {
			assert false, 'the explicit new target must not be called'
			return new_target
		}, 0, PropertyName.from_str('Other'))
	for new_target in [target.object, first.object, second.object, other.object] {
		result := construct(mut vm, Value.from_object(second.object), [Value.from_i32(3)], new_target)!
		final_target := result.get(mut vm, PropertyName.from_str('newTarget'))!.as_object()
		assert final_target == if new_target == other.object { other.object } else { target.object }
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	default_result := construct(mut vm, Value.from_object(second.object), [Value.from_i32(3)], none)!
	assert default_result.get(mut vm, PropertyName.from_str('newTarget'))!.as_object() == target.object
}

fn test_bound_constructor_errors_restore_the_caller_and_nonconstructable_targets_stay_callable_only() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	plain := NativeFunction.create(mut vm, realm, realm.function_prototype, bound_construction_call,
		0, PropertyName.from_str('Plain'), none)
	bound_plain := BoundFunction.create(realm, plain.object, js_null(), []Value{})
	assert !bound_plain.has_constructor() && !Value.from_object(bound_plain.object).is_constructor()
	assert call(mut vm, Value.from_object(bound_plain.object), js_null(), [Value.from_i32(42)])!.number == 42
	if _ := construct(mut vm, Value.from_object(bound_plain.object), []Value{}, none) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	target := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		bound_construction_call, fn (mut vm VM, new_target &Object) !&Object {
			assert vm.argument(0).number == 42
			return throw_completion(Value.from_i32(17))
		}, 0, PropertyName.from_str('Fail'))
	bound := BoundFunction.create(realm, target.object, js_null(), [Value.from_i32(42)])
	if _ := construct(mut vm, Value.from_object(bound.object), []Value{}, none) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	mut stack := vm.interpreter_stack()
	stack.limit = 0
	if _ := construct(mut vm, Value.from_object(bound.object), []Value{}, none) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .internal_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
