module html

import libjs

fn test_data_transfer_item_string_snapshot_preserves_units_after_reindex_and_removal() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	_ = list.add_string('earlier', 'text/earlier')!
	raw := libjs.utf16_string_from_code_units([u16(0xd800), 0, 0xdc00, 0xd83d, 0xde00])
	item := list.add_string_utf16(raw, libjs.utf16_string('text/plain'))!.item?
	assert item.string_data_utf16()?.code_units() == raw.code_units()
	list.remove(0)!
	assert voidptr(list.item(0)?) == voidptr(item)
	snapshot := item.string_data_utf16()?
	list.remove(0)!
	assert item.string_data_utf16() == none
	_ = list.add_string('replacement', 'text/plain')!
	transfer.disassociate_with_drag_data_store()
	assert snapshot.code_units() == raw.code_units()
}

fn test_data_transfer_item_string_snapshot_mode_kind_and_empty_string_gates() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	item := list.add_string('', 'text/plain')!.item?
	file := list.add_file(FormDataFile{ name: 'file.txt', mime_type: 'text/plain', bytes: [u8(65)] })?
	mut store := transfer.associated_store?
	for mode in [DragDataStoreMode.read_write, .read_only] {
		store.set_mode(mode)
		assert item.string_data_utf16()?.code_units().len == 0
		assert file.string_data_utf16() == none
	}
	store.set_mode(.protected)
	assert item.string_data_utf16() == none
	assert file.string_data_utf16() == none
	store.set_mode(.read_write)
	assert item.string_data_utf16() != none
	transfer.disassociate_with_drag_data_store()
	assert item.string_data_utf16() == none
	assert file.string_data_utf16() == none
}
