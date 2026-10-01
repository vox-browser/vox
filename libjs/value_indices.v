module libjs

import math

// Runtime/Value.cpp::ToIntegerOrInfinity, including the plain-double helper.
pub fn to_integer_or_infinity(number f64) f64 {
	if math.is_nan(number) || number == 0 { return 0 }
	if math.is_inf(number, 0) { return number }
	mut integer := math.floor(math.abs(number))
	if number < 0 && integer != 0 { integer = -integer }
	return integer
}

pub fn (value Value) to_integer_or_infinity(mut vm VM) !f64 {
	return to_integer_or_infinity(value.to_number(mut vm)!.number)
}

// Runtime/Value.cpp::ToLength. Match upstream's size_t limit on 32-bit hosts.
pub fn (value Value) to_length(mut vm VM) !u64 {
	length := value.to_integer_or_infinity(mut vm)!
	if length <= 0 { return 0 }
	limit := if sizeof(voidptr) == 4 { f64(0xffffffff) } else { f64(9007199254740991) }
	return u64(math.min(length, limit))
}

// Runtime/Value.cpp::ToIndex: negative and out-of-range values must throw,
// rather than receiving ToLength's clamped result.
pub fn (value Value) to_index(mut vm VM) !u64 {
	if value.is_undefined() { return 0 }
	integer := value.to_integer_or_infinity(mut vm)!
	if integer < 0 { return vm.throw_error_type(.range_error, .invalid_index) }
	clamped := Value.from_f64(integer).to_length(mut vm)!
	if integer != f64(clamped) { return vm.throw_error_type(.range_error, .invalid_index) }
	return clamped
}
