module browsernet

import time

fn test_request_scope_cancellation_is_idempotent_and_rejects_publication() {
	scope := new_request_scope()
	defer { scope.release() }
	assert !scope.is_cancelled()
	scope.cancel()
	scope.cancel()
	assert scope.is_cancelled()
	assert scope.wait_for_cancellation(0)
	mut checked := false
	scope.check() or {
		checked = true
		assert err.code() == request_cancelled_code
	}
	assert checked
	mut denied := false
	scope.begin_publication() or {
		denied = true
		assert err.code() == request_cancelled_code
	}
	assert denied
}

fn scope_test_wait_for_slot(scope &RequestScope, completed chan bool) {
	defer { scope.release() }
	scope.acquire_request_slot() or {
		completed <- false
		return
	}
	release_request_slot()
	completed <- true
}

fn test_request_scope_budget_is_shared_and_cancel_wakes_queued_requests() {
	active := new_request_scope()
	defer { active.release() }
	for _ in 0 .. max_concurrent_requests { active.acquire_request_slot() or { panic(err) } }
	queued := new_request_scope()
	defer { queued.release() }
	completed := chan bool{cap: 1}
	queued.retain()
	spawn scope_test_wait_for_slot(queued, completed)
	select {
		_ := <-completed {
			assert false, 'A second scope bypassed the shared transport budget'
		}
		20 * time.millisecond {
		}
	}
	queued.cancel()
	select {
		acquired := <-completed {
			assert !acquired
		}
		2 * time.second {
			assert false, 'Cancellation did not retire a queued request'
		}
	}
	// Cancellation of a waiter must not release any active request's permit.
	next := new_request_scope()
	defer { next.release() }
	next.retain()
	spawn scope_test_wait_for_slot(next, completed)
	select {
		_ := <-completed {
			assert false, 'A cancelled waiter released another request permit'
		}
		20 * time.millisecond {
		}
	}
	release_request_slot()
	select {
		acquired := <-completed {
			assert acquired
		}
		2 * time.second {
			assert false, 'A completed request did not release scheduling capacity'
		}
	}
	for _ in 1 .. max_concurrent_requests { release_request_slot() }
}

fn scope_test_cancel(scope &RequestScope, started chan bool, completed chan bool) {
	defer { scope.release() }
	started <- true
	scope.cancel()
	completed <- true
}

fn test_request_scope_cancel_waits_for_publication_and_worker_owns_its_lifetime() {
	scope := new_request_scope()
	started := chan bool{cap: 1}
	completed := chan bool{cap: 1}
	scope.retain()
	scope.begin_publication() or { panic(err) }
	spawn scope_test_cancel(scope, started, completed)
	_ := <-started
	select {
		_ := <-completed {
			assert false, 'Cancellation returned while a cache publication was live'
		}
		20 * time.millisecond {
		}
	}
	scope.end_publication()
	// The worker owns a reference even after its navigation drops the owner.
	scope.release()
	select {
		_ := <-completed {
		}
		2 * time.second {
			assert false, 'The cancelling worker did not retire'
		}
	}
}

fn scope_test_publish(scope &RequestScope, values chan int, started chan bool, completed chan bool) {
	defer { scope.release() }
	started <- true
	completed <- publish_result[int](2, values, scope)
}

fn test_cancel_retires_a_producer_with_an_abandoned_full_result_channel() {
	scope := new_request_scope()
	defer { scope.release() }
	values := chan int{cap: 1}
	assert publish_result[int](1, values, scope)
	started := chan bool{cap: 1}
	completed := chan bool{cap: 1}
	scope.retain()
	spawn scope_test_publish(scope, values, started, completed)
	_ := <-started
	select {
		_ := <-completed {
			assert false, 'A full channel unexpectedly accepted another completion'
		}
		20 * time.millisecond {
		}
	}
	scope.cancel()
	select {
		published := <-completed {
			assert !published
		}
		2 * time.second {
			assert false, 'The retired consumer left its producer blocked'
		}
	}
	assert values.len == 1
	assert <-values == 1
	assert !publish_result[int](3, values, scope)
	assert values.len == 0
}
