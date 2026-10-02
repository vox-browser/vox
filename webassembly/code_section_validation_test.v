module webassembly

fn code_validation_module(signature []u8, body []u8, imported bool) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 1, u8(signature.len + 2), 1, 0x60]
	bytes << signature
	if imported { bytes << [u8(2), 5, 1, 0, 0, 0, 0] }
	bytes << [u8(3), 2, 1, 0, 10, u8(body.len + 2), 1, u8(body.len)]
	bytes << body
	return bytes
}

fn test_function_validation_uses_signature_parameters_and_local_defaultability_with_import_offset() {
	compiled := compile_module(code_validation_module([u8(1), 0x64, 0x6f, 1, 0x64, 0x6f],
		[u8(1), 1, 0x64, 0x6f, 0x20, 0, 0x21, 1, 0x20, 1, 0x0b], true))!
	assert compiled.function_bodies[0].body.stack_usage_hint? == 1
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.function_bodies == compiled.function_bodies
	for type_ in [u8(0x7f), 0x7e, 0x7d, 0x7c, 0x7b, 0x6f] {
		valid := compile_module(code_validation_module([u8(0), 1, type_], [u8(1), 1, type_, 0x20,
			0, 0x0b], false))!
		assert valid.function_bodies[0].body.stack_usage_hint? == 1
	}
}

fn test_function_validation_enforces_nonnullable_local_initialization_and_block_rollback() {
	signature := [u8(1), 0x64, 0x6f, 1, 0x64, 0x6f]
	for body in [
		[u8(1), 1, 0x64, 0x6f, 0x20, 1, 0x0b],
		[u8(1), 1, 0x64, 0x6f, 0x02, 0x40, 0x20, 0, 0x21, 1, 0x0b, 0x20, 1, 0x0b],
	] {
		if _ := compile_module(code_validation_module(signature, body, false)) {
			assert false
		} else {
			assert err.msg().contains('uninitialized non-defaultable local')
		}
	}
	valid := compile_module(code_validation_module(signature,
		[u8(1), 1, 0x64, 0x6f, 0x20, 0, 0x22, 1, 0x0b], false))!
	assert valid.function_bodies[0].body.stack_usage_hint? == 1
}

fn test_function_validation_rejects_unknown_local_type_and_signature_result_errors() {
	for body in [
		[u8(0), 0x0b],
		[u8(0), 0x42, 0, 0x0b],
		[u8(0), 0x41, 0, 0x41, 1, 0x0b],
		[u8(1), 1, 0x63, 1, 0x41, 0, 0x0b],
		[u8(0), 0x20, 0, 0x0b],
		[u8(0), 0x41, 0, 0x04, 0x7f, 0x41, 1, 0x0b, 0x0b],
	] {
		if _ := compile_module(code_validation_module([u8(0), 1, 0x7f], body, false)) {
			assert false
		} else {
			assert err.msg().starts_with('CompileError:')
		}
	}
	valid := compile_module(code_validation_module([u8(0), 1, 0x7f], [u8(0), 0x00, 0x0b], false))!
	assert valid.function_bodies[0].body.stack_usage_hint? == 1
}
