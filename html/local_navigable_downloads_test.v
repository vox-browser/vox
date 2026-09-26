@[has_globals]
module html

import dom
import fetch
import http
import page

__global (
	hyperlink_download_requests = []&fetch.Request{}
)

fn hyperlink_download_fetch(request &fetch.Request) !&fetch.Response {
	hyperlink_download_requests << request
	mut response := fetch.Response.create()
	response.url_list = request.url_list.clone()
	response.set_body_bytes('payload'.bytes())
	response.header_list.append(http.Header{
		name:  'Content-Disposition'
		value: 'attachment; filename="fallback.txt"; filename*=UTF-8\'\'server%20report.txt'
	})
	response.header_list.append(http.Header{
		name:  'Content-Length'
		value: '7'
	})
	return response
}

fn cancel_download_navigate_event(event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
	mut mutable_event := unsafe { &dom.Event(event) }
	mutable_event.prevent_default()
	return dom.js_undefined()
}

fn download_test_page() !(&dom.Document, &WindowModel, &NavigableModel, &page.Page) {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/start' })
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	page_model := page.Page.create(1.0)!
	document.set_page(unsafe { &dom.Page(page_model) })
	window := WindowModel.create_top_level(document, none, '')!
	host := document.navigable() or { return error('missing host navigable') }
	model := navigable_model_for_host(host) or { return error('missing navigable model') }
	return document, window, model, page_model
}

fn append_download_anchor(mut document dom.Document, href string, filename string) !&dom.Element {
	mut anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a')!
	anchor.set_attribute_value('href', href)
	anchor.set_attribute_value('download', filename)
	mut body := document.body() or { return error('missing body') }
	mut body_node := body.as_node()
	body_node.append_child(anchor.as_node())!
	return anchor
}

fn test_content_disposition_and_suggested_download_filename_follow_upstream_precedence() {
	parameters := split_content_disposition_parameters('attachment; filename="semi;colon.txt"; filename*=UTF-8\'\'new%20name.txt')
	assert parameters == ['attachment', 'filename="semi;colon.txt"', "filename*=UTF-8''new%20name.txt"]
	mut headers := http.HeaderList.create()
	headers.append(http.Header{
		name:  'Content-Disposition'
		value: 'attachment; filename="old.txt"; filename*=UTF-8\'\'new%20name.txt'
	})
	assert suggested_download_filename(dom.URL{ value: 'https://other.test/path/url.txt' },
		headers, 'author.txt', dom.URL{ value: 'https://example.test/' }.origin()) == 'new name.txt'

	mut inline_headers := http.HeaderList.create()
	inline_headers.append(http.Header{
		name:  'Content-Disposition'
		value: 'inline; filename="server.txt"'
	})
	assert suggested_download_filename(dom.URL{ value: 'https://example.test/path/url.txt' },
		inline_headers, 'author.txt', dom.URL{ value: 'https://example.test/' }.origin()) == 'server.txt'
	assert suggested_download_filename(dom.URL{ value: 'https://other.test/path/url.txt' },
		inline_headers, 'author.txt', dom.URL{ value: 'https://example.test/' }.origin()) == 'url.txt'
}

fn test_download_hyperlink_fetches_and_streams_the_response_to_the_page_client() {
	mut document, _, model_pointer, page_model := download_test_page()!
	mut model := unsafe { &NavigableModel(model_pointer) }
	model.set_navigation_fetch_hook(hyperlink_download_fetch)
	hyperlink_download_requests = []
	anchor := append_download_anchor(mut document, '/files/report.txt', 'author.txt')!

	html_element_click(unsafe { &dom.HTMLElement(anchor) })

	assert hyperlink_download_requests.len == 1
	request := hyperlink_download_requests[0]
	assert request.initiator? == .download
	assert request.use_url_credentials
	assert request.current_url().serialize() == 'https://example.test/files/report.txt'
	download := page_model.client().download(1) or { panic('missing download') }
	assert download.request.url == 'https://example.test/files/report.txt'
	assert download.request.suggested_filename == 'server report.txt'
	assert download.request.total_size? == u64(7)
	assert download.data == 'payload'.bytes()
	assert download.status == .finished
	assert download.controller_registered
	assert download.reader_registered
}

fn test_download_navigate_event_cancellation_and_sandboxing_stop_the_fetch() {
	mut canceled_document, canceled_window, canceled_model_pointer, canceled_page := download_test_page()!
	mut canceled_model := unsafe { &NavigableModel(canceled_model_pointer) }
	canceled_model.set_navigation_fetch_hook(hyperlink_download_fetch)
	mut navigation := unsafe { &Navigation(canceled_window.navigation()) }
	navigation.set_onnavigate(&dom.CallbackType{
		handle_event: cancel_download_navigate_event
	})
	hyperlink_download_requests = []
	canceled_anchor := append_download_anchor(mut canceled_document, '/canceled', 'canceled.txt')!
	html_element_click(unsafe { &dom.HTMLElement(canceled_anchor) })
	assert hyperlink_download_requests.len == 0
	assert canceled_page.client().download(1) == none

	mut sandboxed_document, _, sandboxed_model_pointer, sandboxed_page := download_test_page()!
	sandboxed_document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_downloads))
	mut sandboxed_model := unsafe { &NavigableModel(sandboxed_model_pointer) }
	sandboxed_model.set_navigation_fetch_hook(hyperlink_download_fetch)
	sandboxed_anchor := append_download_anchor(mut sandboxed_document, '/sandboxed', 'sandboxed.txt')!
	html_element_click(unsafe { &dom.HTMLElement(sandboxed_anchor) })
	assert hyperlink_download_requests.len == 0
	assert sandboxed_page.client().download(1) == none
}
