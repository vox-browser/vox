module libjs

// Cases from Tests/LibJS/Runtime/builtins/functions/uriEncodeDecode.js, with
// supplementary characters, reserved-escape spelling, and error cleanup.
fn execute_uri_source(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'uri.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })
}

fn test_uri_functions_preserve_reserved_sets_and_round_trip_unicode() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for text, expected in {
		'шеллы':       '%D1%88%D0%B5%D0%BB%D0%BB%D1%8B'
		'ABC abc 123': 'ABC%20abc%20123'
		'😀':          '%F0%9F%98%80'
		'ÿ':           '%C3%BF'
		'€':           '%E2%82%AC'
		'%':           '%25'
	} {
		for name in ['encodeURI', 'encodeURIComponent'] {
			assert execute_uri_source(mut vm, '${name}("${text}");')!.as_string().str() == expected
		}
		for name in ['decodeURI', 'decodeURIComponent'] {
			assert execute_uri_source(mut vm, '${name}("${expected}");')!.as_string().str() == text
		}
	}
	assert execute_uri_source(mut vm, 'encodeURI(";,/?:@&=+$#");')!.as_string().str() == ';,/?:@&=+$#'
	assert execute_uri_source(mut vm, 'encodeURIComponent(";,/?:@&=+$#");')!.as_string().str() == '%3B%2C%2F%3F%3A%40%26%3D%2B%24%23'
	assert execute_uri_source(mut vm, 'decodeURIComponent("%3B%2C%2F%3F%3A%40%26%3D%2B%24%23");')!.as_string().str() == ';,/?:@&=+$#'
	assert execute_uri_source(mut vm, 'decodeURI("%3b%2c%2f%3f%3a%40%26%3d%2b%24%23");')!.as_string().str() == '%3b%2c%2f%3f%3a%40%26%3d%2b%24%23'
	assert execute_uri_source(mut vm, 'encodeURIComponent("-_.!~*\'()");')!.as_string().str() == "-_.!~*'()"
	assert execute_uri_source(mut vm, 'decodeURIComponent("%00");')!.as_string().utf16.data == [
		u16(0),
	]
	assert execute_uri_source(mut vm, 'encodeURIComponent("\\u0000");')!.as_string().str() == '%00'
	assert execute_uri_source(mut vm, 'decodeURIComponent("a+b");')!.as_string().str() == 'a+b'
}

fn test_uri_errors_reject_invalid_sequences_and_preserve_surrogate_code_units() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for name in ['decodeURI', 'decodeURIComponent'] {
		for text in ['%', '%a', '%gh', '%%%', '%ED%BF%BF', '%C0%AF', '%ED%7F%BF', '%ED%BF',
			'%F4%90%80%80', '%80', '%FF', '%C2x%80', '%F0%80%80%80'] {
			if _ := execute_uri_source(mut vm, '${name}("${text}");') {
				assert false
			} else {
				object := thrown_value(err).as_object()
				assert object.error_kind()? == .uri_error
				assert object.error_message()? == 'URI malformed'
			}
			assert vm.running_execution_context() == base
			assert vm.interpreter_stack().depth() == 0
		}
	}
	for name in ['encodeURI', 'encodeURIComponent'] {
		for text in ['\\ud800', '\\udc00', '\\ud800A', '\\ud800\\ud800'] {
			if _ := execute_uri_source(mut vm, '${name}("${text}");') {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .uri_error
			}
		}
	}
	// Decoding an unescaped surrogate preserves it; encoding rejects it.
	assert execute_uri_source(mut vm, 'decodeURI("\\ud800");')!.as_string().utf16.data == [
		u16(0xd800),
	]
	assert execute_uri_source(mut vm, 'decodeURIComponent("\\udc00");')!.as_string().utf16.data == [
		u16(0xdc00),
	]
	assert execute_uri_source(mut vm, 'encodeURI("hello");')!.as_string().str() == 'hello'
}

fn test_uri_global_metadata_coercion_and_symbol_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	method := NativeFunction.create_raw(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		return Value.from_string(vm.create_string_from_str('a b'))
	}, 1, PropertyName.from_str('coerce'), none)
	object.create_data_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(method.object))
	mut global := vm.get_global_object()
	global.create_data_property(PropertyName.from_str('object'), Value.from_object(object))
	global.create_data_property(PropertyName.from_str('symbol'), Value.from_symbol(Symbol.create(none,
		.unique)))
	for name in ['encodeURI', 'encodeURIComponent', 'decodeURI', 'decodeURIComponent'] {
		descriptor := global.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		assert execute_uri_source(mut vm, '${name}.name;')!.as_string().str() == name
		assert execute_uri_source(mut vm, '${name}.length;')!.number == 1
		assert execute_uri_source(mut vm, '${name}();')!.as_string().str() == 'undefined'
		assert execute_uri_source(mut vm, '${name}(null);')!.as_string().str() == 'null'
		assert execute_uri_source(mut vm, '${name}(42n);')!.as_string().str() == '42'
		if _ := execute_uri_source(mut vm, '${name}(symbol);') {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert vm.running_execution_context() == base
		assert vm.interpreter_stack().depth() == 0
	}
	assert execute_uri_source(mut vm, 'encodeURI(object);')!.as_string().str() == 'a%20b'
	assert execute_uri_source(mut vm, 'decodeURI(object);')!.as_string().str() == 'a b'
}
