module html

import dom
import fetch
import http
import page

struct PageNavigationObservation {
mut:
	requests       []&fetch.Request
	navigation_ids []string
}

fn page_navigation_owner(url string) (&page.Page, &NavigableModel) {
	mut owner := page.Page.create(1) or { panic(err) }
	mut document := dom.Document.create(dom.URL{value: url})
	document.set_origin(document.url.origin())
	document.set_page(unsafe { &dom.Page(owner) })
	document.populate_with_html_head_and_body() or { panic(err) }
	window := WindowModel.create_top_level(document, none, 'page-navigation') or { panic(err) }
	model := window.navigable_model()
	owner.set_local_root_navigable(model.host_navigable()) or { panic(err) }
	return owner, model
}

fn test_page_load_invokes_its_actual_local_root_and_keeps_history_and_navigation_identity() {
	mut owner, model_pointer := page_navigation_owner('https://example.test/start')
	mut model := unsafe { &NavigableModel(model_pointer) }
	state := &PageNavigationObservation{}
	model.set_navigation_fetch_hook(fn [state] (request &fetch.Request) !&fetch.Response {
		mut observation := unsafe { &PageNavigationObservation(state) }
		observation.requests << request
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/html' })
		response.set_body_bytes('<!doctype html><html><body><p id="fetched">actual fetch body</p></body></html>'.bytes())
		return response
	})
	mut original := model.active_document() or { panic('missing source') }
	mut source := unsafe { &dom.Document(original) }
	source.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_navigation) | u32(SandboxingFlag.sandboxed_downloads))
	owner.load_with_history_and_navigation_id(dom.URL{value: 'https://example.test/replace'}, .replace, 'ui-navigation-replace')
	assert state.requests.len == 1
	assert state.requests[0].user_activation
	assert state.requests[0].current_url().serialize() == 'https://example.test/replace'
	assert model.get_session_history_entries().len == 1
	mut first := model.active_document() or { panic('navigation did not commit') }
	assert voidptr(first) != voidptr(original)
	assert first.navigation_id() or { '' } == 'ui-navigation-replace'
	assert first.get_element_by_id('fetched') != none
	owner.load_with_history_and_navigation_id(dom.URL{value: 'https://example.test/push'}, .push, 'ui-navigation-push')
	assert state.requests.len == 2
	assert model.get_session_history_entries().len == 2
	assert model.active_document()?.navigation_id()? == 'ui-navigation-push'
	assert 'navigate' !in owner.client_events.map(it.name)
	first.finalize()
	original.finalize()
}

fn test_page_load_html_navigates_with_srcdoc_resource_and_reload_replaces_the_document() {
	mut owner, model := page_navigation_owner('https://example.test/start')
	owner.load_html_with_navigation_id('<!doctype html><html><body><p id="srcdoc">resource text</p></body></html>', 'ui-srcdoc')
	mut document := model.active_document() or { panic('no srcdoc document') }
	assert document.url.serialize() == 'about:srcdoc'
	assert document.navigation_id()? == 'ui-srcdoc'
	assert document.get_element_by_id('srcdoc')?.text_content()? == 'resource text'
	entry_count := model.get_session_history_entries().len
	owner.reload()
	reloaded := model.active_document() or { panic('reload lost document') }
	assert voidptr(reloaded) != voidptr(document)
	assert reloaded.url.serialize() == 'about:srcdoc'
	assert reloaded.get_element_by_id('srcdoc')?.text_content()? == 'resource text'
	assert model.get_session_history_entries().len == entry_count
	assert 'navigate-html' !in owner.client_events.map(it.name)
	assert 'reload' !in owner.client_events.map(it.name)
	document.finalize()
}

fn test_page_fragment_load_keeps_the_supplied_navigation_id_on_the_real_entry() {
	mut owner, model := page_navigation_owner('https://example.test/start')
	mut original := model.active_document() or { panic('missing original') }
	state := &PageNavigationObservation{}
	mut observer := NavigationObserver.create(model.host_navigable())
	observer.set_ongoing_navigation_changed(fn [state, model] () {
		mut observation := unsafe { &PageNavigationObservation(state) }
		if model.ongoing_navigation().kind == .navigation {
			observation.navigation_ids << model.ongoing_navigation().id
		}
	})
	owner.load_with_history_and_navigation_id(dom.URL{value: 'https://example.test/start#fragment'}, .push, 'ui-fragment')
	assert model.get_session_history_entries().len == 2
	assert voidptr(model.active_document()?) == voidptr(original)
	assert original.url.fragment()? == 'fragment'
	assert state.navigation_ids == ['ui-fragment']
	observer.finalize()
	assert model.ongoing_navigation().kind == .empty
	original.finalize()
}
