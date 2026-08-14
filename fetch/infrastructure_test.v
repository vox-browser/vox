module fetch

import dom

fn data_url(value string) dom.URL {
	return dom.URL{
		value: value
	}
}

fn test_scheme_predicates() {
	assert is_http_or_https_scheme('http') == true
	assert is_http_or_https_scheme('https') == true
	assert is_http_or_https_scheme('ftp') == false
	assert is_fetch_scheme('about') == true
	assert is_fetch_scheme('file') == true
	assert is_fetch_scheme('resource') == true
	assert is_fetch_scheme('ftp') == false
	assert is_local_url(data_url('about:blank')) == true
	assert is_local_url(data_url('blob:xyz')) == true
	assert is_local_url(data_url('https://example.com')) == false
}

fn test_status_predicates() {
	assert is_ok_status(200) == true
	assert is_ok_status(299) == true
	assert is_ok_status(300) == false
	assert is_null_body_status(204) == true
	assert is_null_body_status(304) == true
	assert is_null_body_status(200) == false
	assert is_redirect_status(301) == true
	assert is_redirect_status(308) == true
	assert is_redirect_status(200) == false
}

fn test_bad_port() {
	assert is_bad_port(22) == true // ssh
	assert is_bad_port(6667) == true // irc
	assert is_bad_port(10080) == true
	assert is_bad_port(80) == false
	assert is_bad_port(8080) == false
	// block-bad-port reads the request's current URL; only HTTP(S) on a bad port is blocked.
	assert block_bad_port(request_for('http://example.com:22/')) == .blocked
	assert block_bad_port(request_for('http://example.com:8080/')) == .allowed
	// Non-HTTP schemes are not blocked even on a bad port.
	assert block_bad_port(request_for('ftp://example.com:22/')) == .allowed
}

fn request_for(url string) &Request {
	mut request := Request.create()
	request.url_list << dom.URL{
		value: url
	}
	return request
}

fn test_process_data_url_plain() {
	result := process_data_url(data_url('data:text/plain,Hello%20World'))!
	assert result.mime_type.essence() == 'text/plain'
	assert result.body.bytestr() == 'Hello World'
}

fn test_process_data_url_base64() {
	// "Hello" base64-encoded is "SGVsbG8=".
	result := process_data_url(data_url('data:text/plain;base64,SGVsbG8='))!
	assert result.mime_type.essence() == 'text/plain'
	assert result.body.bytestr() == 'Hello'
}

fn test_process_data_url_html() {
	result := process_data_url(data_url('data:text/html,<b>hi</b>'))!
	assert result.mime_type.essence() == 'text/html'
	assert result.body.bytestr() == '<b>hi</b>'
}

fn test_process_data_url_default_mime_type() {
	// An empty MIME type falls back to text/plain;charset=US-ASCII.
	result := process_data_url(data_url('data:,just text'))!
	assert result.mime_type.essence() == 'text/plain'
	assert result.mime_type.parameters()['charset'] == 'US-ASCII'
	assert result.body.bytestr() == 'just text'
}

fn test_process_data_url_missing_comma_fails() {
	if _ := process_data_url(data_url('data:text/plain')) {
		assert false, 'expected failure for missing comma'
	}
}
