module main

import dom
import layout
import time
import platform

// Native frame preparation can install a document, run callbacks, relayout and
// sample animations before presenting any pixels. Keep layout synchronous, but
// assemble the shell's paint commands only after those updates. DOM APIs can
// still record a display list synchronously whenever they need one.
fn (mut app BrowserApp) begin_frame_preparation() {
	app.frame_preparation_depth++
}

fn (mut app BrowserApp) finish_frame_preparation() {
	if app.frame_preparation_depth == 0 { return }
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	app.frame_preparation_depth--
	app.flush_page_editing_scroll()
	if app.layout_tree_only { return }
	if app.document == unsafe { nil } {
		app.release_paint_commands()
		app.paint_commands_have_backdrop_filter = false
		app.paint_commands_pending = false
		return
	}
	// Boundary events such as mouseleave can leave a pending CSS state change.
	// Commit it before consulting the cached display list for this frame.
	mut document := unsafe { &dom.Document(app.document) }
	if document.needs_style_update_after_layout() || !document.layout_is_up_to_date() {
		document.update_layout(.html_event_loop_rendering_update)
		app.adopt_current_document_geometry()
	}
	app.scroll_profile_mark('layout')
	// A synchronous query may already have recorded the new document's list.
	// Pending commands must still be adopted even when that cache is populated.
	// Also refresh invalidated scroll snapshots without requiring a relayout.
	if app.paint_commands_pending || app.javascript_tasks_have_unadopted_paint() {
		app.record_document_paint_commands()
	}
	// A nested native frame must present current commands too. The remaining
	// depth keeps subsequent work in the outer frame deferred until it presents.
}

// The values app.status shows after a recording.
struct PaintStatusKey {
	load_status     &u8 = unsafe { nil }
	load_status_len int
	commands        int
	width           int
	height          int
}

fn (mut app BrowserApp) record_document_paint_commands() {
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	checkpoint := time.sys_mono_now()
	app.memory_maintenance.document_changed(checkpoint)
	mut document := unsafe { &dom.Document(app.document) }
	display_list := if app.ctx != unsafe { nil } && app.ctx.native_rendering
		&& !app.paint_canvas_culling_disabled {
		document.record_viewport_display_list()
	} else { document.record_display_list() }
	if list := display_list {
		previous_commands := app.paint_commands
		previous_scene := app.paint_scene
		app.paint_display_list = list
		app.paint_generation++
		app.paint_commands = layout.display_list_commands(list)
		app.paint_scene = layout.retain_display_list_scene(list)
		layout.release_display_list_scene(previous_scene)
		// The shell is the only reader of its adopted vector. Return the previous
		// one so the next recording can reuse its capacity instead of
		// allocating a fresh frame-sized vector.
		if previous_commands.data != app.paint_commands.data {
			layout.recycle_display_list_commands(list, previous_commands)
		}
		app.paint_commands_have_backdrop_filter = paint_commands_contain_backdrop_filter(app.paint_commands)
	} else {
		app.release_paint_commands()
		app.paint_commands_have_backdrop_filter = false
	}
	// Recording can refresh paint-only styles in the retained transport without
	// a layout pass. Adopt that final snapshot as well as geometry changes.
	app.adopt_current_document_geometry()
	if document.font_rendering_policy() == .chromium {
		mut raster_scale := 1.0
		$if macos { raster_scale = C.native_display_device_pixel_ratio() }
		app.chromium_raster_plan = layout.chromium_raster_layer_plan(document, app.paint_commands,
			raster_scale)
	} else {
		app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	}
	app.paint_commands_pending = false
	root_rect := app.root_box.border_box()
	// Animation frames re-record without changing what the status shows.
	status_key := PaintStatusKey{
		load_status: app.load_status.str
		load_status_len: app.load_status.len
		commands: app.paint_commands.len
		width: int(root_rect.width)
		height: int(root_rect.height)
	}
	if status_key != app.paint_status_key || app.status.str != app.paint_status_text.str {
		app.paint_status_key = status_key
		app.status = '${app.load_status} · ${app.paint_commands.len} paints · ${int(root_rect.width)}×${int(root_rect.height)} CSS px'
		app.paint_status_text = app.status
	}
	debug_timing_checkpoint('  paint_commands', checkpoint)
}

fn (app &BrowserApp) javascript_tasks_have_unadopted_paint() bool {
	if app.layout_tree_only { return false }
	if cached := app.document.cached_display_list() {
		return voidptr(cached) != voidptr(app.paint_display_list)
	}
	return true
}

// Stop replaying the adopted commands and let their scene be reused.
fn (mut app BrowserApp) release_paint_commands() {
	app.paint_commands = []layout.PaintCommand{}
	app.paint_display_list = unsafe { nil }
	layout.release_display_list_scene(app.paint_scene)
	app.paint_scene = unsafe { nil }
}
