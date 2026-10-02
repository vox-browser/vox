module layout

import dom
import html
import time
import webidl

fn caller_document(inner_target_top int, target_height int) !(&dom.Document, &html.WindowModel, &html.NavigableModel) {
	return caller_document_with_css(inner_target_top, target_height, '')
}

fn caller_document_with_css(inner_target_top int, target_height int, extra_css string) !(&dom.Document, &html.WindowModel, &html.NavigableModel) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{height:1000px}#outer{position:absolute;left:0;top:200px;width:180px;height:100px;overflow:auto}#outer-content{position:relative;width:180px;height:400px}#inner{position:absolute;left:0;top:150px;width:140px;height:60px;overflow:auto}#inner-content{position:relative;width:140px;height:300px}#target{position:absolute;left:0;top:${inner_target_top}px;width:20px;height:${target_height}px}${extra_css}</style><div id="outer"><div id="outer-content"><div id="inner"><div id="inner-content"><div id="target"></div></div></div></div></div>')
	window := html.WindowModel.create_top_level(document, none, 'scroll-into-view-caller')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	return document, window, window.navigable_model()
}

fn test_scroll_into_view_scrolls_actual_inner_outer_and_viewport_in_source_order() {
	document, window, _ := caller_document(220, 20)!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	assert target.get_bounding_client_rect() == dom.Rect{0, 570, 20, 20}
	promise := target.scroll_into_view()
	assert inner.scroll_top() == 220 && outer.scroll_top() == 150
	assert window.scroll_y() == 200
	assert target.get_bounding_client_rect() == dom.Rect{0, 0, 20, 20}
	assert promise.state() == .fulfilled
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert webidl.promise_realm(promise.webidl_promise()?) == u64(voidptr(settings.realm()))
	assert document.pending_scroll_events.filter(it.type_ == 'scroll').map(it.target.unique_id()) == [
		inner.as_node().unique_id(),
		outer.as_node().unique_id(),
		document.as_node().unique_id(),
	]
}

fn test_scroll_into_view_nearest_container_stops_at_actual_inner_scrolling_ancestor() {
	document, window, _ := caller_document(220, 20)!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	promise := target.scroll_into_view_with_options(dom.ScrollIntoViewOptions{ container: .nearest })
	assert inner.scroll_top() == 220 && outer.scroll_top() == 0
	assert window.scroll_y() == 0
	assert target.get_bounding_client_rect() == dom.Rect{0, 350, 20, 20}
	assert promise.state() == .fulfilled
}

fn test_scroll_into_view_projects_committed_transformed_padding_boxes_into_viewport() {
	document, window, _ := caller_document_with_css(220, 20, '#outer{transform:translate(15px,7px)}')!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	assert target.get_bounding_client_rect() == dom.Rect{15, 577, 20, 20}
	_ = target.scroll_into_view()
	assert inner.scroll_top() == 220 && outer.scroll_top() == 150
	assert window.scroll_y() == 207
	assert target.get_bounding_client_rect() == dom.Rect{15, 0, 20, 20}
}

fn test_scroll_into_view_smoothly_projects_destination_before_offsets_move_and_awaits_every_scroll() {
	document, window, mut model := caller_document(220, 20)!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	promise := target.scroll_into_view_with_options(dom.ScrollIntoViewOptions{ behavior: .smooth })
	assert promise.state() == .pending
	assert inner.scroll_top() == 0 && outer.scroll_top() == 0 && window.scroll_y() == 0
	time.sleep(350 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert inner.scroll_top() == 220 && outer.scroll_top() == 150
	assert window.scroll_y() == 200
	assert promise.state() == .pending
	html.perform_a_microtask_checkpoint()
	assert promise.state() == .fulfilled
}

fn test_scroll_into_view_projects_clamped_destination_for_outer_alignment() {
	document, window, _ := caller_document(280, 20)!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	_ = target.scroll_into_view()
	assert inner.scroll_top() == 240
	assert outer.scroll_top() == 190 && window.scroll_y() == 200
	assert target.get_bounding_client_rect() == dom.Rect{0, 0, 20, 20}
}

fn test_scroll_into_view_clips_projected_target_to_actual_inner_padding_box() {
	document, window, _ := caller_document(0, 160)!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	_ = target.scroll_into_view_with_options(dom.ScrollIntoViewOptions{ block: .nearest })
	assert inner.scroll_top() == 0
	// Only the inner scrollport's 60px visible part reaches outer alignment.
	assert outer.scroll_top() == 110 && window.scroll_y() == 200
	assert target.get_bounding_client_rect() == dom.Rect{0, 40, 20, 160}
}

fn test_scroll_into_view_auto_behavior_awaits_only_smooth_css_ancestor_after_others_commit() {
	document, window, mut model := caller_document_with_css(220, 20, '#inner{scroll-behavior:smooth}')!
	mut target := document.get_element_by_id('target') or { panic('target') }
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	promise := target.scroll_into_view()
	assert inner.scroll_top() == 0 && outer.scroll_top() == 150 && window.scroll_y() == 200
	assert promise.state() == .pending
	time.sleep(350 * time.millisecond)
	model.process_main_thread_smooth_scrolls()
	assert inner.scroll_top() == 220 && promise.state() == .pending
	html.perform_a_microtask_checkpoint()
	assert promise.state() == .fulfilled
}

fn test_scroll_into_view_boolean_and_no_box_use_actual_owner_and_source_defaults() {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body{height:1000px}#target{position:absolute;top:220px;width:20px;height:20px}#hidden{display:none}</style><div id="target"></div><div id="hidden"></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'scroll-argument')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	mut target := document.get_element_by_id('target') or { panic('target') }
	_ = target.scroll_into_view_with_argument(false)
	assert window.scroll_y() == 140
	_ = target.scroll_into_view_with_argument(true)
	assert window.scroll_y() == 220
	mut hidden := document.get_element_by_id('hidden') or { panic('hidden') }
	promise := hidden.scroll_into_view()
	assert promise.state() == .fulfilled && window.scroll_y() == 220
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert webidl.promise_realm(promise.webidl_promise()?) == u64(voidptr(settings.realm()))
}

fn test_scroll_into_view_adopts_supplied_capability_in_its_actual_foreign_realm_and_supports_no_promise() {
	document, window, _ := caller_document(220, 20)!
	other_document := html.parse_document('<!doctype html><body></body>')
	_ = html.WindowModel.create_top_level(other_document, none, 'scroll-caller-promise')!
	settings := unsafe { &html.EnvironmentSettingsObject(other_document.relevant_settings_object()) }
	mut supplied := webidl.create_promise_for(other_document.relevant_realm_promise_context())
	mut target := document.get_element_by_id('target') or { panic('target') }
	target.scroll_into_view_with_options_and_promise(dom.ScrollIntoViewOptions{}, supplied)
	assert window.scroll_y() == 200
	assert webidl.promise_realm(supplied) == u64(voidptr(settings.realm()))
	html.perform_a_microtask_checkpoint()
	assert supplied.state == .fulfilled && supplied.result.kind == .undefined
	// Source callers may omit the scrollPromise entirely and still scroll.
	target.scroll_into_view_with_argument_and_promise(false, none)
	inner := document.get_element_by_id('inner') or { panic('inner') }
	outer := document.get_element_by_id('outer') or { panic('outer') }
	assert inner.scroll_top() == 180 && outer.scroll_top() == 110
	assert window.scroll_y() == 200
}
