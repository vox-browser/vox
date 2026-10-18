module main

import browserjs
import css
import dom
import html
import layout
import platform
import time

fn javascript_task_paint_fixture(markup string) (&BrowserApp, &browserjs.Runtime, &dom.Document) {
	mut document := html.parse_document(markup)
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, 'https://task-paint.test/', [], runtime, mut messages)
	assert messages == []string{}
	runtime.evaluate_host('globalThis.taskPaintFilterRuns=0;globalThis.__voxAdblockApplyProcedural=()=>{taskPaintFilterRuns++;return ""};') or { panic(err) }
	mut app := &BrowserApp{document:document,js_runtime:runtime}
	app.relayout(320, 232)
	runtime.evaluate_host('taskPaintFilterRuns=0') or { panic(err) }
	runtime.take_document_state_dirty()
	return app, runtime, document
}

fn test_read_only_input_listener_keeps_adopted_paint_without_cosmetic_refresh() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target" style="width:30px;height:20px;background:green" onclick="getComputedStyle(this).getPropertyValue(\'width\');console.log(\'read-only input\')"></div>')
	defer { runtime.close(); document.finalize() }
	target := document.get_element_by_id('target')?
	paint := document.cached_display_list()?
	commands := app.paint_commands.data
	for _ in 0 .. 2 {
		assert !app.dispatch_javascript_event('mousedown', target)
		assert !app.dispatch_javascript_event('click', target)
		assert runtime.evaluate_host('taskPaintFilterRuns')! == '0'
		assert voidptr(document.cached_display_list()?) == voidptr(paint)
		assert app.paint_commands.data == commands
	}
	assert app.js_messages == ['read-only input', 'read-only input']
}

fn test_input_listener_query_flushed_mutation_still_refreshes_and_adopts_geometry() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><style>#target{width:30px;height:20px;background:green}#target.changed{width:80px;background:rgb(81 82 83)}</style><div id="target" onclick="this.className=\'changed\';getComputedStyle(this).getPropertyValue(\'width\')"></div>')
	defer { runtime.close(); document.finalize() }
	target := document.get_element_by_id('target')?
	assert !app.dispatch_javascript_event('click', target)
	assert target.get_attribute_value('class') == 'changed'
	assert runtime.evaluate_host('taskPaintFilterRuns')! == '1'
	box := app.root_box.find_box(i64(target.as_node().unique_id()))?
	assert box.border_box().width == 80
	assert app.paint_commands.any(it.color == 'rgb(81 82 83)')
}

fn test_input_listener_adopts_native_paint_recorded_before_dispatch_finishes() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target" style="width:30px;height:20px;background:green" onclick="nativeInputPaint(\'\')"></div>')
	defer { runtime.close(); document.finalize() }
	mut target := document.get_element_by_id('target')?
	runtime.define_host_function('nativeInputPaint', fn [mut document, mut target] (_ string) !string {
		target.set_attribute_value('style', 'width:80px;height:20px;background:rgb(81 82 83)')
		document.update_layout(.debugging)
		_ = document.record_display_list() or { return error('missing synchronous paint') }
		return ''
	})!
	assert !app.dispatch_javascript_event('click', target)
	assert app.paint_commands.any(it.color == 'rgb(81 82 83)')
	assert !app.javascript_tasks_have_unadopted_paint()
}

fn run_javascript_task_paint_timer(runtime &browserjs.Runtime, source string) {
	runtime.evaluate_host('globalThis.taskPaintTimerDone=false;setTimeout(()=>{try{${source}}finally{taskPaintTimerDone=true}},1)') or { panic(err) }
	deadline := time.sys_mono_now() + 2_000_000_000
	for runtime.evaluate_host('taskPaintTimerDone') or { panic(err) } != 'true'
		&& time.sys_mono_now() < deadline {
		platform.pump_native_events(0.005)
	}
	assert runtime.evaluate_host('taskPaintTimerDone') or { panic(err) } == 'true'
}

fn test_read_only_timer_style_and_selector_queries_keep_the_adopted_paint_and_style() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><style>#target{width:30px;height:20px;background:green}</style><div id="target">before</div>')
	defer { runtime.close(); document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing target') }
	style := css.computed_properties_for_element(target) or { panic('missing style') }
	paint := document.cached_display_list() or { panic('missing initial paint') }
	commands := app.paint_commands.data
	children := app.root_box.children.data
	for _ in 0 .. 2 {
		run_javascript_task_paint_timer(runtime, 'globalThis.taskPaintWidth=getComputedStyle(target).getPropertyValue("width");document.querySelector("#target");console.log("read-only timer");')
		app.poll_javascript_tasks()
		assert runtime.evaluate_host('taskPaintWidth')! == '30px'
		assert runtime.evaluate_host('taskPaintFilterRuns')! == '0'
		assert voidptr(document.cached_display_list() or { panic('missing retained paint') }) == voidptr(paint)
		assert app.paint_commands.data == commands
		assert app.root_box.children.data == children
		assert voidptr(css.computed_properties_for_element(target) or { panic('missing retained style') }) == voidptr(style)
	}
	assert app.js_messages == ['read-only timer', 'read-only timer']
}

fn test_timer_query_flushed_class_change_still_runs_cosmetic_filter_refresh_once() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target">before</div>')
	defer { runtime.close(); document.finalize() }
	run_javascript_task_paint_timer(runtime, 'target.className="new-adblock-token";getComputedStyle(target).getPropertyValue("width");')
	// The query has already drained the facade operation queue. Its pending
	// effect still matters to cosmetic filters even if the class matches no CSS.
	app.poll_javascript_tasks()
	assert document.get_element_by_id('target')?.get_attribute_value('class') == 'new-adblock-token'
	assert runtime.evaluate_host('taskPaintFilterRuns>0')! == 'true'
	refreshes := runtime.evaluate_host('taskPaintFilterRuns')!
	run_javascript_task_paint_timer(runtime, 'document.querySelector("#target");')
	app.poll_javascript_tasks()
	assert runtime.evaluate_host('taskPaintFilterRuns')! == refreshes
}

fn test_timer_pending_text_and_style_replay_reaches_the_next_shell_paint() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><title>before</title><style>#target{width:30px;height:20px;background:green}</style><div id="target">before</div>')
	defer { runtime.close(); document.finalize() }
	run_javascript_task_paint_timer(runtime, 'target.textContent="after";target.style.width="70px";target.style.backgroundColor="rgb(71 72 73)";document.title="timer title";')
	app.poll_javascript_tasks()
	target := document.get_element_by_id('target') or { panic('missing changed target') }
	assert target.as_node().text_content() or { '' } == 'after'
	assert target.get_bounding_client_rect().width == 70
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	assert document_title(document) == 'timer title'
}

fn test_query_flushed_timer_effects_after_poll_survive_frame_paint_until_filter_refresh() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><style>#target{width:30px;height:20px;background:green}</style><div id="target"></div>')
	defer { runtime.close(); document.finalize() }
	app.begin_frame_preparation()
	app.poll_javascript_tasks()
	// Rendering updates can dispatch callbacks after the frame's JS poll. A
	// synchronous query drains their facade operations before the shell records.
	run_javascript_task_paint_timer(runtime, 'target.className="late-adblock-token";target.style.width="70px";getComputedStyle(target).getPropertyValue("width");')
	app.finish_frame_preparation()
	assert document.layout_is_up_to_date()
	assert !document.needs_style_update_after_layout()
	assert !app.javascript_tasks_have_unadopted_paint()
	assert runtime.evaluate_host('taskPaintFilterRuns')! == '0'
	app.poll_javascript_tasks()
	assert document.get_element_by_id('target')?.get_attribute_value('class') == 'late-adblock-token'
	assert runtime.evaluate_host('taskPaintFilterRuns>0')! == 'true'
	refreshes := runtime.evaluate_host('taskPaintFilterRuns')!
	run_javascript_task_paint_timer(runtime, 'getComputedStyle(target).getPropertyValue("width");')
	app.poll_javascript_tasks()
	assert runtime.evaluate_host('taskPaintFilterRuns')! == refreshes
}

fn test_timer_native_mutation_with_an_already_recorded_list_is_adopted() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><style>#target{width:30px;height:20px;background:green}</style><div id="target"></div>')
	defer { runtime.close(); document.finalize() }
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	runtime.define_host_function('nativeTaskPaint', fn [mut document, mut target] (_ string) !string {
		target.set_attribute_value('style', 'width:80px;height:20px;background:rgb(81 82 83)')
		document.update_layout(.debugging)
		_ = document.record_display_list() or { return error('missing synchronous paint') }
		return ''
	})!
	old := app.paint_display_list
	run_javascript_task_paint_timer(runtime, 'nativeTaskPaint("");')
	assert document.layout_is_up_to_date()
	assert !document.needs_style_update_after_layout()
	assert voidptr(document.cached_display_list() or { panic('missing native paint') }) != voidptr(old)
	app.poll_javascript_tasks()
	assert app.paint_commands.any(it.color == 'rgb(81 82 83)')
	assert app.root_box.bounding_rect_for(target)?.width == 80
}

fn test_timer_canvas_and_selection_effects_are_replayed() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><canvas id="drawing" width="2" height="1"></canvas><div id="target">selected text</div>')
	defer { runtime.close(); document.finalize() }
	run_javascript_task_paint_timer(runtime, 'const context=drawing.getContext("2d");context.fillStyle="red";context.fillRect(0,0,2,1);getSelection().selectAllChildren(target);')
	app.poll_javascript_tasks()
	canvas := document.get_element_by_id('drawing') or { panic('missing canvas') }
	bitmap := html.html_canvas_element_surface(unsafe { &dom.HTMLCanvasElement(canvas) }) or { panic('missing canvas pixels') }
	assert bitmap.data[..4] == [u8(255), 0, 0, 255]
	assert (document.get_selection() or { panic('missing selection') }).to_string() == 'selected text'
	assert runtime.evaluate_host('taskPaintFilterRuns>0')! == 'true'
}

fn test_changed_line_box_diagnostic_setting_repaints_and_equal_replay_stays_clean() {
	$if !darwin { return }
	assert platform.native_timer_scheduling_available()
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target">text</div>')
	defer { runtime.close(); document.finalize() }
	initial := app.paint_display_list
	run_javascript_task_paint_timer(runtime, 'internals.setShowLineBoxBorders(true);')
	app.poll_javascript_tasks()
	assert voidptr(app.paint_display_list) != voidptr(initial)
	model := html.NavigableModel.navigable_with_active_document(document) or { panic('missing navigable') }
	assert model.should_show_line_box_borders()
	paint := app.paint_display_list
	refreshes := runtime.evaluate_host('taskPaintFilterRuns')!
	run_javascript_task_paint_timer(runtime, 'getComputedStyle(target).getPropertyValue("width");')
	app.poll_javascript_tasks()
	assert voidptr(app.paint_display_list) == voidptr(paint)
	assert runtime.evaluate_host('taskPaintFilterRuns')! == refreshes
	assert layout.display_list_commands(paint).data == app.paint_commands.data
}
