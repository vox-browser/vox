module platform

import os

fn test_scratch_handle_copies_cannot_retire_a_reused_lease() {
	$if !prealloc { return }
	first := begin_thread_scratch('copied scratch handle')
	copy := first
	first.finish()
	current := begin_thread_scratch('replacement scratch handle')
	assert voidptr(first.lease) == voidptr(current.lease)
	assert first.generation != current.generation
	bytes := []u8{len:1024, init:37}
	copy.leave()
	copy.finish()
	assert current.lease.active == 1
	assert current.lease.entered == 1
	assert bytes[0] == 37 && bytes[1023] == 37
	current.leave()
	current.finish()
	current.finish()
}

fn test_scratch_leases_grow_with_nesting_and_keep_each_parent_alive() {
	mut scopes := []ThreadScratchScope{cap:48}
	mut payloads := []&u8{cap:48}
	for depth in 0 .. 48 {
		scopes << begin_thread_scratch('nested lease handles')
		bytes := []u8{len:1024, init:u8(depth)}
		payloads << unsafe { &u8(bytes.data) }
	}
	for index := scopes.len - 1; index >= 0; index-- {
		assert unsafe { payloads[index][0] } == u8(index)
		scopes[index].finish()
		if index > 0 {
			assert unsafe { payloads[index - 1][1023] } == u8(index - 1)
		}
	}
}

fn test_scratch_descriptor_memory_is_bounded_across_repeated_work() {
	// Warm native descriptor storage before measuring V's caller arena.
	begin_thread_scratch('descriptor warmup').finish()
	before := thread_arena_usage().used
	for _ in 0 .. 256 {
		scope := begin_thread_scratch('bounded scratch descriptor')
		bytes := []u8{len:1024, init:19}
		assert bytes[0] + bytes[1023] == 38
		scope.finish()
	}
	$if prealloc { assert thread_arena_usage().used - before < 4096 }
}

fn test_scratch_poison_flags_preserve_exact_comma_separated_label_matching() {
	old_poison := os.getenv_opt('VOX_ARENA_POISON')
	old_names := os.getenv_opt('VOX_ARENA_NO_REUSE')
	defer {
		if value := old_poison { os.setenv('VOX_ARENA_POISON', value, true) }
		else { os.unsetenv('VOX_ARENA_POISON') }
		if value := old_names { os.setenv('VOX_ARENA_NO_REUSE', value, true) }
		else { os.unsetenv('VOX_ARENA_NO_REUSE') }
	}
	os.setenv('VOX_ARENA_POISON', '0', true)
	for names in ['', 'one,two', ',one,,two,', 'one, two', '日本語,one'] {
		os.setenv('VOX_ARENA_NO_REUSE', names, true)
		for label in ['', 'one', 'two', 'on', ' two', '日本語'] {
			expected := label in names.split(',')
			assert (C.vox_thread_scratch_poison_enabled(label.str, label.len) != 0) == expected
		}
	}
	os.setenv('VOX_ARENA_POISON', '1', true)
	assert C.vox_thread_scratch_poison_enabled('unlisted'.str, 8) != 0
	os.setenv('VOX_ARENA_POISON', '10', true)
	assert C.vox_thread_scratch_poison_enabled('unlisted'.str, 8) == 0
}

fn scratch_cached_policy_worker() bool {
	for label in ['one','two','日本語','unlisted'] {
		expected := C.vox_thread_scratch_poison_enabled(label.str,label.len)
		for _ in 0 .. 32 {
			scratch := begin_thread_scratch(label)
			$if prealloc { assert scratch.lease.poison == expected }
			bytes := []u8{len:1024,init:19}
			assert bytes[0] + bytes[1023] == 38
			scratch.finish()
		}
	}
	return true
}

fn test_cached_scratch_launch_policy_preserves_poisoned_scopes_on_every_thread() {
	assert scratch_cached_policy_worker()
	mut workers := []thread bool{}
	for _ in 0 .. 4 { workers << spawn scratch_cached_policy_worker() }
	for worker in workers { assert worker.wait() }
}
