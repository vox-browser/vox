module xhr

fn completed_request(type_ ResponseType, content_type string, body string) &XMLHttpRequest {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('GET', '/value', true, none, none) or { panic(err) }
	request.set_response_type(type_) or { panic(err) }
	request.send() or { panic(err) }
	request.receive_headers(MockResponse{
		url:     'https://example.test/value'
		status:  200
		headers: [ResponseHeader{ name: 'Content-Type', value: content_type }]
		body:    body.bytes()
	}) or { panic(err) }
	request.complete_response() or { panic(err) }
	return request
}

fn test_arraybuffer_blob_json_document_and_response_cache() {
	mut array := completed_request(.arraybuffer, 'application/octet-stream', 'abc')
	assert array.response().bytes == 'abc'.bytes()
	mut blob := completed_request(.blob, 'image/png', 'png')
	assert blob.response().blob?.type_() == 'image/png'
	mut json_request := completed_request(.json, 'application/json', '{"x":1}')
	assert json_request.response().json_text? == '{"x":1}'
	mut invalid_json := completed_request(.json, 'application/json', '{')
	assert invalid_json.response().json_text == none
	mut document := completed_request(.document, 'text/html', '<p>x</p>')
	assert document.response().document_text? == '<p>x</p>'
}

fn test_response_type_mime_and_synchronous_window_restrictions() {
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.set_timeout(10)!
	assert request.timeout() == 10
	if _ := request.open('GET', '/x', false, none, none) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidAccessError:')
	}
	mut worker := XMLHttpRequest.construct(.worker, 'https://example.test/')
	worker.set_response_type(.document)!
	assert worker.response_type() == .empty
	request = XMLHttpRequest.construct(.window, 'https://example.test/')
	request.override_mime_type('invalid')!
	assert request.override_mime_type_? == 'application/octet-stream'
}

fn test_blob_retains_serialized_mime_parameters_and_response_xml_rules() {
	mut blob := completed_request(.blob, 'Text/Plain; Charset=iso-8859-1', 'hello')
	assert blob.response().blob?.type_() == 'text/plain;charset=iso-8859-1'
	mut xml := completed_request(.document, 'application/xml', '<x/>')
	assert xml.response_xml()!.document_text? == '<x/>'
	mut html_as_text := completed_request(.empty, 'text/html', '<p>x</p>')
	assert html_as_text.response_xml()!.document_text == none
	mut wrong_type := completed_request(.json, 'application/json', '{}')
	if _ := wrong_type.response_xml() {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError:')
	}
}
