module html

import dom
import fetch
import http
import page
import platform

@[heap]
struct AsyncNavigationProbe {
mut:
	requests []&fetch.Request
	pending  []&fetch.PendingResponse
}

fn async_navigation_owner() (&dom.Document, &NavigableModel, &AsyncNavigationProbe) {
	mut owner := page.Page.create(1) or { panic(err) }
	url := dom.URL{ value: 'https://async-parent.test/index' }
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) }) or { panic(err) }
	parse_html_from_a_string(document, '<!doctype html><iframe id="frame"></iframe>')
	frame := document.get_element_by_id('frame') or { panic('Missing frame') }
	mut child := create_child_navigable_for_element(frame) or { panic(err) }
	probe := &AsyncNavigationProbe{}
	child.set_navigation_fetch_host(&fetch.FetchHost{
		perform:       fn (_ &fetch.Request) !&fetch.Response {
			panic('Blocking navigation transport used')
		}
		perform_async: fn [probe] (request &fetch.Request) &fetch.PendingResponse {
			mut state := unsafe { &AsyncNavigationProbe(probe) }
			mut mutable_request := unsafe { &fetch.Request(request) }
			pending := fetch.PendingResponse.create(mut mutable_request, none)
			state.requests << request
			state.pending << pending
			return pending
		}
	})
	return document, child, probe
}

fn drain_async_navigation_tasks() {
	mut loop := main_thread_event_loop()
	mut queue := loop.task_queue()
	mut plugin := platform.EventLoopPlugin.the()
	for _ in 0 .. 200 {
		if plugin.run_one_deferred() { continue }
		loop.perform_a_microtask_checkpoint()
		task := queue.take_first_runnable() or { return }
		task.execute()
	}
	assert false, 'Navigation task queue did not settle'
}

fn resolve_async_navigation(probe &AsyncNavigationProbe, index int, status u16, headers []http.Header, body string) {
	mut response := fetch.Response.create()
	response.url_list = probe.requests[index].url_list.clone()
	response.status = status
	response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/html' })
	for header in headers { response.header_list.append(header) }
	response.set_body_bytes(body.bytes())
	mut pending := probe.pending[index]
	pending.resolve(response)
	drain_async_navigation_tasks()
}

fn test_async_child_navigation_waits_for_the_owning_fetch_and_then_commits() {
	mut parent, mut child, probe := async_navigation_owner()
	mut initial := child.active_document()?
	child.navigate(NavigableNavigateParams{ url: dom.URL{ value: 'https://async-child.test/page' }, source_document: parent, navigation_id: 'pending-child' })!
	assert voidptr(child.active_document()?) == voidptr(initial)
	assert child.ongoing_navigation().id == 'pending-child'
	assert probe.requests.len == 1
	assert probe.requests[0].target_is_nested_navigable
	assert probe.requests[0].credentials_mode == .include
	assert probe.requests[0].mode == .navigate
	assert child.is_delaying_load_events()
	assert parent.get_element_by_id('frame')?.as_node().currently_delays_the_load_event()
	resolve_async_navigation(probe, 0, 200, [], '<!doctype html><p id="loaded">async child</p>')
	mut loaded := child.active_document()?
	assert loaded.url.serialize() == 'https://async-child.test/page'
	assert loaded.get_element_by_id('loaded')?.text_content()? == 'async child'
	assert loaded.is_fully_active()
	assert voidptr(loaded.page()) == voidptr(parent.page())
	assert child.ongoing_navigation().kind == .empty
	assert !child.is_delaying_load_events()
	child.host_navigable().remove_from_all_navigables()
	initial.finalize()
	loaded.finalize()
	parent.finalize()
}

fn test_async_navigation_ignores_superseded_and_destroyed_responses() {
	mut parent, mut child, probe := async_navigation_owner()
	mut initial := child.active_document()?
	for id in ['old', 'new'] {
		child.navigate(NavigableNavigateParams{ url: dom.URL{ value: 'https://async-child.test/${id}' }, source_document: parent, navigation_id: id })!
	}
	assert probe.requests.len == 2
	resolve_async_navigation(probe, 0, 200, [], '<p id="old">stale</p>')
	assert voidptr(child.active_document()?) == voidptr(initial)
	assert child.ongoing_navigation().id == 'new'
	resolve_async_navigation(probe, 1, 200, [], '<p id="new">current</p>')
	mut loaded := child.active_document()?
	assert loaded.get_element_by_id('new') != none
	assert loaded.get_element_by_id('old') == none
	child.navigate(NavigableNavigateParams{ url: dom.URL{ value: 'https://async-child.test/destroyed' }, source_document: parent })!
	child.set_has_been_destroyed()
	resolve_async_navigation(probe, 2, 200, [], '<p id="destroyed">late</p>')
	assert voidptr(child.active_document()?) == voidptr(loaded)
	assert loaded.get_element_by_id('destroyed') == none
	child.host_navigable().remove_from_all_navigables()
	initial.finalize()
	loaded.finalize()
	parent.finalize()
}

fn test_async_navigation_follows_manual_redirects_before_committing() {
	mut parent, mut child, probe := async_navigation_owner()
	mut initial := child.active_document()?
	child.navigate(NavigableNavigateParams{ url: dom.URL{ value: 'https://async-child.test/start' }, source_document: parent })!
	resolve_async_navigation(probe, 0, 302, [http.Header{ name: 'Location', value: '/final' }], '')
	assert probe.requests.len == 2
	assert probe.requests[1].current_url().serialize() == 'https://async-child.test/final'
	assert voidptr(child.active_document()?) == voidptr(initial)
	resolve_async_navigation(probe, 1, 200, [], '<p id="final">redirected</p>')
	mut loaded := child.active_document()?
	assert loaded.url.serialize() == 'https://async-child.test/final'
	assert loaded.get_element_by_id('final') != none
	child.host_navigable().remove_from_all_navigables()
	initial.finalize()
	loaded.finalize()
	parent.finalize()
}

fn test_async_network_failure_releases_load_delay_without_replacing_the_document() {
	mut parent, mut child, probe := async_navigation_owner()
	mut initial := child.active_document()?
	child.navigate(NavigableNavigateParams{ url: dom.URL{ value: 'https://async-child.test/failure' }, source_document: parent })!
	mut pending := probe.pending[0]
	pending.resolve(fetch.Response.network_error('controlled connection failure'))
	drain_async_navigation_tasks()
	assert voidptr(child.active_document()?) == voidptr(initial)
	assert child.ongoing_navigation().kind == .empty
	assert !child.is_delaying_load_events()
	child.host_navigable().remove_from_all_navigables()
	initial.finalize()
	parent.finalize()
}
