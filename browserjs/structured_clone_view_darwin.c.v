// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import libjs

fn (mut projection NativeCloneProjection) project_array_buffer_view(value voidptr, mut object html.StructuredObject) ! {
	bridge := projection.bridge
	owner := bridge.runtime
	metadata := projection.root(bridge.engine('view_metadata', [value])!)!
	if C.JSValueIsNull(owner.context, metadata) {
		// Source make_*_with_buffer_witness_record + is_*_out_of_bounds.
		// Only captured intrinsic validation runs here; no author exception is
		// converted into a different exception by this source bounds check.
		return native_clone_unsupported('ArrayBuffer view is out of bounds')
	}
	buffer := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 0)])!
	buffer_metadata := projection.root(bridge.engine('buffer_metadata', [buffer])!)!
	if C.JSValueIsUndefined(owner.context, buffer_metadata) {
		return native_clone_unsupported('Exact native viewed ArrayBuffer slots are unavailable')
	}
	resizable := bridge.engine('list_item', [buffer_metadata, C.JSValueMakeNumber(owner.context, 1)])!
	if C.JSValueToBoolean(owner.context, resizable) {
		// Materialized getters cannot reveal original automatic/fixed lengths.
		return native_clone_unsupported('Original native resizable-view length slots are not yet owned')
	}
	buffer_value := projection.project(buffer)!
	object.viewed_array_buffer = html.structured_object_from_value(*buffer_value)!
	name := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 1)])!
	constructor_name := owner.native_utf16_string(name)!
	object.string_utf16_ = constructor_name
	object.string_data = constructor_name.str()
	length := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 2)])!
	offset := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 3)])!
	object.byte_length = u32(bridge.number(length)!)
	object.byte_offset = u32(bridge.number(offset)!)
	if object.string_data != 'DataView' {
		count := bridge.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 4)])!
		object.array_length = u32(bridge.number(count)!)
	}
}

fn (mut projection NativeCloneProjection) reconstruct_array_buffer_view(object &html.StructuredObject) !voidptr {
	bridge := projection.bridge
	mut owner := unsafe { &Runtime(bridge.runtime) }
	buffer := object.viewed_array_buffer or { return native_clone_unsupported('Source view has no ArrayBuffer') }
	if buffer.kind != .array_buffer {
		return native_clone_unsupported('Native SharedArrayBuffer views are unavailable')
	}
	if buffer.max_byte_length != none {
		return native_clone_unsupported('Original native resizable-view length slots are not yet owned')
	}
	actual_buffer := projection.reconstruct(html.structured_object_value(buffer))!
	// Source constructor names are the validated ASCII TypedArray/DataView set.
	actual_name := projection.adopt_root(owner.javascript_utf16_string(libjs.utf16_string(object.string_data))!)
	length := if object.string_data == 'DataView' {
		object.byte_length or { return native_clone_unsupported('Source fixed DataView has no byte length') }
	} else {
		object.array_length or { return native_clone_unsupported('Source fixed TypedArray has no array length') }
	}
	actual := bridge.engine('create_view', [actual_buffer, actual_name, C.JSValueMakeNumber(owner.context, f64(object.byte_offset)), C.JSValueMakeNumber(owner.context, f64(length))])!
	if C.JSValueIsUndefined(owner.context, actual) {
		return native_clone_unsupported('Source view constructor is unavailable in this native engine')
	}
	return projection.root(actual)
}
