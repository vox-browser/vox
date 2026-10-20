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
	for worker in workers { assert worker.wait() == 38 }
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
