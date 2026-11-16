module libjs

import dl
import os
import platform
import rand

fn test_native_compile_batches_reclaim_source_work_and_keep_loaded_entries() {
	directory := os.join_path(os.temp_dir(), 'vox-native-workspace-' + rand.uuid_v4())
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	mut instructions := []Instruction{}
	for _ in 0 .. 2048 { instructions << Instruction{ op: .nop } }
	instructions << Instruction{ op: .end, lhs: Operand.constant(0) }
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		instructions:               instructions
		bytecode_length:            u32(instructions.len)
	}
	executable.validate(0)!
	first := native_compile_library([executable], directory, '/usr/bin/clang')!
	dl.close(first.handle)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 32 {
		compiled := native_compile_library([executable], directory, '/usr/bin/false')!
		assert compiled.stats.cache_hit
		assert os.is_file(compiled.stats.library)
		assert compiled.stats.library_sha256.len == 64
		// Reuse temporary storage before consuming the returned array/strings.
		scratch := platform.begin_thread_scratch('native compilation result lifetime')
		_ := []u8{len: 1024 * 1024, init: 0xa5}
		scratch.finish()
		mut values := []Value{len: 6}
		values[5] = Value.from_i32(42)
		mut pc := u32(0)
		mut budget := u64(10000)
		mut steps := u64(0)
		compiled.entries[0](unsafe { nil }, values.data, &budget, 1, &pc,
			native_slow_step, &steps)
		assert pc == 0xfffffffe && steps == 2049
		assert values[register_return_value].as_i32() == 42
		dl.close(compiled.handle)
	}
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth < 512 * 1024, 'native compilation retained ${growth} bytes'
	}
}

fn test_native_compile_failure_message_outlives_its_workspace() {
	directory := os.join_path(os.temp_dir(), 'vox-native-workspace-error-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		instructions:               [Instruction{ op: .end, lhs: Operand.constant(0) }]
		bytecode_length:            1
	}
	executable.validate(0)!
	if _ := native_compile_library([executable], directory, '/usr/bin/false') {
		assert false, 'A failed compiler must leave an owned error'
	} else {
		scratch := platform.begin_thread_scratch('native compilation error lifetime')
		_ := []u8{len: 1024 * 1024, init: 0xa5}
		scratch.finish()
		assert err.msg().starts_with('Native compiler exited 1:')
	}
}
