module webassembly

fn table_validation_module(table []u8, with_defined_global bool, imported_mutable u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 2, 6, 1, 0, 0, 3, 0x6f, imported_mutable,
		4, u8(table.len + 1), 1]
	bytes << table
	if with_defined_global { bytes << [u8(6), 6, 1, 0x6f, 0, 0xd0, 0x6f, 0x0b] }
	return bytes
}

fn test_table_initializers_validate_nullable_implicit_values_and_imported_immutable_reads() {
	for table in [[u8(0x6f), 0, 0], [u8(0x40), 0, 0x6f, 0, 0, 0x23, 0, 0x0b]] {
		compiled := compile_module(table_validation_module(table, true, 0))!
		assert compiled.table_definitions[0].initializer.stack_usage_hint? == 1
		mut restored := Module.create_for_serialization()
		restored.deserialization_steps(compiled.serialization_steps(false)!)!
		assert restored.table_definitions == compiled.table_definitions
	}
}

fn test_table_initializers_reject_defined_global_reads_nonnullable_defaults_and_nonconstant_or_surplus_values() {
	for table in [
		[u8(0x40), 0, 0x6f, 0, 0, 0x23, 1, 0x0b],
		[u8(0x64), 0x6f, 0, 0],
		[u8(0x40), 0, 0x64, 0x6f, 0, 0, 0xd0, 0x6f, 0x0b],
		[u8(0x40), 0, 0x6f, 0, 0, 0x41, 0, 0x0b],
		[u8(0x40), 0, 0x6f, 0, 0, 0xd0, 0x6f, 0x01, 0x0b],
		[u8(0x40), 0, 0x6f, 0, 0, 0xd0, 0x6f, 0xd0, 0x6f, 0x0b],
	] {
		if _ := compile_module(table_validation_module(table, true, 0)) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
	if _ := compile_module(table_validation_module([u8(0x40), 0, 0x6f, 0, 0, 0x23, 0, 0x0b], false, 1)) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid table initializer'
	}
}
