// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Clipboard/Clipboard.{h,cpp,idl}.
module clipboard

import dom
import fileapi
import html
import mimesniff

pub fn clipboard_item_data_blob(value ClipboardItemData) ?&fileapi.Blob {
	if value.kind != .blob {
		return none
	}
	return value.blob
}

pub struct ClipboardUnsanitizedFormats {
pub:
	unsanitized ?[]string
}

@[heap]
pub struct ClipboardReadPromise {
mut:
	state_  ClipboardPromiseState
	items_  []&ClipboardItem
	reason_ string
}

pub fn ClipboardReadPromise.pending() &ClipboardReadPromise {
	return &ClipboardReadPromise{}
}

pub fn (promise &ClipboardReadPromise) state() ClipboardPromiseState {
	return promise.state_
}

pub fn (promise &ClipboardReadPromise) items() []&ClipboardItem {
	return promise.items_.clone()
}

pub fn (promise &ClipboardReadPromise) reason() string {
	return promise.reason_
}

fn (mut promise ClipboardReadPromise) resolve(items []&ClipboardItem) {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
		promise.items_ = items.clone()
	}
}

pub fn resolve_clipboard_items_promise(mut promise ClipboardReadPromise, items []&ClipboardItem) {
	promise.resolve(items)
}

fn (mut promise ClipboardReadPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

@[heap]
pub struct ClipboardTextPromise {
mut:
	state_  ClipboardPromiseState
	text_   string
	reason_ string
}

pub fn ClipboardTextPromise.pending() &ClipboardTextPromise {
	return &ClipboardTextPromise{}
}

pub fn (promise &ClipboardTextPromise) state() ClipboardPromiseState {
	return promise.state_
}

pub fn (promise &ClipboardTextPromise) text() string {
	return promise.text_
}

pub fn (promise &ClipboardTextPromise) reason() string {
	return promise.reason_
}

fn (mut promise ClipboardTextPromise) resolve(text string) {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
		promise.text_ = text
	}
}

fn (mut promise ClipboardTextPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

@[heap]
pub struct ClipboardVoidPromise {
mut:
	state_  ClipboardPromiseState
	reason_ string
}

pub fn ClipboardVoidPromise.pending() &ClipboardVoidPromise {
	return &ClipboardVoidPromise{}
}

pub fn (promise &ClipboardVoidPromise) state() ClipboardPromiseState {
	return promise.state_
}

pub fn (promise &ClipboardVoidPromise) reason() string {
	return promise.reason_
}

fn (mut promise ClipboardVoidPromise) resolve() {
	if promise.state_ == .pending {
		promise.state_ = .fulfilled
	}
}

fn (mut promise ClipboardVoidPromise) reject(reason string) {
	if promise.state_ == .pending {
		promise.state_ = .rejected
		promise.reason_ = reason
	}
}

// https://w3c.github.io/clipboard-apis/#os-specific-well-known-format
pub fn os_specific_well_known_format(mime_type_string string) string {
	mime_type := mimesniff.MimeType.parse(mime_type_string) or { return '' }
	essence := mime_type.essence()
	return if essence == 'text/plain' || essence == 'text/html' || essence == 'image/png' {
		essence
	} else {
		''
	}
}

pub enum ClipboardReadPermission {
	denied
	granted
	granted_for_own_origin_data
}

pub fn check_clipboard_read_permission(has_transient_activation bool, is_running_from_paste bool, has_focus bool) ClipboardReadPermission {
	// https://w3c.github.io/clipboard-apis/#privacy-async
	if !has_focus || !has_transient_activation { return .denied }
	return if is_running_from_paste { .granted } else { .granted_for_own_origin_data }
}

pub fn check_clipboard_write_permission(has_transient_activation bool) bool {
	return has_transient_activation
}

// The browser-process insertion call is represented by the returned native
// item and presentation style. The caller batches those records into the
// injectable SystemClipboardBackend after all representation promises settle.
// https://w3c.github.io/clipboard-apis/#write-blobs-and-option-to-the-clipboard
pub struct ClipboardNativeWrite {
pub:
	item               SystemClipboardItem
	presentation_style string
}

pub fn write_blobs_and_option_to_clipboard(items []&fileapi.Blob, presentation_style string) ClipboardNativeWrite {
	mut representations := []SystemClipboardRepresentation{cap: items.len}
	for item in items {
		format_string := os_specific_well_known_format(item.type_())
		representations << SystemClipboardRepresentation{
			data: item.raw_bytes().clone()
			mime_type: format_string
		}
	}
	return ClipboardNativeWrite{
		item: SystemClipboardItem{
			system_clipboard_representations: representations
		}
		presentation_style: presentation_style
	}
}

@[heap]
pub struct Clipboard {
	dom.EventTarget
mut:
	backend_                 &SystemClipboardBackend = unsafe { nil }
	event_loop_              &html.EventLoop = unsafe { nil }
	document_                ?&dom.Document
	has_transient_activation bool
	system_clipboard_data_being_pasted_ ?[]SystemClipboardItem
	active_write_operations  []&ClipboardWriteOperation
}

// create wires the API to its per-tab clipboard boundary and native document.
// Standalone adapters without a Window can supply activation explicitly; an
// associated native Window always remains the activation authority.
pub fn Clipboard.create(backend &SystemClipboardBackend, event_loop &html.EventLoop, document ?&dom.Document) &Clipboard {
	return &Clipboard{
		backend_: backend
		event_loop_: event_loop
		document_: document
	}
}

pub fn Clipboard.construct_impl() !&Clipboard {
	return Clipboard.create(SystemClipboardBackend.create(), html.main_thread_event_loop(), none)
}

pub fn (board &Clipboard) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(board) }
}

pub fn (mut board Clipboard) set_has_transient_activation(value bool) {
	board.has_transient_activation = value
}

fn (board &Clipboard) has_transient_user_activation() bool {
	if document := board.document_ {
		if window := document.get_window() {
			return window.has_transient_activation()
		}
	}
	return board.has_transient_activation
}

// The embedder calls this only while dispatching a paste of the system
// clipboard authorized by its own Paste command or shortcut. A synthetic
// paste event or a handed-over text insertion must not enter this scope.
// Reads capture their own copy before the asynchronous permission task runs.
pub fn (mut board Clipboard) during_system_clipboard_paste(data []SystemClipboardItem, steps fn()) {
	previous := board.system_clipboard_data_being_pasted_
	board.system_clipboard_data_being_pasted_ = clone_system_clipboard_items(data)
	defer { board.system_clipboard_data_being_pasted_ = previous }
	steps()
}

fn (board &Clipboard) pasted_data_snapshot() ?[]SystemClipboardItem {
	data := board.system_clipboard_data_being_pasted_ or { return none }
	return clone_system_clipboard_items(data)
}

fn (board &Clipboard) data_allowed_by_read_permission(pasted_data ?[]SystemClipboardItem) ![]SystemClipboardItem {
	has_focus := if document := board.document_ { document.has_focus() } else { false }
	permission := check_clipboard_read_permission(board.has_transient_user_activation(), pasted_data != none, has_focus)
	if permission == .granted {
		return pasted_data or { []SystemClipboardItem{} }
	}
	if permission == .granted_for_own_origin_data {
		if document := board.document_ {
			data := board.backend_.items_written_by(document)
			if data.len > 0 { return data }
		}
	}
	return error('NotAllowedError: Clipboard reading is only allowed while the user pastes')
}

fn (board &Clipboard) write_backend_items(items []SystemClipboardItem, presentation_styles []string) {
	mut backend := board.backend_
	if document := board.document_ {
		backend.replace_items_written_by(items, presentation_styles, document)
	} else {
		backend.replace_items(items, presentation_styles)
	}
}

pub fn (board &Clipboard) backend() &SystemClipboardBackend {
	return board.backend_
}

// https://w3c.github.io/clipboard-apis/#dom-clipboard-read
pub fn (board &Clipboard) read(formats ClipboardUnsanitizedFormats) &ClipboardReadPromise {
	mut promise := ClipboardReadPromise.pending()
	pasted_data := board.pasted_data_snapshot()
	html.queue_a_task(.permissions, board.event_loop_, board.document_, fn [board, mut promise, formats, pasted_data] () {
		data := board.data_allowed_by_read_permission(pasted_data) or {
			promise.reject(err.msg())
			return
		}
		html.queue_a_task(.clipboard, board.event_loop_, board.document_, fn [board, mut promise, formats, data] () {
			mut items := []&ClipboardItem{}
			snapshot_change_count := board.backend_.change_count()
			for system_item in data {
				mut item := ClipboardItem.create_empty()
				for system_representation in system_item.system_clipboard_representations {
					// File-backed native entries are available to an explicit user paste,
					// but are never exposed through navigator.clipboard.
					if system_representation.is_file_backed() {
						continue
					}
					mime_type := os_specific_well_known_format(system_representation.mime_type)
					if mime_type.len == 0 {
						continue
					}
					// The sanitization hook remains a specification FIXME upstream. Still
					// inspect the request so this translation retains that control point.
					mut is_unsanitized := mime_type == 'image/png'
					if requested := formats.unsanitized {
						is_unsanitized = is_unsanitized || mime_type in requested
					}
					_ = is_unsanitized
					item.append_representation(ClipboardItemRepresentation{
						mime_type: mime_type
						data: ClipboardItemDataPromise.pending()
					})
				}
				if item.representations().len > 0 {
					item.set_clipboard_change_count_at_read(snapshot_change_count)
					item.set_originating_system_clipboard_item(system_item)
					if unsanitized := formats.unsanitized {
						item.set_unsanitized_mime_types(unsanitized)
					}
					items << item
				}
			}
			resolve_clipboard_items_promise(mut promise, items)
		})
	})
	return promise
}

// https://w3c.github.io/clipboard-apis/#dom-clipboard-readtext
pub fn (board &Clipboard) read_text() &ClipboardTextPromise {
	mut promise := ClipboardTextPromise.pending()
	pasted_data := board.pasted_data_snapshot()
	html.queue_a_task(.permissions, board.event_loop_, board.document_, fn [board, mut promise, pasted_data] () {
		data := board.data_allowed_by_read_permission(pasted_data) or {
			promise.reject(err.msg())
			return
		}
		html.queue_a_task(.clipboard, board.event_loop_, board.document_, fn [mut promise, data] () {
			for item in data {
				for representation in item.system_clipboard_representations {
					data := representation.byte_data() or { continue }
					if os_specific_well_known_format(representation.mime_type) == 'text/plain' {
						promise.resolve(data.bytestr())
						return
					}
				}
			}
			promise.reject('NotFoundError: Did not find a text item in the system clipboard')
		})
	})
	return promise
}

// https://w3c.github.io/clipboard-apis/#dom-clipboard-write
pub fn (board &Clipboard) write(data []&ClipboardItem) &ClipboardVoidPromise {
	mut promise := ClipboardVoidPromise.pending()
	html.queue_a_task(.permissions, board.event_loop_, board.document_, fn [board, data, mut promise] () {
		if !check_clipboard_write_permission(board.has_transient_user_activation()) {
			promise.reject('NotAllowedError: Clipboard writing is only allowed through user activation')
			return
		}
		mut operation := &ClipboardWriteOperation{
			clipboard: board
			data: data.clone()
			promise: promise
		}
		mut mutable_clipboard := unsafe { &Clipboard(board) }
		mutable_clipboard.active_write_operations << operation
		operation.schedule()
	})
	return promise
}

// https://w3c.github.io/clipboard-apis/#dom-clipboard-writetext
pub fn (board &Clipboard) write_text(data string) &ClipboardVoidPromise {
	mut promise := ClipboardVoidPromise.pending()
	html.queue_a_task(.permissions, board.event_loop_, board.document_, fn [board, data, mut promise] () {
		if !check_clipboard_write_permission(board.has_transient_user_activation()) {
			promise.reject('NotAllowedError: Clipboard writing is only allowed through user activation')
			return
		}
		html.queue_a_task(.clipboard, board.event_loop_, board.document_, fn [board, data, mut promise] () {
			board.write_backend_items([
				SystemClipboardItem{
					system_clipboard_representations: [
						SystemClipboardRepresentation{
							data: data.bytes()
							mime_type: os_specific_well_known_format('text/plain;charset=utf-8')
						},
					]
				},
			], ['unspecified'])
			promise.resolve()
		})
	})
	return promise
}

@[heap]
struct ClipboardWriteOperation {
	clipboard &Clipboard = unsafe { nil }
	data      []&ClipboardItem
	promise   &ClipboardVoidPromise = unsafe { nil }
mut:
	scheduled bool
	completed bool
}

fn (mut operation ClipboardWriteOperation) schedule() {
	if operation.completed || operation.scheduled {
		return
	}
	operation.scheduled = true
	html.queue_a_task(.clipboard, operation.clipboard.event_loop_, operation.clipboard.document_, fn [mut operation] () {
		operation.scheduled = false
		operation.process()
	})
}

fn (mut operation ClipboardWriteOperation) process() {
	if operation.completed {
		return
	}
	mut has_pending_data := false
	for item in operation.data {
		for representation in item.representations() {
			match representation.data.state() {
				.rejected {
					operation.fail('NotAllowedError: Writing to the clipboard failed: ${representation.data.reason()}')
					return
				}
				.pending {
					has_pending_data = true
					representation.data.react(fn [mut operation] (_ ClipboardItemData) {
						operation.schedule()
					}, fn [mut operation] (_ string) {
						operation.schedule()
					})
				}
				.fulfilled {}
			}
		}
	}
	if has_pending_data {
		return
	}

	mut system_items := []SystemClipboardItem{cap: operation.data.len}
	mut presentation_styles := []string{cap: operation.data.len}
	for item in operation.data {
		mut clean_item_list := []&fileapi.Blob{}
		for representation in item.representations() {
			value := representation.data.result() or {
				operation.fail('NotAllowedError: Clipboard representation has no data')
				return
			}
			blob := match value.kind {
				.string_ {
					fileapi.Blob.create(value.text.bytes(), representation.mime_type)
				}
				.blob {
					clipboard_item_data_blob(value) or {
						operation.fail('NotAllowedError: Clipboard Blob value is missing')
						return
					}
				}
			}
			if !ClipboardItem.supports(blob.type_()) {
				operation.fail('NotAllowedError: Clipboard item type ${blob.type_()} is not allowed')
				return
			}
			if os_specific_well_known_format(blob.type_()).len == 0 {
				operation.fail('NotAllowedError: Clipboard item type ${blob.type_()} has no native format')
				return
			}
			clean_item_list << blob
		}
		native_write := write_blobs_and_option_to_clipboard(clean_item_list, presentation_style_to_string(item.presentation_style()))
		system_items << native_write.item
		presentation_styles << native_write.presentation_style
	}
	operation.clipboard.write_backend_items(system_items, presentation_styles)
	mut promise := operation.promise
	promise.resolve()
	operation.complete()
}

fn (mut operation ClipboardWriteOperation) fail(reason string) {
	mut promise := operation.promise
	promise.reject(reason)
	operation.complete()
}

fn (mut operation ClipboardWriteOperation) complete() {
	if operation.completed {
		return
	}
	operation.completed = true
	mut board := unsafe { &Clipboard(operation.clipboard) }
	for index, candidate in board.active_write_operations {
		if candidate == &operation {
			board.active_write_operations.delete(index)
			break
		}
	}
}
