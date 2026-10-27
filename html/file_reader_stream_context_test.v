module html

import dom
import fileapi
import os
import streams
import webidl

@[heap]
struct FileReaderStreamContextObservation {
mut:
	bytes          []u8
	settled        bool
	script_depth   uint
	callback_depth uint
}

fn file_reader_stream_context_owner() (&WindowModel, &EnvironmentSettingsObject, &EventLoop) {
	url := dom.URL{value: 'https://file-reader-stream.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	window := WindowModel.create_top_level(document, none, '') or { panic(err) }
	mut settings := window.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	return window, settings, loop
}

fn test_source_file_reader_context_retains_actual_blob_stream_default_reader_and_webidl_promise() {
	window, settings, mut loop := file_reader_stream_context_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	context := settings.file_reader_global_context_in_realm(settings.stream_realm())
	assert context.stream_realm.id == u64(voidptr(settings.realm()))
	mut reader := settings.create_file_reader_in_realm(context.stream_realm)!
	assert voidptr(reader.relevant_global_object()) == voidptr(context.global_object)
	mut stream := context.get_blob_stream(fileapi.Blob.create([u8(4), 0, 255], ''))
	mut stream_reader := stream.get_default_reader()!
	read := stream_reader.read()
	mut promise := read.as_webidl_promise()
	assert read.state() == .pending && promise.state == .pending
	assert stream_reader.read_requests().len == 1
	assert webidl.promise_realm(promise) == context.stream_realm.id
	seen := &FileReaderStreamContextObservation{}
	webidl.react_to_promise(mut promise, fn [settings, context, seen] (value webidl.Value) !webidl.Value {
		context.run_callback_steps(fn [settings, seen, value] () {
			assert voidptr(current_principal_settings_object()) == voidptr(settings)
			assert voidptr(incumbent_settings_object()) == voidptr(settings)
			assert value.kind == .object
			done := value.object_value['done'] or { panic('missing actual done field') }
			assert !done.boolean_value
			mut observation := unsafe { &FileReaderStreamContextObservation(seen) }
			chunk := value.object_value['value'] or { panic('missing actual value field') }
			buffer := chunk.buffer_value or { panic('missing actual Blob chunk') }
			observation.bytes = webidl.get_buffer_source_copy(buffer)
			observation.settled = true
			observation.script_depth = settings.realm().script_execution_depth
			observation.callback_depth = settings.realm().callback_execution_depth
		})
		return webidl.undefined_value()
	}, fn (_ webidl.Value) !webidl.Value { panic('unexpected actual Blob stream failure') })
	loop.perform_a_microtask_checkpoint()
	assert !seen.settled && promise.state == .pending
	mut queue := loop.task_queue()
	task := queue.take_first_runnable() or { panic('missing actual Blob FileReading task') }
	assert task.source() == .file_reading
	assert voidptr(task.document() or { panic('missing actual task Document') }) == voidptr(document)
	task.execute()
	loop.perform_a_microtask_checkpoint()
	assert seen.settled && seen.bytes == [u8(4), 0, 255]
	assert seen.script_depth == 2 && seen.callback_depth == 3
	assert stream_reader.read_requests().len == 0 && stream.is_closed()
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert loop.is_backup_incumbent_realm_stack_empty()
}

fn test_source_file_reader_callback_context_preserves_creation_realm_and_captured_intrinsic_hooks() {
	window, settings, mut loop := file_reader_stream_context_owner()
	mut document := window.associated_document()
	defer { document.finalize() }
	seen := &FileReaderStreamContextObservation{}
	realm := streams.StreamRealm{
		...settings.stream_realm()
		array_buffer_create: fn [seen] (bytes []u8) !webidl.Value {
			mut observation := unsafe { &FileReaderStreamContextObservation(seen) }
			observation.bytes = bytes.clone()
			return webidl.buffer_source_value(webidl.BufferSource.array_buffer(bytes))
		}
	}
	context := settings.file_reader_global_context_in_realm(realm)
	context.stream_realm.array_buffer_value([u8(8), 9])!
	assert seen.bytes == [u8(8), 9]
	context.run_callback_steps(fn [settings] () {
		assert settings.realm().script_execution_depth == 1
		assert settings.realm().callback_execution_depth == 1
		assert voidptr(incumbent_settings_object()) == voidptr(settings)
	})
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert loop.is_backup_incumbent_realm_stack_empty()
}

fn test_source_file_reader_wrong_owner_realm_preserves_fatal_verification_before_blob_work() {
	if os.getenv('VOX2_FILEREADER_REALM_MISMATCH_PROBE') == '1' {
		window, settings, loop := file_reader_stream_context_owner()
		mut document := window.associated_document()
		defer { document.finalize() }
		assert loop.task_queue().is_empty()
		settings.create_file_reader_in_realm(streams.StreamRealm.create(u64(voidptr(settings.realm())) + 1)) or {
			panic('wrong owner became author-visible error: ${err.msg()}')
		}
		panic('wrong owner passed Source verification')
	}
	mut environment := os.environ()
	environment['VOX2_FILEREADER_REALM_MISMATCH_PROBE'] = '1'
	mut process := os.new_process(os.executable())
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: FileReader relevant Realm must belong to its settings'), output
	process.close()
}
