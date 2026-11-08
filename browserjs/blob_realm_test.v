module browserjs

import dom
import fileapi
import html
import webidl

fn source_blob_realm_host(mut runtime Runtime) !&ReadableStreamHost {
	url := dom.URL{value: 'https://source-blob-realm.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut host := ReadableStreamHost.create(document)!
	host.install(mut runtime)!
	return host
}

fn execute_source_blob_realm_task(host &ReadableStreamHost) {
	mut queue := host.settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	}) or { panic('missing Source Blob FileReading task') }
	assert task.source() == .file_reading && task.document() == host.settings.responsible_document()
	task.execute()
}

fn test_source_blob_read_all_allocates_the_genuine_array_buffer_before_native_promise_delivery() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host := source_blob_realm_host(mut runtime)!
	blob := fileapi.Blob.create([u8(1), 2], '')
	native := host.settings.read_all_blob_bytes_in_realm(blob, host.read_loop_realm())
	owner := voidptr(runtime)
	actual_promise := runtime.javascript_webidl_promise(native, fn [owner] (value webidl.Value) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		return runtime.actual_webidl_value(value)
	})!
	runtime.define_value_host_function('__blobReadAll', fn [actual_promise] (_ voidptr, _ []voidptr) !voidptr {
		return actual_promise
	})!
	runtime.evaluate_host('globalThis.blobDone=false;__blobReadAll().then(value=>{globalThis.blobBuffer=value;blobDone=true});undefined')!
	assert native.state == .pending && runtime.evaluate_host('blobDone')! == 'false'
	execute_source_blob_realm_task(host)
	assert native.state == .fulfilled && native.result.kind == .runtime_value
	assert runtime.evaluate_host('blobDone&&blobBuffer instanceof ArrayBuffer&&blobBuffer.byteLength===2&&new Uint8Array(blobBuffer)[1]===2')! == 'true'
	actual_buffer := runtime.actual_webidl_value(native.result)!
	runtime.define_value_host_function('__sourceBlobBuffer', fn [actual_buffer] (_ voidptr, _ []voidptr) !voidptr {
		return actual_buffer
	})!
	assert runtime.evaluate_host('blobBuffer===__sourceBlobBuffer()')! == 'true'
}

fn test_source_blob_native_stream_and_text_keep_actual_owner_tasks_and_engine_slot_decoding() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host := source_blob_realm_host(mut runtime)!
	blob := fileapi.Blob.create([u8(0xFF), 0xFE, 0x61, 0], 'text/plain;charset=UTF-8')
	stream := host.settings.get_blob_stream_in_realm(blob, host.read_loop_realm())
	actual_stream := runtime.javascript_readable_stream(stream)!
	runtime.define_value_host_function('__blobStream', fn [actual_stream] (_ voidptr, _ []voidptr) !voidptr {
		return actual_stream
	})!
	runtime.evaluate_host('globalThis.sourceReader=__blobStream().getReader();globalThis.sourceChunkDone=false;sourceReader.read().then(result=>{globalThis.sourceChunk=result;sourceChunkDone=true});undefined')!
	assert runtime.evaluate_host('__blobStream() instanceof ReadableStream&&!sourceChunkDone')! == 'true'
	execute_source_blob_realm_task(host)
	assert runtime.evaluate_host('sourceChunkDone&&!sourceChunk.done&&sourceChunk.value instanceof Uint8Array&&sourceChunk.value.length===4&&sourceChunk.value[0]===255')! == 'true'
	native := host.settings.blob_text_in_realm(blob, host.read_loop_realm())
	owner := voidptr(runtime)
	actual_promise := runtime.javascript_webidl_promise(native, fn [owner] (value webidl.Value) !voidptr {
		runtime := unsafe { &Runtime(owner) }
		return runtime.binding_utf16_string(value.string_utf16())
	})!
	runtime.define_value_host_function('__blobText', fn [actual_promise] (_ voidptr, _ []voidptr) !voidptr {
		return actual_promise
	})!
	runtime.evaluate_host('globalThis.sourceTextDone=false;__blobText().then(text=>{globalThis.sourceText=text;sourceTextDone=true});Object.defineProperty(ArrayBuffer.prototype,"byteLength",{get(){throw new Error("author slot getter")}});globalThis.ArrayBuffer=function(){throw new Error("author constructor")};undefined')!
	assert native.state == .pending
	execute_source_blob_realm_task(host)
	assert native.state == .fulfilled
	assert runtime.evaluate_host('sourceTextDone&&sourceText==="\ufffd\ufffda\\u0000"')! == 'true'
}
