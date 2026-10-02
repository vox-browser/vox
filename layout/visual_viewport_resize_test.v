module layout

import css
import dom
import html
import highresolutiontime

@[heap]
struct VisualViewportResizeLog {
mut:
	targets    []voidptr
	timestamps []f64
}

fn visual_resize_callback(window &html.WindowModel, log &VisualViewportResizeLog) &dom.CallbackType {
	log_handle := voidptr(log)
	return &dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [log_handle] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			mut record := unsafe { &VisualViewportResizeLog(log_handle) }
			assert event.type_ == 'resize' && event.is_trusted()
			assert !event.bubbles() && !event.cancelable()
			record.targets << voidptr(current_target or { panic('currentTarget') })
			record.timestamps << event.time_stamp()
			assert voidptr(event.target() or { panic('target') }) == record.targets.last()
			return dom.js_undefined()
		}
	}
}

fn test_initial_visibility_seeds_both_source_snapshots_and_resize_uses_actual_global_time() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><body></body>')
	document.load_timing_info.navigation_start_time = highresolutiontime.unsafe_shared_current_time() - 1200
	assert document.last_viewport_size == none
	mut window := html.WindowModel.create_top_level(document, none, 'visual-initial-resize')!
	initial_rect := window.navigable_model().viewport_rect()
	assert document.last_viewport_size? == [initial_rect.width.to_int(), initial_rect.height.to_int()]!
	visual := document.visual_viewport()
	assert document.last_visual_viewport_state? == dom.VisualViewportState{
		scale:  1
		width:  visual.width()
		height: visual.height()
	}
	assert initial_rect.width.to_double() != 200 || initial_rect.height.to_double() != 100
	_ = layout_document_typed_in_viewport(document, 200, 100)
	log := &VisualViewportResizeLog{}
	callback := visual_resize_callback(window, log)
	window.this_impl().set_event_handler_attribute('resize', callback)
	visual.set_onresize(callback)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	before := settings.global_relative_event_timestamp()
	document.run_the_resize_steps()
	after := settings.global_relative_event_timestamp()
	assert log.targets == [voidptr(window.this_impl()), voidptr(visual.event_target())]
	assert log.timestamps.all(it >= before && it <= after)
	assert log.timestamps.all(it >= 1000 && it < 10000)
	assert document.last_viewport_size? == [200, 100]!
	assert document.last_visual_viewport_state? == dom.VisualViewportState{ scale: 1, width: 200, height: 100 }
	document.run_the_resize_steps()
	assert log.targets.len == 2
	mut actual := window.visual_viewport() or { panic('VisualViewport') }
	assert voidptr(actual) == visual.visual_viewport_record()
	actual.zoom(css.CSSPixelPoint.from_values(0, 0), 1)
	// Reinstalling initial visibility does not replace an existing snapshot.
	document.set_initial_visibility_state(.hidden)
	assert document.last_visual_viewport_state?.scale == 1
	document.run_the_resize_steps()
	assert log.targets == [voidptr(window.this_impl()), voidptr(visual.event_target()),
		voidptr(visual.event_target())]
	assert document.last_visual_viewport_state? == dom.VisualViewportState{ scale: 2, width: 100, height: 50 }
}

fn test_fractional_viewport_dimensions_resize_visual_viewport_without_changing_integer_window_snapshot() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><body></body>')
	mut window := html.WindowModel.create_top_level(document, none, 'visual-fractional-resize')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	document.run_the_resize_steps()
	visual := document.visual_viewport()
	log := &VisualViewportResizeLog{}
	callback := visual_resize_callback(window, log)
	window.this_impl().set_event_handler_attribute('resize', callback)
	visual.set_onresize(callback)
	document.set_viewport_rect(dom.Rect{0, 0, 200.5, 100.25})
	document.run_the_resize_steps()
	assert log.targets == [voidptr(visual.event_target())]
	assert document.last_viewport_size? == [200, 100]!
	assert document.last_visual_viewport_state? == dom.VisualViewportState{ scale: 1, width: 200.5, height: 100.25 }
	document.run_the_resize_steps()
	assert log.targets.len == 1
	// CSSPixels nearest-value conversion occurs before the source int cast.
	document.set_viewport_rect(dom.Rect{0, 0, 200.9999, 100.9999})
	document.run_the_resize_steps()
	assert log.targets == [voidptr(visual.event_target()), voidptr(window.this_impl()),
		voidptr(visual.event_target())]
	assert document.last_viewport_size? == [201, 101]!
	assert document.last_visual_viewport_state? == dom.VisualViewportState{
		scale:  1
		width:  201
		height: 101
	}
}

fn test_resize_snapshots_precede_window_handler_reentrancy_and_visual_resize_follows_window() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><body></body>')
	mut window := html.WindowModel.create_top_level(document, none, 'visual-reentrant-resize')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	document.run_the_resize_steps()
	visual := document.visual_viewport()
	actual := window.visual_viewport() or { panic('VisualViewport') }
	log := &VisualViewportResizeLog{}
	log_callback := visual_resize_callback(window, log)
	actual_handle := voidptr(actual)
	window.this_impl().set_event_handler_attribute('resize', &dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [log_callback, actual_handle] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			callback := log_callback.handle_event or { panic('callback') }
			callback(event, current_target)
			mut owner := unsafe { &css.VisualViewport(actual_handle) }
			owner.zoom(css.CSSPixelPoint.from_values(0, 0), 1)
			return dom.js_undefined()
		}
	})
	visual.set_onresize(log_callback)
	document.set_viewport_rect(dom.Rect{0, 0, 220, 120})
	document.run_the_resize_steps()
	assert log.targets == [voidptr(window.this_impl()), voidptr(visual.event_target())]
	assert document.last_visual_viewport_state? == dom.VisualViewportState{ scale: 1, width: 220, height: 120 }
	assert visual.scale() == 2 && visual.width() == 110 && visual.height() == 60
	document.run_the_resize_steps()
	assert log.targets == [voidptr(window.this_impl()), voidptr(visual.event_target()),
		voidptr(visual.event_target())]
	assert document.last_visual_viewport_state? == dom.VisualViewportState{ scale: 2, width: 110, height: 60 }
	document.run_the_resize_steps()
	assert log.targets.len == 3
}
