// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (mut host Host) release_retired_fetch_aborts() {
	if host.fetch_abort_callback_depth != 0 { return }
	for callback in host.retired_fetch_abort_closures { platform.release_closure(callback) }
	host.retired_fetch_abort_closures = []
}

fn (mut operation DocumentFetchOperation) install_abort() {
	mut signal := unsafe { &dom.AbortSignal(operation.request.signal()) }
	callback := fn [operation] () {
		mut current := unsafe { &DocumentFetchOperation(operation) }
		mut owner := unsafe { &Host(current.host) }
		owner.fetch_abort_callback_depth++
		defer { owner.fetch_abort_callback_depth-- }
		current.abort_from_signal()
	}
	operation.abort_callback = voidptr(callback)
	operation.abort_algorithm = signal.add_abort_algorithm(callback)
	if operation.abort_algorithm == none {
		// Already-aborted input normally takes the earlier fast rejection.
		// Keep registration's native no-op boundary correct as well.
		operation.abort_from_signal()
	}
}

fn (mut operation DocumentFetchOperation) detach_abort() {
	mut signal := unsafe { &dom.AbortSignal(operation.request.signal()) }
	if id := operation.abort_algorithm { signal.remove_abort_algorithm(id) }
	operation.abort_algorithm = none
	callback := operation.abort_callback
	operation.abort_callback = unsafe { nil }
	if callback == unsafe { nil } { return }
	mut host := unsafe { &Host(operation.host) }
	if host.fetch_abort_callback_depth != 0 { host.retired_fetch_abort_closures << callback }
	else { platform.release_closure(callback) }
}

fn (mut operation DocumentFetchOperation) abort_from_signal() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut host := unsafe { &Host(operation.host) }
	if host.closed || operation.finished || operation.aborted { return }
	operation.aborted = true
	signal := operation.request.signal()
	native_reason := signal.reason().as_webidl_value() or { return }
	mut vm := host.vm
	reason := host.abort_reason_value(mut vm, native_reason) or { host.fetch_error_value(mut vm, err) }
	// Controller serialization is a separate native diagnostic channel. Never
	// stringify the author reason; promise/body rejection retains its identity.
	if operation.controller != unsafe { nil } { operation.controller.abort(none) }
	if response := operation.response {
		if body := response.body { mut stream := body.stream(); stream.error_value(native_reason) }
	}
	if !operation.settled {
		operation.settled = true
		host.settle_fetch_promise(operation.capability, reason, true)
	}
	operation.finish()
}

fn (mut host Host) release_completed_fetch_aborts() {
	mut candidates := []&DocumentFetchOperation{}
	for _, operation in host.fetch_signal_operations {
		if operation.network_finished { candidates << operation }
	}
	for mut operation in candidates { operation.finish() }
	host.release_retired_fetch_aborts()
}
