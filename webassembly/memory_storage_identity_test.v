module webassembly

fn test_memory_wrappers_use_actual_store_indices_and_keep_buffer_caches_per_object() {
	cache_a := WebAssemblyCache.create()
	cache_b := WebAssemblyCache.create()
	first := memory_create_with_cache(cache_a, MemoryDescriptor{ initial: 1, maximum: 2 })!
	second := memory_create_with_cache(cache_a, MemoryDescriptor{ maximum: 1 })!
	other := memory_create_with_cache(cache_b, MemoryDescriptor{ initial: 1, maximum: 2 })!
	assert first.address() == 0 && second.address() == 1 && other.address() == 0
	assert voidptr(cache_a.abstract_machine_.store().get_memory(0) or { panic('missing store memory') }) == voidptr(first.machine_instance())
	a := buffer_object_for_realm('actual-memory-buffer-realm', first)
	b := buffer_object_for_realm('actual-memory-buffer-realm', other)
	assert voidptr(a) != voidptr(b)
	assert voidptr(a.storage.owner) == voidptr(first) && voidptr(b.storage.owner) == voidptr(other)
	assert a.storage.handle == first.machine_instance().data().primitive_storage_handle()
	assert voidptr(a.bytes().data) == voidptr(first.machine_instance().data().data())
	mut actual_bytes := a.bytes().data
	unsafe { actual_bytes[3] = 127 }
	alias := buffer_object_for_realm('another-memory-buffer-realm', first)
	assert alias.read_bytes(3, 1) == [u8(127)] && b.read_bytes(3, 1) == [u8(0)]
}

fn test_native_memory_growth_refreshes_real_wrappers_without_copying_the_backing_store() {
	cache := WebAssemblyCache.create()
	mut memory := memory_create_for_module_with_cache(cache, WasmLimits{ address_type: .i64, minimum: 1 })!
	mut buffer := memory.to_resizable_buffer_for_realm('native-growth-realm')!
	handle := buffer.storage.handle
	mut actual_bytes := buffer.bytes().data
	unsafe { actual_bytes[0] = 131 }
	mut instance := memory.machine_instance()
	grew := instance.grow(machine_default_memory_reservation_size, .yes, .no)
	assert grew && instance.type_().minimum == 257
	assert voidptr(buffer_object_for_realm('native-growth-realm', memory)) == voidptr(buffer)
	assert buffer.storage.handle == handle && buffer.byte_length() == instance.size()
	assert voidptr(buffer.bytes().data) == voidptr(instance.data().data())
	assert buffer.read_bytes(0, 1) == [u8(131)] && buffer.read_bytes(uint(page_size), 1) == [u8(0)]
	// The JS API uses GrowType::No and inhibits the native hook, then refreshes
	// exactly once. Its type minimum remains the source machine minimum.
	previous := memory.grow(1)!
	assert previous == 257 && memory.size_pages() == 258 && memory.wasm_type().minimum == 257
	assert buffer.byte_length() == uint(258 * page_size)
	fixed := memory.to_fixed_length_buffer_for_realm('fixed-growth-realm')
	previous_zero := memory.grow(0)!
	assert previous_zero == 258 && fixed.detached && fixed.byte_length() == 0
	assert fixed.bytes().data == unsafe { nil }
}

fn test_shared_memory_fixed_lengths_and_current_source_conversion_keep_canonical_wrapper() {
	mut memory := memory_create_with_cache(WebAssemblyCache.create(), MemoryDescriptor{ initial: 1, maximum: 3, shared: true })!
	fixed := memory.buffer()
	assert fixed.shared && fixed.frozen && fixed.detach_key == ''
	previous := memory.grow(1)!
	assert previous == 1 && !fixed.detached && fixed.byte_length() == uint(page_size)
	assert memory.buffer().byte_length() == uint(2 * page_size)
	resizable := memory.to_resizable_buffer()!
	assert resizable.resizable && resizable.frozen && resizable.detach_key == 'WebAssembly.Memory'
	assert resizable.max_byte_length == u64(3 * page_size)
	// The pinned shared branch returns the canonical object's existing buffer.
	assert voidptr(memory.to_fixed_length_buffer()) == voidptr(resizable)
	previous_again := memory.grow(1)!
	assert previous_again == 2 && resizable.byte_length() == uint(3 * page_size)
	assert !resizable.detached && fixed.byte_length() == uint(page_size)
}

fn test_memory_constructor_source_validation_order_and_declared_maximum_are_preserved() {
	for descriptor, message in {
		0: 'RangeError: Initial is larger than maximum.'
		1: 'TypeError: Maximum has to be specified for shared memory.'
		2: 'TypeError: Wasm Memory allocation failed'
	} {
		input := match descriptor {
			0 { MemoryDescriptor{ initial: 65537, maximum: 0 } }
			1 { MemoryDescriptor{ initial: 65537, shared: true } }
			else { MemoryDescriptor{ initial: 65537, maximum: 65538 } }
		}
		mut rejected := false
		_ = memory_create_with_cache(WebAssemblyCache.create(), input) or {
			rejected = true
			assert err.msg() == message
			unsafe { nil }
		}
		assert rejected
	}
	mut memory := memory_create_with_cache(WebAssemblyCache.create(), MemoryDescriptor{ maximum: 65537 })!
	assert memory.wasm_type().maximum? == 65537 && memory.machine_instance().data().capacity() == uint(65536) * uint(page_size)
	mut rejected := false
	_ = memory.to_resizable_buffer() or {
		rejected = true
		assert err.msg() == 'RangeError: Maximum memory length exceeds 65536 * 65536 bytes'
		unsafe { nil }
	}
	assert rejected
}
