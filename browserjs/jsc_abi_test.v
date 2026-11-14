module browserjs

fn test_jsc_abi_exception_outputs_preserve_identity_and_accept_null() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	context := runtime.context
	token := runtime.evaluate_host_value('globalThis.abiThrown = {tag: "original"}; abiThrown')!
	number := runtime.evaluate_host_value('42')!
	mut exception := token
	assert C.vox_jsc_JSValueToNumber(context, number, &exception) == 42
	assert exception == token
	assert C.vox_jsc_JSValueToNumber(context, number, unsafe { nil }) == 42

	throwing_value := runtime.evaluate_host_value('({valueOf() { throw abiThrown; }})')!
	exception = unsafe { nil }
	failed_number := C.vox_jsc_JSValueToNumber(context, throwing_value, &exception)
	assert failed_number != failed_number
	assert exception == token
	ignored_number := C.vox_jsc_JSValueToNumber(context, throwing_value, unsafe { nil })
	assert ignored_number != ignored_number

	script := js_source_string('throw abiThrown')
	defer { C.JSStringRelease(script) }
	exception = unsafe { nil }
	result := C.vox_jsc_JSEvaluateScript(context, script, unsafe { nil }, unsafe { nil },
		1, &exception)
	assert result == unsafe { nil }
	assert exception == token
	assert C.vox_jsc_JSEvaluateScript(context, script, unsafe { nil }, unsafe { nil },
		1, unsafe { nil }) == unsafe { nil }
	assert runtime.evaluate_host('6 * 7')! == '42'
}

fn test_jsc_abi_promise_output_functions_resolve_and_reject() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	fulfilled := runtime.create_javascript_promise()!
	defer { runtime.release_javascript_promise(fulfilled) }
	rejected := runtime.create_javascript_promise()!
	defer { runtime.release_javascript_promise(rejected) }
	for capability in [fulfilled, rejected] {
		assert capability.promise != unsafe { nil }
		assert capability.resolve != unsafe { nil }
		assert capability.reject != unsafe { nil }
		assert capability.resolve != capability.reject
	}
	token := runtime.evaluate_host_value('({tag: "settled value"})')!
	observe := runtime.evaluate_host_value(r'(function(fulfilled, rejected, expected) {
		globalThis.abiSettled = [];
		fulfilled.then(value => abiSettled.push(value === expected ? "fulfilled" : "wrong value"),
			() => abiSettled.push("unexpected rejection"));
		rejected.then(() => abiSettled.push("unexpected fulfillment"),
			reason => abiSettled.push(reason === expected ? "rejected" : "wrong reason"));
	})')!
	runtime.call_javascript_function(observe, unsafe { nil }, [fulfilled.promise,
		rejected.promise, token])!
	runtime.resolve_javascript_promise(fulfilled, token)!
	runtime.reject_javascript_promise(rejected, token)!
	assert runtime.evaluate_host('JSON.stringify(abiSettled)')! == '["fulfilled","rejected"]'
	runtime.reject_javascript_promise(fulfilled, token)!
	runtime.resolve_javascript_promise(rejected, token)!
	assert runtime.evaluate_host('JSON.stringify(abiSettled)')! == '["fulfilled","rejected"]'
	assert C.vox_jsc_JSObjectMakeDeferredPromise(runtime.context, unsafe { nil },
		unsafe { nil }, unsafe { nil }) != unsafe { nil }
}

fn test_jsc_abi_typed_array_outputs_preserve_view_bounds() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	context := runtime.context
	whole := runtime.evaluate_host_value('globalThis.abiBytes = new Uint8Array([10,20,30,40,50,60,70,80]); abiBytes')!
	view := runtime.evaluate_host_value('abiBytes.subarray(2, 5)')!
	mut exception := unsafe { nil }
	length := C.vox_jsc_JSObjectGetTypedArrayByteLength(context, view, &exception)
	offset := C.vox_jsc_JSObjectGetTypedArrayByteOffset(context, view, &exception)
	buffer := C.vox_jsc_JSObjectGetTypedArrayBuffer(context, view, &exception)
	assert exception == unsafe { nil }
	assert length == 3
	assert offset == 2
	assert C.vox_jsc_JSObjectGetArrayBufferByteLength(context, buffer, &exception) == 8
	assert exception == unsafe { nil }

	// Consume each temporary byte pointer before another engine call can invalidate it.
	whole_pointer := C.vox_jsc_JSObjectGetTypedArrayBytesPtr(context, whole, &exception)
	assert exception == unsafe { nil }
	assert whole_pointer != unsafe { nil }
	whole_bytes := unsafe { (&u8(whole_pointer)).vbytes(8).clone() }
	assert whole_bytes == [u8(10), 20, 30, 40, 50, 60, 70, 80]
	buffer_pointer := C.vox_jsc_JSObjectGetArrayBufferBytesPtr(context, buffer, &exception)
	assert exception == unsafe { nil }
	assert buffer_pointer != unsafe { nil }
	view_bytes := unsafe { (&u8(buffer_pointer) + int(offset)).vbytes(int(length)).clone() }
	assert view_bytes == [u8(30), 40, 50]

	mut original := [u8(1), 2, 3]
	owned_buffer := runtime.source_array_buffer(original)!
	original[0] = 99
	assert runtime.source_array_buffer_bytes(owned_buffer)! == [u8(1), 2, 3]
}

fn test_jsc_abi_error_and_function_argument_arrays_keep_order() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	context := runtime.context
	message := runtime.evaluate_host_value('"array error"')!
	mut exception := unsafe { nil }
	object := C.vox_jsc_JSObjectMakeError(context, 1, &message, &exception)
	assert exception == unsafe { nil }
	assert object != unsafe { nil }
	runtime.retain_javascript_value(object)!
	assert js_string_to_v(context, runtime.binding_property(object, 'message')!)! == 'array error'

	// Long parameter lists must preserve every name and value.
	mut parameters := []string{}
	mut names := []voidptr{}
	mut values := []voidptr{}
	mut expected := []string{}
	for index in 0 .. 32 {
		parameters << 'p${index}'
		names << js_source_string(parameters[index])
		values << C.vox_jsc_JSValueMakeNumber(context, f64(index))
		expected << index.str()
	}
	defer {
		for name in names { C.JSStringRelease(name) }
	}
	body := js_source_string('return [' + parameters.join(',') + '].join(",");')
	defer { C.JSStringRelease(body) }
	function := C.vox_jsc_JSObjectMakeFunction(context, unsafe { nil }, u32(names.len),
		names.data, body, unsafe { nil }, 1, &exception)
	assert exception == unsafe { nil }
	assert function != unsafe { nil }
	runtime.retain_javascript_value(function)!
	result := C.vox_jsc_JSObjectCallAsFunction(context, function, unsafe { nil },
		uint(values.len), values.data, &exception)
	assert exception == unsafe { nil }
	assert js_string_to_v(context, result)! == expected.join(',')
}

fn test_jsc_abi_value_callbacks_keep_large_argument_lists_and_exceptions() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	context := runtime.context
	receiver := runtime.evaluate_host_value('({tag: "receiver"})')!
	token := runtime.evaluate_host_value('({tag: "callback exception"})')!
	callback := fn [context, receiver, token] (actual_receiver voidptr, args []voidptr) !voidptr {
		if actual_receiver != receiver { return error('Callback receiver changed') }
		if args.len != 64 { return error('Callback arguments were truncated') }
		if args[63] == token {
			return JavaScriptValueException{context: context, value: token}
		}
		for index, value in args {
			if C.vox_jsc_JSValueToNumber(context, value, unsafe { nil }) != f64(index) {
				return error('Callback argument ${index} changed')
			}
		}
		return args[63]
	}
	runtime.define_value_host_function('abiDefinedValue', callback)!
	defined := runtime.evaluate_host_value('abiDefinedValue')!
	host := runtime.make_value_host_function(callback)!
	native := runtime.make_native_value_host_function('abiNativeValue', 64, callback)!
	mut values := []voidptr{}
	for index in 0 .. 64 {
		values << C.vox_jsc_JSValueMakeNumber(context, f64(index))
	}
	mut throwing_values := values.clone()
	throwing_values[63] = token
	for function in [defined, host, native] {
		result := runtime.call_javascript_function(function, receiver, values)!
		assert C.vox_jsc_JSValueToNumber(context, result, unsafe { nil }) == 63
		if _ := runtime.call_javascript_function(function, receiver, throwing_values) {
			assert false
		} else {
			if err is JavaScriptValueException {
				assert err.context == context
				assert err.value == token
			} else {
				assert false, err.msg()
			}
		}
		recovered := runtime.call_javascript_function(function, receiver, values)!
		assert C.vox_jsc_JSValueToNumber(context, recovered, unsafe { nil }) == 63
	}
}

fn test_jsc_abi_string_callback_preserves_data_and_recovers_after_errors() {
	$if !darwin && !linux { return }
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	value := runtime.evaluate_host_value(r'"A\u0000\uD800"')!
	projected := runtime.native_utf16_string(value)!
	assert projected.code_units() == [u16(65), 0, 0xd800]
	converted := runtime.binding_dom_utf16(value)!
	assert converted.code_units() == projected.code_units()
	round_trip := runtime.javascript_utf16_string(projected)!
	restored := runtime.native_utf16_string(round_trip)!
	assert restored.code_units() == projected.code_units()
	empty_value := runtime.evaluate_host_value('""')!
	empty := runtime.native_utf16_string(empty_value)!
	assert empty.code_units().len == 0
	runtime.define_host_function('abiString', fn (input string) !string {
		if input == 'throw' { return error('string callback failure') }
		return input + '✓'
	})!
	assert runtime.evaluate_host(r'abiString("λ\u0000😀", ...Array.from({length: 63}, (_, index) => index))')! == 'λ\x00😀✓'
	assert runtime.evaluate_host('abiString()')! == 'undefined✓'
	if _ := runtime.evaluate_host('abiString("throw", ...Array.from({length: 63}, (_, index) => index))') {
		assert false
	} else {
		if err is JavaScriptValueException {
			assert err.context == runtime.context
			assert js_exception_message(err.context, err.value).contains('string callback failure')
		} else {
			assert false, err.msg()
		}
	}
	assert runtime.evaluate_host('abiString("recovered")')! == 'recovered✓'
}
