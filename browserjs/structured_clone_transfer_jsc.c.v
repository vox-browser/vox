// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import platform

pub struct TransferredArrayBuffer {
pub:
	bytes           []u8
	max_byte_length ?u64
}

pub struct NativeArrayBufferTransferRecord {
pub:
	serialized html.SerializationRecord
	buffers    []TransferredArrayBuffer
}

// Capture the detachment intrinsic when the realm is initialized, alongside
// the ordinary clone intrinsics. No author property is consulted during send.
@[heap]
pub struct ArrayBufferTransferBridge {
	clone    &StructuredCloneBridge
	transfer voidptr
}

pub fn ArrayBufferTransferBridge.create(runtime &Runtime) !&ArrayBufferTransferBridge {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &Runtime(runtime) }
	return &ArrayBufferTransferBridge{
		clone: StructuredCloneBridge.create(runtime)!
		// Only detach here; the transfer record already owns the payload bytes.
		transfer: owner.evaluate_host_value(r'(function(){const apply=Reflect.apply,transfer=ArrayBuffer.prototype.transfer;return function(buffer){return apply(transfer,buffer,[0])}})()')!
	}
}

// A transfer memory entry has no payload during graph serialization. The DTO
// serializer still checks view bounds, so retain only the extent witnessed by
// native view projection. Later getters may resize or detach the actual buffer;
// its final bytes are copied only after graph serialization, as in upstream.
fn reserve_transferred_view_extents(value dom.JSValue, memory map[u64]bool, mut visited map[u64]bool) ! {
	if !value.is_structured_object() { return }
	object := html.structured_object_from_value(value)!
	identity := u64(voidptr(object))
	if identity in visited { return }
	visited[identity] = true
	if object.kind == .array_buffer_view {
		buffer := object.viewed_array_buffer or { return native_clone_unsupported('Missing transferred view buffer') }
		if u64(voidptr(buffer)) in memory {
			end := u64(object.byte_offset) + u64(object.byte_length or { 0 })
			if end > u64(2147483647) {
				return native_clone_unsupported('Transferred view exceeds the translated byte-array capacity')
			}
			mut placeholder := unsafe { &html.StructuredObject(buffer) }
			if end > u64(placeholder.bytes.len) {
				placeholder.bytes = []u8{len: int(end)}
			}
		}
	}
	for item in object.values { reserve_transferred_view_extents(*item, memory, mut visited)! }
	for entry in object.entries {
		reserve_transferred_view_extents(*entry.key, memory, mut visited)!
		reserve_transferred_view_extents(*entry.value, memory, mut visited)!
	}
	for property in object.properties { reserve_transferred_view_extents(*property.value, memory, mut visited)! }
}

pub fn (bridge &ArrayBufferTransferBridge) serialize(value voidptr, transfer_list []voidptr) !NativeArrayBufferTransferRecord {
	owner := bridge.clone.runtime
	owner.require_javascript_value_context()!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut projection := NativeCloneProjection{bridge: bridge.clone}
	defer { projection.release_roots() }
	mut memory := []&html.StructuredObject{}
	mut identities := map[u64]bool{}
	for actual in transfer_list {
		projection.root(actual)!
		// This prepass checks brands and duplicates, without rejecting detached
		// buffers yet. Message getters must run before the transfer steps.
		if int(bridge.clone.number(bridge.clone.engine('classify', [actual])!)!) != 22 {
			return native_clone_unsupported('Transfer list entry is not an ArrayBuffer')
		}
		if u64(actual) in projection.input_memory {
			return native_clone_unsupported('Cannot transfer the same ArrayBuffer twice')
		}
		mut placeholder := html.StructuredObject.create(.array_buffer)
		metadata := projection.root(bridge.clone.engine('buffer_metadata', [actual])!)!
		if C.JSValueIsUndefined(owner.context, metadata) {
			return native_clone_unsupported('Exact native ArrayBuffer slot getters are unavailable')
		}
		resizable := bridge.clone.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 1)])!
		if C.JSValueToBoolean(owner.context, resizable) {
			maximum := bridge.clone.engine('list_item', [metadata, C.JSValueMakeNumber(owner.context, 2)])!
			placeholder.max_byte_length = u64(bridge.clone.number(maximum)!)
		}
		projected := html.structured_object_value(placeholder)
		projection.input_memory[u64(actual)] = &projected
		memory << placeholder
		identities[u64(voidptr(placeholder))] = true
	}
	projected := projection.project(value)!
	mut visited := map[u64]bool{}
	reserve_transferred_view_extents(*projected, identities, mut visited)!
	serialized := html.structured_serialize_with_transfer_memory(*projected, memory)!
	mut buffers := []TransferredArrayBuffer{}
	for actual in transfer_list {
		mut holder := html.StructuredObject.create(.array_buffer)
		projection.project_array_buffer(actual, mut holder)!
		// The captured engine operation enforces ArrayBufferDetachKey, including
		// WebAssembly buffers. Earlier transfers remain detached if this throws.
		owner.call_engine_function(bridge.transfer, [actual])!
		buffers << TransferredArrayBuffer{bytes: holder.bytes, max_byte_length: holder.max_byte_length}
	}
	return NativeArrayBufferTransferRecord{serialized: serialized, buffers: buffers}
}

// The returned actual value carries one Runtime root, matching clone.deserialize.
pub fn (bridge &ArrayBufferTransferBridge) deserialize(record NativeArrayBufferTransferRecord) !voidptr {
	owner := bridge.clone.runtime
	owner.require_javascript_value_context()!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	owner.prepare_html_script()
	defer { owner.clean_up_html_script() }
	mut projection := NativeCloneProjection{bridge: bridge.clone}
	defer { projection.release_roots() }
	mut memory := []&html.StructuredObject{}
	for data in record.buffers {
		if maximum := data.max_byte_length {
			if maximum < u64(data.bytes.len) {
				return native_clone_unsupported('Transferred ArrayBuffer exceeds its maximum byte length')
			}
		}
		mut buffer := html.StructuredObject.create(.array_buffer)
		buffer.bytes = data.bytes
		buffer.max_byte_length = data.max_byte_length
		actual := projection.reconstruct_array_buffer(buffer)!
		projection.output_memory[u64(voidptr(buffer))] = actual
		memory << buffer
	}
	value := html.structured_deserialize_with_transfer_memory(record.serialized, memory,
		owner.native_clone_deserialization_context()) or { return native_clone_unsupported(err.msg()) }
	actual := projection.reconstruct(value)!
	mut runtime := unsafe { &Runtime(owner) }
	return runtime.retain_javascript_value(actual)
}
