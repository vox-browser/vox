module html

import dom

struct AnimationCallbackTestState {
mut:
	now f64
}

fn window_test_document(url string) &dom.Document {
	parsed := dom.URL{url}
	return &dom.Document{
		url:     parsed
		origin_: parsed.origin()
	}
}

fn test_location_component_access_and_navigation() {
	document := window_test_document('https://example.test:8443/a/b?q=1#old')
	mut location := LocationModel.create(document, document.origin())
	assert location.href()! == 'https://example.test:8443/a/b?q=1#old'
	assert location.origin()! == 'https://example.test:8443'
	assert location.protocol()! == 'https:'
	assert location.host()! == 'example.test:8443'
	assert location.hostname()! == 'example.test'
	assert location.port()! == '8443'
	assert location.pathname()! == '/a/b'
	assert location.search()! == '?q=1'
	assert location.hash()! == '#old'

	location.set_hash('#new')!
	assert document.url.fragment() or { '' } == 'new'
	location.set_search('?page=2')!
	assert document.url.query() or { '' } == 'page=2'
	location.set_pathname('next')!
	assert document.url.serialize_path() == '/next'
	location.set_port('443')!
	assert location.port()! == '443'
	location.replace('/replacement')!
	assert location.navigations().last().history_behavior == .replace
	location.reload()
	assert location.reload_count() == 1
}

fn test_location_enforces_same_origin_for_sensitive_operations() {
	document := window_test_document('https://example.test/a')
	mut location := LocationModel.create(document, dom.Origin{'https://other.test'})
	if _ := location.href() {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	// Cross-origin WindowProxy assignment to location.href is intentionally allowed.
	location.set_href('https://new.example/path')!
	assert document.url.serialize() == 'https://new.example/path'
}

fn test_browsing_context_ancestry_familiarity_and_target_choice() {
	page := &dom.Page{}
	mut group := BrowsingContextGroup.create(page)
	top_document := window_test_document('https://example.test/')
	top := BrowsingContextModel.create(top_document, none, 'top')
	group.append_model(top)
	child_document := window_test_document('https://child.test/')
	child := BrowsingContextModel.create(child_document, top, 'frame')
	group.append_model(child)
	grandchild_document := window_test_document('https://example.test/nested')
	grandchild := BrowsingContextModel.create(grandchild_document, child, 'nested')
	group.append_model(grandchild)

	assert top.is_top_level()
	assert top.is_ancestor_of(grandchild)
	assert grandchild.top_level_browsing_context() or { panic('missing top') } == top
	assert grandchild.is_familiar_with(top)
	assert grandchild.choose_a_browsing_context('_parent') or { panic('missing parent') } == child
	assert grandchild.choose_a_browsing_context('frame') or { panic('missing named target') } == child
	assert grandchild.choose_a_browsing_context('_blank') == none
}

fn test_window_proxy_indexed_and_cross_origin_access() {
	top_document := window_test_document('https://top.test/')
	mut top := WindowModel.create_top_level(top_document, none, 'top')!
	child_document := window_test_document('https://child.test/')
	child_context := BrowsingContextModel.create(child_document, top.browsing_context(),
		'childFrame')
	child := WindowModel.create(child_document, child_context)!
	_ = child
	proxy := top.window()

	indexed := proxy.get_own_property(dom.Origin{'https://elsewhere.test'}, '0')!
	assert indexed.found
	assert indexed.descriptor.value.kind == .object
	assert proxy.own_property_keys(top_document.origin())[0] == '0'
	length_property := proxy.get_own_property(dom.Origin{'https://elsewhere.test'}, 'length')!
	assert length_property.found
	assert length_property.descriptor.value.number_data == 1
	if _ := proxy.get_own_property(dom.Origin{'https://elsewhere.test'}, 'secret') {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	top.set_named_property('answer', dom.js_number(42))
	answer := proxy.get_own_property(top_document.origin(), 'answer')!
	assert answer.found
	assert answer.descriptor.value.number_data == 42
}

fn test_window_core_relations_close_animation_and_post_message() {
	document := window_test_document('https://example.test/')
	mut window := WindowModel.create_top_level(document, none, 'initial')!
	assert window.window() == window.self()
	assert window.frames() == window.self()
	window.set_name('renamed')
	assert window.name() == 'renamed'
	assert window.browsing_context().target_name() == 'renamed'
	assert window.parent() or { panic('missing parent') } == window.self()
	assert window.locationbar().visible()

	callback_state := &AnimationCallbackTestState{}
	handle := window.request_animation_frame(fn [callback_state] (now f64) {
		mut state := unsafe { &AnimationCallbackTestState(callback_state) }
		state.now = now
	})
	assert handle == 1
	assert window.has_animation_frame_callbacks()
	window.run_animation_frame_callbacks(12.5)
	assert callback_state.now == 12.5

	window.post_message(dom.js_string('hello'), document.origin(), WindowPostMessageOptions{
		target_origin: 'https://example.test'
	})!
	assert window.posted_messages().len == 1
	assert window.posted_messages()[0].data.string_data == 'hello'
	window.post_message(dom.js_string('ignored'), document.origin(), WindowPostMessageOptions{
		target_origin: 'https://other.test'
	})!
	assert window.posted_messages().len == 1

	window.close()
	assert window.closed()
}
