module browserjs

import fileapi

fn test_source_sync_reader_returns_fresh_genuine_array_buffers_independent_of_actual_blob_and_each_other() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	mut input := [u8(9), 0, 255]
	blob := fileapi.Blob.create(input, 'application/octet-stream')
	first := runtime.source_file_reader_sync_array_buffer(reader, blob)!
	second := runtime.source_file_reader_sync_array_buffer(reader, blob)!
	actual_first := runtime.actual_webidl_value(first)!
	actual_second := runtime.actual_webidl_value(second)!
	assert actual_first != actual_second
	input[0] = 42
	view := runtime.source_uint8_array(first)!
	actual_view := runtime.actual_webidl_value(view)!
	runtime.define_value_host_function('__syncFirst', fn [actual_first] (_ voidptr, _ []voidptr) !voidptr {
		return actual_first
	})!
	runtime.define_value_host_function('__syncSecond', fn [actual_second] (_ voidptr, _ []voidptr) !voidptr {
		return actual_second
	})!
	runtime.define_value_host_function('__syncView', fn [actual_view] (_ voidptr, _ []voidptr) !voidptr {
		return actual_view
	})!
	assert runtime.evaluate_host('__syncFirst() instanceof ArrayBuffer&&__syncSecond() instanceof ArrayBuffer&&__syncFirst()!==__syncSecond()&&__syncView().buffer===__syncFirst()&&__syncFirst().byteLength===3')! == 'true'
	runtime.evaluate_host('__syncView()[0]=7;undefined')!
	assert runtime.source_array_buffer_bytes(first)! == [u8(7), 0, 255]
	assert runtime.source_array_buffer_bytes(second)! == [u8(9), 0, 255]
	assert blob.raw_bytes() == [u8(9), 0, 255]
	third := runtime.source_file_reader_sync_array_buffer(reader, blob)!
	assert runtime.actual_webidl_value(third)! != actual_first
	assert runtime.source_array_buffer_bytes(third)! == [u8(9), 0, 255]
}

fn test_source_sync_reader_uses_actual_target_realm_intrinsics_after_poisoned_author_aliases() {
	$if !darwin {
		return
	}
	mut first_runtime := Runtime.create()
	defer { first_runtime.close() }
	mut second_runtime := Runtime.create()
	defer { second_runtime.close() }
	reader := fileapi.FileReaderSync.create()
	blob := fileapi.Blob.create([u8(65)], '')
	first_runtime.evaluate_host('globalThis.targetArrayBufferPrototype=ArrayBuffer.prototype;globalThis.ArrayBuffer=function(){throw new Error("poisoned constructor")};globalThis.globalThis={ArrayBuffer:function(){throw new Error("poisoned global alias")}};undefined')!
	first := first_runtime.source_file_reader_sync_array_buffer(reader, blob)!
	second := second_runtime.source_file_reader_sync_array_buffer(reader, blob)!
	actual_first := first_runtime.actual_webidl_value(first)!
	actual_second := second_runtime.actual_webidl_value(second)!
	assert actual_first != actual_second
	first_runtime.define_value_host_function('__syncTarget', fn [actual_first] (_ voidptr, _ []voidptr) !voidptr {
		return actual_first
	})!
	second_runtime.define_value_host_function('__syncTarget', fn [actual_second] (_ voidptr, _ []voidptr) !voidptr {
		return actual_second
	})!
	assert first_runtime.evaluate_host('Object.getPrototypeOf(__syncTarget())===targetArrayBufferPrototype')! == 'true'
	assert second_runtime.evaluate_host('__syncTarget() instanceof ArrayBuffer&&Object.getPrototypeOf(__syncTarget())===ArrayBuffer.prototype')! == 'true'
	assert first_runtime.source_array_buffer_bytes(first)! == [u8(65)]
	assert second_runtime.source_array_buffer_bytes(second)! == [u8(65)]
}

fn test_source_sync_reader_empty_reads_remain_distinct_real_array_buffers_without_promise_tasks() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	reader := fileapi.FileReaderSync.create()
	blob := fileapi.Blob.create([], '')
	first := runtime.source_file_reader_sync_array_buffer(reader, blob)!
	second := runtime.source_file_reader_sync_array_buffer(reader, blob)!
	assert runtime.actual_webidl_value(first)! != runtime.actual_webidl_value(second)!
	assert runtime.source_array_buffer_bytes(first)!.len == 0
	assert runtime.source_array_buffer_bytes(second)!.len == 0
}
