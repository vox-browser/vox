module libjs

fn test_string_trim_exact_whitespace_set_retains_inner_and_non_whitespace_utf16_units() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for unit in string_trim_whitespace {
		text := Value.from_string(vm.create_string(Utf16String.from_slice([unit, unit, u16(`A`),
			unit, u16(`B`), unit])))
		assert trim_string(mut vm, text, .both)!.data == [u16(`A`), unit, u16(`B`)]
		assert trim_string(mut vm, text, .start)!.data == [u16(`A`), unit, u16(`B`), unit]
		assert trim_string(mut vm, text, .end)!.data == [unit, unit, u16(`A`), unit, u16(`B`)]
		assert trim_string(mut vm, Value.from_string(vm.create_string(Utf16String.from_slice([
			unit,
			unit,
		]))), .both)!.is_empty()
	}
	// These are deliberately outside the 25-unit source list.
	for unit in [u16(0x0085), 0x180e, 0x200b, 0xd800, 0xdc00, 0] {
		text := Utf16String.from_slice([unit, u16(`A`), unit])
		assert trim_string(mut vm, Value.from_string(vm.create_string(text)), .both)! == text
	}
	assert trim_string(mut vm, Value.from_string(vm.create_string_from_str('  😀  ')), .both)!.str() == '😀'
}

@[heap]
struct StringTrimLog {
mut:
	count int
}

fn test_string_trim_native_bodies_use_string_hint_once_and_preserve_nullish_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringTrimLog{}
	mut receiver := Object.create(vm.realm(), none)
	converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		log.count++
		return Value.from_string(vm.create_string_from_str('  text  '))
	}, 1, PropertyName.from_str('coerce'), none)
	receiver.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(converter.object), 7)
	behaviours := [NativeFunctionPointer(string_prototype_trim), string_prototype_trim_start,
		string_prototype_trim_end]
	for index, name in ['trim', 'trimStart', 'trimEnd'] {
		function := Value.from_object(NativeFunction.create_raw(mut vm, vm.realm(),
			vm.realm().function_prototype, behaviours[index], 0, PropertyName.from_str(name), none).object)
		result := call(mut vm, function, Value.from_object(receiver), []Value{})!
		assert result.as_string().str() == ['text', 'text  ', '  text'][index]
		assert log.count == 1
		log.count = 0
		for receiver_value in [js_null(), js_undefined(),
			Value.from_symbol(Symbol.create(none, .unique))] {
			if _ := call(mut vm, function, receiver_value, []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
