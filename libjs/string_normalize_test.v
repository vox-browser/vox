module libjs

fn string_normalize_call(mut vm VM, receiver Value, arguments []Value) !Value {
	method := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		string_prototype_normalize, 0, PropertyName.from_str('normalize'), none)
	return call(mut vm, Value.from_object(method.object), receiver, arguments)
}

fn test_string_normalize_all_four_forms_preserve_upstream_reordering_composition_and_utf16() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	forms := ['NFC', 'NFD', 'NFKC', 'NFKD']
	for row in [['ẛ̣', 'ẛ̣', 'ẛ̣', 'ṩ', 'ṩ'],
		['é', 'é', 'é', 'é', 'é'], ['ﬃ', 'ﬃ', 'ﬃ', 'ffi', 'ffi'],
		['①', '①', '①', '1', '1'], ['가', '가', '가', '가', '가'],
		['😀', '😀', '😀', '😀', '😀']] {
		receiver := Value.from_string(vm.create_string_from_str(row[0]))
		for index, form in forms {
			result := string_normalize_call(mut vm, receiver, [
				Value.from_string(vm.create_string_from_str(form)),
			])!
			assert result.as_string().utf16 == utf16_string(row[index + 1])
		}
	}
	receiver := Value.from_string(vm.create_string_from_str('é'))
	for arguments in [[]Value{}, [js_undefined()]] {
		assert string_normalize_call(mut vm, receiver, arguments)!.as_string().str() == 'é'
	}
	text := Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xd800), 0, 0x41, 0x301,
		0xdc00])))
	assert string_normalize_call(mut vm, text, []Value{})!.as_string().utf16.data == [
		u16(0xd800),
		0,
		0xc1,
		0xdc00,
	]
	assert string_normalize_call(mut vm, text, [
		Value.from_string(vm.create_string_from_str('NFD')),
	])!.as_string().utf16.data == text.as_string().utf16.data
	for form in forms {
		assert string_normalize_call(mut vm, Value.from_string(vm.empty_string()), [
			Value.from_string(vm.create_string_from_str(form)),
		])!.as_string().is_empty()
	}
	assert string_normalize_call(mut vm, Value.from_i32(42), []Value{})!.as_string().str() == '42'
}

fn test_string_normalize_rejects_invalid_forms_before_empty_string_shortcuts() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for receiver in [Value.from_string(vm.create_string_from_str('foo')),
		Value.from_string(vm.empty_string())] {
		for form in [Value.from_string(vm.create_string_from_str('bar')),
			Value.from_string(vm.create_string_from_str('NFC1')),
			Value.from_string(vm.create_string_from_str('nfc')),
			Value.from_string(vm.empty_string()), js_null(), Value.from_i32(42),
			Value.from_bool(false)] {
			if _ := string_normalize_call(mut vm, receiver, [form]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .range_error
				form_string := form.to_primitive_string(mut vm)!
				expected_message :=
					"The normalization form must be one of NFC, NFD, NFKC, NFKD. Got '" +
					form_string.str() + "'"
				assert thrown_value(err).as_object().error_message()?.str() == expected_message
			}
		}
		if _ := string_normalize_call(mut vm, receiver, [
			Value.from_symbol(Symbol.create(none, .unique)),
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

@[heap]
struct StringNormalizeLog {
mut:
	steps []int
}

fn test_string_normalize_converts_receiver_then_form_once_and_restores_abrupt_completions() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringNormalizeLog{}
	for mode in ['normal', 'receiver throws', 'form throws'] {
		mut values := []Value{}
		for index in 0 .. 2 {
			mut object := Object.create(vm.realm(), none)
			converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mode, mut log] (mut vm VM) !Value {
				assert vm.argument(0).as_string().str() == 'string'
				log.steps << index
				if (index == 0 && mode == 'receiver throws')
					|| (index == 1 && mode == 'form throws') {
					return throw_completion(Value.from_i32(77))
				}
				return Value.from_string(vm.create_string_from_str(if index == 0 {
					'ẛ̣'
				} else {
					'NFKC'
				}))
			}, 1, PropertyName.from_str('convert'), none)
			object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(converter.object), 7)
			values << Value.from_object(object)
		}
		if result := string_normalize_call(mut vm, values[0], values[1..]) {
			assert mode == 'normal'
			assert result.as_string().str() == 'ṩ'
		} else {
			assert mode != 'normal'
			assert thrown_value(err).number == 77
		}
		assert log.steps == if mode == 'receiver throws' {
			[0]
		} else {
			[0, 1]
		}
		log.steps.clear()
		for receiver in [js_null(), js_undefined(), Value.from_symbol(Symbol.create(none, .unique))] {
			if _ := string_normalize_call(mut vm, receiver, values[1..]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert log.steps.len == 0
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
