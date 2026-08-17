module mimesniff

fn parse(input string) MimeType {
	return MimeType.parse(input) or { panic('parse(${input}) failed') }
}

fn test_parse_basic() {
	m := parse('text/html')
	assert m.type_() == 'text'
	assert m.subtype() == 'html'
	assert m.essence() == 'text/html'
	assert m.parameters().len == 0
}

fn test_parse_lowercases_type_and_subtype() {
	m := parse('TEXT/HTML')
	assert m.type_() == 'text'
	assert m.subtype() == 'html'
}

fn test_parse_trims_http_whitespace() {
	m := parse('  \t text/plain \r\n ')
	assert m.essence() == 'text/plain'
}

fn test_parse_parameters() {
	m := parse('text/html;charset=utf-8')
	params := m.parameters()
	assert params['charset'] == 'utf-8'
}

fn test_parse_parameter_name_lowercased_value_preserved() {
	m := parse('text/html; CharSet=UTF-8')
	params := m.parameters()
	// Parameter name is lowercased; value keeps its case.
	assert params['charset'] == 'UTF-8'
}

fn test_parse_quoted_parameter_value() {
	m := parse('application/json; foo="bar;baz"')
	params := m.parameters()
	// The ";" inside the quoted string is part of the value.
	assert params['foo'] == 'bar;baz'
}

fn test_parse_quoted_value_with_escapes() {
	m := parse(r'text/plain; x="a\"b\\c"')
	params := m.parameters()
	assert params['x'] == r'a"b\c'
}

fn test_parse_first_parameter_wins() {
	m := parse('text/html;a=1;a=2')
	assert m.parameters()['a'] == '1'
}

fn test_parse_empty_unquoted_value_is_skipped() {
	m := parse('text/html;a=;b=2')
	params := m.parameters()
	assert 'a' !in params
	assert params['b'] == '2'
}

fn test_parse_failures() {
	assert MimeType.parse('') == none
	assert MimeType.parse('noslash') == none
	// Empty subtype.
	assert MimeType.parse('text/') == none
	// Empty type.
	assert MimeType.parse('/html') == none
	// Non-token character in type.
	assert MimeType.parse('te xt/html') == none
}

fn test_parse_rejects_non_scalar_and_non_canonical_utf8() {
	assert MimeType.parse([u8(0xc0), 0xaf].bytestr()) == none
	assert MimeType.parse([u8(0xed), 0xa0, 0x80].bytestr()) == none
	assert MimeType.parse([u8(0xf4), 0x90, 0x80, 0x80].bytestr()) == none
	assert MimeType.parse([u8(0xf5), 0x80, 0x80, 0x80].bytestr()) == none
}

fn test_serialized_round_trip() {
	m := parse('text/html;charset=utf-8')
	assert m.serialized() == 'text/html;charset=utf-8'
}

fn test_serialized_quotes_values_needing_it() {
	mut m := MimeType.create('text', 'plain')
	m.set_parameter('x', 'a b')
	// A value with a space is not solely token code points, so it is quoted.
	assert m.serialized() == 'text/plain;x="a b"'
}

fn test_serialized_escapes_quotes_and_backslashes() {
	mut m := MimeType.create('text', 'plain')
	m.set_parameter('x', 'a"b\\c')
	assert m.serialized() == r'text/plain;x="a\"b\\c"'
}

fn test_type_predicates() {
	assert parse('image/png').is_image()
	assert parse('audio/mpeg').is_audio_or_video()
	assert parse('video/mp4').is_audio_or_video()
	assert parse('application/ogg').is_audio_or_video()
	assert parse('font/woff2').is_font()
	assert parse('application/vnd.ms-fontobject').is_font()
	assert parse('application/epub+zip').is_zip_based()
	assert parse('application/zip').is_archive()
	assert parse('image/svg+xml').is_xml()
	assert parse('text/xml').is_xml()
	assert parse('text/html').is_html()
	assert parse('application/json').is_json()
	assert parse('application/ld+json').is_json()
	assert parse('text/javascript').is_javascript()
	assert parse('application/pdf').is_scriptable()
	assert parse('text/html').is_scriptable()
}

fn test_negative_predicates() {
	m := parse('text/plain')
	assert !m.is_image()
	assert !m.is_audio_or_video()
	assert !m.is_font()
	assert !m.is_xml()
	assert !m.is_html()
	assert !m.is_json()
	assert !m.is_javascript()
	assert !m.is_scriptable()
}

fn test_is_javascript_mime_type_essence_match() {
	assert is_javascript_mime_type_essence_match('text/javascript')
	assert is_javascript_mime_type_essence_match('Text/JavaScript')
	assert is_javascript_mime_type_essence_match('application/ecmascript')
	assert !is_javascript_mime_type_essence_match('text/plain')
}

fn test_minimise_a_supported_mime_type() {
	assert minimise_a_supported_mime_type(parse('application/x-javascript')) == 'text/javascript'
	assert minimise_a_supported_mime_type(parse('application/ld+json')) == 'application/json'
	assert minimise_a_supported_mime_type(parse('image/svg+xml')) == 'image/svg+xml'
	assert minimise_a_supported_mime_type(parse('application/rss+xml')) == 'application/xml'
	assert minimise_a_supported_mime_type(parse('image/png')) == ''
}
