// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Host adaptation of LibWeb's JS::Value at the WebIDL/Streams boundary. JSC
// owns the actual value and GC root; conversion never creates a surrogate JS
// object or serializes a chunk into a dictionary/string.
module browserjs

import strconv
import webidl
import libjs


fn C.JSValueToBoolean(context voidptr, value voidptr) bool

pub fn (mut runtime Runtime) webidl_value(value voidptr) !webidl.Value {
	runtime.retain_javascript_value(value)!
	owner_handle := voidptr(&runtime)
	mut number_primitive := ?f64(none)
	if C.JSValueIsNumber(runtime.context, value) {
		mut exception := unsafe { nil }
		number_primitive = C.vox_jsc_JSValueToNumber(runtime.context, value, &exception)
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	}
	return webidl.runtime_value(webidl.RuntimeValue{
		context: runtime.context
		value: value
		is_undefined: C.JSValueIsUndefined(runtime.context, value)
		number_primitive: number_primitive
		number_conversion: fn [owner_handle, value] () !f64 {
			owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			converted := owner.call_engine_function(owner.value_number_intrinsic_, [value])!
			mut exception := unsafe { nil }
			number := C.vox_jsc_JSValueToNumber(owner.context, converted, &exception)
			if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
			return number
		}
		bigint_int64_conversion: fn [owner_handle, value] () !i64 {
			owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			converted := owner.call_engine_function(owner.value_bigint_int64_intrinsic_, [value])!
			// The intrinsic returns a BigInt primitive, so this string read has
			// no observable author ToPrimitive or global String lookup.
			text := js_string_to_v(owner.context, converted)!
			return strconv.parse_int(text, 10, 64)!
		}
		bigint_conversion: fn [owner_handle, value] () !&libjs.BigInt {
			owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			converted := owner.call_engine_function(owner.value_bigint_intrinsic_, [value])!
			text := js_string_to_v(owner.context, converted)!
			return libjs.string_to_bigint(libjs.utf16_string(text)) or {
				return error('Actual engine BigInt primitive could not be projected')
			}
		}
		boolean_conversion: fn [owner_handle, value] () !bool {
			owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			return C.JSValueToBoolean(owner.context, value)
		}
		same_value: fn [owner_handle, value] (other webidl.RuntimeValue) !bool {
			owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			if other.context != owner.context { return error('JavaScript SameValue requires the owning context') }
			result := owner.call_engine_function(owner.value_same_intrinsic_, [value, other.value])!
			return C.JSValueToBoolean(owner.context, result)
		}
		string_conversion: fn [owner_handle, value] () !string {
			owner := unsafe { &Runtime(owner_handle) }
			owner.require_javascript_value_context()!
			mut exception := unsafe { nil }
			string_value := C.vox_jsc_JSValueToStringCopy(owner.context, value, &exception)
			if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
			if string_value == unsafe { nil } { return error('JavaScriptCore string conversion failed') }
			defer { C.JSStringRelease(string_value) }
			capacity := C.JSStringGetMaximumUTF8CStringSize(string_value)
			mut bytes := []u8{len: int(capacity)}
			written := unsafe { C.JSStringGetUTF8CString(string_value, &char(bytes.data), capacity) }
			if written == 0 { return error('JavaScriptCore string conversion failed') }
			return bytes[..int(written) - 1].bytestr()
		}
	})
}

// Translate the complete source BigInt record into an actual engine primitive.
// Decimal text is the arithmetic ABI, never the returned JavaScript value.
pub fn (mut runtime Runtime) javascript_bigint(value webidl.Value) !voidptr {
	runtime.require_javascript_value_context()!
	if value.kind != .bigint { return error('BigInt projection requires a source BigInt primitive') }
	integer := webidl.value_to_bigint(value)!
	text := js_source_string(integer.big_integer.str())
	defer { C.JSStringRelease(text) }
	actual := runtime.call_engine_function(runtime.value_bigint_intrinsic_, [C.vox_jsc_JSValueMakeString(runtime.context, text)])!
	return runtime.retain_javascript_value(actual)
}

pub fn (runtime &Runtime) actual_webidl_value(value webidl.Value) !voidptr {
	runtime.require_javascript_value_context()!
	native := value.runtime_value_ or { return error('WebIDL value has no native runtime reference') }
	if native.context != runtime.context { return error('WebIDL value belongs to another JavaScriptCore context') }
	return native.value
}
