module webassembly

import os

fn test_source_memory_move_data_destination_verify_precedes_zero_count_shortcut_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_MOVE_DATA_OFFSET') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		// Zero count avoids pointer access in the original method as well.
		buffer.move_data(1, 0, 0)
		println('SOURCE_MOVE_DATA_RETURNED_AFTER_INVALID_OFFSET')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_MOVE_DATA_OFFSET'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::move_data destination_offset <= size()'), output
	assert !output.contains('SOURCE_MOVE_DATA_RETURNED_AFTER_INVALID_OFFSET'), output
}

fn test_source_memory_move_data_count_and_source_guards_precede_zero_and_same_offset_shortcuts() {
	mode := os.getenv('VOX2_SOURCE_MOVE_DATA_GUARD_CATEGORY')
	if mode != '' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		match mode {
			'destination_count' { buffer.move_data(0, 0, 1) }
			'source_offset' { buffer.move_data(0, 1, 0) }
			'source_count' {
				buffer.try_resize(16)!
				buffer.move_data(0, 15, 2)
			}
			else { panic('unexpected move_data guard probe') }
		}
		println('SOURCE_MOVE_DATA_RETURNED_AFTER_INVALID_GUARD')
		exit(0)
	}
	for category in ['destination_count', 'source_offset', 'source_count'] {
		expected := match category {
			'destination_count' { 'count <= size() - destination_offset' }
			'source_offset' { 'source_offset <= size()' }
			else { 'count <= size() - source_offset' }
		}
		mut process := os.new_process(os.executable())
		mut environment := os.environ()
		environment['VOX2_SOURCE_MOVE_DATA_GUARD_CATEGORY'] = category
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		code := process.code
		process.close()
		assert code != 0 && output.contains('Source VERIFY: MemoryBuffer::move_data ${expected}'), output
		assert !output.contains('SOURCE_MOVE_DATA_RETURNED_AFTER_INVALID_GUARD'), output
	}
}

fn test_source_memory_move_data_empty_same_offset_and_both_overlap_directions_preserve_bytes() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.move_data(0, 0, 0)
	buffer.try_resize(16)!
	for index in 0 .. 16 {
		unsafe { buffer.data()[index] = u8(index) }
	}
	buffer.move_data(16, 16, 0)
	buffer.move_data(0, 0, 16)
	for index in 0 .. 16 {
		assert unsafe { buffer.data()[index] } == u8(index)
	}
	buffer.move_data(2, 0, 8)
	mut bytes := []u8{len: 16}
	buffer.copy_to(0, BinaryMachineBytes{ data: bytes.data, size: 16 })
	assert bytes == [u8(0), 1, 0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15]
	buffer.move_data(0, 2, 8)
	buffer.copy_to(0, BinaryMachineBytes{ data: bytes.data, size: 16 })
	assert bytes == [u8(0), 1, 2, 3, 4, 5, 6, 7, 6, 7, 10, 11, 12, 13, 14, 15]
	buffer.move_data(12, 0, 4)
	buffer.copy_to(0, BinaryMachineBytes{ data: bytes.data, size: 16 })
	assert bytes == [u8(0), 1, 2, 3, 4, 5, 6, 7, 6, 7, 10, 11, 0, 1, 2, 3]
}
