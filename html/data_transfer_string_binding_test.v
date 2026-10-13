module html

import libjs

fn test_data_transfer_string_store_matches_source_case_aliases_and_replacement_order() {
	mut transfer := DataTransfer.construct()
	assert transfer.types_revision() == 1
	transfer.set_data('X-CUSTOM', 'first')
	first := transfer.item(0)
	transfer.set_data('x-custom', 'second')
	assert transfer.types() == ['X-CUSTOM', 'x-custom']
	assert transfer.get_data('x-CuStOm') == 'first'
	assert transfer.types_revision() == 5

	// Storage replacement is exact; replacement appends after the other case.
	transfer.set_data('X-CUSTOM', 'replacement')
	assert first.kind() == ''
	assert transfer.types() == ['x-custom', 'X-CUSTOM']
	assert transfer.get_data('X-CUSTOM') == 'second'
	assert transfer.drag_data(1).text_data_utf16().str() == 'replacement'
	assert transfer.types_revision() == 8
	transfer.clear_data('X-Custom')
	assert transfer.length() == 0
	assert transfer.types_revision() == 10

	transfer.set_data('TeXT', 'legacy text')
	transfer.set_data('uRL', '# comment\nhttps://example.test/first\nhttps://example.test/second')
	transfer.set_data('text/plain', 'new text')
	assert transfer.types() == ['text/uri-list', 'text/plain']
	assert transfer.get_data('TEXT') == 'new text'
	// The pinned source has not implemented URL-list parsing.
	assert transfer.get_data('URL') == '# comment\nhttps://example.test/first\nhttps://example.test/second'
	assert transfer.types_revision() == 17
	transfer.add_item(DragDataStoreItem.file_utf16(libjs.utf16_string('image/png'),
		[u8(1)], libjs.utf16_string('image.png')))
	assert transfer.types() == ['text/uri-list', 'text/plain', 'Files']
	transfer.clear_data('TEXT')
	assert transfer.types() == ['text/uri-list', 'Files']
	assert transfer.types_revision() == 19
	transfer.clear_data(none)
	assert transfer.types() == ['Files']
	assert transfer.files().len == 1
	assert transfer.types_revision() == 20
	transfer.clear_data(none)
	assert transfer.types_revision() == 20

	// Only ASCII case folds, including for formats that contain Unicode.
	transfer.set_data('ÉTYPE', 'upper Unicode')
	transfer.set_data('étype', 'lower Unicode')
	assert transfer.get_data('Étype') == 'upper Unicode'
	transfer.clear_data('éTYPE')
	assert transfer.get_data('étype') == ''
	assert transfer.get_data('ÉTYPE') == 'upper Unicode'
	assert transfer.types() == ['ÉTYPE', 'Files']
}

fn test_data_transfer_raw_utf16_types_revision_and_mode_noops() {
	mut format_units := [u16(`X`), 0xd800, 0, 0xdc00, 0x00c9]
	mut value_units := [u16(0xdc00), 0, 0xd800, 0xd83d, 0xde00]
	format := libjs.utf16_string_from_code_units(format_units)
	value := libjs.utf16_string_from_code_units(value_units)
	mut transfer := DataTransfer.construct_impl()
	transfer.set_data_utf16(format, value)
	assert transfer.types_revision() == 3
	format_units[0] = u16(`Q`)
	value_units[0] = 42
	assert transfer.types_utf16()[0].code_units() == [u16(`X`), 0xd800, 0, 0xdc00, 0x00c9]
	lookup := libjs.utf16_string_from_code_units([u16(`x`), 0xd800, 0, 0xdc00, 0x00c9])
	assert transfer.get_data_utf16(lookup).code_units() == [u16(0xdc00), 0, 0xd800, 0xd83d, 0xde00]
	assert libjs.utf16_string_from_utf8_without_validation(transfer.get_data(lookup.str())).code_units() == value.code_units()
	assert libjs.utf16_string_from_utf8_without_validation(transfer.types()[0]).code_units() == format.code_units()

	// A replacement changes revision even when its visible type vector is equal.
	old_types := transfer.types_utf16()
	transfer.set_data(format.str(), value.str())
	assert transfer.types_utf16()[0].code_units() == old_types[0].code_units()
	assert transfer.types_revision() == 6
	mut returned_types := transfer.types_utf16()
	returned_types.clear()
	assert transfer.types_utf16().len == 1
	transfer.clear_data_utf16(libjs.utf16_string('missing'))
	assert transfer.types_revision() == 6

	mut store := transfer.associated_store or { panic('missing store') }
	store.set_mode(.read_only)
	transfer.set_data_utf16(format, libjs.utf16_string('ignored'))
	transfer.clear_data_utf16(none)
	assert transfer.get_data_utf16(lookup).code_units() == value.code_units()
	assert transfer.types_revision() == 6
	transfer.set_effect_allowed('move')
	assert transfer.effect_allowed() == 'none'
	store.set_mode(.protected)
	assert transfer.get_data_utf16(lookup).code_units().len == 0
	transfer.set_data(format.str(), 'ignored')
	transfer.clear_data(none)
	assert transfer.types_utf16()[0].code_units() == format.code_units()
	assert transfer.types_revision() == 6
	store.set_mode(.read_write)
	transfer.clear_data_utf16(lookup)
	assert transfer.types_utf16().len == 0
	assert transfer.types_revision() == 7
	transfer.clear_data_utf16(none)
	assert transfer.types_revision() == 7

	transfer.disassociate_with_drag_data_store()
	assert transfer.types_revision() == 8
	transfer.disassociate_with_drag_data_store()
	assert transfer.types_revision() == 9
	transfer.set_data_utf16(format, value)
	transfer.clear_data_utf16(none)
	assert transfer.get_data_utf16(lookup).code_units().len == 0
	assert transfer.types_utf16().len == 0
	assert transfer.types_revision() == 9
}
