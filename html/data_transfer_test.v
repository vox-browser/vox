module html

fn test_data_transfer_set_get_clear_and_types() {
	mut transfer := DataTransfer.construct()
	assert transfer.drop_effect() == 'none'
	assert transfer.effect_allowed() == 'none'
	transfer.set_drop_effect('copy')
	transfer.set_drop_effect('invalid')
	assert transfer.drop_effect() == 'copy'
	transfer.set_effect_allowed('copyMove')
	assert transfer.effect_allowed() == 'copyMove'

	transfer.set_data('Text', 'hello')
	transfer.set_data('URL', 'https://example.com/')
	assert transfer.get_data('text/plain') == 'hello'
	assert transfer.get_data('url') == 'https://example.com/'
	assert transfer.types() == ['text/plain', 'text/uri-list']

	transfer.set_data('text/plain', 'replacement')
	assert transfer.get_data('text') == 'replacement'
	assert transfer.length() == 2
	transfer.clear_data('TEXT')
	assert transfer.get_data('text') == ''
	assert transfer.types() == ['text/uri-list']
}

fn test_data_transfer_item_list_modes_and_files() {
	mut transfer := DataTransfer.construct()
	mut items := transfer.items()
	text_result := items.add_string('payload', 'Text/Plain') or { panic('${err}') }
	text_item := text_result.item or { panic('missing text item') }
	assert text_item.kind() == 'string'
	assert text_item.type_() == 'text/plain'
	items.add_string('duplicate', 'text/plain') or {
		assert err.msg().contains('NotSupportedError')
		return
	}
	assert false
}

fn test_data_transfer_item_list_files_and_protected_mode() {
	mut transfer := DataTransfer.construct()
	mut items := transfer.items()
	_ := items.add_string('payload', 'Text/Plain') or { panic('${err}') }
	file_item := items.add_file(FormDataFile{
		name:      'note.txt'
		mime_type: 'TEXT/PLAIN'
		bytes:     'file'.bytes()
	}) or { panic('missing file item') }
	assert file_item.kind() == 'file'
	assert transfer.types() == ['text/plain', 'Files']
	files := transfer.files()
	assert files.len == 1
	assert files[0].name == 'note.txt'
	assert files[0].mime_type == 'text/plain'

	mut store := transfer.associated_store or { panic('missing store') }
	store.mode = .protected
	assert transfer.get_data('text/plain') == ''
	assert transfer.files().len == 0
	assert file_item.get_as_file() == none
	assert items.add_file(FormDataFile{}) == none
	items.remove(0) or {
		assert err.msg().contains('InvalidStateError')
		return
	}
	assert false
}

fn test_data_transfer_disassociation_disables_existing_items() {
	mut transfer := DataTransfer.construct()
	mut items := transfer.items()
	result := items.add_string('payload', 'text/plain') or { panic('${err}') }
	item := result.item or { panic('missing item') }
	transfer.disassociate_with_drag_data_store()
	assert transfer.length() == 0
	assert transfer.types().len == 0
	assert item.kind() == ''
	assert item.type_() == ''
}
