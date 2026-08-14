module fetch

import http

fn h(name string, value string) http.Header {
	return http.Header{name, value}
}

fn test_cors_unsafe_request_header_byte() {
	assert is_cors_unsafe_request_header_byte(0x00) == true
	assert is_cors_unsafe_request_header_byte(0x09) == false // HT is allowed
	assert is_cors_unsafe_request_header_byte(0x22) == true // "
	assert is_cors_unsafe_request_header_byte(0x7F) == true // DEL
	assert is_cors_unsafe_request_header_byte(`A`) == false
}

fn test_parse_single_range() {
	full := parse_single_range_header_value('bytes=0-100', false)?
	assert full.start? == u64(0)
	assert full.end? == u64(100)
	// Suffix range: no start.
	suffix := parse_single_range_header_value('bytes=-500', false)?
	assert suffix.start == none
	assert suffix.end? == u64(500)
	// Open-ended: no end.
	open := parse_single_range_header_value('bytes=5-', false)?
	assert open.start? == u64(5)
	assert open.end == none
	// start > end, missing "bytes", and non-numeric all fail.
	assert parse_single_range_header_value('bytes=100-50', false) == none
	assert parse_single_range_header_value('items=0-1', false) == none
	assert parse_single_range_header_value('bytes=abc', false) == none
}

fn test_cors_safelisted_request_header() {
	// accept / accept-language / content-language.
	assert is_cors_safelisted_request_header(h('Accept', 'text/html')) == true
	assert is_cors_safelisted_request_header(h('Accept', 'text/(html)')) == false // "(" is unsafe
	assert is_cors_safelisted_request_header(h('Accept-Language', 'en-US, fr')) == true
	assert is_cors_safelisted_request_header(h('Content-Language', 'en/US')) == false // "/" not allowed

	// content-type: only the three form-submission essences.
	assert is_cors_safelisted_request_header(h('Content-Type', 'text/plain')) == true
	assert is_cors_safelisted_request_header(h('Content-Type', 'multipart/form-data')) == true
	assert is_cors_safelisted_request_header(h('Content-Type', 'application/json')) == false

	// range: a present range-start is required.
	assert is_cors_safelisted_request_header(h('Range', 'bytes=0-100')) == true
	assert is_cors_safelisted_request_header(h('Range', 'bytes=-500')) == false

	// A value longer than 128 bytes, and an unlisted header name, are not safelisted.
	assert is_cors_safelisted_request_header(h('Accept', 'a'.repeat(129))) == false
	assert is_cors_safelisted_request_header(h('X-Custom', 'x')) == false
}

fn test_header_name_predicates() {
	assert is_cors_non_wildcard_request_header_name('authorization') == true
	assert is_cors_non_wildcard_request_header_name('X-Auth') == false
	assert is_privileged_no_cors_request_header_name('Range') == true
	assert is_no_cors_safelisted_request_header_name('Accept-Language') == true
	assert is_no_cors_safelisted_request_header_name('X-Custom') == false
}

fn test_cors_safelisted_response_header_name() {
	assert is_cors_safelisted_response_header_name('Content-Type', []) == true
	assert is_cors_safelisted_response_header_name('X-Exposed', ['X-Exposed']) == true
	// Set-Cookie is a forbidden response-header name, so it is never safelisted.
	assert is_cors_safelisted_response_header_name('Set-Cookie', ['Set-Cookie']) == false
	assert is_cors_safelisted_response_header_name('X-Other', ['X-Exposed']) == false
}

fn test_no_cors_safelisted_request_header() {
	assert is_no_cors_safelisted_request_header(h('Accept', 'text/html')) == true
	// A no-CORS-safelisted name but a value that is not CORS-safelisted.
	assert is_no_cors_safelisted_request_header(h('Content-Type', 'application/json')) == false
	// A name that is not no-CORS-safelisted.
	assert is_no_cors_safelisted_request_header(h('X-Custom', 'x')) == false
}

fn test_convert_and_get_cors_unsafe_header_names() {
	assert convert_header_names_to_a_sorted_lowercase_set(['Z', 'a', 'A']) == ['a', 'z']
	mut list := http.HeaderList.create()
	list.append(h('Accept', 'text/html')) // safelisted
	list.append(h('X-Custom', 'value')) // unsafe
	assert get_cors_unsafe_header_names(list) == ['x-custom']
}
