module fileapi

import dom

fn record_queued_file_reader_task(mut reader FileReader) {
	reader.event_log_ << 'queued-task'
}

struct FileReaderCallbackState {
mut:
	call_count int
	event_type string
}

fn test_blob_package_data_all_read_types() {
	bytes := [u8(`H`), `i`]
	assert blob_package_data(bytes, .array_buffer, 'text/plain', none)!.bytes == bytes
	assert blob_package_data([u8(0x41), 0xff], .binary_string, none, none)!.text == 'Aÿ'
	assert blob_package_data(bytes, .text, 'text/plain;charset=utf-8', none)!.text == 'Hi'
	assert blob_package_data(bytes, .data_url, 'text/plain', none)!.text == 'data:text/plain;base64,SGk='
	assert blob_package_data(bytes, .data_url, none, none)!.text == 'data:application/octet-stream;base64,SGk='
}

fn test_blob_package_data_encoding_precedence_and_bom() {
	// Explicit encoding wins over the MIME charset.
	utf16 := [u8(0xff), 0xfe, 0x41, 0x00]
	result := blob_package_data(utf16, .text, 'text/plain;charset=windows-1252', 'utf-16le')!
	assert result.text == 'A'
	// Unknown explicit labels fall through to the MIME charset.
	windows := blob_package_data([u8(0x80)], .text, 'text/plain;charset=windows-1252', 'unknown-label')!
	assert windows.text == '€'
}

fn test_file_reader_queues_and_completes_a_read() {
	blob := Blob.create('hello'.bytes(), 'text/plain')
	mut reader := FileReader.construct_impl()
	assert reader.ready_state() == .empty
	reader.read_as_text(blob, none)!
	assert reader.ready_state() == .loading
	assert reader.result().kind == .null_
	if _ := reader.read_as_array_buffer(blob) {
		assert false, 'a second read while loading must fail'
	}
	reader.process_pending_tasks()
	assert reader.ready_state() == .done
	assert reader.result().kind == .string_
	assert reader.result().text == 'hello'
	assert reader.error() == none
	assert reader.event_log() == ['loadstart', 'progress', 'load', 'loadend']
}

fn test_file_reader_abort_cancels_pending_work() {
	blob := Blob.create('hello'.bytes(), '')
	mut reader := FileReader.create()
	reader.read_as_data_url(blob)!
	reader.abort()
	assert reader.ready_state() == .done
	assert reader.result().kind == .null_
	assert reader.event_log() == ['abort', 'loadend']
	reader.process_pending_tasks()
	assert reader.event_log() == ['abort', 'loadend']
	// Aborting an idle/done reader clears the result without firing events.
	reader.abort()
	assert reader.event_log() == ['abort', 'loadend']
}

fn test_file_reader_empty_blob_has_no_progress_event() {
	blob := Blob.construct(none, none)
	mut reader := FileReader.create()
	reader.read_as_array_buffer(blob)!
	reader.process_pending_tasks()
	assert reader.result().bytes.len == 0
	assert reader.event_log() == ['loadstart', 'load', 'loadend']
}

fn test_file_reader_sync_accessors() {
	blob := Blob.create('hello'.bytes(), 'text/plain')
	reader := FileReaderSync.construct_impl()
	assert reader.read_as_array_buffer(blob)! == 'hello'.bytes()
	assert reader.read_as_binary_string(Blob.create([u8(0xff)], ''))! == 'ÿ'
	assert reader.read_as_text(blob, none)! == 'hello'
	assert reader.read_as_data_url(blob)! == 'data:text/plain;base64,aGVsbG8='
}

fn test_file_reader_exact_package_queue_and_sync_read_entry_points() {
	packaged := FileReader.blob_package_data('abc'.bytes(), .binary_string, none, none)!
	assert packaged.text == 'abc'

	mut reader := FileReader.construct_impl()
	reader.queue_a_task(record_queued_file_reader_task)
	assert 'queued-task' !in reader.event_log()
	reader.process_queued_tasks()
	assert reader.event_log() == ['queued-task']

	blob := Blob.create('sync'.bytes(), 'text/plain')
	sync_reader := FileReaderSync.construct_impl()
	result := sync_reader.read_as(blob, .text, 'UTF-8')!
	assert result.text == 'sync'
	assert sync_reader.read_as_array_buffer_impl(blob)! == 'sync'.bytes()
}

fn test_file_reader_constructor_global_result_event_and_offset_boundaries() {
	global := &dom.EventTarget{}
	mut reader := FileReader.create_for_constructor(global)
	assert reader.relevant_global_object() == global
	reader.set_result(file_reader_string_result('set-result'))
	assert reader.result().text == 'set-result'
	event := reader.create_associated_event('load')
	assert event.type_name() == 'load'
	assert event.time_stamp() > 0
	assert FileReader.error_offset() > 0
}

fn test_file_reader_events_use_the_inherited_event_target() {
	state := &FileReaderCallbackState{}
	callback := &dom.CallbackType{
		handle_event: fn [state] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			_ := current_target or { panic('missing current target') }
			unsafe {
				mut mutable_state := &FileReaderCallbackState(state)
				mutable_state.call_count++
				mutable_state.event_type = event.type_name()
			}
			return dom.js_undefined()
		}
	}
	blob := Blob.create('event'.bytes(), 'text/plain')
	mut reader := FileReader.create()
	reader.set_onload(callback)
	assert reader.onload() or { panic('missing load handler') } == callback
	reader.read_as_text(blob, none)!
	reader.process_pending_tasks()
	assert state.call_count == 1
	assert state.event_type == 'load'
	reader.set_onload(none)
	assert reader.onload() == none
}

fn test_file_reader_loadstart_abort_stops_the_old_read() {
	blob := Blob.create('old'.bytes(), 'text/plain')
	mut reader := FileReader.create()
	reader_pointer := reader
	callback := &dom.CallbackType{
		handle_event: fn [reader_pointer] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			unsafe {
				mut mutable_reader := &FileReader(reader_pointer)
				mutable_reader.abort()
			}
			return dom.js_undefined()
		}
	}
	reader.set_onloadstart(callback)
	reader.read_as_text(blob, none)!
	reader.process_pending_tasks()
	assert reader.ready_state() == .done
	assert reader.result().kind == .null_
	assert reader.event_log() == ['loadstart', 'abort', 'loadend']
}

fn test_file_reader_progress_abort_stops_the_old_read() {
	blob := Blob.create('old'.bytes(), 'text/plain')
	mut reader := FileReader.create()
	reader_pointer := reader
	callback := &dom.CallbackType{
		handle_event: fn [reader_pointer] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			unsafe {
				mut mutable_reader := &FileReader(reader_pointer)
				mutable_reader.abort()
			}
			return dom.js_undefined()
		}
	}
	reader.set_onprogress(callback)
	reader.read_as_text(blob, none)!
	reader.process_pending_tasks()
	assert reader.ready_state() == .done
	assert reader.result().kind == .null_
	assert reader.event_log() == ['loadstart', 'progress', 'abort', 'loadend']
}
