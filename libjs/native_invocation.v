module libjs

fn (mut stack InterpreterStack) acquire_native_invocation(vm &VM, executable &Executable) &NativeInvocation {
	if stack.native_depth == stack.native_calls.len {
		stack.native_calls << &NativeInvocation{ vm: vm, executable: executable, property_read_step: voidptr(native_property_step), primitive_type_names: if vm.native_type_names.len == 7 { vm.native_type_names.data } else { unsafe { nil } } }
	}
	invocation := stack.native_calls[stack.native_depth]
	unsafe { *invocation = NativeInvocation{ vm: vm, executable: executable, property_read_step: voidptr(native_property_step), primitive_type_names: if vm.native_type_names.len == 7 { vm.native_type_names.data } else { unsafe { nil } } } }
	stack.native_depth++
	return invocation
}

fn (mut stack InterpreterStack) release_native_invocation(invocation &NativeInvocation) {
	if stack.native_depth <= 0 || voidptr(stack.native_calls[stack.native_depth - 1]) != voidptr(invocation) {
		panic('Native invocation records must be released in call order')
	}
	stack.native_depth--
	// Do not keep the last source graph or thrown value alive between calls.
	unsafe { *invocation = NativeInvocation{ vm: nil, executable: nil } }
}

fn (mut vm VM) invoke_native_entry(entry NativeEntry, executable &Executable, fast_steps &u64) !Value {
	mut frame := vm.current_context()
	// Generated code only uses its opaque callback state during this call,
	// including nested calls and exits at throws/await/yield. Reuse one stable
	// record per active native depth; nested entries get independent records.
	mut stack := vm.interpreter_stack()
	invocation := stack.acquire_native_invocation(&vm, executable)
	defer { stack.release_native_invocation(invocation) }
	entry(voidptr(invocation), frame.values.data, &vm.instruction_budget,
		u8(vm.instruction_budget_active), &frame.program_counter, native_slow_step, fast_steps)
	if failure := invocation.failure { return failure }
	if frame.program_counter == 0xfffffffe {
		frame.program_counter = executable.bytecode_length
		return vm.reg(register_return_value)
	}
	if invocation.ended { return vm.reg(register_return_value) }
	return vm.throw_error(.internal_error, 'Bytecode fell off the end without End')
}
