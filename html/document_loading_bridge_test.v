module html

import dom
import css

fn loading_navigation_params(associated &dom.Document, mime_type string, body []u8) &dom.NavigationParams {
	return &dom.NavigationParams{
		response_mime_type:         mime_type
		response_body:              body
		response_url:               dom.URL{ value: 'https://example.test/resource' }
		html_fragment_parsing_hook: associated.html_fragment_parsing_hook()
	}
}

fn test_document_loader_uses_translated_html_parser_and_encoding_detection() {
	associated := parse_document('<!doctype html>')
	body := '<!doctype html><title>Loaded</title><p id="content">Привет</p>'.bytes()
	params := loading_navigation_params(associated, 'text/html;charset=utf-8', body)
	mut document := dom.load_document(params, body) or { panic('HTML load failed') }
	assert document.has_deferred_parser_start()
	assert document.document_element() == none
	document.set_ready_to_run_scripts()
	assert !document.has_deferred_parser_start()
	assert document.document_type() == .html
	assert document.title() == 'Loaded'
	assert document.get_element_by_id('content')?.as_node().text_content()? == 'Привет'
}

fn test_document_loader_uses_vlib_xml_and_mime_parameters() {
	associated := parse_document('<!doctype html>')
	body := '<?xml version="1.0"?><root xmlns="urn:test"><item>A &amp; B</item></root>'.bytes()
	params := loading_navigation_params(associated, 'application/xml;charset=utf-8', body)
	mut document := dom.load_document(params, body) or { panic('XML load failed') }
	assert document.has_deferred_parser_start()
	document.set_ready_to_run_scripts()
	root := document.document_element() or { panic('missing XML root') }
	assert document.document_type() == .xml
	assert root.local_name() == 'root'
	assert root.namespace_uri()? == 'urn:test'
	assert root.as_node().text_content()? == 'A & B'
}

fn test_document_loader_uses_translated_plaintext_tokenizer_sequence() {
	associated := parse_document('<!doctype html>')
	body := 'literal <b>markup</b>'.bytes()
	params := loading_navigation_params(associated, 'text/plain;charset=utf-8', body)
	mut document := dom.load_document(params, body) or { panic('text load failed') }
	assert document.has_deferred_parser_start()
	document.set_ready_to_run_scripts()
	pre := document.get_elements_by_tag_name('pre').item(0) or { panic('missing pre') }
	assert pre.as_node().text_content()? == 'literal <b>markup</b>'
	assert document.get_elements_by_tag_name('b').length() == 0
}

// Ladybird d3a9bd05d525ef32df935d28a027229e4dd86ec6.
fn test_plaintext_document_wraps_lines_and_follows_color_scheme_despite_response_csp() {
	associated := parse_document('<!doctype html>')
	body := 'a'.repeat(500).bytes()
	mut document := dom.load_document(loading_navigation_params(associated, 'text/plain', body), body)?
	document.set_policy_container(&dom.PolicyContainer{
		csp_list: [parse_response_csp_policy("style-src 'none'", .enforce, document.origin())]
	})
	document.set_ready_to_run_scripts()
	pre := document.get_elements_by_tag_name('pre').item(0)?
	assert pre.get_attribute('style') == none
	assert pre.el_inline_style()?.declarations_text == 'word-wrap: break-word; white-space: pre-wrap;'
	assert !pre.el_inline_style()?.awaits_content_security_policy_check
	meta := document.get_elements_by_tag_name('meta').item(0)?
	assert meta.get_attribute_value('name') == 'color-scheme'
	assert meta.get_attribute_value('content') == 'light dark'
	assert pre.as_node().text_content()? == body.bytestr()
}

// Ladybird 9344a9b90ae74072ea207a0cc2139901e0a80fb7.
fn test_standalone_image_uses_a_light_gray_backdrop() {
	associated := parse_document('<!doctype html>')
	body := [u8(0x89), `P`, `N`, `G`, 0x0d, 0x0a, 0x1a, 0x0a]
	mut document := dom.load_document(loading_navigation_params(associated, 'image/png', body), body)?
	image := document.get_elements_by_tag_name('img').item(0)?
	computer := css.StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(image, none))
	assert (computed.property(.background_color, .no) or { panic('background') }).css_text == 'rgb(230, 230, 230)'
}

fn test_document_loader_uses_translated_mime_sniffing() {
	associated := parse_document('<!doctype html>')
	body := [u8(0x89), `P`, `N`, `G`, 0x0d, 0x0a, 0x1a, 0x0a]
	params := loading_navigation_params(associated, 'application/unknown', body)
	mut document := dom.load_document(params, body) or { panic('sniffed image load failed') }
	assert document.content_type == 'image/png'
	assert document.get_elements_by_tag_name('img').length() == 1
}

struct PDFEventObservation {
mut:
	count    int
	response ?&dom.InlinePDFResponse
}

fn test_document_loader_uses_bundled_pdf_viewer_and_delivers_response() {
	associated := parse_document('<!doctype html>')
	body := '%PDF-1.4\n% translated fixture'.bytes()
	params := loading_navigation_params(associated, 'application/pdf', body)
	mut document := dom.load_document(params, body) or { panic('PDF load failed') }

	assert document.document_type() == .html
	assert document.content_type == 'text/html'
	assert document.url_string() == 'https://example.test/resource'
	assert document.origin().serialize() == 'resource://'
	assert document.has_deferred_parser_start()
	assert document.document_element() == none

	document.set_ready_to_run_scripts()
	assert !document.has_deferred_parser_start()
	assert document.title() == 'PDF.js viewer'
	assert document.get_element_by_id('outerContainer') != none
	assert document.get_element_by_id('printContainer') != none

	mut observation := &PDFEventObservation{}
	observation_pointer := voidptr(observation)
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation_pointer] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &PDFEventObservation(observation_pointer) }
			custom_event := unsafe { &dom.CustomEvent(event) }
			observation.count++
			observation.response = dom.inline_pdf_response_from_js_value(custom_event.detail())
			return dom.js_undefined()
		}
	})
	unsafe { &dom.EventTarget(&document.ParentNode.Node) }.add_event_listener_without_options('ladybirdpdf', listener)
	document.dispatch_event_simple('ladybirdviewerready', false)

	assert observation.count == 1
	response := observation.response or { panic('missing inline PDF response detail') }
	assert response.url.serialize() == 'https://example.test/resource'
	assert response.mime_type == 'application/pdf'
	assert response.body == body
}

fn test_document_loader_accepts_legacy_text_pdf_type() {
	associated := parse_document('<!doctype html>')
	body := '%PDF-1.4\n'.bytes()
	params := loading_navigation_params(associated, 'text/pdf', body)
	document := dom.load_document(params, body) or { panic('text/pdf load failed') }
	assert document.content_type == 'text/html'
	assert document.has_deferred_parser_start()
}
