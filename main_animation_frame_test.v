module main

import browserjs
import dom
import html
import page
import time

// Tests deliver actual source rendering opportunities, then drain their source
// task queue. They never call author callbacks or the Window driver directly.
fn compact_test_rendering_frame(document &dom.Document) {
	mut page_ := page.Page.create(1) or { panic(err) }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_page(unsafe { &dom.Page(page_) })
	page_.set_local_root_navigable(document.navigable() or { panic('missing navigable') }) or {
		panic(err)
	}
	mutable_document.update_the_visibility_state(.visible)
	mut app := BrowserApp{
		document:   mutable_document
		page_model: page_
	}
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

fn test_native_animation_frames_replay_each_real_frame_before_source_layout_and_retain_nested_order() {
	$if !darwin { return }
	mut document := parse_browser_navigation_document_with_response_time('<!doctype html><div id="target">initial</div>', dom.URL{value: 'https://frame.test/'},
		none, none, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://frame.test/', [
		r'
 const removed=requestAnimationFrame(()=>target.textContent="cancelled");cancelAnimationFrame(removed);
 globalThis.frameTimes=[];requestAnimationFrame(function(now){"use strict";frameTimes.push(now);target.textContent=this===undefined?"first":"wrong receiver";requestAnimationFrame(later=>{frameTimes.push(later);target.textContent="second"})});
',
	], runtime, mut messages)
	assert messages == []
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'initial'
	compact_test_rendering_frame(document)
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'first'
	assert runtime.evaluate_host('frameTimes.length===1&&frameTimes[0]>=0&&frameTimes[0]<10000')! == 'true'
	compact_test_rendering_frame(document)
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'second'
	assert runtime.evaluate_host('frameTimes.length===2&&frameTimes[1]>=frameTimes[0]')! == 'true'
	mut app := BrowserApp{
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
	app.poll_javascript_tasks()
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_native_animation_frame_replays_mutations_before_reporting_original_callback_exception() {
	$if !darwin { return }
	mut document := html.parse_document('<div id="target">initial</div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://frame.test/', [
		r'globalThis.frameFailure={};requestAnimationFrame(()=>{target.textContent="before failure";throw frameFailure});',
	], runtime, mut messages)
	compact_test_rendering_frame(document)
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'before failure'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('frameFailure')!
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_compact_response_timing_uses_actual_creation_before_parser_and_the_exposed_window_clock() {
	created := time.sys_mono_now()
	loaded := LoadedPage{
		url:    'about:blank'
		markup: '<p>response</p>'
	}
	assert loaded.monotonic_response_time_ns >= created
	document := parse_browser_navigation_document_with_response_time(loaded.markup,
		dom.url_about_blank(), none, none, 123_456_789_000)
	defer {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert document.load_timing_info.navigation_start_time == 123456.7
	assert settings.time_origin() == document.load_timing_info.navigation_start_time
	assert document.document_element() != none
}

fn test_native_navigation_installs_its_actual_rendering_root_and_consumes_display_grants() {
	$if !darwin { return }
	mut page_ := page.Page.create(1)!
	mut client := page_.client()
	client.set_manual_rendering_opportunities(true)
	mut app := BrowserApp{page_model: page_, layout_tree_only: true, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{url: 'about:blank', content_type: 'text/html', markup: '<!doctype html><div id="target">pending</div><script>requestAnimationFrame(()=>target.textContent="native frame")</script>'}, false)
	mut document := app.document
	defer { app.js_runtime.close(); document.finalize() }
	assert app.js_messages == []
	assert voidptr(page_.local_root_navigable()) == voidptr(document.navigable()?)
	assert !client.has_rendering_opportunity()
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'pending'
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	assert client.has_rendering_opportunity()
	mut loop := html.main_thread_event_loop()
	for loop.task_queue().has_runnable_tasks() { loop.process() }
	assert document.get_element_by_id('target')?.as_node().text_content()? == 'native frame'
	assert !client.has_rendering_opportunity()
}
