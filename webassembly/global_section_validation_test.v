module webassembly

fn global_validation_module(globals []u8, imported_mutable u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 2, 6, 1, 0, 0, 3, 0x7f, imported_mutable,
		6, u8(globals.len)]
	bytes << globals
	return bytes
}

fn test_global_initializers_see_imports_and_preceding_immutable_definitions_in_source_order() {
	compiled := compile_module(global_validation_module([u8(3), 0x7f, 0, 0x23, 0, 0x41, 2, 0x6a,
		0x0b, 0x7f, 1, 0x23, 1, 0x0b, 0x6f, 0, 0xd0, 0x6f, 0x0b], 0))!
	assert compiled.global_definitions[0].initializer.stack_usage_hint? == 2
	assert compiled.global_definitions[1].initializer.stack_usage_hint? == 1
	assert compiled.global_definitions[2].initializer.stack_usage_hint? == 1
	context := build_binary_validation_context(compiled)!
	assert context.globals.len == 4 && context.globals_without_internal_globals.len == 1
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.global_definitions == compiled.global_definitions
}

fn test_global_initializers_reject_mutable_reads_self_forward_wrong_types_surplus_and_nonconstant() {
	for globals in [
		[u8(1), 0x7f, 0, 0x23, 1, 0x0b],
		[u8(2), 0x7f, 0, 0x23, 2, 0x0b, 0x7f, 0, 0x41, 0, 0x0b],
		[u8(1), 0x7f, 0, 0x42, 0, 0x0b],
		[u8(1), 0x7f, 0, 0x41, 0, 0x41, 1, 0x0b],
		[u8(1), 0x7f, 0, 0x41, 0, 0x01, 0x0b],
		[u8(1), 0x64, 0x6f, 0, 0xd0, 0x6f, 0x0b],
		[u8(2), 0x7f, 1, 0x41, 0, 0x0b, 0x7f, 0, 0x23, 1, 0x0b],
	] {
		if _ := compile_module(global_validation_module(globals, 0)) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
	if _ := compile_module(global_validation_module([u8(1), 0x7f, 0, 0x23, 0, 0x0b], 1)) {
		assert false
	} else {
		assert err.msg() == 'CompileError: invalid global variable initializer'
	}
}
