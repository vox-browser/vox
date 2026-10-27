module webassembly

fn source_compiled_table_host(mut _ BinaryMachineConfiguration, _ BinaryMachineValueSpan) BinaryMachineResult {
	return BinaryMachineResult.from_values([])
}

fn source_compiled_table_owner(mut store BinaryMachineStore, owner &Module, result_count int) &BinaryMachineModuleInstance {
	type_ := BinaryDefinedType{ kind: .function_, results: []BinaryValueType{len: result_count, init: BinaryValueType{ kind: .i32 }} }
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ types: [type_] })
	mut contents := instance.contents()
	contents.canonical_types << canonicalize_binary_type(type_, BinaryTypeContext{})
	address := store.allocate_function(instance, owner, &owner.function_bodies[0], 0) or { panic('real function allocation') }
	contents.functions << address
	return instance
}

fn source_compiled_table_publish(mut owner Module, marker uint, inlined u32) {
	mut compiled := &owner.function_bodies[0].body.compiled_instructions
	instruction := &BinaryInstruction{ opcode: binary_op_nop }
	compiled.dispatches << BinaryDispatch{ instruction: instruction }
	compiled.src_dst_mappings << BinarySourcesAndDestination{}
	compiled.cranelift_inlined_locals = inlined
	compiled.max_call_rec_size = (uint(1) << 32) + 17
	// A metadata marker proves publication without inventing executable code.
	binary_publish_cranelift_entry(mut compiled, marker)
}

fn test_source_compiled_table_empty_and_host_only_owners_finish_without_native_entries() {
	mut store := BinaryMachineStore.create()
	mut empty := BinaryMachineModuleInstance.create()
	first := empty.compiled_fn_table(store)
	assert first.entries.len == 0 && empty.compiled_fn_table_built_
	assert voidptr(empty.compiled_fn_table(store)) == voidptr(first)
	host := store.allocate_host_function(BinaryMachineHostFunction.create(source_compiled_table_host, BinaryMachineFunctionType{}, '0'))?
	mut host_only := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ functions: [host] })
	table := host_only.compiled_fn_table(store)
	assert table.entries.len == 1 && host_only.compiled_fn_table_built_
	assert table.entries[0].handler_ptr == 0 && table.entries[0].expression == unsafe { nil }
}

fn test_source_compiled_table_rebuilds_until_actual_modules_finish_and_retains_metadata_aliases() {
	mut store := BinaryMachineStore.create()
	mut source := &Module{ function_bodies: [BinaryFunctionBody.create(0, [BinaryLocals{ count: 5, type_: BinaryValueType{ kind: .i32 } }], BinaryExpression{})] }
	defer { source.destroy_compilation_control() }
	mut instance := source_compiled_table_owner(mut store, source, 2)
	first := instance.compiled_fn_table(store)
	assert !instance.compiled_fn_table_built_ && first.entries[0].handler_ptr == 0
	source_compiled_table_publish(mut source, 0x1234, 7)
	table := instance.compiled_fn_table(store)
	assert voidptr(table) == voidptr(first)
	assert !instance.compiled_fn_table_built_
	entry := table.entries[0]
	compiled := &source.function_bodies[0].body.compiled_instructions
	assert entry.handler_ptr == 0x1234
	assert entry.dispatches_ptr == uint(compiled.dispatches.data)
	assert entry.src_dst_ptr == uint(compiled.src_dst_mappings.data)
	assert voidptr(entry.first_instruction) == voidptr(compiled.dispatches[0].instruction)
	assert voidptr(entry.expression) == voidptr(&source.function_bodies[0].body)
	assert voidptr(entry.module) == voidptr(instance)
	assert entry.total_local_count == 12 && entry.arity == 2 && entry.max_call_record_size == 17
	source.finish_cranelift_compilation()
	assert voidptr(instance.compiled_fn_table(store)) == voidptr(table)
	assert instance.compiled_fn_table_built_
	// Once built, Source returns the same table without rereading mutable inputs.
	mut ci := &source.function_bodies[0].body.compiled_instructions
	binary_publish_cranelift_entry(mut ci, 0x5678)
	assert instance.compiled_fn_table(store).entries[0].handler_ptr == 0x1234
}

fn test_source_compiled_table_keeps_imported_function_owners_and_waits_for_each_source() {
	mut store := BinaryMachineStore.create()
	mut source := &Module{ function_bodies: [BinaryFunctionBody.create(0, [], BinaryExpression{})] }
	mut imported_source := &Module{ function_bodies: [BinaryFunctionBody.create(0, [], BinaryExpression{})] }
	defer { source.destroy_compilation_control() }
	defer { imported_source.destroy_compilation_control() }
	mut own := source_compiled_table_owner(mut store, source, 1)
	imported := source_compiled_table_owner(mut store, imported_source, 0)
	mut contents := own.contents()
	contents.functions << imported.functions()[0]
	source_compiled_table_publish(mut source, 0x1111, 0)
	source.finish_cranelift_compilation()
	first := own.compiled_fn_table(store)
	assert !own.compiled_fn_table_built_ && first.entries.len == 2
	assert first.entries[0].handler_ptr == 0x1111 && first.entries[1].handler_ptr == 0
	source_compiled_table_publish(mut imported_source, 0x2222, 0)
	imported_source.finish_cranelift_compilation()
	second := own.compiled_fn_table(store)
	assert voidptr(first) == voidptr(second) && own.compiled_fn_table_built_
	assert second.entries[1].handler_ptr == 0x2222
	assert voidptr(second.entries[1].module) == voidptr(imported)
	assert second.entries[1].arity == 0
}

fn test_source_compiled_table_preserves_prior_entry_when_no_new_native_entry_is_published() {
	mut store := BinaryMachineStore.create()
	mut source := &Module{ function_bodies: [BinaryFunctionBody.create(0, [], BinaryExpression{})] }
	defer { source.destroy_compilation_control() }
	mut instance := source_compiled_table_owner(mut store, source, 0)
	source_compiled_table_publish(mut source, 0x1111, 0)
	first := instance.compiled_fn_table(store)
	mut compiled := &source.function_bodies[0].body.compiled_instructions
	binary_publish_cranelift_entry(mut compiled, 0)
	second := instance.compiled_fn_table(store)
	assert voidptr(first) == voidptr(second)
	assert !instance.compiled_fn_table_built_
	assert second.entries[0].handler_ptr == 0x1111
}
