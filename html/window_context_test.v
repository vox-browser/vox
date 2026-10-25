module html

import dom
import highresolutiontime

struct AnimationCallbackTestState {
mut:
	now f64
}

fn unloading_cleanup_websocket_disappears() bool {
	return true
}

fn window_test_deliver_messages() {
	mut loop := main_thread_event_loop()
	mut queue := loop.task_queue()
	for {
		task := queue.take_first_runnable_matching(fn (task &Task) bool { return task.source() == .posted_message }) or { break }
		task.execute()
	}
}

fn window_test_document(url string) &dom.Document {
	parsed := dom.URL{value: url}
	return &dom.Document{
		url:     parsed
		origin_: parsed.origin()
	}
}

fn test_window_unloading_cleanup_uses_translated_global_scope_algorithms() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	window := WindowModel.create_top_level(document, none, 'cleanup')!
	mut scope := unsafe { &WindowOrWorkerGlobalScopeMixin(window.window_or_worker_global_scope()) }
	scope.set_timeout(timer_source_handler('cleanup'), 1000, [])
	socket := &GlobalScopeWebSocket{
		make_disappear: unloading_cleanup_websocket_disappears
	}
	scope.register_web_socket(socket)
	assert scope.active_timer_count() == 1
	assert document.salvageable

	document.run_unloading_cleanup_steps()
	assert !document.salvageable
	assert scope.active_timer_count() == 0
}

fn test_window_and_location_are_the_dom_exposed_objects() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/path' })
	window := WindowModel.create_top_level(document, none, '')!

	dom_window := document.get_window() or {
		assert false, 'WindowModel was not installed as the document global object'
		return
	}
	assert voidptr(dom_window) == voidptr(window)
	dom_location := document.location() or {
		assert false, 'fully-active document did not expose WindowModel.location'
		return
	}
	assert voidptr(dom_location) == voidptr(window.location())
	assert window.location().href()! == 'https://example.test/path'
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
	// URL's port state removes the scheme's default port, so Location::port
	// returns the empty string exactly as upstream does for https:443.
	assert location.port()! == ''
	location.replace('/replacement')!
	assert location.navigations().last().history_behavior == .replace
	location.reload()
	assert location.reload_count() == 1
}

fn test_declarative_refresh_uses_the_translated_navigable_with_replace_history() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/start' })
	_ = WindowModel.create_top_level(document, none, '')!
	mut navigable := NavigableModel.navigable_with_active_document(document) or {
		assert false, 'WindowModel did not create the translated NavigableModel'
		return
	}
	assert navigable.get_session_history_entries().len == 1

	document.shared_declarative_refresh_steps('0; url=/refreshed')
	document.completely_finish_loading()
	document.active_refresh_timer.fire()

	entry := navigable.current_session_history_entry() or {
		assert false, 'declarative refresh did not retain a current history entry'
		return
	}
	assert entry.url().serialize() == 'https://example.test/refreshed'
	assert navigable.get_session_history_entries().len == 1
}

fn test_location_enforces_same_origin_for_sensitive_operations() {
	document := window_test_document('https://example.test/a')
	mut location := LocationModel.create(document, dom.Origin{ value: 'https://other.test' })
	if _ := location.href() {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	// Cross-origin WindowProxy assignment to location.href is intentionally allowed.
	location.set_href('https://new.example/path')!
	assert document.url.serialize() == 'https://new.example/path'
}

fn test_location_exact_exotic_internal_methods() {
	document := window_test_document('https://example.test/a')
	mut location := LocationModel.create(document, document.origin())
	assert location.internal_is_extensible()
	assert !location.internal_prevent_extensions()
	assert location.internal_get_prototype_of(document.origin()).kind == .null_
	assert location.internal_set_prototype_of(dom.js_null())
	assert !location.internal_set_prototype_of(dom.js_object(voidptr(1)))
	href := location.internal_get_own_property(document.origin(), 'href')!
	assert href.found
	assert href.descriptor.value.string_data == 'https://example.test/a'
	assert location.internal_define_own_property(document.origin(), 'answer', dom.js_number(42))!
	assert location.internal_get(document.origin(), 'answer')!.number_data == 42
	assert location.internal_delete(document.origin(), 'answer')!
	assert location.internal_get(document.origin(), 'answer')!.is_undefined()
	assert 'href' in location.internal_own_property_keys(document.origin())
	cross_origin := dom.Origin{ value: 'https://other.test' }
	assert location.internal_get_prototype_of(cross_origin).kind == .null_
	assert location.internal_get_own_property(cross_origin, 'replace')!.found
	assert location.internal_set(cross_origin, 'href', dom.js_string('/next'))!
	assert document.url.serialize() == 'https://example.test/next'
	assert location.internal_own_property_keys(cross_origin) == ['href', 'replace']
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

fn test_browsing_context_exact_creation_and_traversable_access() {
	page := &dom.Page{}
	mut group := BrowsingContextGroup.create(page)
	creator := dom.Document.create(dom.URL{ value: 'https://example.test/creator' })
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(page, creator,
		none)!
	group.append(created.document.get_browsing_context()?)
	assert created.document.is_html_document()
	assert created.document.origin().is_same_origin(creator.origin())
	assert created.document.document_element() != none
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(created.document.navigable()?)
	mut created_context := created.browsing_context
	created_context.set_top_level_traversable(traversable)
	assert created_context.top_level_traversable()? == traversable
	assert created_context.the_one_permitted_sandboxed_navigator() == none
	auxiliary := BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(page,
		created_context)!
	assert auxiliary.browsing_context.opener()? == created_context
	assert auxiliary.browsing_context.top_level_traversable()? == traversable
	mut auxiliary_context := auxiliary.browsing_context
	auxiliary_context.remove()
	created_context.remove()
	group.finalize()
}

fn test_new_browsing_context_propagates_embedder_sandbox_flags() {
	page := &dom.Page{}
	mut group := BrowsingContextGroup.create(page)
	creator := dom.Document.create(dom.URL{ value: 'https://example.test/creator' })
	mut iframe_element := creator.create_element_ns(namespace_html, 'iframe') or { panic(err) }
	iframe_element.set_attribute_value('sandbox', 'allow-scripts')
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(page, creator,
		iframe_element)!
	group.append(created.document.get_browsing_context()?)
	assert created.document.active_sandboxing_flag_bits() & u32(SandboxingFlag.sandboxed_origin) != 0
	assert created.document.active_sandboxing_flag_bits() & u32(SandboxingFlag.sandboxed_scripts) == 0
	assert !created.document.origin().is_same_origin(creator.origin())
	mut created_context := created.browsing_context
	created_context.remove()
	group.finalize()
}

fn test_window_proxy_indexed_and_cross_origin_access() {
	mut top_document := dom.Document.create(dom.URL{value: 'https://top.test/'})
	top_document.set_origin(top_document.url.origin())
	mut top := WindowModel.create_top_level(top_document, none, 'top')!
	mut child_document := dom.Document.create(dom.URL{value: 'https://child.test/'})
	child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, top.browsing_context(),
		'childFrame')
	mut parent_document := unsafe { &dom.Document(top_document) }
	container := parent_document.create_element_ns(namespace_html, 'iframe')!
	mut parent_node := parent_document.as_node()
	parent_node.append_child(container.as_node())!
	mut mutable_child_context := unsafe { &BrowsingContextModel(child_context) }
	mutable_child_context.set_container(container)
	_ = WindowModel.create(child_document, child_context)!
	proxy := top.window()

	indexed := proxy.get_own_property(dom.Origin{ value: 'https://elsewhere.test' }, '0')!
	assert indexed.found
	assert indexed.descriptor.value.kind == .object
	assert proxy.own_property_keys(top_document.origin())[0] == '0'
	length_property := proxy.get_own_property(dom.Origin{ value: 'https://elsewhere.test' }, 'length')!
	assert length_property.found
	assert length_property.descriptor.value.number_data == 1
	if _ := proxy.get_own_property(dom.Origin{ value: 'https://elsewhere.test' }, 'secret') {
		assert false
	} else {
		assert err.msg().contains('SecurityError')
	}
	top.set_named_property('answer', dom.js_number(42))
	answer := proxy.get_own_property(top_document.origin(), 'answer')!
	assert answer.found
	assert answer.descriptor.value.number_data == 42
	assert proxy.internal_is_extensible()
	mut mutable_proxy := unsafe { &WindowProxyModel(proxy) }
	assert !mutable_proxy.internal_prevent_extensions()
	assert mutable_proxy.internal_set_prototype_of(dom.js_null())
	assert proxy.internal_get_prototype_of(dom.Origin{ value: 'https://elsewhere.test' }).kind == .null_
	assert proxy.internal_get_own_property(top_document.origin(), 'answer')!.found
	assert proxy.internal_get(top_document.origin(), 'answer')!.number_data == 42
	assert proxy.internal_define_own_property(top_document.origin(), 'second', dom.js_number(2))!
	assert proxy.internal_set(top_document.origin(), 'third', dom.js_number(3))!
	assert proxy.internal_delete(top_document.origin(), 'third')!
	assert 'second' in proxy.internal_own_property_keys(top_document.origin())
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
	assert window.posted_messages().len == 0
	window_test_deliver_messages()
	assert window.posted_messages().len == 1
	assert window.posted_messages()[0].data.string_data == 'hello'
	window.post_message(dom.js_string('ignored'), document.origin(), WindowPostMessageOptions{
		target_origin: 'https://other.test'
	})!
	window_test_deliver_messages()
	assert window.posted_messages().len == 1

	window.close()
	assert window.closed()
}

fn test_new_browsing_context_document_records_its_navigation_start_as_the_time_origin() {
	page_ := &dom.Page{}
	mut group := BrowsingContextGroup.create(page_)
	before := highresolutiontime.unsafe_shared_current_time()
	created := BrowsingContextModel.create_a_new_browsing_context_and_document(page_, none, none)!
	group.append(created.document.get_browsing_context()?)
	after := highresolutiontime.unsafe_shared_current_time()
	navigation_start := created.document.load_timing_info.navigation_start_time
	assert navigation_start >= highresolutiontime.coarsen_time(before, false)
	assert navigation_start <= after

	window := created.browsing_context.active_window() or { panic('missing window') }
	assert window.environment_settings_ != unsafe { nil }
	assert window.environment_settings_.time_origin() == navigation_start
}
