module webassembly

import os

fn test_source_memory_span_at_verify_precedes_pointer_access_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_MEMORY_SPAN_INDEX') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		// The empty real span's returned pointer is never dereferenced.
		buffer.span().at(0)
		println('SOURCE_SPAN_AT_RETURNED_AFTER_INVALID_INDEX')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_MEMORY_SPAN_INDEX'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: Span::at index < m_size'), output
	assert !output.contains('SOURCE_SPAN_AT_RETURNED_AFTER_INVALID_INDEX'), output
}

fn test_source_memory_span_at_verify_rejects_exact_end_before_dereference_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_MEMORY_SPAN_END') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.try_resize(16)!
		buffer.bytes().at(16)
		println('SOURCE_SPAN_AT_RETURNED_AFTER_EXACT_END')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_MEMORY_SPAN_END'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: Span::at index < m_size'), output
	assert !output.contains('SOURCE_SPAN_AT_RETURNED_AFTER_EXACT_END'), output
}

fn test_source_memory_span_at_borrows_actual_cage_bytes_and_retains_in_range_pointer_identity() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.try_resize(16)!
	bytes := buffer.bytes()
	span := buffer.span()
	assert bytes.size == 16 && span.size == 16
	for index in 0 .. 16 {
		assert voidptr(bytes.at(uint(index))) == voidptr(buffer.offset_pointer(uint(index)))
		assert voidptr(span.at(uint(index))) == voidptr(bytes.at(uint(index)))
		cell := span.at(uint(index))
		unsafe { *cell = u8(index + 1) }
		assert unsafe { *bytes.at(uint(index)) } == u8(index + 1)
		assert unsafe { buffer.data()[index] } == u8(index + 1)
	}
}
