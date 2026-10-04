module webassembly

import os

fn test_source_memory_copy_to_offset_verify_survives_production() {
	if os.getenv('VOX2_INVALID_SOURCE_COPY_TO_OFFSET') == '1' {
		buffer := BinaryMachineMemoryBuffer.create()
		// This is safe even before the fix: the zero-length copy does not
		// dereference memory, exposing the missing production VERIFY alone.
		buffer.copy_to(1, BinaryMachineBytes{})
		println('SOURCE_COPY_RETURNED_AFTER_INVALID_OFFSET')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_COPY_TO_OFFSET'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::copy_to offset <= size()'), output
	assert !output.contains('SOURCE_COPY_RETURNED_AFTER_INVALID_OFFSET'), output
}

fn test_source_memory_copy_to_zero_bytes_at_empty_owner_is_valid() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.copy_to(0, BinaryMachineBytes{})
	assert buffer.size() == 0
}

fn test_source_memory_copy_to_destination_verify_precedes_any_cage_read_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_COPY_TO_DESTINATION') == '1' {
		buffer := BinaryMachineMemoryBuffer.create()
		mut sink := u8(0)
		buffer.copy_to(0, BinaryMachineBytes{ data: &sink, size: 1 })
		println('SOURCE_COPY_RETURNED_AFTER_INVALID_DESTINATION')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_COPY_TO_DESTINATION'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::copy_to destination.size() <= size() - offset'), output
	assert !output.contains('SOURCE_COPY_RETURNED_AFTER_INVALID_DESTINATION'), output
}

fn test_source_memory_copy_to_exact_end_preserves_actual_bytes_and_destination_guards() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.try_resize(16)!
	input := [u8(0), 0xff, 0x80, 0x7f, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]!
	buffer.overwrite(0, &input[0], 16)
	mut output := [18]u8{init: 0x79}
	buffer.copy_to(0, BinaryMachineBytes{ data: unsafe { &output[1] }, size: 16 })
	assert output[0] == 0x79 && output[17] == 0x79
	for index in 0 .. 16 {
		assert output[index + 1] == input[index]
	}
	buffer.copy_to(16, BinaryMachineBytes{})
	mut tail := [4]u8{}
	buffer.copy_to(12, BinaryMachineBytes{ data: unsafe { &tail[0] }, size: 4 })
	assert tail == [u8(9), 10, 11, 12]!
}
