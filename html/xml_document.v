// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom

// parse_xml_document applies the browser's source and readiness lifecycle to
// the shared vlib XML parser. DOMParser and XML fragments use the source parser
// directly because they do not run this loading lifecycle.
pub fn parse_xml_document(document &dom.Document, source string) ! {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_source(source)
	mutable_document.set_document_type(.xml)
	mutable_document.update_readiness(.loading)
	parse_xml_document_source(document, source)!
	finish_xml_document_parsing(document)
}

// XML uses the HTML parser's asynchronous completion phases, so load delays
// started by DOMContentLoaded handlers are observed before load is queued.
pub fn finish_xml_document_parsing(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	if document.is_decoded_svg() {
		mutable_document.update_readiness(.interactive)
		mutable_document.update_readiness(.complete)
		return
	}
	if document.has_html_parser_end_state() {
		document.schedule_html_parser_end_check()
		return
	}
	HTMLParser.the_end(document, none)
}
