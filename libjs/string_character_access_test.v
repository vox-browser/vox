module libjs

import math

fn string_character_call(mut vm VM, name string, receiver Value, arguments []Value) !Value {
	behaviour := match name {
		'at' { NativeFunctionPointer(string_prototype_at) }
		'charAt' { NativeFunctionPointer(string_prototype_char_at) }
		'charCodeAt' { NativeFunctionPointer(string_prototype_char_code_at) }
		'codePointAt' { NativeFunctionPointer(string_prototype_code_point_at) }
		'toString' { NativeFunctionPointer(string_prototype_to_string) }
		else { NativeFunctionPointer(string_prototype_value_of) }
	}

	function := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		behaviour, if name in ['toString', 'valueOf'] { 0 } else { 1 },
		PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_string_branded_methods_preserve_primitive_identity_and_reject_inherited_or_spoofed_slots() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := vm.create_string(Utf16String.from_slice([u16(0xd800), 0, 0xdc00, 0xd83d, 0xde00]))
	parent := Object.create(vm.realm(), none)
	wrapper := StringObject.create(vm.realm(), text, parent).object
	mut spoof := Object.create(vm.realm(), wrapper)
	spoof.class_name = 'StringObject'
	conversion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		assert false, 'brand validation must not coerce'
		return js_undefined()
	}, 0, PropertyName.from_str('coerce'), none)
	spoof.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(conversion.object), 7)
	for name in ['toString', 'valueOf'] {
		for receiver in [Value.from_string(text), Value.from_object(wrapper)] {
			result := string_character_call(mut vm, name, receiver, [
				Value.from_object(spoof),
			])!
			assert voidptr(result.as_string()) == voidptr(text)
		}
		for receiver in [js_undefined(), js_null(), Value.from_i32(1),
			Value.from_bool(true), Value.from_object(spoof)] {
			if _ := string_character_call(mut vm, name, receiver, []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type String'
			}
		}
	}
}

fn test_string_character_access_indexes_units_with_method_specific_negative_and_out_of_bounds_rules() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	units := [u16(`A`), 0xd83d, 0xde00, 0xd800, u16(`B`), 0xdc00, 0]
	text := Value.from_string(vm.create_string(Utf16String.from_slice(units)))
	for index, unit in units {
		assert string_character_call(mut vm, 'at', text, [Value.from_i32(index)])!.as_string().utf16.data == [
			unit,
		]
		assert string_character_call(mut vm, 'at', text, [
			Value.from_i32(index - units.len),
		])!.as_string().utf16.data == [unit]
		assert string_character_call(mut vm, 'charAt', text, [
			Value.from_f64(f64(index) + 0.9),
		])!.as_string().utf16.data == [unit]
		assert string_character_call(mut vm, 'charCodeAt', text, [
			Value.from_i32(index),
		])!.number == unit
		expected := if index == 1 { u32(0x1f600) } else { u32(unit) }
		assert string_character_call(mut vm, 'codePointAt', text, [
			Value.from_i32(index),
		])!.number == expected
	}
	for argument in [js_undefined(), Value.from_f64(math.nan()),
		Value.from_f64(-0.0)] {
		assert string_character_call(mut vm, 'at', text, [argument])!.as_string().str() == 'A'
		assert string_character_call(mut vm, 'codePointAt', text, [argument])!.number == 65
	}
	for position in [f64(-8), f64(7), math.inf(1), math.inf(-1)] {
		assert string_character_call(mut vm, 'at', text, [Value.from_f64(position)])!.is_undefined()
		assert string_character_call(mut vm, 'charAt', text, [
			Value.from_f64(position),
		])!.as_string().is_empty()
		assert string_character_call(mut vm, 'charCodeAt', text, [
			Value.from_f64(position),
		])!.is_nan()
		assert string_character_call(mut vm, 'codePointAt', text, [
			Value.from_f64(position),
		])!.is_undefined()
	}
	assert string_character_call(mut vm, 'charAt', text, [Value.from_i32(-1)])!.as_string().is_empty()
	for index in 0 .. units.len {
		point := string_code_point_at(text.as_string().utf16, index)
		assert point.code_unit_count == if index == 1 {
			2
		} else {
			1
		}
		assert point.is_unpaired_surrogate == (index in [2, 3, 5])
	}
}

@[heap]
struct StringCharacterLog {
mut:
	hints []string
}

fn test_string_character_methods_coerce_receiver_before_index_and_reject_nullish_before_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringCharacterLog{}
	mut receiver := Object.create(vm.realm(), none)
	mut position := Object.create(vm.realm(), none)
	for stored in [receiver, position] {
		mut object := stored
		conversion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
			hint := vm.argument(0).as_string().str()
			log.hints << hint
			return if hint == 'string' {
				Value.from_string(vm.create_string_from_str('ABC'))
			} else {
				Value.from_i32(1)
			}
		}, 1, PropertyName.from_str('coerce'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(conversion.object), 7)
	}
	for name in ['at', 'charAt', 'charCodeAt', 'codePointAt'] {
		result := string_character_call(mut vm, name, Value.from_object(receiver), [
			Value.from_object(position),
		])!
		assert log.hints == ['string', 'number']
		if name in ['at', 'charAt'] {
			assert result.as_string().str() == 'B'
		} else {
			assert result.number == 66
		}
		log.hints.clear()
		for value in [js_null(), js_undefined()] {
			if _ := string_character_call(mut vm, name, value, [
				Value.from_object(position),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == value.str() +
					' cannot be converted to an object'
			}
			assert log.hints.len == 0
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
