module webassembly

fn test_machine_data_store_owns_mutable_vector_and_index_addresses() {
	mut store := BinaryMachineStore.create()
	address := store.allocate_data([u8(1), 0, 255]) or { panic('allocation failed') }
	assert address == 0
	mut instance := store.get_data(address) or { panic('missing data') }
	assert instance.size() == 3
	mut bytes := instance.data()
	bytes.bytes[1] = 7
	bytes.bytes << u8(11)
	assert instance.size() == 4
	assert instance.data().bytes == [u8(1), 7, 255, 11]
	for _ in 0 .. 128 { store.allocate_data([]u8{}) or { panic('allocation failed') } }
	mut retained := store.get_data(0) or { panic('missing data') }
	assert retained.size() == 4
	// data.drop replaces the actual store record with an empty DataInstance.
	unsafe { *retained = BinaryMachineDataInstance.create([]u8{}) }
	assert retained.size() == 0
	assert store.get_data(129) == none && store.get_data(u64(-1)) == none
}

fn test_machine_element_store_retains_full_reference_variants_and_source_drop() {
	mut store := BinaryMachineStore.create()
	module_ := &Module{}
	type_ := BinaryValueType{ kind: .function_reference }
	references := [BinaryMachineReference(BinaryNullReference{ type_: type_ }),
		BinaryMachineReference(BinaryFunctionReference{ address: 41, source_module: module_ }),
		BinaryMachineReference(BinaryExternReference{ address: 51 }),
		BinaryMachineReference(BinaryI31Reference{ value: 71 })]
	address := store.allocate_element(type_, references) or { panic('allocation failed') }
	assert address == 0
	mut instance := store.get_element(address) or { panic('missing element') }
	assert instance.type_() == type_ && instance.references().len == 4
	function := instance.references()[1]
	if function is BinaryFunctionReference {
		assert function.address == 41 && voidptr(function.source_module) == voidptr(module_)
	} else {
		assert false
	}
	for _ in 0 .. 128 {
		store.allocate_element(type_, []BinaryMachineReference{}) or { panic('allocation failed') }
	}
	mut retained := store.get_element(0) or { panic('missing element') }
	assert retained.references().len == 4 && store.elements().len == 129
	unsafe { *retained = BinaryMachineElementInstance.create(retained.type_(), []BinaryMachineReference{}) }
	assert retained.type_() == type_ && retained.references().len == 0
	assert store.get_element(129) == none && store.get_element(u64(-1)) == none
}
