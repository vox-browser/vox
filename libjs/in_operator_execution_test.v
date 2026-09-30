module libjs

fn execute_in_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'in.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_in_operator_sees_own_inherited_symbol_and_numeric_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(PropertyName.from_str('inherited'), Value.from_i32(17))
	mut host := Object.create(vm.realm(), prototype)
	host.create_data_property(PropertyName.from_str('answer'), js_undefined())
	host.create_data_property(PropertyName.from_number(3), js_null())
	symbol := Symbol.create(utf16_string('answer'), .unique)
	host.create_data_property(PropertyName.from_symbol(symbol), Value.from_bool(false))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('host'), Value.from_object(host))
	global.create_data_property(PropertyName.from_str('key'), Value.from_symbol(symbol))
	for source, expected in {
		'"answer" in host;':                     true
		'"inherited" in host;':                  true
		'"missing" in host;':                    false
		'key in host;':                          true
		'3 in host;':                            true
		'"3" in host;':                          true
		'3n in host;':                           true
		'"03" in host;':                         false
		'delete host.answer; "answer" in host;': false
		'host.created=1; "created" in host;':    true
	} {
		assert execute_in_source(mut vm, source)!.as_bool() == expected, source
	}
	assert host.get(mut vm, PropertyName.from_str('inherited'))!.number == 17
}

fn test_in_rejects_non_objects_before_key_coercion_and_preserves_throw_cleanup() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut key := Object.create(vm.realm(), none)
	coerce := NativeFunction.create_raw(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		return throw_completion(Value.from_i32(23))
	}, 1, PropertyName.from_str('coerce'), none)
	key.create_data_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coerce.object))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('key'), Value.from_object(key))
	for source in ['key in null;', 'key in undefined;', 'key in 42;', 'key in "text";',
		'key in true;', 'key in 42n;'] {
		if _ := execute_in_source(mut vm, source) {
			assert false
		} else {
			object := thrown_value(err).as_object()
			assert object.error_kind()? == .type_error
			assert object.error_message()? == "'in' operator must be used on an object"
		}
	}
	if _ := execute_in_source(mut vm, 'key in globalThis;') {
		assert false
	} else {
		assert thrown_value(err).as_i32() == 23
	}
	assert vm.running_execution_context() == base
	assert vm.interpreter_stack().depth() == 0
	assert execute_in_source(mut vm, '"parseInt" in globalThis;')!.as_bool()
}
