module webassembly

fn test_machine_store_globals_use_real_index_addresses_and_stable_owned_value_storage() {
	mut store := BinaryMachineStore.create()
	i64_type := BinaryGlobalType{ type_: BinaryValueType{ kind: .i64 }, mutable_: true }
	first_address := store.allocate_global(i64_type, BinaryMachineValue.from_i64(-8)) or { panic('allocation failed') }
	second_address := store.allocate_global(BinaryGlobalType{ type_: BinaryValueType{ kind: .extern_reference } }, BinaryMachineValue.from_reference(BinaryExternReference{ address: 37 })) or { panic('allocation failed') }
	assert first_address == 0 && second_address == 1
	mut first := store.get_global(first_address) or { panic('missing global') }
	assert first.type_() == i64_type && first.is_mutable()
	assert first.value().to_i64() == -8
	for _ in 0 .. 256 {
		store.allocate_global(i64_type, BinaryMachineValue.from_i64(0)) or { panic('allocation failed') }
	}
	retained := store.get_global(0) or { panic('lost global') }
	assert voidptr(retained) == voidptr(first)
	first.set_value(BinaryMachineValue.from_i64(0x123456789abcdef))
	assert store.unsafe_get_global(0).value().to_i64() == 0x123456789abcdef
	second := store.get_global(1) or { panic('missing reference global') }
	assert !second.is_mutable()
	reference := second.value().to_reference()
	assert reference is BinaryExternReference
	if reference is BinaryExternReference {
		assert reference.address == 37
	}
	assert store.get_global(258) == none && store.get_global(u64(-1)) == none
	assert store.globals().len == 258
}

fn test_machine_global_value_offset_targets_the_actual_untyped_bits() {
	mut global := BinaryMachineGlobalInstance.create(BinaryMachineValue.from_reference(BinaryI31Reference{ value: 0x42 }), true, BinaryValueType{ kind: .i31_reference })
	value_address := unsafe { &BinaryMachineValue(uint(global) + BinaryMachineGlobalInstance.value_offset()) }
	assert value_address.low == 0x42 && value_address.high == 7
	global.set_value(BinaryMachineValue.from_reference(BinaryNullReference{ type_: BinaryValueType{ kind: .i31_reference } }))
	assert value_address.low == 0 && value_address.high == 8
}
