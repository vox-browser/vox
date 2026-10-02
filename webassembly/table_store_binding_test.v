module webassembly

import webidl

fn test_table_binding_reads_writes_and_grows_actual_store_without_copied_elements() {
	table_ := construct_table_for_realm('actual-table-store', TableDescriptor{
		element: .externref
		initial: 2
		maximum: 4
	}, webidl.platform_object_value_with_id(201))!
	assert table_.address() == 0
	mut store := table_.cache().abstract_machine_.store()
	mut instance := store.get_table(0) or { panic('missing actual Store table') }
	assert instance.type_().limits.minimum == 2
	first := instance.elements().values[0] as BinaryExternReference
	assert table_.cache().get_extern_value(first.address)?.opaque_id == 201
	table_.set(1, webidl.platform_object_value_with_id(202))!
	second := instance.elements().values[1] as BinaryExternReference
	assert first.address != second.address
	instance.set_element(0, second, unsafe { nil })
	assert table_.get(0)!.opaque_id == 202
	assert table_.grow(1, webidl.string_value('new element'))! == 2
	assert instance.elements().values.len == 3
	assert instance.type_().limits.minimum == 3
	assert table_.get(2)!.string_value == 'new element'
	for _ in 0 .. 128 {
		store.allocate_table(BinaryTableType{ element_type: BinaryValueType{ kind: .extern_reference } }) or { panic('allocation failed') }
	}
	// Store tables are source value records: wrappers re-query after growth.
	assert table_.length()! == 3
	assert table_.get(0)!.opaque_id == 202
	table_.set(0, webidl.null_value())!
	mut refreshed := table_.machine_instance()!
	assert refreshed.elements().values[0] is BinaryNullReference
	other := construct_table_for_realm('another-actual-table-store', TableDescriptor{ element: .externref, initial: 1 }, none)!
	assert other.address() == 0
	assert voidptr(other.machine_instance()!) != voidptr(refreshed)
	assert other.get(0)!.kind == .undefined
}

fn test_table_source_wrapping_missing_errors_exn_priority_and_narrowed_growth() {
	cache := WebAssemblyCache.create()
	mut store := cache.abstract_machine_.store()
	address := store.allocate_table(BinaryTableType{
		element_type: BinaryValueType{ kind: .exception_reference }
		limits:       WasmLimits{ minimum: 1 }
	}) or { panic('allocation failed') }
	exn := Table.create_for_store_address(cache, address)
	assert exn.element_type()!.kind == .exception_reference
	if _ := exn.get_reference(u64(-1)) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot get an exnref table element'
	}
	if _ := exn.set(u64(-1), webidl.runtime_value(webidl.RuntimeValue{
		string_conversion: fn () !string { panic('exnref must not coerce its input') }
	})) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Cannot set an exnref table element'
	}
	missing := Table.create_for_store_address(cache, 500)
	if _ := missing.get_reference(0) {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the memory table'
	}
	if _ := missing.grow_reference(0, BinaryNullReference{}) {
		assert false
	} else {
		assert err.msg() == 'RangeError: Could not find the memory table to grow'
	}
	table_ := Table.create_machine(cache, BinaryValueType{ kind: .extern_reference }, .i64,
		1, u64(1), BinaryNullReference{ type_: BinaryValueType{ kind: .extern_reference } })!
	// This narrowing is in pinned Table.cpp -> TableInstance::grow(u32).
	assert table_.grow_reference(u64(1) << 32, BinaryNullReference{})! == 1
	assert table_.length()! == 1
	if _ := table_.grow_reference(1, BinaryNullReference{}) {
		assert false
	} else {
		assert err.msg() == 'RangeError: Failed to grow table'
	}
}

fn test_table_binding_converts_reference_before_bounds_growth_and_allocation_checks() {
	table_ := construct_table_for_realm('actual-table-binding-order', TableDescriptor{ element: .anyfunc, initial: 0, maximum: 0 }, none)!
	if _ := table_.set(5, webidl.string_value('not an exported function')) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	if _ := table_.grow(1, webidl.callback_value()) {
		assert false
	} else {
		assert err.msg() == 'TypeError: anyfunc requires null or an exported function'
	}
	if _ := Table.construct(TableDescriptor{ element: .anyfunc, initial: 2, maximum: 1 }, webidl.callback_value()) {
		assert false
	} else {
		assert err.msg() == 'TypeError: anyfunc requires null or an exported function'
	}
	if _ := Table.construct(TableDescriptor{ element: .externref, initial: machine_max_allowed_table_size + 1 }, none) {
		assert false
	} else {
		assert err.msg() == 'RangeError: Wasm Table allocation failed'
	}
	extern := construct_table_for_realm('actual-table-address-conversion', TableDescriptor{ element: .externref, initial: 1 }, none)!
	extern.set_from_bindings(webidl.string_value('0.9'), webidl.string_value('source conversion'))!
	assert extern.get_from_bindings(webidl.boolean_value(false))!.string_value == 'source conversion'
	assert extern.grow_from_bindings(webidl.number_value(1.9), webidl.null_value())!.number_value == 1
	assert extern.length_from_bindings()!.number_value == 2
	assert extern.get(1)!.kind == .null_
	if _ := extern.get_from_bindings(webidl.number_value(-1)) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}
