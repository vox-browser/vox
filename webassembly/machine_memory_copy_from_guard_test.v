module webassembly

import os

fn test_source_memory_copy_from_offset_verify_remains_active_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_COPY_FROM_OFFSET') == '1' {
		mut source := BinaryMachineMemoryBuffer.create()
		mut destination := BinaryMachineMemoryBuffer.create()
		// The zero count never dereferences a pointer, including before the fix.
		destination.copy_from(source, 1, 0, 0)
		println('SOURCE_COPY_FROM_RETURNED_AFTER_INVALID_OFFSET')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_COPY_FROM_OFFSET'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::copy_from source_offset <= source.size()'), output
	assert !output.contains('SOURCE_COPY_FROM_RETURNED_AFTER_INVALID_OFFSET'), output
}

fn test_source_memory_copy_from_all_verify_categories_precede_chunk_access_and_alias_shortcut() {
	mode := os.getenv('VOX2_SOURCE_COPY_FROM_GUARD_CATEGORY')
	if mode != '' {
		mut source := BinaryMachineMemoryBuffer.create()
		mut destination := BinaryMachineMemoryBuffer.create()
		match mode {
			'source_count' { destination.copy_from(source, 0, 0, 1) }
			'destination_offset' { destination.copy_from(source, 0, 1, 0) }
			'destination_count' {
				source.try_resize(1)!
				destination.copy_from(source, 0, 0, 1)
			}
			'alias_offset' { source.copy_from(source, 1, 1, 0) }
			else { panic('unexpected copy_from guard probe') }
		}
		println('SOURCE_COPY_FROM_RETURNED_AFTER_INVALID_GUARD')
		exit(0)
	}
	for category in ['source_count', 'destination_offset', 'destination_count', 'alias_offset'] {
		expected := match category {
			'source_count' { 'count <= source.size() - source_offset' }
			'destination_offset' { 'destination_offset <= size()' }
			'destination_count' { 'count <= size() - destination_offset' }
			else { 'source_offset <= source.size()' }
		}
		mut process := os.new_process(os.executable())
		mut environment := os.environ()
		environment['VOX2_SOURCE_COPY_FROM_GUARD_CATEGORY'] = category
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		code := process.code
		process.close()
		assert code != 0 && output.contains('Source VERIFY: MemoryBuffer::copy_from ${expected}'), output
		assert !output.contains('SOURCE_COPY_FROM_RETURNED_AFTER_INVALID_GUARD'), output
	}
}

fn test_source_memory_copy_from_valid_empty_and_exact_end_preserve_actual_cage_owners() {
	mut source := BinaryMachineMemoryBuffer.create()
	mut destination := BinaryMachineMemoryBuffer.create()
	defer {
		source.destroy()
		destination.destroy()
	}
	destination.copy_from(source, 0, 0, 0)
	source.copy_from(source, 0, 0, 0)
	assert source.size() == 0 && destination.size() == 0
	source.try_resize(16)!
	destination.try_resize(16)!
	for index in 0 .. 16 {
		unsafe { source.data()[index] = u8(index) }
	}
	destination.fill(0, u8(0x79), 16)
	destination.copy_from(source, 4, 4, 12)
	destination.copy_from(source, 16, 16, 0)
	for index in 0 .. 16 {
		assert unsafe { source.data()[index] } == u8(index)
		assert unsafe { destination.data()[index] } == if index < 4 { u8(0x79) } else { u8(index) }
	}
	assert source.primitive_storage_handle() != destination.primitive_storage_handle()
	// Source aliases the actual owner to move_data, including overlapping copies.
	source.copy_from(source, 0, 2, 8)
	mut result := []u8{len: 10}
	source.copy_to(0, BinaryMachineBytes{ data: result.data, size: 10 })
	assert result == [u8(0), 1, 0, 1, 2, 3, 4, 5, 6, 7]
	source.copy_from(source, 2, 0, 8)
	source.copy_to(0, BinaryMachineBytes{ data: result.data, size: 10 })
	assert result == [u8(0), 1, 2, 3, 4, 5, 6, 7, 6, 7]
}
