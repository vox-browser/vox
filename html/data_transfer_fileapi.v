// Copyright (c) 2024-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Actual FileAPI owners from DataTransfer.cpp / DataTransferItem.cpp.
module html

import fileapi

// Both Source getters copy the stored file bytes into a Blob, then process
// that Blob through File::create with the item's type and default options.
fn drag_data_store_file(item DragDataStoreItem) &fileapi.File {
	blob := fileapi.Blob.create_utf16(item.data, item.type_utf16())
	// File.h's String overload decodes the to_utf8() result with from_utf8;
	// neither boundary replaces lone UTF16 surrogates or embedded null.
	file_name := item.file_name_utf16().str()
	// Source FIXME: Fill in other fields (e.g. last_modified). An explicitly
	// present default FilePropertyBag supplies the current clock, not zero.
	options := fileapi.FilePropertyBag{
		BlobPropertyBag: fileapi.BlobPropertyBag{
			type_: item.type_utf16().str()
		}
	}
	return fileapi.File.construct([fileapi.BlobPart.from_blob(blob)], file_name, options)
}

// DataTransfer::files returns a new actual FileList and new Files each call.
// The older files() snapshots remain a compatibility entry point.
pub fn (transfer &DataTransfer) file_list() &fileapi.FileList {
	mut files := fileapi.FileList.create()
	store := transfer.associated_store or { return files }
	if store.mode == .protected {
		return files
	}
	for item in store.item_list {
		if item.kind == .file {
			files.add_file(drag_data_store_file(item))
		}
	}
	return files
}

// DataTransferItem::get_as_file's actual File record, separate from the older
// FormDataFile snapshot compatibility entry point.
pub fn (item &DataTransferItem) get_as_file_record() ?&fileapi.File {
	mode := item.mode() or { return none }
	if mode !in [.read_write, .read_only] {
		return none
	}
	index := item.item_index or { return none }
	drag_data := item.data_transfer.drag_data(index)
	if drag_data.kind != .file {
		return none
	}
	return drag_data_store_file(drag_data)
}

// DataTransferItemList::add(File) snapshots the actual File slots and bytes;
// later getters construct new Files rather than retaining the original File.
pub fn (mut list DataTransferItemList) add_file_record(file &fileapi.File) ?&DataTransferItem {
	mode := list.data_transfer.mode() or { return none }
	if mode != .read_write {
		return none
	}
	mut transfer := unsafe { &DataTransfer(list.data_transfer) }
	type_ := file.type_utf16().to_ascii_lowercase()
	return transfer.add_item(DragDataStoreItem.file_utf16(type_, file.raw_bytes(), file.name_utf16()))
}
