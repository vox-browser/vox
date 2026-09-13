// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// PageClient state shared with browser chrome for editing history, document
// background, clipboard items, and primary-selection paste coordination.
module page

pub struct ClipboardItem {
pub:
	value              string
	presentation_style string
	representations    []ClipboardRepresentation
}

pub struct ClipboardRepresentation {
pub:
	mime_type string
	data      []u8
}

pub fn (mut client PageClient) page_did_insert_clipboard_representations(representations []ClipboardRepresentation, presentation_style string) {
	mut owned := []ClipboardRepresentation{cap: representations.len}
	for representation in representations {
		owned << ClipboardRepresentation{
			mime_type: representation.mime_type
			data: representation.data.clone()
		}
	}
	client.clipboard_items_ << ClipboardItem{
		presentation_style: presentation_style
		representations: owned
	}
	client.record('insert-clipboard-item', '${presentation_style}:${owned.len}')
}

pub fn (mut client PageClient) page_did_update_editing_history_state(can_undo bool, can_redo bool) {
	client.editing_history_can_undo_ = can_undo
	client.editing_history_can_redo_ = can_redo
	client.record('update-editing-history-state', '${can_undo}:${can_redo}')
}

pub fn (client &PageClient) editing_history_state() (bool, bool) {
	return client.editing_history_can_undo_, client.editing_history_can_redo_
}

pub fn (mut client PageClient) page_did_change_background_color(color string) {
	if client.background_color_ == color {
		return
	}
	client.background_color_ = color
	client.record('change-background-color', color)
}

pub fn (client &PageClient) background_color() string {
	return client.background_color_
}

pub fn (mut client PageClient) page_did_insert_clipboard_item(value string, presentation_style string) {
	client.clipboard_items_ << ClipboardItem{
		value: value
		presentation_style: presentation_style
	}
	client.record('insert-clipboard-item', '${presentation_style}:${value}')
}

pub fn (client &PageClient) clipboard_items() []ClipboardItem {
	return client.clipboard_items_.clone()
}

pub fn (mut client PageClient) page_did_request_primary_paste() {
	client.primary_paste_request_count_++
	client.record('request-primary-paste', '')
}

pub fn (mut client PageClient) page_did_complete_paste_action() {
	client.paste_action_completion_count_++
	client.record('complete-paste-action', '')
}

pub fn (client &PageClient) primary_paste_request_count() u64 {
	return client.primary_paste_request_count_
}

pub fn (client &PageClient) paste_action_completion_count() u64 {
	return client.paste_action_completion_count_
}

pub fn (mut client PageClient) page_did_update_primary_selection(value string) {
	client.primary_selection_ = value
	client.record('update-primary-selection', value)
}

pub fn (client &PageClient) primary_selection() string {
	return client.primary_selection_
}
