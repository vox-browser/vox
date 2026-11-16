module libjs

import os
import rand

const revisit_source = 'function inc(n){return n+1} function read(o){return o.x} var answer=inc(41);read({x:"fresh realm"});answer'

fn revisit_cache_directory() string {
	return os.join_path(os.temp_dir(), 'vox-revisit-' + rand.uuid_v4())
}

fn revisit_script(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'https://github.githubassets.com/assets/revisit.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_cached_generator_exits_native_code_at_start_yield_and_delegated_yield() {
	directory := revisit_cache_directory()
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert revisit_script(mut vm, 'var events=[];function* sequence(){events.push("start");var input=yield 7;events.push(input);yield* [8,9];return 42}var iterator=sequence();var lazy=events.length===0;var first=iterator.next();var paused=events.join() === "start";var second=iterator.next("resume"),third=iterator.next(),last=iterator.next();lazy&&paused&&first.value===7&&!first.done&&second.value===8&&!second.done&&third.value===9&&!third.done&&last.value===42&&last.done&&events.join()==="start,resume"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_hits >= 2 && stats.cache_misses == 0 && stats.compiler_invocations == 0
			assert activity.entries >= 2 && activity.slow_steps > 0
		}
		vm.close_native_code()!
	}
}

fn test_cached_async_body_leaves_native_code_until_its_pending_await_resumes() {
	directory := revisit_cache_directory()
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		revisit_script(mut vm, 'var events=[],release,observed=0;var gate=new Promise(resolve=>{release=resolve});async function work(){events.push("before");var value=await gate;events.push(value);return value+1}var promise=work();var paused=events.join()==="before";release(41);promise.then(value=>{observed=value})')!
		global := vm.realm().global_object_record()
		assert global.get(mut vm, PropertyName.from_str('paused'))!.as_bool()
		assert global.get(mut vm, PropertyName.from_str('observed'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_hits >= 4 && stats.cache_misses == 0 && stats.compiler_invocations == 0
			assert activity.entries >= 4 && activity.slow_steps > 0
		}
		vm.close_native_code()!
	}
}

fn test_second_vm_uses_native_code_on_its_first_execution_without_a_compiler_or_warmup() {
	directory := revisit_cache_directory()
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		assert revisit_script(mut vm, revisit_source)!.number == 42
		before := vm.native_code_cache_stats()
		activity := vm.diagnose_native_code(false)!
		if visit == 0 {
			assert before.cache_misses == 3 && before.cache_hits == 0
			assert activity.entries == 0
		} else {
			assert before.cache_hits == 3 && before.cache_misses == 0
			assert activity.entries == 3 && activity.fast_steps > 0 && activity.slow_steps > 0
		}
		after := vm.flush_native_code_cache()!
		assert after.compiler_invocations == u64(if visit == 0 { 1 } else { 0 }), 'visit ${visit}: compiler calls ${after.compiler_invocations}, compiled ${after.compiled_executables}, pending ${after.pending_executables}, directory ${directory}'
		assert vm.flush_native_code_cache()!.compiler_invocations == after.compiler_invocations
		assert revisit_script(mut vm, 'read({x:"changed"})')!.as_string().str() == 'changed'
		assert revisit_script(mut vm, 'inc("x")')!.as_string().str() == 'x1'
		vm.close_native_code()!
	}
}

fn test_persistent_native_cache_rejects_changed_source_and_corrupt_records_without_replaying_effects() {
	directory := revisit_cache_directory()
	defer { os.rmdir_all(directory) or {} }
	mut first := VM.create()
	create_simple_execution_context(mut first)
	first.enable_native_code_cache(directory, '/usr/bin/clang')!
	assert revisit_script(mut first, 'var count=0;count++;count')!.number == 1
	first.flush_native_code_cache()!
	first.close_native_code()!
	mut changed := VM.create()
	create_simple_execution_context(mut changed)
	changed.enable_native_code_cache(directory, '/usr/bin/false')!
	assert revisit_script(mut changed, 'var count=0;count+=2;count')!.number == 2
	assert changed.native_code_cache_stats().cache_hits == 0
	assert changed.native_code_cache_stats().cache_misses == 1
	if _ := changed.flush_native_code_cache() {
		assert false
	}
	changed.close_native_code()!
	for path in os.walk_ext(directory, '.json') { os.write_file(path, '{"key":"wrong"}')! }
	mut corrupt := VM.create()
	create_simple_execution_context(mut corrupt)
	corrupt.enable_native_code_cache(directory, '/usr/bin/false')!
	assert revisit_script(mut corrupt, 'var count=0;count++;count')!.number == 1
	assert corrupt.native_code_cache_stats().invalid_entries == 1
	// The intact library can repair a damaged manifest without a compiler.
	assert corrupt.flush_native_code_cache()!.compiler_invocations == 0
	assert revisit_script(mut corrupt, 'count')!.number == 1
	corrupt.close_native_code()!
}

fn test_module_linking_and_body_reuse_native_code_in_a_fresh_module_environment() {
	directory := revisit_cache_directory()
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		mut module_record := SourceTextModule.parse('export var value=40;export function add(n){value+=n;return value} add(2)',
			vm.realm(), 'https://github.githubassets.com/assets/module.js', unsafe { nil })!
		vm.diagnose_native_code(true)!
		module_record.link(mut vm)!
		result := module_record.evaluate(mut vm)!
		assert result.promise.state == .fulfilled
		assert module_record.local_export_value(mut vm, 'value')!.number == 42
		activity := vm.diagnose_native_code(false)!
		if visit == 1 {
			assert vm.native_code_cache_stats().cache_hits == 2
			assert activity.entries >= 3
		}
		vm.flush_native_code_cache()!
		vm.close_native_code()!
	}
}
