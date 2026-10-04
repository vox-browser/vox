module webassembly

import os

fn test_source_memory_fill_offset_verify_remains_active_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_FILL_OFFSET') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		// No bytes are touched even before the fix; only Source VERIFY is exposed.
		buffer.fill(1, u8(0x79), 0)
		println('SOURCE_FILL_RETURNED_AFTER_INVALID_OFFSET')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_FILL_OFFSET'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::fill offset <= size()'), output
	assert !output.contains('SOURCE_FILL_RETURNED_AFTER_INVALID_OFFSET'), output
}

fn test_source_memory_fill_zero_bytes_at_empty_owner_is_valid() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.fill(0, u8(0x79), 0)
	assert buffer.size() == 0
}

fn test_source_memory_fill_count_verify_precedes_any_cage_write_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_FILL_COUNT') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.fill(0, u8(0x79), 1)
		println('SOURCE_FILL_RETURNED_AFTER_INVALID_COUNT')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_FILL_COUNT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::fill count <= size() - offset'), output
	assert !output.contains('SOURCE_FILL_RETURNED_AFTER_INVALID_COUNT'), output
}

fn test_source_memory_fill_exact_end_updates_actual_cage_bytes_and_preserves_neighbors() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.try_resize(16)!
	buffer.fill(0, u8(0x79), 16)
	buffer.fill(12, u8(0xff), 4)
	buffer.fill(16, u8(0), 0)
	for index in 0 .. 16 {
		assert unsafe { buffer.data()[index] } == if index < 12 { u8(0x79) } else { u8(0xff) }
	}
	buffer.fill(0, u8(0), 1)
	assert unsafe { buffer.data()[0] } == 0
	assert unsafe { buffer.data()[1] } == 0x79
}
