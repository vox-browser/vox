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
