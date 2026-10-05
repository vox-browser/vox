module html

import dom
import fileapi
import highresolutiontime

@[heap]
struct FileReaderOwnerObservation {
mut:
	steps      []string
	task_ids   []u64
	timestamps []f64
}

fn file_reader_owner_window() &WindowModel {
	url := dom.URL{value: 'https://file-reader-owner.example.test/creation.html'}
	document := &dom.Document{
		url:              url
		origin_:          url.origin()
		load_timing_info: dom.DocumentLoadTimingInfo{
			navigation_start_time: highresolutiontime.unsafe_shared_current_time()
		}
	}
	return WindowModel.create_top_level(document, none, '') or { panic(err) }
}

fn drive_file_reader_owner_steps(mut loop EventLoop, observation &FileReaderOwnerObservation, count int) {
	was_paused := loop.execution_paused
	loop.execution_paused = false
	defer { loop.execution_paused = was_paused }
	for _ in 0 .. 32 {
		if observation.steps.len >= count { break }
		loop.process()
	}
	assert observation.steps.len == count
}

fn test_source_file_reader_tasks_use_creation_global_loop_and_queue_time_document() {
	mut window := file_reader_owner_window()
	mut creation_document := window.associated_document()
	defer { creation_document.finalize() }
	settings := window.environment_settings_.settings
	mut loop := settings.responsible_event_loop()
	was_paused := loop.execution_paused
	loop.execution_paused = true
	defer { loop.execution_paused = was_paused }
	mut reader := settings.create_file_reader()!
	assert voidptr(reader.relevant_global_object()) == voidptr(settings.global_object())
	observation := &FileReaderOwnerObservation{}
	reader.queue_a_task(fn [settings, observation, creation_document] (mut _ fileapi.FileReader) {
		task := settings.responsible_event_loop().currently_running_task() or {
			panic('missing actual FileReader FileReading task')
		}
		assert task.source() == .file_reading
		assert voidptr(task.document() or { panic('missing queued document') }) == voidptr(creation_document)
		mut seen := unsafe { &FileReaderOwnerObservation(observation) }
		seen.steps << 'creation document'
		seen.task_ids << task.id()
	})
	first_task := loop.task_queue().last_added_task() or { panic('missing first task') }
	assert first_task.source() == .file_reading
	url := dom.URL{value: 'https://file-reader-owner.example.test/later.html'}
	mut later_document := &dom.Document{ url: url, origin_: url.origin() }
	defer { later_document.finalize() }
	// The actual creation Window/Realm stays fixed. Its current associated
	// Document is read when each task is queued, not at reader construction.
	window.Window.set_associated_document(later_document)
	reader.queue_a_task(fn [settings, observation, later_document] (mut _ fileapi.FileReader) {
		task := settings.responsible_event_loop().currently_running_task() or {
			panic('missing actual FileReader task for later document')
		}
		assert task.source() == .file_reading
		assert voidptr(task.document() or { panic('missing later document') }) == voidptr(later_document)
		mut seen := unsafe { &FileReaderOwnerObservation(observation) }
		seen.steps << 'later document'
		seen.task_ids << task.id()
	})
	second_task := loop.task_queue().last_added_task() or { panic('missing second task') }
	assert second_task.id() != first_task.id()
	assert voidptr(second_task.document() or { panic('missing second queued document') }) == voidptr(later_document)
	assert observation.steps.len == 0
	// Restore the creation Window's actual active document. The second task
	// keeps the inactive document it captured at queue time and stays queued.
	window.Window.set_associated_document(creation_document)
	drive_file_reader_owner_steps(mut loop, observation, 1)
	assert observation.steps == ['creation document']
	assert observation.task_ids == [first_task.id()]
	assert loop.task_queue().tasks.any(it.id() == second_task.id())
	reader.read_as_text(fileapi.Blob.create([], ''), none)!
	reader.abort()
	assert !loop.task_queue().tasks.any(it.id() == second_task.id())
	assert voidptr(reader.relevant_global_object()) == voidptr(settings.global_object())
}

fn test_source_file_reader_abort_removes_only_affiliated_task_ids_and_reentrant_work() {
	window := file_reader_owner_window()
	mut document := window.associated_document()
	defer { document.finalize() }
	settings := window.environment_settings_.settings
	mut loop := settings.responsible_event_loop()
	was_paused := loop.execution_paused
	loop.execution_paused = true
	defer { loop.execution_paused = was_paused }
	mut reader := settings.create_file_reader()!
	mut other := settings.create_file_reader()!
	observation := &FileReaderOwnerObservation{}
	// The Source read starts its own Blob/setup tasks. The manually queued
	// callbacks below still retain their actual affiliated task ownership.
	reader.read_as_text(fileapi.Blob.create('pending'.bytes(), ''), none)!
	reader.queue_a_task(fn [observation] (mut actual fileapi.FileReader) {
		mut seen := unsafe { &FileReaderOwnerObservation(observation) }
		seen.steps << 'first callback'
		actual.queue_a_task(fn [observation] (mut _ fileapi.FileReader) {
			mut seen := unsafe { &FileReaderOwnerObservation(observation) }
			seen.steps << 'removed reentrant callback'
		})
		actual.abort()
	})
	other.queue_a_task(fn [observation] (mut _ fileapi.FileReader) {
		mut seen := unsafe { &FileReaderOwnerObservation(observation) }
		seen.steps << 'other reader'
	})
	drive_file_reader_owner_steps(mut loop, observation, 2)
	assert observation.steps == ['first callback', 'other reader']
	assert reader.event_log() == ['abort', 'loadend']
	assert reader.ready_state() == .done && reader.result().kind == .null_
	for _ in 0 .. 3 { loop.process() }
	assert observation.steps.len == 2
}

fn test_source_worker_file_reader_uses_actual_worker_loop_null_document_and_global_clock() {
	window := file_reader_owner_window()
	mut document := window.associated_document()
	defer { document.finalize() }
	mut realm := &ScriptingRealm{}
	worker := WorkerGlobalScope.create(dom.URL{value: 'https://file-reader-owner.example.test/worker.js'},
		.classic, '', realm)
	settings := WorkerEnvironmentSettingsObject.setup(worker, mut realm,
		window.environment_settings_.settings.serialize(), highresolutiontime.unsafe_shared_current_time()).settings
	mut loop := worker.event_loop
	assert voidptr(loop) != voidptr(main_thread_event_loop())
	was_paused := loop.execution_paused
	loop.execution_paused = true
	defer { loop.execution_paused = was_paused }
	mut reader := settings.create_file_reader()!
	assert voidptr(reader.relevant_global_object()) == voidptr(settings.global_object())
	observation := &FileReaderOwnerObservation{}
	before := settings.global_relative_event_timestamp()
	reader.queue_a_task(fn [settings, observation] (mut actual fileapi.FileReader) {
		task := settings.responsible_event_loop().currently_running_task() or { panic('missing Worker FileReading task') }
		assert task.source() == .file_reading && task.document() == none
		event := actual.create_associated_event('load')
		assert event.is_trusted() && !event.bubbles() && !event.cancelable() && !event.composed()
		mut seen := unsafe { &FileReaderOwnerObservation(observation) }
		seen.steps << 'worker task'
		seen.timestamps << event.time_stamp()
	})
	drive_file_reader_owner_steps(mut loop, observation, 1)
	assert observation.timestamps[0] >= before
	assert observation.timestamps[0] <= settings.global_relative_event_timestamp()
	assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
}

fn test_source_file_reader_abort_event_reentrant_task_survives_old_wrapper_cleanup() {
	window := file_reader_owner_window()
	mut document := window.associated_document()
	defer { document.finalize() }
	settings := window.environment_settings_.settings
	mut loop := settings.responsible_event_loop()
	was_paused := loop.execution_paused
	loop.execution_paused = true
	defer { loop.execution_paused = was_paused }
	mut reader := settings.create_file_reader()!
	owner_handle := voidptr(reader)
	observation := &FileReaderOwnerObservation{}
	before := settings.global_relative_event_timestamp()
	reader.set_onabort(&dom.CallbackType{
		handle_event: fn [owner_handle, settings, observation] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mut actual := unsafe { &fileapi.FileReader(owner_handle) }
			assert voidptr(current or { panic('missing FileReader receiver') }) == owner_handle
			assert event.type_name() == 'abort' && event.is_trusted()
			assert event.time_stamp() <= settings.global_relative_event_timestamp()
			actual.read_as_text(fileapi.Blob.create('next'.bytes(), ''), none) or { panic(err) }
			actual.queue_a_task(fn [observation] (mut _ fileapi.FileReader) {
				mut seen := unsafe { &FileReaderOwnerObservation(observation) }
				seen.steps << 'fresh owned task'
			})
			task := settings.responsible_event_loop().task_queue().last_added_task() or { panic('missing reentrant FileReading task') }
			mut seen := unsafe { &FileReaderOwnerObservation(observation) }
			seen.steps << 'abort callback'
			seen.timestamps << event.time_stamp()
			seen.task_ids << task.id()
			return dom.js_undefined()
		}
	})
	reader.read_as_text(fileapi.Blob.create('first'.bytes(), ''), none)!
	reader.queue_a_task(fn (mut actual fileapi.FileReader) {
		actual.abort()
	})
	drive_file_reader_owner_steps(mut loop, observation, 1)
	assert observation.steps == ['abort callback']
	assert observation.timestamps[0] >= before
	assert reader.ready_state() == .loading && reader.event_log() == ['abort']
	assert loop.task_queue().tasks.any(it.id() == observation.task_ids[0])
	// The old executing wrapper must remove only its own ID. The abort
	// listener's new read/task remains affiliated and a later abort removes it.
	reader.set_onabort(none)
	reader.abort()
	assert !loop.task_queue().tasks.any(it.id() == observation.task_ids[0])
	assert reader.event_log() == ['abort', 'abort', 'loadend']
	assert observation.steps == ['abort callback']
}
