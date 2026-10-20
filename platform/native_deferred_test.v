module platform

import time

@[heap]
struct DeferredThreadObservation {
mut:
	delivered       bool
	origin_thread   u64
	worker_thread   u64
	callback_thread u64
	bytes           []u8
}

fn post_deferred_worker_result(invoker NativeDeferredInvoker, state &DeferredThreadObservation) {
	worker := native_thread_identity()
	bytes := 'source worker result'.bytes()
	invoker.deferred_invoke(fn [state, worker, bytes] () {
		mut observation := unsafe { &DeferredThreadObservation(state) }
		observation.worker_thread = worker
		observation.callback_thread = native_thread_identity()
		observation.bytes = bytes.clone()
		observation.delivered = true
	})
}

fn test_worker_completion_is_retained_and_delivered_on_its_actual_origin_native_loop() {
	invoker := capture_native_deferred_invoker() or { return }
	state := &DeferredThreadObservation{
		origin_thread: native_thread_identity()
	}
	worker := spawn post_deferred_worker_result(invoker, state)
	worker.wait()
	assert !state.delivered
	deadline := time.sys_mono_now() + time.second
	for !state.delivered && time.sys_mono_now() < deadline {
		pump_native_events(0.05)
	}
	assert state.delivered
	assert state.worker_thread != state.origin_thread
	assert state.callback_thread == state.origin_thread
	assert state.bytes.bytestr() == 'source worker result'
}

fn deliver_with_worker_owned_loop() bool {
	invoker := capture_native_deferred_invoker() or { return false }
	state := &DeferredThreadObservation{origin_thread: native_thread_identity()}
	worker := spawn post_deferred_worker_result(invoker, state)
	worker.wait()
	deadline := time.sys_mono_now() + time.second
	for !state.delivered && time.sys_mono_now() < deadline { pump_native_events(0.05) }
	return state.delivered && state.callback_thread == state.origin_thread
		&& state.worker_thread != state.origin_thread
}

fn test_deferred_completion_can_target_a_worker_owned_native_loop() {
	$if !linux { return }
	worker := spawn deliver_with_worker_owned_loop()
	assert worker.wait()
}

fn post_document_owned_result(invoker NativeDeferredInvoker, state &DeferredThreadObservation, payload []u8) {
	invoker.deferred_invoke(fn [state, payload] () {
		assert payload.bytestr() == 'document-owned result'
		mut observation := unsafe { &DeferredThreadObservation(state) }
		observation.delivered = true
	})
}

fn test_deferred_worker_completion_keeps_retired_document_payload_until_delivery() {
	mut storage := new_retained_arena('deferred document')
	state := &DeferredThreadObservation{}
	mut scope := storage.enter()
	payload := 'document-owned result'.bytes()
	invoker := capture_native_deferred_invoker() or { scope.finish(); storage.release(); return }
	scope.finish()
	storage.release()
	worker := spawn post_document_owned_result(invoker, state, payload)
	worker.wait()
	$if prealloc { assert storage.arena.usage().used > 0 }
	deadline := time.sys_mono_now() + time.second
	for !state.delivered && time.sys_mono_now() < deadline { pump_native_events(0.05) }
	assert state.delivered
	assert storage.arena.usage().used == 0
}
