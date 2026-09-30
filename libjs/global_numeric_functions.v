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
		'isFinite': NativeFunctionPointer(global_is_finite)
		'isNaN':    NativeFunctionPointer(global_is_nan)
		'parseInt': NativeFunctionPointer(global_parse_int)
	} {
		length := if name == 'parseInt' { 2.0 } else { 1.0 }
		function := NativeFunction.create_raw(mut vm, realm, none, behaviour, length,
			PropertyName.from_str(name), none)
		global.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
}
