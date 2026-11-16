// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import fetch
import libjs
import platform

@[heap]
struct DocumentFetchOperation {
	host &Host
	request &fetch.RequestObject
	capability &libjs.JSPromiseCapability
mut:
	controller &fetch.FetchController = unsafe { nil }
	response ?&fetch.Response
	abort_algorithm ?u64
	abort_callback voidptr
	aborted bool
	network_finished bool
	settled bool
	finished bool
}

pub fn (host &Host) has_pending_fetches() bool { return host.fetch_operations.len > 0 }

pub fn (mut host Host) install_fetch(client fetch.RequestClient, transport &fetch.FetchHost) ! {
	mut vm := host.vm
	host.require_open(mut vm)!
	if host.fetch_transport != unsafe { nil } {
		if voidptr(host.fetch_transport) == voidptr(transport) { return }
		return error('Fetch already belongs to another transport')
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	host.fetch_client, host.fetch_transport = client, transport
	host.install_fetch_objects()!
	mut global := host.realm.global_object_record()
	host.method_attributes(mut global, 'fetch', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		owner.release_retired_fetch_aborts()
		capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
		if vm.argument_count() < 1 { owner.settle_fetch_error(capability, error('TypeError: fetch requires an input')); return capability.promise }
		request, _ := host.fetch_request(mut vm, vm.argument(0), vm.argument(1), none) or { owner.settle_fetch_error(capability, err); return capability.promise }
		if request.signal().aborted() {
			reason := owner.abort_reason_value(mut vm, request.signal().reason().as_webidl_value()!)!
			owner.settle_fetch_promise(capability, reason, true)
			return capability.promise
		}
		mut operation := &DocumentFetchOperation{host: owner, request: request, capability: capability}
		owner.fetch_operations << operation
		owner.fetch_signal_operations[voidptr(operation)] = operation
		operation.install_abort()
		if operation.aborted { return capability.promise }
		algorithms := fetch.FetchAlgorithms.create(fetch.FetchAlgorithmsInput{
			process_response: fn [operation] (response &fetch.Response) {
				mut current := unsafe { &DocumentFetchOperation(operation) }
				mut owner := unsafe { &Host(current.host) }
				if owner.closed || current.finished || current.network_finished || current.aborted { return }
				current.settled = true
				if response.is_network_error() {
					owner.settle_fetch_error(current.capability, error('TypeError: ' + (response.network_error_message or { 'Failed to fetch' })))
					current.finish()
					return
				}
				persistent := platform.enter_persistent()
				defer { platform.leave_persistent(persistent) }
				current.response = response
				value := owner.wrap_response(fetch.ResponseObject.from_response(response, .immutable), none)
				owner.settle_fetch_promise(current.capability, value, false)
			}
			process_response_end_of_body: fn [operation] (_ &fetch.Response) {
				mut current := unsafe { &DocumentFetchOperation(operation) }
				current.finish()
			}
		})
		operation.controller = fetch.fetch(request.internal_request(), algorithms, host.fetch_transport, .no)
		// A transport callback can reenter the host before fetch() returns its
		// controller. Apply cancellation that arrived during that interval.
		if operation.aborted { operation.controller.abort(none) }
		else if host.closed { operation.controller.stop_fetch() }
		return capability.promise
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}

fn (mut operation DocumentFetchOperation) finish() {
	if operation.finished { return }
	operation.network_finished = true
	mut host := unsafe { &Host(operation.host) }
	for index, active in host.fetch_operations {
		if voidptr(active) == voidptr(&operation) { host.fetch_operations.delete(index); break }
	}
	// Network delivery can finish while unread bytes remain queued. Keep the
	// signal associated until that body is consumed, errored or aborted.
	if !operation.aborted && !host.closed {
		if response := operation.response {
			if body := response.body {
				stream := body.stream()
				if stream.is_readable() { return }
			}
		}
	}
	operation.finished = true
	operation.detach_abort()
	host.fetch_signal_operations.delete(voidptr(&operation))
}

fn (mut host Host) settle_fetch_error(capability &libjs.JSPromiseCapability, err IError) {
	mut vm := host.vm
	host.settle_fetch_promise(capability, host.fetch_error_value(mut vm, err), true)
}

fn (mut host Host) settle_fetch_promise(capability &libjs.JSPromiseCapability, value libjs.Value, reject bool) {
	host.invoke_fetch_callback(fn [capability, value, reject] (mut vm libjs.VM) !libjs.Value {
		return libjs.call(mut vm, if reject { capability.reject } else { capability.resolve }, libjs.js_undefined(), [value])
	})
}

fn (mut host Host) invoke_fetch_callback(callback libjs.NativeFunctionPointer) {
	defer { platform.release_closure(voidptr(callback)) }
	if host.closed || host.document.has_been_destroyed() { return }
	if can_run := host.hooks.can_run_callback { if !can_run() { return } }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if before := host.hooks.before_callback { before() }
	defer { if after := host.hooks.after_callback { after() } }
	mut vm := host.vm
	function := libjs.NativeFunction.create(mut vm, host.realm, host.realm.function_prototype, callback, 0, libjs.PropertyName.from_str('fetchCallback'), none).object
	vm.call_with_limits(libjs.Value.from_object(function), libjs.js_undefined(), [], host.hooks.execution_limits) or {
		if report := host.hooks.exception { report(exception_message_with_stack(err)) }
	}
	host.changed()
}

fn (mut host Host) close_fetch() {
	for _, mut operation in host.fetch_signal_operations {
		operation.finished = true
		operation.detach_abort()
		if operation.controller != unsafe { nil } { operation.controller.stop_fetch() }
	}
	host.fetch_operations = []
	host.fetch_signal_operations.clear()
	host.release_retired_fetch_aborts()
	host.fetch_requests.clear()
	host.fetch_responses.clear()
	host.fetch_wrappers.clear()
}
