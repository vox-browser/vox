module webassembly

import os

fn test_source_reverse_chunk_verify_rejects_zero_offset_on_actual_storage_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_REVERSE_CHUNK_OFFSET') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.try_resize(16)!
		buffer.contiguous_bytes_before(0, 1)
		println('SOURCE_REVERSE_CHUNK_RETURNED_AFTER_ZERO_OFFSET')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_REVERSE_CHUNK_OFFSET'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::contiguous_bytes_before offset > 0'), output
	assert !output.contains('SOURCE_REVERSE_CHUNK_RETURNED_AFTER_ZERO_OFFSET'), output
}

fn test_source_reverse_chunk_shortcuts_and_actual_positive_offsets_follow_source_order() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	// Source returns before VERIFY for zero count or an invalid storage offset.
	assert buffer.contiguous_bytes_before(0, 0) == 0
	assert buffer.contiguous_bytes_before(0, 1) == 1
	assert buffer.contiguous_bytes_before(0, 17) == 17
	buffer.try_resize(16)!
	assert buffer.contiguous_bytes_before(0, 0) == 0
	assert buffer.contiguous_bytes_before(1, 1) == 1
	assert buffer.contiguous_bytes_before(16, 16) == 16
	for index in 0 .. 16 {
		unsafe { buffer.data()[index] = u8(index) }
	}
	buffer.move_data(2, 0, 8)
	mut bytes := []u8{len: 16}
	buffer.copy_to(0, BinaryMachineBytes{ data: bytes.data, size: 16 })
	assert bytes == [u8(0), 1, 0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15]
}
