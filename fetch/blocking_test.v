module fetch

import http

fn response_with(name string, value string) &Response {
	mut response := Response.create()
	response.header_list.append(http.Header{name, value})
	return response
}

fn request_with_destination(destination Destination) &Request {
	mut request := Request.create()
	request.destination = destination
	return request
}

fn test_extract_mime_type() {
	response := response_with('Content-Type', 'text/html; charset=utf-8')
	mime := extract_mime_type(response.header_list) or { panic('expected a MIME type') }
	assert mime.essence() == 'text/html'
	assert mime.parameters()['charset'] == 'utf-8'
	// No Content-Type header → failure.
	assert extract_mime_type(Response.create().header_list) == none
}

fn test_extract_mime_type_carries_charset_forward() {
	// A later same-essence value without a charset inherits the earlier charset.
	mut response := Response.create()
	response.header_list.append(http.Header{'Content-Type', 'text/html;charset=utf-8'})
	response.header_list.append(http.Header{'Content-Type', 'text/html'})
	mime := extract_mime_type(response.header_list)?
	assert mime.parameters()['charset'] == 'utf-8'
}

fn test_determine_nosniff() {
	assert determine_nosniff(response_with('X-Content-Type-Options', 'nosniff').header_list) == true
	assert determine_nosniff(response_with('X-Content-Type-Options', 'NoSniff').header_list) == true
	assert determine_nosniff(response_with('X-Content-Type-Options', 'other').header_list) == false
	assert determine_nosniff(Response.create().header_list) == false
}

fn test_block_due_to_nosniff() {
	script := request_with_destination(.script)
	// nosniff + script destination + non-JS MIME → blocked.
	mut bad := response_with('X-Content-Type-Options', 'nosniff')
	bad.header_list.append(http.Header{'Content-Type', 'text/plain'})
	assert should_response_to_request_be_blocked_due_to_nosniff(bad, script) == .blocked

	// nosniff + script destination + JavaScript MIME → allowed.
	mut good := response_with('X-Content-Type-Options', 'nosniff')
	good.header_list.append(http.Header{'Content-Type', 'text/javascript'})
	assert should_response_to_request_be_blocked_due_to_nosniff(good, script) == .allowed

	// nosniff + style destination + non-CSS → blocked.
	style := request_with_destination(.style)
	assert should_response_to_request_be_blocked_due_to_nosniff(bad, style) == .blocked

	// No nosniff → allowed regardless.
	no_header := request_with_destination(.script)
	assert should_response_to_request_be_blocked_due_to_nosniff(response_with('Content-Type',
		'text/plain'), no_header) == .allowed
}

fn test_block_due_to_mime_type() {
	script := request_with_destination(.script)
	// Script destination served image/audio/video/csv → blocked.
	assert should_response_to_request_be_blocked_due_to_its_mime_type(response_with('Content-Type',
		'image/png'), script) == .blocked
	assert should_response_to_request_be_blocked_due_to_its_mime_type(response_with('Content-Type',
		'text/csv'), script) == .blocked
	// Script destination served JavaScript → allowed.
	assert should_response_to_request_be_blocked_due_to_its_mime_type(response_with('Content-Type',
		'text/javascript'), script) == .allowed
	// A non-script destination is never blocked here.
	image := request_with_destination(.image)
	assert should_response_to_request_be_blocked_due_to_its_mime_type(response_with('Content-Type',
		'image/png'), image) == .allowed
}
