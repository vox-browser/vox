@[has_globals]
module html

import css
import dom
import fetch
import http
import page
import painting

__global (
	navigable_test_observer_completions = 0
	navigable_test_observer_changes     = 0
	navigable_test_pastes               = []string{}
	navigable_test_paints               = 0
	navigable_test_screenshots          = 0
	navigable_test_fetches              = 0
	navigable_test_destroy_during_fetch = &NavigableModel(unsafe { nil })
)

fn navigable_test_complete() {
	navigable_test_observer_completions++
}

fn navigable_test_changed() {
	navigable_test_observer_changes++
}

fn navigable_test_paste(text string) {
	navigable_test_pastes << text
}

fn navigable_test_paint() {
	navigable_test_paints++
}

fn navigable_test_screenshot(_ dom.Rect) {
	navigable_test_screenshots++
}

fn navigable_test_javascript_url(source string, _ &dom.Document) ?string {
	if source == "'generated'" {
		return '<!doctype html><html><body>generated</body></html>'
	}
	return none
}

fn navigable_test_fetch(request &fetch.Request) !&fetch.Response {
	navigable_test_fetches++
	mut response := fetch.Response.create()
	response.url_list = request.url_list.clone()
	if request.current_url().serialize() == 'https://example.test/redirect' {
		response.status = 302
		response.header_list.append(http.Header{
			name: 'Location'
			value: '/fetched'
		})
		return response
	}
	response.set_body_bytes('<!doctype html><html><body>fetched response</body></html>'.bytes())
	response.header_list.append(http.Header{
		name: 'Content-Type'
		value: 'text/html'
	})
	response.header_list.append(http.Header{
		name: 'Content-Security-Policy'
		value: "sandbox allow-scripts; default-src 'self'"
	})
	return response
}

fn navigable_test_fetch_and_destroy(request &fetch.Request) !&fetch.Response {
	mut model := navigable_test_destroy_during_fetch
	model.set_has_been_destroyed()
	return navigable_test_fetch(request)
}

fn navigable_test_top_level(url string, target_name string) !(&dom.Document, &WindowModel, &NavigableModel) {
	mut document := dom.Document.create(dom.URL{url})
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	window := WindowModel.create_top_level(document, none, target_name)!
	host := document.cached_navigable() or { return error('missing host navigable') }
	model := navigable_model_for_host(host) or { return error('missing navigable model') }
	return document, window, model
}

fn test_navigable_initialization_hierarchy_and_target_choice() {
	mut parent_document, mut parent_window, parent_model := navigable_test_top_level('https://example.test/', 'top')!
	assert parent_model.id() != ''
	assert parent_model.active_document()? == parent_document
	assert parent_model.target_name() == 'top'
	assert parent_model.is_top_level_traversable()
	assert parent_model.is_script_closable()
	assert !parent_model.host_navigable().is_focused()
	mut focused_parent_model := unsafe { &NavigableModel(parent_model) }
	focused_parent_model.set_focused(true)
	assert parent_model.host_navigable().is_focused()

	mut child_document := dom.Document.create(dom.URL{'https://example.test/frame'})
	child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, parent_window.browsing_context(), 'frame')
	mut container := parent_document.create_element_ns('http://www.w3.org/1999/xhtml', 'iframe')!
	mut parent_body := parent_document.body() or { panic('missing parent body') }
	mut parent_body_node := parent_body.as_node()
	parent_body_node.append_child(container.as_node())!
	mut mutable_child_context := unsafe { &BrowsingContextModel(child_context) }
	mutable_child_context.set_container(container)
	_ = WindowModel.create(child_document, child_context)!
	child_host := child_document.cached_navigable() or { panic('missing child host') }
	mut child_model := navigable_model_for_host(child_host) or { panic('missing child model') }
	assert child_model.parent()? == parent_model
	assert parent_model.is_ancestor_of(child_model)
	assert child_model.traversable_navigable() == parent_model
	assert child_host.container()? == container.as_node()
	assert child_host.container_document()? == parent_document
	mut iframe_model := html_iframe_element_model_for_dom_element(unsafe { &dom.HTMLIFrameElement(container) })
	iframe_model.set_sandbox('allow-scripts allow-forms')
	parent_document.set_active_sandboxing_flag_set(dom.SandboxingFlagSet{
		sandboxed_document_domain: true
	})
	child_snapshot := child_model.snapshot_target_snapshot_params()
	assert child_snapshot.sandboxing_flags.contains(.sandboxed_navigation)
	assert child_snapshot.sandboxing_flags.contains(.sandboxed_document_domain)
	assert !child_snapshot.sandboxing_flags.contains(.sandboxed_scripts)
	assert !child_snapshot.sandboxing_flags.contains(.sandboxed_forms)
	child_document.set_cached_navigable(none)
	assert child_document.as_node().navigable()? == child_host
	assert child_document.cached_navigable()? == child_host
	assert parent_document.document_tree_child_navigables() == [child_host]
	assert parent_model.child_navigables().len == 0
	child_model.set_has_session_history_entry_and_ready_for_navigation()
	assert parent_model.child_navigables() == [child_model]

	mut mutable_parent_model := unsafe { &NavigableModel(parent_window.navigable_model()) }
	self_choice := mutable_parent_model.choose_a_navigable('_self', false)!
	assert self_choice.navigable? == parent_model
	assert self_choice.window_type == .existing_or_none
	frame_choice := mutable_parent_model.choose_a_navigable('frame', false)!
	assert frame_choice.navigable? == child_model
	blank_choice := mutable_parent_model.choose_a_navigable('_blank', true)!
	assert blank_choice.navigable != none
	assert blank_choice.window_type == .new_with_no_opener
}

fn test_top_level_target_snapshot_uses_popup_sandboxing_flags() {
	_, window, model := navigable_test_top_level('https://example.test/', 'top')!
	mut context := unsafe { &BrowsingContextModel(window.browsing_context()) }
	context.set_popup_sandboxing_flag_set(SandboxingFlagSet{
		bits: u32(SandboxingFlag.sandboxed_scripts) | u32(SandboxingFlag.sandboxed_forms)
	})

	snapshot := model.snapshot_target_snapshot_params()
	assert snapshot.sandboxing_flags.contains(.sandboxed_scripts)
	assert snapshot.sandboxing_flags.contains(.sandboxed_forms)
	assert !snapshot.sandboxing_flags.contains(.sandboxed_origin)
}

fn test_navigable_history_cross_document_fragment_reload_and_javascript_url() {
	mut original_document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	assert model.backing_store_manager() != unsafe { nil }
	assert model.event_handler() != unsafe { nil }
	assert model.rendering_thread() != unsafe { nil }
	assert !model.is_svg_page()
	model.navigate(NavigableNavigateParams{
		url: dom.URL{'https://example.test/next'}
		source_document: original_document
		document_resource: '<!doctype html><html><body>next</body></html>'
	})!
	assert model.get_session_history_entries().len == 2
	next_document := model.active_document() or { panic('missing navigated document') }
	assert next_document.url.serialize() == 'https://example.test/next'
	assert next_document.body() != none
	assert model.ongoing_navigation().kind == .empty
	assert model.get_the_target_history_entry(0)? == model.get_session_history_entries()[0]
	assert model.get_the_target_history_entry(1)? == model.current_session_history_entry()?

	model.navigate(NavigableNavigateParams{
		url: dom.URL{'https://example.test/next#section'}
		source_document: next_document
	})!
	assert model.get_session_history_entries().len == 3
	assert model.active_document()?.url.fragment()? == 'section'
	model.reload(none, .none)
	assert model.get_session_history_entries().len == 3
	assert model.active_document()?.url.fragment()? == 'section'

	model.set_javascript_url_hook(navigable_test_javascript_url)
	current_document := model.active_document() or { panic('missing current document') }
	model.navigate(NavigableNavigateParams{
		url: dom.URL{"javascript:'generated'"}
		source_document: current_document
		history_handling: .replace
	})!
	assert model.active_document()?.body() != none
	assert model.get_session_history_entries().len == 3
}

fn test_navigable_sandbox_viewport_selection_observers_and_rendering() {
	mut document, _, model_pointer := navigable_test_top_level('https://example.test/', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	assert model.allowed_by_sandboxing_to_navigate(model, SourceSnapshotParams{
		sandboxing_flags: SandboxingFlagSet{ bits: u32(SandboxingFlag.sandboxed_navigation) }
	})

	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})
	model.set_viewport_size(css.CSSPixelSize.from_values(640, 480))
	assert model.viewport_size().width().to_double() == 640
	assert model.viewport_size().height().to_double() == 480
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(12, 18))
	assert model.viewport_scroll_offset().to_double_pair() == [12.0, 18.0]!
	assert model.snapshot_containing_block().left_value() == 12
	document.scroll_to_the_beginning_of_the_document()
	assert model.viewport_scroll_offset().to_double_pair() == [0.0, 0.0]!
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(12, 18))
	assert model.scroll_viewport_by_delta(css.CSSPixelPoint.from_values(-12, -18)).state() == .fulfilled
	assert model.viewport_scroll_offset().to_double_pair() == [0.0, 0.0]!

	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body) }
	mut visible_text_node := document.create_text_node('selected value').as_node()
	visible_text_node.set_layout_node(&dom.LayoutNode{})
	body_node.append_child(visible_text_node)!
	model.select_all()
	assert model.selected_text() == 'selected value'
	navigable_test_pastes = []
	model.set_paste_hook(navigable_test_paste)
	model.paste('clipboard')
	assert model.last_pasted_text() == 'clipboard'
	assert navigable_test_pastes == ['clipboard']

	navigable_test_observer_completions = 0
	navigable_test_observer_changes = 0
	mut observer := NavigationObserver.create(model.host_navigable())
	observer.set_navigation_complete(navigable_test_complete)
	observer.set_ongoing_navigation_changed(navigable_test_changed)
	model.register_navigation_observer(observer)
	model.set_ongoing_navigation(NavigableOngoingNavigation{ kind: .navigation, id: 'test' })
	model.set_ongoing_navigation(NavigableOngoingNavigation{})
	assert navigable_test_observer_changes == 2
	notify_navigation_complete(model.host_navigable())
	assert navigable_test_observer_completions == 1
	model.unregister_navigation_observer(observer)
	notify_navigation_complete(model.host_navigable())
	assert navigable_test_observer_completions == 1

	navigable_test_paints = 0
	navigable_test_screenshots = 0
	model.set_paint_hook(navigable_test_paint)
	model.set_screenshot_hook(navigable_test_screenshot)
	model.ready_to_paint()
	model.paint_next_frame()
	model.render_screenshot(dom.PaintConfig{})
	assert model.paint_count() == 2
	assert model.screenshot_count() == 1
	assert navigable_test_paints == 2
	assert navigable_test_screenshots == 1
	assert model.has_a_rendering_opportunity()
}

fn test_navigable_viewport_resize_grows_then_shrinks_device_backing_stores() {
	mut document := dom.Document.create(dom.URL{'https://example.test/'})
	document.set_origin(document.url.origin())
	document.populate_with_html_head_and_body()!
	page_model := page.Page.create(2.0)!
	document.set_page(unsafe { &dom.Page(page_model) })
	window := WindowModel.create_top_level(document, none, 'backing-store')!
	mut model := unsafe { &NavigableModel(window.navigable_model()) }
	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})

	model.set_viewport_size(css.CSSPixelSize.from_values(640, 480))
	mut manager := model.backing_store_manager()
	assert manager.allocated_size == painting.IntSize{1536, 1216}
	assert manager.front_bitmap_id == 1
	assert manager.back_bitmap_id == 2
	assert manager.resize_timer_is_active()
	assert manager.resize_timer_interval() == 3000
	assert model.rendering_thread().pending_command_count() == 1
	assert page_model.client().events.last().name == 'allocate-backing-stores'
	assert page_model.client().events.last().text == '1:2'

	manager.fire_resize_timer()
	assert !manager.resize_timer_is_active()
	assert manager.allocated_size == painting.IntSize{1280, 960}
	assert manager.front_bitmap_id == 3
	assert manager.back_bitmap_id == 4
	assert model.rendering_thread().pending_command_count() == 2
	assert page_model.client().events.last().text == '3:4'

	// An unchanged viewport is the source's early-return path: it neither grows
	// the stores nor restarts a timer that has already fired.
	model.set_viewport_size(css.CSSPixelSize.from_values(640, 480))
	assert !manager.resize_timer_is_active()
	assert model.rendering_thread().pending_command_count() == 2
}

fn test_navigable_fetch_redirect_policy_and_url_history_algorithms() {
	mut original_document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	navigable_test_fetches = 0
	model.set_navigation_fetch_hook(navigable_test_fetch)
	model.navigate(NavigableNavigateParams{
		url: dom.URL{ value: 'https://example.test/redirect' }
		source_document: original_document
	})!
	assert navigable_test_fetches == 2
	mut fetched_document := model.active_document() or { panic('missing fetched document') }
	assert fetched_document.url.serialize() == 'https://example.test/fetched'
	assert fetched_document.body() or { panic('missing body') }.as_node().text_content()? == 'fetched response'
	assert model.current_session_history_entry()?.url.serialize() == 'https://example.test/fetched'
	assert navigation_must_be_a_replace(dom.URL{ value: 'javascript:1' }, fetched_document)
	assert !navigation_must_be_a_replace(dom.URL{ value: 'https://example.test/next' }, fetched_document)

	perform_url_and_history_update_steps(fetched_document, dom.URL{
		value: 'https://example.test/fetched?state=1'
	}, SerializationRecord{ data: [u8(42)] }, .push)!
	assert fetched_document.url.serialize() == 'https://example.test/fetched?state=1'
	assert model.get_session_history_entries().len == 3
	assert model.current_session_history_entry()?.classic_history_api_state.data == [
		u8(42),
	]
	assert fetched_document.history().index == 1
	assert fetched_document.history().length == 2

	response_container := &PolicyContainer{
		referrer_policy: .origin
	}
	initiator_container := &PolicyContainer{
		referrer_policy: .no_referrer
	}
	local_policy := determine_navigation_params_policy_container(dom.URL{
		value: 'data:text/html,hello'
	}, none, initiator_container, none, response_container)
	assert local_policy.referrer_policy == .no_referrer
	history_container := &PolicyContainer{
		referrer_policy: .same_origin
	}
	history_policy := determine_navigation_params_policy_container(dom.URL{
		value: 'https://example.test/'
	}, history_container, initiator_container, none, response_container)
	assert history_policy.referrer_policy == .same_origin

	srcdoc_state := &DocumentState{
		origin: fetched_document.origin()
		resource: '<p>srcdoc</p>'
	}
	srcdoc_entry := &SessionHistoryEntry{
		url: dom.URL{ value: 'about:srcdoc' }
		document_state: srcdoc_state
	}
	srcdoc_params := create_navigation_params_from_a_srcdoc_resource(srcdoc_entry, model, TargetSnapshotParams{}, .none, none)!
	assert srcdoc_params.response.fetch_response_body()?.bytes().bytestr() == '<p>srcdoc</p>'
	assert srcdoc_params.response.header_list.get('Content-Type')? == 'text/html'
}

fn test_navigation_does_not_install_response_after_navigable_destruction() {
	mut original_document, _, model_pointer := navigable_test_top_level('https://example.test/start', 'top')!
	mut model := unsafe { &NavigableModel(model_pointer) }
	navigable_test_destroy_during_fetch = model
	model.set_navigation_fetch_hook(navigable_test_fetch_and_destroy)
	model.navigate(NavigableNavigateParams{
		url: dom.URL{ value: 'https://example.test/fetched' }
		source_document: original_document
	})!
	navigable_test_destroy_during_fetch = unsafe { nil }

	assert model.has_been_destroyed()
	assert model.active_document()? == original_document
	assert model.get_session_history_entries().len == 1
}
