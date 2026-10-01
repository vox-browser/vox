module libjs

import math

// Runtime/Value.h number predicates. These inspect the tag without coercion.
pub fn (value Value) is_finite_number() bool {
	if !value.is_number() { return false }
	if value.is_int32() { return true }
	return !math.is_nan(value.number) && !math.is_inf(value.number, 0)
}

pub fn (value Value) is_integral_number() bool {
	if value.is_int32() { return true }
	return value.is_finite_number() && math.trunc(value.number) == value.number
}

pub fn (value Value) is_nan() bool {
	return value.is_number() && math.is_nan(value.number)
}

// Runtime/NumberConstructor.cpp::{is_finite,is_integer,is_nan,is_safe_integer}.
pub fn number_constructor_is_finite(mut vm VM) !Value {
	return Value.from_bool(vm.argument(0).is_finite_number())
}

pub fn number_constructor_is_integer(mut vm VM) !Value {
	return Value.from_bool(vm.argument(0).is_integral_number())
}

pub fn number_constructor_is_nan(mut vm VM) !Value {
	return Value.from_bool(vm.argument(0).is_nan())
}

pub fn number_constructor_is_safe_integer(mut vm VM) !Value {
	number := vm.argument(0)
	if number.is_integral_number() {
		if math.abs(number.number) <= 9007199254740991.0 { return Value.from_bool(true) }
	}
	return Value.from_bool(false)
}
