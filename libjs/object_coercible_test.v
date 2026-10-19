module libjs

fn test_require_object_coercible_preserves_each_non_nullish_value_without_boxing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('valueOf'), fn (mut vm VM) !Value {
		panic('RequireObjectCoercible does not convert objects')
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	for value in [Value.from_f64(-0.0), Value.from_bool(false),
		Value.from_string(vm.create_string_from_str('')),
		Value.from_symbol(Symbol.create(none,
			.unique)),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_object(object)] {
		result := require_object_coercible(mut vm, value)!
		assert same_value(value, result)
	}
}

fn test_require_object_coercible_throws_source_error_for_null_and_undefined() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for value in [js_null(), js_undefined()] {
		if _ := require_object_coercible(mut vm, value) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			assert thrown_value(err).as_object().error_message()?.str() == '${value.str()} cannot be converted to an object'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
