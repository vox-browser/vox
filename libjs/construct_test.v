module libjs

fn construction_test_call(mut vm VM) !Value {
	return vm.argument(0)
}

fn test_native_construction_uses_callee_realm_arguments_and_uninitialized_this() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut caller := vm.running_execution_context()
	environment := Environment(DeclarativeEnvironment.create(none))
	caller.lexical_environment = environment
	caller.variable_environment = environment
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	function := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
		construction_test_call, fn [foreign, environment] (mut vm VM, new_target &Object) !&Object {
			context := vm.running_execution_context()
			assert vm.realm() == foreign
			active := context.function or { panic('missing active constructor') }
			assert (active.realm() or { panic('missing constructor realm') }) == foreign
			assert context.this_value == none && context.script_or_module.is_empty()
			assert (context.lexical_environment or { panic('missing lexical environment') }) == environment
			assert (context.variable_environment or { panic('missing variable environment') }) == environment
			assert vm.argument_count() == 2
			assert vm.argument(0).number == 20 && vm.argument(1).number == 22
			assert vm.argument(2).is_undefined()
			assert Value.from_object(new_target).is_constructor()
			mut result := Object.create(foreign, none)
			result.define_direct_property(PropertyName.from_str('newTarget'), Value.from_object(new_target), 7)
			result.define_direct_property(PropertyName.from_str('sum'), add(mut vm, vm.argument(0), vm.argument(1))!, 7)
			return result
		}, 2, PropertyName.from_str('Build'))
	value := Value.from_object(function.object)
	assert value.is_constructor() && function.has_constructor()
	assert call(mut vm, value, js_null(), [Value.from_i32(42)])!.number == 42
	result := construct(mut vm, value, [Value.from_i32(20), Value.from_i32(22)], none)!
	assert result.get(mut vm, PropertyName.from_str('newTarget'))!.as_object() == function.object
	assert result.get(mut vm, PropertyName.from_str('sum'))!.number == 42
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_construction_preserves_explicit_new_target_and_propagates_errors_after_restoring_context() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	new_target := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		construction_test_call, fn (mut vm VM, new_target &Object) !&Object {
			return Object.create(vm.realm(), none)
		}, 0, PropertyName.from_str('Other'))
	function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		construction_test_call, fn [new_target] (mut vm VM, target &Object) !&Object {
			assert target == new_target.object
			assert vm.argument_count() == 0 && vm.argument(0).is_undefined()
			return throw_completion(Value.from_i32(17))
		}, 0, PropertyName.from_str('Fail'))
	if _ := construct(mut vm, Value.from_object(function.object), []Value{}, new_target.object) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	mut stack := vm.interpreter_stack()
	stack.limit = 0
	if _ := construct(mut vm, Value.from_object(function.object), []Value{}, new_target.object) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .internal_error
		assert thrown_value(err).as_object().error_message()? == ErrorType.call_stack_size_exceeded.message()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_constructor_checks_reject_primitives_ordinary_objects_and_callable_methods() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	plain := NativeFunction.create(mut vm, realm, realm.function_prototype, construction_test_call,
		0, PropertyName.from_str('Plain'), none)
	assert !plain.has_constructor()
	for value in [js_null(), js_undefined(), Value.from_bool(false), Value.from_i32(42),
		Value.from_object(Object.create(realm, none)), Value.from_object(plain.object),
		Value.from_object(realm.function_prototype_record())] {
		assert !value.is_constructor()
		if _ := construct(mut vm, value, []Value{}, none) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		construction_test_call, fn (mut vm VM, new_target &Object) !&Object {
			assert false, 'invalid new target must be rejected before construction'
			return new_target
		}, 0, PropertyName.from_str('Construct'))
	if _ := construct(mut vm, Value.from_object(constructor.object), []Value{}, plain.object) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
