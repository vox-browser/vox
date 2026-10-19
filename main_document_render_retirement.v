module main

import css
import dom
import layout

// The old native surface stays presented while synchronous navigation work
// prepares its replacement. Once the old realm closes, the shell no longer
// needs its paint tree or command storage during the new style/layout pass.
fn (mut app BrowserApp) retire_native_document_rendering(previous &dom.Document) bool {
	if !css.discard_native_document_computed_styles(previous) { return false }
	app.root_box = layout.BlockBox{}
	app.release_paint_commands()
	app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	app.chromium_raster_tiles = [][]i32{}
	app.paint_commands_have_backdrop_filter = false
	app.paint_commands_pending = false
	return true
}
