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
	buffer := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(owner.context, 0)])!
	if C.JSValueToBoolean(owner.context, bridge.engine('is_shared_buffer', [buffer])!) {
		return native_clone_unsupported('Native SharedArrayBuffer isolation and sharing slots are not yet bound')
	}
	buffer_metadata := projection.root(bridge.engine('buffer_metadata', [buffer])!)!
	if C.JSValueIsUndefined(owner.context, buffer_metadata) {
		return native_clone_unsupported('Exact native viewed ArrayBuffer slots are unavailable')
	}
	resizable := bridge.engine('list_item', [buffer_metadata, C.vox_jsc_JSValueMakeNumber(owner.context, 1)])!
	if C.JSValueToBoolean(owner.context, resizable) {
		// These immutable original slots belong to actual views constructed
		// from source records, never inferred from a current materialized length.
		slots := owner.native_clone_view_slots(value) or {
			return native_clone_unsupported('Original native resizable-view length slots are not yet owned')
		}
		if slots.buffer != buffer { return native_clone_unsupported('Source view backing identity changed') }
		buffer_value := projection.project(buffer)!
		object.viewed_array_buffer = html.structured_object_from_value(*buffer_value)!
		object.string_data = slots.constructor_name
		object.byte_length = slots.byte_length
		object.byte_offset = slots.byte_offset
		object.array_length = slots.array_length
		return
	}
	buffer_value := projection.project(buffer)!
	object.viewed_array_buffer = html.structured_object_from_value(*buffer_value)!
	name := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(owner.context, 1)])!
	constructor_name := owner.native_utf16_string(name)!
	object.string_utf16_ = constructor_name
	object.string_data = constructor_name.str()
	length := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(owner.context, 2)])!
	offset := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(owner.context, 3)])!
	object.byte_length = u32(bridge.number(length)!)
	object.byte_offset = u32(bridge.number(offset)!)
	if object.string_data != 'DataView' {
		count := bridge.engine('list_item', [metadata, C.vox_jsc_JSValueMakeNumber(owner.context, 4)])!
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
	actual_buffer := projection.reconstruct(html.structured_object_value(buffer))!
	// Source constructor names are the validated ASCII TypedArray/DataView set.
	actual_name := projection.adopt_root(owner.javascript_utf16_string(libjs.utf16_string(object.string_data))!)
	length := if object.string_data == 'DataView' { object.byte_length } else { object.array_length }
	mut actual_length := C.vox_jsc_JSValueMakeUndefined(owner.context)
	if fixed_length := length { actual_length = C.vox_jsc_JSValueMakeNumber(owner.context, f64(fixed_length)) }
	actual := bridge.engine('create_view', [actual_buffer, actual_name, C.vox_jsc_JSValueMakeNumber(owner.context, f64(object.byte_offset)), actual_length])!
	if C.JSValueIsUndefined(owner.context, actual) {
		return native_clone_unsupported('Source view constructor is unavailable in this native engine')
	}
	projection.root(actual)!
	if buffer.max_byte_length != none {
		owner.retain_native_clone_view_slots(actual, NativeCloneViewSlots{
			buffer: actual_buffer
			constructor_name: object.string_data
			byte_length: object.byte_length
			byte_offset: object.byte_offset
			array_length: object.array_length
		})!
	}
	return actual
}
