module html

import dom
import fileapi
import webidl

fn blob_text_settings() &EnvironmentSettingsObject {
	url := dom.URL{value: 'https://blob-text.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	window := WindowModel.create_top_level(document, none, 'blob-text') or { panic(err) }
	mut settings := window.environment_settings_.settings
	settings.responsible_event_loop_ = EventLoop.create(.window)
	return settings
}

fn finish_blob_text_task(settings &EnvironmentSettingsObject) {
	mut owner := unsafe { &EventLoop(settings.responsible_event_loop()) }
	mut queue := owner.task_queue()
	task := queue.take_first_runnable() or { panic('missing Blob text FileReading task') }
	assert task.source() == .file_reading
	assert task.document() == settings.responsible_document()
	task.execute()
	owner.perform_a_microtask_checkpoint()
}

fn test_blob_text_owns_a_distinct_pending_fulfillment_promise_for_each_call() {
	settings := blob_text_settings()
	mut owner := unsafe { &EventLoop(settings.responsible_event_loop()) }
	blob := fileapi.Blob.create('héllo'.bytes(), 'text/plain;charset=windows-1252')
	first := settings.blob_text(blob)
	second := settings.blob_text(blob)
	assert first != second
	assert first.state == .pending && second.state == .pending
	assert webidl.promise_realm(first) == u64(voidptr(settings.realm()))
	assert webidl.promise_realm(second) == u64(voidptr(settings.realm()))
	owner.perform_a_microtask_checkpoint()
	assert first.state == .pending && second.state == .pending
	finish_blob_text_task(settings)
	assert first.state == .fulfilled && first.result.string_value == 'héllo'
	assert first.result.string_utf16().code_units() == [u16(0x68), 0xE9, 0x6C, 0x6C, 0x6F]
	assert second.state == .pending
	finish_blob_text_task(settings)
	assert second.state == .fulfilled && second.result.string_value == 'héllo'
}

fn test_blob_text_decodes_only_utf8_and_strips_only_one_initial_bom() {
	settings := blob_text_settings()
	cases := [
		fileapi.Blob.create([u8(0xFF), 0xFE, 0x61, 0], 'text/plain;charset=UTF-8'),
		fileapi.Blob.create([u8(0xFE), 0xFF, 0, 0x61], ''),
		fileapi.Blob.create([u8(0xE9)], 'text/plain;charset=windows-1252'),
		fileapi.Blob.create([u8(0xC3), 0x28], 'text/plain'),
		fileapi.Blob.create([], 'text/plain'),
		fileapi.Blob.create([u8(0xEF), 0xBB, 0xBF, 0xEF, 0xBB, 0xBF, 0x50], ''),
		fileapi.Blob.create([u8(0x50), 0xEF, 0xBB, 0xBF], ''),
		fileapi.Blob.create([u8(0x50), 0xC3], ''),
	]
	for i, blob in cases {
		promise := settings.blob_text(blob)
		assert promise.state == .pending
		finish_blob_text_task(settings)
		assert promise.state == .fulfilled
		assert promise.result.string_value == ['\ufffd\ufffda\x00', '\ufffd\ufffd\x00a', '\ufffd', '\ufffd(', '', '\ufeffP', 'P\ufeff', 'P\ufffd'][i]
	}
}

fn test_worker_blob_text_fulfillment_stays_on_its_actual_relevant_realm() {
	window_settings := blob_text_settings()
	mut window_owner := unsafe { &EventLoop(window_settings.responsible_event_loop()) }
	mut realm := &ScriptingRealm{}
	scope := WorkerGlobalScope.create(dom.URL{value: 'https://blob-text.example.test/worker.js'}, .classic, 'blob-text-worker', realm)
	settings := WorkerEnvironmentSettingsObject.setup(scope, mut realm, window_settings.serialize(), 1).settings
	blob := fileapi.Blob.create([u8(0xFF), 0xFE, 0x61, 0], '')
	promise := settings.blob_text(blob)
	assert webidl.promise_realm(promise) == u64(voidptr(settings.realm()))
	window_owner.perform_a_microtask_checkpoint()
	assert promise.state == .pending
	finish_blob_text_task(settings)
	assert promise.state == .fulfilled && promise.result.string_value == '\ufffd\ufffda\x00'
}
