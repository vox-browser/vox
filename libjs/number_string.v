module libjs

import math

// Runtime/NumberPrototype.cpp::this_number_value. Inherited slots and
// conversion hooks do not qualify a receiver for Number prototype methods.
fn this_number_value(mut vm VM, value Value) !Value {
	if value.is_number() { return value }
	if value.is_object() {
		if wrapper := value.as_object().number_object { return Value.from_f64(wrapper.value) }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Number')
}

const number_radix_precision = [0, 0, 52, 32, 26, 22, 20, 18, 17, 16, 15, 15, 14, 14, 13, 13, 13,
	12, 12, 12, 12, 11, 11, 11, 11, 11, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]
const number_radix_digits = '0123456789abcdefghijklmnopqrstuvwxyz'

// Runtime/NumberPrototype.cpp::to_string. Preserve the pinned implementation's
// floating-point radix division and fixed fractional precision, including its
// implementation-defined rounding for large non-decimal numbers.
pub fn number_prototype_to_string(mut vm VM) !Value {
	number_value := this_number_value(mut vm, vm.this_value())!
	radix_mv := if vm.argument(0).is_undefined() {
		f64(10)
	} else {
		vm.argument(0).to_integer_or_infinity(mut vm)!
	}
	if radix_mv < 2 || radix_mv > 36 { return vm.throw_error_type(.range_error, .invalid_radix) }
	if radix_mv == 10 { return Value.from_string(number_value.to_primitive_string(mut vm)!) }
	if !number_value.is_finite_number() || number_value.number == 0 {
		return Value.from_string(number_value.to_primitive_string(mut vm)!)
	}
	mut number := number_value.number
	negative := number < 0
	if negative { number *= -1 }
	mut int_part := math.floor(number)
	mut decimal_part := number - int_part
	radix := int(radix_mv)
	mut backwards := []u8{}
	if int_part == 0 {
		backwards << u8(`0`)
	} else {
		for int_part > 0 {
			backwards << number_radix_digits[int(math.floor(math.fmod(int_part, radix)))]
			int_part /= radix
			int_part = math.floor(int_part)
		}
	}
	mut builder := []u16{}
	if negative { builder << u16(`-`) }
	for index := backwards.len - 1; index >= 0; index-- {
		builder << u16(backwards[index])
	}
	if decimal_part != 0 {
		builder << u16(`.`)
		for _ in 0 .. number_radix_precision[radix] {
			decimal_part *= radix
			integral := u64(math.floor(decimal_part))
			builder << u16(number_radix_digits[int(integral)])
			decimal_part -= f64(integral)
		}
		for builder.last() == u16(`0`) {
			builder.delete_last()
		}
	}
	return Value.from_string(vm.create_string(Utf16String{ data: builder }))
}

pub fn number_prototype_value_of(mut vm VM) !Value {
	return this_number_value(mut vm, vm.this_value())
}
