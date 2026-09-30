module libjs

fn execute_property_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'properties.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn install_property_object(mut vm VM) &Object {
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(PropertyName.from_str('inherited'), Value.from_i32(42))
	mut host := Object.create(vm.realm(), prototype)
	host.create_data_property(PropertyName.from_str('answer'), Value.from_i32(42))
	host.create_data_property(PropertyName.from_number(3), Value.from_i32(42))
	method := NativeFunction.create_raw(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return vm.this_value()
	}, 0, PropertyName.from_str('method'), none)
	host.create_data_property(PropertyName.from_str('method'), Value.from_object(method.object))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('host'), Value.from_object(host))
	return host
}

fn test_compiled_property_reads_and_method_calls_preserve_key_and_receiver() {
	for source, expected in {
		'host.answer;':                           '42'
		'host["answer"];':                        '42'
		'host[3];':                               '42'
		'host["3"];':                             '42'
		'host[3n];':                              '42'
		'host.inherited;':                        '42'
		'host.missing;':                          'undefined'
		'host.method() === host;':                'true'
		'host["method"]() === host;':             'true'
		'(host.method)() === host;':              'true'
		'(0,host.method)() === undefined;':       'true'
		'var h=host; h.method(h=null) === host;': 'true'
		'host.method.name;':                      '"method"'
		'host.method.length;':                    '0'
		'globalThis.host === host;':              'true'
		'"A😀".length;':                          '3'
		'"A😀"["length"];':                       '3'
		'"A😀"[0n];':                             '"A"'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		install_property_object(mut vm)
		assert execute_property_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert execute_property_source(mut vm, '"A😀"[1];')!.as_string().utf16.data == [
		u16(0xd83d),
	]
	assert execute_property_source(mut vm, '"A😀"[2];')!.as_string().utf16.data == [
		u16(0xde00),
	]
}

fn test_computed_keys_use_string_hint_once_and_keep_symbol_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut host := install_property_object(mut vm)
	symbol := Symbol.create(utf16_string('slot'), .unique)
	host.create_data_property(PropertyName.from_symbol(symbol), Value.from_i32(42))
	mut key := Object.create(vm.realm(), none)
	key.create_data_property(PropertyName.from_str('calls'), Value.from_i32(0))
	method := NativeFunction.create(mut vm, vm.realm(), none, fn [symbol] (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		mut receiver := vm.this_value().as_object()
		calls := receiver.get(PropertyName.from_str('calls')).number
		receiver.set(mut vm, PropertyName.from_str('calls'), Value.from_f64(calls + 1), .yes)!
		return Value.from_symbol(symbol)
	}, 1, PropertyName.from_str('key'), none)
	key.create_data_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(method.object))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('key'), Value.from_object(key))
	assert execute_property_source(mut vm, 'host[key];')!.number == 42
	assert key.get(PropertyName.from_str('calls')).number == 1
	key.set(mut vm, PropertyName.from_str('calls'), Value.from_i32(0), .yes)!
	if _ := execute_property_source(mut vm, 'null[key];') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert key.get(PropertyName.from_str('calls')).number == 0
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}

fn test_property_access_failures_leave_later_scripts_runnable() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	install_property_object(mut vm)
	for source in ['null.answer;', 'undefined.answer;', 'host.answer();'] {
		if _ := execute_property_source(mut vm, source) {
			assert false
		} else {
			object := thrown_value(err).as_object()
			assert object.error_kind()? == .type_error
			assert object.error_data?.stack_string(false).contains('properties.js')
		}
		assert vm.running_execution_context() == base
		assert vm.interpreter_stack().depth() == 0
	}
	assert execute_property_source(mut vm, 'host.answer;')!.number == 42
}
