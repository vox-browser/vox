module page

import compositor
import dom

fn test_visual_viewport_pan_axes_and_scroll_box_routing() {
	viewport := VisualViewportScrollState{
		layout_width: 800
		layout_height: 600
		visual_width: 400
		visual_height: 300
		offset_left: 0
		offset_top: 100
	}
	axes := visual_viewport_pan_axes_for_scroll_step(viewport, -10, 20)
	assert !axes.x
	assert axes.y
	assert scrolling_box_for_scroll_step([
		ScrollBoxCandidate{ id: 'leaf' },
		ScrollBoxCandidate{ id: 'viewport', is_viewport: true, can_scroll_y: true },
	], PixelPoint{ y: 20 }, viewport) == none
	inner := scrolling_box_for_scroll_step([
		ScrollBoxCandidate{ id: 'inner', can_scroll_y: true },
		ScrollBoxCandidate{ id: 'viewport', is_viewport: true, can_scroll_y: true },
	], PixelPoint{ y: 20 }, viewport) or { panic('missing inner scroller') }
	assert inner.id == 'inner'
}

fn test_page_cursor_change_is_deduplicated() {
	mut model := Page.create(1)!
	set_page_cursor(mut model, 'pointer')
	set_page_cursor(mut model, 'pointer')
	assert model.current_cursor() == 'pointer'
	assert model.client().events.filter(it.name == 'request-cursor-change').len == 1
}

fn test_wheel_dispatch_preserves_cancelability_and_async_default_action() {
	mut handler := EventHandler{}
	target := InputTarget{
		id: 'scroller'
		cancel_mouse: true
		has_scrollable_box: true
	}
	assert handler.handle_mousewheel_with_parameters(target, PixelPoint{x: 3, y: 4},
		PixelPoint{x: 30, y: 40}, 0, 0, dom.modifier_shift, 5, 9, .discrete, .changed,
		false) == .cancelled
	event := handler.last_wheel_event() or { panic('missing wheel event') }
	assert event.delta_x == 9
	assert event.delta_y == 5
	assert event.cancelable

	assert handler.handle_mousewheel_with_parameters(target, PixelPoint{}, PixelPoint{}, 0, 0,
		0, 0, 8, compositor.WheelDeltaPrecision.precise, .momentum, true) == .handled
	async_event := handler.last_wheel_event() or { panic('missing async wheel event') }
	assert !async_event.cancelable
}

fn test_synthetic_pinch_dispatches_cancelable_ctrl_wheel() {
	mut handler := EventHandler{}
	assert handler.dispatch_synthetic_pinch_wheel_event(InputTarget{id: 'content'}, PixelPoint{},
		PixelPoint{}, dom.modifier_alt, -12) == .accepted
	event := handler.last_wheel_event() or { panic('missing synthetic wheel event') }
	assert event.delta_x == 0
	assert event.delta_y == -12
	assert event.modifiers & dom.modifier_ctrl != 0
	assert event.modifiers & dom.modifier_alt != 0
	assert event.cancelable
}

fn test_hover_after_scroll_uses_retained_mouse_target_unless_selecting() {
	mut handler := EventHandler{}
	target := InputTarget{ id: 'link', is_link: true }
	handler.record_last_known_mouse_position(PixelPoint{x: 1, y: 2}, PixelPoint{x: 3, y: 4},
		0, 0)
	handler.last_known_mouse_target_ = target
	handler.update_hover_after_scroll()
	assert handler.current_cursor == 'pointer'
	assert handler.event_log.last().name == 'hover-after-scroll'

	handler.event_log.clear()
	handler.mousedown_target_ = 'selection-anchor'
	handler.update_hover_after_scroll()
	assert handler.event_log.len == 0
}
