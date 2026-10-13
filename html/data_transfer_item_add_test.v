module html

import libjs

fn test_data_transfer_item_add_keeps_raw_string_units_duplicates_and_identity() {
	// Compatibility V callers retain noncanonical byte spellings verbatim.
	mut compatibility := DataTransfer.construct()
	mut compatibility_list := compatibility.items()
	bytes := [u8(0xc0), 0x80, 0xff]
	type_bytes := [u8(`X`), 0xc0, 0xaf]
	assert compatibility_list.add_string(bytes.bytestr(), type_bytes.bytestr())!.item != none
	assert compatibility.drag_data(0).data == bytes
	assert compatibility.drag_data(0).type_string.bytes() == [u8(`x`), 0xc0, 0xaf]
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	format := libjs.utf16_string_from_code_units([u16(`X`), 0xd800, 0, 0xdc00, 0x00c9])
	data := libjs.utf16_string_from_code_units([u16(0xdc00), 0, 0xd800, 0xd83d, 0xde00])
	first := list.add_string_utf16(data, format)!.item?
	assert voidptr(first) == voidptr(list.item(0)?)
	assert first.kind() == 'string'
	assert first.type_utf16().code_units() == [u16(`x`), 0xd800, 0, 0xdc00, 0x00c9]
	assert transfer.drag_data(0).text_data_utf16().code_units() == data.code_units()
	assert transfer.get_data_utf16(format).code_units() == data.code_units()
	before := transfer.types_revision()
	list.add_string_utf16(libjs.utf16_string('ignored'), format) or {
		message := libjs.utf16_string_from_utf8_without_validation(err.msg().all_after('NotSupportedError: '))
		mut expected := libjs.utf16_string('There is already a DataTransferItem with type ').code_units()
		expected << format.code_units()
		assert message.code_units() == expected
		assert list.length() == 1 && transfer.types_revision() == before
		list.remove(0)!
		assert first.kind() == ''
		second := list.add_string(data.str(), format.str())!.item?
		assert voidptr(second) != voidptr(first)
		assert transfer.drag_data(0).text_data_utf16().code_units() == data.code_units()
		return
	}
	assert false, 'duplicate string type must reject'
}

fn test_data_transfer_item_add_mode_gates_precede_duplicate_detection() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	assert list.add_string('original', 'TEXT/PLAIN')!.item != none
	mut store := transfer.associated_store?
	before := transfer.types_revision()
	for mode in [DragDataStoreMode.read_only, .protected] {
		store.set_mode(mode)
		assert list.add_string_utf16(libjs.utf16_string('ignored'), libjs.utf16_string('TEXT/PLAIN'))!.item == none
		assert list.length() == 1 && transfer.types_revision() == before
	}
	transfer.disassociate_with_drag_data_store()
	assert list.add_string_utf16(libjs.utf16_string('ignored'), libjs.utf16_string('TEXT/PLAIN'))!.item == none
	assert list.length() == 0
}
