module browserjs

fn test_source_array_buffer_allocations_and_uint8_views_own_genuine_engine_identity_and_slots() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut original := [u8(4), 5]
	buffer := runtime.source_array_buffer(original)!
	actual_buffer := runtime.actual_webidl_value(buffer)!
	view := runtime.source_uint8_array(buffer)!
	actual_view := runtime.actual_webidl_value(view)!
	runtime.define_value_host_function('__sourceBuffer', fn [actual_buffer] (_ voidptr, _ []voidptr) !voidptr {
		return actual_buffer
	})!
	runtime.define_value_host_function('__sourceView', fn [actual_view] (_ voidptr, _ []voidptr) !voidptr {
		return actual_view
	})!
	assert runtime.evaluate_host('__sourceBuffer() instanceof ArrayBuffer&&__sourceView() instanceof Uint8Array&&__sourceView().buffer===__sourceBuffer()&&__sourceView().byteOffset===0&&__sourceView().byteLength===2')! == 'true'
	original[0] = 99
	assert runtime.source_array_buffer_bytes(buffer)! == [u8(4), 5]
	runtime.evaluate_host('globalThis.originalBuffer=__sourceBuffer();globalThis.originalView=__sourceView();originalView[0]=8;Object.defineProperty(originalBuffer,"byteLength",{get(){throw new Error("author length getter")}});Object.defineProperty(ArrayBuffer.prototype,"byteLength",{get(){throw new Error("author prototype getter")}});globalThis.ArrayBuffer=function(){throw new Error("author constructor")};globalThis.Uint8Array=function(){throw new Error("author view constructor")};undefined')!
	assert runtime.source_array_buffer_bytes(buffer)! == [u8(8), 5]
	second_view := runtime.source_uint8_array(buffer)!
	actual_second := runtime.actual_webidl_value(second_view)!
	assert actual_second != actual_view
	runtime.define_value_host_function('__sourceSecondView', fn [actual_second] (_ voidptr, _ []voidptr) !voidptr {
		return actual_second
	})!
	assert runtime.evaluate_host('__sourceSecondView().buffer===originalBuffer&&__sourceSecondView()[0]===8')! == 'true'
	second_buffer := runtime.source_array_buffer([u8(1)])!
	assert runtime.source_array_buffer_bytes(second_buffer)! == [u8(1)]
	assert runtime.actual_webidl_value(second_buffer)! != actual_buffer
}

fn test_source_empty_array_buffer_and_uint8_allocations_retain_distinct_new_objects() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	first := runtime.source_array_buffer([])!
	second := runtime.source_array_buffer([])!
	assert runtime.actual_webidl_value(first)! != runtime.actual_webidl_value(second)!
	assert runtime.source_array_buffer_bytes(first)!.len == 0
	view := runtime.source_uint8_array(first)!
	actual_buffer := runtime.actual_webidl_value(first)!
	actual_view := runtime.actual_webidl_value(view)!
	runtime.define_value_host_function('__emptySourceBuffer', fn [actual_buffer] (_ voidptr, _ []voidptr) !voidptr {
		return actual_buffer
	})!
	runtime.define_value_host_function('__emptySourceView', fn [actual_view] (_ voidptr, _ []voidptr) !voidptr {
		return actual_view
	})!
	assert runtime.evaluate_host('__emptySourceView().buffer===__emptySourceBuffer()&&__emptySourceView().length===0&&__emptySourceBuffer().byteLength===0')! == 'true'
}
