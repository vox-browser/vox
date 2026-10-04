module webassembly

import os

fn test_source_memory_resize_verify_rejects_shrink_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_MEMORY_SHRINK') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.try_resize(16)!
		buffer.try_resize(8)!
		println('SOURCE_RESIZE_RETURNED_AFTER_SHRINK')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_MEMORY_SHRINK'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::try_resize new_size >= m_size'), output
	assert !output.contains('SOURCE_RESIZE_RETURNED_AFTER_SHRINK'), output
}

fn test_source_memory_resize_keeps_equal_size_valid_and_zeroes_actual_grown_tail() {
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer { buffer.destroy() }
	buffer.try_resize(0)!
	assert buffer.size() == 0 && !buffer.primitive_storage_handle().is_valid()
	buffer.try_resize(16)!
	handle := buffer.primitive_storage_handle()
	base := buffer.data()
	for index in 0 .. 16 {
		unsafe { buffer.data()[index] = u8(index + 1) }
	}
	buffer.try_resize(16)!
	assert buffer.size() == 16 && buffer.primitive_storage_handle() == handle
	assert voidptr(buffer.data()) == voidptr(base)
	buffer.try_resize(32)!
	assert buffer.size() == 32 && buffer.capacity() >= 32
	assert buffer.primitive_storage_handle() == handle
	for index in 0 .. 32 {
		assert unsafe { buffer.data()[index] } == if index < 16 { u8(index + 1) } else { u8(0) }
	}
	buffer.try_resize(200000)!
	assert buffer.size() == 200000 && buffer.capacity() >= 200000
	assert buffer.primitive_storage_handle() == handle
	for index in 0 .. 200000 {
		assert unsafe { buffer.data()[index] } == if index < 16 { u8(index + 1) } else { u8(0) }
	}
}
