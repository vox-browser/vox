module libjs

fn string_case_call(mut vm VM, receiver Value, uppercase bool, arguments []Value) !Value {
	method := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, if uppercase {
		NativeFunctionPointer(string_prototype_to_uppercase)
	} else {
		NativeFunctionPointer(string_prototype_to_lowercase)
	}, 0, PropertyName.from_str(if uppercase { 'toUpperCase' } else { 'toLowerCase' }), none)
	return call(mut vm, Value.from_object(method.object), receiver, arguments)
}

fn test_string_case_maps_upstream_expansions_context_and_supplementary_utf16() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for row in [['ω', 'ω', 'Ω'], ['Ω', 'ω', 'Ω'], ['😀', '😀', '😀'],
		['foo', 'foo', 'FOO'], ['Foo', 'foo', 'FOO'], ['FOO', 'foo', 'FOO'], ['ß', 'ß', 'SS'],
		['İ', 'i̇', 'İ'], ['ﬀ', 'ﬀ', 'FF'], ['ﬁ', 'ﬁ', 'FI'], ['ﬂ', 'ﬂ', 'FL'],
		['ﬃ', 'ﬃ', 'FFI'], ['ﬄ', 'ﬄ', 'FFL'], ['ﬅ', 'ﬅ', 'ST'], ['ﬆ', 'ﬆ', 'ST'],
		['ΐ', 'ΐ', 'Ϊ́'], ['ΰ', 'ΰ', 'Ϋ́'], ['ᾷ', 'ᾷ', 'Α͂Ι'],
		['ῇ', 'ῇ', 'Η͂Ι'], ['ῷ', 'ῷ', 'Ω͂Ι'], ['ΟΣ', 'ος', 'ΟΣ'],
		['ΟΣΑ', 'οσα', 'ΟΣΑ'], ['𐐀𐐨', '𐐨𐐨', '𐐀𐐀']] {
		receiver := Value.from_string(vm.create_string_from_str(row[0]))
		for uppercase in [false, true] {
			result := string_case_call(mut vm, receiver, uppercase, []Value{})!
			assert result.as_string().utf16 == utf16_string(row[if uppercase { 2 } else { 1 }]), '${row[0]} uppercase=${uppercase}: ${result.as_string().str()}'
		}
	}
	text := Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xd800), 0x41, 0, 0xdc00,
		0x42])))
	assert string_case_call(mut vm, text, false, []Value{})!.as_string().utf16.data == [
		u16(0xd800),
		0x61,
		0,
		0xdc00,
		0x62,
	]
	assert string_case_call(mut vm, text, true, []Value{})!.as_string().utf16.data == text.as_string().utf16.data
	for uppercase in [false, true] {
		assert string_case_call(mut vm, Value.from_string(vm.empty_string()), uppercase, []Value{})!.as_string().is_empty()
	}
}

@[heap]
struct StringCaseLog {
mut:
	calls int
}

fn test_string_case_coerces_once_ignores_arguments_and_restores_conversion_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringCaseLog{}
	for mode in ['normal', 'throw', 'symbol'] {
		mut receiver := Object.create(vm.realm(), none)
		converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut log] (mut vm VM) !Value {
			assert vm.argument(0).as_string().str() == 'string'
			log.calls++
			if mode == 'throw' { return throw_completion(Value.from_i32(77)) }
			if mode == 'symbol' { return Value.from_symbol(Symbol.create(none, .unique)) }
			return Value.from_string(vm.create_string_from_str('FoΩ'))
		}, 1, PropertyName.from_str('convert'), none)
		receiver.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(converter.object), 7)
		for uppercase in [false, true] {
			if result := string_case_call(mut vm, Value.from_object(receiver), uppercase, [
				Value.from_symbol(Symbol.create(none, .unique)),
			])
			{
				assert mode == 'normal'
				assert result.as_string().str() == if uppercase {
					'FOΩ'
				} else {
					'foω'
				}
			} else {
				assert mode != 'normal'
				if mode == 'throw' {
					assert thrown_value(err).number == 77
				} else {
					assert thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
			assert log.calls == 1
			log.calls = 0
			for value in [js_null(), js_undefined(), Value.from_symbol(Symbol.create(none, .unique))] {
				if _ := string_case_call(mut vm, value, uppercase, []Value{}) {
					assert false
				} else {
					assert thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
			assert log.calls == 0
			assert string_case_call(mut vm, Value.from_bool(true), uppercase, []Value{})!.as_string().str() == if uppercase {
				'TRUE'
			} else {
				'true'
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_string_case_default_mapping_is_locale_independent() {
	assert unicode_string_case(utf16_string('I'), false).str() == 'i'
	assert unicode_string_case(utf16_string('i'), true).str() == 'I'
	assert unicode_string_case(utf16_string('IΩ'), false).str() == 'iω'
	assert unicode_string_case(utf16_string('iω'), true).str() == 'IΩ'
}
