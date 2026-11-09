// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// XMLHttpRequest.cpp: set_document_response. Response documents are parsed once
// and cached so response/responseXML return the same DOM document identity.
module xhr

import dom
import encoding
import html

fn (mut request XMLHttpRequest) populate_document_response() {
	if cached := request.response_cache {
		if cached.document != none { return }
	}
	if request.response_body_is_null() { return }
	mime := request.get_final_mime_type()
	if !mime.is_html() && !mime.is_xml() { return }
	if request.response_type_ == .empty && mime.is_html() { return }
	response_url := dom.URL{ value: request.response_.url }
	mut charset := request.get_final_encoding()
	mut document := if mime.is_html() {
		dom.Document.create(response_url)
	} else {
		dom.XMLDocument.create(response_url).as_document()
	}
	if owner := request.global_object_.associated_document {
		document.set_page(owner.page())
	}
	if mime.is_html() {
		if charset == none {
			charset = html.run_prescan_byte_stream_algorithm(request.received_bytes)
		}
		encoding_name := charset or { 'UTF-8' }
		mut parser := html.HTMLParser.create_from_bytes(document, request.received_bytes,
			encoding_name) or { return }
		parser.scripting_mode = .disabled
		parser.run()
		document.set_document_type(.html)
	} else {
		// Upstream's current XML encoding step remains UTF-8. The shared XML parser
		// applies namespace well-formedness checks and returns failure instead of
		// constructing DOMParser's parsererror replacement document.
		decoder := encoding.TextDecoder.construct_impl('UTF-8', encoding.TextDecoderOptions{
			fatal: true
		}) or { return }
		source := decoder.decode(request.received_bytes, encoding.TextDecodeOptions{}) or { return }
		html.parse_xml_document(document, source) or {
			request.reset_response_object()
			return
		}
	}
	resolved_charset := charset or { 'UTF-8' }
	document.set_encoding(?string(resolved_charset))
	document.set_content_type(mime.serialized())
	document.set_url(response_url)
	document.set_origin(request.global_object_.origin or { dom.URL{ value: request.base_url }.origin() })
	request.response_cache = XHRResponse{
		type_:         .document
		document:      document
		document_text: request.get_text_response()
	}
}
