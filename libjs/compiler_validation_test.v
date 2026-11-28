module libjs

fn compiler_validation_script(mut vm VM, source string) !&Executable {
	mut script := Script.parse(source, vm.realm(), 'compiler-validation.js', unsafe { nil })!
	return script.compile(mut vm)
}

fn invalidate_compiler_validation_operand(mut executable Executable) {
	executable.instructions[0] = Instruction{
		op:  .mov
		dst: Operand.register(0)
		lhs: Operand.constant(u32(executable.constants.len))
	}
}

fn test_compiler_validation_requires_explicit_current_owner_and_compiler_finalization() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert vm.compiler_validation_owner == none
	old := compiler_validation_script(mut vm, '42')!
	assert old.compiler_validation == none
	vm.use_immutable_compiler_executables(true)!
	vm.validate_execution(old, 0)!
	assert old.compiler_validation == none
	executable := compiler_validation_script(mut vm, '43')!
	assert executable.compiler_validation != none
	vm.profile_native_code()!
	vm.diagnose_native_code(true)!
	vm.validate_execution(executable, 0)!
	vm.validate_execution(executable, 3)!
	assert vm.diagnose_native_code(false)!.compiler_validation_hits == 2
	mut roots := HeapRoots{}
	vm.gather_roots(mut roots)
	assert roots.contains(voidptr(vm.compiler_validation_owner or { panic('Missing ownership token') }))
}

fn test_disabling_and_reenabling_compiler_validation_revokes_older_tokens() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.use_immutable_compiler_executables(true)!
	mut executable := compiler_validation_script(mut vm, '42')!
	previous := vm.compiler_validation_owner or { panic('Missing owner') }
	vm.validate_execution(executable, 0)!
	vm.use_immutable_compiler_executables(false)!
	invalidate_compiler_validation_operand(mut executable)
	if _ := vm.validate_execution(executable, 0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
	vm.use_immutable_compiler_executables(true)!
	current := vm.compiler_validation_owner or { panic('Missing replacement owner') }
	assert voidptr(previous) != voidptr(current)
	if _ := vm.validate_execution(executable, 0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
	new_executable := compiler_validation_script(mut vm, '44')!
	vm.validate_execution(new_executable, 0)!
}

fn test_compiler_ownership_does_not_trust_handbuilt_or_other_vm_bytecode() {
	mut first := VM.create()
	create_simple_execution_context(mut first)
	first.use_immutable_compiler_executables(true)!
	mut executable := compiler_validation_script(mut first, '42')!
	first.use_immutable_compiler_executables(false)!
	invalidate_compiler_validation_operand(mut executable)
	mut second := VM.create()
	create_simple_execution_context(mut second)
	second.use_immutable_compiler_executables(true)!
	if _ := second.validate_execution(executable, 0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
	handbuilt := &Executable{
		registers_and_locals_count: reserved_register_count
		bytecode_length:            1
		instructions:               [Instruction{ op: .end, lhs: Operand.constant(0) }]
	}
	if _ := second.validate_execution(handbuilt, 0) {
		assert false
	} else {
		assert err.msg().contains('Constant out of range')
	}
}

fn test_compiler_ownership_keeps_instruction_limits_and_idle_switch_guards() {
	for enabled in [false, true] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.use_immutable_compiler_executables(enabled)!
		mut script := Script.parse('function f(){return 1}var x=0;while(true){x+=f()}', vm.realm(), 'compiler-limit.js', unsafe { nil })!
		if _ := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100 }) {
			assert false
		}
		assert vm.interpreter_stack().depth() == 0
		vm.run_executable_depth = 1
		if _ := vm.use_immutable_compiler_executables(!enabled) {
			assert false
		}
		vm.run_executable_depth = 0
	}
}
