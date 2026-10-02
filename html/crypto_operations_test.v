module html

import dom
import webcrypto
import webidl

@[heap]
struct CryptoOwnerReactions {
mut:
	seen []string
}

fn crypto_owner_run_task(event_loop &EventLoop, expected TaskSource) {
	mut queue := event_loop.task_queue()
	task := queue.dequeue() or { panic('missing Crypto task') }
	assert task.source() == expected
	task.execute()
}

fn test_global_crypto_is_concrete_same_object_and_worker_owns_tasks_and_microtasks() {
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{ value: 'https://example.test' }, true, false)
	mut event_loop := EventLoop.create(.worker)
	scope.responsible_event_loop_ = event_loop
	crypto := scope.crypto()
	assert scope.crypto() == crypto
	assert crypto.subtle() == crypto.subtle()
	assert crypto.crypto().subtle() != unsafe { nil }
	mut random := []u8{len: 32}
	crypto.get_random_values(mut random)!
	assert random != []u8{len: 32}
	uuid := crypto.random_uuid()!
	assert uuid.len == 36
	assert uuid[14] == `4`
	mut promise := crypto.subtle().digest(webidl.string_value('SHA-256'), webidl.BufferSource.array_buffer('abc'.bytes()))
	mut reactions := &CryptoOwnerReactions{}
	child := promise.upon_fulfillment(fn [mut reactions] (value webidl.Value) !webidl.Value {
		reactions.seen << 'worker reaction'
		return value
	})
	assert promise.state == .pending
	assert event_loop.task_queue().tasks.len == 1
	assert event_loop.microtask_queue.len == 0
	crypto_owner_run_task(event_loop, .unspecified)
	assert promise.state == .pending
	assert event_loop.task_queue().tasks.len == 1
	assert event_loop.microtask_queue.len == 0
	crypto_owner_run_task(event_loop, .crypto)
	assert promise.state == .fulfilled
	assert reactions.seen.len == 0
	assert event_loop.microtask_queue.len == 1
	assert child.state == .pending
	job := event_loop.dequeue_microtask() or { panic('missing Promise reaction job') }
	assert job.source() == .microtask
	job.execute()
	assert reactions.seen == ['worker reaction']
	assert child.state == .fulfilled
	assert webidl.promise_realm(child) == u64(voidptr(scope))
}

fn test_crypto_window_and_worker_queues_remain_independent_and_errors_obey_source_order() {
	mut window_loop := EventLoop.create(.window)
	mut worker_loop := EventLoop.create(.worker)
	mut window_scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{ value: 'https://window.test' }, true, false)
	mut worker_scope := WindowOrWorkerGlobalScopeMixin.create(dom.Origin{ value: 'https://window.test' }, true, false)
	window_scope.responsible_event_loop_ = window_loop
	worker_scope.responsible_event_loop_ = worker_loop
	window_crypto := window_scope.crypto()
	worker_crypto := worker_scope.crypto()
	assert window_crypto != worker_crypto
	window_result := window_crypto.subtle().digest(webidl.string_value('SHA-256'), webidl.BufferSource.array_buffer('window'.bytes()))
	worker_result := worker_crypto.subtle().digest(webidl.string_value('SHA-256'), webidl.BufferSource.array_buffer('worker'.bytes()))
	crypto_owner_run_task(worker_loop, .unspecified)
	crypto_owner_run_task(worker_loop, .crypto)
	assert worker_result.state == .fulfilled
	assert window_result.state == .pending
	assert window_loop.task_queue().tasks.len == 1
	crypto_owner_run_task(window_loop, .unspecified)
	crypto_owner_run_task(window_loop, .crypto)
	assert window_result.state == .fulfilled
	assert window_result.result != worker_result.result
	mut immediate := worker_crypto.subtle().digest(webidl.string_value('missing'), webidl.BufferSource.array_buffer([]u8{}))
	assert immediate.state == .rejected
	assert worker_loop.task_queue().tasks.len == 0
	child := immediate.upon_rejection(fn (reason webidl.Value) !webidl.Value { return reason })
	assert worker_loop.microtask_queue.len == 1
	assert window_loop.microtask_queue.len == 0
	job := worker_loop.dequeue_microtask() or { panic('missing rejection reaction') }
	job.execute()
	assert child.state == .fulfilled
	assert child.result.object_value['name'].string_value == 'NotSupportedError'
	key := webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: 'AES-CBC' }, [.encrypt], []u8{len: 16})
	key_error := worker_crypto.subtle().sign(webidl.string_value('HMAC'), key, webidl.BufferSource.array_buffer([]u8{}))
	assert key_error.state == .pending
	crypto_owner_run_task(worker_loop, .unspecified)
	assert key_error.state == .pending
	crypto_owner_run_task(worker_loop, .crypto)
	assert key_error.state == .rejected
	assert key_error.result.object_value['name'].string_value == 'InvalidAccessError'
}
