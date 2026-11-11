module libjs

// codegen.rs::emit_delete_reference and SlowPaths.cpp::delete_by_value / variable.
fn execute_delete_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'delete.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn delete_test_host(mut vm VM) &Object {
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(mut vm, PropertyName.from_str('answer'), Value.from_i32(17)) or {
		panic(err)
	}
	mut host := Object.create(vm.realm(), prototype)
	host.create_data_property(mut vm, PropertyName.from_str('answer'), Value.from_i32(42)) or {
		panic(err)
	}
	host.define_direct_property(PropertyName.from_str('fixed'), Value.from_i32(2), 0)
	mut global := vm.get_global_object()
	global.create_data_property(mut vm, PropertyName.from_str('host'), Value.from_object(host)) or {
		panic(err)
	}
	return host
}

fn test_delete_compiles_identifiers_properties_and_non_reference_side_effects() {
	for source, expected in {
		'delete missing;':                                    'true'
		'var x=1; delete x;':                                 'false'
		'let x=1; delete x;':                                 'false'
		'const x=1; delete x;':                               'false'
		'x=1; delete x;':                                     'true'
		'x=1; delete x; typeof x;':                           '"undefined"'
		'delete host.answer;':                                'true'
		'delete host["answer"]; host.answer;':                '17'
		'delete host.fixed;':                                 'false'
		'delete host.missing;':                               'true'
		'var key="answer"; delete host[(key="answer",key)];': 'true'
		'var count=0; delete (count++,1); count;':            '1'
		'delete (host.answer=17); host.answer;':              '17'
		'"use strict"; delete 1;':                            'true'
		'"use strict"; delete host.answer;':                  'true'
		'"use strict"; delete host.missing;':                 'true'
	} {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		delete_test_host(mut vm)
		assert execute_delete_source(mut vm, source)!.str() == expected, source
		assert vm.execution_context_stack().len == 1
		assert vm.interpreter_stack().depth() == 0
	}
}

fn test_delete_preserves_symbol_keys_and_prototype_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut host := delete_test_host(mut vm)
	symbol := Symbol.create(utf16_string('answer'), .unique)
	host.create_data_property(mut vm, PropertyName.from_symbol(symbol), Value.from_i32(42)) or {
		panic(err)
	}
	mut global := vm.get_global_object()
	global.create_data_property(mut vm, PropertyName.from_str('key'), Value.from_symbol(symbol)) or {
		panic(err)
	}
	assert execute_delete_source(mut vm, 'delete host[key];')!.as_bool()
	assert !host.has_own_property(PropertyName.from_symbol(symbol))
	assert host.get(mut vm, PropertyName.from_str('answer'))!.number == 42
	assert execute_delete_source(mut vm, 'delete host.answer;')!.as_bool()
	assert !host.has_own_property(PropertyName.from_str('answer'))
	assert host.prototype?.get(mut vm, PropertyName.from_str('answer'))!.number == 17
	assert execute_delete_source(mut vm, 'host.answer;')!.number == 17
}

fn test_delete_errors_keep_the_original_throw_and_restore_execution_state() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	host := delete_test_host(mut vm)
	for source in ['"use strict"; delete host.fixed;', 'delete null.answer;',
		'delete undefined.answer;'] {
		if _ := execute_delete_source(mut vm, source) {
			assert false
		} else {
			object := thrown_value(err).as_object()
			assert object.error_kind()? == .type_error
			if source.contains('null.') || source.contains('undefined.') {
				assert object.error_message()? == 'ToObject on null or undefined'
			}
		}
		assert vm.running_execution_context() == base
		assert vm.interpreter_stack().depth() == 0
	}
	if _ := execute_delete_source(mut vm, 'delete (0,missing);') {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .reference_error
	}
	assert host.get(mut vm, PropertyName.from_str('fixed'))!.number == 2
	assert execute_delete_source(mut vm, 'host.answer;')!.number == 42
}

fn test_delete_rejects_nullish_bases_before_computed_key_coercion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut host := delete_test_host(mut vm)
	mut key := Object.create(vm.realm(), none)
	coerce := NativeFunction.create(mut vm, vm.realm(), none, fn [mut host] (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		host.set(mut vm, PropertyName.from_str('answer'), Value.from_i32(17), .yes)!
		return throw_completion(Value.from_i32(23))
	}, 1, PropertyName.from_str('coerce'), none)
	key.create_data_property(mut vm, PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coerce.object)) or { panic(err) }
	mut global := vm.get_global_object()
	global.create_data_property(mut vm, PropertyName.from_str('key'), Value.from_object(key)) or {
		panic(err)
	}
	for base in ['null', 'undefined'] {
		for prefix in ['', '"use strict"; '] {
			if _ := execute_delete_source(mut vm, '${prefix}delete ${base}[key];') {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
			assert host.get(mut vm, PropertyName.from_str('answer'))!.number == 42
		}
	}
	// A valid base still converts the key and preserves its original exception.
	if _ := execute_delete_source(mut vm, 'delete host[key];') {
		assert false
	} else {
		assert thrown_value(err).as_i32() == 23
	}
	assert host.get(mut vm, PropertyName.from_str('answer'))!.number == 17
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
}
