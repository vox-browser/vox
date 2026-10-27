// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/DragDataStore.cpp.
module html

import libjs

pub enum DragDataStoreItemKind {
	text
	file
}

pub struct DragDataStoreItem {
	// DragDataStore.h owns UTF-16 type/text/name slots separately from file bytes.
	// Retain the existing string/byte views for translated compatibility callers.
	type_utf16_      ?libjs.Utf16String
	text_data_utf16_ ?libjs.Utf16String
	file_name_utf16_ ?libjs.Utf16String
pub:
	kind        DragDataStoreItemKind = .text
	type_string string
	data        []u8
	file_name   string
}

pub fn DragDataStoreItem.text_utf16(type_string libjs.Utf16String, data libjs.Utf16String) DragDataStoreItem {
	return DragDataStoreItem{
		kind:             .text
		type_string:      type_string.str()
		data:             data.str().bytes()
		type_utf16_:      type_string
		text_data_utf16_: data
	}
}

pub fn DragDataStoreItem.file_utf16(type_string libjs.Utf16String, file_data []u8, file_name libjs.Utf16String) DragDataStoreItem {
	return DragDataStoreItem{
		kind:             .file
		type_string:      type_string.str()
		data:             file_data.clone()
		file_name:        file_name.str()
		type_utf16_:      type_string
		file_name_utf16_: file_name
	}
}

pub fn (item DragDataStoreItem) type_utf16() libjs.Utf16String {
	if text := item.type_utf16_ {
		if text.str() == item.type_string {
			return text
		}
	}
	return libjs.utf16_string_from_utf8_without_validation(item.type_string)
}

pub fn (item DragDataStoreItem) text_data_utf16() libjs.Utf16String {
	if item.kind == .text {
		if text := item.text_data_utf16_ {
			if text.str().bytes() == item.data {
				return text
			}
		}
		return libjs.utf16_string_from_utf8_without_validation(item.data.bytestr())
	}
	return libjs.Utf16String{}
}

pub fn (item DragDataStoreItem) file_name_utf16() libjs.Utf16String {
	if text := item.file_name_utf16_ {
		if text.str() == item.file_name {
			return text
		}
	}
	return libjs.utf16_string_from_utf8_without_validation(item.file_name)
}

pub enum DragDataStoreMode {
	read_write
	read_only
	protected
}

@[heap]
pub struct DragDataStore {
pub mut:
	item_list             []DragDataStoreItem
	mode                  DragDataStoreMode = .protected
	allowed_effects_state string            = 'uninitialized'
}

pub fn DragDataStore.create() &DragDataStore {
	return &DragDataStore{}
}

pub fn (store &DragDataStore) item_list() []DragDataStoreItem {
	return store.item_list.clone()
}

pub fn (store &DragDataStore) mode() DragDataStoreMode {
	return store.mode
}

pub fn (mut store DragDataStore) set_mode(value DragDataStoreMode) {
	store.mode = value
}

pub fn (store &DragDataStore) allowed_effects_state() string {
	return store.allowed_effects_state
}

pub fn (mut store DragDataStore) set_allowed_effects_state(value string) {
	store.allowed_effects_state = value
}

pub fn (mut store DragDataStore) add_item(item DragDataStoreItem) {
	store.item_list << item
}

pub fn (mut store DragDataStore) remove_item_at(index uint) {
	store.item_list.delete(int(index))
}

pub fn (store &DragDataStore) size() uint {
	return uint(store.item_list.len)
}

pub fn (store &DragDataStore) has_text_item() bool {
	for item in store.item_list {
		if item.kind == .text && item.type_string == 'text/plain' {
			return true
		}
	}
	return false
}
