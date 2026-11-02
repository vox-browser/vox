module browserjs

import streams
import webidl

fn C.JSGarbageCollect(context voidptr)

@[heap]
struct NativeWebIDLValues {
mut:
	values []voidptr
}

fn test_webidl_and_stream_native_values_preserve_actual_jsc_chunk_and_callback_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	chunk := runtime.evaluate_host_value('globalThis.actualChunk={};actualChunk.self=actualChunk;actualChunk')!
	native_value := runtime.webidl_value(chunk)!
	assert runtime.actual_webidl_value(native_value)! == chunk
	mut stream := streams.ReadableStream.create(streams.StreamRealm{}, streams.UnderlyingSource{}, streams.QueuingStrategy{ high_water_mark: 0 })!
	mut reader := stream.get_default_reader()!
	read := reader.read()
	stream.enqueue(streams.runtime_value(native_value))!
	result := read.as_webidl_promise().result.object_value['value'] or { panic('missing source result chunk') }
	assert runtime.actual_webidl_value(result)! == chunk
	runtime.define_value_host_function('__nativeReadChunk', fn [runtime, result] (_ voidptr, _ []voidptr) !voidptr { return runtime.actual_webidl_value(result) })!
	assert runtime.evaluate_host('__nativeReadChunk()===actualChunk')! == 'true'
	mut seen := &NativeWebIDLValues{}
	mut writable := streams.WritableStream.create(streams.StreamRealm{}, streams.UnderlyingSink{
		write_callback: webidl.CallbackType{
			callback: fn [runtime, mut seen] (_ webidl.Value, args []webidl.Value) !webidl.Value {
				seen.values << runtime.actual_webidl_value(args[0])!
				return webidl.undefined_value()
			}
		}
	}, streams.QueuingStrategy{})!
	mut writer := writable.get_writer()!
	written := writer.write(streams.runtime_value(native_value))
	assert written.state() == .fulfilled
	assert seen.values == [chunk]
}

fn test_native_webidl_runtime_value_conversion_and_context_ownership_use_actual_engine() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	mut other := Runtime.create()
	defer { runtime.close(); other.close() }
	value := runtime.evaluate_host_value('({toString(){return "actual string conversion"}})')!
	wrapped := runtime.webidl_value(value)!
	assert webidl.to_string(wrapped)! == 'actual string conversion'
	throwing := runtime.evaluate_host_value('globalThis.conversionReason={code:"actual conversion throw"};({toString(){throw conversionReason}})')!
	throwing_wrapped := runtime.webidl_value(throwing)!
	runtime.define_value_host_function('__nativeConversionThrows', fn [runtime, throwing_wrapped] (_ voidptr, _ []voidptr) !voidptr {
		webidl.to_string(throwing_wrapped)!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	})!
	assert runtime.evaluate_host('let caught;try{__nativeConversionThrows()}catch(error){caught=error}caught===conversionReason')! == 'true'
	if _ := other.actual_webidl_value(wrapped) { assert false } else { assert err.msg().contains('another JavaScriptCore context') }
	C.JSGarbageCollect(runtime.context)
	assert webidl.to_string(wrapped)! == 'actual string conversion'
	runtime.close()
	if _ := webidl.to_string(wrapped) { assert false } else { assert err.msg().contains('closed') }
}

fn test_native_number_projection_checks_actual_engine_brand_without_coercion() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	for expression in ['1.25', '-3', 'Infinity', '-Infinity', 'NaN'] {
		actual := runtime.evaluate_host_value(expression)!
		value := runtime.webidl_value(actual)!
		assert value.number_primitive() != none
		assert runtime.actual_webidl_value(value)! == actual
	}
	for expression in ['null', 'true', '"1"', '1n', 'Symbol()', '({valueOf(){throw "must not coerce"},[Symbol.toPrimitive](){throw "must not coerce"}})'] {
		actual := runtime.evaluate_host_value(expression)!
		value := runtime.webidl_value(actual)!
		assert value.number_primitive() == none
		assert runtime.actual_webidl_value(value)! == actual
	}
}
