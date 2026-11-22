module main

import os

fn C.native_begin_deferred_layer_frame(i32)
fn C.native_finish_deferred_layer_frame() i32

// Same-binary control: keep every leaf raster immediate in frames that qualify
// for viewport scroll reuse, even inside compositor layers.
const disable_reused_frame_layer_deferral = os.getenv('VOX_DISABLE_REUSED_FRAME_LAYER_DEFERRAL') != ''

// Same-binary control: choose each frame's layer deferral from the previous
// frame's scroll raster eligibility.
const lagged_raster_frame_deferral = os.getenv('VOX_LAGGED_RASTER_FRAME_DEFERRAL') != ''

// The deferred layer mode of a frame's first replay attempt: 1 lets root
// pictures defer leaf rasters, 2 only compositor layers, which publish within
// the command replay. A deferred frame cannot enter the scroll raster ring, so
// the mode follows this frame's commands. Deciding from the previous frame
// deferred the first frame whose content qualified; the next frame then had no
// retained pixels and rastered the complete viewport again.
fn (mut app BrowserApp) begin_raster_frame_deferral(chromium bool) i32 {
	mut eligible := app.scroll_raster_content_eligible
	if chromium && !eligible && !lagged_raster_frame_deferral {
		app.update_chromium_viewport_raster_plan()
		eligible = app.scroll_raster_content_qualifies()
	}
	enabled := chromium && !eligible
	layers_only := chromium && eligible && !disable_reused_frame_layer_deferral
	app.scroll_raster_frame_deferred = enabled
	return if enabled { 1 } else if layers_only { 2 } else { 0 }
}
