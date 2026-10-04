module html

import dom
import fileapi
import streams
import webidl

@[heap]
struct BlobTaskObservations {
mut:
	bytes     []u8
	completed bool
}

fn blob_task_owner() (&WindowModel, &EnvironmentSettingsObject, &EventLoop) {
	url := dom.URL{'https://blob-tasks.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	window := WindowModel.create_top_level(document, none, 'blob-task-owner') or { panic(err) }
	mut settings := window.environment_settings_.settings
	owner := EventLoop.create(.window)
	settings.responsible_event_loop_ = owner
	return window, settings, owner
}

fn execute_blob_task(settings &EnvironmentSettingsObject) {
	mut queue := settings.responsible_event_loop().task_queue()
	task := queue.take_first_runnable() or { panic('missing Source FileReading task') }
	assert task.source() == .file_reading
	assert task.document() == settings.responsible_document()
	task.execute()
}

fn test_blob_stream_keeps_the_actual_pending_reader_until_its_owner_file_task() {
	_, settings, mut owner := blob_task_owner()
	mut original_bytes := [u8(4), 5, 6]
	blob := fileapi.Blob.create(original_bytes, 'application/octet-stream')
	mut stream := settings.get_blob_stream(blob)
	assert stream.realm().id == u64(voidptr(settings.realm()))
	mut reader := stream.get_default_reader()!
	mut seen := &BlobTaskObservations{}
	reader.read_all_bytes_with_steps(fn [settings, mut seen] (bytes []u8) {
		assert settings.realm().script_execution_depth == 1
		assert settings.realm().callback_execution_depth == 1
		assert voidptr(current_principal_settings_object()) == voidptr(settings)
		assert voidptr(incumbent_settings_object()) == voidptr(settings)
		seen.bytes = bytes
		seen.completed = true
	}, fn (_ webidl.Value) { panic('unexpected Source Blob read failure') })
	original_bytes[0] = 99
	owner.perform_a_microtask_checkpoint()
	assert !seen.completed && reader.read_requests().len == 1
	execute_blob_task(settings)
	assert seen.completed && seen.bytes == [u8(4), 5, 6]
	assert stream.is_closed() && reader.read_requests().len == 0
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
	assert owner.is_backup_incumbent_realm_stack_empty()
}

fn test_empty_blob_task_enqueues_its_empty_chunk_before_closing_and_settles_the_source_promise() {
	_, settings, mut owner := blob_task_owner()
	blob := fileapi.Blob.create([], '')
	mut stream := settings.get_blob_stream(blob)
	mut reader := stream.get_default_reader()!
	first := reader.read()
	assert first.state() == .pending
	execute_blob_task(settings)
	assert first.state() == .fulfilled && !first.result().done
	assert first.result().value.kind == .bytes && first.result().value.bytes_.len == 0
	assert reader.read().result().done
	promise := settings.read_all_blob_bytes(blob)
	assert promise.state == .pending
	assert webidl.promise_realm(promise) == u64(voidptr(settings.realm()))
	owner.perform_a_microtask_checkpoint()
	assert promise.state == .pending
	execute_blob_task(settings)
	assert promise.state == .fulfilled
	assert promise.result.buffer_value?.kind == .array_buffer
	assert webidl.get_buffer_source_copy(promise.result.buffer_value?).len == 0
}

fn test_worker_blob_reading_tasks_and_promises_use_the_actual_worker_owner_loop() {
	window, window_settings, mut window_loop := blob_task_owner()
	mut realm := &ScriptingRealm{}
	scope := WorkerGlobalScope.create(dom.URL{'https://blob-tasks.example.test/worker.js'}, .classic, 'blob-worker', realm)
	settings := WorkerEnvironmentSettingsObject.setup(scope, mut realm, window.environment_settings_.settings.serialize(), 12).settings
	mut worker_loop := unsafe { &EventLoop(settings.responsible_event_loop()) }
	assert voidptr(worker_loop) != voidptr(window_loop)
	assert settings.responsible_document() == none
	blob := fileapi.Blob.create([u8(8), 9], '')
	mut promise := settings.read_all_blob_bytes(blob)
	assert promise.state == .pending
	mut seen := &BlobTaskObservations{}
	child := promise.upon_fulfillment(fn [settings, mut seen] (value webidl.Value) !webidl.Value {
		assert settings.realm().script_execution_depth == 1
		// Source closes the Blob task's script context before its callback
		// context. That checkpoint nests the Promise callback inside the
		// still-retained outer FileReading callback.
		assert settings.realm().callback_execution_depth == 2
		assert voidptr(incumbent_settings_object()) == voidptr(settings)
		buffer := value.buffer_value or { panic('missing Source read-all ArrayBuffer') }
		seen.bytes = webidl.get_buffer_source_copy(buffer)
		seen.completed = true
		return value
	})
	assert webidl.promise_realm(child) == u64(voidptr(settings.realm()))
	window_loop.perform_a_microtask_checkpoint()
	assert promise.state == .pending && !seen.completed
	assert window_settings.responsible_event_loop().task_queue().is_empty()
	execute_blob_task(settings)
	worker_loop.perform_a_microtask_checkpoint()
	assert promise.state == .fulfilled && child.state == .fulfilled
	assert seen.completed && seen.bytes == [u8(8), 9]
	assert settings.realm().script_execution_depth == 0
	assert settings.realm().callback_execution_depth == 0
}

fn test_queued_blob_task_preserves_closed_and_errored_stream_gates_and_original_reason() {
	_, settings, _ := blob_task_owner()
	blob := fileapi.Blob.create([u8(1)], '')
	mut closed := settings.get_blob_stream(blob)
	mut closed_reader := closed.get_default_reader()!
	closed_result := closed_reader.read_all_bytes_deprecated()
	closed_reader.cancel(streams.string_value('cancel before the FileReading task'))
	assert closed_result.state == .fulfilled
	execute_blob_task(settings)
	assert closed.is_closed()
	assert webidl.get_buffer_source_copy(closed_result.result.buffer_value?).len == 0
	mut errored := settings.get_blob_stream(blob)
	mut error_reader := errored.get_default_reader()!
	error_result := error_reader.read_all_bytes_deprecated()
	reason := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('AbortError', 'original failure'))
	errored.error_value(reason)
	assert error_result.state == .rejected && error_result.result.opaque_id == reason.opaque_id
	execute_blob_task(settings)
	assert errored.is_errored() && errored.stored_error_value().opaque_id == reason.opaque_id
}

fn test_blob_exception_boundary_retains_thrown_values_and_source_builtin_descriptors() {
	reason := webidl.object_value_with_id({}, 816)
	assert blob_operation_exception_value(webidl.throw_value(reason)).opaque_id == reason.opaque_id
	value := blob_operation_exception_value(error('TypeError: source built-in failure'))
	assert value.simple_exception_?.type_ == .type_error
	assert value.simple_exception_?.message == 'source built-in failure'
}
