module platform

fn shared_pool_retirement_worker(iterations int, pattern u8) bool {
	for _ in 0 .. iterations {
		scratch := begin_thread_scratch('shared pool refill')
		bytes := []u8{len:128 * 1024, init:pattern}
		valid := bytes[0] == pattern && bytes[bytes.len - 1] == pattern
		scratch.finish()
		if !valid { return false }
	}
	return true
}

fn test_shared_pool_retirement_serializes_with_cross_thread_refills() {
	$if prealloc {
		mut workers := []thread bool{}
		for index in 0 .. 4 {
			workers << spawn shared_pool_retirement_worker(40, u8(17 + index))
		}
		for _ in 0 .. 40 { trim_thread_arena_recycle_pages() }
		for worker in workers { assert worker.wait() }
		// The process-wide cache can retain blocks freed by any worker, while
		// live main-thread data remains outside the pool's retirement boundary.
		live := []u8{len:4096, init:91}
		trim_thread_arena_recycle_pages()
		assert live[0] == 91 && live[live.len - 1] == 91
	}
}
