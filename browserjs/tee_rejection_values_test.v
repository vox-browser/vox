module browserjs

import dom
import html
import streams
import webidl

fn tee_actual_document() &dom.Document {
	url := dom.URL{'https://tee-values.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_source_tee_reader_closed_rejection_retains_actual_jsc_reason_for_default_and_byte_branches() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(tee_actual_document())!
	host.install(mut runtime)!
	settings := host.settings
	mut owner := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	actual := runtime.evaluate_host_value('globalThis.teeReasonCoercions=0;({toString(){teeReasonCoercions++;throw "never coerce tee reason"}})')!
	for type_ in [streams.UnderlyingSourceType.default_source, .bytes] {
		mut source := settings.create_readable_stream(streams.UnderlyingSource{type_: type_}, streams.QueuingStrategy{high_water_mark: 0})!
		pair := source.tee()!
		mut first := pair.first
		mut second := pair.second
		owner.perform_a_microtask_checkpoint()
		cancelled := first.cancel(streams.string_value('one branch only'))
		source.error_value(runtime.webidl_value(actual)!)
		assert cancelled.state() == .pending
		owner.perform_a_microtask_checkpoint()
		assert cancelled.state() == .fulfilled
		assert runtime.actual_webidl_value(second.stored_error_value())! == actual
		mut reader := second.get_default_reader()!
		read := reader.read()
		assert runtime.actual_webidl_value(read.as_webidl_promise().result)! == actual
	}
	assert runtime.evaluate_host('teeReasonCoercions')! == '0'
}

fn test_tee_shared_pending_source_cancellation_keeps_actual_jsc_rejection_for_both_branches() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(tee_actual_document())!
	host.install(mut runtime)!
	settings := host.settings
	mut owner := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	actual := runtime.evaluate_host_value('Symbol("actual tee cancellation failure")')!
	for type_ in [streams.UnderlyingSourceType.default_source, .bytes] {
		mut cancel := webidl.create_promise_for(settings.stream_promise_context())
		mut source := settings.create_readable_stream(streams.UnderlyingSource{
			type_: type_
			cancel_promise: fn [cancel] (_ streams.Value) !&webidl.Promise { return cancel }
		}, streams.QueuingStrategy{high_water_mark: 0})!
		pair := source.tee()!
		mut first := pair.first
		mut second := pair.second
		owner.perform_a_microtask_checkpoint()
		a := first.cancel(streams.string_value('first'))
		b := second.cancel(streams.string_value('second'))
		assert a.state() == .pending && b.state() == .pending
		cancel.reject(runtime.webidl_value(actual)!)
		owner.perform_a_microtask_checkpoint()
		assert a.state() == .rejected && b.state() == .rejected
		assert runtime.actual_webidl_value(a.as_webidl_promise().result)! == actual
		assert runtime.actual_webidl_value(b.as_webidl_promise().result)! == actual
	}
}
