// Copyright (c) 2023-2026, Shannon Booth <shannon@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// FileReader.cpp ReadOperationState and read_operation's owning Promise loop.
module fileapi

import streams
import time
import webidl

@[heap]
struct ReadOperationState {
	reader &streams.ReadableStreamDefaultReader
mut:
	process_next_chunk fn (&webidl.Promise) = unsafe { nil }
	bytes              []u8
	is_first_chunk     bool = true
	progress_timer     ?i64
}

fn file_reader_enough_progress_time_passed(timer ?i64, now i64) bool {
	if previous := timer { return now - previous >= i64(50_000_000) }
	return true
}

fn (mut reader FileReader) read_owned_operation(context FileReaderGlobalContext, blob &Blob, type_ FileReaderType, encoding_name ?string) ! {
	blobs_type := blob.type_()
	if reader.state_ == .loading {
		return webidl.throw_value(webidl.dom_exception_value_for_record(webidl.DOMException.create_record('InvalidStateError', 'Read already in progress')))
	}
	reader.state_ = .loading
	reader.is_aborted_ = false
	reader.set_result(FileReaderResult{})
	reader.error_ = none
	mut stream := unsafe { context.get_blob_stream(blob) }
	mut stream_reader := stream.get_default_reader()!
	chunk_promise := stream_reader.read().as_webidl_promise()
	mut state := &ReadOperationState{ reader: stream_reader }
	owner_handle := voidptr(&reader)
	state_handle := voidptr(state)
	state.process_next_chunk = fn [owner_handle, state_handle, context, type_, encoding_name, blobs_type] (current_chunk_promise &webidl.Promise) {
		mut promise := unsafe { &webidl.Promise(current_chunk_promise) }
		webidl.react_to_promise(mut promise, fn [owner_handle, state_handle, context, type_, encoding_name, blobs_type] (promise_value webidl.Value) !webidl.Value {
			context.run_callback_steps(fn [owner_handle, state_handle, promise_value, type_, encoding_name, blobs_type] () {
				mut actual := unsafe { &FileReader(owner_handle) }
				if actual.is_aborted_ { return }
				mut state := unsafe { &ReadOperationState(state_handle) }
				if state.is_first_chunk {
					actual.queue_a_task(fn (mut reader FileReader) {
						reader.fire_event('loadstart')
					})
				}
				state.is_first_chunk = false
				if promise_value.kind != .object {
					panic('Source VERIFY: FileReader chunk result must be an object')
				}
				// DefaultReaderReadRequest's retained typed result has ordinary
				// value/done fields. Genuine native result-object Get operations
				// remain part of the native Streams result-wrapper boundary.
				value := promise_value.object_value['value'] or { webidl.undefined_value() }
				done := promise_value.object_value['done'] or { webidl.undefined_value() }
				if done.kind != .boolean {
					panic('Source VERIFY: FileReader done must be a Boolean')
				}
				if !done.boolean_value && value.kind == .buffer_source {
					if source := value.buffer_value {
						if source.kind == .uint8_array {
							// The actual internal Blob stream emits fixed typed views.
							// Its retained ArrayLength is independent of copied
							// witness bytes after detachment/OOB. Native and auto
							// witnesses need their actual engine slots separately.
							state.bytes << webidl.get_buffer_source_copy(source)
							now := i64(time.sys_mono_now())
							enough_time_passed := file_reader_enough_progress_time_passed(state.progress_timer, now)
							contained_data := (source.fixed_array_length() or { panic('Source VERIFY: Uint8Array requires its retained length') }) > 0
							if enough_time_passed && contained_data {
								actual.queue_a_task(fn (mut reader FileReader) {
									reader.fire_event('progress')
								})
								state.progress_timer = now
							}
							mut stream_reader := state.reader
							next_chunk_promise := stream_reader.read().as_webidl_promise()
							state.process_next_chunk(next_chunk_promise)
						}
					}
				} else if done.boolean_value {
					packaged_bytes := state.bytes
					state.bytes = []
					actual.queue_a_task(fn [packaged_bytes, type_, encoding_name, blobs_type] (mut reader FileReader) {
						reader.state_ = .done
						result := blob_package_data(packaged_bytes, type_, blobs_type, encoding_name) or {
							// Source FIXME: set fr's error to the package error.
							reader.fire_event('error')
							if reader.state_ != .loading { reader.fire_event('loadend') }
							return
						}
						reader.set_result(result)
						reader.fire_event('load')
						if reader.state_ != .loading { reader.fire_event('loadend') }
					})
				}
			})
			return webidl.undefined_value()
		}, fn [owner_handle, context] (_ webidl.Value) !webidl.Value {
			context.run_callback_steps(fn [owner_handle] () {
				mut actual := unsafe { &FileReader(owner_handle) }
				if actual.is_aborted_ { return }
				actual.queue_a_task(fn (mut reader FileReader) {
					reader.state_ = .done
					// Source FIXME: set fr's error to the rejection reason.
					reader.fire_event('error')
					if reader.state_ != .loading { reader.fire_event('loadend') }
				})
			})
			return webidl.undefined_value()
		})
	}
	// Source's initial setup task belongs to the actual global queue but is
	// not affiliated in FileReader.m_pending_tasks. Abort does not remove it.
	context.queue_file_reading_task(fn [context, chunk_promise, state_handle] () {
		context.run_callback_steps(fn [chunk_promise, state_handle] () {
			state := unsafe { &ReadOperationState(state_handle) }
			state.process_next_chunk(chunk_promise)
		})
	})
}
