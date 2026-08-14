// Copyright (c) 2024, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DataTransfer.cpp, DataTransferItem.cpp, and DataTransferItemList.cpp.
module html

const data_transfer_drop_effects = ['none', 'copy', 'link', 'move']
const data_transfer_allowed_effects = ['none', 'copy', 'copyLink', 'copyMove', 'link', 'linkMove',
	'move', 'all', 'uninitialized']

@[heap]
pub struct DataTransfer {
mut:
	drop_effect_     string = 'none'
	effect_allowed_  string = 'none'
	items_           ?&DataTransferItemList
	item_list        []&DataTransferItem
	types_           []string
	associated_store ?&DragDataStore
}

pub fn DataTransfer.create(store &DragDataStore) &DataTransfer {
	mut transfer := &DataTransfer{
		associated_store: store
	}
	for index in 0 .. store.item_list.len {
		transfer.item_list << DataTransferItem.create(transfer, usize(index))
	}
	transfer.update_data_transfer_types_list()
	return transfer
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer
pub fn DataTransfer.construct() &DataTransfer {
	mut store := DragDataStore.create()
	store.mode = .read_write
	return DataTransfer.create(store)
}

pub fn (transfer &DataTransfer) drop_effect() string {
	return transfer.drop_effect_
}

pub fn (mut transfer DataTransfer) set_drop_effect(drop_effect string) {
	if drop_effect in data_transfer_drop_effects {
		transfer.drop_effect_ = drop_effect
	}
}

pub fn (transfer &DataTransfer) effect_allowed() string {
	return transfer.effect_allowed_
}

pub fn (mut transfer DataTransfer) set_effect_allowed(effect_allowed string) {
	mode := transfer.mode() or { return }
	if mode != .read_write {
		return
	}
	transfer.set_effect_allowed_internal(effect_allowed)
}

pub fn (mut transfer DataTransfer) set_effect_allowed_internal(effect_allowed string) {
	if effect_allowed in data_transfer_allowed_effects {
		transfer.effect_allowed_ = effect_allowed
	}
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-items
pub fn (mut transfer DataTransfer) items() &DataTransferItemList {
	if items := transfer.items_ {
		return items
	}
	items := DataTransferItemList.create(&transfer)
	transfer.items_ = items
	return items
}

pub fn (transfer &DataTransfer) types() []string {
	return transfer.types_.clone()
}

fn normalize_data_transfer_format(format_argument string) string {
	format := ascii_lowercase_string(format_argument)
	return match format {
		'text' { 'text/plain' }
		'url' { 'text/uri-list' }
		else { format }
	}
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-getdata
pub fn (transfer &DataTransfer) get_data(format_argument string) string {
	store := transfer.associated_store or { return '' }
	if store.mode == .protected {
		return ''
	}
	format := normalize_data_transfer_format(format_argument)
	for item in store.item_list {
		if item.kind == .text && item.type_string == format {
			return item.data.bytestr()
		}
	}
	return ''
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-setdata
pub fn (mut transfer DataTransfer) set_data(format_argument string, value string) {
	mut store := transfer.associated_store or { return }
	if store.mode != .read_write {
		return
	}
	format := normalize_data_transfer_format(format_argument)
	for index, item in store.item_list {
		if item.kind == .text && item.type_string == format {
			transfer.remove_item(usize(index))
			break
		}
	}
	transfer.add_item(DragDataStoreItem{
		kind:        .text
		type_string: format
		data:        value.bytes()
	})
	transfer.update_data_transfer_types_list()
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-files
pub fn (transfer &DataTransfer) files() []FormDataFile {
	store := transfer.associated_store or { return []FormDataFile{} }
	if store.mode == .protected {
		return []FormDataFile{}
	}
	mut files := []FormDataFile{}
	for item in store.item_list {
		if item.kind == .file {
			files << FormDataFile{
				name:      item.file_name
				mime_type: item.type_string
				bytes:     item.data.clone()
			}
		}
	}
	return files
}

pub fn (transfer &DataTransfer) mode() ?DragDataStoreMode {
	store := transfer.associated_store or { return none }
	return store.mode
}

pub fn (mut transfer DataTransfer) disassociate_with_drag_data_store() {
	transfer.associated_store = none
	transfer.update_data_transfer_types_list()
}

pub fn (mut transfer DataTransfer) add_item(item DragDataStoreItem) &DataTransferItem {
	mut store := transfer.associated_store or { panic('DataTransfer has no associated drag data store') }
	store.add_item(item)
	data_transfer_item := DataTransferItem.create(&transfer, store.size() - 1)
	transfer.item_list << data_transfer_item
	transfer.update_data_transfer_types_list()
	return data_transfer_item
}

pub fn (mut transfer DataTransfer) remove_item(index usize) {
	mut store := transfer.associated_store or { panic('DataTransfer has no associated drag data store') }
	assert index < usize(transfer.item_list.len)
	store.remove_item_at(index)
	mut removed_item := transfer.item_list[int(index)]
	removed_item.item_index = none
	transfer.item_list.delete(int(index))
	for current_index := int(index); current_index < transfer.item_list.len; current_index++ {
		mut item := transfer.item_list[current_index]
		item.item_index = usize(current_index)
	}
	transfer.update_data_transfer_types_list()
}

pub fn (transfer &DataTransfer) contains_item_with_type(kind DragDataStoreItemKind, type_string string) bool {
	store := transfer.associated_store or { panic('DataTransfer has no associated drag data store') }
	for item in store.item_list {
		if item.kind == kind && ascii_lowercase_string(item.type_string) == ascii_lowercase_string(type_string) {
			return true
		}
	}
	return false
}

pub fn (transfer &DataTransfer) item(index usize) &DataTransferItem {
	assert index < usize(transfer.item_list.len)
	return transfer.item_list[int(index)]
}

pub fn (transfer &DataTransfer) drag_data(index usize) DragDataStoreItem {
	store := transfer.associated_store or { panic('DataTransfer has no associated drag data store') }
	assert index < usize(store.item_list.len)
	return store.item_list[int(index)]
}

pub fn (transfer &DataTransfer) length() usize {
	store := transfer.associated_store or { return 0 }
	return store.size()
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-cleardata
pub fn (mut transfer DataTransfer) clear_data(maybe_format ?string) {
	mut store := transfer.associated_store or { return }
	if store.mode != .read_write {
		return
	}
	format := if value := maybe_format { ?string(normalize_data_transfer_format(value)) } else { none }
	mut index := store.item_list.len - 1
	for index >= 0 && store.item_list.len > 0 {
		item := store.item_list[index]
		if item.kind == .text && (format == none || item.type_string == (format or { '' })) {
			transfer.remove_item(usize(index))
		}
		index--
	}
}

fn (mut transfer DataTransfer) update_data_transfer_types_list() {
	mut types := []string{}
	if store := transfer.associated_store {
		mut contains_file := false
		for item in store.item_list {
			if item.kind == .text {
				types << item.type_string
			} else {
				contains_file = true
			}
		}
		if contains_file {
			types << 'Files'
		}
	}
	transfer.types_ = types
}

pub type DataTransferStringCallback = fn (string)

@[heap]
pub struct DataTransferItem {
mut:
	data_transfer &DataTransfer @[required]
	item_index    ?usize
}

pub fn DataTransferItem.create(data_transfer &DataTransfer, item_index usize) &DataTransferItem {
	return &DataTransferItem{
		data_transfer: data_transfer
		item_index:    item_index
	}
}

pub fn (item &DataTransferItem) mode() ?DragDataStoreMode {
	if item.item_index == none {
		return none
	}
	return item.data_transfer.mode()
}

pub fn (item &DataTransferItem) kind() string {
	index := item.item_index or { return '' }
	if item.mode() == none {
		return ''
	}
	return if item.data_transfer.drag_data(index).kind == .text { 'string' } else { 'file' }
}

pub fn (item &DataTransferItem) type_() string {
	index := item.item_index or { return '' }
	if item.mode() == none {
		return ''
	}
	return item.data_transfer.drag_data(index).type_string
}

pub fn (item &DataTransferItem) get_as_string(callback ?DataTransferStringCallback) {
	callback_function := callback or { return }
	mode := item.mode() or { return }
	if mode !in [.read_write, .read_only] {
		return
	}
	index := item.item_index or { return }
	drag_data := item.data_transfer.drag_data(index)
	if drag_data.kind != .text {
		return
	}
	data := drag_data.data.bytestr()
	queue_a_task(.unspecified, none, none, fn [callback_function, data] () {
		callback_function(data)
	})
}

pub fn (item &DataTransferItem) get_as_file() ?FormDataFile {
	mode := item.mode() or { return none }
	if mode !in [.read_write, .read_only] {
		return none
	}
	index := item.item_index or { return none }
	drag_data := item.data_transfer.drag_data(index)
	if drag_data.kind != .file {
		return none
	}
	return FormDataFile{
		name:      drag_data.file_name
		mime_type: drag_data.type_string
		bytes:     drag_data.data.clone()
	}
}

@[heap]
pub struct DataTransferItemList {
mut:
	data_transfer &DataTransfer @[required]
}

pub fn DataTransferItemList.create(data_transfer &DataTransfer) &DataTransferItemList {
	return &DataTransferItemList{
		data_transfer: data_transfer
	}
}

pub fn (list &DataTransferItemList) length() usize {
	return list.data_transfer.length()
}

pub struct DataTransferItemAddResult {
pub:
	item ?&DataTransferItem
}

pub fn (mut list DataTransferItemList) add_string(data string, type_string string) !DataTransferItemAddResult {
	mode := list.data_transfer.mode() or { return DataTransferItemAddResult{} }
	if mode != .read_write {
		return DataTransferItemAddResult{}
	}
	if list.data_transfer.contains_item_with_type(.text, type_string) {
		return error('NotSupportedError: There is already a DataTransferItem with type ${type_string}')
	}
	mut transfer := unsafe { &DataTransfer(list.data_transfer) }
	return DataTransferItemAddResult{
		item: transfer.add_item(DragDataStoreItem{
		kind:        .text
		type_string: ascii_lowercase_string(type_string)
		data:        data.bytes()
		})
	}
}

pub fn (mut list DataTransferItemList) add_file(file FormDataFile) ?&DataTransferItem {
	mode := list.data_transfer.mode() or { return none }
	if mode != .read_write {
		return none
	}
	mut transfer := unsafe { &DataTransfer(list.data_transfer) }
	return transfer.add_item(DragDataStoreItem{
		kind:        .file
		type_string: ascii_lowercase_string(file.mime_type)
		data:        file.bytes.clone()
		file_name:   file.name
	})
}

pub fn (mut list DataTransferItemList) remove(index usize) ! {
	mode := list.data_transfer.mode() or {
		return error('InvalidStateError: DataTransferItemList is not in read/write mode')
	}
	if mode != .read_write {
		return error('InvalidStateError: DataTransferItemList is not in read/write mode')
	}
	if index >= list.data_transfer.length() {
		return
	}
	mut transfer := unsafe { &DataTransfer(list.data_transfer) }
	transfer.remove_item(index)
}

pub fn (mut list DataTransferItemList) clear() {
	if mode := list.data_transfer.mode() {
		if mode != .read_write {
			return
		}
		mut transfer := unsafe { &DataTransfer(list.data_transfer) }
		transfer.clear_data(none)
	}
}

pub fn (list &DataTransferItemList) item(index usize) ?&DataTransferItem {
	if index >= list.data_transfer.length() {
		return none
	}
	return list.data_transfer.item(index)
}
