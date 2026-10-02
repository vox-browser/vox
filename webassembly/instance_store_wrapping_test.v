module webassembly

import webidl

fn test_instance_wraps_existing_nonzero_store_addresses_without_allocating_defaults() {
	instance := Instance.create_for_realm('actual-instance-address-wrapping', &Module{}, ImportObject{})!
	mut store := instance.cache().abstract_machine_.store()
	store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .i32 } }, BinaryMachineValue.from_i32(4)) or { panic('allocation failed') }
	global_address := store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .f64 }, mutable_: true }, BinaryMachineValue.from_f64(3.25)) or { panic('allocation failed') }
	store.allocate_table(BinaryTableType{ element_type: BinaryValueType{ kind: .extern_reference } }) or { panic('allocation failed') }
	table_address := store.allocate_table(BinaryTableType{ element_type: BinaryValueType{ kind: .function_reference }, limits: WasmLimits{ minimum: 2, maximum: u64(3) } }) or { panic('allocation failed') }
	assert global_address == 1 && table_address == 1
	mut global := instance.global_instance(global_address)
	assert global.address() == global_address
	assert global.type()!.type_.kind == .f64
	assert global.value()!.number_value == 3.25
	global.set_value(webidl.number_value(7.5))!
	assert store.get_global(global_address)?.value().to_f64() == 7.5
	table_ := instance.table_instance(table_address)
	assert table_.address() == table_address
	assert table_.element_type()!.kind == .function_reference
	assert table_.length()! == 2
	assert table_.get(1)!.kind == .null_
	assert table_.grow(1, none)! == 2
	mut actual_table := store.get_table(table_address)?
	assert actual_table.elements().values.len == 3
	assert voidptr(instance.global_instance(global_address)) == voidptr(global)
	assert voidptr(instance.table_instance(table_address)) == voidptr(table_)
	// No extra default instance was allocated while wrapping either address.
	assert store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .i32 } }, BinaryMachineValue{})? == 2
	assert store.allocate_table(BinaryTableType{ element_type: BinaryValueType{ kind: .extern_reference } })? == 2
}

fn test_instance_cache_miss_wraps_real_memory_and_installs_source_growth_hook() {
	instance := Instance.create_for_realm('actual-instance-memory-wrapping', &Module{}, ImportObject{})!
	mut store := instance.cache().abstract_machine_.store()
	address := store.allocate_memory(WasmLimits{ minimum: 1, maximum: u64(2) })?
	mut actual := store.get_memory(address)?
	mut memory := instance.memory_instance(address)
	assert memory.address() == address
	assert !memory.shared
	assert voidptr(instance.memory_instance(address)) == voidptr(memory)
	buffer := memory.buffer()
	assert buffer.byte_length() == 65536
	assert actual.successful_grow_hook != none
	assert memory.grow(1)! == 1
	assert actual.size() == 131072
	assert buffer.detached
	assert memory.buffer().byte_length() == 131072
}

fn test_instance_unknown_address_wraps_source_address_without_fabricating_readable_value() {
	instance := Instance.create_for_realm('missing-instance-address-wrapping', &Module{}, ImportObject{})!
	global := instance.global_instance(100)
	assert global.address() == 100
	if _ := global.value() {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the global instance'
	}
	table_ := instance.table_instance(200)
	assert table_.address() == 200
	if _ := table_.length() {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the memory table'
	}
}
