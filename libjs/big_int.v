module libjs

import math
import math.big

// Runtime/BigInt.{h,cpp}. V's arbitrary-precision integer is the storage and
// arithmetic substrate in place of LibCrypto's LibTomMath-backed integer.
@[heap]
pub struct BigInt {
pub:
	big_integer big.Integer
}

pub fn BigInt.create(integer big.Integer) &BigInt {
	return &BigInt{
		big_integer: integer
	}
}

pub fn (integer &BigInt) to_utf16_string() Utf16String {
	return utf16_string(integer.big_integer.str() + 'n')
}

// LibCrypto::SignedBigInteger(double) delegates to LibTomMath mp_set_double.
// Translate its IEEE-754 extraction and shifts; decimal formatting would lose
// integer bits for doubles beyond the exact decimal formatting range.
fn big_integer_from_double(number f64) big.Integer {
	bits := math.f64_bits(number)
	exponent := int((bits >> 52) & 0x7ff) - 1023 - 52
	fraction := (bits & ((u64(1) << 52) - 1)) | (u64(1) << 52)
	mut integer := big.integer_from_u64(fraction)
	integer = if exponent < 0 {
		integer.right_shift(u32(-exponent))
	} else {
		integer.left_shift(u32(exponent))
	}
	return if bits >> 63 != 0 { integer.neg() } else { integer }
}

// Runtime/BigInt.cpp::NumberToBigInt.
pub fn number_to_bigint(mut vm VM, number Value) !&BigInt {
	assert number.is_number()
	if math.is_nan(number.number) || math.is_inf(number.number, 0)
		|| math.trunc(number.number) != number.number {
		return vm.throw_error_type(.range_error, .big_int_from_non_integral)
	}
	return BigInt.create(big_integer_from_double(number.number))
}

// Runtime/Value.cpp::parse_bigint_text and StringToBigInt. Validate UTF-16
// before passing ASCII digits to the arithmetic substrate.
pub fn string_to_bigint(text Utf16String) ?&BigInt {
	mut start := 0
	mut end := text.data.len
	for start < end && is_number_whitespace(text.data[start]) {
		start++
	}
	for end > start && is_number_whitespace(text.data[end - 1]) {
		end--
	}
	// An empty StringIntegerLiteral is 0. Current V's math.big rejects an empty
	// digit string rather than returning zero.
	if start == end {
		return BigInt.create(big.integer_from_int(0))
	}
	mut base := u32(10)
	mut negative := false
	if end - start > 2 && text.data[start] == u16(`0`) {
		base = match text.data[start + 1] {
			u16(`b`), u16(`B`) { 2 }
			u16(`o`), u16(`O`) { 8 }
			u16(`x`), u16(`X`) { 16 }
			else { 10 }
		}
	}
	if base != 10 {
		start += 2
	} else if start < end && text.data[start] in [u16(`+`), u16(`-`)] {
		negative = text.data[start] == u16(`-`)
		start++
	}
	mut digits := []u8{cap: end - start}
	for unit in text.data[start..end] {
		digit := match unit {
			u16(`0`)...u16(`9`) { u32(unit - u16(`0`)) }
			u16(`a`)...u16(`f`) { u32(unit - u16(`a`) + 10) }
			u16(`A`)...u16(`F`) { u32(unit - u16(`A`) + 10) }
			else { u32(99) }
		}

		if digit >= base { return none }
		digits << u8(unit)
	}
	integer := big.integer_from_radix(digits.bytestr(), base) or { return none }
	return BigInt.create(if negative { integer.neg() } else { integer })
}

// Runtime/Value.cpp::ToBigInt.
pub fn (value Value) to_bigint(mut vm VM) !&BigInt {
	primitive := value.to_primitive_with_hint(mut vm, .number)!
	match primitive.tag {
		.bigint {
			return primitive.as_bigint()
		}
		.boolean {
			return BigInt.create(big.integer_from_int(if primitive.as_bool() { 1 } else { 0 }))
		}
		.string {
			return string_to_bigint(primitive.as_string().utf16) or {
				// Value's upstream error formatter uses the primitive string's
				// contents, without the quotes in our diagnostic Value.str().
				return vm.throw_error_type(.syntax_error, .big_int_invalid_value,
					primitive.as_string().str())
			}
		}
		else {
			type_name := if primitive.is_number() { 'number' } else { primitive.tag.str() }
			return vm.throw_error_type(.type_error, .convert, type_name, 'BigInt')
		}
	}
}

// LibCrypto::SignedBigInteger::to_u64 delegates to mp_get_u64, which retains
// the low 64 bits and negates modulo 2^64 for a negative input.
fn big_integer_to_u64(integer big.Integer) u64 {
	bytes, _ := integer.bytes()
	mut result := u64(0)
	start := if bytes.len > 8 {
		bytes.len - 8
	} else {
		0
	}
	for byte in bytes[start..] {
		result = (result << 8) | byte
	}
	return if integer.signum < 0 { ~result + 1 } else { result }
}

// LibCrypto::SignedBigInteger::to_i64, used by WebAssembly's ToBigInt
// conversion after it has obtained the actual arbitrary-precision integer.
pub fn (integer &BigInt) to_i64() i64 {
	return i64(big_integer_to_u64(integer.big_integer))
}

pub fn (value Value) to_bigint_uint64(mut vm VM) !u64 {
	integer := value.to_bigint(mut vm)!
	return big_integer_to_u64(integer.big_integer)
}

pub fn (value Value) to_bigint_int64(mut vm VM) !i64 {
	return i64(value.to_bigint_uint64(mut vm)!)
}

// LibCrypto::SignedBigInteger::{bitwise_and,bitwise_or} use LibTomMath's
// bn_mp_{and,or}.c. Translate that sign/magnitude <-> two's-complement loop
// with 8-bit digits rather than its configurable MP_DIGIT_BIT storage.
fn big_integer_bitwise(a big.Integer, b big.Integer, is_and bool) big.Integer {
	a_bytes, _ := a.bytes()
	b_bytes, _ := b.bytes()
	used := int(math.max(a_bytes.len, b_bytes.len)) + 1
	negative := if is_and { a.signum < 0 && b.signum < 0 } else { a.signum < 0 || b.signum < 0 }
	mut ac := u16(1)
	mut bc := u16(1)
	mut cc := u16(1)
	mut bytes := []u8{len: used}
	for i in 0 .. used {
		mut x := if i >= a_bytes.len { u8(0) } else { a_bytes[a_bytes.len - i - 1] }
		mut y := if i >= b_bytes.len { u8(0) } else { b_bytes[b_bytes.len - i - 1] }
		if a.signum < 0 {
			ac += u16(x) ^ u16(255)
			x = u8(ac & 255)
			ac >>= 8
		}
		if b.signum < 0 {
			bc += u16(y) ^ u16(255)
			y = u8(bc & 255)
			bc >>= 8
		}
		mut digit := if is_and { x & y } else { x | y }
		if negative {
			cc += u16(digit) ^ u16(255)
			digit = u8(cc & 255)
			cc >>= 8
		}
		bytes[used - i - 1] = digit
	}
	return big.integer_from_bytes(bytes, big.IntegerConfig{
		signum: if negative { -1 } else { 1 }
	})
}

fn reverse_comparison(result ComparisonResult) ComparisonResult {
	return match result {
		.less { .greater }
		.greater { .less }
		else { result }
	}
}

// LibCrypto::UnsignedBigInteger::compare_to_double: compare magnitude bit
// counts, then 32-bit words against the IEEE-754 significand with virtual zeros.
fn compare_big_integer_magnitude_to_double(integer big.Integer, number f64) ComparisonResult {
	if math.is_inf(number, 1) { return .less }
	if number == 0 { return if integer.signum == 0 { .equal } else { .greater }
	 }
	if integer.signum == 0 { return .less }
	bits := math.f64_bits(number)
	real_exponent := int((bits >> 52) & 0x7ff) - 1023
	if real_exponent < 0 { return .greater }
	integer_bits := integer.bit_len()
	double_bits := real_exponent + 1
	if integer_bits > double_bits { return .greater }
	if integer_bits < double_bits { return .less }
	mut mantissa := ((bits & ((u64(1) << 52) - 1)) | (u64(1) << 52)) << 11
	mut mantissa_bits_left := 53
	bytes, _ := integer.bytes()
	mut words := []u32{len: (bytes.len + 3) / 4}
	for i, byte in bytes {
		position := bytes.len - i - 1
		words[position / 4] |= u32(byte) << u32((position % 4) * 8)
	}
	mut next_word := words.len
	mut bits_in_word := (integer_bits - 1) % 32 + 1
	for next_word > 0 && mantissa_bits_left > 0 {
		num_bits := int(math.min(bits_in_word, mantissa_bits_left))
		mantissa_bits_left -= num_bits
		extracted := mantissa & (((u64(1) << u32(num_bits)) - 1) << u32(64 - num_bits))
		mut double_word := u32(extracted >> 32)
		mantissa <<= u32(num_bits)
		double_word >>= u32(32 - bits_in_word)
		if words[next_word - 1] < double_word { return .less }
		if words[next_word - 1] > double_word { return .greater }
		next_word--
		bits_in_word = 32
	}
	for next_word > 0 {
		if words[next_word - 1] != 0 { return .greater }
		next_word--
	}
	if mantissa_bits_left > 0 && mantissa != 0 { return .less }
	return .equal
}

// LibCrypto::SignedBigInteger::compare_to_double, with ComparisonResult ordered
// from the integer's perspective rather than the upstream double's perspective.
fn compare_big_integer_to_double(integer big.Integer, number f64) ComparisonResult {
	if math.is_nan(number) { return .unordered }
	integer_negative := integer.signum < 0
	number_negative := number < 0
	if integer_negative != number_negative {
		return if integer_negative { .less } else { .greater }
	}
	result := compare_big_integer_magnitude_to_double(integer, math.abs(number))
	return if number_negative { reverse_comparison(result) } else { result }
}
