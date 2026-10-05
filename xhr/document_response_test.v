module xhr

import dom

fn parsed_xhr_response(type_ ResponseType, content_type string, bytes []u8, null_body bool) &XMLHttpRequest {
	global := &XMLHttpRequestGlobal{
		kind:     .window
		base_url: 'https://source.test/page'
		origin:   dom.URL{value: 'https://source.test/'}.origin()
	}
	mut request := XMLHttpRequest.create(global)
	request.open('GET', 'https://response.test/data', true, none, none) or { panic(err) }
	request.set_response_type(type_) or { panic(err) }
	request.send() or { panic(err) }
	request.receive_headers(MockResponse{
		url:          'https://response.test/data'
		status:       200
		headers:      [ResponseHeader{ name: 'Content-Type', value: content_type }]
		body:         bytes
		body_is_null: null_body
	}) or { panic(err) }
	request.complete_response() or { panic(err) }
	return request
}

fn test_xhr_html_response_is_real_dom_with_response_url_encoding_and_client_origin() {
	mut bytes := '<p id="answer">'.bytes()
	bytes << u8(0x80)
	bytes << '</p><script>throw 1</script>'.bytes()
	mut request := parsed_xhr_response(.document, 'text/html;charset=windows-1252', bytes, false)
	first := request.response().document?
	assert first.document_type() == .html
	assert first.url.serialize() == 'https://response.test/data'
	assert first.origin().serialize() == 'https://source.test'
	assert first.get_encoding()? == 'windows-1252'
	assert first.content_type == 'text/html;charset=windows-1252'
	assert first.get_element_by_id('answer')?.as_node().text_content()? == '€'
	assert request.response().document? == first
	assert request.response_xml()!.document? == first
}

fn test_xhr_html_prescan_encoding_and_empty_present_body() {
	mut bytes := '<meta charset="windows-1252"><p>'.bytes()
	bytes << u8(0x80)
	bytes << '</p>'.bytes()
	mut request := parsed_xhr_response(.document, 'text/html', bytes, false)
	result := request.response().document?
	assert result.get_encoding()? == 'windows-1252'
	assert result.body()?.as_node().text_content()? == '€'
	mut empty := parsed_xhr_response(.document, 'text/html', []u8{}, false)
	assert !empty.response_body_is_null()
	assert empty.response().document?.document_element() != none
	mut absent := parsed_xhr_response(.document, 'text/html', []u8{}, true)
	assert absent.response_body_is_null()
	assert absent.response().document == none
}

fn test_xhr_xml_response_parses_namespaces_and_rejects_malformed_document() {
	mut request := parsed_xhr_response(.document, 'application/xml',
		'<root xmlns="urn:root"><item>text</item></root>'.bytes(), false)
	parsed := request.response_xml()!.document?
	assert parsed.document_type() == .xml
	assert parsed.document_element()?.namespace_uri()? == 'urn:root'
	assert parsed.document_element()?.as_node().text_content()? == 'text'
	assert request.response().document? == parsed
	for source in ['<root>', '<a/><b/>', '<undeclared:root/>', ''] {
		mut invalid := parsed_xhr_response(.document, 'application/xml', source.bytes(), false)
		assert invalid.response_xml()!.document == none
		assert invalid.response().document == none
	}
}

fn test_default_xml_response_text_and_response_xml_share_the_proper_kinds() {
	mut request := parsed_xhr_response(.empty, 'application/xml', '<root/>'.bytes(), false)
	assert request.response().text == '<root/>'
	parsed := request.response_xml()!.document?
	assert parsed.document_element()?.local_name() == 'root'
	assert request.response().text == '<root/>'
	assert request.response_xml()!.document? == parsed
	mut html_text := parsed_xhr_response(.empty, 'text/html', '<p>x</p>'.bytes(), false)
	assert html_text.response_xml()!.document == none
}
