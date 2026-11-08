module main

import os
import layout
import platform

const disable_frame_task_layout_coalescing = os.getenv('VOX_DISABLE_FRAME_TASK_LAYOUT_COALESCING') == '1'
const frame_task_layout_diagnostics = os.getenv('VOX_FRAME_TASK_LAYOUT_DIAGNOSTICS') == '1'

__global frame_task_layout_reported bool

// Replayed input belongs to the frame's preparation too. A wheel can apply
// pending script effects after its synchronous hit-test layout. Starting this
// boundary later forced a second shell layout and paint recording immediately,
// ahead of the frame's normal script/resource flush. Event geometry queries
// retain their synchronous Document update boundary.
fn (mut app BrowserApp) prepare_frame_page_input() {
	app.prepare_browser_navigation_icons()
	app.begin_frame_preparation()
	app.queue_frame_aligned_wheel_for_replay()
	app.poll_deferred_page_input()
}

// A frame can poll script effects before subsequent resource callbacks mutate
// the same document. Preserve the shell's scale and cosmetic-filter work now,
// then let finish_frame_preparation flush the final document. DOM geometry and
// paint queries still use Document's synchronous update boundary in between.
fn (mut app BrowserApp) defer_javascript_layout_to_current_frame() bool {
	if disable_frame_task_layout_coalescing || app.frame_preparation_depth == 0
		|| app.initial_layout_pending || app.layout_tree_only
		|| app.applied_page_zoom != app.page_zoom
		|| app.document.autofocus_candidates().len > 0
		|| layout.document_layout_result(app.document) == none {
		return false
	}
	// Focused editing can schedule additional shadow/layout work while the
	// shell adopts geometry. Keep its full synchronous shell layout boundary.
	if focused := app.document.focused_area() {
		if voidptr(focused) != voidptr(app.document.as_node()) { return false }
	}
	mut heap_scope := platform.begin_browser_activity_heap_scope_for_scripting(app.document_scripting_enabled_for_heap())
	defer { heap_scope.finish() }
	app.sync_layout_coordinate_scale()
	app.refresh_browser_adblock()
	if app.js_runtime != unsafe { nil } { app.js_runtime.take_document_replay_effects() }
	app.sync_window_activity()
	app.paint_commands_pending = true
	if frame_task_layout_diagnostics && !frame_task_layout_reported {
		frame_task_layout_reported = true
		eprintln('Vox frame task layout: deferred unqueried geometry to frame completion')
	}
	return true
}
