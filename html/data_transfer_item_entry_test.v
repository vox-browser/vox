module html

import libjs

fn test_data_transfer_entry_is_fresh_and_keeps_raw_name_after_reindex_and_removal() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	_ = list.add_string('earlier', 'text/plain')!
	mut store := transfer.associated_store?
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00])
	item := transfer.add_item(DragDataStoreItem.file_utf16(libjs.utf16_string('text/plain'), [u8(1)], name))
	first := item.webkit_get_as_entry()?
	second := item.webkit_get_as_entry()?
	assert voidptr(first) != voidptr(second)
	assert first.is_file() && !first.is_directory()
	assert first.name_utf16().code_units() == name.code_units()
	list.remove(0)!
	assert voidptr(list.item(0)?) == voidptr(item)
	store.item_list[0] = DragDataStoreItem{
		...store.item_list[0]
		file_name: 'replacement'
	}
	assert item.webkit_get_as_entry()?.name() == 'replacement'
	list.remove(0)!
	assert item.webkit_get_as_entry() == none
	transfer.disassociate_with_drag_data_store()
	assert first.name_utf16().code_units() == name.code_units()
	assert second.name_utf16().code_units() == name.code_units()
}

fn test_data_transfer_entry_read_modes_and_file_kind_gate_empty_and_directory_names() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	text := list.add_string('text', 'text/plain')!.item?
	empty := list.add_file(FormDataFile{ name: '', bytes: [u8(1)] })?
	directory := list.add_file(FormDataFile{ name: 'directory/', bytes: []u8{} })?
	mut store := transfer.associated_store?
	for mode in [DragDataStoreMode.read_write, .read_only] {
		store.set_mode(mode)
		assert text.webkit_get_as_entry() == none
		assert empty.webkit_get_as_entry()?.name() == ''
		assert directory.webkit_get_as_entry()?.is_file()
		assert !directory.webkit_get_as_entry()?.is_directory()
	}
	store.set_mode(.protected)
	assert empty.webkit_get_as_entry() == none
	store.set_mode(.read_write)
	list.remove(1)!
	assert empty.webkit_get_as_entry() == none
	assert directory.webkit_get_as_entry()?.name() == 'directory/'
	transfer.disassociate_with_drag_data_store()
	assert directory.webkit_get_as_entry() == none
}
