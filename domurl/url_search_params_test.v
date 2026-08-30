module domurl

import fileapi

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

fn test_url_search_params_exact_constructor_and_delete_entry_points() {
	mut from_string := URLSearchParams.construct_impl(URLSearchParamsInit('?a=1&a=2'))!
	assert from_string.get_all('a') == ['1', '2']
	from_string.delete_('a', '1')
	assert from_string.to_string() == 'a=2'

	from_sequence := URLSearchParams.construct_impl(URLSearchParamsInit([['x', '9']]))!
	assert from_sequence.get('x')? == '9'
	from_record := URLSearchParams.construct_impl(URLSearchParamsInit({
		'y': '8'
	}))!
	assert from_record.get('y')? == '8'
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

fn test_dom_url_components_and_live_search_params() {
	mut url := DOMURL.construct_impl('/path?x=1#frag', 'https://user:pass@example.com:8443/base') or {
		panic(err)
	}
	assert url.protocol() == 'https:'
	assert url.username() == 'user'
	assert url.password() == 'pass'
	assert url.host() == 'example.com:8443'
	assert url.hostname() == 'example.com'
	assert url.port() == '8443'
	assert url.pathname() == '/path'
	assert url.search() == '?x=1'
	assert url.hash() == '#frag'
	assert url.search_params().get('x') or { '' } == '1'

	mut params := url.search_params()
	params.append('space', 'a b')
	assert url.search() == '?x=1&space=a+b'
	assert url.href().contains('x=1&space=a+b')
	url.set_search('?next=2')
	assert params.get('x') == none
	assert params.get('next') or { '' } == '2'
	url.set_hash('changed')
	url.set_port('443')
	assert url.hash() == '#changed'
	assert url.origin() == 'https://example.com'
	assert url.to_json() == url.href()
}

fn test_dom_url_parse_validation_and_origin_identity() {
	assert DOMURL.can_parse('https://example.com/a', none)
	assert !DOMURL.can_parse('/relative', none)
	assert DOMURL.parse_for_bindings('/relative', 'https://example.com/base') != none
	if _ := DOMURL.construct_impl('/relative', none) {
		assert false, 'relative URL without a base must throw'
	}

	a := Origin.from_string('https://EXAMPLE.com:443/a') or { panic(err) }
	b := Origin.from_string('https://example.com/b') or { panic(err) }
	c := Origin.from_string('http://example.com/') or { panic(err) }
	assert !a.opaque()
	assert a.serialize() == 'https://example.com'
	assert a.is_same_origin(b)
	assert !a.is_same_origin(c)
	opaque := Origin.construct_impl()
	other_opaque := Origin.construct_impl()
	assert opaque.opaque()
	assert opaque.is_same_origin(opaque)
	assert !opaque.is_same_origin(other_opaque)
}

fn test_url_search_params_iterator_is_live() {
	mut params := URLSearchParams.from_string('a=1&b=2')
	mut iterator := URLSearchParamsIterator.create(params, .key_value)
	first := iterator.next()
	assert !first.done
	assert first.key == 'a'
	assert first.value == '1'
	params.append('c', '3')
	assert iterator.next().key == 'b'
	assert iterator.next().key == 'c'
	assert iterator.next().done
}

fn test_urlencoded_parser_replaces_invalid_utf8() {
	params := url_decode('bad=%FF&truncated=%E2%82')
	assert params[0].value == '\ufffd'
	assert params[1].value == '\ufffd'
}

fn test_dom_url_setters_validate_normalize_and_percent_encode() {
	mut url := DOMURL.construct_impl('https://example.com:443/base?q=a b', none)!
	assert url.href() == 'https://example.com/base?q=a%20b'
	assert url.port() == ''
	url.set_port('00443')
	assert url.port() == ''
	url.set_port('65536')
	assert url.port() == ''
	url.set_port('8080')
	assert url.port() == '8080'
	url.set_port('invalid')
	assert url.port() == '8080'
	url.set_pathname('a b')
	assert url.pathname() == '/a%20b'
	assert url.href().contains('/a%20b')
	url.set_search('?value=a b#c')
	assert url.search() == '?value=a%20b%23c'
	assert url.search_params().get('value')? == 'a b#c'
	old_host := url.host()
	url.set_host('bad host')
	assert url.host() == old_host
}

fn test_blob_url_origin_and_store_integration() {
	blob := fileapi.Blob.create('payload'.bytes(), 'text/plain')
	mut store := fileapi.BlobURLStore.create()
	environment := fileapi.BlobURLEnvironment{
		id:          'document'
		origin:      'https://example.com'
		storage_key: 'partition'
	}
	value := DOMURL.create_object_url_for_blob(blob, environment, mut store)!
	url := DOMURL.construct_impl(value, none)!
	assert url.origin() == 'https://example.com'
	assert store.resolve(value) != none
	unauthorized := fileapi.BlobURLEnvironment{
		id:          'other'
		origin:      'https://example.com'
		storage_key: 'other-partition'
	}
	DOMURL.revoke_object_url_from_store(value, unauthorized, mut store)
	assert store.resolve(value) != none
	DOMURL.revoke_object_url_from_store(value, environment, mut store)
	assert store.resolve(value) == none
}

fn test_non_network_schemes_have_opaque_origins() {
	file_origin := Origin.from_string('file:///tmp/a')!
	custom_origin := Origin.from_string('custom://example.com/a')!
	assert file_origin.opaque()
	assert custom_origin.opaque()
	assert file_origin.serialize() == 'null'
}

fn test_dom_url_component_getters_serialize_percent_encoding() {
	mut url := DOMURL.construct_impl('https://A%20B:P%3Bass@EXAMPLE.COM/a%20b#c%20d', none)!
	assert url.username() == 'A%20B'
	assert url.password() == 'P%3Bass'
	assert url.hostname() == 'example.com'
	assert url.pathname() == '/a%20b'
	assert url.hash() == '#c%20d'
	url.set_username('x;y')
	url.set_password('p:q')
	assert url.username() == 'x%3By'
	assert url.password() == 'p%3Aq'
	assert url.href().starts_with('https://x%3By:p%3Aq@example.com/')
	ipv6 := DOMURL.construct_impl('http://[::A]:80/', none)!
	assert ipv6.hostname() == '[::a]'
	assert ipv6.host() == '[::a]'
	assert ipv6.origin() == 'http://[::a]'
}

fn test_dom_url_scheme_and_empty_query_setter_rules() {
	mut special := DOMURL.construct_impl('http://example.com:443/path', none)!
	special.set_protocol('custom:')
	assert special.protocol() == 'http:'
	special.set_protocol('https:')
	assert special.protocol() == 'https:'
	assert special.port() == ''
	special.set_search('?')
	assert special.search() == ''
	assert special.href().contains('/path?')
	special.set_hash('#')
	assert special.hash() == ''
	assert special.href().ends_with('?#')
	old_host := special.host()
	special.set_host('user@example.test')
	assert special.host() == old_host

	mut opaque := DOMURL.construct_impl('custom:value', none)!
	opaque.set_protocol('https:')
	assert opaque.protocol() == 'custom:'
}

fn test_dom_url_internal_component_entry_points() {
	mut url := DOMURL.construct_impl('https://example.com/a?#', none)!
	assert url.query()? == ''
	assert url.fragment()? == ''
	url.set_query('x=1')
	assert url.query()? == 'x=1'
	url.set_query(none)
	assert url.query() == none
	url.set_paths(['a b', 'c?d'])
	assert url.pathname() == '/a%20b/c%3Fd'

	without_components := DOMURL.construct_impl('https://example.com/', none)!
	assert without_components.query() == none
	assert without_components.fragment() == none
}

fn test_dom_url_create_initialize_and_origin_from_entry_points() {
	record := parse_api_url('https://example.com/path?x=1', none) or { panic('parse failed') }
	mut query := URLSearchParams.from_string(record.raw_query)
	created := DOMURL.create(record, false, query)
	assert created.href() == 'https://example.com/path?x=1'
	initialized := DOMURL.initialize_a_url(record, false)
	assert initialized.search_params().get('x')? == '1'

	from_string := Origin.from(OriginInput('https://example.com:443/a'))!
	from_url := Origin.from(OriginInput(OriginDOMURLSource{
		value: initialized
	}))!
	assert from_string.is_same_origin(from_url)
	opaque := Origin.construct_impl()
	cloned := Origin.from(OriginInput(OriginObjectSource{
		value: opaque
	}))!
	assert cloned.is_same_origin(opaque)
}
