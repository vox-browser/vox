module browserjs

import dom
import fileapi
import html
import streams
import webidl

@[heap]
struct SourceBlobBytesObservation {
mut:
	read_all_buffer voidptr
	allocations     int
}

fn test_source_blob_bytes_fulfillment_returns_actual_view_sharing_the_read_all_buffer() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://source-blob-bytes.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut host := ReadableStreamHost.create(document)!
	host.install(mut runtime)!
	owner := voidptr(runtime)
	mut seen := &SourceBlobBytesObservation{}
	realm := streams.StreamRealm{
		...host.read_loop_realm()
		array_buffer_create: fn [owner, mut seen] (bytes []u8) !webidl.Value {
			mut runtime := unsafe { &Runtime(owner) }
			seen.allocations++
			return runtime.source_array_buffer(bytes)
		}
		uint8_array_create:  fn [owner, mut seen] (buffer webidl.Value) !webidl.Value {
			mut runtime := unsafe { &Runtime(owner) }
			seen.read_all_buffer = runtime.actual_webidl_value(buffer)!
			return runtime.source_uint8_array(buffer)
		}
	}
	blob := fileapi.Blob.create([u8(1), 2, 3], '')
	native := host.settings.blob_bytes_in_realm(blob, realm)
	assert native.state == .pending
	mut queue := host.settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
		return task.source() == .file_reading
	}) or { panic('missing Source Blob bytes task') }
	task.execute()
	assert native.state == .fulfilled && native.result.kind == .runtime_value
	assert seen.allocations == 1
	actual_view := runtime.actual_webidl_value(native.result)!
	original := seen.read_all_buffer
	runtime.define_value_host_function('__sourceBlobBytesBuffer', fn [original] (_ voidptr, _ []voidptr) !voidptr {
		return original
	})!
	runtime.define_value_host_function('__sourceBlobBytesView', fn [actual_view] (_ voidptr, _ []voidptr) !voidptr {
		return actual_view
	})!
	assert runtime.evaluate_host('__sourceBlobBytesView() instanceof Uint8Array&&__sourceBlobBytesView().buffer===__sourceBlobBytesBuffer()&&__sourceBlobBytesView().length===3')! == 'true'
	runtime.evaluate_host('__sourceBlobBytesView()[0]=9;undefined')!
	assert runtime.source_array_buffer_bytes(runtime.webidl_value(original)!)! == [
		u8(9),
		2,
		3,
	]
	assert blob.raw_bytes() == [u8(1), 2, 3]

	// Source allocation uses captured engine records for empty NewObject calls too.
	runtime.evaluate_host('globalThis.Uint8Array=function(){throw "author constructor"};Object.defineProperty(ArrayBuffer.prototype,"byteLength",{get(){throw "author slot getter"}});undefined')!
	empty := fileapi.Blob.create([]u8{}, '')
	first := host.settings.blob_bytes_in_realm(empty, realm)
	second := host.settings.blob_bytes_in_realm(empty, realm)
	assert first.state == .pending && second.state == .pending
	for _ in 0 .. 2 {
		empty_task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .file_reading
		}) or { panic('missing empty Source Blob bytes task') }
		empty_task.execute()
	}
	assert first.state == .fulfilled && second.state == .fulfilled
	first_view := runtime.actual_webidl_value(first.result)!
	second_view := runtime.actual_webidl_value(second.result)!
	assert first_view != second_view
	assert seen.allocations == 3
	witness := realm.uint8_array_bytes or { panic('missing Source Uint8Array witness') }
	first_bytes := witness(first.result)!
	second_bytes := witness(second.result)!
	assert (first_bytes.bytes or { panic('expected actual empty Uint8Array') }).len == 0
	assert (second_bytes.bytes or { panic('expected actual empty Uint8Array') }).len == 0
}
