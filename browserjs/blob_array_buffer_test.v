module browserjs

import dom
import fileapi
import html
import streams
import webidl

@[heap]
struct SourceBlobArrayBufferObservation {
mut:
	read_all_buffer voidptr
}

fn test_source_blob_array_buffer_fulfillment_copies_into_a_distinct_actual_engine_buffer() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://source-blob-array-buffer.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut host := ReadableStreamHost.create(document)!
	host.install(mut runtime)!
	owner := voidptr(runtime)
	mut seen := &SourceBlobArrayBufferObservation{}
	realm := streams.StreamRealm{
		...host.read_loop_realm()
		array_buffer_copy: fn [owner, mut seen] (value webidl.Value) ![]u8 {
			mut runtime := unsafe { &Runtime(owner) }
			seen.read_all_buffer = runtime.actual_webidl_value(value)!
			return runtime.source_array_buffer_bytes(value)
		}
	}
	blob := fileapi.Blob.create([u8(1), 2, 3], '')
	native := host.settings.blob_array_buffer_in_realm(blob, realm)
	assert native.state == .pending
	mut queue := host.settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	}) or { panic('missing Source Blob ArrayBuffer task') }
	task.execute()
	assert native.state == .fulfilled && native.result.kind == .runtime_value
	actual_buffer := runtime.actual_webidl_value(native.result)!
	assert actual_buffer != seen.read_all_buffer
	assert runtime.source_array_buffer_bytes(native.result)! == [u8(1), 2, 3]
	original := seen.read_all_buffer
	runtime.define_value_host_function('__originalBlobReadAllBuffer', fn [original] (_ voidptr, _ []voidptr) !voidptr {
		return original
	})!
	runtime.define_value_host_function('__copiedBlobArrayBuffer', fn [actual_buffer] (_ voidptr, _ []voidptr) !voidptr {
		return actual_buffer
	})!
	assert runtime.evaluate_host('__copiedBlobArrayBuffer() instanceof ArrayBuffer&&__originalBlobReadAllBuffer()!==__copiedBlobArrayBuffer()')! == 'true'
	runtime.evaluate_host('new Uint8Array(__copiedBlobArrayBuffer())[0]=9;undefined')!
	assert runtime.source_array_buffer_bytes(native.result)! == [u8(9), 2, 3]
	assert runtime.source_array_buffer_bytes(runtime.webidl_value(original)!)! == [
		u8(1),
		2,
		3,
	]
	assert blob.raw_bytes() == [u8(1), 2, 3]
}
