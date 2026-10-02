module webassembly

fn test_machine_function_store_retains_actual_type_module_code_and_indexed_addresses() {
	type_ := BinaryDefinedType{ kind: .function_, parameters: [BinaryValueType{ kind: .i64 }], results: [BinaryValueType{ kind: .f64 }] }
	canonical := canonicalize_binary_type(type_, BinaryTypeContext{})
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ types: [type_] })
	mut contents := instance.contents()
	contents.canonical_types << canonical
	module_ := &Module{}
	mut code := &BinaryFunctionBody{ locals: [BinaryLocals{ count: 2, type_: BinaryValueType{ kind: .i32 } }] }
	mut store := BinaryMachineStore.create()
	assert store.allocate_function(instance, module_, code, 1) == none
	address := store.allocate_function(instance, module_, code, 0)?
	assert address == 0
	contents.functions << address
	assert name_of_webassembly_function(store, address) == '0'
	function := store.get_function(address)?
	assert function is BinaryMachineWasmFunction
	if function is BinaryMachineWasmFunction {
		assert function.type_().parameters == type_.parameters
		assert function.type_().results == type_.results
		assert voidptr(function.defined_type()) == voidptr(canonical)
		assert voidptr(function.module()) == voidptr(instance)
		assert voidptr(function.code()) == voidptr(code)
	}
	code.body.instructions << BinaryInstruction{ opcode: 0x0b }
	// Function entries are values in a vector. Re-query after growth, preserving
	// actual code/module aliases rather than a copied function body.
	for _ in 0 .. 129 { _ := store.allocate_function(instance, module_, code, 0)? }
	retained := store.get_function(address)?
	if retained is BinaryMachineWasmFunction {
		assert retained.code().body.instructions.len == 1
		assert retained.code().locals[0].count == 2
	}
	assert voidptr(store.get_module_for(address)?) == voidptr(module_)
	assert voidptr(store.get_module_instance_for(address)?) == voidptr(instance)
	assert store.get_function(130) == none
	assert store.get_function(~u64(0)) == none
	assert store.get_module_for(130) == none
	assert store.get_module_instance_for(130) == none
	assert voidptr(store.unsafe_get_function(address)) == voidptr(store.get_function(address)?)
}

fn test_machine_host_functions_intern_actual_types_preserve_supplied_type_and_invoke_stored_callable() {
	type_ := BinaryMachineFunctionType{ parameters: [BinaryValueType{ kind: .i32 }], results: [BinaryValueType{ kind: .i64 }] }
	callable := fn (_ voidptr, arguments []BinaryMachineValue) BinaryMachineResult {
		return BinaryMachineResult.from_values([BinaryMachineValue.from_i64(i64(arguments[0].to_i32()))])
	}
	mut store := BinaryMachineStore.create()
	first := store.allocate_host_function(BinaryMachineHostFunction.create(callable, type_, '0'))?
	second := store.allocate_host_function(BinaryMachineHostFunction.create(callable, type_, '1'))?
	assert first == 0 && second == 1
	assert name_of_webassembly_function(store, first) == '0'
	assert name_of_webassembly_function(store, second) == '1'
	mut explicit := BinaryMachineHostFunction.create(callable, BinaryMachineFunctionType{}, '2')
	provided := canonicalize_binary_type(BinaryDefinedType{ kind: .function_ }, BinaryTypeContext{})
	explicit.set_defined_type(provided)
	third := store.allocate_host_function(explicit)?
	assert third == 2
	first_entry := store.get_function(first)?
	second_entry := store.get_function(second)?
	third_entry := store.get_function(third)?
	assert first_entry is BinaryMachineHostFunction && second_entry is BinaryMachineHostFunction && third_entry is BinaryMachineHostFunction
	if first_entry is BinaryMachineHostFunction {
		assert first_entry.name() == '0' && first_entry.type_().parameters == type_.parameters
		actual_type := first_entry.defined_type()
		assert actual_type.sub_type().parameters == type_.parameters
		if second_entry is BinaryMachineHostFunction {
			assert voidptr(second_entry.defined_type()) == voidptr(actual_type)
		}
		mut result := first_entry.function()(unsafe { nil }, [BinaryMachineValue.from_i32(-17)])
		assert !result.is_trap() && result.values().values[0].to_i64() == -17
	}
	if third_entry is BinaryMachineHostFunction {
		assert voidptr(third_entry.defined_type()) == voidptr(provided)
	}
	assert store.get_module_for(first) == none
	assert store.get_module_instance_for(first) == none
}

fn test_machine_function_name_uses_module_function_order_including_host_imports() {
	mut store := BinaryMachineStore.create()
	callable := fn (_ voidptr, _ []BinaryMachineValue) BinaryMachineResult {
		return BinaryMachineResult.from_values([])
	}
	// Unrelated functions already occupy this owning Store.
	_ := store.allocate_host_function(BinaryMachineHostFunction.create(callable, BinaryMachineFunctionType{}, '17'))?
	imported := store.allocate_host_function(BinaryMachineHostFunction.create(callable, BinaryMachineFunctionType{}, '0'))?
	type_ := BinaryDefinedType{ kind: .function_ }
	mut instance := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ types: [type_], functions: [imported] })
	mut contents := instance.contents()
	contents.canonical_types << canonicalize_binary_type(type_, BinaryTypeContext{})
	module_ := &Module{}
	code := &BinaryFunctionBody{}
	defined := store.allocate_function(instance, module_, code, 0)?
	contents.functions << defined
	assert imported == 1 && defined == 2
	assert name_of_webassembly_function(store, imported) == '0'
	assert name_of_webassembly_function(store, defined) == '1'
}
