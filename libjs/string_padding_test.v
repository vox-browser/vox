module libjs

import math

fn string_padding_call(mut vm VM, placement StringPadPlacement, receiver Value, arguments []Value) !Value {
	method := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype, if placement == .start {
		NativeFunctionPointer(string_prototype_pad_start)
	} else {
		NativeFunctionPointer(string_prototype_pad_end)
	}, 1, PropertyName.from_str(if placement == .start { 'padStart' } else { 'padEnd' }), none)
	return call(mut vm, Value.from_object(method.object), receiver, arguments)
}

fn test_string_padding_retains_upstream_defaults_filler_truncation_and_utf16_halves() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := vm.create_string_from_str('foo')
	for placement in [StringPadPlacement.start, .end] {
		for maximum in [js_undefined(), js_null(), Value.from_f64(math.nan()),
			Value.from_i32(-1), Value.from_i32(0), Value.from_i32(3),
			Value.from_f64(math.inf(-1))] {
			result := string_padding_call(mut vm, placement, Value.from_string(text), [
				maximum,
				Value.from_symbol(Symbol.create(none, .unique)),
			])!
			assert voidptr(result.as_string()) == voidptr(text)
		}
		for maximum in [Value.from_i32(5), Value.from_f64(5.9),
			Value.from_string(vm.create_string_from_str('5'))] {
			result := string_padding_call(mut vm, placement, Value.from_string(text), [
				maximum,
			])!
			assert result.as_string().str() == if placement == .start {
				'  foo'
			} else {
				'foo  '
			}
		}
		for index, filler in [Value.from_string(vm.create_string_from_str('+')),
			Value.from_i32(1), js_null(), Value.from_string(vm.create_string_from_str('bar')),
			Value.from_string(vm.create_string_from_str('123456789'))] {
			result := string_padding_call(mut vm, placement, Value.from_string(text), [
				Value.from_i32(10),
				filler,
			])!
			prefix := ['+++++++', '1111111', 'nullnul', 'barbarb', '1234567'][index]
			assert result.as_string().str() == if placement == .start {
				prefix + 'foo'
			} else {
				'foo' + prefix
			}
		}
		for maximum in [Value.from_i32(10), Value.from_f64(math.inf(1)),
			Value.from_f64(9007199254740991.0)] {
			result := string_padding_call(mut vm, placement, Value.from_string(text), [
				maximum,
				Value.from_string(vm.empty_string()),
			])!
			assert voidptr(result.as_string()) == voidptr(text)
		}
		emoji := vm.create_string_from_str('😀')
		for index, length in [3, 4, 5] {
			result := string_padding_call(mut vm, placement, Value.from_string(emoji), [
				Value.from_i32(length),
				Value.from_string(emoji),
			])!
			expected := if placement == .start {
				[[u16(0xd83d), 0xd83d, 0xde00], [u16(0xd83d), 0xde00, 0xd83d, 0xde00],
					[u16(0xd83d), 0xde00, 0xd83d, 0xd83d, 0xde00]][index]
			} else {
				[[u16(0xd83d), 0xde00, 0xd83d], [u16(0xd83d), 0xde00, 0xd83d, 0xde00],
					[u16(0xd83d), 0xde00, 0xd83d, 0xde00, 0xd83d]][index]
			}
			assert result.as_string().utf16.data == expected
		}
		filler := vm.create_string(Utf16String.from_slice([u16(0), 0xdc00, 0xd800]))
		result := string_padding_call(mut vm, placement, Value.from_string(vm.empty_string()), [
			Value.from_i32(4),
			Value.from_string(filler),
		])!
		assert result.as_string().utf16.data == [u16(0), 0xdc00, 0xd800, 0]
	}
}

@[heap]
struct StringPaddingLog {
mut:
	steps []int
}

fn test_string_padding_conversion_order_early_returns_and_errors_match_source() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringPaddingLog{}
	for placement in [StringPadPlacement.start, .end] {
		for mode in ['normal', 'no fill', 'empty fill', 'count throws', 'fill throws'] {
			mut values := []Value{}
			for index in 0 .. 3 {
				mut object := Object.create(vm.realm(), none)
				converter := NativeFunction.create(mut vm, vm.realm(),
					vm.realm().function_prototype, fn [index, mode, mut log] (mut vm VM) !Value {
					assert vm.argument(0).as_string().str() == if index == 1 {
						'number'
					} else {
						'string'
					}
					log.steps << index
					if (index == 1 && mode == 'count throws')
						|| (index == 2 && mode == 'fill throws') {
						return throw_completion(Value.from_i32(77))
					}
					if index == 0 { return Value.from_string(vm.create_string_from_str('ab')) }
					if index == 1 { return Value.from_i32(if mode == 'no fill' { 1 } else { 5 })
					 }
					return Value.from_string(vm.create_string_from_str(if mode == 'empty fill' {
						''
					} else {
						'xy'
					}))
				}, 1, PropertyName.from_str('convert'), none)
				object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
					Value.from_object(converter.object), 7)
				values << Value.from_object(object)
			}
			if result := string_padding_call(mut vm, placement, values[0], values[1..]) {
				assert result.as_string().str() == if mode != 'normal' {
					'ab'
				} else if placement == .start {
					'xyxab'
				} else {
					'abxyx'
				}
			} else {
				assert mode in ['count throws', 'fill throws']
				assert thrown_value(err).number == 77
			}
			assert log.steps == if mode in ['no fill', 'count throws'] {
				[0, 1]
			} else {
				[0, 1, 2]
			}
			log.steps.clear()
			for receiver in [js_null(), js_undefined()] {
				if _ := string_padding_call(mut vm, placement, receiver, values[1..]) {
					assert false
				} else {
					assert thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
			assert log.steps.len == 0
		}
		text := Value.from_string(vm.create_string_from_str('a'))
		for poison in [Value.from_symbol(Symbol.create(none, .unique)),
			Value.from_bigint(string_to_bigint(utf16_string('5')) or { panic('invalid BigInt literal') })] {
			if _ := string_padding_call(mut vm, placement, text, [poison]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		// Storage rejection comes after filler conversion, but before allocating.
		if _ := string_padding_call(mut vm, placement, text, [
			Value.from_f64(math.inf(1)),
			Value.from_symbol(Symbol.create(none, .unique)),
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		if _ := string_padding_call(mut vm, placement, text, [
			Value.from_f64(2147483648.0),
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
			assert thrown_value(err).as_object().error_message()?.str() == 'string size must not overflow'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
