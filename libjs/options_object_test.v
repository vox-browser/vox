module libjs

fn test_get_options_object_creates_distinct_empty_null_prototype_records() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	first := get_options_object(mut vm, js_undefined())!
	second := get_options_object(mut vm, js_undefined())!
	assert voidptr(first) != voidptr(second)
	assert first.prototype == none && second.prototype == none
	assert first.own_property_keys().len == 0
}

fn test_get_options_object_preserves_identity_without_reading_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut options := Object.create(Realm.create(), none)
	options.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('valueOf'), fn (mut vm VM) !Value {
		panic('GetOptionsObject must not read properties')
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	result := get_options_object(mut vm, Value.from_object(options))!
	assert voidptr(result) == voidptr(options)
}

fn test_get_options_object_rejects_every_defined_primitive_without_boxing() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for value in [js_null(), Value.from_i32(42), Value.from_bool(false),
		Value.from_string(vm.create_string_from_str('options')),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_symbol(Symbol.create(none, .unique))] {
		if _ := get_options_object(mut vm, value) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			assert thrown_value(err).as_object().error_message()?.str() == 'Options is not an object'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
