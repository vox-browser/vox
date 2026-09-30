module libjs

import math
import math.big
import strconv

// Primitive-value paths from Runtime/Value.cpp. Object coercion requires the
// pending callable/accessor object model; it fails explicitly rather than using
// the debugging Value.str() representation as an ECMAScript conversion.
pub fn (value Value) to_primitive(mut vm VM) !Value {
	if value.tag in [.object, .accessor, .empty] {
		return vm.throw_error(.internal_error, 'ToPrimitive requires the callable object model')
	}
	return value
}

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
		return strconv.atof64(integer.str()) or { return math.nan() }
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
	return strconv.atof64(source) or { return math.nan() }
}

// 7.1.4 ToNumber.
pub fn (value Value) to_number(mut vm VM) !Value {
	return match value.tag {
		.int32, .double { value }
		.undefined { Value.from_f64(math.nan()) }
		.null { Value.from_i32(0) }
		.boolean { Value.from_i32(if value.as_bool() { 1 } else { 0 }) }
		.string { Value.from_f64(string_to_number(value.as_string().utf16)) }
		.symbol { return vm.throw_error_type(.type_error, .convert, 'symbol', 'number') }
		.bigint { return vm.throw_error_type(.type_error, .convert, 'BigInt', 'number') }
		else { return vm.throw_error(.internal_error, 'Object ToNumber is not translated yet') }
	}
}

pub fn (value Value) to_numeric(mut vm VM) !Value {
	if value.is_bigint() {
		return vm.throw_error(.internal_error, 'BigInt arithmetic is not translated yet')
	}
	return value.to_number(mut vm)
}

// 7.1.17 ToString's primitive paths. Preserve UTF-16 identity during concatenation.
pub fn (value Value) to_primitive_string(mut vm VM) !&PrimitiveString {
	if value.is_string() { return value.as_string() }
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
		.symbol {
			return vm.throw_error_type(.type_error, .convert, 'symbol', 'string')
		}
		else {
			return vm.throw_error(.internal_error, 'Object/BigInt ToString is not translated yet')
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
	x := left.to_numeric(mut vm)!.number
	y := right.to_numeric(mut vm)!.number
	return Value.from_f64(x + y)
}

pub fn sub(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!.number
	y := rhs.to_numeric(mut vm)!.number
	return Value.from_f64(x - y)
}

pub fn mul(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!.number
	y := rhs.to_numeric(mut vm)!.number
	return Value.from_f64(x * y)
}

pub fn div(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!.number
	y := rhs.to_numeric(mut vm)!.number
	return Value.from_f64(x / y)
}

pub fn mod_(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!.number
	y := rhs.to_numeric(mut vm)!.number
	return Value.from_f64(math.fmod(x, y))
}

pub fn exp(mut vm VM, lhs Value, rhs Value) !Value {
	x := lhs.to_numeric(mut vm)!.number
	y := rhs.to_numeric(mut vm)!.number
	// Number::exponentiate differs from libc pow for abs(x)==1 and infinite y.
	if y == 0 { return Value.from_i32(1) }
	if math.abs(x) == 1 && math.is_inf(y, 0) { return Value.from_f64(math.nan()) }
	return Value.from_f64(math.pow(x, y))
}

pub fn unary_minus(mut vm VM, value Value) !Value {
	number := value.to_numeric(mut vm)!.number
	return Value.from_f64(-number)
}

// 7.2.15 IsStrictlyEqual: string content, number equality, and cell identity.
pub fn is_strictly_equal(lhs Value, rhs Value) bool {
	if lhs.is_number() && rhs.is_number() { return lhs.number == rhs.number }
	if lhs.tag != rhs.tag { return false }
	return match lhs.tag {
		.undefined, .null { true }
		.boolean { lhs.number == rhs.number }
		.string { lhs.as_string().utf16 == rhs.as_string().utf16 }
		.symbol, .object { lhs.cell == rhs.cell }
		else { false }
	}
}

pub enum ComparisonResult {
	less
	greater
	equal
	unordered
}

// IsLessThan's primitive paths. UTF-16 ordering differs from scalar ordering.
pub fn compare_primitive_values(mut vm VM, lhs Value, rhs Value) !ComparisonResult {
	left := lhs.to_primitive(mut vm)!
	right := rhs.to_primitive(mut vm)!
	if left.is_string() && right.is_string() {
		a := left.as_string().utf16
		b := right.as_string().utf16
		if a == b { return .equal }
		return if a < b { ComparisonResult.less } else { ComparisonResult.greater }
	}
	x := left.to_numeric(mut vm)!.number
	y := right.to_numeric(mut vm)!.number
	if math.is_nan(x) || math.is_nan(y) { return .unordered }
	if x == y { return .equal }
	return if x < y { ComparisonResult.less } else { ComparisonResult.greater }
}

// Primitive branch of IsLooselyEqual; unsupported object conversions still throw.
pub fn is_loosely_equal(mut vm VM, lhs Value, rhs Value) !bool {
	if lhs.tag == rhs.tag || (lhs.is_number() && rhs.is_number()) {
		return is_strictly_equal(lhs, rhs)
	}
	if lhs.is_nullish() || rhs.is_nullish() { return lhs.is_nullish() && rhs.is_nullish() }
	if lhs.is_boolean() { return is_loosely_equal(mut vm, lhs.to_number(mut vm)!, rhs) }
	if rhs.is_boolean() { return is_loosely_equal(mut vm, lhs, rhs.to_number(mut vm)!) }
	if lhs.is_number() && rhs.is_string() { return is_strictly_equal(lhs, rhs.to_number(mut vm)!) }
	if lhs.is_string() && rhs.is_number() { return is_strictly_equal(lhs.to_number(mut vm)!, rhs) }
	if lhs.is_object() || rhs.is_object() || lhs.is_bigint() || rhs.is_bigint() {
		return vm.throw_error(.internal_error,
			'Object/BigInt equality conversion is not translated yet')
	}
	return false
}
