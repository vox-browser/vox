module libjs

import math

// Runtime/Value.cpp::ToInt16/ToUint16/ToInt8/ToUint8/ToUint8Clamp.
pub fn (value Value) to_i16(mut vm VM) !i16 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) || number == 0 { return 0 }
	mut integer := math.floor(math.abs(number))
	if math.signbit(number) { integer = -integer }
	mut result := math.fmod(integer, 65536.0)
	if result < 0 { result += 65536.0 }
	if result >= 32768 { result -= 65536.0 }
	return i16(result)
}

pub fn (value Value) to_u16(mut vm VM) !u16 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) || number == 0 { return 0 }
	mut integer := math.floor(math.abs(number))
	if math.signbit(number) { integer = -integer }
	mut result := math.fmod(integer, 65536.0)
	if result < 0 { result += 65536.0 }
	return u16(result)
}

pub fn (value Value) to_i8(mut vm VM) !i8 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) || number == 0 { return 0 }
	mut integer := math.floor(math.abs(number))
	if math.signbit(number) { integer = -integer }
	mut result := math.fmod(integer, 256.0)
	if result < 0 { result += 256.0 }
	if result >= 128 { result -= 256.0 }
	return i8(result)
}

pub fn (value Value) to_u8(mut vm VM) !u8 {
	if value.tag == .int32 { return u8(value.as_i32() & 255) }
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || math.is_inf(number, 0) || number == 0 { return 0 }
	mut integer := math.floor(math.abs(number))
	if math.signbit(number) { integer = -integer }
	mut result := math.fmod(integer, 256.0)
	if result < 0 { result += 256.0 }
	return u8(result)
}

pub fn (value Value) to_u8_clamp(mut vm VM) !u8 {
	number := value.to_number(mut vm)!.number
	if math.is_nan(number) || number <= 0 { return 0 }
	if number >= 255 { return 255 }
	integer := math.floor(number)
	if integer + 0.5 < number { return u8(integer + 1) }
	if number < integer + 0.5 { return u8(integer) }
	if math.fmod(integer, 2) == 1 { return u8(integer + 1) }
	return u8(integer)
}
