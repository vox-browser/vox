module libjs

import os
import platform
import rand

fn entry_cache_a(state voidptr, values voidptr, budget &u64, limited u8, pc &u32, slow fn (voidptr, u32) u32, fast &u64) {}
fn entry_cache_b(state voidptr, values voidptr, budget &u64, limited u8, pc &u32, slow fn (voidptr, u32) u32, fast &u64) {}

fn test_native_entry_cache_checks_identity_collisions_updates_and_disabled_execution() {
	defer { set_native_entry_cache_for_testing(true) }
	mut tier := NativeTier{enabled: true, profiling: false}
	mut by_slot := map[int]&Executable{}
	mut first := unsafe { &Executable(nil) }
	mut second := unsafe { &Executable(nil) }
	for _ in 0 .. 600 {
		executable := &Executable{}
		slot := native_entry_cache_slot(executable)
		if previous := by_slot[slot] { first = previous; second = executable; break }
		by_slot[slot] = executable
	}
	assert first != unsafe { nil } && second != unsafe { nil }
	tier.set_native_entry(first, entry_cache_a)
	tier.set_native_entry(second, entry_cache_b)
	assert voidptr(tier.entry_for_execution(first)?) == voidptr(entry_cache_a)
	assert voidptr(tier.entry_for_execution(second)?) == voidptr(entry_cache_b)
	set_native_entry_cache_for_testing(false)
	tier.set_native_entry(second, entry_cache_a)
	set_native_entry_cache_for_testing(true)
	assert voidptr(tier.entry_for_execution(second)?) == voidptr(entry_cache_a)
	tier.enabled = false
	assert tier.entry_for_execution(second) == none
	tier.enabled = true
	missing := &Executable{}
	assert tier.entry_for_execution(missing) == none
	tier.set_native_entry(missing, entry_cache_b)
	assert voidptr(tier.entry_for_execution(missing)?) == voidptr(entry_cache_b)
}

fn test_native_entry_cache_is_bounded_rooted_and_does_not_allocate_per_hit() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm.native_tier = &NativeTier{enabled: true, profiling: false}
	mut tier := vm.native_tier?
	for _ in 0 .. 600 { tier.set_native_entry(&Executable{}, entry_cache_a) }
	assert tier.entry_cache.len == native_entry_cache_slots
	roots := vm.heap_roots()
	for slot in tier.entry_cache { if slot.executable != unsafe { nil } { assert roots.contains(voidptr(slot.executable)) } }
	executable := &Executable{}
	tier.set_native_entry(executable, entry_cache_b)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100000 { assert voidptr(tier.entry_for_execution(executable)?) == voidptr(entry_cache_b) }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert tier.entry_cache.len == native_entry_cache_slots
}

fn test_native_entry_cache_preserves_execution_and_tier_close_reopen() {
	defer { set_native_entry_cache_for_testing(true) }
	cache := os.join_path(os.temp_dir(), 'vox-entry-cache-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut setup := Script.parse('function add(a,b){return a+b}add(20,22)', vm.realm(), 'entry-cache.js', unsafe { nil })!
	for generation in 0 .. 2 {
		vm.profile_native_code()!
		assert vm.run(mut setup)!.number == 42
		vm.compile_native_code(cache, if generation == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		for enabled in [false, true] {
			set_native_entry_cache_for_testing(enabled)
			vm.diagnose_native_code(true)!
			mut script := Script.parse('add(20,22)+add(20,22)', vm.realm(), 'entry-cache-check.js', unsafe { nil })!
			assert vm.run(mut script)!.number == 84
			activity := vm.diagnose_native_code(false)!
			assert activity.entries > 0
			assert (activity.entry_cache_hits > 0) == enabled
		}
		vm.close_native_code()!
		assert vm.native_tier == none
		assert vm.run(mut setup)!.number == 42
	}
}
