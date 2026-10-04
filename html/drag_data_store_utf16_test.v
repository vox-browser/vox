module html

import libjs

fn test_drag_data_store_owns_raw_utf16_text_name_type_and_file_bytes() {
	mut type_units := [u16(`T`), 0xd800, 0, u16(`Z`)]
	mut text_units := [u16(0xdc00), 0, 0xd83d, 0xde00]
	mut name_units := [u16(`n`), 0xdfff, 0, u16(`x`)]
	mut bytes := [u8(0), 0xff, 3]
	text := DragDataStoreItem.text_utf16(libjs.utf16_string_from_code_units(type_units),
		libjs.utf16_string_from_code_units(text_units))
	file := DragDataStoreItem.file_utf16(libjs.utf16_string_from_code_units(type_units), bytes,
		libjs.utf16_string_from_code_units(name_units))
	type_units[0] = u16(`q`)
	text_units[0] = u16(`q`)
	name_units[0] = u16(`q`)
	bytes[0] = 99
	mut store := DragDataStore.create()
	store.add_item(text)
	store.add_item(file)
	assert store.item_list[0].type_utf16().code_units() == [u16(`T`), 0xd800, 0, u16(`Z`)]
	assert store.item_list[0].text_data_utf16().code_units() == [u16(0xdc00), 0, 0xd83d, 0xde00]
	assert store.item_list[1].file_name_utf16().code_units() == [u16(`n`), 0xdfff, 0, u16(`x`)]
	assert store.item_list[1].data == [u8(0), 0xff, 3]
	assert store.item_list[1].text_data_utf16().code_units().len == 0
	mut returned_units := store.item_list[1].file_name_utf16().code_units()
	returned_units[0] = u16(`q`)
	assert store.item_list[1].file_name_utf16().code_units()[0] == `n`
	assert text.type_string == text.type_utf16().str()
	assert text.data == text.text_data_utf16().str().bytes()
	assert file.file_name == file.file_name_utf16().str()
}

fn test_drag_data_store_compatibility_updates_do_not_reuse_stale_raw_slots() {
	text := DragDataStoreItem.text_utf16(libjs.utf16_string_from_code_units([u16(0xd800)]),
		libjs.utf16_string_from_code_units([u16(0xdc00)]))
	changed_text := DragDataStoreItem{
		...text
		type_string: 'text/plain'
		data:        'replacement'.bytes()
	}
	assert changed_text.type_utf16().code_units() == libjs.utf16('text/plain')
	assert changed_text.text_data_utf16().code_units() == libjs.utf16('replacement')
	file := DragDataStoreItem.file_utf16(libjs.utf16_string('image/png'), [u8(1)],
		libjs.utf16_string_from_code_units([u16(0xdfff)]))
	changed_file := DragDataStoreItem{
		...file
		file_name: 'new.png'
	}
	assert changed_file.file_name_utf16().code_units() == libjs.utf16('new.png')
	legacy := DragDataStoreItem{
		kind:        .file
		type_string: 'text/plain'
		data:        [u8(1), 2]
		file_name:   'legacy.txt'
	}
	assert legacy.type_utf16().str() == 'text/plain'
	assert legacy.file_name_utf16().str() == 'legacy.txt'
}

fn test_drag_data_store_preserves_raw_utf16_storage_and_existing_text_lookup() {
	wide_ascii := libjs.utf16_string_from_code_units_with_storage([u16(`x`)], false)!
	item := DragDataStoreItem.text_utf16(wide_ascii, wide_ascii)
	assert !item.type_utf16().has_ascii_storage()
	assert !item.text_data_utf16().has_ascii_storage()
	mut store := DragDataStore.create()
	store.add_item(DragDataStoreItem.text_utf16(libjs.utf16_string('text/plain'), wide_ascii))
	assert store.has_text_item()
	store.add_item(DragDataStoreItem.file_utf16(wide_ascii, []u8{}, wide_ascii))
	assert !store.item_list[1].type_utf16().has_ascii_storage()
	assert !store.item_list[1].file_name_utf16().has_ascii_storage()
	assert store.size() == 2
	store.remove_item_at(0)
	assert !store.has_text_item()
}
