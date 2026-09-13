module page

import compositor
import dom

struct PageScreenshotHarness {
mut:
	repaint_count int
	render_count  int
	configs       []dom.PaintConfig
	bytes         []u8
}

fn page_screenshot_set_needs_repaint(target voidptr) {
	mut harness := unsafe { &PageScreenshotHarness(target) }
	harness.repaint_count++
}

fn page_screenshot_render(target voidptr, config dom.PaintConfig, _ ?dom.UniqueNodeID) []u8 {
	mut harness := unsafe { &PageScreenshotHarness(target) }
	harness.render_count++
	harness.configs << config
	return harness.bytes.clone()
}

fn test_page_identity_geometry_dialogs_and_clipboard_correlation() {
	mut p := Page.create(2)!
	p.set_top_level_traversable('top')!
	assert p.top_level_traversable() == 'top'
	assert p.focused_navigable() == 'top'
	mut replacement_failed := false
	p.set_top_level_traversable('replacement') or {
		replacement_failed = true
		assert err.msg().contains('replacement')
	}
	assert replacement_failed
	assert p.device_to_css_point(PixelPoint{ x: 5, y: 8 }) == PixelPoint{
		x: 2.5
		y: 4
	}
	assert p.enclosing_device_rect(PixelRect{ x: 1.2, y: 2.7, width: 3.1, height: 4.2 }) == PixelRect{
		x:      2
		y:      5
		width:  7
		height: 9
	}

	assert p.request_dialog(.confirm, 'Continue?', '')
	assert !p.request_dialog(.alert, 'busy', '')
	assert p.close_dialog(false, none)
	assert p.pending_dialog_response() or { '' } == 'false'
	assert p.request_non_blocking_dialog(.file_picker, 'input-7')
	assert p.close_non_blocking_dialog(.select) == none
	assert p.close_non_blocking_dialog(.file_picker) or { '' } == 'input-7'
	p.set_user_style('body { color: green; }')
	assert p.user_style()? == 'body { color: green; }'

	first := p.request_clipboard_entries()
	second := p.request_clipboard_entries()
	assert first == 0 && second == 1
	assert p.retrieved_clipboard_entries(second)
	assert !p.retrieved_clipboard_entries(second)
}

fn test_dom_document_notifications_reach_the_translated_page_client() {
	mut model := Page.create(1.0)!
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_page(unsafe { &dom.Page(model) })
	assert model.client().events.last().name == 'create-new-document'
	assert model.client().events.last().text == 'https://example.test/'

	document.increment_number_of_things_delaying_the_load_event()
	assert model.client().events.last().name == 'update-resource-count'
	assert model.client().events.last().text == '1'

	mut dom_page := unsafe { &dom.Page(model) }
	dom_page.client_page_did_change_title('Translated title')
	assert model.client().events.last().name == 'change-title'
	assert model.client().events.last().text == 'Translated title'
}

fn test_context_menu_request_is_replaced_and_taken_once() {
	mut model := Page.create(1.0)!
	mut document := dom.Document.create_for_fragment_parsing()
	first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'a')!
	second := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img')!
	model.record_context_menu_request(ContextMenuRequest{
		kind: .link
		target: first.as_node()
	})
	model.record_context_menu_request(ContextMenuRequest{
		kind: .image
		target: second.as_node()
	})
	request := model.take_context_menu_request() or { panic('missing request') }
	assert request.kind == .image
	assert voidptr(request.target) == voidptr(second.as_node())
	assert model.take_context_menu_request() == none
	model.record_context_menu_request(ContextMenuRequest{
		target: first.as_node()
	})
	model.clear_context_menu_request()
	assert model.take_context_menu_request() == none
}

fn test_screen_wake_lock_notifies_only_on_active_state_transitions() {
	mut model := Page.create(1.0)!
	model.acquire_screen_wake_lock()
	model.acquire_screen_wake_lock()
	assert model.is_screen_wake_lock_active()
	assert model.client().events.map(it.name) == ['change-screen-wake-lock-state']
	assert model.client().events.last().text == 'acquired'
	model.release_screen_wake_lock()
	assert model.client().events.len == 1
	model.release_screen_wake_lock()
	assert !model.is_screen_wake_lock_active()
	assert model.client().events.last().text == 'released'

	mut handle := ScreenWakeLockHandle.create(mut model)
	assert handle.is_active()
	assert model.is_screen_wake_lock_active()
	handle.release()
	handle.release()
	assert !handle.is_active()
	assert !model.is_screen_wake_lock_active()
}

fn test_document_work_requests_frames_on_demand() {
	mut model := Page.create(1.0)!
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_page(unsafe { &dom.Page(model) })
	mut client := model.client()
	client.events.clear()

	document.update_readiness(.interactive)
	assert client.events.last().name == 'request-frame'
	client.events.clear()

	document.set_needs_animated_style_update()
	assert client.events.map(it.name) == ['request-frame']
	// Repeated animation invalidation is coalesced until the update is consumed.
	document.set_needs_animated_style_update()
	assert client.events.map(it.name) == ['request-frame']
	client.events.clear()

	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut element_node := element.as_node()
	element_node.set_needs_style_update(true)
	assert client.events.last().name == 'request-frame'
	assert document.needs_repaint
	client.events.clear()
	document.needs_repaint = false
	element_node.set_needs_layout_tree_update(true, .node_insert_before)
	assert client.events.last().name == 'request-frame'
	assert document.needs_repaint
	client.events.clear()

	document.add_render_blocking_element(element)
	document.remove_render_blocking_element(element)
	assert client.events.last().name == 'request-frame'
	client.events.clear()
	document.append_pending_fullscreen_change(.change, element)
	assert client.events.last().name == 'request-frame'
	client.events.clear()
	document.set_rendering_suppression_for_view_transitions(true)
	assert client.events.len == 0
	document.set_rendering_suppression_for_view_transitions(false)
	assert client.events.last().name == 'request-frame'
}

fn test_media_registry_and_find_in_page_wrap_rules() {
	mut p := Page.create(1)!
	p.set_top_level_traversable('top')!
	p.load('https://example.test/')
	p.documents = [
		SearchDocument{
			id:   'main'
			text: 'One fish, two FISH.'
		},
		SearchDocument{
			id:   'frame'
			text: 'fish'
		},
	]
	result := p.find_in_page(FindInPageQuery{ string_: 'fish' })
	assert result.total_match_count or { 0 } == 3
	assert result.current_match_index == 0
	assert p.find_in_page_previous_match().current_match_index == 2
	assert p.find_in_page_next_match().current_match_index == 0
	assert p.selected_match or { FindMatch{} }.document_id == 'main'

	p.register_media_element(10, MediaElementState{ playing: true })
	p.update_all_media_element_video_sinks()
	assert p.client().events.last().name == 'request-frame'
	assert p.request_media_context_menu(10)
	assert p.toggle_media_property('play')
	assert !p.media_elements[10].playing
	assert p.toggle_media_property('controls')
	assert p.media_elements[10].controls
	p.toggle_page_mute_state()
	assert p.page_mute_state() == .muted
	assert p.media_elements[10].page_mute_change_count == 1
	p.set_page_mute_state(.muted)
	assert p.media_elements[10].page_mute_change_count == 1
}

fn test_page_runtime_preferences_and_user_style_invalidation() {
	mut p := Page.create(1)!
	mut client := p.client()
	client.preferred_color_scheme_ = 'light'
	assert p.preferred_color_scheme() == 'light'
	p.set_preferred_color_scheme_override_for_testing('dark')
	assert p.preferred_color_scheme() == 'dark'
	p.set_preferred_color_scheme_override_for_testing(none)
	assert p.preferred_color_scheme() == 'light'

	assert p.enable_primary_paste()
	p.set_enable_primary_paste(false)
	assert !p.enable_primary_paste()
	assert !p.async_scrolling_enabled()
	p.set_async_scrolling_enabled(true)
	assert p.async_scrolling_enabled()

	mut document := dom.Document.create_for_fragment_parsing()
	document.set_page(unsafe { &dom.Page(p) })
	initial_environment := document.style_environment_version()
	p.set_user_style('body { color: green; }')
	assert document.style_environment_version() == initial_environment + 1
	assert document.needs_full_style_update()
	assert document.page().user_style()? == 'body { color: green; }'
	p.set_user_style('')
	assert p.user_style() == none

	document.set_needs_full_style_update(false)
	p.invalidate_style_for_preference_change()
	assert document.style_environment_version() == initial_environment + 3
	assert document.needs_full_style_update()
}

fn test_page_compositor_host_and_wheel_listener_generation() {
	mut p := Page.create(1)!
	p.ensure_compositor_host()
	assert !p.has_compositor_host()

	mut client := p.client()
	client.compositor_supported_ = true
	p.ensure_compositor_host()
	assert p.has_compositor_host()
	mut host := p.compositor_host()
	context := host.create_context(compositor.CompositorContextId(73))!
	p.set_compositor_context(context)

	p.invalidate_compositor_wheel_event_listener_state()
	assert p.wheel_event_listener_state_generation() == 1
	assert !host.call_log().contains('invalidate_wheel_event_listener_state:73:1')

	p.set_top_level_traversable('root')!
	p.set_async_scrolling_enabled(true)
	p.invalidate_compositor_wheel_event_listener_state()
	assert p.wheel_event_listener_state_generation() == 2
	assert host.call_log().contains('invalidate_wheel_event_listener_state:73:2')
}

fn test_page_beforeunload_check_tracks_attached_window_listeners() {
	mut p := Page.create(1)!
	mut document := dom.Document.create_for_fragment_parsing()
	mut window := &dom.Window{}
	document.set_window(window)
	mut navigable := &dom.Navigable{
		is_top_level_traversable_: true
	}
	navigable.set_active_document(document)
	document.set_page(unsafe { &dom.Page(p) })
	assert p.needs_beforeunload_check()

	p.set_local_root_navigable(navigable)!
	assert p.has_local_root_navigable()
	assert voidptr(p.local_root_navigable()) == voidptr(navigable)
	assert !p.needs_beforeunload_check()
	assert p.client().events.last().name == 'change-needs-beforeunload-check'
	assert p.client().events.last().text == 'false'

	callback := &dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			return dom.js_undefined()
		}
	}
	mut event_target := unsafe { &dom.EventTarget(window) }
	event_target.set_event_handler_attribute('beforeunload', callback)
	p.update_needs_beforeunload_check()
	assert p.needs_beforeunload_check()
	assert p.client().events.last().text == 'true'

	mut replacement_rejected := false
	p.set_local_root_navigable(&dom.Navigable{}) or {
		replacement_rejected = true
	}
	assert replacement_rejected
}

fn test_page_screenshot_queue_renders_valid_targets_and_reports_failures() {
	mut p := Page.create(1)!
	mut document := dom.Document.create_for_fragment_parsing()
	root_layout := &dom.LayoutNode{}
	document.set_layout_viewport(&dom.LayoutViewport{
		root_node: root_layout
	})
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	target_layout := &dom.LayoutNode{
		paintables_: [&dom.Paintable{}]
		border_box_: dom.Rect{4, 5, 60, 30}
	}
	mut target_node := target.as_node()
	target_node.set_layout_node(target_layout)

	mut harness := &PageScreenshotHarness{
		bytes: [u8(1), 2, 3, 4]
	}
	mut navigable := &dom.Navigable{
		html_model_handle_: voidptr(harness)
		set_needs_repaint_callback_: page_screenshot_set_needs_repaint
		render_screenshot_callback_: page_screenshot_render
	}
	navigable.set_active_document(document)
	p.set_local_root_navigable(navigable)!
	mut client := p.client()
	client.events.clear()

	p.queue_screenshot_task(target.as_node().unique_id())
	p.queue_screenshot_task(dom.UniqueNodeID(0))
	p.queue_screenshot_task(none)
	assert harness.repaint_count == 3
	assert client.events.filter(it.name == 'request-frame').len == 3

	p.process_screenshot_requests()
	assert harness.render_count == 2
	assert harness.configs[0].canvas_fill_rect == dom.Rect{4, 5, 60, 30}
	assert harness.configs[1].paint_overlay
	assert client.screenshots == [[u8(1), 2, 3, 4], []u8{}, [u8(1), 2, 3, 4]]
	p.process_screenshot_requests()
	assert harness.render_count == 2
}

fn test_find_navigation_resets_on_document_url_change_but_not_fragment_change() {
	mut p := Page.create(1)!
	p.set_top_level_traversable('top')!
	p.load('https://example.test/first')
	p.documents = [SearchDocument{ id: 'first', text: 'x x x' }]
	p.find_in_page(FindInPageQuery{ string_: 'x' })
	assert p.find_in_page_next_match().current_match_index == 1

	// Fragments are excluded from the URL comparison, matching Page.cpp.
	p.load('https://example.test/first#section')
	assert p.find_in_page_next_match().current_match_index == 2

	p.load('https://example.test/second')
	p.documents = [SearchDocument{ id: 'second', text: 'x x' }]
	result := p.find_in_page_next_match()
	assert result.current_match_index == 0
	assert (p.selected_match or { panic('missing selection') }).document_id == 'second'
}

fn test_fullscreen_queue_waits_for_ui_and_preserves_fifo() {
	mut p := Page.create(1)!
	enter := p.enqueue_fullscreen_enter('doc', 'video', 'doc', true, '')
	assert enter.state == .pending
	assert p.client_events.last().name == 'request-fullscreen-window'
	p.set_viewport_is_fullscreen(true)
	assert p.viewport_is_fullscreen()
	assert enter.state == .fulfilled

	exit_promise := p.enqueue_fullscreen_exit('doc', true)
	assert exit_promise.state == .pending
	assert p.client_events.last().name == 'request-exit-fullscreen'
	p.set_viewport_is_fullscreen(false)
	assert !p.viewport_is_fullscreen()
	assert exit_promise.state == .fulfilled

	bad := p.enqueue_fullscreen_enter('doc', 'x', 'other-doc', true, 'already-failed')
	assert bad.state == .rejected
	assert bad.error == 'already-failed'
}
