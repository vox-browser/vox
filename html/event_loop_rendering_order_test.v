module html

import dom
import page

@[heap]
struct RenderingOrderLog {
mut:
	entries []string
	painted []&dom.Document
	times []f64
}

fn rendering_order_window(label string) (&dom.Document, &WindowModel, &page.Page) {
	mut document := parse_document('<!doctype html><body></body>')
	mut window := WindowModel.create_top_level(document, none, label) or { panic(err) }
	mut page_ := page.Page.create(1) or { panic(err) }
	document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(window.navigable() or { panic('missing navigable') }) or { panic(err) }
	document.update_the_visibility_state(.visible)
	return document, window, page_
}

fn rendering_order_listen(target &dom.EventTarget, type_ string, name string, log &RenderingOrderLog) {
	target.add_event_listener_without_options(type_, dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [name, log] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut state := unsafe { &RenderingOrderLog(log) }
			state.entries << name
			return dom.js_undefined()
		}
	}))
}

fn test_rendering_runs_each_stage_for_all_documents_before_the_next_stage() {
	mut event_loop := EventLoop.create(.window)
	mut log := &RenderingOrderLog{}
	mut parent, parent_window, _ := rendering_order_window('parent')
	mut child, child_window, _ := rendering_order_window('child')
	defer {
		parent.finalize()
		child.finalize()
	}
	mut child_nav := child.navigable() or { panic('missing child navigable') }
	child_nav.container_document_ = parent
	event_loop.register_document(child)
	event_loop.register_document(parent)
	rendering_order_listen(unsafe { &dom.EventTarget(parent_window) }, 'resize', 'resize-parent', log)
	rendering_order_listen(unsafe { &dom.EventTarget(child_window) }, 'resize', 'resize-child', log)
	rendering_order_listen(unsafe { &dom.EventTarget(parent) }, 'scroll', 'scroll-parent', log)
	rendering_order_listen(unsafe { &dom.EventTarget(child) }, 'scroll', 'scroll-child', log)
	parent.last_viewport_size = [0, 0]!
	child.last_viewport_size = [0, 0]!
	parent.set_viewport_rect(dom.Rect{0, 0, 100, 100})
	child.set_viewport_rect(dom.Rect{0, 0, 50, 50})
	parent.pending_scroll_events << dom.PendingScrollEvent{target: parent.as_node(), type_: 'scroll'}
	child.pending_scroll_events << dom.PendingScrollEvent{target: child.as_node(), type_: 'scroll'}
	event_loop.update_the_rendering()
	assert log.entries == ['resize-parent', 'resize-child', 'scroll-parent', 'scroll-child']
}

fn test_rendering_filters_view_transition_suppression_and_actual_page_opportunities() {
	mut event_loop := EventLoop.create(.window)
	mut log := &RenderingOrderLog{}
	mut document, window, page_ := rendering_order_window('rendering-gate')
	defer { document.finalize() }
	event_loop.register_document(document)
	event_loop.set_rendering_hook(fn [mut log] (documents []&dom.Document, _ f64) {
		log.painted = documents.clone()
	})
	mut client := page_.client()
	client.set_manual_rendering_opportunities(true)
	assert !window.navigable_model().has_a_rendering_opportunity()
	assert !event_loop.rendering_opportunity(150, false)
	event_loop.update_the_rendering()
	assert log.painted.len == 0
	client.request_frame()
	client.inject_rendering_opportunity(150)
	assert window.navigable_model().has_a_rendering_opportunity()
	document.rendering_suppression_for_view_transitions = true
	event_loop.update_the_rendering()
	assert log.painted.len == 0
	assert !client.has_rendering_opportunity()
	document.rendering_suppression_for_view_transitions = false
	client.request_frame()
	client.inject_rendering_opportunity(160)
	event_loop.update_the_rendering()
	assert log.painted == [document]
	assert !client.has_rendering_opportunity()
}

fn test_animation_frame_timestamps_use_each_document_time_origin_and_clamp_before_origin() {
	mut event_loop := EventLoop.create(.window)
	mut log := &RenderingOrderLog{}
	mut first, mut first_window, _ := rendering_order_window('first-origin')
	mut second, mut second_window, _ := rendering_order_window('second-origin')
	defer {
		first.finalize()
		second.finalize()
	}
	// Window's time origin follows its current associated Document.
	first.load_timing_info.navigation_start_time = 100
	second.load_timing_info.navigation_start_time = 200
	event_loop.register_document(first)
	event_loop.register_document(second)
	first_window.request_animation_frame(fn [mut log] (now f64) { log.times << now })
	second_window.request_animation_frame(fn [mut log] (now f64) { log.times << now })
	event_loop.last_render_opportunity_time_ = 150.59
	event_loop.update_the_rendering()
	assert log.times == [50.5, 0.0]
	assert first.last_animation_frame_timestamp? == 50.5
	assert second.last_animation_frame_timestamp? == 0
}

fn test_display_opportunity_timestamps_reject_future_frames_and_preserve_monotonicity() {
	mut event_loop := EventLoop.create(.window)
	before := unsafe_shared_current_time_ms()
	event_loop.rendering_opportunity(before + 100_000, false)
	after := unsafe_shared_current_time_ms()
	assert event_loop.last_render_opportunity_time_ >= before
	assert event_loop.last_render_opportunity_time_ <= after
	clamped := event_loop.last_render_opportunity_time_
	event_loop.rendering_opportunity(before - 100, false)
	assert event_loop.last_render_opportunity_time_ == clamped
}
