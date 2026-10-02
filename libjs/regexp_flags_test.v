module libjs

fn test_regexp_flag_bits_match_upstream_and_validation_accepts_each_compatible_subset() {
	flags := ['d', 'g', 'i', 'm', 's', 'v', 'u', 'y']
	for index, flag in flags {
		assert int(validate_regexp_flags(utf16_string(flag))!) == 1 << index
	}
	for mask in 0 .. 256 {
		mut text := ''
		for index, flag in flags {
			if mask & (1 << index) != 0 { text += flag }
		}
		assert int(regexp_to_flag_bits(utf16_string(text))) == mask
		if mask & 0x60 == 0x60 {
			if _ := validate_regexp_flags(utf16_string(text)) {
				assert false
			} else {
				assert err.msg() == "RegExp flag 'u' is incompatible with flag 'v'"
			}
		} else {
			assert int(validate_regexp_flags(utf16_string(text))!) == mask
		}
	}
	assert int(regexp_to_flag_bits(utf16_string('!ggévu?'))) == 0x62
}

fn test_regexp_flag_errors_keep_source_priority_and_char16_diagnostic_conversion() {
	for row in [['x', "Invalid RegExp flag 'x'"], ['gg', "Repeated RegExp flag 'g'"],
		['uv', "RegExp flag 'u' is incompatible with flag 'v'"],
		['vu', "RegExp flag 'u' is incompatible with flag 'v'"],
		['uvx', "Invalid RegExp flag 'x'"], ['uvgug', "Repeated RegExp flag 'u'"],
		['uvgg', "Repeated RegExp flag 'g'"], ['é', "Invalid RegExp flag 'é'"]] {
		if _ := validate_regexp_flags(utf16_string(row[0])) {
			assert false
		} else {
			assert err is RegExpFlagError && err.msg() == row[1]
		}
	}
	for unit in [u16(0), 0x80, 0xd800, 0xdc00, 0xffff] {
		if _ := validate_regexp_flags(Utf16String.from_slice([unit])) {
			assert false
		} else {
			assert err is RegExpFlagError
			if err is RegExpFlagError {
				mut expected := utf16('Invalid RegExp flag ')
				expected << u16(`'`)
				expected << unit
				expected << u16(`'`)
				assert err.message.data == expected
			}
		}
	}
}

fn test_regexp_flag_vm_boundary_throws_syntax_error_and_restores_execution_context() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		bits := validate_regexp_flags_with_vm(mut vm,
			vm.argument(0).to_primitive_string(mut vm)!.utf16)!
		return Value.from_i32(int(bits))
	}, 1, PropertyName.from_str('flags'), none)
	for text in ['g', 'x', 'uv', 'gg'] {
		if result := call(mut vm, Value.from_object(function.object), js_undefined(), [
			Value.from_string(vm.create_string_from_str(text)),
		])
		{
			assert text == 'g' && result.number == 2
		} else {
			assert text != 'g' && thrown_value(err).as_object().error_kind()? == .syntax_error
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
