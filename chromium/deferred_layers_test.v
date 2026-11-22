module main

import dom
import html
import layout

fn deferral_test_app(mut document dom.Document) BrowserApp {
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document}
	app.relayout(800, 600 + app.chrome_height())
	app.paint_commands = []layout.PaintCommand{len: 64, init: layout.PaintCommand{
		kind: 'fill_rect'
		x: f64(index % 8) * 10
		y: f64(index / 8) * 20
		width: 5
		height: 10
	}}
	app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	return app
}

fn test_the_first_qualifying_frame_is_not_deferred_and_enters_the_scroll_raster_ring() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div style="height:2000px"></div>')
	mut app := deferral_test_app(mut document)
	defer {
		app.release_paint_commands()
		document.finalize()
	}
	// No frame has qualified yet: the decision must not lag one frame behind.
	assert !app.scroll_raster_content_eligible
	assert app.begin_raster_frame_deferral(true) == 2
	assert !app.scroll_raster_frame_deferred
	_ = app.begin_scroll_raster()
	assert app.scroll_raster_content_eligible
	assert app.scroll_raster_keys.valid
	assert app.begin_raster_frame_deferral(true) == 2
	assert app.begin_raster_frame_deferral(false) == 0
	assert !app.scroll_raster_frame_deferred
}

fn test_content_outside_the_scroll_raster_ring_keeps_root_picture_deferral() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div style="height:2000px"></div>')
	mut app := deferral_test_app(mut document)
	defer {
		app.release_paint_commands()
		document.finalize()
	}
	app.paint_canvas_culling_disabled = true
	assert app.begin_raster_frame_deferral(true) == 1
	assert app.scroll_raster_frame_deferred
	_ = app.begin_scroll_raster()
	assert !app.scroll_raster_content_eligible
	assert !app.scroll_raster_keys.valid
}
