module main

import layout

fn test_frame_task_layout_coalesces_unqueried_mutations_into_final_geometry() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target" style="width:30px;height:20px;background:green"></div>')
	defer { runtime.close(); document.finalize() }
	generation := document.layout_pass_generation
	app.begin_frame_preparation()
	for width in [70, 90] {
		run_javascript_task_paint_timer(runtime, 'target.style.width="${width}px";target.style.backgroundColor="rgb(71 72 73)"')
		app.poll_javascript_tasks()
	}
	assert document.layout_pass_generation == generation + if disable_frame_task_layout_coalescing { 2 } else { 0 }
	app.finish_frame_preparation()
	assert document.layout_pass_generation == generation + if disable_frame_task_layout_coalescing { 2 } else { 1 }
	assert document.get_element_by_id('target')?.get_bounding_client_rect().width == 90
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	assert document.layout_is_up_to_date()
	assert !app.javascript_tasks_have_unadopted_paint()
	assert runtime.evaluate_host('taskPaintFilterRuns')! == '2'
}

fn test_frame_task_layout_preserves_intermediate_geometry_and_paint_queries() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target" style="width:30px;height:20px;background:green"></div>')
	defer { runtime.close(); document.finalize() }
	app.begin_frame_preparation()
	run_javascript_task_paint_timer(runtime, 'target.style.width="70px"')
	app.poll_javascript_tasks()
	assert runtime.evaluate_host('String(target.getBoundingClientRect().width)')! == '70'
	first := document.record_display_list() or { panic('missing synchronous paint') }
	first_scene := layout.retain_display_list_scene(first)
	defer { layout.release_display_list_scene(first_scene) }
	run_javascript_task_paint_timer(runtime, 'target.style.width="90px";target.style.backgroundColor="rgb(81 82 83)"')
	app.poll_javascript_tasks()
	app.finish_frame_preparation()
	assert document.get_element_by_id('target')?.get_bounding_client_rect().width == 90
	assert app.paint_commands.any(it.color == 'rgb(81 82 83)')
	assert voidptr(app.paint_display_list) != voidptr(first)
}

fn test_frame_task_layout_applies_cosmetic_filters_before_later_script_queries() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target" style="width:30px;height:20px;background:green"></div>')
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host('globalThis.__voxAdblockApplyProcedural=()=>{taskPaintFilterRuns++;return "#target{width:80px!important;background:rgb(81 82 83)!important}"}')!
	app.begin_frame_preparation()
	run_javascript_task_paint_timer(runtime, 'target.className="new-token"')
	app.poll_javascript_tasks()
	refreshes := runtime.evaluate_host('taskPaintFilterRuns')!
	assert refreshes == '1', refreshes
	assert runtime.evaluate_host('String(target.getBoundingClientRect().width)')! == '80'
	app.finish_frame_preparation()
	assert runtime.evaluate_host('taskPaintFilterRuns')! == '1'
	assert app.paint_commands.any(it.color == 'rgb(81 82 83)')
}

fn test_frame_task_layout_flushes_nested_frames_and_keeps_initial_layout_synchronous() {
	$if !darwin { return }
	mut app, mut runtime, mut document := javascript_task_paint_fixture('<!doctype html><div id="target" style="width:30px;height:20px;background:green"></div>')
	defer { runtime.close(); document.finalize() }
	app.begin_frame_preparation()
	app.begin_frame_preparation()
	run_javascript_task_paint_timer(runtime, 'target.style.width="70px";target.style.backgroundColor="rgb(71 72 73)"')
	app.poll_javascript_tasks()
	app.finish_frame_preparation()
	assert app.frame_preparation_depth == 1
	assert document.layout_is_up_to_date()
	assert app.paint_commands.any(it.color == 'rgb(71 72 73)')
	app.initial_layout_pending = true
	run_javascript_task_paint_timer(runtime, 'target.style.width="90px"')
	app.poll_javascript_tasks()
	assert !app.initial_layout_pending
	assert document.layout_is_up_to_date()
	target := document.get_element_by_id('target')?
	box := app.root_box.find_box(i64(target.as_node().unique_id())) or { panic('missing target box') }
	assert box.border_box().width == 90 * document.layout_coordinate_scale()
	app.finish_frame_preparation()
}
