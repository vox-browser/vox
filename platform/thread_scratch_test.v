module platform

fn scratch_worker() int {
	mut scratch := begin_thread_scratch('worker temporary')
	bytes := []u8{len: 1024, init: 19}
	result := int(bytes[0]) + int(bytes[bytes.len - 1])
	scratch.finish()
	return result
}

fn test_thread_scratch_can_retire_independently_on_workers() {
	mut workers := []thread int{}
	for _ in 0 .. 4 { workers << spawn scratch_worker() }
	for worker in workers {
		assert worker.wait() == 38
	}
}

fn test_thread_scratch_can_copy_a_result_out_before_release() {
	mut scratch := begin_thread_scratch('temporary error')
	message := 'owned error ${73}'
	scratch.leave()
	owned := message.clone()
	scratch.finish()
	scratch.finish()
	assert owned == 'owned error 73'
}

fn scratch_persistent_worker() int {
	outer := begin_thread_scratch('persistent outer scratch')
	inner := begin_thread_scratch('persistent inner scratch')
	$if prealloc {
		assert transient_arena_entered()
	}
	entry := enter_persistent()
	kept := []u8{len: 20 * 1024 * 1024, init: 37}
	nested := enter_persistent()
	message := 'persistent result ${kept[0]}'
	leave_persistent(nested)
	leave_persistent(entry)
	inner.finish()
	outer.finish()
	$if prealloc {
		assert thread_arena_usage().used >= kept.len
	}
	assert message == 'persistent result 37'
	return int(kept[0]) + int(kept[kept.len - 1])
}

fn test_persistent_allocations_escape_nested_thread_scratch() {
	assert scratch_persistent_worker() == 74
	worker := spawn scratch_persistent_worker()
	assert worker.wait() == 74
}
