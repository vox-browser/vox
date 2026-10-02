module html

import dom
import math

fn test_source_structured_serialization_tags_keep_pinned_wire_values() {
	assert u8(StructuredSerializeValueTag.growable_shared_array_buffer) == 19
	assert u8(StructuredSerializeValueTag.shared_array_buffer) == 20
	assert u8(StructuredSerializeValueTag.resizable_array_buffer) == 21
	assert u8(StructuredSerializeValueTag.array_buffer) == 22
	assert u8(StructuredSerializeValueTag.array_buffer_view) == 23
	assert u8(StructuredSerializeValueTag.serializable_object) == 24
	assert u8(StructuredSerializeValueTag.int32_primitive) == 25
	assert u8(StructuredSerializeValueTag.end_object) == 255
	buffer := StructuredObject.create(.array_buffer)
	assert structured_serialize(structured_object_value(buffer))!.data[0] == 22
	shared_buffer := StructuredObject.create_shared_array_buffer([], none)
	assert structured_serialize_with_shared_array_buffers(structured_object_value(shared_buffer), .same_agent_always)!.data[0] == 20
	for tag in [u8(0), 26, 255] {
		if _ := structured_deserialize(SerializationRecord{data: [tag]}) { assert false } else { assert err.msg().contains('DataCloneError') }
	}
}

fn test_source_int32_primitive_ipc_encoding_preserves_signed_bits_and_double_boundaries() {
	for number, bits in {
		f64(-1): u32(-1)
		f64(-2147483648): u32(2147483648)
		f64(2147483647): u32(2147483647)
		f64(0): u32(0)
	} {
		record := structured_serialize(dom.js_number(number))!
		assert record.data == [u8(25), u8(bits), u8(bits >> 8), u8(bits >> 16), u8(bits >> 24)]
		assert structured_deserialize(record)!.number_data == number
	}
	for number in [f64(2147483648), f64(-2147483649), f64(0.5), math.f64_from_bits(u64(1) << 63)] {
		record := structured_serialize(dom.js_number(number))!
		assert record.data[0] == 4
		assert math.f64_bits(structured_deserialize(record)!.number_data) == math.f64_bits(number)
	}
}
