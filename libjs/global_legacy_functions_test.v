module libjs

fn execute_legacy_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'legacy.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_escape_and_unescape_follow_upstream_code_unit_fixtures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	// Tests/LibJS/Runtime/builtins/functions/escapeUnescape.js.
	for text, expected in {
		'abc123':         'abc123'
		'äöü':            '%E4%F6%FC'
		'ć':              '%u0107'
		'@*_+-./':        '@*_+-./'
		'\\ud834\\udf06': '%uD834%uDF06'
		'😀':             '%uD83D%uDE00'
		" !~'()?#%":      '%20%21%7E%27%28%29%3F%23%25'
	} {
		assert execute_legacy_source(mut vm, 'escape("${text}");')!.as_string().str() == expected
		actual := execute_legacy_source(mut vm, 'unescape("${expected}");')!
		original := execute_legacy_source(mut vm, '"${text}";')!
		assert actual.as_string().utf16.data == original.as_string().utf16.data
	}
	assert execute_legacy_source(mut vm, 'unescape("äöü");')!.as_string().str() == 'äöü'
	assert execute_legacy_source(mut vm,
		'escape("\\u0000\\u001f\\u007f\\u0080\\u00ff\\u0100\\ud800\\udfff\\uffff");')!.as_string().str() == '%00%1F%7F%80%FF%u0100%uD800%uDFFF%uFFFF'
	assert execute_legacy_source(mut vm, 'unescape("%uD800");')!.as_string().utf16.data == [
		u16(0xd800),
	]
	assert execute_legacy_source(mut vm, 'unescape("%C3%A9");')!.as_string().utf16.data == [
		u16(0xc3),
		u16(0xa9),
	]
}

fn test_unescape_preserves_malformed_sequences_and_decodes_only_once() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for text in ['%', '%a', '%gh', '%u', '%u123', '%u0g00', '%U0041', '%u１２３４'] {
		assert execute_legacy_source(mut vm, 'unescape("${text}");')!.as_string().str() == text
	}
	for text, expected in {
		'%25u0041':     '%u0041'
		'%%41':         '%A'
		'%u00411':      'A1'
		'%u00ff%fF%4a': 'ÿÿJ'
		'%u0g00%41%':   '%u0g00A%'
		'%u0025u0041':  '%u0041'
		'a+b':          'a+b'
	} {
		assert execute_legacy_source(mut vm, 'unescape("${text}");')!.as_string().str() == expected
	}
}

fn test_legacy_functions_round_trip_every_utf16_code_unit() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	units := []u16{len: 65536, init: u16(index)}
	value := Value.from_string(vm.create_string(Utf16String.from_slice(units)))
	escape := vm.get_global_object().get(mut vm, PropertyName.from_str('escape'))!
	unescape := vm.get_global_object().get(mut vm, PropertyName.from_str('unescape'))!
	escaped := call(mut vm, escape, js_undefined(), [value])!
	decoded := call(mut vm, unescape, js_undefined(), [escaped])!
	assert decoded.as_string().utf16.data == units
}

@[heap]
struct LegacyCoercionState {
mut:
	calls int
}

fn test_legacy_function_metadata_coercion_and_abrupt_completion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut state := &LegacyCoercionState{}
	mut object := Object.create(vm.realm(), none)
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut state] (mut vm VM) !Value {
		state.calls++
		assert vm.this_value().is_object()
		assert vm.argument(0).as_string().str() == 'string'
		return Value.from_string(vm.create_string_from_str('a b'))
	}, 1, PropertyName.from_str('coerce'), none)
	key := PropertyName.from_symbol(vm.well_known_symbol_to_primitive())
	object.create_data_property(mut vm, key, Value.from_object(method.object)) or { panic(err) }
	mut global := vm.get_global_object()
	global.create_data_property(mut vm, PropertyName.from_str('object'), Value.from_object(object)) or {
		panic(err)
	}
	global.create_data_property(mut vm, PropertyName.from_str('symbol'), Value.from_symbol(Symbol.create(none,
		.unique))) or { panic(err) }
	for name in ['escape', 'unescape'] {
		descriptor := global.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		assert descriptor.value?.as_object().internal_get_prototype_of()? == vm.realm().function_prototype_record()
		assert execute_legacy_source(mut vm, '${name}.name;')!.as_string().str() == name
		assert execute_legacy_source(mut vm, '${name}.length;')!.number == 1
		for expression, expected in {
			'':     'undefined'
			'null': 'null'
			'42n':  '42'
			'true': 'true'
		} {
			assert execute_legacy_source(mut vm, '${name}(${expression});')!.as_string().str() == expected
		}
		if _ := execute_legacy_source(mut vm, '${name}(symbol);') {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert execute_legacy_source(mut vm, 'escape.call(null,object);')!.as_string().str() == 'a%20b'
	assert execute_legacy_source(mut vm, 'unescape.bind(null,object)();')!.as_string().str() == 'a b'
	assert state.calls == 2
	thrower := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 1, PropertyName.from_str('coerce'), none)
	object.create_data_property(mut vm, key, Value.from_object(thrower.object)) or { panic(err) }
	for name in ['escape', 'unescape'] {
		if _ := execute_legacy_source(mut vm, '${name}(object);') {
			assert false
		} else {
			assert thrown_value(err).number == 17
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
