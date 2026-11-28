// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import platform
import streams
import webidl

@[heap]
struct StreamReadRequestBinding {
	host &Host
mut:
	capability ?&libjs.JSPromiseCapability
}

fn (request &StreamReadRequestBinding) read_request_identity() voidptr { return voidptr(request) }
fn (mut request StreamReadRequestBinding) on_chunk(value streams.Value) { request.complete(value, false, none) }
fn (mut request StreamReadRequestBinding) on_close() { request.complete(streams.undefined_value(), true, none) }
fn (mut request StreamReadRequestBinding) on_error(reason webidl.Value) { request.complete(streams.undefined_value(), false, reason) }

fn (mut request StreamReadRequestBinding) complete(value streams.Value, done bool, failure ?webidl.Value) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	capability := request.capability or { return }
	request.capability = none
	mut host := unsafe { &Host(request.host) }
	host.stream_reads.delete(voidptr(&request))
	if host.closed || host.document.has_been_destroyed() { return }
	host.stream_entry(fn [mut host, capability, value, done, failure] (mut vm libjs.VM) !libjs.Value {
		if reason := failure {
			return libjs.call(mut vm, capability.reject, libjs.js_undefined(), [host.stream_error_value(mut vm, reason)!])
		}
		chunk := host.stream_value_to_js(mut vm, value) or {
			return libjs.call(mut vm, capability.reject, libjs.js_undefined(), [host.fetch_error_value(mut vm, err)])
		}
		mut result := libjs.Object.create(host.realm, host.realm.object_prototype)
		attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
		result.define_direct_property(libjs.PropertyName.from_str('value'), chunk, attributes)
		result.define_direct_property(libjs.PropertyName.from_str('done'), libjs.Value.from_bool(done), attributes)
		return libjs.call(mut vm, capability.resolve, libjs.js_undefined(), [libjs.Value.from_object(result)])
	}) or { if report := host.hooks.exception { report(exception_message(err)) } }
	host.release_completed_fetch_aborts()
}

fn (mut host Host) start_stream_read(mut vm libjs.VM, mut reader streams.ReadableStreamDefaultReader, capability &libjs.JSPromiseCapability) {
	if reader.reader_stream() == none {
		host.settle_fetch_error(capability, error('TypeError: Reader has no associated stream'))
		return
	}
	mut request := &StreamReadRequestBinding{host: &host, capability: capability}
	host.stream_reads[voidptr(request)] = request
	streams.readable_stream_default_reader_read_request(mut reader, mut request)
}
