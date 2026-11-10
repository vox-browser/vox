// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// TransformStreamOperations.cpp Promise algorithms. Native callbacks enqueue
// their output through the actual controller and retain pending callback work.
module streams

import webidl

fn adopt_callback_promise(mut target webidl.Promise, mut source webidl.Promise) {
	webidl.react_to_promise(mut source, fn [mut target] (_ webidl.Value) !webidl.Value {
		target.resolve(webidl.undefined_value())
		return webidl.undefined_value()
	}, fn [mut target] (reason webidl.Value) !webidl.Value {
		target.reject(reason)
		return webidl.undefined_value()
	})
}

fn (mut stream TransformStream) start_transformer(transformer Transformer, mut start_promise webidl.Promise) ! {
	if callback := transformer.start_callback {
		bound := stream_webidl_callback(callback, stream.realm_, .no)
		controller_value := stream_controller_callback_value(voidptr(stream.controller_), 'TransformStreamDefaultController')
		result := webidl.invoke_callback(bound, transformer.transformer_value, [controller_value])!
		start_promise.resolve(result)
	} else if algorithm := transformer.start_promise {
		mut result := algorithm()!
		adopt_callback_promise(mut start_promise, mut result)
	} else {
		if algorithm := transformer.start { algorithm()! }
		start_promise.resolve(webidl.undefined_value())
	}
}

fn (mut stream TransformStream) invoke_transform_promise(chunk Value) &webidl.Promise {
	if algorithm := stream.promise_transform_algorithm_ {
		return algorithm(chunk) or { rejected_callback_exception(stream.realm_, err) }
	}
	outputs := if algorithm := stream.transform_algorithm_ {
		algorithm(chunk) or { return rejected_callback_exception(stream.realm_, err) }
	} else {
		// A write waiting on backpressure can resume after cancellation cleared
		// the algorithms. The default identity algorithm is installed at setup;
		// an absent algorithm here has no work left to perform.
		return resolved_callback_promise(stream.realm_)
	}
	mut controller := stream.controller_
	for output in outputs {
		controller.enqueue(output) or { return rejected_callback_exception(stream.realm_, err) }
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream TransformStream) perform_transform_promise(chunk Value) &webidl.Promise {
	mut transform_promise := stream.invoke_transform_promise(chunk)
	return transform_promise.upon_rejection(fn [mut stream] (reason webidl.Value) !webidl.Value {
		stream.error_value(reason)
		return webidl.throw_value(reason)
	})
}

fn (mut stream TransformStream) sink_write_promise(chunk Value) &webidl.Promise {
	if !stream.backpressure_ { return stream.perform_transform_promise(chunk) }
	mut result := webidl.create_promise_for(stream.realm_.promise_context())
	mut changed := stream.backpressure_change_promise_.as_webidl_promise()
	webidl.react_to_promise(mut changed, fn [mut stream, mut result, chunk] (_ webidl.Value) !webidl.Value {
		if stream.writable_.state_ == .erroring {
			result.reject(stream.writable_.stored_error_value())
		} else {
			assert stream.writable_.state_ == .writable
			mut transformed := stream.perform_transform_promise(chunk)
			adopt_callback_promise(mut result, mut transformed)
		}
		return webidl.undefined_value()
	}, fn [mut result] (reason webidl.Value) !webidl.Value {
		result.reject(reason)
		return webidl.undefined_value()
	})
	return result
}

fn (mut stream TransformStream) invoke_flush_promise() &webidl.Promise {
	if algorithm := stream.promise_flush_algorithm_ {
		return algorithm() or { rejected_callback_exception(stream.realm_, err) }
	}
	if algorithm := stream.flush_algorithm_ {
		outputs := algorithm() or { return rejected_callback_exception(stream.realm_, err) }
		mut controller := stream.controller_
		for output in outputs {
			controller.enqueue(output) or { return rejected_callback_exception(stream.realm_, err) }
		}
	}
	return resolved_callback_promise(stream.realm_)
}

fn (mut stream TransformStream) invoke_transformer_cancel_promise(reason Value) &webidl.Promise {
	if algorithm := stream.promise_cancel_algorithm_ {
		return algorithm(reason) or { rejected_callback_exception(stream.realm_, err) }
	}
	if algorithm := stream.cancel_algorithm_ {
		algorithm(reason) or { return rejected_callback_exception(stream.realm_, err) }
	}
	return resolved_callback_promise(stream.realm_)
}

// https://streams.spec.whatwg.org/#transform-stream-default-sink-close-algorithm
fn (mut stream TransformStream) close_writable() &VoidPromise {
	mut controller := stream.controller_
	if !isnil(controller.finish_promise_) { return controller.finish_promise_ }
	mut finish := VoidPromise.pending_in(stream.realm_)
	controller.finish_promise_ = finish
	mut flush := stream.invoke_flush_promise()
	stream.clear_algorithms()
	webidl.react_to_promise(mut flush, fn [mut stream, mut finish] (_ webidl.Value) !webidl.Value {
		if stream.readable_.state_ == .errored { finish.reject_value(stream.readable_.stored_error_value()) }
		else {
			mut readable_controller := stream.readable_.default_controller_
			readable_stream_default_controller_close(mut readable_controller)
			finish.resolve()
		}
		return webidl.undefined_value()
	}, fn [mut stream, mut finish] (reason webidl.Value) !webidl.Value {
		mut readable := stream.readable_
		readable.error_value(reason)
		finish.reject_value(reason)
		return webidl.undefined_value()
	})
	return finish
}

// https://streams.spec.whatwg.org/#transform-stream-default-sink-abort-algorithm
fn (mut stream TransformStream) abort_writable(reason Value) &VoidPromise {
	mut controller := stream.controller_
	if !isnil(controller.finish_promise_) { return controller.finish_promise_ }
	mut finish := VoidPromise.pending_in(stream.realm_)
	controller.finish_promise_ = finish
	mut cancel := stream.invoke_transformer_cancel_promise(reason)
	stream.clear_algorithms()
	webidl.react_to_promise(mut cancel, fn [mut stream, mut finish, reason] (_ webidl.Value) !webidl.Value {
		if stream.readable_.state_ == .errored { finish.reject_value(stream.readable_.stored_error_value()) }
		else {
			mut readable := stream.readable_
			readable.error_value(stream_value_to_webidl(reason))
			finish.resolve()
		}
		return webidl.undefined_value()
	}, fn [mut stream, mut finish] (reason webidl.Value) !webidl.Value {
		mut readable := stream.readable_
		readable.error_value(reason)
		finish.reject_value(reason)
		return webidl.undefined_value()
	})
	return finish
}

// https://streams.spec.whatwg.org/#transform-stream-default-source-cancel
fn (mut stream TransformStream) cancel_readable(reason Value) &VoidPromise {
	mut controller := stream.controller_
	if !isnil(controller.finish_promise_) { return controller.finish_promise_ }
	mut finish := VoidPromise.pending_in(stream.realm_)
	controller.finish_promise_ = finish
	mut cancel := stream.invoke_transformer_cancel_promise(reason)
	stream.clear_algorithms()
	webidl.react_to_promise(mut cancel, fn [mut stream, mut finish, reason] (_ webidl.Value) !webidl.Value {
		if stream.writable_.state_ == .errored { finish.reject_value(stream.writable_.stored_error_value()) }
		else {
			mut writable_controller := stream.writable_.controller_
			writable_stream_default_controller_error_if_needed(mut writable_controller, reason)
			stream.unblock_write()
			finish.resolve()
		}
		return webidl.undefined_value()
	}, fn [mut stream, mut finish] (reason webidl.Value) !webidl.Value {
		mut writable_controller := stream.writable_.controller_
		writable_stream_default_controller_error_if_needed(mut writable_controller, stream_value_from_webidl(reason))
		stream.unblock_write()
		finish.reject_value(reason)
		return webidl.undefined_value()
	})
	return finish
}
