module webassembly

fn test_machine_module_contents_keep_actual_vectors_types_and_export_variants() {
	type_ := BinaryDefinedType{ kind: .function_ }
	canonical := canonicalize_binary_type(type_, BinaryTypeContext{})
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{
		types:                    [type_]
		functions:                [u64(7)]
		tables:                   [u64(11)]
		memories:                 [u64(13)]
		globals:                  [u64(17)]
		datas:                    [u64(19)]
		tags:                     [u64(23)]
		tag_types:                [BinaryTagType{ type_index: 0 }]
		exports:                  [BinaryMachineExportInstance.create('memory', BinaryMachineMemoryAddress{ value: 13 })]
		minimum_call_record_size: 128
	})
	assert instance.cached_minimum_call_record_allocation_size == 128
	assert instance.types() == [type_] && instance.functions() == [u64(7)]
	assert instance.tables() == [u64(11)] && instance.memories() == [u64(13)]
	assert instance.globals() == [u64(17)] && instance.datas() == [u64(19)]
	assert instance.tags() == [u64(23)] && instance.tag_types()[0].type_index == 0
	assert instance.elements().len == 0 && instance.canonical_types().len == 0
	mut contents := instance.contents()
	contents.functions << 29
	contents.elements << 31
	contents.canonical_types << canonical
	assert instance.functions() == [u64(7), 29] && instance.elements() == [u64(31)]
	assert voidptr(instance.canonical_types()[0]) == voidptr(canonical)
	export_ := instance.exports()[0]
	assert export_.name() == 'memory'
	value := export_.value()
	assert value is BinaryMachineMemoryAddress
	if value is BinaryMachineMemoryAddress {
		assert value.value == 13
	}
	entry := BinaryMachineCompiledFunctionEntry{}
	assert entry.handler_ptr == 0 && entry.module == unsafe { nil }
	assert entry.total_local_count == 0 && entry.arity == 0 && entry.max_call_record_size == 0
}

fn test_machine_module_resolved_owner_tables_retain_actual_stable_store_pointers() {
	mut store := BinaryMachineStore.create()
	first_memory := store.allocate_memory(WasmLimits{ maximum: u64(1) })?
	second_memory := store.allocate_memory(WasmLimits{ maximum: u64(1) })?
	defer {
		mut first := store.unsafe_get_memory(first_memory)
		mut second := store.unsafe_get_memory(second_memory)
		first.destroy()
		second.destroy()
	}
	global_type := BinaryGlobalType{ type_: BinaryValueType{ kind: .i32 }, mutable_: true }
	first_global := store.allocate_global(global_type, BinaryMachineValue.from_i32(41))?
	second_global := store.allocate_global(global_type, BinaryMachineValue.from_i32(73))?
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{
		memories: [second_memory, first_memory]
		globals:  [second_global, first_global]
	})
	memories := instance.resolved_memories(store)
	globals := instance.resolved_globals(store)
	assert unsafe { voidptr(memories[0]) } == voidptr(store.unsafe_get_memory(second_memory))
	assert unsafe { voidptr(memories[1]) } == voidptr(store.unsafe_get_memory(first_memory))
	assert unsafe { globals[0].value().to_i32() } == 73
	assert unsafe { globals[1].value().to_i32() } == 41
	for _ in 0 .. 100 {
		_ := store.allocate_global(global_type, BinaryMachineValue{})?
	}
	assert voidptr(instance.resolved_memories(store)) == voidptr(memories)
	assert voidptr(instance.resolved_globals(store)) == voidptr(globals)
	assert unsafe { voidptr(globals[0]) } == voidptr(store.unsafe_get_global(second_global))
	mut actual := store.unsafe_get_global(second_global)
	actual.set_value(BinaryMachineValue.from_i32(97))
	assert unsafe { globals[0].value().to_i32() } == 97
	mut empty := BinaryMachineModuleInstance.create()
	_ = empty.resolved_memories(store)
	_ = empty.resolved_globals(store)
	assert empty.resolved_memories_built_ && empty.resolved_globals_built_
}
