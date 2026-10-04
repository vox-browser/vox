module html

import fileapi
import libjs
import time

fn test_data_transfer_actual_files_are_fresh_ordered_owners_with_source_name_type_and_clock() {
	mut store := DragDataStore.create()
	store.mode = .read_write
	store.add_item(DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'), libjs.utf16_string('text')))
	name := libjs.utf16_string_from_code_units([u16(`n`), 0xd800, 0, 0xdc00, 0xd83d, 0xde00, u16(`x`)])
	store.add_item(DragDataStoreItem.file_utf16(libjs.utf16_string('TEXT/PLAIN'), [
		u8(0),
		0xff,
		3,
	], name))
	store.add_item(DragDataStoreItem.file_utf16(libjs.utf16_string_from_code_units([
		u16(`x`),
		0xd800,
	]),
		'second'.bytes(), libjs.utf16_string('second.bin')))
	transfer := DataTransfer.create(store)
	before := time.now().unix_milli()
	first := transfer.file_list()
	second := transfer.file_list()
	after := time.now().unix_milli()
	assert voidptr(first) != voidptr(second)
	assert first.length() == 2
	one := first.item(0)?
	two := first.item(1)?
	assert voidptr(one) != voidptr(second.item(0)?)
	assert one.name_utf16().code_units() == name.code_units()
	assert one.raw_bytes() == [u8(0), 0xff, 3]
	assert one.type_() == 'text/plain'
	assert two.name() == 'second.bin'
	assert two.raw_bytes() == 'second'.bytes()
	assert two.type_() == ''
	assert one.last_modified() >= before && one.last_modified() <= after
	assert two.last_modified() >= before && two.last_modified() <= after
	mut file_bytes := one.raw_bytes()
	file_bytes[0] = 77
	assert store.item_list[1].data[0] == 0
	store.item_list[1] = DragDataStoreItem{
		...store.item_list[1]
		data:      [u8(9)]
		file_name: 'changed.bin'
	}
	assert first.item(0)?.raw_bytes() == [u8(0), 0xff, 3]
	assert first.item(0)?.name_utf16().code_units() == name.code_units()
	assert transfer.file_list().item(0)?.raw_bytes() == [u8(9)]
	assert transfer.file_list().item(0)?.name() == 'changed.bin'
}

fn test_data_transfer_actual_file_getters_preserve_protected_disabled_and_removed_item_gates() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	text := list.add_string('text', 'text/plain')!.item?
	file := list.add_file_record(fileapi.File.create([u8(1)], 'one.bin', 'application/octet-stream', -7))?
	assert text.get_as_file_record() == none
	one := file.get_as_file_record()?
	two := file.get_as_file_record()?
	assert voidptr(one) != voidptr(two)
	assert one.raw_bytes() == [u8(1)]
	assert one.last_modified() != -7
	mut store := transfer.associated_store?
	store.mode = .read_only
	assert file.get_as_file_record() != none
	assert transfer.file_list().length() == 1
	assert list.add_file_record(one) == none
	store.mode = .protected
	first_empty := transfer.file_list()
	second_empty := transfer.file_list()
	assert first_empty.length() == 0
	assert voidptr(first_empty) != voidptr(second_empty)
	assert file.get_as_file_record() == none
	store.mode = .read_write
	list.remove(1)!
	assert file.get_as_file_record() == none
	transfer.disassociate_with_drag_data_store()
	assert text.get_as_file_record() == none
	assert transfer.file_list().length() == 0
	assert voidptr(transfer.file_list()) != voidptr(transfer.file_list())
}

fn test_data_transfer_actual_file_add_copies_raw_owner_slots_and_preserves_existing_snapshots() {
	mut transfer := DataTransfer.construct()
	mut list := transfer.items()
	name := libjs.utf16_string_from_code_units([u16(0xdfff), 0, u16(`Z`)])
	type_ := libjs.utf16_string_from_code_units([u16(`T`), u16(`X`), 0xd800])
	mut input := fileapi.File.create_utf16('original'.bytes(), name, type_, -4096)
	item := list.add_file_record(input)?
	stored := transfer.drag_data(0)
	assert stored.file_name_utf16().code_units() == name.code_units()
	assert stored.type_utf16().code_units() == [u16(`t`), u16(`x`), 0xd800]
	assert stored.data == 'original'.bytes()
	input.deserialization_steps_utf16(libjs.utf16_string('text/plain'), 'changed'.bytes(),
		libjs.utf16_string('changed.txt'), 10)
	assert stored.data == 'original'.bytes()
	assert transfer.file_list().item(0)?.name_utf16().code_units() == name.code_units()
	actual := item.get_as_file_record()?
	assert voidptr(actual) != voidptr(input)
	assert actual.raw_bytes() == 'original'.bytes()
	assert actual.type_() == ''
	assert actual.name_utf16().code_units() == name.code_units()
	assert transfer.files()[0].name == stored.file_name
	assert item.get_as_file()?.bytes == 'original'.bytes()
}
