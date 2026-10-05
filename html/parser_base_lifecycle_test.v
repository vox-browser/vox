module html

import dom
import fetch
import http
import page

@[heap]
struct SourceParserBaseObservation {
mut:
	violations        int
	interactive_bases []string
}

fn source_parser_base_document(owner &page.Page, address string) !(&dom.Document, &WindowModel) {
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(window) }
}

fn test_source_full_parser_checks_base_csp_once_through_actual_insertion() {
	owner := page.Page.create(1)!
	mut document, window := source_parser_base_document(owner, 'https://parser-base.test/root/page.html')!
	defer { document.finalize() }
	mut settings := window.environment_settings_.settings
	loop := EventLoop.create(.window)
	settings.responsible_event_loop_ = loop
	mut response := fetch.Response.create()
	response.url_list = [document.url]
	response.header_list.append(http.Header{ name: 'Content-Security-Policy', value: "base-uri 'none'" })
	settings.set_policy_container(create_a_policy_container_from_fetch_response(response))
	observation := &SourceParserBaseObservation{}
	target := unsafe { &dom.EventTarget(document) }
	target.add_event_listener_without_options('securitypolicyviolation', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [observation, document] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('actual violation target') }) == voidptr(document)
			assert event.is_trusted()
			mut observed := unsafe { &SourceParserBaseObservation(observation) }
			observed.violations++
			return dom.js_undefined()
		}
	}))
	parse_html_from_a_string(document, '<!doctype html><html><head><base href="https://foreign-base.test/"></head><body>real full parser</body></html>')
	assert document.base_url() == document.fallback_base_url()
	assert observation.violations == 0
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable() or { break }
		assert task.source() == .unspecified && task.document() == none
		task.execute()
	}
	assert observation.violations == 1
}

fn test_source_full_parser_retains_frozen_base_when_actual_readiness_handler_changes_document_url() {
	owner := page.Page.create(1)!
	mut document, window := source_parser_base_document(owner, 'https://parser-base.test/root/page.html')!
	defer { document.finalize() }
	observation := &SourceParserBaseObservation{}
	changed_url := dom.URL{value: 'https://parser-base.test/changed/document.html'}
	target := unsafe { &dom.EventTarget(document) }
	target.add_event_listener_without_options('readystatechange', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: document.get_window()?
		handle_event:      fn [observation, document, changed_url] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('actual readiness target') }) == voidptr(document)
			if document.readiness() == .interactive {
				mut observed := unsafe { &SourceParserBaseObservation(observation) }
				observed.interactive_bases << document.base_url().serialize()
				mut actual_document := unsafe { &dom.Document(document) }
				actual_document.set_url(changed_url)
			}
			return dom.js_undefined()
		}
	}))
	parse_html_from_a_string(document, '<!doctype html><html><head><base href="assets/"></head><body>real readiness event</body></html>')
	assert observation.interactive_bases == ['https://parser-base.test/root/assets/']
	assert document.url == changed_url
	assert document.base_url().serialize() == 'https://parser-base.test/root/assets/'
	assert document.encoding_parse_url('image.png')?.serialize() == 'https://parser-base.test/root/assets/image.png'
	assert voidptr(window.associated_document()) == voidptr(document)
	assert voidptr(document.page()) == voidptr(owner)
	mut base := unsafe { &dom.Element(document.first_base_element_with_href_in_tree_order()?) }
	base.set_attribute_value('href', 'next/')
	assert document.base_url().serialize() == 'https://parser-base.test/changed/next/'
}
