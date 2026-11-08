module html

import fileapi

fn test_data_transfer_public_files_are_live_and_keep_surviving_native_file_identity() {
	mut transfer := DataTransfer.construct()
	mut items := transfer.items()
	first := fileapi.File.create('one'.bytes(), 'one.txt', 'text/plain', 1)
	second := fileapi.File.create('two'.bytes(), 'two.txt', 'text/plain', 2)
	list := transfer.live_file_list()
	assert voidptr(list) == voidptr(transfer.live_file_list())
	assert list.length() == 0
	items.add_file_record(first)?
	one := list.item(0)?
	assert list.length() == 1 && one.name() == 'one.txt'
	assert voidptr(one) == voidptr(list.item(0)?)
	items.add_string('text', 'text/plain')!
	items.add_file_record(second)?
	two := list.item(1)?
	assert list.length() == 2 && two.name() == 'two.txt'
	items.remove(0)!
	assert list.length() == 1 && voidptr(list.item(0)?) == voidptr(two)
	assert one.raw_bytes() == 'one'.bytes()
	mut store := transfer.associated_store?
	store.set_mode(.protected)
	assert list.length() == 0 && list.item(0) == none
	store.set_mode(.read_only)
	assert list.length() == 1 && voidptr(list.item(0)?) == voidptr(two)
	transfer.disassociate_with_drag_data_store()
	assert list.length() == 0
	assert voidptr(list) == voidptr(transfer.live_file_list())
	assert two.raw_bytes() == 'two'.bytes()
}

fn test_data_transfer_saved_live_list_observes_clear_without_getting_files_again() {
	mut transfer := DataTransfer.construct()
	mut items := transfer.items()
	first_item := items.add_file_record(fileapi.File.create('one'.bytes(), 'one.txt', 'text/plain', 1))?
	items.add_string('text', 'text/plain')!
	items.add_file_record(fileapi.File.create('two'.bytes(), 'two.txt', 'text/plain', 2))?
	list := transfer.live_file_list()
	file := list.item(0)?
	serialized := list.serialization_steps()
	items.clear()
	assert transfer.length() == 0 && transfer.types().len == 0
	assert first_item.mode() == none
	assert list.length() == 0 && list.item(0) == none
	assert file.raw_bytes() == 'one'.bytes()
	assert fileapi.FileList.deserialization_steps(serialized).item(0)?.name() == 'one.txt'
}
