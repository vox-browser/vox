// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/DragDataStore.cpp.
module html

pub enum DragDataStoreItemKind {
	text
	file
}

pub struct DragDataStoreItem {
pub:
	kind        DragDataStoreItemKind = .text
	type_string string
	data        []u8
	file_name   string
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

pub fn (mut store DragDataStore) add_item(item DragDataStoreItem) {
	store.item_list << item
}

pub fn (mut store DragDataStore) remove_item_at(index usize) {
	store.item_list.delete(int(index))
}

pub fn (store &DragDataStore) size() usize {
	return usize(store.item_list.len)
}

pub fn (store &DragDataStore) has_text_item() bool {
	for item in store.item_list {
		if item.kind == .text && item.type_string == 'text/plain' {
			return true
		}
	}
	return false
}
