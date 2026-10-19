module libjs

import math
import math.big
import strconv

// Runtime/Value.cpp numeric, string, and equality operations. Object conversions
// use the ToPrimitive algorithms in value_coercion.v.

fn is_number_whitespace(character u16) bool {
	return
		character in [u16(9), 10, 11, 12, 13, 32, 0xa0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff]
		|| (character >= 0x2000 && character <= 0x200a)
}

// 7.1.4.1.1 StringToNumber, including the complete ECMAScript whitespace set.
pub fn string_to_number(text Utf16String) f64 {
	mut start := 0
	mut end := text.data.len
	for start < end && is_number_whitespace(text.data[start]) {
		start++
	}
	for end > start && is_number_whitespace(text.data[end - 1]) {
		end--
	}
	if start == end { return 0.0 }
	source := encode_utf16(text.data[start..end], false)
	if source in ['Infinity', '+Infinity'] { return math.inf(1) }
	if source == '-Infinity' { return math.inf(-1) }
	mut radix := u32(10)
	if source.len > 2 && source[0] == `0` {
		radix = match source[1] {
			`b`, `B` { 2 }
			`o`, `O` { 8 }
			`x`, `X` { 16 }
			else { 10 }
		}
	}
	if radix != 10 {
		for character in source[2..].bytes() {
			digit := match character {
				`0`...`9` { u32(character - `0`) }
				`a`...`f` { u32(character - `a` + 10) }
				`A`...`F` { u32(character - `A` + 10) }
				else { u32(99) }
			}

			if digit >= radix { return math.nan() }
		}
		integer := big.integer_from_radix(source[2..], radix) or { return math.nan() }
		return atof64_rounding_overflow(integer.str()) or { return math.nan() }
	}
	// atof64 accepts incomplete exponents; validate StringNumericLiteral first.
	mut cursor := 0
	if source[cursor] in [`+`, `-`] { cursor++ }
	mut digits := 0
	for cursor < source.len && source[cursor].is_digit() {
		cursor++
		digits++
	}
	if cursor < source.len && source[cursor] == `.` {
		cursor++
		for cursor < source.len && source[cursor].is_digit() {
			cursor++
			digits++
		}
	}
	if digits == 0 { return math.nan() }
	if cursor < source.len && source[cursor] in [`e`, `E`] {
		cursor++
		if cursor < source.len && source[cursor] in [`+`, `-`] { cursor++ }
		exponent_start := cursor
		for cursor < source.len && source[cursor].is_digit() {
			cursor++
		}
		if cursor == exponent_start { return math.nan() }
	}
	if cursor != source.len { return math.nan() }
	return atof64_rounding_overflow(source) or { return math.nan() }
}

// Upstream's decimal parsers round a magnitude beyond the f64 range to an
// infinity. Current V's strconv.atof64 reports it as an error instead (the
// compatibility compiler's returned the infinity); restore the rounding.
fn atof64_rounding_overflow(text string) !f64 {
	value := strconv.atof64(text) or {
		if !err.msg().ends_with('value out of range') {
			return err
		}
		math.inf(if text.starts_with('-') { -1 } else { 1 })
	}
	return value
}

// 7.1.4 ToNumber.
pub fn (value Value) to_number(mut vm VM) !Value {
	return match value.tag {
		.int32, .double {
			value
		}
		.undefined {
			Value.from_f64(math.nan())
		}
		.null {
			Value.from_i32(0)
		}
		.boolean {
			Value.from_i32(if value.as_bool() { 1 } else { 0 })
		}
		.string {
			Value.from_f64(string_to_number(value.as_string().utf16))
		}
		.symbol {
			return vm.throw_error_type(.type_error, .convert, 'symbol', 'number')
		}
		.bigint {
			return vm.throw_error_type(.type_error, .convert, 'BigInt', 'number')
		}
		.object {
			primitive := value.to_primitive_with_hint(mut vm, .number)!
			return primitive.to_number(mut vm)
		}
		else {
			return vm.throw_error(.internal_error, 'ToNumber received an internal value')
		}
	}
}

pub fn (value Value) to_numeric(mut vm VM) !Value {
	primitive := value.to_primitive_with_hint(mut vm, .number)!
	if primitive.is_bigint() { return primitive }
	return primitive.to_number(mut vm)
}

// 7.1.17 ToString's primitive paths. Preserve UTF-16 identity during concatenation.
pub fn (value Value) to_primitive_string(mut vm VM) !&PrimitiveString {
	if value.is_string() { return value.as_string() }
	if value.is_object() {
		primitive := value.to_primitive_with_hint(mut vm, .string)!
		return primitive.to_primitive_string(mut vm)
	}
	text := match value.tag {
		.undefined {
			'undefined'
		}
		.null {
			'null'
		}
		.boolean {
			if value.as_bool() { 'true' } else { 'false' }
		}
		.int32, .double {
			format_f64_value(value.number)
		}
		.bigint {
			value.as_bigint().big_integer.str()
		}
		.symbol {
			return vm.throw_error_type(.type_error, .convert, 'symbol', 'string')
		}
		else {
			return vm.throw_error(.internal_error, 'ToString received an internal value')
		}
	}

	return vm.create_string_from_str(text)
}

// 7.1.6/7.1.7 ToInt32/ToUint32. Conversion happens modulo 2^32, before casting.
pub fn (value Value) to_u32(mut vm VM) !u32 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) || number == 0.0 { return 0 }
	mut result := math.fmod(math.trunc(number), 4294967296.0)
	if result < 0 { result += 4294967296.0 }
	return u32(result)
}

pub fn (value Value) to_i32(mut vm VM) !i32 {
	unsigned := value.to_u32(mut vm)!
	return if unsigned >= 0x80000000 { i32(i64(unsigned) - 4294967296) } else { i32(unsigned) }
}

pub fn add(mut vm VM, lhs Value, rhs Value) !Value {
	left := lhs.to_primitive(mut vm)!
	right := rhs.to_primitive(mut vm)!
	if left.is_string() || right.is_string() {
		left_string := left.to_primitive_string(mut vm)!
		right_string := right.to_primitive_string(mut vm)!
		mut units := left_string.utf16.data.clone()
		units << right_string.utf16.data
		return Value.from_string(vm.create_string(Utf16String{ data: units }))
	}
	return numeric_binary_operation(mut vm, left, right, .add)
}

pub fn sub(mut vm VM, lhs Value, rhs Value) !Value {
	return numeric_binary_operation(mut vm, lhs, rhs, .sub)
}

pub fn mul(mut vm VM, lhs Value, rhs Value) !Value {
	return numeric_binary_operation(mut vm, lhs, rhs, .mul)
}

pub fn div(mut vm VM, lhs Value, rhs Value) !Value {
	return numeric_binary_operation(mut vm, lhs, rhs, .div)
}

pub fn mod_(mut vm VM, lhs Value, rhs Value) !Value {
	return numeric_binary_operation(mut vm, lhs, rhs, .mod_)
}

pub fn exp(mut vm VM, lhs Value, rhs Value) !Value {
	return numeric_binary_operation(mut vm, lhs, rhs, .exp)
}

// Runtime/Value.cpp::ApplyStringOrNumericBinaryOperator. Dispatch both numeric
// types only after converting the left and right operands, in that order.
fn numeric_binary_operation(mut vm VM, lhs Value, rhs Value, op OpCode) !Value {
	x := lhs.to_numeric(mut vm)!
	y := rhs.to_numeric(mut vm)!
	if x.is_number() && y.is_number() {
		return Value.from_f64(match op {
			.add { x.number + y.number }
			.sub { x.number - y.number }
			.mul { x.number * y.number }
			.div { x.number / y.number }
			.mod_ { math.fmod(x.number, y.number) }
			else { number_exponentiate(x.number, y.number) }
		})
	}
	if x.is_bigint() && y.is_bigint() {
		a := x.as_bigint().big_integer
		b := y.as_bigint().big_integer
		if op in [.div, .mod_] && b.signum == 0 {
			return vm.throw_error_type(.range_error, .division_by_zero)
		}
		if op == .exp {
			if b.signum < 0 { return vm.throw_error_type(.range_error, .negative_exponent) }
			if b.bit_len() > 32 { return vm.throw_error_type(.range_error, .big_int_size_exceeded) }
		}
		integer := match op {
			.add { a + b }
			.sub { a - b }
			.mul { a * b }
			.div { a / b }
			.mod_ { a % b }
			else { a.pow(u32(big_integer_to_u64(b))) }
		}

		return Value.from_bigint(BigInt.create(integer))
	}
	name := match op {
		.add { 'addition' }
		.sub { 'subtraction' }
		.mul { 'multiplication' }
		.div { 'division' }
		.mod_ { 'modulo' }
		else { 'exponentiation' }
	}

	return vm.throw_error_type(.type_error, .big_int_bad_operator_other_type, name)
}

// Runtime/Value.cpp::Number::exponentiate. The ordered special cases matter:
// libc pow alone returns different results for non-integral powers of -Infinity
// and -0, and for |base| == 1 with an infinite exponent.
fn number_exponentiate(base f64, exponent f64) f64 {
	if math.is_nan(exponent) { return math.nan() }
	if exponent == 0 { return 1 }
	if math.is_nan(base) { return math.nan() }
	if math.is_inf(base, 1) { return if exponent > 0 { math.inf(1) } else { 0.0 }
	 }
	odd := !math.is_inf(exponent, 0) && math.trunc(exponent) == exponent
		&& math.fmod(exponent, 2) != 0
	if math.is_inf(base, -1) {
		if exponent > 0 { return if odd { math.inf(-1) } else { math.inf(1) }
		 }
		return if odd { -0.0 } else { 0.0 }
	}
	if base == 0 {
		if exponent > 0 { return if math.signbit(base) && odd { -0.0 } else { 0.0 }
		 }
		return if math.signbit(base) && odd { math.inf(-1) } else { math.inf(1) }
	}
	if math.is_inf(exponent, 0) {
		absolute := math.abs(base)
		if absolute == 1 { return math.nan() }
		return if (absolute > 1) == (exponent > 0) { math.inf(1) } else { 0.0 }
	}
	if base < 0 && math.trunc(exponent) != exponent { return math.nan() }
	return math.pow(base, exponent)
}

pub fn unary_minus(mut vm VM, value Value) !Value {
	numeric := value.to_numeric(mut vm)!
	if numeric.is_number() { return Value.from_f64(-numeric.number) }
	return Value.from_bigint(BigInt.create(numeric.as_bigint().big_integer.neg()))
}

pub fn bitwise_not(mut vm VM, value Value) !Value {
	numeric := value.to_numeric(mut vm)!
	if numeric.is_number() { return Value.from_i32(~numeric.to_i32(mut vm)!) }
	return Value.from_bigint(BigInt.create(numeric.as_bigint().big_integer.bitwise_com()))
}

pub fn bitwise_and(mut vm VM, lhs Value, rhs Value) !Value {
	return bitwise_binary_operation(mut vm, lhs, rhs, .bitwise_and)
}

pub fn bitwise_or(mut vm VM, lhs Value, rhs Value) !Value {
	return bitwise_binary_operation(mut vm, lhs, rhs, .bitwise_or)
}

pub fn bitwise_xor(mut vm VM, lhs Value, rhs Value) !Value {
	return bitwise_binary_operation(mut vm, lhs, rhs, .bitwise_xor)
}

fn bitwise_binary_operation(mut vm VM, lhs Value, rhs Value, op OpCode) !Value {
	x := lhs.to_numeric(mut vm)!
	y := rhs.to_numeric(mut vm)!
	if x.is_number() && y.is_number() {
		a := x.to_i32(mut vm)!
		b := y.to_i32(mut vm)!
		return Value.from_i32(match op {
			.bitwise_and { a & b }
			.bitwise_or { a | b }
			else { a ^ b }
		})
	}
	if x.is_bigint() && y.is_bigint() {
		a := x.as_bigint().big_integer
		b := y.as_bigint().big_integer
		// SignedBigInteger::bitwise_xor = bitwise_or - bitwise_and.
		integer := if op == .bitwise_xor {
			big_integer_bitwise(a, b, false) - big_integer_bitwise(a, b, true)
		} else {
			big_integer_bitwise(a, b, op == .bitwise_and)
		}
		return Value.from_bigint(BigInt.create(integer))
	}
	name := match op {
		.bitwise_and { 'bitwise AND' }
		.bitwise_or { 'bitwise OR' }
		else { 'bitwise XOR' }
	}

	return vm.throw_error_type(.type_error, .big_int_bad_operator_other_type, name)
}

pub fn left_shift(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!
	y := rhs.to_numeric(mut vm)!
	if x.is_number() && y.is_number() {
		a := u32(x.to_i32(mut vm)!)
		b := y.to_u32(mut vm)! & 31
		return Value.from_i32(i32(a << b))
	}
	if x.is_bigint() && y.is_bigint() {
		a := x.as_bigint().big_integer
		b := y.as_bigint().big_integer
		if b.bit_len() > 32 { return vm.throw_error_type(.range_error, .big_int_size_exceeded) }
		factor := big.integer_from_int(2).pow(u32(big_integer_to_u64(b.abs())))
		if b.signum < 0 {
			quotient, remainder := a.div_mod(factor)
			integer := if remainder.signum == 0 || a.signum >= 0 {
				quotient
			} else {
				quotient - big.integer_from_int(1)
			}
			return Value.from_bigint(BigInt.create(integer))
		}
		return Value.from_bigint(BigInt.create(a * factor))
	}
	return vm.throw_error_type(.type_error, .big_int_bad_operator_other_type, 'left-shift')
}

pub fn right_shift(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!
	y := rhs.to_numeric(mut vm)!
	if x.is_number() && y.is_number() {
		a := x.to_i32(mut vm)!
		b := y.to_u32(mut vm)! & 31
		return Value.from_i32(a >> b)
	}
	if x.is_bigint() && y.is_bigint() { return left_shift(mut vm, x, unary_minus(mut vm, y)!) }
	return vm.throw_error_type(.type_error, .big_int_bad_operator_other_type, 'right-shift')
}

pub fn unsigned_right_shift(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!
	y := rhs.to_numeric(mut vm)!
	if x.is_number() && y.is_number() {
		a := x.to_u32(mut vm)!
		b := y.to_u32(mut vm)! & 31
		return Value.from_f64(f64(a >> b))
	}
	return vm.throw_error_type(.type_error, .big_int_bad_operator, 'unsigned right-shift')
}

// 7.2.15 IsStrictlyEqual: string content, number equality, and cell identity.
pub fn is_strictly_equal(lhs Value, rhs Value) bool {
	if lhs.is_number() && rhs.is_number() { return lhs.number == rhs.number }
	if lhs.tag != rhs.tag { return false }
	return match lhs.tag {
		.undefined, .null { true }
		.boolean { lhs.number == rhs.number }
		.string { lhs.as_string().utf16 == rhs.as_string().utf16 }
		.bigint { lhs.as_bigint().big_integer == rhs.as_bigint().big_integer }
		.symbol, .object { lhs.cell == rhs.cell }
		else { false }
	}
}

// Runtime/Value.cpp::in. Validate the right operand before ToPropertyKey can
// invoke coercion hooks on the left operand.
pub fn in_operator(mut vm VM, lhs Value, rhs Value) !Value {
	if !rhs.is_object() { return vm.throw_error_type(.type_error, .in_operator_with_object) }
	key := lhs.to_property_key(mut vm)!
	return Value.from_bool(rhs.as_object().has_property(key))
}

pub enum ComparisonResult {
	less
	greater
	equal
	unordered
}

// IsLessThan's primitive paths. UTF-16 ordering differs from scalar ordering.
pub fn compare_primitive_values(mut vm VM, lhs Value, rhs Value) !ComparisonResult {
	left := lhs.to_primitive_with_hint(mut vm, .number)!
	right := rhs.to_primitive_with_hint(mut vm, .number)!
	if left.is_string() && right.is_string() {
		a := left.as_string().utf16
		b := right.as_string().utf16
		if a == b { return .equal }
		return if a < b { ComparisonResult.less } else { ComparisonResult.greater }
	}
	mut x := left
	mut y := right
	if x.is_bigint() && y.is_string() {
		parsed := string_to_bigint(y.as_string().utf16) or { return .unordered }
		y = Value.from_bigint(parsed)
	} else if x.is_string() && y.is_bigint() {
		parsed := string_to_bigint(x.as_string().utf16) or { return .unordered }
		x = Value.from_bigint(parsed)
	}
	x = x.to_numeric(mut vm)!
	y = y.to_numeric(mut vm)!
	if x.is_bigint() && y.is_bigint() {
		a := x.as_bigint().big_integer
		b := y.as_bigint().big_integer
		if a == b { return .equal }
		return if a < b { .less } else { .greater }
	}
	if x.is_bigint() { return compare_big_integer_to_double(x.as_bigint().big_integer, y.number) }
	if y.is_bigint() {
		return reverse_comparison(compare_big_integer_to_double(y.as_bigint().big_integer, x.number))
	}
	if math.is_nan(x.number) || math.is_nan(y.number) { return .unordered }
	if x.number == y.number { return .equal }
	return if x.number < y.number { ComparisonResult.less } else { ComparisonResult.greater }
}

// Runtime/Value.cpp::IsLooselyEqual, including object and BigInt coercion.
pub fn is_loosely_equal(mut vm VM, lhs Value, rhs Value) !bool {
	if lhs.tag == rhs.tag || (lhs.is_number() && rhs.is_number()) {
		return is_strictly_equal(lhs, rhs)
	}
	if lhs.is_nullish() || rhs.is_nullish() { return lhs.is_nullish() && rhs.is_nullish() }
	if lhs.is_boolean() { return is_loosely_equal(mut vm, lhs.to_number(mut vm)!, rhs) }
	if rhs.is_boolean() { return is_loosely_equal(mut vm, lhs, rhs.to_number(mut vm)!) }
	if lhs.is_number() && rhs.is_string() { return is_strictly_equal(lhs, rhs.to_number(mut vm)!) }
	if lhs.is_string() && rhs.is_number() { return is_strictly_equal(lhs.to_number(mut vm)!, rhs) }
	if lhs.is_bigint() && rhs.is_string() {
		parsed := string_to_bigint(rhs.as_string().utf16) or { return false }
		return is_strictly_equal(lhs, Value.from_bigint(parsed))
	}
	if lhs.is_string() && rhs.is_bigint() { return is_loosely_equal(mut vm, rhs, lhs) }
	if (lhs.is_bigint() && rhs.is_number()) || (lhs.is_number() && rhs.is_bigint()) {
		integer := if lhs.is_bigint() {
			lhs.as_bigint().big_integer
		} else {
			rhs.as_bigint().big_integer
		}
		number := if lhs.is_number() { lhs.number } else { rhs.number }
		return compare_big_integer_to_double(integer, number) == .equal
	}
	if lhs.is_object() { return is_loosely_equal(mut vm, lhs.to_primitive(mut vm)!, rhs) }
	if rhs.is_object() { return is_loosely_equal(mut vm, lhs, rhs.to_primitive(mut vm)!) }
	return false
}
