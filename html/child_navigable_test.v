module html

import dom
import fetch
import http
import page

fn child_navigable_parent(markup string) &dom.Document {
	mut owner := page.Page.create(1) or { panic(err) }
	url := dom.URL{ value: 'https://parent.example/path/index.html' }
	mut document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) }) or { panic(err) }
	parse_html_from_a_string(document, markup)
	return document
}

fn test_child_navigable_uses_the_container_parent_page_origin_and_context() {
	mut parent := child_navigable_parent('<!doctype html><iframe id="frame" name="child"></iframe>')
	frame := parent.get_element_by_id('frame')?
	mut child := create_child_navigable_for_element(frame)!
	mut initial := child.active_document()?
	defer {
		child.host_navigable().remove_from_all_navigables()
		initial.finalize()
		parent.finalize()
	}
	assert voidptr(frame.as_node().content_navigable()?) == voidptr(child.host_navigable())
	assert voidptr(child.host_navigable().parent()?) == voidptr(parent.navigable()?)
	assert voidptr(initial.page()) == voidptr(parent.page())
	assert initial.is_fully_active()
	assert initial.get_is_initial_about_blank()
	assert initial.url.serialize() == 'about:blank'
	assert initial.base_url().serialize() == parent.base_url().serialize()
	assert initial.origin().is_same_origin(parent.origin())
	assert voidptr(content_document_for_element(frame)?) == voidptr(initial)
	assert child.target_name() == 'child'
	assert child.has_session_history_entry_and_ready_for_navigation()
	assert voidptr(create_child_navigable_for_element(frame)!) == voidptr(child)
	context := child.active_browsing_context()?
	assert voidptr(context.parent()?.active_document()?) == voidptr(parent)
}

fn test_child_navigable_navigation_commits_a_real_cross_origin_document() {
	mut parent := child_navigable_parent('<!doctype html><iframe id="frame"></iframe>')
	frame := parent.get_element_by_id('frame')?
	mut child := create_child_navigable_for_element(frame)!
	mut initial := child.active_document()?
	child.set_navigation_fetch_hook(fn (request &fetch.Request) !&fetch.Response {
		assert request.target_is_nested_navigable
		mut response := fetch.Response.create()
		response.url_list = request.url_list.clone()
		response.header_list.append(http.Header{ name: 'Content-Type', value: 'text/html' })
		response.set_body_bytes('<!doctype html><p id="loaded">network document</p>'.bytes())
		return response
	})
	child.navigate(NavigableNavigateParams{ url: dom.URL{ value: 'https://child.example/document' }, source_document: parent, initial_insertion: .yes })
	mut loaded := child.active_document()?
	defer {
		child.host_navigable().remove_from_all_navigables()
		initial.finalize()
		loaded.finalize()
		parent.finalize()
	}
	assert loaded.url.serialize() == 'https://child.example/document'
	assert loaded.get_element_by_id('loaded')?.text_content()? == 'network document'
	assert loaded.is_fully_active()
	assert voidptr(loaded.page()) == voidptr(parent.page())
	assert content_document_for_element(frame) == none
	assert initial.navigable() == none
}

fn test_sandboxed_child_document_is_opaque_and_disconnected_containers_are_rejected() {
	mut parent := child_navigable_parent('<!doctype html><iframe id="frame" sandbox="allow-scripts"></iframe>')
	frame := parent.get_element_by_id('frame')?
	mut child := create_child_navigable_for_element(frame)!
	mut initial := child.active_document()?
	defer {
		child.host_navigable().remove_from_all_navigables()
		initial.finalize()
		parent.finalize()
	}
	assert !initial.origin().is_same_origin(parent.origin())
	assert initial.active_sandboxing_flag_bits() & u32(SandboxingFlag.sandboxed_origin) != 0
	assert content_document_for_element(frame) == none
	other := parent.create_element('iframe')!
	if _ := create_child_navigable_for_element(other) {
		assert false, 'Disconnected iframe created a browsing context'
	}
}
