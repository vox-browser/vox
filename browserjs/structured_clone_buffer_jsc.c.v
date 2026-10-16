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
	if length > usize(2147483647) {
		return native_clone_unsupported('Native ArrayBuffer exceeds the translated byte-array capacity')
	}
	// Source CreateByteDataBlock + CopyDataBlockBytes. The C pointer is temporary:
	// copy its actual bytes before invoking any further engine operation.
	pointer := C.JSObjectGetArrayBufferBytesPtr(owner.context, value, &exception)
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
	mut exception := unsafe { nil }
	pointer := C.JSObjectGetArrayBufferBytesPtr(owner.context, actual, &exception)
	if exception != unsafe { nil } { return owner.actual_javascript_exception(exception) }
	if object.bytes.len != 0 && pointer == unsafe { nil } { return native_clone_unsupported('Native target ArrayBuffer has no backing data') }
	if object.bytes.len != 0 {
		unsafe { vmemcpy(pointer, object.bytes.data, object.bytes.len) }
	}
	return actual
}
