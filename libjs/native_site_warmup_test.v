module libjs

import os
import rand

@[heap]
struct SiteCompileBatches {
mut:
	completed []int
}

fn test_site_native_warmup_compiles_without_running_scripts_and_reuses_programs() {
	directory := os.join_path(os.temp_dir(), 'vox-site-warmup-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	address := 'https://example.test/list/'
	options := NativeCodeCacheOptions{}
	mut classic := 'if (!globalThis.loaded) throw 1; function answer() { return 42 }; answer();'
	for i in 0 .. 127 {
		classic += 'function staged${i}() { return ${i}; }'
	}
	module_source := 'import { x } from "./dependency.js"; export const value = x;'
	assert !native_site_cache_ready(directory, address, options)
	mut batches := &SiteCompileBatches{}
	compile_native_site_cache(directory, address, 'clang', options, [
		NativeWarmupSource{code: classic, filename: address, line: 4},
		NativeWarmupSource{code: module_source, filename: address + 'entry.js', kind: .module},
	], on_progress: fn [mut batches] (completed int, total int) {
		assert total == 130
		batches.completed << completed
	})!
	assert batches.completed == [128, 130]
	assert native_site_cache_ready(directory, address, options)
	assert !native_site_cache_ready(directory, address + 'other/', options)

	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut setup := Script.parse('globalThis.loaded = true;', vm.realm(), '<setup>', unsafe { nil })!
	vm.run_with_limits(mut setup, ExecutionLimits{})!
	vm.enable_native_code_cache(directory, 'clang')!
	mut script := Script.parse(classic, vm.realm(), address, unsafe { nil })!
	script.starting_line = 4
	assert vm.run_with_limits(mut script, ExecutionLimits{})!.number == 42
	assert vm.native_code_cache_stats().cache_hits == 2
	vm.close_native_code()!

	cache := native_site_cache_directory(directory, options)!
	marker := native_site_cache_path(cache, address)
	key := os.read_file(marker)!.split('\n')[0]
	os.rm(os.join_path(cache, key + '.json'))!
	assert !native_site_cache_ready(directory, address, options)
}

fn test_untranslatable_script_leaves_site_cold() {
	directory := os.join_path(os.temp_dir(), 'vox-site-cold-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	address := 'https://example.test/'
	if _ := compile_native_site_cache(directory, address, 'clang', NativeCodeCacheOptions{}, [
		NativeWarmupSource{code: 'export const x = await Promise.resolve(1);', filename: address, kind: .module},
	]) {
		assert false
	}
	assert !native_site_cache_ready(directory, address, NativeCodeCacheOptions{})
}
