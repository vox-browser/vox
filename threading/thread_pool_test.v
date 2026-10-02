module threading

import platform
import time

fn test_shared_thread_pool_runs_four_workers_and_keeps_pending_work_until_a_worker_is_free() {
	mut pool := ThreadPool.the()
	assert pool == ThreadPool.the()
	assert pool.threads_.len == 4
	started := chan u64{cap: 4}
	release := chan bool{cap: 4}
	finished := chan bool{cap: 5}
	for _ in 0 .. 4 {
		pool.submit(fn [started, release, finished] () {
			started <- platform.native_thread_identity()
			_ := <-release
			finished <- true
		})
	}
	mut workers := []u64{}
	for _ in 0 .. 4 {
		select {
			worker := <-started {
				workers << worker
			}
			2 * time.second {
				assert false, 'source pool did not start four jobs'
			}
		}
	}
	$if macos {
		for i, worker in workers {
			assert worker != platform.native_thread_identity()
			assert worker !in workers[..i]
		}
	}
	pool.submit(fn [finished] () {
		finished <- true
	})
	assert finished.len == 0
	for _ in 0 .. 4 {
		release <- true
	}
	for _ in 0 .. 5 {
		select {
			_ := <-finished {}
			2 * time.second {
				assert false, 'source pool did not drain queued work'
			}
		}
	}
}
