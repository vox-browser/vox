module webassembly

import libgc

@[heap]
struct MachineMemoryStoreCollectionFixture {
mut:
	collections int
}

fn (mut heap MachineMemoryStoreCollectionFixture) collect_garbage() { heap.collections++ }

fn test_machine_store_memory_owns_stable_instances_at_real_vector_index_addresses() {
	mut store := BinaryMachineStore.create()
	first_address := store.allocate_memory(WasmLimits{ minimum: 1, maximum: u64(2) }) or { panic('memory allocation failed') }
	assert first_address == 0
	mut first := store.get_memory(0) or { panic('missing actual memory') }
	base := first.data().data()
	handle := first.data().primitive_storage_handle()
	unsafe { base[0] = 97 }
	for i in 0 .. 65 {
		address := store.allocate_memory(WasmLimits{ address_type: .i64 }) or { panic('memory allocation failed') }
		assert address == u64(i + 1)
	}
	retained_memory := store.get_memory(0) or { panic('lost actual memory') }
	assert voidptr(retained_memory) == voidptr(first)
	assert voidptr(store.unsafe_get_memory(0).data().data()) == voidptr(base)
	grew := first.grow(uint(page_size), .yes, .no)
	assert grew && retained_memory.size() == uint(2 * page_size)
	assert unsafe { retained_memory.data().data()[0] } == 97
	assert store.get_memory(66) == none && store.get_memory(u64(-1)) == none
	for mut memory in store.memories_ { memory.destroy() }
	assert !libgc.PrimitiveStorage.the().is_valid(handle)
}

fn test_machine_store_failed_memory_creation_only_retries_after_actual_heap_collection() {
	mut store := BinaryMachineStore.create()
	invalid_type := WasmLimits{ minimum: 2, maximum: u64(1) }
	assert store.allocate_memory(invalid_type) == none
	assert store.memories_.len == 0
	mut collector := &MachineMemoryStoreCollectionFixture{}
	store.set_heap(collector)
	assert store.allocate_memory(invalid_type) == none
	assert collector.collections == 1 && store.memories_.len == 0
	retained := store.heap()
	assert retained is &MachineMemoryStoreCollectionFixture
	address := store.allocate_memory(WasmLimits{ address_type: .i64 }) or { panic('zero memory allocation failed') }
	assert address == 0 && collector.collections == 1
	mut memory := store.get_memory(address) or { panic('missing actual memory') }
	memory.destroy()
}
