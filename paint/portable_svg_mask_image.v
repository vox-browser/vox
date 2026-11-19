module main

import cpuraster
import layout
import math
import painting

fn (mut app BrowserApp) raster_svg_mask_image(mut layer PortableSVGMaskLayer, width int, pitch int,
	operation &layout.PaintMaskOperation, matrix [6]f32) ?bool {
	if operation.opacity == 0 { return true }
	// While a request is outstanding, its transparent contribution must not
	// become a retained group texture.
	image := app.background_image(operation.image_url) or { return false }
	if image.data == unsafe { nil } || image.nr_channels != 4 || image.width <= 0
		|| image.height <= 0 || image.width > 0x1fffffff / image.height
		|| !matrix.all(math.is_finite(f64(it))) {
		return none
	}
	rect := operation.image_rect
	replay := resolved_svg_operation_image(operation.image_paintable,
		painting.Rect{rect.x, rect.y, rect.width, rect.height}, operation.image_position_x,
		operation.image_position_y, operation.image_rendering, image.width, image.height) or {
		return true
	}
	dest := replay.destination
	clip := replay.clip
	visible := clip.intersection(dest)
	if visible.is_empty() { return true }
	mut transform := matrix
	transform[5] -= f32(layer.rows.top)
	mut clips := []cpuraster.Path{}
	if visible != dest {
		mut path := cpuraster.PathBuilder{}
		path.move_to(f32(clip.x), f32(clip.y))
		path.line_to(f32(clip.right()), f32(clip.y))
		path.line_to(f32(clip.right()), f32(clip.bottom()))
		path.line_to(f32(clip.x), f32(clip.bottom()))
		path.close()
		clips << path.detach().transform(cpuraster.Matrix{transform[0], transform[1], transform[2],
			transform[3], transform[4], transform[5]})
	}
	image_pitch := image.width * 4
	bitmap := cpuraster.CanvasBitmap{
		pixels: unsafe { (&u8(image.data)).vbytes(image_pitch * image.height) }
		width: image.width
		height: image.height
		pitch: image_pitch
	}
	if !cpuraster.draw_canvas_image(mut layer.pixels, width, layer.rows.height(), pitch, 2,
		transform, bitmap, [f32(0), 0, f32(image.width), f32(image.height)]!,
		[f32(dest.x), f32(dest.y), f32(dest.width), f32(dest.height)]!,
		replay.scaling != .nearest_neighbor, f32(operation.opacity), .src_over, clips) {
		return none
	}
	return true
}
