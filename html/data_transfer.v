// Copyright (c) 2024, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DataTransfer.cpp, DataTransferItem.cpp, and DataTransferItemList.cpp.
module html

import entriesapi
import fileapi
import libjs

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
	types_utf16_     []libjs.Utf16String
	types_revision_  u64
	associated_store ?&DragDataStore
	live_file_list_ ?&fileapi.FileList
	live_files_ map[voidptr]DataTransferLiveFile
}

pub fn DataTransfer.create(store &DragDataStore) &DataTransfer {
	mut transfer := &DataTransfer{
		associated_store: store
	}
	for index in 0 .. store.item_list.len {
		transfer.item_list << DataTransferItem.create(transfer, uint(index))
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

pub fn DataTransfer.construct_impl() &DataTransfer {
	return DataTransfer.construct()
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

pub fn (transfer &DataTransfer) types_utf16() []libjs.Utf16String {
	return transfer.types_utf16_.clone()
}

pub fn (transfer &DataTransfer) types_revision() u64 {
	return transfer.types_revision_
}

// DataTransfer.cpp normalizes its legacy aliases without lowercasing the
// stored spelling of other formats. Lookup and clearing ignore ASCII case.
fn normalize_data_transfer_format_utf16(format_argument libjs.Utf16String) libjs.Utf16String {
	return match format_argument.to_ascii_lowercase().str() {
		'text' { libjs.utf16_string('text/plain') }
		'url' { libjs.utf16_string('text/uri-list') }
		else { format_argument }
	}
}

fn data_transfer_format_equals_ignoring_ascii_case(left libjs.Utf16String, right libjs.Utf16String) bool {
	return left.to_ascii_lowercase().code_units() == right.to_ascii_lowercase().code_units()
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-getdata
pub fn (transfer &DataTransfer) get_data(format_argument string) string {
	return transfer.get_data_utf16(libjs.utf16_string_from_utf8_without_validation(format_argument)).str()
}

pub fn (transfer &DataTransfer) get_data_utf16(format_argument libjs.Utf16String) libjs.Utf16String {
	store := transfer.associated_store or { return libjs.Utf16String{} }
	if store.mode == .protected {
		return libjs.Utf16String{}
	}
	format := normalize_data_transfer_format_utf16(format_argument)
	for item in store.item_list {
		if item.kind == .text
			&& data_transfer_format_equals_ignoring_ascii_case(item.type_utf16(), format) {
			// The source still leaves URL-list parsing as a FIXME.
			return item.text_data_utf16()
		}
	}
	return libjs.Utf16String{}
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-setdata
pub fn (mut transfer DataTransfer) set_data(format_argument string, value string) {
	transfer.set_data_utf16(libjs.utf16_string_from_utf8_without_validation(format_argument),
		libjs.utf16_string_from_utf8_without_validation(value))
}

pub fn (mut transfer DataTransfer) set_data_utf16(format_argument libjs.Utf16String, value libjs.Utf16String) {
	mut store := transfer.associated_store or { return }
	if store.mode != .read_write {
		return
	}
	format := normalize_data_transfer_format_utf16(format_argument)
	for index, item in store.item_list {
		if item.kind == .text && item.type_utf16().code_units() == format.code_units() {
			transfer.remove_item(uint(index))
			break
		}
	}
	transfer.add_item(DragDataStoreItem.text_utf16(format, value))
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
	mut store := transfer.associated_store or {
		panic('DataTransfer has no associated drag data store')
	}

	store.add_item(item)
	data_transfer_item := DataTransferItem.create(&transfer, store.size() - 1)
	transfer.item_list << data_transfer_item
	transfer.update_data_transfer_types_list()
	return data_transfer_item
}

pub fn (mut transfer DataTransfer) remove_item(index uint) {
	mut store := transfer.associated_store or {
		panic('DataTransfer has no associated drag data store')
	}

	assert index < uint(transfer.item_list.len)
	store.remove_item_at(index)
	mut removed_item := transfer.item_list[int(index)]
	removed_item.item_index = none
	transfer.item_list.delete(int(index))
	for current_index := int(index); current_index < transfer.item_list.len; current_index++ {
		mut item := transfer.item_list[current_index]
		item.item_index = uint(current_index)
	}
	transfer.update_data_transfer_types_list()
}

pub fn (transfer &DataTransfer) contains_item_with_type(kind DragDataStoreItemKind, type_string string) bool {
	store := transfer.associated_store or {
		panic('DataTransfer has no associated drag data store')
	}

	for item in store.item_list {
		if item.kind == kind
			&& ascii_lowercase_string(item.type_string) == ascii_lowercase_string(type_string) {
			return true
		}
	}
	return false
}

pub fn (transfer &DataTransfer) item(index uint) &DataTransferItem {
	assert index < uint(transfer.item_list.len)
	return transfer.item_list[int(index)]
}

pub fn (transfer &DataTransfer) drag_data(index uint) DragDataStoreItem {
	store := transfer.associated_store or {
		panic('DataTransfer has no associated drag data store')
	}

	assert index < uint(store.item_list.len)
	return store.item_list[int(index)]
}

pub fn (transfer &DataTransfer) length() uint {
	store := transfer.associated_store or { return 0 }
	return store.size()
}

// https://html.spec.whatwg.org/multipage/dnd.html#dom-datatransfer-cleardata
pub fn (mut transfer DataTransfer) clear_data(maybe_format ?string) {
	format := if value := maybe_format {
		?libjs.Utf16String(libjs.utf16_string_from_utf8_without_validation(value))
	} else {
		none
	}
	transfer.clear_data_utf16(format)
}

pub fn (mut transfer DataTransfer) clear_data_utf16(maybe_format ?libjs.Utf16String) {
	mut store := transfer.associated_store or { return }
	if store.mode != .read_write {
		return
	}
	format := if value := maybe_format {
		?libjs.Utf16String(normalize_data_transfer_format_utf16(value))
	} else {
		none
	}
	mut index := store.item_list.len - 1
	for index >= 0 && store.item_list.len > 0 {
		item := store.item_list[index]
		matches := if value := format {
			data_transfer_format_equals_ignoring_ascii_case(item.type_utf16(), value)
		} else {
			true
		}
		if item.kind == .text && matches {
			transfer.remove_item(uint(index))
		}
		index--
	}
}

fn (mut transfer DataTransfer) update_data_transfer_types_list() {
	mut types := []string{}
	mut types_utf16 := []libjs.Utf16String{}
	if store := transfer.associated_store {
		mut contains_file := false
		for item in store.item_list {
			if item.kind == .text {
				types << item.type_string
				types_utf16 << item.type_utf16()
			} else {
				contains_file = true
			}
		}
		if contains_file {
			types << 'Files'
			types_utf16 << libjs.utf16_string('Files')
		}
	}
	transfer.types_ = types
	transfer.types_utf16_ = types_utf16
	transfer.types_revision_++
}

pub type DataTransferStringCallback = fn (string)

@[heap]
pub struct DataTransferItem {
mut:
	data_transfer &DataTransfer @[required]
	item_index    ?uint
}

pub fn DataTransferItem.create(data_transfer &DataTransfer, item_index uint) &DataTransferItem {
	return &DataTransferItem{
		data_transfer: data_transfer
		item_index:    item_index
	}
}

pub fn (mut item DataTransferItem) set_item_index(item_index ?uint) {
	item.item_index = item_index
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

// DataTransferItem.cpp::type returns the stored raw UTF-16 type, including
// in protected mode. Only removed items and disassociated stores disable it.
pub fn (item &DataTransferItem) type_utf16() libjs.Utf16String {
	index := item.item_index or { return libjs.Utf16String{} }
	if item.mode() == none {
		return libjs.Utf16String{}
	}
	return item.data_transfer.drag_data(index).type_utf16()
}

// V reserves `type`, so the translated WebIDL getter keeps the class name in
// the free-function entry point.
pub fn data_transfer_item_type(item &DataTransferItem) string {
	return item.type_()
}

// DataTransferItem.cpp::string_data snapshots readable text as raw DOMString
// units. A queued callback keeps this value after removal or store changes.
pub fn (item &DataTransferItem) string_data_utf16() ?libjs.Utf16String {
	mode := item.mode() or { return none }
	if mode !in [.read_write, .read_only] { return none }
	index := item.item_index or { return none }
	data := item.data_transfer.drag_data(index)
	if data.kind != .text { return none }
	return data.text_data_utf16()
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

pub fn (item &DataTransferItem) webkit_get_as_entry() ?&entriesapi.FileSystemEntry {
	mode := item.mode() or { return none }
	if mode !in [.read_write, .read_only] {
		return none
	}
	index := item.item_index or { return none }
	drag_data := item.data_transfer.drag_data(index)
	if drag_data.kind != .file {
		return none
	}
	return entriesapi.FileSystemEntry.create_utf16(.file, drag_data.file_name_utf16())
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

pub fn (list &DataTransferItemList) length() uint {
	return list.data_transfer.length()
}

pub struct DataTransferItemAddResult {
pub:
	item ?&DataTransferItem
}

pub type DataTransferItemAddInput = FormDataFile | string

// DataTransferItemList::add is overloaded in C++. A sum type plus an optional
// trailing type string preserves both overloads in V under the exact name.
pub fn (mut list DataTransferItemList) add(input DataTransferItemAddInput, type_strings ...string) !DataTransferItemAddResult {
	match input {
		string {
			type_string := if type_strings.len > 0 { type_strings[0] } else { '' }
			return list.add_string(input, type_string)
		}
		FormDataFile {
			return DataTransferItemAddResult{
				item: list.add_file(input)
			}
		}
	}
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

// DataTransferItemList.cpp stores DOMString code units and only folds ASCII.
pub fn (mut list DataTransferItemList) add_string_utf16(data libjs.Utf16String, type_string libjs.Utf16String) !DataTransferItemAddResult {
	mode := list.data_transfer.mode() or { return DataTransferItemAddResult{} }
	if mode != .read_write {
		return DataTransferItemAddResult{}
	}
	if list.data_transfer.contains_item_with_type(.text, type_string.str()) {
		return error('NotSupportedError: There is already a DataTransferItem with type ${type_string.str()}')
	}
	mut transfer := unsafe { &DataTransfer(list.data_transfer) }
	return DataTransferItemAddResult{
		item: transfer.add_item(DragDataStoreItem.text_utf16(type_string.to_ascii_lowercase(), data))
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

pub fn (mut list DataTransferItemList) remove(index uint) ! {
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
		// clearData() removes strings; DataTransferItemList.clear() removes
		// every item, including files, and disables the retained item owners.
		for transfer.length() > 0 {
			transfer.remove_item(transfer.length() - 1)
		}
	}
}

pub fn (list &DataTransferItemList) item(index uint) ?&DataTransferItem {
	if index >= list.data_transfer.length() {
		return none
	}
	return list.data_transfer.item(index)
}

pub fn (list &DataTransferItemList) item_value(index uint) ?&DataTransferItem {
	return list.item(index)
}
