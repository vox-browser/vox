module main

import dom
import layout
import time

// Native frame preparation can install a document, run callbacks, relayout and
// sample animations before presenting any pixels. Keep layout synchronous, but
// assemble the shell's paint commands only after those updates. DOM APIs can
// still record a display list synchronously whenever they need one.
fn (mut app BrowserApp) begin_frame_preparation() {
	app.frame_preparation_depth++
}

fn (mut app BrowserApp) finish_frame_preparation() {
	if app.frame_preparation_depth == 0 { return }
	app.frame_preparation_depth--
	if app.layout_tree_only { return }
	if app.document == unsafe { nil } {
		app.paint_commands = []layout.PaintCommand{}
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
	if app.paint_commands_pending || app.document.cached_display_list() == none {
		app.record_document_paint_commands()
	}
	// A nested native frame must present current commands too. The remaining
	// depth keeps subsequent work in the outer frame deferred until it presents.
}

fn (mut app BrowserApp) record_document_paint_commands() {
	checkpoint := time.sys_mono_now()
	mut document := unsafe { &dom.Document(app.document) }
	if display_list := document.record_display_list() {
		app.paint_commands = layout.display_list_commands(display_list)
		app.paint_commands_have_backdrop_filter = paint_commands_contain_backdrop_filter(app.paint_commands)
	} else {
		app.paint_commands = []layout.PaintCommand{}
		app.paint_commands_have_backdrop_filter = false
	}
	app.paint_commands_pending = false
	root_rect := app.root_box.border_box()
	app.status = '${app.load_status} · ${app.paint_commands.len} paints · ${int(root_rect.width)}×${int(root_rect.height)} CSS px'
	debug_timing_checkpoint('  paint_commands', checkpoint)
}
