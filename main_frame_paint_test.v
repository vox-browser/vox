module main

import browserjs
import css
import dom
import html
import layout
import time

fn test_frame_preparation_keeps_layout_current_and_records_only_final_paint() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:30px;height:20px;background:rgb(17 34 51)}</style><div id="target"></div>')
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut app := BrowserApp{document: document}
	app.begin_frame_preparation()
	app.relayout(200, 232)
	assert document.cached_display_list() == none
	box := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing box') }
	assert box.border_box().width == 30
	target.set_attribute_value('style', 'width:70px;background:rgb(71 72 73)')
	app.relayout(200, 232)
	assert document.cached_display_list() == none
	updated := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing updated box') }
	assert updated.border_box().width == 70
	app.finish_frame_preparation()
	assert document.cached_display_list() != none
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	assert !app.paint_commands.any(it.color == 'rgb(17 34 51)')
	assert app.status.contains('${app.paint_commands.len} paints')
}

fn test_frame_preparation_allows_synchronous_geometry_and_paint_queries() {
	mut document := html.parse_document('<!doctype html><div id="target" style="width:30px;height:20px;background:rgb(17 34 51)"></div>')
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut app := BrowserApp{document: document}
	app.begin_frame_preparation()
	app.relayout(200, 232)
	assert target.get_bounding_client_rect().width == 30
	first := document.record_display_list() or { panic('missing synchronous display list') }
	first_scene := layout.retain_display_list_scene(first)
	defer { layout.release_display_list_scene(first_scene) }
	target.set_attribute_value('style', 'width:70px;height:20px;background:rgb(71 72 73)')
	app.relayout(200, 232)
	assert target.get_bounding_client_rect().width == 70
	app.finish_frame_preparation()
	last := document.cached_display_list() or { panic('missing final display list') }
	assert voidptr(first) != voidptr(last)
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
}

fn test_nested_frame_preparation_presents_inner_updates_and_retains_outer_deferral() {
	mut document := html.parse_document('<!doctype html><div id="target" style="width:30px;height:20px;background:rgb(17 34 51)"></div>')
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	mut app := BrowserApp{document: document}
	app.begin_frame_preparation()
	app.relayout(200, 232)
	app.begin_frame_preparation()
	target.set_attribute_value('style', 'height:20px;background:rgb(71 72 73)')
	app.relayout(200, 232)
	app.finish_frame_preparation()
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	target.set_attribute_value('style', 'height:20px;background:rgb(81 82 83)')
	app.relayout(200, 232)
	assert document.cached_display_list() == none
	app.finish_frame_preparation()
	assert app.paint_commands.any(it.color == 'rgb(81 82 83)')
	// Calls outside the native frame still produce commands immediately.
	target.set_attribute_value('style', 'height:20px;background:rgb(91 92 93)')
	app.relayout(200, 232)
	assert app.paint_commands.any(it.color == 'rgb(91 92 93)')
}

fn test_frame_preparation_adopts_a_replacement_documents_already_recorded_list() {
	mut app := BrowserApp{
		document: html.parse_document('<!doctype html><div style="height:20px;background:rgb(17 34 51)"></div>')
	}
	app.relayout(200, 232)
	assert app.paint_commands.any(it.color == 'rgb(17 34 51)')
	mut replacement := html.parse_document('<!doctype html><div style="height:20px;background:rgb(71 72 73)"></div>')
	app.begin_frame_preparation()
	app.document = replacement
	app.relayout(200, 232)
	_ = replacement.record_display_list() or { panic('missing replacement list') }
	app.finish_frame_preparation()
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	assert !app.paint_commands.any(it.color == 'rgb(17 34 51)')
	app.begin_frame_preparation()
	app.document = unsafe { nil }
	app.finish_frame_preparation()
	assert app.paint_commands.len == 0
	assert !app.paint_commands_have_backdrop_filter
}

fn test_frame_preparation_refreshes_scroll_snapshot_without_relayout() {
	mut document := html.parse_document('<!doctype html><div style="height:600px;background:rgb(71 72 73)"></div>')
	mut app := BrowserApp{document: document}
	app.relayout(200, 232)
	before := document.cached_display_list() or { panic('missing initial list') }
	app.begin_frame_preparation()
	app.set_scroll_y(25, 232)
	assert document.cached_display_list() == none
	app.finish_frame_preparation()
	after := document.cached_display_list() or { panic('missing scroll list') }
	assert voidptr(before) != voidptr(after)
	assert document.viewport_rect().y == 25
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
}

fn test_frame_preparation_samples_animations_before_first_recording() {
	mut document := html.parse_document('<!doctype html><style>@keyframes flip{0%{transform:rotateY(60deg)}0.01%,100%{transform:rotateY(180deg)}}.flip{animation:10s linear infinite flip}#scene{width:100px;height:100px;transform:rotateY(60deg);transform-style:preserve-3d}#target{position:absolute;top:0;left:0;width:200px;height:200px;background:lightblue;transform:rotateY(180deg);backface-visibility:hidden}</style><div id="scene" class="flip"><div id="target"></div></div>')
	mut app := BrowserApp{
		document: document
		animation_epoch_ns: time.sys_mono_now() - 16_000_000
	}
	app.begin_frame_preparation()
	app.relayout(200, 232)
	assert css.document_has_running_css_animations(document)
	assert document.cached_display_list() == none
	app.advance_document_animations(200, 120)
	assert document.cached_display_list() == none
	app.finish_frame_preparation()
	scene_element := document.get_element_by_id('scene') or { panic('missing scene') }
	scene := app.root_box.find_box(i64(scene_element.as_node().unique_id())) or { panic('missing scene paint box') }
	assert scene.own_paint_transform_4x4.m33 < -0.9
	assert app.paint_commands.any(it.color.contains('173') || it.color.to_lower().contains('add8e6'))
}

fn test_frame_preparation_preserves_layout_tree_only_mode() {
	mut app := BrowserApp{
		document: html.parse_document('<!doctype html><div style="height:20px;background:rgb(71 72 73)"></div>')
		layout_tree_only: true
	}
	app.begin_frame_preparation()
	app.relayout(200, 232)
	app.finish_frame_preparation()
	assert app.document.layout_is_up_to_date()
	assert app.document.cached_display_list() == none
	assert app.paint_commands.len == 0
}

fn test_animation_ticks_keep_unchanged_paint_and_do_not_repeat_procedural_filters() {
	$if !darwin { return }
	for animation in [
		'@keyframes hold{from,to{opacity:1}}#target{animation:hold 1000s linear infinite}',
		'@keyframes wait{from{opacity:0}to{opacity:1}}#target{animation:wait 1s linear 1000s infinite}',
	] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:20px;height:20px;background:green;opacity:1}${animation}</style><div id="target"></div>')
		mut runtime := browserjs.Runtime.create()
		defer { runtime.close(); document.finalize() }
		runtime.evaluate_host('globalThis.animationFilterCommits=0;globalThis.__voxAdblockApplyProcedural=()=>{animationFilterCommits++;return ""};')!
		mut app := BrowserApp{document: document, js_runtime: runtime}
		app.relayout(200, 232)
		assert css.document_has_running_css_animations(document)
		initial := document.cached_display_list() or { panic('missing initial animation paint') }
		layout_handle := document.layout_engine_handle()
		runtime.evaluate_host('animationFilterCommits=0')!
		app.animation_epoch_ns = time.sys_mono_now() - 500_000_000
		app.begin_frame_preparation()
		app.advance_document_animations(200, app.viewport_height)
		app.finish_frame_preparation()
		current := document.cached_display_list() or { panic('missing unchanged animation paint') }
		assert voidptr(current) == voidptr(initial)
		assert document.layout_engine_handle() == layout_handle
		assert runtime.evaluate_host('animationFilterCommits')! == '0'
	}
}

fn test_animation_tick_commits_sampled_width_endpoint_and_adopts_current_geometry() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes grow{from{width:20px}to{width:100px}}#target{height:20px;background:green;animation:grow 1ms linear forwards}</style><div id="target"></div>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing animated width target') }
	mut app := BrowserApp{document: document}
	app.relayout(200, 232)
	assert css.document_has_running_css_animations(document)
	initial := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing initial width box') }
	assert initial.border_box().width == 20
	app.animation_epoch_ns = time.sys_mono_now() - 1_000_000_000
	app.begin_frame_preparation()
	app.advance_document_animations(200, app.viewport_height)
	app.finish_frame_preparation()
	current := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing final width box') }
	assert current.border_box().width == 100
	assert target.get_bounding_client_rect().width == 100
}

fn test_animation_tick_commits_sampled_transform_endpoint_without_rebuilding_geometry() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}@keyframes turn{from{transform:rotateY(60deg)}to{transform:rotateY(180deg)}}#target{width:20px;height:20px;background:green;animation:turn 1ms linear forwards}</style><div id="target"></div>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('missing animated transform target') }
	mut app := BrowserApp{document: document}
	app.relayout(200, 232)
	assert css.document_has_running_css_animations(document)
	layout_handle := document.layout_engine_handle()
	initial := document.cached_display_list() or { panic('missing initial transform paint') }
	app.animation_epoch_ns = time.sys_mono_now() - 1_000_000_000
	app.begin_frame_preparation()
	app.advance_document_animations(200, app.viewport_height)
	app.finish_frame_preparation()
	current := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing final transform box') }
	assert current.own_paint_transform_4x4.m33 < -0.9
	assert document.layout_engine_handle() == layout_handle
	paint := document.cached_display_list() or { panic('missing final transform paint') }
	assert voidptr(paint) != voidptr(initial)
}
