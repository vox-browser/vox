module webassembly

import webidl

fn host_add_one(arguments []webidl.Value) !webidl.Value {
	return webidl.number_value(arguments[0].number_value + 1)
}

fn host_pair(arguments []webidl.Value) !webidl.Value {
	return webidl.sequence_value([
		webidl.number_value(arguments[0].number_value),
		webidl.bigint_value(arguments[1].bigint_value),
	])
}

fn host_wrong_result_count(_ []webidl.Value) !webidl.Value {
	return webidl.sequence_value([webidl.number_value(1)])
}

fn host_trap(_ []webidl.Value) !webidl.Value {
	return error('host callback trapped')
}

fn test_global_value_types_defaults_mutability_and_conversion() {
	mut global := Global.construct(GlobalDescriptor{ value: .i32, mutable_: true },
		webidl.number_value(4))!
	assert global.value()!.number_value == 4
	global.set_value(webidl.number_value(7.9))!
	assert global.value_of()!.number_value == 7
	mut constant := Global.construct(GlobalDescriptor{ value: .f64 }, none)!
	assert constant.value()!.number_value == 0
	if _ := constant.set_value(webidl.number_value(1)) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	if _ := Global.construct(GlobalDescriptor{ value: .v128 }, none) {
		assert false
	} else {
		assert err.msg().contains('V128')
	}
}

fn test_global_creation_exposes_type_and_cache_metadata() {
	descriptor := global_descriptor_from_bindings(GlobalDescriptor{
		value:    .i64
		mutable_: true
	})
	mut global := construct_global(descriptor, webidl.bigint_value(12))!
	assert global.type()! == BinaryGlobalType{
		type_:    BinaryValueType{ kind: .i64 }
		mutable_: true
	}
	assert global.value_type()!.kind == .i64
	assert global.cache().get_global_instance(global.address())? == global

	direct := Global.create(GlobalDescriptor{ value: .i32 }, WasmValue{
		type_:     .i32
		i32_value: 7
	})!
	assert direct.value()!.number_value == 7
	if _ := Global.create(GlobalDescriptor{ value: .f64 }, WasmValue{ type_: .i32 }) {
		assert false
	} else {
		assert err.msg().contains('does not match')
	}
}

fn test_global_keeps_the_cache_that_owns_its_address() {
	global := construct_global_for_realm('global-owner-realm', GlobalDescriptor{
		value: .i32
	}, webidl.number_value(42))!
	owner_cache := get_cache_for_realm('global-owner-realm')
	assert voidptr(global.cache()) == voidptr(owner_cache)
	assert voidptr(global.cache()) != voidptr(get_cache_for_realm('global-other-realm'))
	assert voidptr(owner_cache.get_global_instance(global.address()) or {
		panic('global was not registered in its owner cache')
	}) == voidptr(global)
}

fn test_i64_uses_bigint_and_externref_defaults_to_undefined() {
	global := Global.construct(GlobalDescriptor{ value: .i64 }, webidl.bigint_value(-42))!
	assert global.value()!.kind == .bigint
	assert global.value()!.bigint_value == -42
	if _ := Global.construct(GlobalDescriptor{ value: .i64 }, webidl.number_value(42)) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	extern_global := Global.construct(GlobalDescriptor{ value: .externref }, none)!
	assert extern_global.value()!.kind == .undefined
	extern_table := Table.construct(TableDescriptor{ element: .externref, initial: 1 }, none)!
	assert extern_table.get(0)!.kind == .undefined
}

fn test_table_bounds_grow_and_anyfunc_validation() {
	mut table_ := Table.construct(TableDescriptor{ element: .externref, initial: 2, maximum: 3 },
		webidl.string_value('x'))!
	assert table_.length()! == 2
	assert table_.get(1)!.string_value == 'x'
	table_.set(0, webidl.number_value(9))!
	assert table_.get(0)!.number_value == 9
	assert table_.grow(1, webidl.null_value())! == 2
	if _ := table_.grow(1, none) {
		assert false
	} else {
		assert err.msg().starts_with('RangeError:')
	}
	if _ := Table.construct(TableDescriptor{ element: .anyfunc, initial: 1 },
		webidl.string_value('not callable'))
	{
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_table64_address_values_and_binding_conversions() {
	mut table64 := construct_table(TableDescriptor{
		element: .externref
		initial: 2
		maximum: 4
		address: .i64
	}, webidl.string_value('initial'))!
	assert table64.address_type()! == .i64
	assert table64.element_type()!.kind == .extern_reference
	assert address_type_from_bindings(.i64) == .i64
	assert address_value_to_u64(webidl.bigint_value(3), .i64)! == 3
	assert table_limit_to_js_value(table64.length()!, .i64).bigint_value == 2
	assert table(table64) == table64
	default_reference := value_to_table_reference(table64, none)! as BinaryExternReference
	assert table64.cache().get_extern_value(default_reference.address)?.kind == .undefined
	assert table64.grow(1, none)! == 2
	assert table64.length()! == 3

	if _ := address_value_to_u64(webidl.number_value(1), .i64) {
		assert false
	} else {
		assert err.msg().contains('BigInt')
	}
	if _ := address_value_to_u64(webidl.bigint_value(-1), .i64) {
		assert false
	} else {
		assert err.msg().contains('non-negative')
	}
	assert address_value_to_u64(webidl.number_value(1.5), .i32)! == 1
}

fn test_table_keeps_the_cache_that_owns_its_address() {
	table_ := construct_table_for_realm('table-owner-realm', TableDescriptor{
		element: .externref
		initial: 1
	}, none)!
	owner_cache := get_cache_for_realm('table-owner-realm')
	assert voidptr(table_.cache()) == voidptr(owner_cache)
	assert voidptr(table_.cache()) != voidptr(get_cache_for_realm('table-other-realm'))
	assert voidptr(owner_cache.get_table_instance(table_.address()) or {
		panic('table was not registered in its owner cache')
	}) == voidptr(table_)
	assert owner_cache.table_instances().len == 1
}

fn test_cache_identity_conversions_and_constructor_entry_points() {
	mut cache := WebAssemblyCache.create()
	function := ExportedWasmFunction.create('answer', 17)
	cache.add_function_instance(17, function)
	assert (cache.get_function_instance(17) or { panic('missing function') }).exported_address() == 17
	cache.add_extern_value(3, webidl.string_value('external'))
	assert (cache.get_extern_value(3) or { panic('missing extern') }).string_value == 'external'
	assert cache.inverse_extern_values()['string_:external'] == 3
	global := Global.construct_impl(GlobalDescriptor{ value: .i32 }, webidl.number_value(9))!
	memory := Memory.construct_impl(MemoryDescriptor{ initial: 1, maximum: 2 })!
	cache.add_global_instance(global.address(), global)
	cache.add_memory_instance(memory.address(), memory)
	assert cache.get_global_instance(global.address()) != none
	assert cache.get_memory_instance(memory.address()) != none
	assert to_value_type(.anyfunc) == .anyfunc
	assert table_kind_to_value_type(.externref) == .externref
	assert to_js_value(WasmValue{ type_: .i64, i64_value: 5 })!.bigint_value == 5
	assert memory.buffer_object().bytes().size == uint(page_size)
	assert memory.create_a_fixed_length_memory_buffer().resizable == false
	assert memory.create_a_resizable_memory_buffer(u64(2 * page_size))!.resizable
}

fn test_host_function_converts_single_and_multiple_values() {
	single := create_host_function('host-function-realm', host_add_one, FunctionType{
		parameters: [.i32]
		results: [.i32]
	}, 4)
	assert single.realm == 'host-function-realm'
	assert single.function_index == 4
	single_result := single.invoke([WasmValue{ type_: .i32, i32_value: 6 }])!
	assert single_result.len == 1
	assert single_result[0].i32_value == 7

	multiple := create_host_function('host-function-realm', host_pair, FunctionType{
		parameters: [.f64, .i64]
		results: [.f64, .i64]
	}, 5)
	multiple_result := multiple.invoke([
		WasmValue{ type_: .f64, f64_value: 1.5 },
		WasmValue{ type_: .i64, i64_value: 9 },
	])!
	assert multiple_result.len == 2
	assert multiple_result[0].f64_value == 1.5
	assert multiple_result[1].i64_value == 9
}

fn test_host_function_reports_conversion_and_callback_traps() {
	wrong_count := create_host_function('', host_wrong_result_count, FunctionType{
		results: [.i32, .i32]
	}, 0)
	if _ := wrong_count.invoke([]WasmValue{}) {
		assert false
	} else {
		assert err.msg().contains('Invalid number of return values')
	}
	trapping := create_host_function('', host_trap, FunctionType{}, 1)
	if _ := trapping.invoke([]WasmValue{}) {
		assert false
	} else {
		assert err.msg() == 'host callback trapped'
	}
	if _ := create_host_function('', host_add_one, FunctionType{
		parameters: [.i32]
		results: [.i32]
	}, 2).invoke([]WasmValue{}) {
		assert false
	} else {
		assert err.msg().contains('expected 1 arguments')
	}
}
