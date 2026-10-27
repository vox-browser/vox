module webassembly

fn test_memory_descriptor_growth_and_buffer_modes() {
	mut memory := Memory.construct(MemoryDescriptor{ initial: 1, maximum: 3 })!
	assert memory.size_pages() == 1
	fixed := memory.buffer()
	assert fixed.byte_length() == uint(page_size)
	assert !fixed.resizable
	assert memory.grow(1)! == 1
	assert memory.size_pages() == 2
	resizable := memory.to_resizable_buffer()!
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

fn test_memory_buffers_are_cached_per_realm_and_refreshed_after_growth() {
	mut memory := Memory.create_for_constructor('memory-owner-realm', MemoryDescriptor{
		initial: 1
		maximum: 4
	})!
	assert voidptr(memory.cache()) == voidptr(get_cache_for_realm('memory-owner-realm'))
	assert voidptr(memory.cache().get_memory_instance(memory.address()) or { panic('missing memory') }) == voidptr(memory)

	realm_a_buffer := buffer_object_for_realm('memory-buffer-realm-a', memory)
	assert voidptr(buffer_object_for_realm('memory-buffer-realm-a', memory)) == voidptr(realm_a_buffer)
	realm_b_buffer := buffer_object_for_realm('memory-buffer-realm-b', memory)
	assert voidptr(realm_a_buffer) != voidptr(realm_b_buffer)
	assert memory_has_buffer_object(memory, realm_a_buffer)
	assert memory_has_buffer_object(memory, realm_b_buffer)

	assert memory.grow(1)! == 1
	assert realm_a_buffer.detached
	assert realm_b_buffer.detached
	assert !memory_has_buffer_object(memory, realm_a_buffer)
	assert !memory_has_buffer_object(memory, realm_b_buffer)
	refreshed_a_buffer := buffer_object_for_realm('memory-buffer-realm-a', memory)
	assert voidptr(refreshed_a_buffer) != voidptr(realm_a_buffer)
	assert refreshed_a_buffer.byte_length() == uint(2 * page_size)

	resizable_b_buffer := memory.to_resizable_buffer_for_realm('memory-buffer-realm-b')!
	assert resizable_b_buffer.resizable
	assert memory.grow(1)! == 2
	assert !resizable_b_buffer.detached
	assert resizable_b_buffer.byte_length() == uint(3 * page_size)
	assert resizable_b_buffer.detached_generation == 2
	assert voidptr(buffer_object_for_realm('memory-buffer-realm-b', memory)) == voidptr(resizable_b_buffer)
}

fn test_memory_external_storage_describes_current_backing_data() {
	mut memory := Memory.create(MemoryDescriptor{ initial: 1, maximum: 2 })!
	initial := external_memory_storage(memory, true)
	assert initial.byte_length() == uint(page_size)
	assert initial.generation == 0
	assert initial.fixed_length

	memory.grow(1)!
	grown := external_memory_storage(memory, false)
	assert grown.byte_length() == uint(2 * page_size)
	assert grown.generation == 1
	assert !grown.fixed_length
}

fn test_webassembly_caches_are_stable_per_realm_and_registered_live() {
	cache_a := get_cache_for_realm('cache-test-realm-a')
	cache_a_again := get_cache_for_realm('cache-test-realm-a')
	cache_b := get_cache_for_realm('cache-test-realm-b')
	assert voidptr(cache_a) == voidptr(cache_a_again)
	assert voidptr(cache_a) != voidptr(cache_b)
	assert live_caches().any(voidptr(it) == voidptr(cache_a))
	assert live_caches().any(voidptr(it) == voidptr(cache_b))
}
