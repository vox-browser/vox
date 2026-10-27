module webassembly

import os

fn test_source_memory_overwrite_offset_verify_remains_active_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_OVERWRITE_OFFSET') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		// Zero count touches no bytes even before the fix.
		buffer.overwrite(1, unsafe { nil }, 0)
		println('SOURCE_OVERWRITE_RETURNED_AFTER_INVALID_OFFSET')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_OVERWRITE_OFFSET'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::overwrite offset <= size()'), output
	assert !output.contains('SOURCE_OVERWRITE_RETURNED_AFTER_INVALID_OFFSET'), output
}

fn test_source_memory_overwrite_count_verify_precedes_pointer_reads_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_OVERWRITE_COUNT') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.overwrite(0, unsafe { nil }, 1)
		println('SOURCE_OVERWRITE_RETURNED_AFTER_INVALID_COUNT')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_OVERWRITE_COUNT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::overwrite count <= size() - offset'), output
	assert !output.contains('SOURCE_OVERWRITE_RETURNED_AFTER_INVALID_COUNT'), output
}

fn test_source_memory_overwrite_empty_exact_end_and_partial_writes_use_actual_cage() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.overwrite(0, unsafe { nil }, 0)
	assert buffer.size() == 0
	buffer.try_resize(16)!
	buffer.fill(0, u8(0x79), 16)
	input := [u8(0), 0xff, 0x23, 0x81]
	buffer.overwrite(12, input.data, uint(input.len))
	buffer.overwrite(16, unsafe { nil }, 0)
	for index in 0 .. 16 {
		assert unsafe { buffer.data()[index] } == if index < 12 {
			u8(0x79)
		} else {
			input[index - 12]
		}
	}
	buffer.overwrite(0, input.data, uint(input.len))
	for index in 0 .. 12 {
		assert unsafe { buffer.data()[index] } == if index < 4 { input[index] } else { u8(0x79) }
	}
}
