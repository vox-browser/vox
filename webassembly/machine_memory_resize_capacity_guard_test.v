module webassembly

import os

fn test_source_memory_resize_capacity_verify_precedes_zero_capacity_shortcut_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_MEMORY_RESIZE_CAPACITY') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.try_resize_with_capacity(1, 0)!
		println('SOURCE_RESIZE_CAPACITY_RETURNED_AFTER_INVALID_CAPACITY')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_MEMORY_RESIZE_CAPACITY'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::try_resize(new_size, reserved_capacity) new_size <= reserved_capacity'), output
	assert !output.contains('SOURCE_RESIZE_CAPACITY_RETURNED_AFTER_INVALID_CAPACITY'), output
}

fn test_source_memory_resize_capacity_shrink_verify_precedes_capacity_and_storage_in_production() {
	if os.getenv('VOX2_INVALID_SOURCE_MEMORY_RESIZE_CAPACITY_SHRINK') == '1' {
		mut buffer := BinaryMachineMemoryBuffer.create()
		buffer.try_resize_with_capacity(16, 32)!
		// Both predicates fail; Source requires the shrink predicate first.
		buffer.try_resize_with_capacity(8, 0)!
		println('SOURCE_RESIZE_CAPACITY_RETURNED_AFTER_SHRINK')
		exit(0)
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_INVALID_SOURCE_MEMORY_RESIZE_CAPACITY_SHRINK'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: MemoryBuffer::try_resize(new_size, reserved_capacity) new_size >= m_size'), output
	assert !output.contains('SOURCE_RESIZE_CAPACITY_RETURNED_AFTER_SHRINK'), output
}

fn test_source_memory_resize_capacity_valid_empty_and_grown_storage_preserve_bytes_and_handle() {
	mut empty := BinaryMachineMemoryBuffer.create()
	mut buffer := BinaryMachineMemoryBuffer.create()
	defer {
		empty.destroy()
		buffer.destroy()
	}
	empty.try_resize_with_capacity(0, 0)!
	assert empty.size() == 0 && !empty.primitive_storage_handle().is_valid()
	buffer.try_resize_with_capacity(0, 32)!
	handle := buffer.primitive_storage_handle()
	assert handle.is_valid() && buffer.size() == 0 && buffer.capacity() == 32
	buffer.try_resize_with_capacity(16, 32)!
	for index in 0 .. 16 {
		assert unsafe { buffer.data()[index] } == 0
		unsafe { buffer.data()[index] = u8(index + 1) }
	}
	buffer.try_resize_with_capacity(32, 64)!
	assert buffer.size() == 32 && buffer.capacity() >= 64
	assert buffer.primitive_storage_handle() == handle
	for index in 0 .. 32 {
		assert unsafe { buffer.data()[index] } == if index < 16 { u8(index + 1) } else { u8(0) }
	}
	buffer.try_resize_with_capacity(32, 32)!
	assert buffer.size() == 32 && buffer.capacity() >= 32
	assert buffer.primitive_storage_handle() == handle
	for index in 0 .. 32 {
		assert unsafe { buffer.data()[index] } == if index < 16 { u8(index + 1) } else { u8(0) }
	}
}
