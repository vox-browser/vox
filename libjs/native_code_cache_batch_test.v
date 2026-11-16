// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn test_native_cache_batches_leave_later_functions_pending_and_full_flush_finishes_them() {
	directory := os.join_path(os.temp_dir(), 'vox-native-batches-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut source := ''
	for i in 0 .. 140 { source += 'function f${i}(){return ${i}};f${i}();' }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		mut script := Script.parse(source, vm.realm(), 'batched.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!.number == 139
		if visit == 0 {
			first := vm.flush_native_code_cache_batch()!
			assert first.compiler_invocations == 1 && first.compiled_executables == 128 && first.pending_executables == 13
			last := vm.flush_native_code_cache()!
			assert last.compiler_invocations == 2 && last.compiled_executables == 141 && last.pending_executables == 0
		} else {
			stats := vm.flush_native_code_cache()!
			assert stats.cache_hits == 141 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && stats.pending_executables == 0
		}
		vm.close_native_code()!
	}
}
