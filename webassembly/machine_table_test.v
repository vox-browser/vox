module webassembly

fn test_machine_table_elements_retain_and_replace_actual_module_anchors() {
	element_type := BinaryValueType{ kind: .function_reference }
	null := BinaryNullReference{ type_: element_type }
	mut instance := BinaryMachineTableInstance.create(BinaryTableType{
		element_type: element_type
		limits:       WasmLimits{ minimum: 2 }
	}, [BinaryMachineReference(null), null])
	assert instance.module_anchor_at(0) == unsafe { nil }
	anchor := BinaryMachineModuleInstance.create()
	module_ := &Module{}
	function := BinaryFunctionReference{ address: 37, source_module: module_ }
	instance.set_element(0, function, anchor)
	reference := instance.elements().values[0]
	assert reference is BinaryFunctionReference
	if reference is BinaryFunctionReference {
		assert reference.address == 37 && voidptr(reference.source_module) == voidptr(module_)
	}
	assert voidptr(instance.module_anchor_at(0)) == voidptr(anchor)
	instance.set_element(0, null, unsafe { nil })
	assert instance.elements().values[0] is BinaryNullReference
	assert instance.module_anchor_at(0) == unsafe { nil }
	mut vector := instance.elements()
	vector.values[1] = BinaryExternReference{ address: 71 }
	assert instance.elements().values[1] is BinaryExternReference
}

fn test_machine_table_growth_preserves_source_limits_fill_and_zero_delta_order() {
	element_type := BinaryValueType{ kind: .function_reference }
	null := BinaryNullReference{ type_: element_type }
	mut instance := BinaryMachineTableInstance.create(BinaryTableType{
		element_type: element_type
		limits:       WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(3) }
	}, [BinaryMachineReference(null), null])
	anchor := BinaryMachineModuleInstance.create()
	fill := BinaryFunctionReference{ address: 89, source_module: &Module{} }
	grew := instance.grow(1, fill, anchor)
	assert grew && instance.elements().values.len == 3
	assert instance.type_().limits.minimum == 2
	assert instance.type_().limits.maximum? == 3 && instance.type_().limits.address_type == .i64
	assert instance.elements().values[0] is BinaryNullReference
	assert instance.elements().values[2] is BinaryFunctionReference
	assert voidptr(instance.module_anchor_at(2)) == voidptr(anchor)
	denied := instance.grow(1, null, unsafe { nil })
	assert !denied && instance.elements().values.len == 3 && instance.type_().limits.minimum == 2
	mut unbounded := BinaryMachineTableInstance.create(BinaryTableType{ element_type: element_type }, []BinaryMachineReference{})
	too_large := unbounded.grow(u32(-1), null, unsafe { nil })
	assert !too_large && unbounded.elements().values.len == 0
	mut inconsistent := BinaryMachineTableInstance.create(BinaryTableType{
		element_type: element_type
		limits:       WasmLimits{ maximum: u64(0) }
	}, [BinaryMachineReference(null)])
	zero := inconsistent.grow(0, fill, anchor)
	assert zero && inconsistent.elements().values.len == 1
	assert inconsistent.module_anchor_at(0) == unsafe { nil }
}

fn test_machine_store_tables_use_indexed_value_records_and_typed_null_initializers() {
	mut store := BinaryMachineStore.create()
	type_ := BinaryTableType{
		element_type: BinaryValueType{ kind: .extern_reference, nullable: false }
		limits:       WasmLimits{ minimum: 2, maximum: u64(3) }
	}
	first := store.allocate_table(type_)?
	second := store.allocate_table(BinaryTableType{ element_type: type_.element_type })?
	assert first == 0 && second == 1
	assert store.get_table(2) == none && store.get_table(u64(-1)) == none
	mut instance := store.get_table(first)?
	assert instance.type_() == type_ && instance.elements().values.len == 2
	for reference in instance.elements().values {
		assert reference is BinaryNullReference
		if reference is BinaryNullReference {
			assert reference.type_ == type_.element_type
		}
	}
	instance.set_element(0, BinaryExternReference{ address: 97 }, unsafe { nil })
	for _ in 0 .. 100 {
		_ := store.allocate_table(BinaryTableType{ element_type: type_.element_type })?
	}
	// Source stores TableInstance values: query again after its vector grows.
	mut refreshed := store.get_table(first)?
	assert refreshed.elements().values[0] is BinaryExternReference
	assert voidptr(refreshed) == voidptr(store.unsafe_get_table(first))
	assert store.allocate_table(BinaryTableType{
		element_type: type_.element_type
		limits:       WasmLimits{ minimum: machine_max_allowed_table_size + 1 }
	}) == none
}
