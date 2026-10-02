module xhr

import dom
import html

fn test_document_request_uses_actual_html_serialization_and_source_content_type() {
	document := html.parse_document('<p>µ &amp; text</p>')
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('POST', '/document', true, none, none)!
	request.send_document(document)!
	assert request.request_body.bytestr() == document.as_node().serialize_fragment(.no, .inner)!
	assert request.request_body.bytestr().contains('<p>µ &amp; text</p>')
	assert request.author_request_headers == [ResponseHeader{ name: 'Content-Type', value: 'text/html;charset=UTF-8' }]
}

fn test_document_request_rewrites_author_charset_and_get_discards_the_document() {
	document := html.parse_document('<p>actual document</p>')
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('POST', '/document', true, none, none)!
	request.set_request_header('Content-Type', 'application/custom;charset=windows-1252')!
	request.send_document(document)!
	assert request.author_request_headers[0].value == 'application/custom;charset=UTF-8'
	mut get := XMLHttpRequest.construct(.window, 'https://example.test/')
	get.open('GET', '/document', true, none, none)!
	get.send_document(document)!
	assert !get.request_body_present && get.request_body.len == 0
	assert get.author_request_headers.len == 0
}

fn test_document_request_checks_source_state_before_serializing() {
	document := dom.Document.create(dom.url_about_blank())
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	if _ := request.send_document(document) { assert false }
	else { assert err.msg().starts_with('InvalidStateError:') }
}

fn test_document_request_uses_actual_xml_serializer_and_xml_content_type() {
	owner := dom.Document.create(dom.url_about_blank())
	parser := html.DOMParser.create(owner)
	document := parser.parse_from_string('<root xmlns="urn:request"><child>µ</child></root>', .application_xml)!
	mut request := XMLHttpRequest.construct(.window, 'https://example.test/')
	request.open('POST', '/xml', true, none, none)!
	request.send_document(document)!
	assert request.request_body.bytestr() == document.as_node().serialize_fragment(.no, .inner)!
	assert request.request_body.bytestr().contains('xmlns="urn:request"')
	assert request.author_request_headers[0].value == 'application/xml;charset=UTF-8'
}
