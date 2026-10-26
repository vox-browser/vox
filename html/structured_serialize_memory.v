// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

// StructuredSerialize.cpp seeds both memories in transfer-list order before
// traversing the message. The transfer receiving steps supply the actual target
// objects; their data is carried separately from this IPC serialization record.
fn structured_transfer_memory_indices(memory []&StructuredObject) !map[u64]u32 {
	mut indices := map[u64]u32{}
	for index, object in memory {
		identity := u64(voidptr(object))
		if identity == 0 || identity in indices {
			return error('DataCloneError: duplicate or null transfer memory object')
		}
		// UINT32_MAX is reserved for the null-prototype reference sentinel.
		if u64(index) >= u64(4294967295) {
			return error('DataCloneError: transfer memory exceeds the object-reference capacity')
		}
		indices[identity] = u32(index)
	}
	return indices
}

pub fn structured_serialize_with_transfer_memory(value dom.JSValue, memory []&StructuredObject) !SerializationRecord {
	mut serializer := StructuredSerializer{
		memory: structured_transfer_memory_indices(memory)!
	}
	serializer.serialize_value(value, false, .cross_origin_isolated_only)!
	return SerializationRecord{
		data:                 serializer.data
		shared_array_buffers: serializer.shared_array_buffers
	}
}

pub fn structured_deserialize_with_transfer_memory(record SerializationRecord, memory []&StructuredObject, context StructuredDeserializationContext) !dom.JSValue {
	if record.type_ != .ipc {
		return error('DataCloneError: transfer memory requires an IPC serialization record')
	}
	if record.data.len == 0 {
		return error('DataCloneError: empty serialization record')
	}
	structured_transfer_memory_indices(memory)!
	mut decoder := StructuredDecoder{
		data:                 record.data
		shared_array_buffers: record.shared_array_buffers
		type_:                record.type_
		context:              context
	}
	for object in memory {
		decoder.register_object(object)
	}
	// Like the upstream IPC overload, this intentionally does not require full
	// consumption. The storage decoder and its envelope remain separate.
	return *decoder.decode_value()!
}
