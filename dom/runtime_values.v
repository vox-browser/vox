// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module dom

import webidl

pub fn (value JSValue) native_boolean_value() !bool {
	native := value.native_value_ or { return error('Missing actual DOM JavaScript value') }
	if runtime := native.runtime_value_ {
		convert := runtime.boolean_conversion or { return error('Missing owning JavaScript ToBoolean operation') }
		return convert()
	}
	// Source WebIDL platform objects, including DOMException, are objects.
	if native.kind == .platform_object { return true }
	return error('Native DOM value requires its owning JavaScript ToBoolean operation')
}

pub fn (value JSValue) native_same_value(other JSValue) !bool {
	left := value.native_value_ or { return error('Missing actual DOM JavaScript value') }
	right := other.native_value_ or { return error('Missing actual DOM JavaScript value') }
	if runtime := left.runtime_value_ {
		other_runtime := right.runtime_value_ or { return false }
		compare := runtime.same_value or { return error('Missing owning JavaScript SameValue operation') }
		return compare(other_runtime)
	}
	if left.kind == .platform_object && right.kind == .platform_object {
		return left.opaque_id != 0 && left.opaque_id == right.opaque_id
	}
	return error('Native DOM value requires its owning JavaScript SameValue operation')
}

// Adapt source JS::Value reasons without serializing or cloning actual engine
// values. Scalar native callers retain their existing DOM value representation.
pub fn js_webidl_value(value webidl.Value) JSValue {
	if native := value.runtime_value_ {
		if native.is_undefined { return js_undefined() }
	}
	return match value.kind {
		.undefined { js_undefined() }
		.null_ { js_null() }
		.boolean { js_bool(value.boolean_value) }
		.number { js_number(value.number_value) }
		.string_ { js_string(value.string_value) }
		else { JSValue{kind: .runtime_value, native_value_: value} }
	}
}

pub fn (value JSValue) as_webidl_value() !webidl.Value {
	return match value.kind {
		.undefined { webidl.undefined_value() }
		.null_ { webidl.null_value() }
		.boolean { webidl.boolean_value(value.boolean_data) }
		.number { webidl.number_value(value.number_data) }
		.string { webidl.string_value(value.string_data) }
		.runtime_value { value.native_value_ or { return error('Missing actual DOM JavaScript value') } }
		.object { webidl.platform_object_value_with_id(u64(value.object_data)) }
	}
}
