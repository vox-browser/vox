module libjs

import encoding.utf8

// Runtime/GlobalObject.cpp::{encode,decode,decode_percent_encoded_byte} and the
// four public URI functions. UTF-8 validation uses V's strict DFA in place of
// AK::Utf8View's simdutf dependency; UTF-16 is retained throughout the algorithms.
fn uri_encode(mut vm VM, units []u16, unescaped_set string) !Value {
	mut encoded := []u16{}
	mut index := 0
	hex := '0123456789ABCDEF'.bytes()
	for index < units.len {
		unit := units[index]
		if unit < 0x80 && unescaped_set.bytes().contains(u8(unit)) {
			index++
			encoded << unit
			continue
		}
		// CodePointAt(string, k): reject an unpaired surrogate before applying
		// the UTF-8 transformation, as the upstream Encode algorithm requires.
		start := index
		if is_utf16_high_surrogate(unit) {
			if index + 1 >= units.len || !is_utf16_low_surrogate(units[index + 1]) {
				return vm.throw_error_type(.uri_error, .uri_malformed)
			}
			index += 2
		} else if is_utf16_low_surrogate(unit) {
			return vm.throw_error_type(.uri_error, .uri_malformed)
		} else {
			index++
		}
		for octet in encode_utf16(units[start..index], false).bytes() {
			encoded << u16(`%`)
			encoded << u16(hex[octet >> 4])
			encoded << u16(hex[octet & 15])
		}
	}
	return Value.from_string(vm.create_string(Utf16String.from_slice(encoded)))
}

fn uri_hex_digit(unit u16) ?u8 {
	return match unit {
		u16(`0`)...u16(`9`) { u8(unit - u16(`0`)) }
		u16(`a`)...u16(`f`) { u8(unit - u16(`a`) + 10) }
		u16(`A`)...u16(`F`) { u8(unit - u16(`A`) + 10) }
		else { none }
	}
}

fn uri_decode_percent_byte(mut vm VM, units []u16, percent_index int) !u8 {
	if percent_index + 2 >= units.len { return vm.throw_error_type(.uri_error, .uri_malformed) }
	first := uri_hex_digit(units[percent_index + 1]) or {
		return vm.throw_error_type(.uri_error, .uri_malformed)
	}
	second := uri_hex_digit(units[percent_index + 2]) or {
		return vm.throw_error_type(.uri_error, .uri_malformed)
	}
	return (first << 4) | second
}

fn uri_decode(mut vm VM, units []u16, reserved_set string) !Value {
	mut decoded := []u16{}
	for index := 0; index < units.len; index++ {
		unit := units[index]
		if unit != u16(`%`) {
			decoded << unit
			continue
		}
		first := uri_decode_percent_byte(mut vm, units, index)!
		index += 2
		if first < 0x80 {
			if reserved_set.bytes().contains(first) {
				decoded << units[index - 2..index + 1]
			} else {
				decoded << u16(first)
			}
			continue
		}
		// count_leading_zeroes_safe(u8(~first)) from the upstream decoder.
		mut leading_ones := 0
		mut mask := u8(0x80)
		for mask != 0 && first & mask != 0 {
			leading_ones++
			mask >>= 1
		}
		if leading_ones == 1 || leading_ones > 4 {
			return vm.throw_error_type(.uri_error, .uri_malformed)
		}
		mut bytes := [first]
		for _ in 1 .. leading_ones {
			if index + 3 >= units.len || units[index + 1] != u16(`%`) {
				return vm.throw_error_type(.uri_error, .uri_malformed)
			}
			bytes << uri_decode_percent_byte(mut vm, units, index + 1)!
			index += 3
		}
		text := bytes.bytestr()
		if !utf8.validate_str(text) { return vm.throw_error_type(.uri_error, .uri_malformed) }
		decoded << utf16(text)
	}
	return Value.from_string(vm.create_string(Utf16String.from_slice(decoded)))
}

fn global_encode_uri(mut vm VM) !Value {
	input := vm.argument(0).to_primitive_string(mut vm)!
	return uri_encode(mut vm, input.utf16.data,
		";/?:@&=+$,abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.!~*'()#")
}

fn global_encode_uri_component(mut vm VM) !Value {
	input := vm.argument(0).to_primitive_string(mut vm)!
	return uri_encode(mut vm, input.utf16.data,
		"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.!~*'()")
}

fn global_decode_uri(mut vm VM) !Value {
	input := vm.argument(0).to_primitive_string(mut vm)!
	return uri_decode(mut vm, input.utf16.data, ';/?:@&=+$,#')
}

fn global_decode_uri_component(mut vm VM) !Value {
	input := vm.argument(0).to_primitive_string(mut vm)!
	return uri_decode(mut vm, input.utf16.data, '')
}

fn set_default_global_uri_functions(mut vm VM, realm &Realm) {
	mut global := realm.global_object_record()
	for name, behaviour in {
		'decodeURI':          NativeFunctionPointer(global_decode_uri)
		'decodeURIComponent': NativeFunctionPointer(global_decode_uri_component)
		'encodeURI':          NativeFunctionPointer(global_encode_uri)
		'encodeURIComponent': NativeFunctionPointer(global_encode_uri_component)
	} {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour, 1,
			PropertyName.from_str(name), none)
		global.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
}
