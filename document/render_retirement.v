module main

import css
import dom
import layout

// The old native surface stays presented while synchronous navigation work
// prepares its replacement. Once the old realm closes, the shell no longer
// needs its paint tree or command storage during the new style/layout pass.
fn (mut app BrowserApp) retire_native_document_rendering(previous &dom.Document) bool {
	if !css.discard_native_document_computed_styles(previous) { return false }
	app.release_document_rendering()
	return true
}

// Release the session's adopted paint tree and commands. A
// document kept in the back/forward cache keeps its computed styles and
// layout; only its paint commands are recorded again when it is shown.
fn (mut app BrowserApp) release_document_rendering() {
	mut session := app.document_session()
	session.release_document_rendering()
}

fn (mut session DocumentSession) release_document_rendering() {
	// Replay scratch contains shallow command payloads. Detach every borrowed
	// view before dropping the leases that keep those payloads readable.
	session.rounded_rect_underlay = none
	session.rounded_rect_underlay_source = none
	session.background_image_border = none
	session.background_image_border_consumed = false
	session.draw_command_copies = []&layout.PaintCommand{}
	session.root_box = layout.BlockBox{}
	layout.release_paint_tree(session.paint_tree_storage)
	session.paint_tree_storage = unsafe { nil }
	session.release_paint_commands()
	session.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	session.chromium_raster_tiles = [][]i32{}
	session.chromium_raster_grids = []ChromiumRasterGrid{}
	session.paint_commands_have_backdrop_filter = false
	session.paint_commands_pending = false
}
