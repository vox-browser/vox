// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// ArrayBuffer.cpp::create(ByteBuffer) and TypedArray.cpp::Uint8Array::create
// allocate genuine owning-realm engine records at the existing JS ABI boundary.
module browserjs

import webidl


#include "@DIR/source_array_buffer_darwin.h"

fn C.vox_make_source_array_buffer_copy(context voidptr, bytes voidptr, length uint, exception &voidptr) voidptr
fn C.JSObjectMakeTypedArrayWithArrayBuffer(context voidptr, type_ int, buffer voidptr, exception &voidptr) voidptr

pub fn (mut runtime Runtime) source_array_buffer(bytes []u8) !webidl.Value {
	runtime.require_javascript_value_context()!
	mut exception := unsafe { nil }
	actual := C.vox_make_source_array_buffer_copy(runtime.context, bytes.data, uint(bytes.len), &exception)
	if exception != unsafe { nil } { return webidl.throw_value(runtime.webidl_value(exception)!) }
	if actual == unsafe { nil } { panic('Source MUST: ArrayBuffer ByteBuffer allocation failed') }
	return runtime.webidl_value(actual)
}

fn (runtime &Runtime) source_array_buffer_object(value webidl.Value) !voidptr {
	actual := runtime.actual_webidl_value(value)!
	mut exception := unsafe { nil }
	type_ := C.JSValueGetTypedArrayType(runtime.context, actual, &exception)
	if exception != unsafe { nil } { panic('Source VERIFY: ArrayBuffer class check failed') }
	assert type_ == C.kJSTypedArrayTypeArrayBuffer, 'Source VERIFY: expected an actual ArrayBuffer'
	return actual
}

pub fn (mut runtime Runtime) source_array_buffer_bytes(value webidl.Value) ![]u8 {
	actual := runtime.source_array_buffer_object(value)!
	mut exception := unsafe { nil }
	length := C.JSObjectGetArrayBufferByteLength(runtime.context, actual, &exception)
	if exception != unsafe { nil } { return webidl.throw_value(runtime.webidl_value(exception)!) }
	assert length <= uint(2147483647), 'Source ArrayBuffer span exceeds the V byte-buffer representation'
	mut bytes := []u8{len: int(length)}
	if length > 0 {
		pointer := C.JSObjectGetArrayBufferBytesPtr(runtime.context, actual, &exception)
		if exception != unsafe { nil } {
			return webidl.throw_value(runtime.webidl_value(exception)!)
		}
		assert pointer != unsafe { nil }, 'Source VERIFY: nonempty ArrayBuffer has no data'
		unsafe { C.memcpy(bytes.data, pointer, length) }
	}
	return bytes
}

pub fn (mut runtime Runtime) source_uint8_array(buffer webidl.Value) !webidl.Value {
	actual_buffer := runtime.source_array_buffer_object(buffer)!
	mut exception := unsafe { nil }
	actual := C.JSObjectMakeTypedArrayWithArrayBuffer(runtime.context, C.kJSTypedArrayTypeUint8Array, actual_buffer, &exception)
	if exception != unsafe { nil } { return webidl.throw_value(runtime.webidl_value(exception)!) }
	if actual == unsafe { nil } { panic('Source MUST: Uint8Array record allocation failed') }
	return runtime.webidl_value(actual)
}
