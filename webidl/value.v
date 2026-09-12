// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Typed boundary used by the WebIDL translation in place of LibJS::Value.
module webidl

pub enum ValueKind {
	undefined
	null_
	boolean
	number
	bigint
	string_
	object
	sequence
	buffer_source
	callback
	platform_object
}

pub struct Value {
pub:
	kind                ValueKind
	boolean_value       bool
	number_value        f64
	bigint_value        i64
	string_value        string
	object_value        map[string]Value
	sequence_value      []Value
	buffer_value        ?BufferSource
	platform_interfaces []string
	opaque_id           u64
	frozen              bool
}

pub fn undefined_value() Value {
	return Value{
		kind: .undefined
	}
}

pub fn null_value() Value {
	return Value{
		kind: .null_
	}
}

pub fn boolean_value(value bool) Value {
	return Value{
		kind:          .boolean
		boolean_value: value
	}
}

pub fn number_value(value f64) Value {
	return Value{
		kind:         .number
		number_value: value
	}
}

pub fn bigint_value(value i64) Value {
	return Value{
		kind:         .bigint
		bigint_value: value
	}
}

pub fn string_value(value string) Value {
	return Value{
		kind:         .string_
		string_value: value
	}
}

pub fn object_value(value map[string]Value) Value {
	return Value{
		kind:         .object
		object_value: value
	}
}

pub fn object_value_with_id(value map[string]Value, opaque_id u64) Value {
	return Value{
		kind: .object
		object_value: value
		opaque_id: opaque_id
	}
}

pub fn sequence_value(value []Value) Value {
	return Value{
		kind:           .sequence
		sequence_value: value
	}
}

pub fn frozen_sequence_value_with_id(value []Value, opaque_id u64) Value {
	return Value{
		kind: .sequence
		sequence_value: value.clone()
		opaque_id: opaque_id
		frozen: true
	}
}

pub fn buffer_source_value(value BufferSource) Value {
	return Value{
		kind:         .buffer_source
		buffer_value: value
	}
}

pub fn buffer_source_value_with_id(value BufferSource, opaque_id u64) Value {
	return Value{
		kind: .buffer_source
		buffer_value: value
		opaque_id: opaque_id
	}
}

pub fn callback_value() Value {
	return Value{
		kind: .callback
	}
}

pub fn platform_object_value() Value {
	return Value{
		kind: .platform_object
	}
}

pub fn platform_object_value_with_id(opaque_id u64) Value {
	return Value{
		kind: .platform_object
		opaque_id: opaque_id
	}
}

pub fn platform_object_value_with_interfaces(interface_names []string) Value {
	return Value{
		kind: .platform_object
		platform_interfaces: interface_names.clone()
	}
}

pub fn is_buffer_source_type(value Value) bool {
	return value.kind == .buffer_source
}

pub fn to_byte_string(value Value) !string {
	text := to_string(value)!
	utf16 := to_utf16_string(value)!
	for index, code_unit in utf16 {
		if code_unit > 0xff {
			return error('TypeError: Invalid byte 0x${code_unit.hex()} at index ${index}, must be no greater than 0xFF')
		}
	}
	return text
}

pub fn to_string(value Value) !string {
	return match value.kind {
		.undefined {
			'undefined'
		}
		.null_ {
			'null'
		}
		.boolean {
			if value.boolean_value {
				'true'
			} else {
				'false'
			}
		}
		.number {
			format_number(value.number_value)
		}
		.bigint {
			value.bigint_value.str()
		}
		.string_ {
			value.string_value
		}
		.object, .platform_object {
			'[object Object]'
		}
		.sequence {
			mut items := []string{cap: value.sequence_value.len}
			for item in value.sequence_value {
				items << to_string(item)!
			}
			items.join(',')
		}
		.callback {
			'function () { [native code] }'
		}
		.buffer_source {
			'[object ArrayBuffer]'
		}
	}
}

fn format_number(value f64) string {
	if value == f64(int(value)) {
		return int(value).str()
	}
	return value.str()
}

// V strings are well-formed UTF-8. Invalid scalar input is represented by the
// replacement character before this boundary, matching USVString conversion.
pub fn to_usv_string(value Value) !string {
	return to_string(value)
}

pub type Boolean = bool
pub type Byte = i8
pub type Octet = u8
pub type Short = i16
pub type UnsignedShort = u16
pub type Long = i32
pub type UnsignedLong = u32
pub type LongLong = i64
pub type UnsignedLongLong = u64
pub type Double = f64
