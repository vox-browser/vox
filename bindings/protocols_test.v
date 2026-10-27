module bindings

import html

struct SerializableFixture {
	bytes []u8
}

fn (fixture &SerializableFixture) serialization_steps(mut encoder TransferDataEncoder, for_storage bool, mut memory SerializationMemory) ! {
	encoder.write(fixture.bytes)
	memory.object_indices[1] = if for_storage { u32(2) } else { u32(1) }
}

fn (_ &SerializableFixture) deserialization_steps(mut decoder TransferDataDecoder, mut memory DeserializationMemory) ! {
	bytes := decoder.read(2)!
	memory.objects[u32(bytes[0])] = voidptr(uint(bytes[1]))
}

fn serialize_fixture(value Serializable, for_storage bool) ![]u8 {
	mut encoder := TransferDataEncoder{}
	mut memory := SerializationMemory{}
	value.serialization_steps(mut encoder, for_storage, mut memory)!
	return encoder.data
}

@[heap]
struct TransferableFixture {
	state &TransferableState
}

fn (fixture &TransferableFixture) transfer_steps(mut encoder TransferDataEncoder) ! {
	if fixture.is_detached() {
		return error('DataCloneError: object is detached')
	}
	encoder.write([u8(7), 8])
	fixture.set_detached(true)
}

fn (fixture &TransferableFixture) transfer_receiving_steps(mut decoder TransferDataDecoder) ! {
	_ = decoder.read(2)!
	fixture.set_detached(false)
}

fn (_ &TransferableFixture) primary_interface() html.TransferType {
	return .array_buffer
}

fn (fixture &TransferableFixture) is_detached() bool {
	return fixture.state.is_detached()
}

fn (fixture &TransferableFixture) set_detached(detached bool) {
	mut state := unsafe { &TransferableState(fixture.state) }
	state.set_detached(detached)
}

fn transfer_fixture(value Transferable) ![]u8 {
	mut encoder := TransferDataEncoder{}
	value.transfer_steps(mut encoder)!
	return encoder.data
}

fn test_serializable_and_transferable_protocols() {
	serializable := &SerializableFixture{
		bytes: [u8(1), 2]
	}
	assert serialize_fixture(serializable, true) or { panic(err) } == [u8(1), 2]
	mut decoder := TransferDataDecoder{
		data: [u8(3), 4]
	}
	mut memory := DeserializationMemory{}
	serializable.deserialization_steps(mut decoder, mut memory) or { panic(err) }
	assert decoder.offset == 2

	transferable := &TransferableFixture{
		state: &TransferableState{}
	}
	assert transferable.primary_interface() == .array_buffer
	assert transfer_fixture(transferable) or { panic(err) } == [u8(7), 8]
	assert transferable.is_detached()
	mut receiving_decoder := TransferDataDecoder{
		data: [u8(7), 8]
	}
	transferable.transfer_receiving_steps(mut receiving_decoder) or { panic(err) }
	assert !transferable.is_detached()

	mut truncated := TransferDataDecoder{
		data: [u8(1)]
	}
	if _ := truncated.read(2) {
		assert false
	}
	mut buffer_decoder := TransferDataDecoder{
		data: [u8(3), 0, 0, 0, 9, 8, 7]
	}
	assert buffer_decoder.decode_buffer()! == [u8(9), 8, 7]
}

fn test_transfer_data_encoder_exact_buffer_operations() {
	mut first := TransferDataEncoder{}
	first.append([u8(1), 2])
	assert first.buffer() == [u8(1), 2]
	mut second := TransferDataEncoder{}
	second.append([u8(3), 4])
	mut combined := TransferDataEncoder{}
	combined.extend([first, second])
	assert combined.buffer() == [u8(1), 2, 3, 4]
	assert combined.take_buffer() == [u8(1), 2, 3, 4]
	assert combined.buffer().len == 0
}
