module domurl

fn test_url_decode_basic() {
	params := url_decode('a=1&b=2&c=3')
	assert params.len == 3
	assert params[0] == QueryParam{'a', '1'}
	assert params[2] == QueryParam{'c', '3'}
}

fn test_url_decode_plus_and_percent() {
	params := url_decode('q=a+b&sym=%26%3D&utf=%C3%A4')
	assert params[0] == QueryParam{'q', 'a b'}
	assert params[1] == QueryParam{'sym', '&='}
	assert params[2] == QueryParam{'utf', 'ä'}
}

fn test_url_decode_edge_cases() {
	// No '=' → empty value; leading '=' → empty name; empty segments dropped.
	params := url_decode('novalue&=val&a=1&&b=2')
	assert params.len == 4
	assert params[0] == QueryParam{'novalue', ''}
	assert params[1] == QueryParam{'', 'val'}
	assert params[2] == QueryParam{'a', '1'}
	assert params[3] == QueryParam{'b', '2'}
}

fn test_url_encode_serializer() {
	tuples := [QueryParam{'a', '1'}, QueryParam{'x y', '&='},
		QueryParam{'keep', '*-._'}]
	// Space → '+', reserved chars percent-encoded, *-._ kept as-is.
	assert url_encode(tuples) == 'a=1&x+y=%26%3D&keep=*-._'
}

fn test_utf8_round_trip() {
	tuples := [QueryParam{'name', 'ä€'}]
	encoded := url_encode(tuples)
	assert encoded == 'name=%C3%A4%E2%82%AC'
	decoded := url_decode(encoded)
	assert decoded[0].value == 'ä€'
}

fn test_from_string_strips_leading_question_mark() {
	params := URLSearchParams.from_string('?a=1&b=2')
	assert params.size() == 2
	assert params.get('a')? == '1'
}

fn test_from_sequence_and_record() {
	seq := URLSearchParams.from_sequence([['a', '1'], ['b', '2']]) or { panic('${err}') }
	assert seq.get('a')? == '1'
	// A pair without exactly two items is a TypeError.
	if _ := URLSearchParams.from_sequence([['only-one']]) {
		assert false, 'expected TypeError'
	}
	record := URLSearchParams.from_record({
		'x': '9'
	})
	assert record.get('x')? == '9'
}

fn test_append_get_getall_has() {
	mut params := URLSearchParams.from_string('a=1&a=2&b=3')
	assert params.get('a')? == '1'
	assert params.get_all('a') == ['1', '2']
	assert params.get('missing') == none
	assert params.has('a') == true
	assert params.has('a', '2') == true
	assert params.has('a', '9') == false
	params.append('c', '4')
	assert params.size() == 4
	assert params.get('c')? == '4'
}

fn test_set_replaces_first_and_removes_rest() {
	mut params := URLSearchParams.from_string('a=1&b=2&a=3')
	params.set('a', '9')
	// The first "a" becomes 9, the duplicate is removed, "b" stays.
	assert params.get_all('a') == ['9']
	assert params.to_string() == 'a=9&b=2'
	// set on a missing name appends.
	params.set('z', '0')
	assert params.get('z')? == '0'
}

fn test_delete() {
	mut params := URLSearchParams.from_string('a=1&a=2&b=3')
	params.delete('a', '1')
	assert params.get_all('a') == ['2']
	params.delete('a', none)
	assert params.has('a') == false
	assert params.to_string() == 'b=3'
}

fn test_sort_is_stable_by_code_units() {
	mut params := URLSearchParams.from_string('b=1&a=x&b=2&A=y')
	params.sort()
	// Uppercase 'A' (0x41) sorts before lowercase letters; equal names keep relative order.
	assert params.to_string() == 'A=y&a=x&b=1&b=2'
}

fn test_to_string_round_trip() {
	mut params := URLSearchParams.from_string('a=1&b=hello+world')
	assert params.to_string() == 'a=1&b=hello+world'
}
