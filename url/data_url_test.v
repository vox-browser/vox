module url

fn test_source_create_with_data_builds_actual_opaque_url_record() {
	record := create_with_data('text/plain', 'SGk=', true)
	assert record.scheme == 'data' && record.has_an_opaque_path
	assert record.host == none && record.port == none
	assert record.query == none && record.fragment == none
	assert record.username == '' && record.password == ''
	assert record.paths == ['text/plain;base64,SGk=']
	assert record.serialize_path() == 'text/plain;base64,SGk='
	assert record.serialize(false) == 'data:text/plain;base64,SGk='
	assert record.serialize(true) == 'data:text/plain;base64,SGk='
	assert record.serialize_for_display() == 'data:text/plain;base64,SGk='
}

fn test_source_create_with_data_does_not_parse_or_escape_opaque_input() {
	for mime in ['', 'text/plain;name="a?b#c %"', 'raw\x00mime', 'text/é'] {
		for payload in ['', 'a?b#c %/,:;', '\x00raw\xff'.bytes().bytestr()] {
			record := create_with_data(mime, payload, false)
			assert record.paths == ['${mime},${payload}']
			assert record.serialize(false) == 'data:${mime},${payload}'
			assert record.query == none && record.fragment == none
		}
	}
	assert create_with_data('', '', true).serialize(false) == 'data:;base64,'
}

fn test_source_create_with_data_returns_independent_records_and_owned_path_bytes() {
	mut mime_bytes := 'text/plain'.bytes()
	mut payload_bytes := 'SGk='.bytes()
	mut first := create_with_data(mime_bytes.bytestr(), payload_bytes.bytestr(), true)
	second := create_with_data('text/plain', 'SGk=', true)
	assert voidptr(first) != voidptr(second)
	mime_bytes[0] = `X`
	payload_bytes[0] = `X`
	assert first.paths == ['text/plain;base64,SGk=']
	first.paths[0] = 'changed'
	assert second.serialize(false) == 'data:text/plain;base64,SGk='
}
