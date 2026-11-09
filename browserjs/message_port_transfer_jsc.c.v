// Local MessageChannel transfer memory uses native endpoints, independently of
// the worker pipe's endpoint tokens. Buffers keep their captured engine slots.
module browserjs

import html
import platform

fn (bridge &ArrayBufferTransferBridge) serialize_local_message(value voidptr, transfer_list []voidptr) !html.SerializedTransferRecord {
	owner := bridge.clone.runtime
	owner.require_javascript_value_context()!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut projection := NativeCloneProjection{ bridge: bridge.clone }
	defer { projection.release_roots() }
	mut memory := []&html.StructuredObject{}
	mut buffers := map[u64]bool{}
	for actual in transfer_list {
		projection.root(actual)!
		if u64(actual) in projection.input_memory {
			return native_clone_unsupported('Cannot transfer the same object twice')
		}
		mut placeholder := html.StructuredObject.create(.array_buffer)
		if _ := owner.native_message_port(actual) {
			placeholder = html.StructuredObject.create(.message_port)
		} else {
			if int(bridge.clone.number(bridge.clone.engine('classify', [actual])!)!) != 22 {
				return native_clone_unsupported('Transfer list entry is not an ArrayBuffer or MessagePort')
			}
			metadata := projection.root(bridge.clone.engine('buffer_metadata', [actual])!)!
			if C.JSValueIsUndefined(owner.context, metadata) {
				return native_clone_unsupported('Exact native ArrayBuffer slots are unavailable')
			}
			resizable := bridge.clone.engine('list_item', [metadata,
				C.vox_jsc_JSValueMakeNumber(owner.context, 1)])!
			if C.JSValueToBoolean(owner.context, resizable) {
				maximum := bridge.clone.engine('list_item', [metadata,
					C.vox_jsc_JSValueMakeNumber(owner.context, 2)])!
				placeholder.max_byte_length = u64(bridge.clone.number(maximum)!)
			}
			buffers[u64(voidptr(placeholder))] = true
		}
		projected := html.structured_object_value(placeholder)
		projection.input_memory[u64(actual)] = &projected
		memory << placeholder
	}
	projected := projection.project(value)!
	mut visited := map[u64]bool{}
	reserve_transferred_view_extents(*projected, buffers, mut visited)!
	serialized := html.structured_serialize_with_transfer_memory(*projected, memory) or { return native_clone_unsupported(err.msg()) }
	// Author getters have finished; transfer each source in its original order.
	mut transfers := []html.SerializedTransferItem{}
	for actual in transfer_list {
		if port := owner.native_message_port(actual) {
			mut source := unsafe { &html.MessagePort(port) }
			transfers << source.transfer_steps() or { return native_clone_unsupported(err.msg()) }
		} else {
			mut holder := html.StructuredObject.create(.array_buffer)
			projection.project_array_buffer(actual, mut holder)!
			owner.call_engine_function(bridge.transfer, [actual])!
			transfers << html.SerializedTransferItem.array_buffer(holder.bytes, holder.max_byte_length)
		}
	}
	return html.SerializedTransferRecord{ serialized: serialized, transfers: transfers, uses_transfer_memory: true }
}
