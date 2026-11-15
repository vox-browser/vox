// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs

// WebIDL argument conversion retains the native object. Byte copying happens
// separately, after subsequent argument getters have had their observable turn.
fn native_buffer_source(mut vm libjs.VM, value libjs.Value, allow_shared bool) !&libjs.Object {
	if !value.is_object() { return vm.throw_error(.type_error, 'Expected a BufferSource') }
	object := value.as_object()
	buffer := if actual := object.array_buffer { actual }
		else if array := object.typed_array { array.viewed_buffer }
		else if view := object.data_view { view.viewed_buffer or { return vm.throw_error(.type_error, 'Uninitialized DataView') } }
		else { return vm.throw_error(.type_error, 'Expected a BufferSource') }
	if !allow_shared && buffer.is_shared_array_buffer() { return vm.throw_error(.type_error, 'Shared BufferSource is not allowed') }
	if !buffer.is_fixed_length() { return vm.throw_error(.type_error, 'Expected a fixed-length BufferSource') }
	return object
}

fn charge_buffer_source_work(mut vm libjs.VM, count u64) ! {
	for offset := u64(0); offset < count; offset += 1024 { vm.consume_execution_budget()! }
}

// WebIDL::get_buffer_source_copy includes only the view's current window.
// Detached and out-of-bounds sources contribute an empty byte sequence.
fn copy_native_buffer_source(mut vm libjs.VM, object &libjs.Object) ![]u8 {
	mut buffer := &libjs.ArrayBufferObject(unsafe { nil })
	mut offset := uint(0)
	mut length := uint(0)
	if actual := object.array_buffer {
		buffer = actual; length = actual.byte_length()
	} else if array := object.typed_array {
		record := libjs.make_typed_array_with_buffer_witness_record(array, .seq_cst)
		if libjs.is_typed_array_out_of_bounds(record) { return []u8{} }
		buffer = array.viewed_buffer; offset = uint(array.byte_offset); length = uint(libjs.typed_array_byte_length(record))
	} else if view := object.data_view {
		record := libjs.make_data_view_with_buffer_witness_record(view, .seq_cst)
		if libjs.is_view_out_of_bounds(record) { return []u8{} }
		buffer = view.viewed_buffer or { return vm.throw_error(.type_error, 'Uninitialized DataView') }
		offset = uint(view.byte_offset()); length = uint(libjs.get_view_byte_length(record))
	} else { return vm.throw_error(.type_error, 'Expected a BufferSource') }
	if buffer.is_detached() { return []u8{} }
	if length > uint(0x7fffffff) { return vm.throw_error(.range_error, 'BufferSource copy exceeds the native byte-vector limit') }
	charge_buffer_source_work(mut vm, u64(length))!
	if !buffer.is_shared_array_buffer() { return buffer.read_bytes(offset, length) }
	// Shared memory retains the source's byte-wise read boundary.
	mut result := []u8{len: int(length)}
	for index in 0 .. length {
		result[int(index)] = u8(buffer.get_value(mut vm, offset + index, .uint8, true, .unordered, true).number)
	}
	return result
}

fn (host &Host) uint8_array_from_bytes(bytes []u8) libjs.Value {
	buffer_prototype := host.realm.array_buffer_prototype or { panic('Missing ArrayBuffer prototype') }
	prototype := host.realm.typed_array_prototypes[.uint8] or { panic('Missing Uint8Array prototype') }
	buffer := libjs.ArrayBufferObject.create_from_bytes(host.realm, bytes, false, buffer_prototype)
	return libjs.Value.from_object(libjs.TypedArray.create(host.realm, .uint8, u32(bytes.len), buffer, prototype).object)
}
