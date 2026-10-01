module libjs

import math.big

// Runtime/BigIntPrototype.cpp::this_bigint_value. Only the receiver's own
// primitive or BigIntObject slot qualifies; prototype branding and coercion
// hooks do not participate.
fn this_bigint_value(mut vm VM, value Value) !&BigInt {
	if value.is_bigint() { return value.as_bigint() }
	if value.is_object() {
		if wrapper := value.as_object().bigint_object { return wrapper.bigint }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'BigInt')
}

// LibCrypto/BigInt/SignedBigInteger.cpp::to_base_utf16, retaining its zero
// branch and lowercase ASCII-to-UTF-16 construction. math.big.radix_str is
// the mp_radix_size/mp_to_radix substrate; V allocation failures are not
// recoverable through LibCrypto's ErrorOr allocation boundary.
fn big_integer_to_base_utf16(integer big.Integer, radix u16) Utf16String {
	assert radix >= 2 && radix <= 36
	if integer.signum == 0 { return utf16_string('0') }
	text := integer.radix_str(u32(radix))
	mut builder := []u16{cap: text.len}
	for byte in text.bytes() {
		mut character := byte
		if character >= u8(`A`) && character <= u8(`Z`) {
			character += u8(`a` - `A`)
		}
		builder << u16(character)
	}
	return Utf16String{
		data: builder
	}
}

// Runtime/BigIntPrototype.cpp::to_string.
pub fn bigint_prototype_to_string(mut vm VM) !Value {
	bigint := this_bigint_value(mut vm, vm.this_value())!
	mut radix := f64(10)
	if !vm.argument(0).is_undefined() {
		radix = vm.argument(0).to_integer_or_infinity(mut vm)!
		if radix < 2 || radix > 36 {
			return vm.throw_error_type(.range_error, .invalid_radix)
		}
	}
	return Value.from_string(vm.create_string(big_integer_to_base_utf16(bigint.big_integer,
		u16(radix))))
}

// Runtime/BigIntPrototype.cpp::value_of.
pub fn bigint_prototype_value_of(mut vm VM) !Value {
	return Value.from_bigint(this_bigint_value(mut vm, vm.this_value())!)
}
