// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import webidl

@[heap]
struct StreamPromiseBinding {
	host &Host
	native &webidl.Promise
	value libjs.Value
mut:
	capability ?&libjs.JSPromiseCapability
}

fn (binding &StreamPromiseBinding) promise_observer_identity() voidptr { return voidptr(binding) }

fn (mut binding StreamPromiseBinding) native_promise_settled(state webidl.PromiseState, value webidl.Value) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	capability := binding.capability or { return }
	binding.capability = none
	mut host := unsafe { &Host(binding.host) }
	if host.closed || host.document.has_been_destroyed() { return }
	host.stream_entry(fn [mut host, capability, state, value] (mut vm libjs.VM) !libjs.Value {
		result := if state == .rejected { host.stream_error_value(mut vm, value)! } else { libjs.js_undefined() }
		return libjs.call(mut vm, if state == .rejected { capability.reject } else { capability.resolve }, libjs.js_undefined(), [result])
	}) or { if report := host.hooks.exception { report(exception_message(err)) } }
}

fn (mut host Host) wrap_stream_promise(mut vm libjs.VM, native &webidl.Promise) !libjs.Value {
	if binding := host.stream_promises[voidptr(native)] { return binding.value }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
	mut binding := &StreamPromiseBinding{host: &host, native: native, value: capability.promise, capability: capability}
	host.stream_promises[voidptr(native)] = binding
	mut promise := unsafe { &webidl.Promise(native) }
	promise.observe_native_settlement(mut binding)
	return capability.promise
}
