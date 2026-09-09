module page

fn test_upstream_page_client_and_page_state_entry_points() {
	mut p := Page.create(2)!
	mut client := p.client()
	assert client.is_url_suitable_for_same_process_navigation('https://a.test',
		'https://b.test')
	client.page_did_change_title('Title')
	client.page_did_request_resize_window(PixelSize{width: 800, height: 600})
	assert client.events.map(it.name) == ['change-title', 'request-resize-window']

	p.set_is_scripting_enabled(false)
	p.set_should_block_pop_ups(false)
	p.set_is_webdriver_active(true)
	p.set_is_hovering_link(true)
	p.set_is_in_tooltip_area(true)
	p.set_current_cursor('pointer')
	p.set_window_position(PixelPoint{x: 20, y: 40})
	p.set_window_size(PixelSize{width: 800, height: 600})
	assert !p.is_scripting_enabled()
	assert !p.should_block_pop_ups()
	assert p.is_webdriver_active()
	assert p.is_hovering_link()
	assert p.is_in_tooltip_area()
	assert p.current_cursor() == 'pointer'
	assert p.web_exposed_screen_area() == PixelRect{x: 10, y: 20, width: 400, height: 300}

	client.preferred_color_scheme_ = 'dark'
	client.preferred_contrast_ = 'more'
	client.preferred_motion_ = 'reduce'
	assert p.preferred_color_scheme() == 'dark'
	assert p.preferred_contrast() == 'more'
	assert p.preferred_motion() == 'reduce'
	client.preferred_color_scheme_ = 'auto'
	client.palette_is_dark_ = true
	assert p.palette() == 'dark'
	assert p.preferred_color_scheme() == 'dark'
	client.palette_is_dark_ = false
	assert p.preferred_color_scheme() == 'light'
	client.zoom_level_ = 2
	metrics := p.chrome_metrics()
	assert metrics.scroll_thumb_min_length == 12
	assert metrics.scroll_gutter_thickness == 6
	assert metrics.resize_gripper_size == 6
}

fn test_upstream_page_input_and_dialog_entry_points_route_existing_state_machines() {
	mut p := Page.create(1)!
	target := InputTarget{id: 'button', is_focusable: true}
	assert p.handle_mousedown(target, PixelPoint{}, 0, 1, 0, 1) == .handled
	assert p.handle_mouseup(target, PixelPoint{}, 0, 0, 0) == .handled
	assert p.event_handler.event_log.map(it.name) == ['pointerdown', 'mousedown', 'pointerup',
		'mouseup', 'click']
	assert p.request_dialog(.confirm, 'Continue?', '')
	assert p.has_pending_dialog()
	assert p.pending_dialog_text() or { '' } == 'Continue?'
	p.confirm_closed(true)
	assert !p.has_pending_dialog()
	assert p.pending_dialog_response() or { '' } == 'true'
}

fn test_upstream_event_helper_selection_focus_and_auto_scroll_entry_points() {
	assert find_paragraph_range('one\ntwo\nthree', 5) == SelectionRange{start: 4, end: 7}
	edge := compute_effective_auto_scroll_edge(PixelRect{x: 50, y: 50, width: 100, height: 100},
		PixelRect{width: 200, height: 200})
	assert compute_auto_scroll_speed(PixelPoint{x: 0, y: 100}, edge).x < 0

	mut handler := EventHandler{}
	handler.initiate_word_selection(PixelPoint{x: 2, y: 3})
	assert handler.is_handling_mouse_selection()
	assert handler.focus_next_element([
		InputTarget{id: 'first', is_focusable: true},
		InputTarget{id: 'second', is_focusable: true},
	])
	handler.track_the_effective_position_of_the_legacy_mouse_pointer(PixelPoint{x: 10, y: 10})
	assert handler.compute_mouse_event_movement(PixelPoint{x: 13, y: 8}) == PixelPoint{x: 3, y: -2}

	mut auto_scroll := AutoScrollHandler{}
	auto_scroll.activate(PixelPoint{x: 0, y: 50}, PixelRect{x: 25, y: 25, width: 100, height: 100},
		PixelRect{width: 200, height: 200}, false)
	assert auto_scroll.is_active()
}

fn test_upstream_drag_and_backing_store_entry_points() {
	mut drag := DragAndDropEventHandler{}
	assert drag.handle_drag_start([], false, .copy) == .handled
	drag.add_text_item('text')
	target := DragTarget{id: 'editable', allows_text_drop: true}
	assert drag.allow_text_drop(target)
	drag.fire_a_drag_and_drop_event('dragenter', target, none, true, .copy)
	assert drag.event_log.last().name == 'dragenter'

	mut store := SharedBackingStore.create([u8(1), 2, 3])
	assert store.bitmap() == [u8(1), 2, 3]
	assert store.release_iosurface_port()! == [u8(1), 2, 3]
}
