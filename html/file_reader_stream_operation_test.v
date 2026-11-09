module html

import dom
import fileapi
import streams
import webidl

fn file_reader_read_owner() (&WindowModel, &EnvironmentSettingsObject, &EventLoop) {
	url := dom.URL{ value: 'https://file-reader-read.example.test/' }
	document := &dom.Document{ url: url, origin_: url.origin() }
	window := WindowModel.create_top_level(document, none, '') or { panic(err) }
	mut settings := window.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	return window, settings, loop
}

fn drive_source_file_reader(mut loop EventLoop, reader &fileapi.FileReader) {
	was_paused := loop.execution_paused
	loop.execution_paused = false
	defer { loop.execution_paused = was_paused }
	for _ in 0 .. 64 {
		if reader.ready_state() == .done && loop.task_queue().is_empty() { break }
		loop.process()
	}
	assert reader.ready_state() == .done
	assert loop.task_queue().is_empty()
}

fn test_source_read_operation_uses_pending_blob_and_setup_tasks_then_affiliated_event_tasks() {
	window, settings, mut loop := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	mut reader := settings.create_file_reader()!
	mut blob := fileapi.Blob.create([u8(0xff), 0xfe, 0x41, 0], 'text/plain;charset=windows-1252')
	reader.read_as_text(blob, none)!
	assert reader.ready_state() == .loading && reader.result().kind == .null_
	assert reader.event_log().len == 0 && loop.task_queue().tasks.len == 2
	for task in loop.task_queue().tasks {
		assert task.source() == .file_reading
		assert voidptr(task.document() or { panic('missing real owning Document') }) == voidptr(document)
	}
	if _ := reader.read_as_array_buffer(blob) {
		assert false
	} else {
		assert err is webidl.ValueException
		if err is webidl.ValueException {
			assert err.value.dom_exception_?.name() == 'InvalidStateError'
			assert err.value.dom_exception_?.message() == 'Read already in progress'
		}
	}
	// Source captures the Blob type and queues its byte copy before returning.
	blob.deserialization_steps_utf16(fileapi.Blob.create([], '').type_utf16(), 'later'.bytes())
	loop.process()
	assert reader.ready_state() == .loading && reader.event_log().len == 0
	assert loop.task_queue().tasks.len == 1
	loop.process()
	assert reader.ready_state() == .loading && reader.event_log().len == 0
	assert loop.task_queue().tasks.len == 3
	reader.process_pending_tasks()
	assert reader.ready_state() == .loading && reader.event_log().len == 0
	drive_source_file_reader(mut loop, reader)
	assert reader.result().text == 'A' && reader.error() == none
	assert reader.event_log() == ['loadstart', 'progress', 'load', 'loadend']
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert loop.is_backup_incumbent_realm_stack_empty()
}

fn test_source_read_operation_packages_each_type_and_empty_blob_without_progress() {
	window, settings, mut loop := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	for type_ in [fileapi.FileReaderType.array_buffer, .binary_string, .text, .data_url] {
		mut reader := settings.create_file_reader()!
		blob := fileapi.Blob.create([u8(65), 0], 'text/plain')
		match type_ {
			.array_buffer { reader.read_as_array_buffer(blob)! }
			.binary_string { reader.read_as_binary_string(blob)! }
			.text { reader.read_as_text(blob, 'UTF-8')! }
			.data_url { reader.read_as_data_url(blob)! }
		}
		drive_source_file_reader(mut loop, reader)
		if type_ == .array_buffer {
			assert reader.result().kind == .bytes && reader.result().bytes == [u8(65), 0]
		} else if type_ == .data_url {
			assert reader.result().text == 'data:text/plain;base64,QQA='
		} else {
			assert reader.result().text.bytes() == [u8(65), 0]
		}
		assert reader.event_log() == ['loadstart', 'progress', 'load', 'loadend']
	}
	mut empty := settings.create_file_reader()!
	empty.read_as_array_buffer(fileapi.Blob.create([], ''))!
	drive_source_file_reader(mut loop, empty)
	assert empty.result().kind == .bytes && empty.result().bytes.len == 0
	assert empty.event_log() == ['loadstart', 'load', 'loadend']
}

fn test_source_abort_keeps_untracked_blob_and_setup_tasks_and_removes_affiliated_events() {
	window, settings, mut loop := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	mut before_setup := settings.create_file_reader()!
	before_setup.read_as_text(fileapi.Blob.create('before'.bytes(), ''), none)!
	assert loop.task_queue().tasks.len == 2
	before_setup.abort()
	assert loop.task_queue().tasks.len == 2
	drive_source_file_reader(mut loop, before_setup)
	assert before_setup.result().kind == .null_
	assert before_setup.event_log() == ['abort', 'loadend']
	mut after_setup := settings.create_file_reader()!
	after_setup.read_as_text(fileapi.Blob.create('after'.bytes(), ''), none)!
	loop.process()
	loop.process()
	assert loop.task_queue().tasks.len == 3
	after_setup.abort()
	assert loop.task_queue().is_empty()
	assert after_setup.result().kind == .null_
	assert after_setup.event_log() == ['abort', 'loadend']
}

fn test_source_load_handler_reentrant_read_suppresses_only_the_old_loadend() {
	window, settings, mut loop := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	mut reader := settings.create_file_reader()!
	owner_handle := voidptr(reader)
	reader.set_onload(&dom.CallbackType{
		handle_event: fn [owner_handle] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut reader := unsafe { &fileapi.FileReader(owner_handle) }
			assert reader.ready_state() == .done && reader.result().text == 'first'
			reader.set_onload(none)
			reader.read_as_text(fileapi.Blob.create('second'.bytes(), ''), none) or { panic(err) }
			assert reader.ready_state() == .loading && reader.result().kind == .null_
			return dom.js_undefined()
		}
	})
	reader.read_as_text(fileapi.Blob.create('first'.bytes(), ''), none)!
	drive_source_file_reader(mut loop, reader)
	assert reader.result().text == 'second'
	assert reader.event_log() == ['loadstart', 'progress', 'load', 'loadstart', 'progress', 'load',
		'loadend']
}

fn test_source_read_rejection_preserves_error_setter_fixme_and_owning_callback_cleanup() {
	window, settings, mut loop := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	reason := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('AbortError', 'actual stream reason'))
	base := settings.file_reader_global_context_in_realm(settings.stream_realm())
	context := fileapi.FileReaderGlobalContext{
		...base
		get_blob_stream: fn [settings, reason] (blob &fileapi.Blob) &streams.ReadableStream {
			mut stream := settings.get_blob_stream(blob)
			stream.error_value(reason)
			return stream
		}
	}
	mut reader := fileapi.FileReader.create_in_global_context(context)
	reader.read_as_text(fileapi.Blob.create([u8(1)], ''), none)!
	drive_source_file_reader(mut loop, reader)
	assert reader.ready_state() == .done && reader.result().kind == .null_
	assert reader.error() == none
	assert reader.event_log() == ['error', 'loadend']
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert loop.is_backup_incumbent_realm_stack_empty()
}

fn test_source_abort_handler_new_read_before_setup_discards_the_previous_operation() {
	window, settings, mut loop := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	mut reader := settings.create_file_reader()!
	owner_handle := voidptr(reader)
	reader.set_onabort(&dom.CallbackType{
		handle_event: fn [owner_handle] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut reader := unsafe { &fileapi.FileReader(owner_handle) }
			reader.read_as_text(fileapi.Blob.create('second'.bytes(), ''), none) or { panic(err) }
			return dom.js_undefined()
		}
	})
	reader.read_as_text(fileapi.Blob.create('first'.bytes(), ''), none)!
	reader.abort()
	assert reader.ready_state() == .loading && reader.event_log() == ['abort']
	// Both initial tasks remain untracked. Their callbacks must distinguish
	// operations after the reentrant read resets the shared abort Boolean.
	assert loop.task_queue().tasks.len == 4
	drive_source_file_reader(mut loop, reader)
	assert reader.result().text == 'second'
	assert reader.event_log() == ['abort', 'loadstart', 'progress', 'load', 'loadend']
}

fn test_source_worker_read_operation_uses_actual_worker_realm_loop_and_null_document() {
	window, _, _ := file_reader_read_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{ value: 'https://file-reader-read.example.test/worker.js' },
		.classic, '', realm)
	settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm,
		window.environment_settings_.settings.serialize(), 12).settings
	mut loop := worker.event_loop
	mut reader := settings.create_file_reader()!
	reader.read_as_binary_string(fileapi.Blob.create([u8(0), 255], ''))!
	assert loop.task_queue().tasks.len == 2
	for task in loop.task_queue().tasks {
		assert task.document() == none
	}
	drive_source_file_reader(mut loop, reader)
	assert reader.result().text.bytes() == [u8(0), 0xc3, 0xbf]
	assert reader.event_log() == ['loadstart', 'progress', 'load', 'loadend']
	assert voidptr(reader.relevant_global_object()) == voidptr(settings.global_object())
	assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
}
