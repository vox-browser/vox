// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html


fn (mut projection NativeCloneProjection) project_array_buffer(value voidptr, mut object html.StructuredObject) ! {
	bridge := projection.bridge
	owner := bridge.runtime
	owner.require_javascript_value_context()!
	metadata := projection.root(bridge.engine('buffer_metadata', [value])!)!
	if C.JSValueIsUndefined(owner.context, metadata) {
		return native_clone_unsupported('Exact native ArrayBuffer slot getters are unavailable')
	}
	detached := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 0)])!
	if C.JSValueToBoolean(owner.context, detached) {
		return native_clone_unsupported('Cannot serialize detached ArrayBuffer')
	}
	resizable := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 1)])!
	if C.JSValueToBoolean(owner.context, resizable) {
		maximum := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 2)])!
		object.max_byte_length = u64(bridge.number(maximum)!)
	}
	mut exception := unsafe { nil }
	length := C.JSObjectGetArrayBufferByteLength(owner.context, value, &exception)
	if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
	if length > uint(2147483647) {
		return native_clone_unsupported('Native ArrayBuffer exceeds the translated byte-array capacity')
	}
	// JSC permanently pins buffers whose backing pointers cross the C API.
	// Borrow only an internal copy so serialization leaves the author's buffer
	// detachable, including when it is transferred later in this same send.
	copy := projection.root(bridge.engine('copy_buffer', [value])!)!
	pointer := C.JSObjectGetTypedArrayBytesPtr(owner.context, copy, &exception)
	if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
	if length != 0 && pointer == unsafe { nil } { return native_clone_unsupported('Native ArrayBuffer has no backing data') }
	object.bytes = if length == 0 { []u8{} } else { unsafe { (&u8(pointer)).vbytes(int(length)).clone() } }
}

fn (mut projection NativeCloneProjection) reconstruct_array_buffer(object &html.StructuredObject) !voidptr {
	bridge := projection.bridge
	owner := bridge.runtime
	owner.require_javascript_value_context()!
	mut maximum := C.JSValueMakeUndefined(owner.context)
	if capacity := object.max_byte_length {
		// Every actual native ArrayBuffer capacity is represented as a precise
		// Number. Do not round a wider untrusted source u64 into another capacity.
		if capacity > u64(9007199254740991) {
			return native_clone_unsupported('Source ArrayBuffer capacity exceeds the exact native constructor range')
		}
		maximum = C.JSValueMakeNumber(owner.context, f64(capacity))
	}
	actual := projection.root(bridge.engine('create_buffer', [C.JSValueMakeNumber(owner.context, f64(object.bytes.len)), maximum])!)!
	if object.bytes.len != 0 {
		// Fill through captured typed-array operations. Exposing the target's
		// pointer here would make a received buffer impossible to transfer again.
		mut exception := unsafe { nil }
		bytes := C.vox_make_source_array_buffer_copy(owner.context, object.bytes.data, uint(object.bytes.len), &exception)
		if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
		if bytes == unsafe { nil } { return native_clone_unsupported('Native target ArrayBuffer allocation failed') }
		projection.root(bytes)!
		bridge.engine('write_buffer', [actual, bytes])!
	}
	return actual
}
