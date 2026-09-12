module page

import dom
import painting

struct TestChromeWidgetCallbacks {
mut:
	pointer_events []string
	hover_events   []string
}

fn chrome_widget_test_pointer_callback(target voidptr, widget string, event_type string,
	_ int, _ PixelPoint) painting.MouseAction {
	mut state := unsafe { &TestChromeWidgetCallbacks(target) }
	state.pointer_events << '${widget}:${event_type}'
	if widget == 'scrollbar' && event_type == 'pointerdown' {
		return .capture_input
	}
	if widget == 'scrollbar' && event_type == 'pointermove' {
		return .capture_input_and_swallow_event
	}
	if widget == 'scrollbar' && event_type == 'pointerup' {
		return .swallow_event
	}
	return .none
}

fn chrome_widget_test_hover_callback(target voidptr, widget string, hovered bool) {
	mut state := unsafe { &TestChromeWidgetCallbacks(target) }
	state.hover_events << '${if hovered { 'enter' } else { 'leave' }}:${widget}'
}

fn test_auto_scroll_edges_speed_fraction_and_text_control_constraint() {
	viewport := PixelRect{
		x: 0
		y: 0
		width: 200
		height: 100
	}
	scrollport := PixelRect{
		x: 0
		y: 0
		width: 200
		height: 100
	}
	edge := effective_auto_scroll_edge(scrollport, viewport)
	assert edge == PixelRect{
		x: 32
		y: 32
		width: 136
		height: 36
	}
	assert auto_scroll_speed(PixelPoint{ x: -100, y: 50 }, edge).x == -5000

	mut handler := AutoScrollHandler{}
	selection := handler.process(PixelPoint{ x: 250, y: -10 }, scrollport, viewport, true)
	assert handler.is_active()
	assert selection == PixelPoint{
		x: 200
		y: 0
	}
	tick := handler.perform_tick(scrollport, viewport, true, true, true) or {
		panic('expected tick')
	}
	assert tick.delta_x == 80
	assert tick.delta_y == -67
	assert tick.selection_position == PixelPoint{
		x: 200
		y: 0
	}
	handler.perform_tick(scrollport, viewport, false, true, true)
	assert !handler.is_active()
}

fn test_middle_button_autoscroll_activation_dead_zone_and_cancellation() {
	mut handler := EventHandler{}
	target := InputTarget{ id: 'scroller', has_scrollable_box: true }
	origin := PixelPoint{ x: 50, y: 50 }
	assert handler.handle_mousedown_with_button(target, origin, 1, 1, true) == .handled
	assert handler.middle_button_scroll_handler() != none
	assert handler.handle_mouseup_with_button(target, 1) == .handled
	assert handler.middle_button_scroll_handler() != none
	assert handler.event_log.map(it.name).last() == 'click'

	// A second press toggles autoscroll off.
	assert handler.handle_mousedown_with_button(target, origin, 1, 1, true) == .handled
	assert handler.middle_button_scroll_handler() == none
	handler.handle_mouseup_with_button(target, 1)

	handler.event_log.clear()
	handler.handle_mousedown_with_button(target, origin, 1, 1, true)
	handler.handle_mousemove(target, PixelPoint{ x: 75, y: 50 })
	tick := handler.process_auto_scroll(PixelRect{}, PixelRect{}, false, false, false) or {
		panic('expected middle-button scroll tick')
	}
	assert tick.delta_x == 2
	assert tick.delta_y == 0
	assert handler.middle_button_scroll_handler()?.mouse_has_moved_beyond_dead_zone()
	handler.handle_mouseup_with_button(target, 1)
	assert handler.middle_button_scroll_handler() == none
	assert 'click' !in handler.event_log.map(it.name)

	handler.handle_mousedown_with_button(target, origin, 1, 1, true)
	assert handler.middle_button_scroll_handler() != none
	assert handler.handle_keydown(27, 0, 0, false, false) == .handled
	assert handler.middle_button_scroll_handler() == none
	assert handler.handle_mousedown_with_button(target, origin, 1, 1, false) == .handled
	assert handler.middle_button_scroll_handler() == none
	assert handler.handle_mousedown_with_button(InputTarget{
		id: 'link'
		is_link: true
		has_scrollable_box: true
	}, origin, 1, 1, true) == .handled
	assert handler.middle_button_scroll_handler() == none
}

fn test_page_autoscroll_setting_controls_middle_button_activation() {
	mut model := Page.create(1)!
	target := InputTarget{ id: 'scroller', has_scrollable_box: true }
	model.set_enable_autoscroll(false)
	assert !model.enable_autoscroll()
	model.handle_mousedown(target, PixelPoint{ x: 20, y: 20 }, 1, 1, 0, 1)
	assert model.event_handler.middle_button_scroll_handler() == none
	model.handle_mouseup(target, PixelPoint{}, 1, 0, 0)

	model.set_enable_autoscroll(true)
	assert model.enable_autoscroll()
	model.handle_mousedown(target, PixelPoint{ x: 20, y: 20 }, 1, 1, 0, 1)
	assert model.event_handler.middle_button_scroll_handler() != none
}

fn test_resize_axes_writing_mode_constraints_and_content_box() {
	action := ElementResizeAction{
		pointer_down_origin: PixelPoint{
			x: 50
			y: 50
		}
		initial_border_size: PixelSize{
			width: 100
			height: 80
		}
	}
	size := action.handle_pointer_move(PixelPoint{ x: 80, y: 90 }, ResizeConstraints{
		mode: .both
		min_width: 120
		max_height: 100
		content_box: true
		horizontal_noncontent: 20
		vertical_noncontent: 10
	}) or { panic('expected size') }
	assert size == PixelSize{
		width: 110
		height: 90
	}

	rtl := action.handle_pointer_move(PixelPoint{ x: 70, y: 90 }, ResizeConstraints{
		mode: .inline
		rtl: true
	}) or { panic('expected RTL resize') }
	assert rtl.width == 80
	assert rtl.height == 80
	assert action.handle_pointer_move(PixelPoint{}, ResizeConstraints{}) == none
}

fn test_drag_and_drop_modes_effect_negotiation_and_reset() {
	mut handler := DragAndDropEventHandler{}
	assert handler.handle_drag_start([SelectedFile{ name: 'a.bin' }], false, .copy_move) == .handled
	assert handler.has_ongoing_drag_and_drop_operation()
	assert handler.items()[0].type_ == 'application/octet-stream'
	assert handler.event_log[0].mode == .read_write

	target := DragTarget{
		id: 'editor'
		allows_text_drop: true
	}
	assert handler.handle_drag_move(target, false, false, true, .move) == .handled
	assert handler.current_operation() == .move
	assert handler.handle_drag_end(false, true, .move) == .handled
	assert !handler.has_ongoing_drag_and_drop_operation()
	assert handler.items().len == 0
	assert handler.event_log.map(it.name) == ['dragstart', 'drag', 'dragenter', 'dragover', 'drop',
		'dragend']
}

fn test_event_handler_drops_input_during_drag_and_orders_pointer_mouse_click() {
	mut handler := EventHandler{}
	target := InputTarget{
		id: 'button'
		is_focusable: true
		is_editable: true
	}
	assert handler.handle_mousedown(target, 1) == .handled
	assert handler.handle_mouseup(target) == .handled
	assert handler.event_log.map(it.name) == ['pointerdown', 'mousedown', 'pointerup', 'mouseup',
		'click']

	assert handler.drag_and_drop.handle_drag_start([], false, .all) == .handled
	assert handler.handle_mousemove(target, PixelPoint{}) == .dropped
	assert handler.drag_and_drop.handle_drag_end(true, false, .none) == .cancelled

	handler.event_log.clear()
	assert handler.handle_keydown(65, u32(`a`), 0, false, false) == .handled
	assert handler.event_log.map(it.name) == ['keydown', 'keypress', 'beforeinput', 'input']
}

fn test_event_handler_pointer_cancellation_and_mouseup_cleanup_match_upstream() {
	mut handler := EventHandler{}
	cancelled_pointer := InputTarget{
		id: 'button'
		is_focusable: true
		cancel_pointer: true
	}
	assert handler.handle_mousedown(cancelled_pointer, 1) == .cancelled
	assert handler.event_log.map(it.name) == ['pointerdown']

	// A cancelled pointerdown suppresses compatibility mouse events until
	// pointerup, but the press target remains eligible for click dispatch.
	assert handler.handle_mouseup(InputTarget{ id: 'button' }) == .handled
	assert handler.event_log.map(it.name) == ['pointerdown', 'pointerup', 'click']

	handler.event_log.clear()
	assert handler.handle_mousedown(InputTarget{ id: 'editor' }, 1) == .handled
	handler.start_selection(.character)
	// A press followed by release outside the hit-tested content is delivered
	// at the document fallback target so the page can finish a drag.
	assert handler.handle_mouseup(none) == .handled
	assert !handler.is_handling_mouse_selection()
	// Mouseup cleanup cleared the preceding press target/click count.
	assert handler.handle_mouseup(InputTarget{ id: 'editor' }) == .dropped
	assert 'click' !in handler.event_log.map(it.name)

	handler.event_log.clear()
	assert handler.handle_mousedown(InputTarget{ id: 'field' }, 1) == .handled
	assert handler.handle_mouseup(InputTarget{ id: 'field', cancel_mouse: true }) == .handled

	handler.event_log.clear()
	assert handler.handle_mousedown(InputTarget{ id: 'drag-source' }, 1) == .handled
	assert handler.handle_mouseup(none) == .handled
	assert handler.event_log.map(it.name) == ['pointerdown', 'mousedown', 'pointerup', 'mouseup']

	handler.event_log.clear()
	assert handler.handle_mousedown(InputTarget{ id: 'zero-click' }, 0) == .handled
	assert handler.handle_mouseup(InputTarget{ id: 'zero-click' }) == .dropped
	assert handler.event_log.map(it.name) == ['pointerdown', 'mousedown']
}

fn test_prevented_mouse_events_and_dragstart_stop_drag_candidate_tracking() {
	origin := PixelPoint{ x: 10, y: 10 }
	drag_position := PixelPoint{ x: 16, y: 10 }

	mut cancelled_mousedown := EventHandler{}
	assert cancelled_mousedown.handle_mousedown_with_button(InputTarget{
		id: 'cancelled-mousedown'
		cancel_mouse: true
	}, origin, 0, 1, false) == .cancelled
	assert cancelled_mousedown.handle_mousemove(InputTarget{
		id: 'cancelled-mousedown'
	}, drag_position) == .handled
	assert cancelled_mousedown.drag_and_drop.event_log.len == 0

	mut cancelled_dragstart := EventHandler{}
	drag_source := InputTarget{
		id: 'cancelled-dragstart'
		cancel_drag_start: true
	}
	assert cancelled_dragstart.handle_mousedown_with_button(drag_source, origin, 0, 1, false) == .handled
	assert cancelled_dragstart.handle_mousemove(drag_source, drag_position) == .handled
	assert cancelled_dragstart.drag_and_drop.event_log.map(it.name) == ['dragstart']
	assert cancelled_dragstart.handle_mousemove(drag_source, PixelPoint{ x: 20, y: 10 }) == .handled
	assert cancelled_dragstart.drag_and_drop.event_log.map(it.name) == ['dragstart']
}

fn test_primary_press_starts_drag_only_after_threshold_and_ends_on_mouseup() {
	mut handler := EventHandler{}
	drag_source := InputTarget{
		id: 'drag-source'
		is_editable: true
	}
	assert handler.handle_mousedown_with_button(drag_source, PixelPoint{ x: 10, y: 10 }, 0, 1, false) == .handled
	assert handler.handle_mousemove(drag_source, PixelPoint{ x: 14, y: 14 }) == .handled
	assert handler.drag_and_drop.event_log.len == 0
	assert handler.handle_mousemove(drag_source, PixelPoint{ x: 15, y: 14 }) == .handled
	assert handler.drag_and_drop.event_log.map(it.name) == ['dragstart']
	assert handler.handle_mousemove(drag_source, PixelPoint{ x: 16, y: 14 }) == .handled
	assert handler.drag_and_drop.event_log.map(it.name) == ['dragstart', 'drag', 'dragenter',
		'dragover']
	assert handler.handle_mouseup_with_button(drag_source, 0) == .cancelled
	assert handler.drag_and_drop.event_log.map(it.name) == ['dragstart', 'drag', 'dragenter',
		'dragover', 'dragleave', 'dragend']
	assert !handler.drag_and_drop.has_ongoing_drag_and_drop_operation()

	mut secondary := EventHandler{}
	assert secondary.handle_mousedown_with_button(drag_source, PixelPoint{}, 2, 1, false) == .handled
	assert secondary.handle_mousemove(drag_source, PixelPoint{ x: 20 }) == .handled
	assert secondary.drag_and_drop.event_log.len == 0

	mut leaving := EventHandler{}
	assert leaving.handle_mousedown_with_button(drag_source, PixelPoint{}, 0, 1, false) == .handled
	assert leaving.handle_mousemove(drag_source, PixelPoint{ x: 5 }) == .handled
	assert leaving.handle_mouseleave() == .cancelled
	assert leaving.drag_and_drop.event_log.map(it.name) == ['dragstart', 'dragend']
}

fn test_event_handler_focus_traversal_starts_at_the_correct_end_and_honors_document_state() {
	candidates := [
		InputTarget{ id: 'ignored' },
		InputTarget{ id: 'first', is_focusable: true },
		InputTarget{ id: 'second', is_focusable: true },
	]
	mut next := EventHandler{}
	assert next.focus_next_element(candidates)
	assert next.focused_target_ == 'first'
	assert next.focus_next_element(candidates)
	assert next.focused_target_ == 'second'
	assert next.focus_next_element(candidates)
	assert next.focused_target_ == 'first'

	mut previous := EventHandler{}
	assert previous.focus_previous_element(candidates)
	assert previous.focused_target_ == 'second'
	previous.set_document_state(false, true)
	assert !previous.focus_previous_element(candidates)
}

fn test_event_handler_key_classification_matches_upstream_filters() {
	assert should_ignore_keydown_event(0, 0)
	assert should_ignore_keydown_event(27, 0)
	assert should_ignore_keydown_event(int(`a`), dom.modifier_ctrl)
	assert !should_ignore_keydown_event(int(`a`), dom.modifier_shift)
	assert produces_character_value(0, u32(`A`))
	assert produces_character_value(0, u32(`$`))
	assert !produces_character_value(0, u32(` `))
	assert !produces_character_value(0, u32(`\n`))
	assert is_enter_key_or_interoperable_enter_key_combo(13, 0)
	assert is_enter_key_or_interoperable_enter_key_combo(13, dom.modifier_ctrl)
	assert !is_enter_key_or_interoperable_enter_key_combo(13, dom.modifier_alt)

	mut handler := EventHandler{}
	handler.run_mousedown_default_actions(InputTarget{ id: 'button', is_focusable: true })
	assert handler.handle_keydown(65, u32(`a`), 0, false, false) == .accepted
	assert handler.event_log.map(it.name) == ['keydown', 'keypress']
	assert handler.handle_paste('text') == .dropped
	assert handler.handle_keyup(true, false) == .dropped
	assert handler.event_log.map(it.name) == ['keydown', 'keypress']
}

fn test_event_handler_input_event_dispatches_payload_and_target_ranges() {
	mut handler := EventHandler{}
	handler.run_mousedown_default_actions(InputTarget{
		id:            'editor'
		is_focusable:  true
		cancel_keyboard: true
	})
	handler.set_input_selection_range(SelectionRange{ start: 2, end: 5 })
	assert handler.input_event('beforeinput', 'insertText', u32(`A`)) == .cancelled
	dispatch := handler.event_log.last()
	assert dispatch.name == 'beforeinput'
	assert dispatch.target == 'editor'
	assert dispatch.input_type == 'insertText'
	assert dispatch.data? == 'A'
	assert dispatch.target_ranges == [SelectionRange{ start: 2, end: 5 }]

	handler.set_input_selection_range(SelectionRange{ start: 3, end: 3 })
	assert handler.input_event('input', 'insertLineBreak', u32(`\n`)) == .cancelled
	assert handler.event_log.last().data == none
	assert handler.event_log.last().target_ranges.len == 0

	mut fallback := EventHandler{}
	assert fallback.input_event('input', 'insertText', 'text') == .accepted
	assert fallback.event_log.last().target == ''
	assert fallback.event_log.last().data? == 'text'
	fallback.set_document_state(false, true)
	assert fallback.input_event('input', 'insertText', 'ignored') == .dropped
	assert fallback.event_log.len == 1
}

fn test_event_handler_translates_chrome_hover_capture_and_swallow_order() {
	mut callbacks := TestChromeWidgetCallbacks{}
	mut handler := EventHandler{}
	handler.install_chrome_widget_callbacks(voidptr(&callbacks), chrome_widget_test_pointer_callback, chrome_widget_test_hover_callback)

	handler.update_hovered_chrome_widget('scrollbar')
	handler.update_hovered_chrome_widget('scrollbar')
	handler.update_hovered_chrome_widget('resizer')
	handler.update_hovered_chrome_widget('')
	assert callbacks.hover_events == ['enter:scrollbar', 'leave:scrollbar', 'enter:resizer',
		'leave:resizer']

	assert handler.dispatch_chrome_widget_pointer_event('scrollbar', 'pointerdown', 0, PixelPoint{10, 20})
	assert handler.captured_chrome_widget == 'scrollbar'
	// Capture is dispatched before the currently hit widget. Returning both
	// flags keeps capture and suppresses the DOM-side default path immediately.
	assert !handler.dispatch_chrome_widget_pointer_event('resizer', 'pointermove', 9, PixelPoint{30, 40})
	assert handler.captured_chrome_widget == 'scrollbar'
	assert callbacks.pointer_events == ['scrollbar:pointerdown', 'scrollbar:pointermove']

	// Once the captured widget releases, the same event is also offered to the
	// current target, while its SwallowEvent result remains sticky.
	assert !handler.dispatch_chrome_widget_pointer_event('resizer', 'pointerup', 0, PixelPoint{30, 40})
	assert handler.captured_chrome_widget == ''
	assert callbacks.pointer_events == ['scrollbar:pointerdown', 'scrollbar:pointermove',
		'scrollbar:pointerup', 'resizer:pointerup']

	handler.update_hovered_chrome_widget('resizer')
	handler.update_cursor('pointer')
	handler.track_the_effective_position_of_the_legacy_mouse_pointer(PixelPoint{ x: 5, y: 6 })
	assert handler.handle_mouseleave() == .handled
	assert handler.hovered_chrome_widget == ''
	assert handler.current_cursor == 'arrow'
	assert handler.previous_screen == none
	assert callbacks.hover_events.last() == 'leave:resizer'
}

fn test_event_handler_cancelled_pointermove_suppresses_compatibility_mousemove() {
	mut handler := EventHandler{}
	target := InputTarget{ id: 'target', cancel_pointer: true }
	assert handler.handle_mousemove(target, PixelPoint{ x: 4, y: 5 }) == .cancelled
	assert handler.event_log.map(it.name) == ['pointermove']
}
