module webassembly

fn test_machine_tag_store_retains_signature_and_actual_canonical_identity() {
	mut store := BinaryMachineStore.create()
	parameters := [BinaryValueType{ kind: .i64 }, BinaryValueType{ kind: .extern_reference }]
	canonical := canonicalize_binary_type(BinaryDefinedType{ kind: .function_, parameters: parameters, rec_group: BinaryRecGroupSpan{ count: 1 } }, BinaryTypeContext{})
	type_ := BinaryMachineFunctionType{ parameters: parameters }
	first := store.allocate_tag(type_, canonical, 0) or { panic('allocation failed') }
	second := store.allocate_tag(type_, canonical, 0) or { panic('allocation failed') }
	assert first == 0 && second == 1
	tag := store.get_tag(first) or { panic('missing tag') }
	assert tag.type_().parameters == parameters && tag.type_().results.len == 0
	assert voidptr(tag.defined_type()) == voidptr(canonical) && tag.flags() == 0
	assert store.get_tag(2) == none && store.get_tag(u64(-1)) == none
}

fn test_machine_exception_store_retains_untyped_parameter_bits_and_uncaught_address() {
	mut store := BinaryMachineStore.create()
	params := [BinaryMachineValue.from_i64(-17),
		BinaryMachineValue.from_reference(BinaryExternReference{ address: 29 }),
		BinaryMachineValue{ low: 0x7ff8000000001234 }]
	first := store.allocate_exception(11, params) or { panic('allocation failed') }
	second := store.allocate_exception(12, []BinaryMachineValue{}) or { panic('allocation failed') }
	assert first == 0 && second == 1
	exception := store.get_exception(first) or { panic('missing exception') }
	assert exception.tag() == 11 && exception.params() == params
	empty := store.get_exception(second) or { panic('missing exception') }
	assert empty.tag() == 12 && empty.params().len == 0
	assert store.exceptions().len == 2
	assert store.get_exception(2) == none && store.get_exception(u64(-1)) == none
	mut result := BinaryMachineResult.from_trap(BinaryMachineTrap{ data: BinaryUncaughtException{ address: first } })
	assert result.is_trap() && result.trap().format() == 'uncaught exception'
	trap_data := result.trap().data
	if trap_data is BinaryUncaughtException {
		retained := store.get_exception(trap_data.address) or { panic('lost uncaught exception') }
		assert retained.params() == params
	} else {
		assert false
	}
}
