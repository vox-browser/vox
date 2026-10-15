module url

fn test_large_embedded_image_opaque_path_roundtrips_without_losing_payload() {
	// Real SVG patterns embed raster data at this scale. This used to copy the
	// entire growing path per byte, allocating a quadratic amount of memory.
	payload := 'QUJD'.repeat(262144)
	input := 'data:image/png;base64,' + payload
	base := parse('https://pikabu.ru/images/onboarding.svg')?
	actual := parse_with_base(input, base)?
	assert actual.scheme == 'data'
	assert actual.has_an_opaque_path
	assert actual.host == none
	assert actual.paths == ['image/png;base64,' + payload]
	assert actual.query == none
	assert actual.fragment == none
	assert actual.serialize(false) == input
}

fn test_opaque_path_buffer_keeps_unicode_controls_and_url_preprocessing() {
	actual := parse('\x00 \tDaTa:text/plain,Привет\x01\x7f%2F%zz\r\n payload \x00')?
	assert actual.paths == ['text/plain,%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%01%7F%2F%zz payload']
	assert actual.serialize(false) == 'data:text/plain,%D0%9F%D1%80%D0%B8%D0%B2%D0%B5%D1%82%01%7F%2F%zz payload'
}

fn test_opaque_path_buffer_commits_path_before_query_and_fragment() {
	query := parse('data:text/plain,first  ?query=Ю #fragment value')?
	assert query.paths == ['text/plain,first %20']
	assert query.query? == 'query=%D0%AE%20'
	assert query.fragment? == 'fragment%20value'
	fragment := parse('data:text/plain,first  #fragment value')?
	assert fragment.paths == ['text/plain,first %20']
	assert fragment.query == none
	assert fragment.fragment? == 'fragment%20value'
	assert parse('custom:')?.paths == ['']
	assert parse('custom:?query')?.paths == ['']
	assert parse('custom:#fragment')?.paths == ['']
}

fn test_opaque_path_buffer_preserves_base_fragment_resolution() {
	base := parse('data:text/plain,original ?old#first')?
	resolved := parse_with_base('#next value', base)?
	assert resolved.paths == ['text/plain,original%20']
	assert resolved.query? == 'old'
	assert resolved.fragment? == 'next%20value'
	assert parse_with_base('relative', base) == none
	assert parse_with_base('?replacement', base) == none
	assert base.serialize(false) == 'data:text/plain,original%20?old#first'
}
