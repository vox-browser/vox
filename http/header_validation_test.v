module http

fn test_is_header_name() {
	assert is_header_name('Content-Type')
	assert is_header_name('X-Custom-Header')
	assert is_header_name('a')
	// Token punctuation is allowed.
	assert is_header_name("x!#\$%&'*+-.^_`|~")
	// Empty and non-token characters are rejected.
	assert !is_header_name('')
	assert !is_header_name('Content Type') // space
	assert !is_header_name('foo:bar') // colon
	assert !is_header_name('a\tb') // tab
}

fn test_is_header_value_accepts_valid() {
	// The empty value is valid, as are values without edge whitespace or control bytes.
	assert is_header_value('')
	assert is_header_value('text/html')
	assert is_header_value('a b c') // internal spaces are fine
	assert is_header_value('deflate, gzip')
}

fn test_is_header_value_rejects_edge_whitespace() {
	assert !is_header_value(' leading') // leading space
	assert !is_header_value('trailing ') // trailing space
	assert !is_header_value('\ttab-lead') // leading tab
	assert !is_header_value('tab-trail\t') // trailing tab
}

fn test_is_header_value_rejects_nul_and_newlines() {
	assert !is_header_value('has\x00nul')
	assert !is_header_value('has\nnewline')
	assert !is_header_value('has\rcr')
	// A trailing newline is rejected by the newline check (not the tab/space check).
	assert !is_header_value('value\n')
}

fn test_normalize_header_value() {
	assert normalize_header_value('  text/html  ') == 'text/html'
	assert normalize_header_value('\n\r\t value \t\r\n') == 'value'
	assert normalize_header_value('no-whitespace') == 'no-whitespace'
	assert normalize_header_value('') == ''
	// Internal whitespace is preserved.
	assert normalize_header_value('  a b  ') == 'a b'
}

fn test_forbidden_request_header_by_name() {
	// Matched case-insensitively against the forbidden request header names.
	assert is_forbidden_request_header(Header{ name: 'Host', value: 'example.com' })
	assert is_forbidden_request_header(Header{ name: 'HOST', value: 'x' })
	assert is_forbidden_request_header(Header{ name: 'accept-encoding', value: 'gzip' })
	assert is_forbidden_request_header(Header{ name: 'Content-Length', value: '5' })
	assert is_forbidden_request_header(Header{ name: 'Cookie', value: 'a=b' })
}

fn test_forbidden_request_header_by_prefix() {
	assert is_forbidden_request_header(Header{ name: 'Proxy-Authorization', value: 'x' })
	assert is_forbidden_request_header(Header{ name: 'Sec-Fetch-Mode', value: 'cors' })
	assert is_forbidden_request_header(Header{ name: 'proxy-anything', value: 'x' })
	assert is_forbidden_request_header(Header{ name: 'SEC-anything', value: 'x' })
}

fn test_not_forbidden_request_header() {
	assert !is_forbidden_request_header(Header{ name: 'Content-Type', value: 'text/html' })
	assert !is_forbidden_request_header(Header{ name: 'X-Custom', value: 'x' })
	// "Accept" is not forbidden even though "Accept-Charset"/"Accept-Encoding" are.
	assert !is_forbidden_request_header(Header{ name: 'Accept', value: '*/*' })
}

fn test_forbidden_request_header_method_override() {
	// A method-override header naming a forbidden method is forbidden.
	assert is_forbidden_request_header(Header{ name: 'X-HTTP-Method-Override', value: 'CONNECT' })
	assert is_forbidden_request_header(Header{ name: 'x-http-method', value: 'track' })
	assert is_forbidden_request_header(Header{ name: 'X-Method-Override', value: 'TRACE' })
	// A non-forbidden method is fine.
	assert !is_forbidden_request_header(Header{ name: 'X-HTTP-Method-Override', value: 'GET' })
	// One forbidden method among several comma-separated values still forbids it.
	assert is_forbidden_request_header(Header{ name: 'X-HTTP-Method-Override', value: 'GET, CONNECT' })
	assert !is_forbidden_request_header(Header{ name: 'X-HTTP-Method-Override', value: 'GET, POST' })
}
