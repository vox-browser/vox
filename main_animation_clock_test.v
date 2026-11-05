module main

import css
import dom
import page
import time
import html

const animation_clock_markup = '<!doctype html><style>@keyframes grow{from{width:20px}to{width:100px}}#target{height:20px;background:green;animation:grow 10s linear infinite}</style><div id="target"></div>'

fn animation_clock_drain_tasks() {
	mut loop := html.main_thread_event_loop()
	for loop.task_queue().has_runnable_tasks() { loop.process() }
}

fn test_html_frame_keeps_its_animation_timestamp_through_native_paint_and_next_frame() {
	mut owner := page.Page.create(1)!
	mut client := owner.client()
	client.set_manual_rendering_opportunities(true)
	created := time.sys_mono_now() - 500_000_000
	mut document := parse_browser_navigation_document_for_page_with_response_time(animation_clock_markup,
		dom.URL{value: 'https://animation-clock.test/'}, none, none, unsafe { &dom.Page(owner) }, created)
	defer { document.finalize() }
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') })!
	document.update_the_visibility_state(.visible)
	mut app := BrowserApp{document: document, page_model: owner, animation_epoch_ns: u64(created)}
	app.relayout(200, 232)
	assert css.document_has_running_css_animations(document)
	assert app.source_rendering_owns_animation_clock()
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	animation_clock_drain_tasks()
	first := document.last_animation_frame_timestamp_value() or { panic('missing animation timestamp') }
	assert first >= 500
	assert document.layout_is_up_to_date()
	// Deliberately different from the HTML clock: duplicate sampling must be
	// observable without depending on a sub-millisecond timing race.
	app.animation_epoch_ns = u64(time.sys_mono_now() - 2_000_000_000)
	app.begin_frame_preparation()
	app.advance_document_animations(200, 120)
	if !retain_native_animation_tick {
		assert document.last_animation_frame_timestamp_value() or { panic('missing animation timestamp') } == first
		assert document.layout_is_up_to_date()
	} else {
		assert document.last_animation_frame_timestamp_value() or { panic('missing animation timestamp') } >= 2000
	}
	app.finish_frame_preparation()
	target := document.get_element_by_id('target') or { panic('missing target') }
	adopted := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing adopted animation box') }
	assert adopted.border_box().width == target.get_bounding_client_rect().width * document.layout_coordinate_scale()
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	animation_clock_drain_tasks()
	second := document.last_animation_frame_timestamp_value() or { panic('missing animation timestamp') }
	assert second >= first
	assert document.layout_is_up_to_date()
	assert target.get_bounding_client_rect().width >= 20
	assert target.get_bounding_client_rect().width <= 100
}

fn test_native_draw_does_not_bypass_html_hidden_or_render_blocked_animation_eligibility() {
	for blocked in [false, true] {
		mut owner := page.Page.create(1)!
		mut document := parse_browser_navigation_document_for_page_with_response_time(animation_clock_markup,
			dom.URL{value: 'https://animation-clock.test/'}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
		defer { document.finalize() }
		owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') })!
		mut app := BrowserApp{document: document, page_model: owner, animation_epoch_ns: u64(time.sys_mono_now() - 1_000_000_000), layout_tree_only: true}
		app.relayout(200, 232)
		assert css.document_has_running_css_animations(document)
		if blocked { document.add_render_blocking_element(document.get_element_by_id('target') or { panic('missing target') }) }
		else { document.update_the_visibility_state(.hidden) }
		before := document.last_animation_frame_timestamp_value()
		app.advance_document_animations(200, 120)
		if !retain_native_animation_tick { assert document.last_animation_frame_timestamp_value() == before }
		else { assert document.last_animation_frame_timestamp_value() or { panic('missing animation timestamp') } >= 1000 }
	}
}

fn test_standalone_documents_and_uninstalled_page_roots_keep_the_native_clock() {
	mut document := html.parse_document(animation_clock_markup)
	defer { document.finalize() }
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{document: document, animation_epoch_ns: u64(time.sys_mono_now() - 1_000_000_000), layout_tree_only: true}
	app.relayout(200, 232)
	assert !app.source_rendering_owns_animation_clock()
	app.advance_document_animations(200, 120)
	assert document.last_animation_frame_timestamp_value() or { panic('missing animation timestamp') } >= 1000
	app.page_model = owner
	assert !app.source_rendering_owns_animation_clock()
	document.set_page(unsafe { &dom.Page(owner) })
	assert !app.source_rendering_owns_animation_clock()
	owner.set_local_root_navigable(document.navigable() or { panic('missing navigable') })!
	assert app.source_rendering_owns_animation_clock()
	mut other := page.Page.create(1)!
	app.page_model = other
	assert !app.source_rendering_owns_animation_clock()
}
