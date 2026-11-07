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

// Release the shell's paint tree and commands for the displayed document. A
// document kept in the back/forward cache keeps its computed styles and
// layout; only its paint commands are recorded again when it is shown.
fn (mut app BrowserApp) release_document_rendering() {
	app.root_box = layout.BlockBox{}
	layout.release_paint_tree(app.paint_tree_storage)
	app.paint_tree_storage = unsafe { nil }
	app.release_paint_commands()
	app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	app.chromium_raster_tiles = [][]i32{}
	app.paint_commands_have_backdrop_filter = false
	app.paint_commands_pending = false
}
