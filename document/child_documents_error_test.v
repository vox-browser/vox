module main

import dom
import fetch
import html
import http
import layout
import page
import platform
import time

@[heap]
struct ChildMissingResponseProbe {
mut:
	requests []&fetch.Request
	pending  []&fetch.PendingResponse
}

// Sealed site replays return an empty 410 for uncaptured frame URLs. Such a
// frame must finish without adopting the parent's document or resources.
fn test_browser_child_empty_http_error_keeps_parent_and_sibling_documents_distinct() {
	$if !darwin {
		return
	}
	address := 'https://missing.example/frame'
	owner := page.Page.create(1)!
	mut parent := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><title>Parent document</title><p id="parent">Parent content</p><iframe src="${address}"></iframe><iframe></iframe>',
		dom.URL{ value: 'http://parent.example/' }, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut host := browser_child_document_host(parent, .javascriptcore)
	defer {
		host.close()
		parent.destroy_a_document_and_its_descendants()
		parent.finalize()
		parent.release_native_storage()
	}
	mut messages := []string{}
	host.discover(parent, mut messages)
	assert host.children.len == 2, messages.join('\n')
	probe := &ChildMissingResponseProbe{}
	mut navigable := unsafe { &html.NavigableModel(host.children[0].navigable) }
	navigable.set_navigation_fetch_host(&fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response { panic('Blocking frame fetch used') }
		perform_async: fn [probe] (request &fetch.Request) &fetch.PendingResponse {
			mut state := unsafe { &ChildMissingResponseProbe(probe) }
			mut input := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut input, none)
			state.requests << request
			state.pending << pending
			return pending
		}
	})
	host.poll(mut messages)
	assert probe.requests.len == 1, messages.join('\n')
	assert probe.requests[0].current_url().serialize() == address
	mut response := fetch.Response.create()
	response.status = 410
	response.url_list = probe.requests[0].url_list.clone()
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/html' })
	response.set_body_bytes([]u8{})
	mut pending := probe.pending[0]
	pending.resolve(response)
	mut loop := html.main_thread_event_loop()
	mut queue := loop.task_queue()
	mut plugin := platform.EventLoopPlugin.the()
	for _ in 0 .. 200 {
		if plugin.run_one_deferred() { continue }
		loop.perform_a_microtask_checkpoint()
		if task := queue.take_first_runnable() {
			task.execute()
			continue
		}
		host.poll(mut messages)
		_ = layout.run_document_layout(parent, 320, 200)
		if service := host.children[0].service {
			if service.initialized && service.load_fired { break }
		}
	}
	assert host.children.len == 2
	first := host.children[0].service?
	second := host.children[1].service?
	assert first.initialized && first.load_fired
	assert first.document.url.serialize() == address
	assert second.document.url.serialize() == 'about:blank'
	assert voidptr(first.document) != voidptr(parent)
	assert voidptr(second.document) != voidptr(parent)
	assert voidptr(first.document) != voidptr(second.document)
	assert first.document.get_element_by_id('parent') == none
	assert second.document.get_element_by_id('parent') == none
	assert first.remaining == 0 && second.remaining == 0
	assert !parent.anything_is_delaying_the_load_event()
	assert parent.title() == 'Parent document'
	assert probe.requests.len == 1
}
