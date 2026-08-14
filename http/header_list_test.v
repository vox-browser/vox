module http

fn test_contains_and_get_are_case_insensitive() {
	mut list := HeaderList.create()
	list.append(Header{'Content-Type', 'text/html'})
	assert list.contains('content-type') == true
	assert list.contains('CONTENT-TYPE') == true
	assert list.contains('X-Missing') == false
	assert list.get('content-type')? == 'text/html'
	assert list.get('missing') == none
}

fn test_get_combines_multiple_values() {
	mut list := HeaderList.create()
	list.append(Header{'X-Test', '1'})
	list.append(Header{'x-test', '2'})
	// All matching values are joined with ", ".
	assert list.get('X-Test')? == '1, 2'
	// append reuses the casing of the first matching header's name.
	assert list.headers()[1].name == 'X-Test'
}

fn test_is_empty() {
	mut list := HeaderList.create()
	assert list.is_empty() == true
	list.append(Header{'A', 'b'})
	assert list.is_empty() == false
}

fn test_get_decode_and_split_simple() {
	assert get_decode_and_split_header_value('nosniff') == ['nosniff']
	assert get_decode_and_split_header_value('a, b, c') == ['a', 'b', 'c']
	// Surrounding tab/space is trimmed from each value.
	assert get_decode_and_split_header_value('  a ,\tb\t') == ['a', 'b']
}

fn test_get_decode_and_split_respects_quotes() {
	// A comma inside a quoted string does not split; the quoted run is kept verbatim.
	assert get_decode_and_split_header_value('a, "b, c", d') == ['a', '"b, c"', 'd']
	// A backslash escape inside the quoted string is preserved.
	assert get_decode_and_split_header_value(r'x, "a\",b"') == ['x', r'"a\",b"']
}

fn test_get_decode_and_split_on_header_list() {
	mut list := HeaderList.create()
	list.append(Header{'Accept', 'text/html'})
	list.append(Header{'accept', 'application/json'})
	// Combined ("text/html, application/json") then split.
	assert list.get_decode_and_split('Accept')? == ['text/html', 'application/json']
	assert list.get_decode_and_split('Missing') == none
}
