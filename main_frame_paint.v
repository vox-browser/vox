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
		app.paint_commands = []layout.PaintCommand{}
		app.paint_display_list = unsafe { nil }
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
	// A synchronous query may already have recorded the new document's list.
	// Pending commands must still be adopted even when that cache is populated.
	// Also refresh invalidated scroll snapshots without requiring a relayout.
	if app.paint_commands_pending || app.javascript_tasks_have_unadopted_paint() {
		app.record_document_paint_commands()
	}
	// A nested native frame must present current commands too. The remaining
	// depth keeps subsequent work in the outer frame deferred until it presents.
}

fn (mut app BrowserApp) record_document_paint_commands() {
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	checkpoint := time.sys_mono_now()
	app.memory_maintenance.document_changed(checkpoint)
	mut document := unsafe { &dom.Document(app.document) }
	display_list := if app.ctx != unsafe { nil } && app.ctx.native_rendering {
		document.record_viewport_display_list()
	} else { document.record_display_list() }
	if list := display_list {
		previous_commands := app.paint_commands
		app.paint_display_list = list
		app.paint_commands = layout.display_list_commands(list)
		// The shell is the only reader of its adopted vector. Return the previous
		// one so the next recording can reuse its capacity instead of
		// allocating a fresh frame-sized vector.
		if previous_commands.data != app.paint_commands.data {
			layout.recycle_display_list_commands(list, previous_commands)
		}
		app.paint_commands_have_backdrop_filter = paint_commands_contain_backdrop_filter(app.paint_commands)
	} else {
		app.paint_commands = []layout.PaintCommand{}
		app.paint_display_list = unsafe { nil }
		app.paint_commands_have_backdrop_filter = false
	}
	// Recording can refresh paint-only styles in the retained transport without
	// a layout pass. Adopt that final snapshot as well as geometry changes.
	app.adopt_current_document_geometry()
	app.paint_commands_pending = false
	root_rect := app.root_box.border_box()
	app.status = '${app.load_status} · ${app.paint_commands.len} paints · ${int(root_rect.width)}×${int(root_rect.height)} CSS px'
	debug_timing_checkpoint('  paint_commands', checkpoint)
}

fn (app &BrowserApp) javascript_tasks_have_unadopted_paint() bool {
	if app.layout_tree_only { return false }
	if cached := app.document.cached_display_list() {
		return voidptr(cached) != voidptr(app.paint_display_list)
	}
	return true
}
