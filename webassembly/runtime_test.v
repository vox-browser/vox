module webassembly

import webidl

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
	mut table := Table.construct(TableDescriptor{ element: .externref, initial: 2, maximum: 3 },
		webidl.string_value('x'))!
	assert table.length() == 2
	assert table.get(1)!.string_value == 'x'
	table.set(0, webidl.number_value(9))!
	assert table.get(0)!.number_value == 9
	assert table.grow(1, webidl.null_value())! == 2
	if _ := table.grow(1, none) {
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
	assert memory.buffer_object().bytes.len == page_size
	assert memory.create_a_fixed_length_memory_buffer().resizable == false
	assert memory.create_a_resizable_memory_buffer(u64(2 * page_size))!.resizable
}
