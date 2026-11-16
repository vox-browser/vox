module libjs

import platform

fn test_dispatch_borrows_instructions_without_per_step_retained_allocations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	executable := &Executable{
		registers_and_locals_count: 6
		constants:                  [Value.from_i32(42)]
		instructions:               [
			Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.constant(0) },
			Instruction{ op: .end, lhs: Operand.register(5) },
		]
		bytecode_length:            2
	}
	executable.validate(0)!
	mut frame := ExecutionContext.create(6, executable.constants, 0)
	frame.realm = vm.realm()
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	mut invocation := NativeInvocation{ vm: vm, executable: executable }
	for native_fallback in [false, true] {
		frame.program_counter = 0
		assert vm.execute_instruction(&executable.instructions[0], executable)! == 1
		before := platform.thread_arena_usage().used
		for _ in 0 .. 100000 {
			if native_fallback {
				assert native_slow_step(voidptr(&invocation), 0) == 1
			} else {
				frame.program_counter = 0
				assert vm.execute_instruction(&executable.instructions[0], executable)! == 1
			}
		}
		growth := platform.thread_arena_usage().used - before
		assert frame.values[5].as_i32() == 42
		assert invocation.failure == none && !invocation.ended
		$if prealloc {
			assert growth < 4096, 'dispatch retained ${growth} bytes'
		}
	}
}
