// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Clipboard actions and editing input-event ranges from EventHandler.cpp.
module page

import dom
import encoding.base64
import infra

pub enum ClipboardDataItemKind {
	text
	file
}

pub struct ClipboardDataItem {
pub:
	kind      ClipboardDataItemKind
	mime_type string
	data      []u8
	file_name string
}

pub struct ClipboardDataStore {
pub mut:
	mode  DragDataStoreMode = .protected_
	items []ClipboardDataItem
}

pub fn input_type_for_delete_key(key int) ?string {
	if key == 8 {
		return 'deleteContentBackward'
	}
	if key == 46 {
		return 'deleteContentForward'
	}
	return none
}

pub fn clipboard_event_target(document &dom.Document) ?&dom.Node {
	if selection := document.get_selection() {
		if range := selection.range() {
			start_container := range.start_container()
			if start_container.is_editable_or_editing_host() {
				return start_container
			}
		}
	}
	if focused_area := document.focused_area() {
		return focused_area
	}
	if body := document.body() {
		return unsafe { &dom.Node(body) }
	}
	if document_element := document.document_element() {
		return document_element.as_node()
	}
	return none
}

pub fn (mut handler EventHandler) set_page_client(client ?&PageClient) {
	handler.client_ = client
}

pub fn (mut handler EventHandler) set_selected_clipboard_content(text string, html string) {
	handler.selected_text_ = text
	handler.selected_html_ = html
}

pub fn (mut handler EventHandler) set_clipboard_event_cancelled(event_name string, cancelled bool) {
	handler.clipboard_event_cancellations_[event_name] = cancelled
}

pub fn (mut handler EventHandler) set_clipboard_event_items(event_name string, items []ClipboardDataItem) {
	handler.clipboard_event_items_[event_name] = items.clone()
}

pub fn (mut handler EventHandler) set_system_clipboard_items(items []ClipboardDataItem) {
	handler.system_clipboard_items_ = items.clone()
}

pub fn (handler &EventHandler) pasted_content() (string, ?string) {
	return handler.pasted_text_, handler.pasted_html_
}

pub fn fire_clipboard_event(mut handler EventHandler, event_name string, mut data_store ClipboardDataStore) bool {
	handler.log(event_name, handler.focused_target())
	if injected := handler.clipboard_event_items_[event_name] {
		if data_store.mode == .read_write {
			data_store.items = injected.clone()
		}
	}
	return !(handler.clipboard_event_cancellations_[event_name] or { false })
}

fn clipboard_mime_essence(value string) string {
	return value.split(';')[0].trim_space().to_lower()
}

pub fn write_data_transfer_to_clipboard(mut client PageClient, data_store ClipboardDataStore) {
	mut representations := []ClipboardRepresentation{}
	for item in data_store.items {
		if item.kind != .text {
			continue
		}
		mime_type := clipboard_mime_essence(item.mime_type)
		if mime_type !in ['text/plain', 'text/html'] {
			continue
		}
		representations << ClipboardRepresentation{
			mime_type: mime_type
			data: item.data.clone()
		}
	}
	if representations.len > 0 {
		client.page_did_insert_clipboard_representations(representations, 'unspecified')
	}
}

fn selected_clipboard_data_store(handler &EventHandler) ClipboardDataStore {
	mut items := []ClipboardDataItem{}
	if handler.selected_html_ != '' {
		items << ClipboardDataItem{
			kind: .text
			mime_type: 'text/html'
			data: handler.selected_html_.bytes()
		}
	}
	if handler.selected_text_ != '' {
		items << ClipboardDataItem{
			kind: .text
			mime_type: 'text/plain'
			data: handler.selected_text_.bytes()
		}
	}
	return ClipboardDataStore{
		mode: .protected_
		items: items
	}
}

fn write_store_with_handler_client(mut handler EventHandler, store ClipboardDataStore) {
	if mut client := handler.client_ {
		write_data_transfer_to_clipboard(mut client, store)
	}
}

pub fn (mut handler EventHandler) perform_copy_action() EventResult {
	if !handler.active_document {
		return .dropped
	}
	mut event_store := ClipboardDataStore{ mode: .read_write }
	event_was_not_cancelled := fire_clipboard_event(mut handler, 'copy', mut event_store)
	event_store.mode = .protected_
	if event_was_not_cancelled {
		write_store_with_handler_client(mut handler, selected_clipboard_data_store(handler))
	} else {
		write_store_with_handler_client(mut handler, event_store)
	}
	return .handled
}

pub fn (mut handler EventHandler) perform_cut_action() EventResult {
	if !handler.active_document {
		return .dropped
	}
	mut event_store := ClipboardDataStore{ mode: .read_write }
	event_was_not_cancelled := fire_clipboard_event(mut handler, 'cut', mut event_store)
	event_store.mode = .protected_
	if event_was_not_cancelled {
		target := handler.focused_target()
		if focused := target {
			if focused.is_editable && (handler.selected_text_ != '' || handler.selected_html_ != '') {
				write_store_with_handler_client(mut handler, selected_clipboard_data_store(handler))
				handler.log('beforeinput:deleteByCut', focused)
				handler.selected_text_ = ''
				handler.selected_html_ = ''
			}
		}
	} else {
		write_store_with_handler_client(mut handler, event_store)
	}
	return .handled
}

pub fn system_clipboard_data_store(system_items []ClipboardDataItem) ClipboardDataStore {
	mut items := []ClipboardDataItem{}
	for item in system_items {
		mime_type := clipboard_mime_essence(item.mime_type)
		if item.kind == .text {
			if mime_type in ['text/plain', 'text/html'] {
				items << ClipboardDataItem{
					...item
					mime_type: mime_type
					data: item.data.clone()
				}
			} else if mime_type == 'image/png' {
				items << ClipboardDataItem{
					kind: .file
					mime_type: mime_type
					data: item.data.clone()
					file_name: 'image.png'
				}
			}
		} else {
			items << ClipboardDataItem{
				...item
				mime_type: mime_type
				data: item.data.clone()
			}
		}
	}
	return ClipboardDataStore{ items: items }
}

pub fn (mut handler EventHandler) perform_paste_action() EventResult {
	if !handler.active_document {
		return .dropped
	}
	mut store := system_clipboard_data_store(handler.system_clipboard_items_)
	return handler.perform_paste_action_with_data_store(mut store)
}

pub fn (mut handler EventHandler) perform_paste_action_with_data_store(mut data_store ClipboardDataStore) EventResult {
	if !handler.active_document {
		return .dropped
	}
	data_store.mode = .read_only
	event_was_not_cancelled := fire_clipboard_event(mut handler, 'paste', mut data_store)
	data_store.mode = .protected_
	mut result := EventResult.handled
	if event_was_not_cancelled {
		mut html := ?string(none)
		mut plain_text := ''
		for item in data_store.items {
			mime_type := clipboard_mime_essence(item.mime_type)
			if mime_type == 'text/html' {
				html = item.data.bytestr()
			} else if mime_type == 'text/plain' {
				plain_text = item.data.bytestr()
			} else if item.kind == .file && mime_type.starts_with('image/') {
				encoded := base64.encode(item.data)
				html = '<img src="data:${mime_type};base64,' + encoded + '" />'
			}
		}
		if html != none || plain_text != '' {
			result = handler.insert_pasted_content(plain_text, html)
		}
	}
	if mut client := handler.client_ {
		client.page_did_complete_paste_action()
	}
	return result
}

pub fn (mut handler EventHandler) insert_pasted_content(plain_text string, html ?string) EventResult {
	if !handler.active_document {
		return .dropped
	}
	target := handler.focused_target() or { return .dropped }
	if !target.is_editable {
		return .dropped
	}
	normalized_text := infra.normalize_newlines(plain_text)
	beforeinput_result := handler.input_event('beforeinput', 'insertFromPaste',
		InputEventData(normalized_text))
	if beforeinput_result == .cancelled {
		return .cancelled
	}
	handler.pasted_text_ = normalized_text
	handler.pasted_html_ = html
	insert_result := handler.insert_clipboard_content(normalized_text, html)
	if insert_result != .handled {
		return insert_result
	}
	handler.log('input:insertFromPaste', target)
	return .handled
}

pub fn collapsed_delete_target_range_for_input_event(text string, offset int, input_type string) ?SelectionRange {
	segmenter := &dom.Segmenter{
		segmented_text: text
		granularity: .grapheme
	}
	if input_type == 'deleteContentBackward' && offset > 0 {
		return SelectionRange{
			start: segmenter.previous_boundary(offset) or { offset - 1 }
			end: offset
		}
	}
	text_length := segmenter.boundaries().last()
	if input_type == 'deleteContentForward' && offset < text_length {
		return SelectionRange{
			start: offset
			end: segmenter.next_boundary(offset) or { offset + 1 }
		}
	}
	return none
}

pub fn (mut handler EventHandler) fire_text_input_event(data string) EventResult {
	if !handler.active_document {
		return .dropped
	}
	target := handler.focused_target()
	handler.event_log << InputDispatch{
		name: 'textInput'
		target: if focused := target { focused.id } else { '' }
		data: data
	}
	if focused := target {
		if focused.cancel_keyboard {
			return .cancelled
		}
	}
	return .accepted
}
