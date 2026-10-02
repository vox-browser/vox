// ReadableStream.idl pipeTo/pipeThrough generated argument conversions and
// ReadableStream.cpp entry points. All data flow belongs to native Streams.
module browserjs

import streams

fn (mut host ReadableStreamHost) pipe_options(value voidptr) !streams.StreamPipeOptions {
	if C.JSValueIsUndefined(host.runtime.context, value) || C.JSValueIsNull(host.runtime.context, value) { return streams.StreamPipeOptions{} }
	if !C.JSValueIsObject(host.runtime.context, value) { return error('TypeError: pipe options must be a dictionary') }
	prevent_abort := C.JSValueToBoolean(host.runtime.context, host.property(value, 'preventAbort')!)
	prevent_cancel := C.JSValueToBoolean(host.runtime.context, host.property(value, 'preventCancel')!)
	prevent_close := C.JSValueToBoolean(host.runtime.context, host.property(value, 'preventClose')!)
	actual_signal := host.property(value, 'signal')!
	mut signal := ?&streams.AbortSignal(none)
	if !C.JSValueIsUndefined(host.runtime.context, actual_signal) { signal = streams.AbortSignal.from_dom(host.runtime.native_abort_signal(actual_signal)!) }
	return streams.StreamPipeOptions{prevent_abort: prevent_abort, prevent_cancel: prevent_cancel, prevent_close: prevent_close, signal: signal}
}

fn (mut host ReadableStreamHost) pipe_pair(value voidptr) !streams.ReadableWritablePair {
	if C.JSValueIsUndefined(host.runtime.context, value) || C.JSValueIsNull(host.runtime.context, value) { return error('TypeError: ReadableWritablePair is missing required members') }
	if !C.JSValueIsObject(host.runtime.context, value) { return error('TypeError: ReadableWritablePair must be a dictionary') }
	readable_value := host.property(value, 'readable')!
	readable := host.runtime.native_readable_stream(readable_value)!
	writable_value := host.property(value, 'writable')!
	writable := host.runtime.native_writable_stream(writable_value)!
	return streams.ReadableWritablePair{readable: readable, writable: writable}
}

fn (mut host ReadableStreamHost) pipe_operation(mut source streams.ReadableStream, operation string, argument voidptr, options_value voidptr) !voidptr {
	if operation == 'stream.pipeTo' {
		mut destination := host.runtime.native_writable_stream(argument)!
		options := host.pipe_options(options_value)!
		return host.promise(source.pipe_to(mut destination, options).as_webidl_promise())
	}
	pair := host.pipe_pair(argument)!
	options := host.pipe_options(options_value)!
	readable := source.pipe_through(pair, options)!
	return host.runtime.javascript_readable_stream(readable)
}
