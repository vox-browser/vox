module main

import layout
import os
import painting

// The Windows release uses -gc none. Keep the per-draw raster path
// opt-in until its working set is measured in a Windows process.
const portable_web_font_enabled = $if windows {
	os.getenv('VOX_PORTABLE_WEB_FONTS') == '1'
} $else {
	true
}

fn (mut app BrowserApp) draw_portable_web_font(command &layout.PaintCommand, page_x f32,
	page_y f32, scroll_y f64) bool {
	scale := f64(app.ctx.scale)
	// The existing glyph renderer works in document pixels. Move the
	// viewport back to that coordinate space before rounding to texels.
	viewport := portable_pixel_bounds(app.portable_device_viewport(page_y).translated(
		painting.Point{-f64(page_x) * scale, (scroll_y - f64(page_y)) * scale}))
	bitmap := layout.rasterize_portable_text(*command, scale, viewport) or { return false }
	if bitmap.width > 0 && bitmap.height > 0 {
		app.draw_portable_raster_image(bitmap.x + page_x, bitmap.y + page_y - f32(scroll_y),
			bitmap.width, bitmap.height, bitmap.pixels)
	}
	return true
}
