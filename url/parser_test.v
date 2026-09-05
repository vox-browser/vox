module url

fn test_basic_url_parser_special_components_and_idna() {
	record := parse('https://user:pass@faß.de:443/a/../b?q=x y#f z') or {
		panic('URL parse failed')
	}
	assert record.scheme == 'https'
	assert record.username == 'user'
	assert record.password == 'pass'
	assert record.host?.serialize() == 'xn--fa-hia.de'
	assert record.port == none
	assert record.paths == ['b']
	assert record.query? == 'q=x%20y'
	assert record.fragment? == 'f%20z'
	assert record.serialize(false) == 'https://user:pass@xn--fa-hia.de/b?q=x%20y#f%20z'
}

fn test_basic_url_parser_relative_resolution_and_dot_segments() {
	base := parse('https://example.com/a/b/c?old#fragment') or { panic('base parse failed') }
	resolved := parse_with_base('../d/./e?new', base) or { panic('relative parse failed') }
	assert resolved.serialize(false) == 'https://example.com/a/d/e?new'
	query := parse_with_base('?replacement', base) or { panic('query parse failed') }
	assert query.serialize(false) == 'https://example.com/a/b/c?replacement'
	fragment := parse_with_base('#new', base) or { panic('fragment parse failed') }
	assert fragment.serialize(false) == 'https://example.com/a/b/c?old#new'
}

fn test_basic_url_parser_ipv4_ipv6_file_and_opaque_urls() {
	ipv4 := parse('http://0x7f.1/') or { panic('IPv4 parse failed') }
	assert ipv4.serialize(false) == 'http://127.0.0.1/'
	ipv6 := parse('http://[2001:db8::1]:80/x') or { panic('IPv6 parse failed') }
	assert ipv6.serialize(false) == 'http://[2001:db8::1]/x'
	file := parse('file:///C|/a/../b') or { panic('file parse failed') }
	assert file.serialize(false) == 'file:///C:/b'
	opaque := parse('mailto:user@example.com?q=a b#x y') or { panic('opaque parse failed') }
	assert opaque.has_an_opaque_path
	assert opaque.serialize(false) == 'mailto:user@example.com?q=a%20b#x%20y'
}

fn test_url_parser_setter_state_semantics() {
	record := parse('https://example.com/a') or { panic('parse failed') }
	assert record.with_scheme('http:').serialize(false) == 'http://example.com/a'
	assert record.with_username('a b').serialize(false) == 'https://a%20b@example.com/a'
	assert record.with_password('p@ss').serialize(false) == 'https://:p%40ss@example.com/a'
	assert record.with_host('測試:8443', false).serialize(false) == 'https://xn--g6w251d:8443/a'
	assert record.with_host('0x7f.1', true).serialize(false) == 'https://127.0.0.1/a'
	assert record.with_port('443').port == none
	assert record.with_path('/x/../y').serialize(false) == 'https://example.com/y'
	assert record.with_query('a b').query? == 'a%20b'
	assert record.with_fragment('x y').fragment? == 'x%20y'
}

fn test_url_parser_setters_use_state_override_rules() {
	record := parse('https://old.example:99/original?old#fragment') or { panic('parse failed') }
	assert record.with_path('/question?mark#hash').serialize(false) ==
		'https://old.example:99/question%3Fmark%23hash?old#fragment'
	assert record.with_path('').serialize(false) == 'https://old.example:99/?old#fragment'
	assert record.with_host('new.example:8080/trailing', false).serialize(false) ==
		'https://new.example:8080/original?old#fragment'
	assert record.with_host('new.example:', false).serialize(false) ==
		'https://new.example:99/original?old#fragment'
	assert record.with_host('user@new.example', false).serialize(false) == record.serialize(false)
	assert record.with_host('new.example:8080', true).serialize(false) == record.serialize(false)
	assert record.with_port('123garbage').port? == 123
	assert record.with_port('garbage').port? == 99

	file := parse('file://localhost/C:/one') or { panic('file parse failed') }
	assert file.with_host('localhost', false).serialize(false) == 'file:///C:/one'
	assert file.with_path('/D|/two?three').serialize(false) == 'file:///D:/two%3Fthree'
}

fn test_url_parser_rejects_invalid_authorities() {
	assert parse('https://') == none
	assert parse('https://example.com:99999/') == none
	assert parse('https://[2001:db8::1/') == none
	assert parse('1relative-without-base') == none
	assert parse('https://xn--a/') == none
}
