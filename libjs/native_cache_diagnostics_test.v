// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn test_pending_cache_diagnostics_are_bounded_read_only_source_identities() {
	directory := os.join_path(os.temp_dir(), 'vox-cache-identities-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.enable_native_code_cache(directory, '/usr/bin/false')!
	mut script := Script.parse('function named(){return 42}named()', vm.realm(), 'identities.js', unsafe { nil })!
	assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.number == 42
	before := vm.native_code_cache_stats()
	assert vm.pending_native_code_cache_diagnostics(0).len == 0
	assert vm.pending_native_code_cache_diagnostics(1).len == 1
	entries := vm.pending_native_code_cache_diagnostics(16)
	assert entries.len == 2
	for entry in entries {
		assert entry.key.len == 64 && entry.filename == 'identities.js' && entry.instructions > 0 && entry.scope != ''
	}
	assert entries.any(it.name == 'named')
	after := vm.native_code_cache_stats()
	assert before.cache_misses == after.cache_misses && after.compiler_invocations == 0 && after.pending_executables == 2
	vm.close_native_code()!
}
