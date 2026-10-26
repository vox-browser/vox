module main

import layout

// Preserve per-sample coverage across the image clip's restore and the next
// border. If native repeated-image replay declines, retain ordinary replay of
// the border and all of the image's fallback paths.
fn (mut app BrowserApp) draw_chromium_background_border_group(index int,
	image layout.PaintCommand, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| index + 1 >= app.paint_commands.len {
			return index
		}
		layers := app.chromium_raster_plan.command_layers
		if index + 1 < layers.len && layers[index] != layers[index + 1] { return index }
		border := app.zoomed_paint_command(app.paint_commands[index + 1])
		if !layout.background_image_border_can_share_pass(image, border) { return index }
		app.background_image_border = border
		app.background_image_border_consumed = false
		app.draw_command(image, 0, page_y, window_height)
		consumed := app.background_image_border_consumed
		app.background_image_border = none
		app.background_image_border_consumed = false
		return index + if consumed { 2 } else { 1 }
	}
	return index
}
