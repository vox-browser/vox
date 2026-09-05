module page

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
		x:      0
		y:      0
		width:  200
		height: 100
	}
	scrollport := PixelRect{
		x:      0
		y:      0
		width:  200
		height: 100
	}
	edge := effective_auto_scroll_edge(scrollport, viewport)
	assert edge == PixelRect{
		x:      32
		y:      32
		width:  136
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

fn test_resize_axes_writing_mode_constraints_and_content_box() {
	action := ElementResizeAction{
		pointer_down_origin: PixelPoint{
			x: 50
			y: 50
		}
		initial_border_size: PixelSize{
			width:  100
			height: 80
		}
	}
	size := action.handle_pointer_move(PixelPoint{ x: 80, y: 90 }, ResizeConstraints{
		mode:                  .both
		min_width:             120
		max_height:            100
		content_box:           true
		horizontal_noncontent: 20
		vertical_noncontent:   10
	}) or { panic('expected size') }
	assert size == PixelSize{
		width:  110
		height: 90
	}

	rtl := action.handle_pointer_move(PixelPoint{ x: 70, y: 90 }, ResizeConstraints{
		mode: .inline
		rtl:  true
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
		id:               'editor'
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
		id:           'button'
		is_focusable: true
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
	assert handler.event_log.map(it.name) == ['keydown', 'beforeinput', 'input']
}

fn test_event_handler_pointer_cancellation_and_mouseup_cleanup_match_upstream() {
	mut handler := EventHandler{}
	cancelled_pointer := InputTarget{
		id:             'button'
		is_focusable:   true
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
	assert handler.handle_mouseup(none) == .dropped
	assert !handler.is_handling_mouse_selection()
	// Early mouseup cleanup cleared the preceding press target/click count.
	assert handler.handle_mouseup(InputTarget{ id: 'editor' }) == .handled
	assert 'click' !in handler.event_log.map(it.name)

	handler.event_log.clear()
	assert handler.handle_mousedown(InputTarget{ id: 'field' }, 1) == .handled
	assert handler.handle_mouseup(InputTarget{ id: 'field', cancel_mouse: true }) == .handled
}

fn test_event_handler_translates_chrome_hover_capture_and_swallow_order() {
	mut callbacks := TestChromeWidgetCallbacks{}
	mut handler := EventHandler{}
	handler.install_chrome_widget_callbacks(voidptr(&callbacks),
		chrome_widget_test_pointer_callback, chrome_widget_test_hover_callback)

	handler.update_hovered_chrome_widget('scrollbar')
	handler.update_hovered_chrome_widget('scrollbar')
	handler.update_hovered_chrome_widget('resizer')
	handler.update_hovered_chrome_widget('')
	assert callbacks.hover_events == ['enter:scrollbar', 'leave:scrollbar', 'enter:resizer',
		'leave:resizer']

	assert handler.dispatch_chrome_widget_pointer_event('scrollbar', 'pointerdown', 0,
		PixelPoint{10, 20})
	assert handler.captured_chrome_widget == 'scrollbar'
	// Capture is dispatched before the currently hit widget. Returning both
	// flags keeps capture and suppresses the DOM-side default path immediately.
	assert !handler.dispatch_chrome_widget_pointer_event('resizer', 'pointermove', 9,
		PixelPoint{30, 40})
	assert handler.captured_chrome_widget == 'scrollbar'
	assert callbacks.pointer_events == ['scrollbar:pointerdown', 'scrollbar:pointermove']

	// Once the captured widget releases, the same event is also offered to the
	// current target, while its SwallowEvent result remains sticky.
	assert !handler.dispatch_chrome_widget_pointer_event('resizer', 'pointerup', 0,
		PixelPoint{30, 40})
	assert handler.captured_chrome_widget == ''
	assert callbacks.pointer_events == ['scrollbar:pointerdown', 'scrollbar:pointermove',
		'scrollbar:pointerup', 'resizer:pointerup']
}
