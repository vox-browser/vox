module browserjs

import dom
import html
import streams
import webidl

fn actual_pipe_document() &dom.Document {
	url := dom.URL{value: 'https://actual-pipe.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_actual_dom_signal_pipe_waits_for_both_actions_and_rejects_with_original_jsc_reason() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(actual_pipe_document())!
	host.install(mut runtime)!
	settings := host.settings
	mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	actual := runtime.evaluate_host_value('globalThis.pipeReasonCoercions=0;({toString(){pipeReasonCoercions++;throw new Error("must retain reason")}})')!
	reason := runtime.webidl_value(actual)!
	mut cancel := webidl.create_promise_for(settings.stream_promise_context())
	mut abort := webidl.create_promise_for(settings.stream_promise_context())
	mut source := settings.create_readable_stream(streams.UnderlyingSource{
		cancel_callback: webidl.CallbackType{callback: fn [runtime, actual, cancel] (_ webidl.Value, args []webidl.Value) !webidl.Value {
			assert runtime.actual_webidl_value(args[0])! == actual
			return webidl.promise_value(cancel)
		}}
	}, streams.QueuingStrategy{high_water_mark: 0})!
	mut destination := settings.create_writable_stream(streams.UnderlyingSink{
		abort_callback: webidl.CallbackType{callback: fn [runtime, actual, abort] (_ webidl.Value, args []webidl.Value) !webidl.Value {
			assert runtime.actual_webidl_value(args[0])! == actual
			return webidl.promise_value(abort)
		}}
	}, streams.QueuingStrategy{})!
	event_loop.perform_a_microtask_checkpoint()
	mut native_signal := dom.AbortSignal.new()
	signal := streams.AbortSignal.from_dom(native_signal)
	piped := source.pipe_to(mut destination, streams.StreamPipeOptions{signal: signal})
	event_loop.perform_a_microtask_checkpoint()
	native_signal.signal_abort(dom.js_webidl_value(reason))
	event_loop.perform_a_microtask_checkpoint()
	assert piped.state() == .pending
	assert source.locked() && destination.locked()
	cancel.resolve(webidl.undefined_value())
	event_loop.perform_a_microtask_checkpoint()
	assert piped.state() == .pending
	abort.resolve(webidl.undefined_value())
	event_loop.perform_a_microtask_checkpoint()
	assert piped.state() == .rejected
	assert runtime.actual_webidl_value(piped.as_webidl_promise().result)! == actual
	assert !source.locked() && !destination.locked()
	assert native_signal.abort_algorithms.len == 0
	assert runtime.evaluate_host('pipeReasonCoercions')! == '0'
}

fn test_pipe_source_original_error_and_later_abort_rejection_keep_source_precedence_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(actual_pipe_document())!
	host.install(mut runtime)!
	settings := host.settings
	mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	original := runtime.evaluate_host_value('({source:"original pipe error"})')!
	replacement := runtime.evaluate_host_value('Symbol("later abort rejection")')!
	for reject_action in [false, true] {
		mut abort := webidl.create_promise_for(settings.stream_promise_context())
		mut source := settings.create_readable_stream(streams.UnderlyingSource{}, streams.QueuingStrategy{high_water_mark: 0})!
		mut destination := settings.create_writable_stream(streams.UnderlyingSink{
			abort_callback: webidl.CallbackType{callback: fn [runtime, original, abort] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				assert runtime.actual_webidl_value(args[0])! == original
				return webidl.promise_value(abort)
			}}
		}, streams.QueuingStrategy{})!
		event_loop.perform_a_microtask_checkpoint()
		piped := source.pipe_to(mut destination, streams.StreamPipeOptions{})
		source.error_value(runtime.webidl_value(original)!)
		event_loop.perform_a_microtask_checkpoint()
		assert piped.state() == .pending
		if reject_action { abort.reject(runtime.webidl_value(replacement)!) }
		else { abort.resolve(webidl.undefined_value()) }
		event_loop.perform_a_microtask_checkpoint()
		assert piped.state() == .rejected
		result := runtime.actual_webidl_value(piped.as_webidl_promise().result)!
		if reject_action { assert result == replacement }
		else { assert result == original }
		assert !source.locked() && !destination.locked()
	}
}

fn test_pipe_pending_write_error_and_later_cancel_rejection_keep_actual_jsc_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(actual_pipe_document())!
	host.install(mut runtime)!
	settings := host.settings
	mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
	original := runtime.evaluate_host_value('Symbol("original write error")')!
	replacement := runtime.evaluate_host_value('({source:"later cancel rejection"})')!
	for reject_action in [false, true] {
		mut write := webidl.create_promise_for(settings.stream_promise_context())
		mut cancel := webidl.create_promise_for(settings.stream_promise_context())
		mut source := settings.create_readable_stream(streams.UnderlyingSource{
			cancel_callback: webidl.CallbackType{callback: fn [runtime, original, cancel] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				assert runtime.actual_webidl_value(args[0])! == original
				return webidl.promise_value(cancel)
			}}
		}, streams.QueuingStrategy{high_water_mark: 0})!
		mut destination := settings.create_writable_stream(streams.UnderlyingSink{
			write_callback: webidl.CallbackType{callback: fn [write] (_ webidl.Value, _ []webidl.Value) !webidl.Value { return webidl.promise_value(write) }}
		}, streams.QueuingStrategy{})!
		event_loop.perform_a_microtask_checkpoint()
		piped := source.pipe_to(mut destination, streams.StreamPipeOptions{})
		source.enqueue(streams.string_value('native queued chunk'))!
		event_loop.perform_a_microtask_checkpoint()
		assert piped.state() == .pending
		write.reject(runtime.webidl_value(original)!)
		event_loop.perform_a_microtask_checkpoint()
		assert piped.state() == .pending
		if reject_action { cancel.reject(runtime.webidl_value(replacement)!) }
		else { cancel.resolve(webidl.undefined_value()) }
		event_loop.perform_a_microtask_checkpoint()
		assert piped.state() == .rejected
		result := runtime.actual_webidl_value(piped.as_webidl_promise().result)!
		if reject_action { assert result == replacement }
		else { assert result == original }
		assert !source.locked() && !destination.locked()
	}
}
