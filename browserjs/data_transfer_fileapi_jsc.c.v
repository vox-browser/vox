// Copyright (c) 2024-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Bounded actual DataTransfer implementation → FileAPI wrapper adapters.
module browserjs

import html


// Shared by the public native DataTransfer.files getter and implementation
// producers. Preserve DataTransfer.cpp's fresh FileList/Files on every call;
// the caller supplies the actual implementation, not an author-visible ID.
pub fn (mut runtime Runtime) javascript_data_transfer_files(transfer &html.DataTransfer) !voidptr {
	runtime.require_javascript_value_context()!
	return runtime.javascript_file_list(transfer.file_list())
}

pub fn (mut runtime Runtime) javascript_data_transfer_item_file(item &html.DataTransferItem) !voidptr {
	runtime.require_javascript_value_context()!
	file := item.get_as_file_record() or { return C.vox_jsc_JSValueMakeNull(runtime.context) }
	return runtime.javascript_file(file)
}

// Only the generated add(File) branch is adapted here. Its input requires the
// actual File implementation before the Source read/write applicability gate.
// The producer adapter retains its typed result; the public add() arbiter uses
// the same native File record and implementation producer.
pub fn (mut runtime Runtime) add_javascript_data_transfer_file(mut list html.DataTransferItemList, value voidptr) !html.DataTransferItemAddResult {
	runtime.require_javascript_value_context()!
	file := runtime.native_file(value) or {
		return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
	}
	return html.DataTransferItemAddResult{
		item: list.add_file_record(file)
	}
}
