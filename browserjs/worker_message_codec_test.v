module browserjs

import html
import platform

fn worker_codec_fixture() NativeArrayBufferTransferRecord {
	return NativeArrayBufferTransferRecord{
		serialized: html.SerializationRecord{data: [u8(18), 0, 0, 0, 0]}
		buffers: [
			TransferredArrayBuffer{bytes: [u8(0), 128, 255]},
			TransferredArrayBuffer{bytes: [], max_byte_length: u64(4294967313)},
		]
	}
}

fn test_worker_message_wire_format_preserves_transfer_order_and_full_width_capacities() {
	record := worker_codec_fixture()
	bytes := encode_worker_message(record)!
	assert bytes == [u8(86), 88, 77, 49, 0, 0, 0, 5, 0, 0, 0, 2,
		18, 0, 0, 0, 0,
		0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 255,
		0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 17]
	decoded := decode_worker_message(bytes)!
	assert decoded.serialized.type_ == .ipc
	assert decoded.serialized.data == record.serialized.data
	assert decoded.serialized.shared_array_buffers.len == 0
	assert decoded.buffers.len == 2
	assert decoded.buffers[0].bytes == [u8(0), 128, 255]
	assert decoded.buffers[0].max_byte_length == none
	assert decoded.buffers[1].bytes.len == 0
	assert decoded.buffers[1].max_byte_length? == u64(4294967313)
	assert encode_worker_message(decoded)! == bytes
	plain := NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: [u8(0)]}}
	assert decode_worker_message(encode_worker_message(plain)!)!.buffers.len == 0
}

fn test_worker_message_decoder_rejects_truncation_corrupt_lengths_versions_flags_and_trailing_bytes() {
	valid := encode_worker_message(worker_codec_fixture())!
	for end in 0 .. valid.len {
		if _ := decode_worker_message(valid[..end]) { assert false }
	}
	mut bad_version := valid.clone()
	bad_version[3] = 50
	mut empty_graph := valid.clone()
	empty_graph[7] = 0
	mut long_graph := valid.clone()
	long_graph[4] = 255
	mut long_list := valid.clone()
	long_list[8] = 255
	mut long_payload := valid.clone()
	long_payload[17] = 255
	mut invalid_kind := valid.clone()
	invalid_kind[21] = 2
	mut fixed_maximum := valid.clone()
	fixed_maximum[29] = 1
	mut small_maximum := valid.clone()
	small_maximum[21] = 1
	mut unsafe_maximum := valid.clone()
	unsafe_maximum[38] = 255
	mut trailing := valid.clone()
	trailing << 0
	for bad in [bad_version, empty_graph, long_graph, long_list, long_payload,
		invalid_kind, fixed_maximum, small_maximum, unsafe_maximum, trailing] {
		if _ := decode_worker_message(bad) { assert false }
	}
}

fn test_worker_message_codec_enforces_frame_limit_and_rejects_process_local_side_tables() {
	graph := []u8{len: worker_message_max_bytes - 12, init: 1}
	encoded := encode_worker_message(NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: graph}})!
	assert encoded.len == worker_message_max_bytes
	assert decode_worker_message(encoded)!.serialized.data.len == graph.len
	mut oversized := encoded.clone()
	oversized << 0
	if _ := decode_worker_message(oversized) { assert false }
	for record in [
		NativeArrayBufferTransferRecord{},
		NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{type_: .storage, data: [u8(0)]}},
		NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: [u8(0)], shared_array_buffers: [html.StructuredObject.create_shared_array_buffer([u8(1)], none)]}},
		NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: graph}, buffers: [TransferredArrayBuffer{}]},
		NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: [u8(0)]}, buffers: [TransferredArrayBuffer{bytes: [u8(1)], max_byte_length: 0}]},
		NativeArrayBufferTransferRecord{serialized: html.SerializationRecord{data: [u8(0)]}, buffers: [TransferredArrayBuffer{max_byte_length: worker_message_max_capacity + 1}]},
	] {
		if _ := encode_worker_message(record) { assert false }
	}
}

fn test_worker_message_codec_owns_source_and_received_bytes_across_poisoned_scratch_resets() {
	mut caller := platform.begin_thread_scratch('worker codec caller')
	mut graph := [u8(18), 0, 0, 0, 0]
	mut payload := [u8(0), 128, 255]
	mut encoded := encode_worker_message(NativeArrayBufferTransferRecord{
		serialized: html.SerializationRecord{data: graph}
		buffers: [TransferredArrayBuffer{bytes: payload}]
	})!
	graph[0] = 99
	payload[0] = 99
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker codec delivery')
	decoded := decode_worker_message(encoded)!
	encoded[12] = 99
	encoded[30] = 99
	delivery.finish()
	assert decoded.serialized.data == [u8(18), 0, 0, 0, 0]
	assert decoded.buffers[0].bytes == [u8(0), 128, 255]
}

fn test_worker_message_wire_round_trip_reconstructs_actual_values_in_a_separate_runtime() {
	$if !darwin && !linux { return }
	mut sender := Runtime.create()
	mut receiver := Runtime.create()
	defer { sender.close(); receiver.close() }
	send := ArrayBufferTransferBridge.create(sender)!
	receive := ArrayBufferTransferBridge.create(receiver)!
	value := sender.evaluate_host_value(r'globalThis.buffer=new ArrayBuffer(3);new Uint8Array(buffer).set([0,128,255]);globalThis.message={buffer,view:new Uint8Array(buffer,1)};message.self=message;message')!
	record := send.serialize(value, [sender.evaluate_host_value('buffer')!])!
	encoded := encode_worker_message(record)!
	decoded := decode_worker_message(encoded)!
	actual := receive.deserialize(decoded)!
	receiver.define_value_host_function('__wireMessage', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert sender.evaluate_host('buffer.detached')! == 'true'
	assert receiver.evaluate_host('const value=__wireMessage();value.self===value&&value.buffer instanceof ArrayBuffer&&value.view instanceof Uint8Array&&value.view.buffer===value.buffer&&Array.from(value.view).join() === "128,255"')! == 'true'
}
