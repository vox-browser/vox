module libjs

import math

// Translated from Runtime/GlobalObject.cpp. NativeFunction owns the callee realm
// and frame; the complete Intrinsics prototype graph is separate runtime work.
fn global_is_finite(mut vm VM) !Value {
	// 19.2.2 isFinite ( number ).
	number := vm.argument(0).to_number(mut vm)!
	return Value.from_bool(!math.is_nan(number.number) && !math.is_inf(number.number, 0))
}

fn global_is_nan(mut vm VM) !Value {
	// 19.2.3 isNaN ( number ).
	number := vm.argument(0).to_number(mut vm)!
	return Value.from_bool(math.is_nan(number.number))
}

// AK::parse_first_number<double>'s decimal prefix path delegates to fast_float
// parse_number_string (ascii_number.h). Translate its general decimal grammar;
// V strconv supplies binary conversion rather than fast_float's mantissa backend.
fn parse_first_decimal(units []u16) ?f64 {
	if units.len == 0 { return none }
	mut cursor := 0
	if units[cursor] in [u16(`-`), u16(`+`)] {
		cursor++
		if cursor == units.len { return none }
	}
	mut digits := 0
	for cursor < units.len && units[cursor] >= u16(`0`) && units[cursor] <= u16(`9`) {
		cursor++
		digits++
	}
	if cursor < units.len && units[cursor] == u16(`.`) {
		cursor++
		for cursor < units.len && units[cursor] >= u16(`0`) && units[cursor] <= u16(`9`) {
			cursor++
			digits++
		}
	}
	if digits == 0 { return none }
	if cursor < units.len && units[cursor] in [u16(`e`), u16(`E`)] {
		location_of_e := cursor
		cursor++
		if cursor < units.len && units[cursor] in [u16(`-`), u16(`+`)] { cursor++ }
		exponent_start := cursor
		for cursor < units.len && units[cursor] >= u16(`0`) && units[cursor] <= u16(`9`) {
			cursor++
		}
		// General format enables fixed notation: an incomplete exponent is a
		// trailing token, so restore the prefix ending immediately before e.
		if cursor == exponent_start { cursor = location_of_e }
	}
	return atof64_rounding_overflow(encode_utf16(units[..cursor], false)) or { return none }
}

fn global_parse_float(mut vm VM) !Value {
	// 19.2.4 parseFloat ( string ).
	argument := vm.argument(0)
	if argument.is_number() {
		if argument.number == 0 && math.signbit(argument.number) { return Value.from_i32(0) }
		return argument
	}
	input := argument.to_primitive_string(mut vm)!
	mut start := 0
	for start < input.utf16.data.len && is_number_whitespace(input.utf16.data[start]) {
		start++
	}
	units := input.utf16.data[start..]
	if units.len == 0 { return Value.from_f64(math.nan()) }
	if number := parse_first_decimal(units) { return Value.from_f64(number) }
	first := units[0]
	infinity_start := if first in [u16(`+`), u16(`-`)] { 1 } else { 0 }
	if units.len - infinity_start >= 8
		&& units[infinity_start..infinity_start + 8] == utf16_string('Infinity').data {
		return Value.from_f64(math.inf(if first == u16(`-`) { -1 } else { 1 }))
	}
	return Value.from_f64(math.nan())
}

fn global_parse_int(mut vm VM) !Value {
	// 19.2.5 parseInt ( string, radix ): retain upstream's repeated double
	// multiply/add accumulation, including rounding at each iteration.
	input := vm.argument(0).to_primitive_string(mut vm)!
	units := input.utf16.data
	mut start := 0
	for start < units.len && is_number_whitespace(units[start]) {
		start++
	}
	mut sign := 1
	if start < units.len && units[start] == u16(`-`) { sign = -1 }
	if start < units.len && units[start] in [u16(`+`), u16(`-`)] { start++ }
	mut radix := vm.argument(1).to_i32(mut vm)!
	mut strip_prefix := true
	if radix != 0 {
		if radix < 2 || radix > 36 { return Value.from_f64(math.nan()) }
		if radix != 16 { strip_prefix = false }
	} else {
		radix = 10
	}
	if strip_prefix && start + 1 < units.len && units[start] == u16(`0`)
		&& units[start + 1] in [u16(`x`), u16(`X`)] {
		start += 2
		radix = 16
	}
	mut had_digits := false
	mut number := 0.0
	for unit in units[start..] {
		// AK::parse_ascii_base36_digit after is_ascii_alphanumeric.
		digit := match unit {
			u16(`0`)...u16(`9`) { int(unit - u16(`0`)) }
			u16(`a`)...u16(`z`) { int(unit - u16(`a`)) + 10 }
			u16(`A`)...u16(`Z`) { int(unit - u16(`A`)) + 10 }
			else { -1 }
		}

		if digit < 0 || digit >= radix { break
		 }
		had_digits = true
		number *= radix
		number += digit
	}
	if !had_digits { return Value.from_f64(math.nan()) }
	return Value.from_f64(sign * number)
}

fn set_default_global_numeric_functions(mut vm VM, realm &Realm) {
	// Intrinsics.cpp::initialize creates the functions; GlobalObject.cpp's
	// set_default_global_bindings installs writable/configurable value properties.
	mut global := realm.global_object_record()
	for name, behaviour in {
		'isFinite':   NativeFunctionPointer(global_is_finite)
		'isNaN':      NativeFunctionPointer(global_is_nan)
		'parseFloat': NativeFunctionPointer(global_parse_float)
		'parseInt':   NativeFunctionPointer(global_parse_int)
	} {
		length := if name == 'parseInt' { 2.0 } else { 1.0 }
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour, length,
			PropertyName.from_str(name), none)
		global.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
}
