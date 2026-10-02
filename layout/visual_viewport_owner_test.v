module layout

import css
import dom
import html

@[heap]
struct VisualViewportEventLog {
mut:
	types   []string
	targets []voidptr
}

fn visual_viewport_log_callback(window &html.WindowModel, log &VisualViewportEventLog) &dom.CallbackType {
	log_handle := voidptr(log)
	return &dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [log_handle] (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			mut events := unsafe { &VisualViewportEventLog(log_handle) }
			events.types << event.type_
			events.targets << voidptr(current_target or { panic('currentTarget') })
			assert voidptr(event.target() or { panic('target') }) == events.targets.last()
			return dom.js_undefined()
		}
	}
}

fn test_document_visual_viewport_keeps_source_record_created_before_window_and_live_geometry() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}body{height:1000px;width:1000px}</style><body></body>')
	facade := document.visual_viewport()
	assert voidptr(facade.document()) == voidptr(document)
	assert facade.width() == 0 && facade.height() == 0 && facade.scale() == 1
	assert facade.offset_left() == 0 && facade.page_top() == 0
	mut actual := unsafe { &css.VisualViewport(facade.visual_viewport_record()) }
	assert actual.relevant_global_impl() == none
	mut window := html.WindowModel.create_top_level(document, none, 'visual-owner')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	from_window := window.visual_viewport() or { panic('Window VisualViewport') }
	assert voidptr(from_window) == facade.visual_viewport_record()
	assert document.visual_viewport().visual_viewport_record() == facade.visual_viewport_record()
	assert voidptr(actual.relevant_global_impl() or { panic('owning global') }) == voidptr(window)
	assert facade.width() == 200 && facade.height() == 100
	_ = window.scroll_xy(40, 100)
	actual.zoom(css.CSSPixelPoint.from_values(40, 20), 1)
	assert facade.scale() == 2 && facade.width() == 100 && facade.height() == 50
	assert facade.offset_left() == 20 && facade.offset_top() == 10
	assert facade.page_left() == 60 && facade.page_top() == 110
	assert voidptr(facade.event_target()) == voidptr(actual.event_target())
}

fn test_inactive_window_returns_null_without_replacing_document_visual_viewport_or_scale() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><body></body>')
	mut window := html.WindowModel.create_top_level(document, none, 'visual-inactive')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	facade := document.visual_viewport()
	mut actual := window.visual_viewport() or { panic('VisualViewport') }
	actual.zoom(css.CSSPixelPoint.from_values(40, 20), 1)
	mut model := window.navigable_model()
	model.set_active_document(none)
	assert window.visual_viewport() == none
	assert facade.offset_left() == 0 && facade.offset_top() == 0
	assert facade.page_left() == 0 && facade.page_top() == 0
	assert facade.width() == 0 && facade.height() == 0 && facade.scale() == 2
	assert document.visual_viewport().visual_viewport_record() == voidptr(actual)
	model.set_active_document(document)
	assert voidptr(window.visual_viewport() or { panic('reactivated viewport') }) == voidptr(actual)
	assert facade.width() == 100 && facade.height() == 50 && facade.offset_left() == 20
}

fn test_visual_viewport_facade_event_handlers_share_actual_target_scroll_queue_and_reset() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><body></body>')
	mut window := html.WindowModel.create_top_level(document, none, 'visual-events')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	facade := document.visual_viewport()
	mut actual := window.visual_viewport() or { panic('VisualViewport') }
	log := &VisualViewportEventLog{}
	callback := visual_viewport_log_callback(window, log)
	facade.set_onscroll(callback)
	facade.set_onscrollend(callback)
	facade.set_onresize(callback)
	assert voidptr(actual.onscroll() or { panic('scroll handler') }) == voidptr(callback)
	assert voidptr(actual.onscrollend() or { panic('scrollend handler') }) == voidptr(callback)
	assert voidptr(actual.onresize() or { panic('resize handler') }) == voidptr(callback)
	actual.scroll_by(css.CSSPixelPoint.from_values(0, 0))
	assert document.pending_scroll_events.len == 0
	actual.scroll_by(css.CSSPixelPoint.from_values(5, 7))
	actual.scroll_by(css.CSSPixelPoint.from_values(4, 6))
	assert facade.offset_left() == 9 && facade.offset_top() == 13
	assert document.pending_scroll_events.len == 1
	assert voidptr(document.pending_scroll_events[0].event_target?) == voidptr(facade.event_target())
	document.run_the_scroll_steps()
	actual.reset()
	assert document.pending_scroll_events.map(it.type_) == ['scroll', 'scrollend']
	document.run_the_scroll_steps()
	assert log.types == ['scroll', 'scroll', 'scrollend']
	assert log.targets == [voidptr(actual.event_target()), voidptr(actual.event_target()),
		voidptr(actual.event_target())]
	facade.set_onscroll(none)
	assert actual.onscroll() == none
	assert actual.onscrollend() != none && actual.onresize() != none
}
