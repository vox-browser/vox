// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the remaining concrete WebIDL abstract operations. Realm and
// script-stack preparation are embedder responsibilities; completion/value
// transformations are preserved at this typed boundary.
module webidl

import math
import strconv

pub enum EnforceRange {
	no
	yes
}

pub enum Clamp {
	no
	yes
}

pub fn clean_up_on_return(value Value) Value {
	return value
}

pub fn to_utf16_string(value Value) ![]u16 {
	text := to_string(value)!
	mut result := []u16{}
	for code_point in text.runes() {
		point := u32(code_point)
		if point <= 0xffff {
			result << u16(point)
		} else {
			scalar := point - 0x10000
			result << u16(0xd800 + (scalar >> 10))
			result << u16(0xdc00 + (scalar & 0x3ff))
		}
	}
	return result
}

pub fn to_utf16_usv_string(value Value) ![]u16 {
	// V strings contain Unicode scalar values, so to_utf16_string necessarily
	// produces a well-formed UTF-16 sequence.
	return to_utf16_string(value)
}

pub fn invoke_callback_impl(callback CallbackType, this_argument ?Value, arguments []Value) !Value {
	return callback.callback(this_argument or { undefined_value() }, arguments)
}

pub fn invoke_promise_callback(callback CallbackType, this_argument ?Value, arguments []Value) &Promise {
	result := invoke_callback_impl(callback, this_argument, arguments) or {
		return create_rejected_promise(string_value(err.msg()))
	}
	return create_resolved_promise(result)
}

pub fn integer_part(number f64) f64 {
	result := math.floor(math.abs(number))
	return if number < 0 { -result } else { result }
}

fn value_to_number(value Value) !f64 {
	return match value.kind {
		.number { value.number_value }
		.boolean { if value.boolean_value { f64(1) } else { f64(0) } }
		.null_ { f64(0) }
		.undefined { math.nan() }
		.string_ { strconv.atof64(value.string_value.trim_space()) or { math.nan() } }
		else { return error('TypeError: value cannot be converted to a number') }
	}
}

fn round_ties_to_even(number f64) f64 {
	lower := math.floor(number)
	fraction := number - lower
	if fraction < 0.5 {
		return lower
	}
	if fraction > 0.5 {
		return lower + 1
	}
	return if i64(lower) % 2 == 0 { lower } else { lower + 1 }
}

// The C++ operation is templated on the target integer type. Supplying its bit
// length and signedness keeps the complete algorithm available without hiding
// the target type behind the JS engine.
pub fn convert_to_int(value Value, bit_length int, is_signed bool, enforce_range EnforceRange, clamp Clamp) !f64 {
	if bit_length !in [8, 16, 32, 64] {
		return error('TypeError: unsupported WebIDL integer bit length')
	}
	mut upper_bound := if bit_length == 64 {
		f64(9_007_199_254_740_991)
	} else if is_signed {
		math.pow(2, bit_length - 1) - 1
	} else {
		math.pow(2, bit_length) - 1
	}
	mut lower_bound := if bit_length == 64 {
		if is_signed { -upper_bound } else { f64(0) }
	} else if is_signed {
		-math.pow(2, bit_length - 1)
	} else {
		f64(0)
	}
	mut number := value_to_number(value)!
	if number == -0.0 {
		number = 0
	}
	if enforce_range == .yes {
		if math.is_nan(number) || math.is_inf(number, 0) {
			return error('TypeError: Number is NaN or Infinity')
		}
		number = integer_part(number)
		if number < lower_bound || number > upper_bound {
			return error('TypeError: Number is outside the allowed range')
		}
		return number
	}
	if clamp == .yes && !math.is_nan(number) {
		number = math.min(math.max(number, lower_bound), upper_bound)
		return round_ties_to_even(number)
	}
	if math.is_nan(number) || number == 0 || math.is_inf(number, 0) {
		return 0
	}
	number = integer_part(number)
	modulus := math.pow(2, bit_length)
	number = math.mod(number, modulus)
	if number < 0 {
		number += modulus
	}
	if is_signed && number >= math.pow(2, bit_length - 1) {
		return number - modulus
	}
	return number
}

pub fn lists_contain_same_elements(cached []u64, elements []u64) bool {
	if cached.len != elements.len {
		return false
	}
	for element in elements {
		if element !in cached {
			return false
		}
	}
	return true
}

pub fn convert_ecmascript_type_to_idl_value(value Value, _ &Type) Value {
	// This is deliberately a pass-through upstream as well; generated bindings
	// perform the concrete conversion.
	return value
}

pub fn has_overload_with_argument_type_or_subtype_matching(overloads EffectiveOverloadSet, argument_index int, type_names []string) bool {
	for item in overloads.items_ {
		if argument_index < 0 || argument_index >= item.types.len {
			continue
		}
		type_ := item.types[argument_index]
		if type_.name() in type_names {
			return true
		}
		if type_.is_union() {
			for member in type_.as_union().flattened_member_types() {
				if member.name() in type_names {
					return true
				}
			}
		}
	}
	return false
}
