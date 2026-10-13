module html

import libjs

fn test_data_transfer_item_type_preserves_raw_utf16_and_compatibility_views() {
	text_type := libjs.utf16_string_from_code_units([u16(`X`), u16(`/`), 0xd800, 0,
		u16(`M`), 0xdc00, 0xd83d, 0xde00])
	file_type := libjs.utf16_string_from_code_units([u16(`F`), u16(`/`), 0xdc00, 0,
		0xd800])
	mut transfer := DataTransfer.construct()
	text := transfer.add_item(DragDataStoreItem.text_utf16(text_type, libjs.utf16_string('text')))
	file := transfer.add_item(DragDataStoreItem.file_utf16(file_type, [u8(1)],
		libjs.utf16_string('raw.bin')))
	assert text.kind() == 'string'
	assert text.type_utf16().code_units() == [u16(`X`), u16(`/`), 0xd800, 0,
		u16(`M`), 0xdc00, 0xd83d, 0xde00]
	assert file.kind() == 'file'
	assert file.type_utf16().code_units() == [u16(`F`), u16(`/`), 0xdc00, 0, 0xd800]
	assert text.type_() == text_type.str()
	assert file.type_() == file_type.str()
	assert data_transfer_item_type(text) == text_type.str()
	assert data_transfer_item_type(file) == file_type.str()
	// File construction normalizes an invalid MIME type; item metadata does not.
	assert file.get_as_file_record()?.type_utf16().code_units().len == 0
	assert file.type_utf16().code_units() == file_type.code_units()

	// Native compatibility callers can update the byte-string view directly.
	mut store := transfer.associated_store?
	store.item_list[0] = DragDataStoreItem{
		...store.item_list[0]
		type_string: 'Mixed/Legacy'
	}
	assert text.type_utf16().str() == 'Mixed/Legacy'
	assert text.type_() == 'Mixed/Legacy'
}

fn test_data_transfer_item_type_stays_visible_when_protected_and_disables_with_its_owner() {
	format := libjs.utf16_string_from_code_units([u16(`X`), 0xd800, 0, 0xdc00])
	mut transfer := DataTransfer.construct()
	text := transfer.add_item(DragDataStoreItem.text_utf16(format, libjs.utf16_string('text')))
	mut list := transfer.items()
	assert voidptr(list.item(0)?) == voidptr(text)
	file := transfer.add_item(DragDataStoreItem.file_utf16(format, [u8(7)],
		libjs.utf16_string('one.bin')))
	mut store := transfer.associated_store?
	store.set_mode(.read_only)
	assert text.type_utf16().code_units() == format.code_units()
	assert file.type_utf16().code_units() == format.code_units()
	assert file.get_as_file_record() != none
	list.clear()
	assert list.length() == 2
	store.set_mode(.protected)
	assert text.kind() == 'string' && file.kind() == 'file'
	assert text.type_utf16().code_units() == format.code_units()
	assert file.type_utf16().code_units() == format.code_units()
	assert text.type_() == format.str() && file.type_() == format.str()
	assert list.length() == 2 && voidptr(list.item(1)?) == voidptr(file)
	assert file.get_as_file_record() == none
	list.clear()
	assert list.length() == 2

	// The pinned clear() removes only text, disabling it and shifting the file.
	store.set_mode(.read_write)
	list.clear()
	assert text.mode() == none && text.kind() == '' && text.type_() == ''
	assert text.type_utf16().code_units().len == 0
	assert list.length() == 1 && voidptr(list.item(0)?) == voidptr(file)
	assert file.type_utf16().code_units() == format.code_units()
	transfer.disassociate_with_drag_data_store()
	assert file.mode() == none && file.kind() == '' && file.type_() == ''
	assert file.type_utf16().code_units().len == 0
	assert file.get_as_file_record() == none
	assert list.length() == 0 && list.item(0) == none
}
