module libjs

fn run_instanceof_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'instanceof.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn instance_execution_target(mut vm VM) &Object {
	prototype := Object.create(vm.realm(), none)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, 0, PropertyName.from_str('Target'), none)
	mut target := function.object
	target.create_data_property(PropertyName.from_str('prototype'), Value.from_object(prototype))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('Target'), Value.from_object(target))
	global.create_data_property(PropertyName.from_str('instance'), Value.from_object(Object.create(vm.realm(),
		prototype)))
	return target
}

fn test_compiled_instanceof_uses_default_handler_and_follows_bound_targets() {
	for source, expected in {
		'instance instanceof Target;':                       true
		'instance instanceof Target.bind(null);':            true
		'instance instanceof Target.bind(null).bind(null);': true
		'Target instanceof Target;':                         false
		'Target.prototype instanceof Target;':               false
		'42 instanceof Target;':                             false
		'null instanceof Target;':                           false
		'undefined instanceof Target;':                      false
		'instance instanceof (instance=null,Target);':       true
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		instance_execution_target(mut vm)
		assert run_instanceof_source(mut vm, source)!.to_boolean() == expected, source
		assert vm.execution_context_stack().len == 1 && vm.interpreter_stack().depth() == 0
	}
}

fn test_compiled_instanceof_custom_handler_getters_preserve_effect_order_and_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut target := instance_execution_target(mut vm)
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return vm.argument(0)
	}, 1, PropertyName.from_str('handler'), none)
	key := PropertyName.from_symbol(vm.well_known_symbol_has_instance())
	target.define_native_accessor(mut vm, vm.realm(), key, fn [method] (mut vm VM) !Value {
		return Value.from_object(method.object)
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	assert run_instanceof_source(mut vm, '42 instanceof Target;')!.to_boolean()
	assert !run_instanceof_source(mut vm, '0 instanceof Target;')!.to_boolean()
	assert run_instanceof_source(mut vm, '42 instanceof Target.bind(null);')!.to_boolean()
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 0, key, 'get')
	assert target.internal_define_own_property(key, PropertyDescriptor{
		getter: Value.from_object(getter.object)
	})
	if _ := run_instanceof_source(mut vm,
		'globalThis.before=1; instance instanceof Target; globalThis.after=1;')
	{
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.get_global_object().get(mut vm, PropertyName.from_str('before'))!.number == 1
	assert !vm.get_global_object().has_own_property(PropertyName.from_str('after'))
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_compiled_instanceof_throws_for_invalid_rhs_and_bad_prototype_but_keeps_primitive_fast_path() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut target := instance_execution_target(mut vm)
	for source in ['instance instanceof 42;', 'instance instanceof null;',
		'instance instanceof globalThis;', 'instance instanceof parseInt;'] {
		if _ := run_instanceof_source(mut vm, source) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	target.define_direct_property(PropertyName.from_str('prototype'), js_null(), 7)
	assert !run_instanceof_source(mut vm, '42 instanceof Target;')!.to_boolean()
	if _ := run_instanceof_source(mut vm, 'instance instanceof Target;') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	assert run_instanceof_source(mut vm, '42;')!.number == 42
}
