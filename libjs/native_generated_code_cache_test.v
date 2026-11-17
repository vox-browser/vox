// SPDX-License-Identifier: BSD-2-Clause
module libjs

import crypto.sha256
import os
import platform
import rand

fn test_generated_code_cache_reuses_current_constants_after_source_and_url_change() {
	directory := os.join_path(os.temp_dir(), 'vox-generated-revisit-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache_with_options(directory,
			if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' },
			NativeCodeCacheOptions{ generated_code_identity: true })!
		vm.diagnose_native_code(true)!
		value := if visit == 0 { 41 } else { 99 }
		mut script := Script.parse('function read(o){return o.x}read({x:${value}})',
			vm.realm(), 'https://example.com/bundle-${visit}.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.number == value
		stats := vm.flush_native_code_cache()!
		assert stats.identity_kind == 'generated-code'
		if visit == 1 {
			assert stats.cache_hits > 0 && stats.cache_misses == 0
			assert stats.compiler_invocations == 0 && stats.pending_executables == 0
			assert stats.last_error == '' && vm.diagnose_native_code(false)!.entries > 0
		}
		vm.close_native_code()!
	}
}

fn test_generated_code_identity_includes_fast_instruction_semantics_and_operand_slots() {
	first := &Executable{
		registers_and_locals_count: 6
		constants:                  [Value.from_i32(42)]
		instructions:               [
			Instruction{ op: .mov, dst: Operand.register(5), lhs: Operand.constant(0) },
			Instruction{ op: .end, lhs: Operand.register(5) },
		]
		bytecode_length:            2
	}
	second := &Executable{ ...*first, constants: [Value.from_i32(99)] }
	assert native_generated_code_identity(first)! == native_generated_code_identity(second)!
	changed := &Executable{
		...*first
		instructions: [
			Instruction{ op: .increment, dst: Operand.register(5), lhs: Operand.constant(0) },
			Instruction{ op: .end, lhs: Operand.register(5) },
		]
	}
	assert native_generated_code_identity(first)! != native_generated_code_identity(changed)!
	different_slot := &Executable{ ...*first, registers_and_locals_count: 7 }
	assert native_generated_code_identity(first)! != native_generated_code_identity(different_slot)!
}

fn test_generated_code_identity_matches_portable_sha256_of_the_emitted_source() {
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		instructions:               [Instruction{op: .end, lhs: Operand.constant(0)}]
		bytecode_length:            1
	}
	source, _ := native_source([executable])!
	expected := sha256.hexhash('native-generated-function-v1:' + source)
	defer { set_native_cache_digests_for_testing(true) }
	for enabled in [false, true] {
		set_native_cache_digests_for_testing(enabled)
		assert native_generated_code_identity(executable)! == expected
	}
}

fn test_generated_code_reuse_reads_the_current_closure_bindings_and_error_constants() {
	for sources in [
		['function make(first){return function(){return first}}make(41)()',
			'function make(other){return function(){return other}}make(99)()'],
		['function fail(){throw new Error("old")}var result;try{fail()}catch(e){result=e.message}result==="old"?41:0',
			'function fail(){throw new Error("new")}var result;try{fail()}catch(e){result=e.message}result==="new"?99:0'],
	] {
		directory := os.join_path(os.temp_dir(), 'vox-generated-context-' + rand.uuid_v4())
		defer { os.rmdir_all(directory) or {} }
		for visit, source in sources {
			mut vm := VM.create()
			create_simple_execution_context(mut vm)
			vm.enable_native_code_cache_with_options(directory,
				if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' },
				NativeCodeCacheOptions{ generated_code_identity: true })!
			vm.diagnose_native_code(true)!
			mut script := Script.parse(source, vm.realm(),
				'https://example.com/context-${visit}.js', unsafe { nil })!
			assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.number == if visit == 0 {
				41
			} else {
				99
			}
			stats := vm.flush_native_code_cache()!
			if visit == 1 {
				assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0
				assert vm.diagnose_native_code(false)!.entries > 0 && stats.last_error == ''
			}
			vm.close_native_code()!
		}
	}
}

fn test_generated_code_cache_leaves_default_source_identity_and_library_validation_in_place() {
	directory := os.join_path(os.temp_dir(), 'vox-generated-corrupt-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache_with_options(directory,
			if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' },
			NativeCodeCacheOptions{ generated_code_identity: true })!
		mut script := Script.parse('var effects=0;effects++;effects', vm.realm(),
			'https://example.com/' + visit.str() + '.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 10000 })!.number == 1
		if visit == 0 {
			vm.flush_native_code_cache()!
		} else {
			assert vm.native_code_cache_stats().invalid_entries > 0
			assert vm.native_code_cache_stats().cache_hits == 0
		}
		vm.close_native_code()!
		if visit == 0 {
			for path in os.walk_ext(directory, '.json') { os.write_file(path, '{"key":"wrong"}')! }
		}
	}
	mut ordinary := VM.create()
	create_simple_execution_context(mut ordinary)
	ordinary.enable_native_code_cache(directory, '/usr/bin/false')!
	assert ordinary.native_code_cache_stats().identity_kind == 'source'
	ordinary.close_native_code()!
}

fn test_generated_code_identity_reclaims_source_and_keeps_the_returned_digest() {
	executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(42)]
		instructions:               [Instruction{ op: .end, lhs: Operand.constant(0) }]
		bytecode_length:            1
	}
	expected := native_generated_code_identity(executable)!
	before := platform.thread_arena_usage().used
	for _ in 0 .. 32 {
		assert native_generated_code_identity(executable)! == expected
	}
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth < 128 * 1024, 'generated-code identity retained ${growth} bytes'
	}
}
