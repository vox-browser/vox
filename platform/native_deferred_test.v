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
