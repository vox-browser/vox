module layout

import css
import dom
import html
import time

fn smooth_scroll_document(source string) !(&dom.Document, &html.WindowModel, &html.NavigableModel) {
	document := html.parse_document(source)
	window := html.WindowModel.create_top_level(document, none, 'scroll-test')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return document, window, window.navigable_model()
}

fn test_same_destination_scroll_interrupts_earlier_promise_and_resolves_final_sample() {
	document, mut window, mut model :=
		smooth_scroll_document('<!doctype html><style>html,body{margin:0}body{height:1000px}</style><body></body>')!
	mut first := window.scroll(html.ScrollToOptions{ top: 400, behavior: .smooth })
	assert first.state() == .pending
	assert window.scroll_y() == 0
	time.sleep(50 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert window.scroll_y() > 0 && window.scroll_y() < 400
	second := window.scroll(html.ScrollToOptions{ top: 400, behavior: .smooth })
	assert voidptr(second) != voidptr(first) && second.state() == .pending
	html.perform_a_microtask_checkpoint()
	assert first.state() == .fulfilled && first.scroll_interrupted_
	time.sleep(250 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert window.scroll_y() == 400
	assert second.state() == .pending
	assert document.pending_scroll_events.filter(it.type_ == 'scroll').len == 1
	assert document.pending_scroll_events.filter(it.type_ == 'scrollend').len == 1
	html.perform_a_microtask_checkpoint()
	assert first.state() == .fulfilled && second.state() == .fulfilled
	assert !second.scroll_interrupted_
}

fn test_replacing_smooth_scroll_resolves_previous_without_an_extra_scrollend() {
	document, mut window, mut model :=
		smooth_scroll_document('<!doctype html><style>html,body{margin:0}html{scroll-behavior:smooth}body{height:1000px}</style><body></body>')!
	first := window.scroll(html.ScrollToOptions{ top: 500 })
	assert first.state() == .pending
	time.sleep(50 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	instant := window.scroll(html.ScrollToOptions{ top: 50, behavior: .instant })
	assert instant.state() == .fulfilled
	assert first.state() == .pending
	assert window.scroll_y() == 50
	assert document.pending_scroll_events.filter(it.type_ == 'scrollend').len == 1
	html.perform_a_microtask_checkpoint()
	assert first.state() == .fulfilled
	assert first.scroll_interrupted_
}

fn test_element_smooth_snap_keeps_intermediate_samples_and_adoption_resolves_pending_scroll() {
	document, _, mut model :=
		smooth_scroll_document('<!doctype html><style>html,body{margin:0}#scroller{height:100px;width:100px;overflow:auto;scroll-snap-type:y mandatory;scroll-behavior:smooth}.area{height:100px;scroll-snap-align:start}</style><div id="scroller"><div class="area"></div><div id="second" class="area"></div><div class="area"></div></div>')!
	mut element := document.get_element_by_id('scroller') or { panic('scroller') }
	promise := element.el_scroll_with_options(dom.ScrollToOptions_{ top: 138 })
	assert promise.state() == .pending
	second := document.get_element_by_id('second') or { panic('second') }
	assert element.snapped_scroll_areas_y()[0].element_id == i64(second.as_node().unique_id())
	time.sleep(25 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert element.scroll_top() > 0 && element.scroll_top() < 100
	time.sleep(250 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert element.scroll_top() == 100
	html.perform_a_microtask_checkpoint()
	assert promise.state() == .fulfilled
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.pending_scroll_events.clear()
	removed_promise := element.el_scroll_with_options(dom.ScrollToOptions_{
		top:      200
		behavior: .smooth
	})
	assert removed_promise.state() == .pending
	mut replacement_document := dom.Document.create(dom.URL{value: 'https://other.test/'})
	replacement_document.adopt_node(element.as_node())
	model.process_main_thread_smooth_scrolls()
	assert document.pending_scroll_events.filter(it.type_ == 'scrollend').len == 0
	html.perform_a_microtask_checkpoint()
	assert removed_promise.state() == .fulfilled
}

fn test_visual_viewport_scroll_events_precede_layout_viewport_events() {
	document, mut window, mut model :=
		smooth_scroll_document('<!doctype html><style>html,body{margin:0}body{height:1000px}</style><body></body>')!
	mut visual := window.visual_viewport() or { panic('visual viewport') }
	visual.scale_ = 2
	promise := window.scroll(html.ScrollToOptions{ top: 120, behavior: .instant })
	assert promise.state() == .fulfilled
	assert visual.offset_top() == 50
	assert window.scroll_y() == 70
	assert document.pending_scroll_events.map(it.type_) == ['scroll', 'scrollend', 'scroll', 'scrollend']
	assert document.pending_scroll_events[0].event_target? == unsafe { &dom.EventTarget(visual) }
	assert document.pending_scroll_events[2].target == document.as_node()
}

fn test_reverse_overflow_limits_and_scroll_event_reentrancy() {
	document, _, mut model :=
		smooth_scroll_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:50px;overflow:auto;direction:rtl}#wide{width:300px;height:20px}</style><div id="scroller"><div id="wide"></div></div>')!
	mut element := document.get_element_by_id('scroller') or { panic('scroller') }
	before := element.paintable_box() or { panic('before paintable') }
	assert [before.minimum_scroll_offset().x(), before.maximum_scroll_offset().x(),
		before.padding_box_x_, before.scrollable_overflow_rect()?.x_] == [f64(-200), 0, 0, -200]
	promise := element.el_scroll(-80, 0)
	assert promise.state() == .fulfilled
	assert element.scroll_left() == -80
	paintable := element.paintable_box() or { panic('paintable') }
	assert paintable.minimum_scroll_offset().x() == -200
	assert paintable.maximum_scroll_offset().x() == 0
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.pending_scroll_events.clear()
	model.perform_scroll_of_viewport_scrolling_box(css.CSSPixelPoint.from_values(0, 10))
	assert document.pending_scroll_events.map(it.type_) == ['scroll']
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [document] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert event.bubbles()
			mut target := unsafe { &dom.Document(document) }
			target.append_pending_scroll_event(dom.PendingScrollEvent{
				target: document.as_node()
				type_:  'scrollend'
			})
			return dom.js_undefined()
		}
	})
	target := unsafe { &dom.EventTarget(document.as_node()) }
	target.add_event_listener_without_options('scroll', listener)
	assert target.has_event_listener('scroll')
	mutable_document.run_the_scroll_steps()
	assert document.pending_scroll_events.map(it.type_) == ['scrollend']
}
