module main

import layout

fn C.native_begin_stationary_raster(u64, u64, u64, f64, f64, f64, f64, i32) i32
fn C.native_end_stationary_raster()
fn C.native_discard_stationary_raster()

fn stationary_document_raster_eligible(commands []layout.PaintCommand) bool {
	for command in commands {
		if command.kind in ['draw_canvas', 'draw_video', 'draw_nested_document',
			'paint_nested_display_list'] {
			return false
		}
	}
	return true
}

// Canvas and media can provide new pixels during replay without replacing the
// display list. Animated native images also veto storage while being painted.
fn (app &BrowserApp) begin_stationary_document_raster() bool {
	$if macos {
		eligible := stationary_document_raster_eligible(app.paint_commands)
		return C.native_begin_stationary_raster(u64(app.document.unique_id().value()),
			app.document.paint_content_revision(), app.paint_generation, app.scroll_y,
			f64(app.page_top()), app.page_zoom, app.overlay_scrollbars.paint_opacity,
			i32(eligible)) != 0
	}
	return false
}
