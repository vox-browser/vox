module libjs

import os
import rand

const lookup_index_source = 'function inc(n){return n+1} function twice(f,x){return f(f(x))} var total=0; for (var i=0;i<20;i++) total=twice(inc,total); total'

fn lookup_index_visit(directory string, compiler string) !(f64, NativeCacheStats, NativeLookupStats, NativeCodeActivity) {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.enable_native_code_cache(directory, compiler)!
	vm.diagnose_native_code(true)!
	mut script := Script.parse(lookup_index_source, vm.realm(), 'https://github.githubassets.com/assets/lookup-index.js', unsafe { nil })!
	result := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!
	activity := vm.diagnose_native_code(false)!
	stats := vm.flush_native_code_cache()!
	vm.persist_native_lookup_index()!
	lookup := vm.native_lookup_stats()
	vm.close_native_code()!
	return result.number, stats, lookup, activity
}

fn lookup_index_path(directory string) string {
	for entry in os.ls(directory) or { []string{} } {
		path := os.join_path(directory, entry, native_lookup_index_name)
		if os.is_file(path) { return path }
	}
	return ''
}

fn test_index_resolves_learned_records_without_rehashing_libraries() {
	directory := os.join_path(os.temp_dir(), 'vox-lookup-index-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	value, first, first_lookup, _ := lookup_index_visit(directory, '/usr/bin/clang')!
	assert value == 40
	assert first.cache_misses == 3 && first.compiler_invocations == 1
	// Compiled entries are recorded at flush; nothing was resolved from disk yet.
	assert first_lookup.learned == 0 && first_lookup.hits == 0
	assert lookup_index_path(directory) == ''

	value2, second, second_lookup, second_activity := lookup_index_visit(directory, '/usr/bin/false')!
	assert value2 == 40
	assert second.cache_hits == 3 && second.cache_misses == 0 && second.compiler_invocations == 0
	assert second_lookup.misses == 3 && second_lookup.learned == 3 && second_lookup.hits == 0
	assert second_lookup.persisted_records == 3
	assert second_activity.entries > 3
	index_path := lookup_index_path(directory)
	assert index_path != ''
	written := os.read_file(index_path)!

	value3, third, third_lookup, third_activity := lookup_index_visit(directory, '/usr/bin/false')!
	assert value3 == 40
	assert third.cache_hits == 3 && third.cache_misses == 0 && third.compiler_invocations == 0
	assert third_lookup.loaded_records == 3 && third_lookup.hits == 3 && third_lookup.misses == 0
	assert third_lookup.learned == 0 && third_lookup.dropped == 0
	// The library digest was verified when learned; its identity is unchanged.
	$if macos {
		assert third_lookup.identity_libraries == 1 && third_lookup.rehashed_libraries == 0
	}
	assert third_activity.entries == second_activity.entries
	assert third_activity.fast_steps == second_activity.fast_steps
	// A fully indexed visit leaves the index unchanged.
	assert os.read_file(index_path)! == written
}

fn test_unopenable_index_entries_fall_back_and_are_relearned() {
	directory := os.join_path(os.temp_dir(), 'vox-lookup-index-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	lookup_index_visit(directory, '/usr/bin/clang')!
	lookup_index_visit(directory, '/usr/bin/false')!
	index_path := lookup_index_path(directory)
	original := os.read_file(index_path)!
	mut lines := original.split_into_lines()
	for i, line in lines {
		if line.starts_with('E ') {
			fields := line.split(' ')
			lines[i] = 'E ${fields[1]} ${fields[2]} ${fields[3]} ${fields[4]} 999999'
		}
	}
	os.write_file(index_path, lines.join('\n') + '\n')!
	value, stats, lookup, _ := lookup_index_visit(directory, '/usr/bin/false')!
	assert value == 40
	assert stats.cache_hits == 3 && stats.cache_misses == 0 && stats.compiler_invocations == 0
	assert lookup.dropped == 3 && lookup.hits == 0 && lookup.learned == 3
	value2, _, relearned, _ := lookup_index_visit(directory, '/usr/bin/false')!
	assert value2 == 40
	assert relearned.hits == 3 && relearned.dropped == 0
}

fn test_index_from_another_build_is_not_used_for_executables() {
	directory := os.join_path(os.temp_dir(), 'vox-lookup-index-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	lookup_index_visit(directory, '/usr/bin/clang')!
	lookup_index_visit(directory, '/usr/bin/false')!
	index_path := lookup_index_path(directory)
	mut lines := os.read_file(index_path)!.split_into_lines()
	header := lines[0].split(' ')
	lines[0] = '${header[0]} ${'0'.repeat(64)} ${header[2]}'
	os.write_file(index_path, lines.join('\n') + '\n')!
	value, stats, lookup, _ := lookup_index_visit(directory, '/usr/bin/false')!
	assert value == 40
	assert stats.cache_hits == 3 && stats.cache_misses == 0
	assert lookup.loaded_records == 0 && lookup.hits == 0 && lookup.learned == 3
}

fn test_disabled_index_uses_the_ordinary_record_path() {
	directory := os.join_path(os.temp_dir(), 'vox-lookup-index-' + rand.uuid_v4())
	defer {
		set_native_lookup_index_for_testing(true)
		os.rmdir_all(directory) or {}
	}
	lookup_index_visit(directory, '/usr/bin/clang')!
	lookup_index_visit(directory, '/usr/bin/false')!
	set_native_lookup_index_for_testing(false)
	value, stats, lookup, _ := lookup_index_visit(directory, '/usr/bin/false')!
	assert value == 40
	assert stats.cache_hits == 3 && stats.cache_misses == 0
	assert lookup.hits == 0 && lookup.loaded_records == 0
}
