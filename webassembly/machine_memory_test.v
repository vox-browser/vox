module webassembly

import libgc

@[heap]
struct MachineMemoryGrowObservation {
mut:
	memory   &BinaryMachineMemoryInstance = unsafe { nil }
	calls    int
	sizes    []uint
	minimums []u64
}

fn test_machine_memory32_reserves_the_source_guard_and_grows_without_moving() {
	mut memory := BinaryMachineMemoryInstance.create(WasmLimits{ minimum: 1, maximum: u64(3) })!
	defer { memory.destroy() }
	mut buffer := memory.data()
	assert memory.size() == uint(page_size) && buffer.capacity() == uint(3 * page_size)
	base := buffer.data()
	handle := buffer.primitive_storage_handle()
	unsafe { base[0] = 79 }
	assert memory.contains_virtual_address(unsafe { base + uint(machine_wasm32_guarded_reservation_size) - 1 })
	assert !memory.contains_virtual_address(unsafe { base + uint(machine_wasm32_guarded_reservation_size) })
	mut observed := &MachineMemoryGrowObservation{ memory: memory }
	memory.successful_grow_hook = fn [mut observed] () {
		observed.calls++
		observed.sizes << observed.memory.size()
		observed.minimums << observed.memory.type_().minimum
	}
	grew := memory.grow(uint(page_size), .yes, .no)
	assert grew && memory.type_().minimum == 2 && memory.size() == uint(2 * page_size)
	assert observed.calls == 1 && observed.sizes == [uint(2 * page_size)] && observed.minimums == [u64(1)]
	assert voidptr(buffer.data()) == voidptr(base) && buffer.primitive_storage_handle() == handle
	assert unsafe { base[0] } == 79 && unsafe { base[page_size] } == 0 && unsafe { base[2 * page_size - 1] } == 0
	assert memory.grow(0, .yes, .no) && observed.calls == 1
	grew_inhibited := memory.grow(uint(page_size), .yes, .yes)
	assert grew_inhibited && memory.type_().minimum == 3 && observed.calls == 1
	assert !memory.grow(1, .yes, .no) && memory.size() == uint(3 * page_size)
	assert !memory.grow(uint(-1), .yes, .no) && observed.calls == 1
	actual_data := unsafe { &BinaryMachineMemoryBuffer(uint(memory) + BinaryMachineMemoryInstance.data_offset()) }
	assert voidptr(actual_data) == voidptr(buffer)
}

fn test_machine_memory64_dynamic_reservations_and_source_minimum_update_modes() {
	mut memory := BinaryMachineMemoryInstance.create(WasmLimits{ address_type: .i64 })!
	defer { memory.destroy() }
	assert memory.size() == 0 && memory.data().capacity() == 0
	grew := memory.grow(uint(page_size), .yes, .no)
	assert grew && memory.type_().minimum == 1
	assert memory.data().capacity() == machine_default_memory_reservation_size
	mut buffer := memory.data()
	handle := buffer.primitive_storage_handle()
	unsafe { buffer.data()[0] = 89 }
	grew_again := memory.grow(machine_default_memory_reservation_size, .no, .no)
	assert grew_again && memory.type_().minimum == 1
	assert memory.size() == machine_default_memory_reservation_size + uint(page_size)
	assert buffer.capacity() == machine_default_memory_reservation_size * 2 && buffer.primitive_storage_handle() == handle
	assert unsafe { buffer.data()[0] } == 89 && unsafe { buffer.data()[memory.size() - 1] } == 0
	assert memory.contains_virtual_address(unsafe { buffer.data() + buffer.capacity() - 1 })
	assert !memory.contains_virtual_address(unsafe { buffer.data() + buffer.capacity() })
}

fn test_machine_memory_limits_checked_pages_and_supported_memory64_width() {
	assert machine_maximum_memory_size(WasmLimits{ address_type: .i64, maximum: u64(1) << 48 })! == uint(machine_wasm32_max_pages * u64(page_size))
	assert machine_initial_memory_reservation_size(WasmLimits{ address_type: .i32, minimum: 1 })! == uint(machine_wasm32_max_pages * u64(page_size))
	assert machine_initial_memory_reservation_size(WasmLimits{ address_type: .i64, minimum: 1 })! == uint(page_size)
	assert machine_initial_memory_reservation_size(WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(4) })! == uint(4 * page_size)
	mut rejected := false
	_ = BinaryMachineMemoryInstance.create(WasmLimits{ minimum: 2, maximum: u64(1) }) or {
		rejected = true
		assert err.code() == C.ENOMEM
		unsafe { nil }
	}
	assert rejected
	rejected = false
	_ = machine_size_from_page_count(u64(-1)) or {
		rejected = true
		assert err.code() == C.ENOMEM
		uint(0)
	}
	assert rejected
	assert machine_grown_memory_reservation_size(0, uint(page_size), uint(2 * page_size)) == uint(2 * page_size)
	assert machine_grown_memory_reservation_size(16, 80, 100) == 100
	mut memory := BinaryMachineMemoryInstance.create(WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(4) })!
	handle := memory.data().primitive_storage_handle()
	assert memory.data().capacity() == uint(4 * page_size)
	memory.destroy()
	assert !libgc.PrimitiveStorage.the().is_valid(handle)
}
