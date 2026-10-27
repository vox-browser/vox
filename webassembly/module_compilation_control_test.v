module webassembly

fn source_try_begin_compilation(compiled &Module) bool {
	return compiled.try_begin_cranelift_compilation()
}

fn source_wait_for_compilation_metadata(compiled &Module) uint {
	compiled.wait_for_cranelift_compilation()
	assert compiled.has_attempted_cranelift_compilation()
	return compiled.function_bodies[0].body.compiled_instructions.max_call_rec_size
}

fn test_source_module_compilation_state_is_owned_and_has_one_atomic_starter() {
	mut compiled := &Module{}
	mut other := &Module{}
	defer { compiled.destroy_compilation_control() }
	defer { other.destroy_compilation_control() }
	assert voidptr(compiled.cranelift_compilation_) != voidptr(other.cranelift_compilation_)
	assert !compiled.has_attempted_cranelift_compilation()
	compiled.wait_for_cranelift_compilation() // Source returns immediately at 0.
	mut starters := []thread bool{}
	for _ in 0 .. 16 { starters << spawn source_try_begin_compilation(compiled) }
	mut successes := 0
	for starter in starters {
		if starter.wait() { successes++ }
	}
	assert successes == 1
	assert !compiled.has_attempted_cranelift_compilation()
	assert !compiled.try_begin_cranelift_compilation()
	assert !other.has_attempted_cranelift_compilation()
	compiled.finish_cranelift_compilation()
	assert compiled.has_attempted_cranelift_compilation()
	assert !compiled.try_begin_cranelift_compilation()
	compiled.wait_for_cranelift_compilation() // Source returns immediately at 2.
}

fn test_source_module_compilation_waiters_observe_real_metadata_after_broadcast() {
	mut compiled := &Module{ function_bodies: [BinaryFunctionBody{}] }
	defer { compiled.destroy_compilation_control() }
	started := compiled.try_begin_cranelift_compilation()
	assert started
	mut consumers := []thread uint{}
	for _ in 0 .. 16 { consumers << spawn source_wait_for_compilation_metadata(compiled) }
	compiled.function_bodies[0].body.compiled_instructions.max_call_rec_size = 83
	compiled.finish_cranelift_compilation()
	for consumer in consumers {
		assert consumer.wait() == 83
	}
}

fn test_source_module_deserialization_installs_fresh_compilation_state() {
	mut compiled := &Module{}
	old_control := compiled.cranelift_compilation_
	compiled.finish_cranelift_compilation()
	assert compiled.has_attempted_cranelift_compilation()
	compiled.deserialization_steps(SerializedModule{ bytes: [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0,
		0] })!
	assert voidptr(compiled.cranelift_compilation_) != voidptr(old_control)
	assert !compiled.has_attempted_cranelift_compilation()
	assert compiled.try_begin_cranelift_compilation()
	compiled.finish_cranelift_compilation()
	compiled.destroy_compilation_control()
	// The older wrapper/Module conflation has no automatic ref-counted release.
	C.vox_wasm_module_compilation_control_destroy(old_control.native)
}
