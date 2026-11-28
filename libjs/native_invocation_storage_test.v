module libjs

import dl
import os
import platform
import rand

fn test_native_entry_callback_state_does_not_accumulate_per_function_call() {
	directory := os.join_path(os.temp_dir(), 'vox-native-invocation-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		instructions:               [Instruction{ op: .end, lhs: Operand.constant(0) }]
		bytecode_length:            1
	}
	executable.validate(0)!
	compiled := native_compile_library([executable], directory, '/usr/bin/clang')!
	defer { dl.close(compiled.handle) }
	mut frame := ExecutionContext.create(5, executable.constants, 0)
	frame.realm = vm.realm()
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	assert vm.invoke_native_entry(compiled.entries[0], executable, unsafe { nil })!.as_i32() == 42
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100000 {
		frame.program_counter = 0
		assert vm.invoke_native_entry(compiled.entries[0], executable, unsafe { nil })!.as_i32() == 42
		assert frame.program_counter == executable.bytecode_length
	}
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth < 4096, 'native callback state retained ${growth} bytes'
	}
}

fn test_native_invocation_records_restore_nested_exception_and_return_state() {
	directory := os.join_path(os.temp_dir(), 'vox-native-nested-invocation-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.profile_native_code()!
	defer { vm.close_native_code() or {} }
	mut warm := Script.parse('function inner(n){if(n)throw n;return 42}function outer(n){try{return inner(n)}catch(e){return e}}outer(7)', vm.realm(), 'native-nested.js', unsafe { nil })!
	assert vm.run_with_limits(mut warm, ExecutionLimits{ max_instructions: 100000 })!.number == 7
	vm.compile_native_code(directory, '/usr/bin/clang', 1)!
	for source in ['outer(7)', 'outer(0)', 'outer(7)'] {
		mut script := Script.parse(source, vm.realm(), 'native-nested-call.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!.number == if source == 'outer(0)' {
			f64(42)
		} else {
			f64(7)
		}
		assert vm.interpreter_stack().native_depth == 0
	}
	assert vm.interpreter_stack().native_calls.len >= 2
}
