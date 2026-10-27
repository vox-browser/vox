// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FileAPI/FileReader.{h,cpp} and FileReaderSync.{h,cpp}.
// Actual Window/Worker readers use the owning Blob stream/default reader,
// WebIDL Promise reactions and FileReading tasks. Standalone construction
// retains its explicit process_pending_tasks() compatibility adapter.
module fileapi

import dom
import encoding
import encoding.base64
import infra
import libjs
import mimesniff
import url

pub enum FileReaderState {
	empty
	loading
	done
}

pub const file_reader_empty = u16(0)
pub const file_reader_loading = u16(1)
pub const file_reader_done = u16(2)

pub enum FileReaderType {
	array_buffer
	binary_string
	text
	data_url
}

pub enum FileReaderResultKind {
	null_
	string_
	bytes
}

pub struct FileReaderResult {
	text_utf16_ ?libjs.Utf16String
pub:
	kind  FileReaderResultKind
	text  string
	bytes []u8
}

pub fn (result FileReaderResult) clone() FileReaderResult {
	return FileReaderResult{
		text_utf16_: result.text_utf16_
		kind: result.kind
		text: result.text
		bytes: result.bytes.clone()
	}
}

// Native string projection must consume the actual immutable Source slot.
// Compatibility DTO edits cannot reuse stale raw units/storage metadata.
pub fn (result FileReaderResult) string_utf16_record() ?libjs.Utf16String {
	if result.kind != .string_ { return none }
	if raw := result.text_utf16_ {
		if raw.str() == result.text { return raw }
	}
	return none
}

fn file_reader_utf16_result(value libjs.Utf16String) FileReaderResult {
	return FileReaderResult{
		kind: .string_
		text: value.str()
		text_utf16_: value
	}
}

fn file_reader_string_result(value string) FileReaderResult {
	return FileReaderResult{
		kind: .string_
		text: value
	}
}

fn file_reader_bytes_result(value []u8) FileReaderResult {
	return FileReaderResult{
		kind: .bytes
		bytes: value.clone()
	}
}

// Source appends every byte as one UTF16 code unit. The existing owned Source
// Utf16String record supplies its UTF8 compatibility projection; this operation
// does not decode the bytes or encode Unicode itself.
fn file_reader_binary_string(bytes []u8) libjs.Utf16String {
	mut code_units := []u16{cap: bytes.len}
	for byte in bytes {
		code_units << u16(byte)
	}
	return libjs.utf16_string_from_code_units(code_units)
}

fn encoding_for_blob(mime_type ?string, encoding_name ?string) string {
	if name := encoding_name {
		if standardized := encoding.get_an_encoding(name) {
			return standardized
		}
	}
	if mime := mime_type {
		if parsed := mimesniff.MimeType.parse(mime) {
			parameters := parsed.parameters()
			if charset := parameters['charset'] {
				if standardized := encoding.get_an_encoding(charset) {
					return standardized
				}
			}
		}
	}
	return 'UTF-8'
}

// https://w3c.github.io/FileAPI/#blob-package-data
pub fn blob_package_data(bytes []u8, type_ FileReaderType, mime_type ?string, encoding_name ?string) !FileReaderResult {
	return match type_ {
		.data_url {
			mut mime := 'application/octet-stream'
			if supplied := mime_type {
				if supplied != '' {
					mime = supplied
				}
			}
			record := url.create_with_data(mime, base64.encode(bytes), true)
			file_reader_utf16_result(infra.utf16_string_record_from_url_ascii(record.serialize(false)))
		}
		.text {
			// Source Utf16String::from_utf8(String const&) delegates to the
			// actual from_utf8_without_validation owner construction.
			decoded := encoding.convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(
				encoding_for_blob(mime_type, encoding_name), bytes)!
			file_reader_utf16_result(libjs.utf16_string_from_utf8_without_validation(decoded))
		}
		.array_buffer {
			file_reader_bytes_result(bytes)
		}
		.binary_string {
			file_reader_utf16_result(file_reader_binary_string(bytes))
		}
	}
}

pub fn FileReader.blob_package_data(bytes []u8, type_ FileReaderType, mime_type ?string, encoding_name ?string) !FileReaderResult {
	return blob_package_data(bytes, type_, mime_type, encoding_name)
}

pub type FileReaderTask = fn (mut FileReader)

struct QueuedFileReaderTask {
	id   u64
	task ?FileReaderTask
}

struct PendingFileRead {
	id            u64
	bytes         []u8
	mime_type     string
	type_         FileReaderType
	encoding_name ?string
}

@[heap]
pub struct FileReader {
	dom.EventTarget
mut:
	relevant_global_object_ &dom.EventTarget = unsafe { nil }
	state_                  FileReaderState
	result_                 FileReaderResult
	error_                  ?string
	pending_read_           ?PendingFileRead
	is_aborted_             bool
	event_log_              []string
	next_read_id_           u64
	queued_tasks_           []QueuedFileReaderTask
	pending_task_ids_       []u64
	next_task_id_           u64
	global_context_         ?FileReaderGlobalContext
}

pub fn FileReader.create() &FileReader {
	mut reader := &FileReader{}
	reader.relevant_global_object_ = &reader.EventTarget
	return reader
}

pub fn FileReader.construct_impl() &FileReader {
	return FileReader.create()
}

pub fn FileReader.create_for_constructor(relevant_global_object &dom.EventTarget) &FileReader {
	return &FileReader{
		relevant_global_object_: relevant_global_object
	}
}

pub fn (reader &FileReader) relevant_global_object() &dom.EventTarget {
	if reader.relevant_global_object_ == unsafe { nil } {
		return &reader.EventTarget
	}
	return reader.relevant_global_object_
}

fn (reader &FileReader) event_target() &dom.EventTarget {
	return &reader.EventTarget
}

fn (mut reader FileReader) fire_event(name string) {
	reader.event_log_ << name
	reader.event_target().dispatch_event(reader.create_associated_event(name))
}

pub fn (reader &FileReader) ready_state() FileReaderState {
	return reader.state_
}

pub fn (reader &FileReader) result() FileReaderResult {
	return reader.result_.clone()
}

pub fn (mut reader FileReader) set_result(result FileReaderResult) {
	reader.result_ = result.clone()
}

pub fn (reader &FileReader) create_associated_event(event_name string) &dom.Event {
	mut event := dom.Event.create(event_name, dom.EventInit{})
	if context := reader.global_context_ {
		event.set_time_stamp(context.event_timestamp())
	}
	return event
}

pub fn (reader &FileReader) error() ?string {
	return reader.error_
}

pub fn FileReader.error_offset() uint {
	return uint(__offsetof(FileReader, error_))
}

pub fn (reader &FileReader) event_log() []string {
	return reader.event_log_.clone()
}

fn (mut reader FileReader) read_operation(blob &Blob, type_ FileReaderType, encoding_name ?string) ! {
	if context := reader.global_context_ {
		reader.read_owned_operation(context, blob, type_, encoding_name)!
		return
	}
	if reader.state_ == .loading {
		return error('InvalidStateError: Read already in progress')
	}
	reader.state_ = .loading
	reader.is_aborted_ = false
	reader.set_result(FileReaderResult{})
	reader.error_ = none
	reader.next_read_id_++
	reader.pending_read_ = PendingFileRead{
		id: reader.next_read_id_
		bytes: blob.raw_bytes()
		mime_type: blob.type_()
		type_: type_
		encoding_name: encoding_name
	}
}

pub fn (mut reader FileReader) read_as_array_buffer(blob &Blob) ! {
	reader.read_operation(blob, .array_buffer, none)!
}

pub fn (mut reader FileReader) read_as_binary_string(blob &Blob) ! {
	reader.read_operation(blob, .binary_string, none)!
}

pub fn (mut reader FileReader) read_as_text(blob &Blob, encoding_name ?string) ! {
	reader.read_operation(blob, .text, encoding_name)!
}

pub fn (mut reader FileReader) read_as_data_url(blob &Blob) ! {
	reader.read_operation(blob, .data_url, none)!
}

pub fn (mut reader FileReader) queue_a_task(task FileReaderTask) {
	if context := reader.global_context_ {
		reader.queue_owned_file_reading_task(context, task)
		return
	}
	reader.next_task_id_++
	reader.pending_task_ids_ << reader.next_task_id_
	reader.queued_tasks_ << QueuedFileReaderTask{
		id: reader.next_task_id_
		task: task
	}
}

pub fn (mut reader FileReader) process_queued_tasks() {
	for reader.queued_tasks_.len > 0 {
		queued := reader.queued_tasks_[0]
		reader.queued_tasks_.delete(0)
		task := queued.task or { continue }
		task(mut reader)
		reader.pending_task_ids_ = reader.pending_task_ids_.filter(it != queued.id)
	}
}

// Standalone compatibility completion; actual owner reads use Stream promises
// and the creation global's FileReading tasks instead of this byte adapter.
pub fn (mut reader FileReader) process_pending_tasks() {
	pending := reader.pending_read_ or { return }
	if reader.state_ != .loading || reader.is_aborted_ {
		reader.pending_read_ = none
		return
	}
	reader.fire_event('loadstart')
	if !reader.pending_read_is_active(pending.id) {
		return
	}
	if pending.bytes.len > 0 {
		reader.fire_event('progress')
		if !reader.pending_read_is_active(pending.id) {
			return
		}
	}
	result := blob_package_data(pending.bytes, pending.type_, pending.mime_type, pending.encoding_name) or {
		reader.state_ = .done
		reader.error_ = err.msg()
		reader.pending_read_ = none
		reader.fire_event('error')
		if reader.state_ != .loading {
			reader.fire_event('loadend')
		}
		return
	}
	reader.state_ = .done
	reader.set_result(result)
	reader.pending_read_ = none
	reader.fire_event('load')
	if reader.state_ != .loading {
		reader.fire_event('loadend')
	}
}

fn (reader &FileReader) pending_read_is_active(id u64) bool {
	if reader.state_ != .loading || reader.is_aborted_ {
		return false
	}
	pending := reader.pending_read_ or { return false }
	return pending.id == id
}

// https://w3c.github.io/FileAPI/#dfn-abort
pub fn (mut reader FileReader) abort() {
	if reader.state_ in [.empty, .done] {
		reader.set_result(FileReaderResult{})
		return
	}
	reader.state_ = .done
	reader.set_result(FileReaderResult{})
	reader.pending_read_ = none
	if context := reader.global_context_ {
		context.remove_affiliated_tasks(reader.pending_task_ids_)
	} else {
		reader.queued_tasks_.clear()
	}
	reader.pending_task_ids_.clear()
	reader.is_aborted_ = true
	reader.fire_event('abort')
	if reader.state_ != .loading {
		reader.fire_event('loadend')
	}
}

pub fn (reader &FileReader) set_onloadstart(value ?&dom.CallbackType) {
	reader.event_target().set_event_handler_attribute('loadstart', value)
}

pub fn (reader &FileReader) onloadstart() ?&dom.CallbackType {
	return reader.event_target().event_handler_attribute('loadstart')
}

pub fn (reader &FileReader) set_onprogress(value ?&dom.CallbackType) {
	reader.event_target().set_event_handler_attribute('progress', value)
}

pub fn (reader &FileReader) onprogress() ?&dom.CallbackType {
	return reader.event_target().event_handler_attribute('progress')
}

pub fn (reader &FileReader) set_onload(value ?&dom.CallbackType) {
	reader.event_target().set_event_handler_attribute('load', value)
}

pub fn (reader &FileReader) onload() ?&dom.CallbackType {
	return reader.event_target().event_handler_attribute('load')
}

pub fn (reader &FileReader) set_onabort(value ?&dom.CallbackType) {
	reader.event_target().set_event_handler_attribute('abort', value)
}

pub fn (reader &FileReader) onabort() ?&dom.CallbackType {
	return reader.event_target().event_handler_attribute('abort')
}

pub fn (reader &FileReader) set_onerror(value ?&dom.CallbackType) {
	reader.event_target().set_event_handler_attribute('error', value)
}

pub fn (reader &FileReader) onerror() ?&dom.CallbackType {
	return reader.event_target().event_handler_attribute('error')
}

pub fn (reader &FileReader) set_onloadend(value ?&dom.CallbackType) {
	reader.event_target().set_event_handler_attribute('loadend', value)
}

pub fn (reader &FileReader) onloadend() ?&dom.CallbackType {
	return reader.event_target().event_handler_attribute('loadend')
}

pub struct FileReaderSync {}

pub fn FileReaderSync.create() &FileReaderSync {
	return &FileReaderSync{}
}

pub fn FileReaderSync.construct_impl() &FileReaderSync {
	return FileReaderSync.create()
}

pub fn (reader &FileReaderSync) read_as_array_buffer(blob &Blob) ![]u8 {
	return reader.read_as_array_buffer_impl(blob)
}

pub fn (_ &FileReaderSync) read_as_array_buffer_impl(blob &Blob) ![]u8 {
	return blob.raw_bytes()
}

pub fn (reader &FileReaderSync) read_as_binary_string(blob &Blob) !string {
	return reader.read_as(blob, .binary_string, none)!.text
}

pub fn (reader &FileReaderSync) read_as_text(blob &Blob, encoding_name ?string) !string {
	return reader.read_as(blob, .text, encoding_name)!.text
}

pub fn (reader &FileReaderSync) read_as_data_url(blob &Blob) !string {
	return reader.read_as(blob, .data_url, none)!.text
}

pub fn (reader &FileReaderSync) read_as(blob &Blob, type_ FileReaderType, encoding_name ?string) !FileReaderResult {
	_ = reader
	return FileReader.blob_package_data(blob.raw_bytes(), type_, blob.type_(), encoding_name)
}
