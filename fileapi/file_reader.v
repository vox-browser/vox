// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of FileAPI/FileReader.{h,cpp} and FileReaderSync.{h,cpp}.
// File reading task scheduling is exposed through process_pending_tasks(); this
// preserves the observable loading/abort/event state machine without hiding a
// browser event loop behind synchronous callbacks.
module fileapi

import dom
import encoding
import encoding.base64
import mimesniff

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
pub:
	kind  FileReaderResultKind
	text  string
	bytes []u8
}

pub fn (result FileReaderResult) clone() FileReaderResult {
	return FileReaderResult{
		kind:  result.kind
		text:  result.text
		bytes: result.bytes.clone()
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
		kind:  .bytes
		bytes: value.clone()
	}
}

fn decode_binary_string(bytes []u8) string {
	mut output := []u8{}
	for byte in bytes {
		if byte < 0x80 {
			output << byte
		} else if byte < 0xc0 {
			output << u8(0xc2)
			output << byte
		} else {
			output << u8(0xc3)
			output << byte - 0x40
		}
	}
	return output.bytestr()
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
			mime := mime_type or { '' }
			file_reader_string_result('data:${mime};base64,${base64.encode(bytes)}')
		}
		.text {
			decoder :=
				encoding.TextDecoder.construct(encoding_for_blob(mime_type, encoding_name), encoding.TextDecoderOptions{})!
			file_reader_string_result(decoder.decode(bytes, encoding.TextDecodeOptions{})!)
		}
		.array_buffer {
			file_reader_bytes_result(bytes)
		}
		.binary_string {
			file_reader_string_result(decode_binary_string(bytes))
		}
	}
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
	state_        FileReaderState
	result_       FileReaderResult
	error_        ?string
	pending_read_ ?PendingFileRead
	is_aborted_   bool
	event_log_    []string
	next_read_id_ u64
}

pub fn FileReader.create() &FileReader {
	return &FileReader{}
}

pub fn FileReader.construct_impl() &FileReader {
	return FileReader.create()
}

fn (reader &FileReader) event_target() &dom.EventTarget {
	return &reader.EventTarget
}

fn (mut reader FileReader) fire_event(name string) {
	reader.event_log_ << name
	reader.event_target().dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (reader &FileReader) ready_state() FileReaderState {
	return reader.state_
}

pub fn (reader &FileReader) result() FileReaderResult {
	return reader.result_.clone()
}

pub fn (reader &FileReader) error() ?string {
	return reader.error_
}

pub fn (reader &FileReader) event_log() []string {
	return reader.event_log_.clone()
}

fn (mut reader FileReader) read_operation(blob &Blob, type_ FileReaderType, encoding_name ?string) ! {
	if reader.state_ == .loading {
		return error('InvalidStateError: Read already in progress')
	}
	reader.state_ = .loading
	reader.is_aborted_ = false
	reader.result_ = FileReaderResult{}
	reader.error_ = none
	reader.next_read_id_++
	reader.pending_read_ = PendingFileRead{
		id:            reader.next_read_id_
		bytes:         blob.raw_bytes()
		mime_type:     blob.type_()
		type_:         type_
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

// Runs the queued file-reading work at the explicit HTML event-loop boundary.
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
	result := blob_package_data(pending.bytes, pending.type_, pending.mime_type,
		pending.encoding_name) or {
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
	reader.result_ = result
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
		reader.result_ = FileReaderResult{}
		return
	}
	reader.state_ = .done
	reader.result_ = FileReaderResult{}
	reader.pending_read_ = none
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
	_ = reader
	return blob_package_data(blob.raw_bytes(), .array_buffer, blob.type_(), none)!.bytes
}

pub fn (reader &FileReaderSync) read_as_binary_string(blob &Blob) !string {
	_ = reader
	return blob_package_data(blob.raw_bytes(), .binary_string, blob.type_(), none)!.text
}

pub fn (reader &FileReaderSync) read_as_text(blob &Blob, encoding_name ?string) !string {
	_ = reader
	return blob_package_data(blob.raw_bytes(), .text, blob.type_(), encoding_name)!.text
}

pub fn (reader &FileReaderSync) read_as_data_url(blob &Blob) !string {
	_ = reader
	return blob_package_data(blob.raw_bytes(), .data_url, blob.type_(), none)!.text
}
