module libjs

import math.big

// LibCrypto/BigInt/SignedBigInteger.cpp::mod_power_of_two. Preserve the
// pinned arm64 LibTomMath configuration's 60-bit digit fast path even though
// the arithmetic substrate is V math.big. Width overflow maps ENOMEM through
// Runtime/Completion.h::TRY_OR_THROW_OOM to the preallocated VM message.
fn big_integer_mod_power_of_two(mut vm VM, integer big.Integer, width u64) !big.Integer {
	if width == 0 { return big.integer_from_int(0) }
	used_bits := ((u64(integer.bit_len()) + 59) / 60) * 60
	if integer.signum >= 0 && used_bits <= width { return integer }
	if width > 2147483647 {
		return vm.throw_error_utf16(.internal_error, vm.error_message(.out_of_memory))
	}
	mut result := big_integer_mod_2d(integer, int(width))
	if result.signum >= 0 { return result }
	modulus := big.integer_from_int(1).left_shift(u32(width))
	result = result + modulus
	return result
}

// LibTomMath 1.3.0 bn_mp_mod_2d.c, using 8-bit magnitude digits. Copy the
// input, clear digits outside the modulus, mask its partial digit, and clamp
// through integer_from_bytes. Its signed remainder precedes LibCrypto's
// addition of the modulus; a negative exact multiple therefore remains zero.
fn big_integer_mod_2d(integer big.Integer, width int) big.Integer {
	if width <= 0 { return big.integer_from_int(0) }
	bytes, _ := integer.bytes()
	if width >= bytes.len * 8 { return integer }
	mut result := bytes.clone()
	retained := width / 8 + if width % 8 == 0 { 0 } else { 1 }
	for index in 0 .. result.len - retained {
		result[index] = 0
	}
	result[result.len - width / 8 - 1] &= u8((u16(1) << u32(width % 8)) - 1)
	return big.integer_from_bytes(result, big.IntegerConfig{ signum: integer.signum })
}

// LibCrypto/BigInt/UnsignedBigInteger.cpp::bitwise_not_fill_to_one_based_index.
// Translate the mp_2expt/sub_d/and/xor sequence through the existing math.big
// substrate. Canonicalize its magnitude just as the LibTomMath calls clamp it.
fn big_integer_not_fill(mut vm VM, integer big.Integer, width u64) !big.Integer {
	if width == 0 { return big.integer_from_int(0) }
	if width > 2147483647 {
		return vm.throw_error_utf16(.internal_error, vm.error_message(.out_of_memory))
	}
	mask := big.integer_from_int(1).left_shift(u32(width)) - big.integer_from_int(1)
	temp := mask.bitwise_and(integer)
	result := temp.bitwise_xor(mask)
	bytes, _ := result.bytes()
	return big.integer_from_bytes(bytes, big.IntegerConfig{})
}

// Runtime/BigIntConstructor.cpp::as_int_n.
pub fn bigint_constructor_as_int_n(mut vm VM) !Value {
	bits := vm.argument(0).to_index(mut vm)!
	bigint := vm.argument(1).to_bigint(mut vm)!
	if bits == 0 { return Value.from_bigint(BigInt.create(big.integer_from_int(0))) }
	if bigint.big_integer.signum < 0 && u64(bigint.big_integer.bit_len()) < bits {
		return Value.from_bigint(bigint)
	}
	mod := big_integer_mod_power_of_two(mut vm, bigint.big_integer, bits)!
	if mod.signum == 0 { return Value.from_bigint(BigInt.create(big.integer_from_int(0))) }
	if u64(mod.bit_len()) >= bits {
		decoded := big_integer_not_fill(mut vm, mod, bits)! + big.integer_from_int(1)
		return Value.from_bigint(BigInt.create(decoded.neg()))
	}
	return Value.from_bigint(BigInt.create(mod))
}

// Runtime/BigIntConstructor.cpp::as_uint_n.
pub fn bigint_constructor_as_uint_n(mut vm VM) !Value {
	bits := vm.argument(0).to_index(mut vm)!
	bigint := vm.argument(1).to_bigint(mut vm)!
	mod := big_integer_mod_power_of_two(mut vm, bigint.big_integer, bits)!
	return Value.from_bigint(BigInt.create(mod))
}
