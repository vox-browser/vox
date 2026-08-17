module webassembly

fn test_memory_descriptor_growth_and_buffer_modes() {
	mut memory := Memory.construct(MemoryDescriptor{ initial: 1, maximum: 3 })!
	assert memory.size_pages() == 1
	fixed := memory.buffer()
	assert fixed.bytes.len == page_size
	assert !fixed.resizable
	assert memory.grow(1)! == 1
	assert memory.size_pages() == 2
	resizable := memory.to_resizable_buffer()
	assert resizable.resizable
	assert resizable.max_byte_length == u64(3 * page_size)
	assert memory.to_fixed_length_buffer().resizable == false
	if _ := memory.grow(2) {
		assert false
	} else {
		assert err.msg().starts_with('RangeError:')
	}
}

fn test_memory_descriptor_rejections_and_shared_requirement() {
	for descriptor in [
		MemoryDescriptor{
			initial: 2
			maximum: 1
		},
		MemoryDescriptor{
			initial: 1
			shared:  true
		},
		MemoryDescriptor{
			initial: maximum_pages + 1
		},
	] {
		if _ := Memory.construct(descriptor) {
			assert false
		} else {
			assert err.msg().starts_with('RangeError:') || err.msg().starts_with('TypeError:')
		}
	}
	shared_memory := Memory.construct(MemoryDescriptor{ initial: 0, maximum: 1, shared: true })!
	assert shared_memory.buffer().shared
}
