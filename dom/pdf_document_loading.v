// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the inline-PDF path in Libraries/LibWeb/DOM/DocumentLoading.cpp.
module dom

import platform

// PDF.js 5.6.205 web/viewer.html, matching Ladybird's pinned vcpkg port.
const bundled_pdf_viewer_source = platform.embedded_text($embed_file('resources/pdfjs/viewer.html'))

// The JavaScript Fetch::Response handed to pdf.js upstream owns the response URL,
// MIME type, and body. This dependency-cycle-safe host object preserves the same
// payload at the DOM/JavaScript boundary used by the V runtime.
@[heap]
pub struct InlinePDFResponse {
pub:
	url       URL
	mime_type string
	body      []u8
}

pub fn inline_pdf_response_from_js_value(value JSValue) ?&InlinePDFResponse {
	if value.kind != .object || value.object_data == unsafe { nil } {
		return none
	}
	return unsafe { &InlinePDFResponse(value.object_data) }
}

fn dispatch_inline_pdf_response(document &Document, response &InlinePDFResponse) {
	event := CustomEvent.create('ladybirdpdf', CustomEventInit{
		detail: js_object(response)
	})
	base_event := unsafe { &Event(event) }
	unsafe { &Node(document) }.dispatch_event(base_event)
}

fn parse_bundled_pdf_viewer(document &Document, pdf_url URL) {
	html_parser_run_with_uncertain_encoding(document, bundled_pdf_viewer_source.bytes(), mime_type_from_essence('text/html'), pdf_url)
}

// Renders the PDF using the bundled pdf.js viewer at an internal resource:// URL.
fn load_pdf_document(navigation_params &NavigationParams) !&Document {
	pdf_url := navigation_response_url(navigation_params)
	mut document := Document.create_and_initialize(.html, 'text/html', navigation_params)!
	document.set_origin(origin_from_tuple('resource', '', none))

	response := &InlinePDFResponse{
		url: pdf_url
		mime_type: navigation_params.response_mime_type
		body: navigation_params.response_body.clone()
	}
	document_pointer := voidptr(document)
	response_pointer := voidptr(response)
	callback := &CallbackType{
		handle_event: fn [document_pointer, response_pointer] (_ &Event, _ ?&EventTarget) JSValue {
			document := unsafe { &Document(document_pointer) }
			response := unsafe { &InlinePDFResponse(response_pointer) }
			dispatch_inline_pdf_response(document, response)
			return js_undefined()
		}
	}
	unsafe { &EventTarget(&document.ParentNode.Node) }.add_event_listener_without_options('ladybirdviewerready', IDLEventListener.create(callback))

	if document.document_ready_to_run_scripts() {
		parse_bundled_pdf_viewer(document, pdf_url)
	} else {
		document.set_deferred_parser_start(fn [document_pointer, pdf_url] () {
			document := unsafe { &Document(document_pointer) }
			parse_bundled_pdf_viewer(document, pdf_url)
		})
	}

	return document
}
