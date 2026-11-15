// SPDX-License-Identifier: BSD-2-Clause
module streams

import webidl

@[heap]
struct NativeSourceRecorder {
mut:
	starts int
	pulls int
	cancels int
	handle ?ReadableStreamControllerHandle
	reason Value
	pending_start ?&webidl.Promise
	close_on_pull bool
}

@[heap]
struct NativeSizeRecorder {
mut:
	calls int
}

fn (mut record NativeSizeRecorder) invoke_size_algorithm(_ Value) !webidl.Value {
	record.calls++
	return webidl.number_value(2)
}

fn (mut source NativeSourceRecorder) start_readable_source(handle ReadableStreamControllerHandle) !&webidl.Promise {
	source.starts++
	source.handle = handle
	return source.pending_start or { webidl.create_resolved_promise(webidl.undefined_value()) }
}

fn (mut source NativeSourceRecorder) pull_readable_source(handle ReadableStreamControllerHandle) !&webidl.Promise {
	source.pulls++
	if source.close_on_pull {
		mut controller := handle.default_controller or { return error('Expected a default controller') }
		controller.enqueue(number_value(7))!
		controller.close()!
	}
	return webidl.create_resolved_promise(webidl.undefined_value())
}

fn (mut source NativeSourceRecorder) cancel_readable_source(reason Value) !&webidl.Promise {
	source.cancels++
	source.reason = reason
	return webidl.create_resolved_promise(webidl.undefined_value())
}

fn test_native_source_record_gets_actual_controller_and_default_pull_state() {
	mut source := &NativeSourceRecorder{close_on_pull: true}
	mut native := ReadableStream.create(StreamRealm{}, UnderlyingSource{native_callbacks: source}, QueuingStrategy{})!
	assert source.starts == 1 && source.pulls == 1
	assert voidptr(source.handle?.default_controller?) == voidptr(native.default_controller()!)
	mut reader := native.get_default_reader()!
	assert reader.read().result().value.number == 7
	assert reader.read().result().done
}

fn test_native_source_record_waits_for_pending_start_before_pulling() {
	mut promise := webidl.create_promise()
	mut source := &NativeSourceRecorder{pending_start: promise, close_on_pull: true}
	mut native := ReadableStream.create(StreamRealm{}, UnderlyingSource{native_callbacks: source}, QueuingStrategy{})!
	mut reader := native.get_default_reader()!
	read := reader.read()
	assert read.state() == .pending && source.pulls == 0
	promise.resolve(webidl.undefined_value())
	assert read.state() == .fulfilled && read.result().value.number == 7 && source.pulls == 1
}

fn test_native_source_record_preserves_cancel_value_and_byte_controller_identity() {
	mut source := &NativeSourceRecorder{}
	mut native := ReadableStream.create(StreamRealm{}, UnderlyingSource{type_: .bytes, native_callbacks: source}, QueuingStrategy{})!
	assert voidptr(source.handle?.byte_controller?) == voidptr(native.byte_controller()!)
	promise := native.cancel(string_value('original reason'))
	assert promise.state() == .fulfilled && source.cancels == 1 && source.reason.text == 'original reason'
}

fn test_native_size_record_is_used_by_readable_and_writable_queues() {
	mut size := &NativeSizeRecorder{}
	mut native := ReadableStream.create(StreamRealm{}, UnderlyingSource{}, QueuingStrategy{high_water_mark: 5, size_object: size})!
	mut controller := native.default_controller()!
	controller.enqueue(number_value(1))!
	assert controller.desired_size()? == 3 && size.calls == 1
	mut writable := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{size_object: size})!
	mut writer := writable.get_writer()!
	assert writer.write(number_value(3)).state() == .fulfilled && size.calls == 2
}

fn test_native_byte_source_rejects_traced_size_algorithm_like_function_adapters() {
	mut size := &NativeSizeRecorder{}
	if _ := ReadableStream.create(StreamRealm{}, UnderlyingSource{type_: .bytes}, QueuingStrategy{size_object: size}) {
		assert false
	} else { assert err.msg().starts_with('RangeError:') }
	assert size.calls == 0
}
