module main

import gg
import ggshape
import layout
import math
import painting

// Keep opaque, unscaled sRGB JPEG XL circles and their coverage in one draw.
// Other geometry and transparent frames retain the platform image path.
fn (mut app BrowserApp) draw_sampled_jpegxl_circle(command &layout.PaintCommand, image &gg.Image,
	url string, destination painting.IntRect, source [4]f32, clip [12]f32, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f64, nearest bool) bool {
	if app.document == unsafe { nil } || app.document.font_rendering_policy() != .chromium
		|| command.apply_force_dark_to_image || nearest || command.opacity != 1
		|| C.native_document_raster_uses_p3() != 0
		|| image.path != '' || image.nr_channels != 7 || image.data == unsafe { nil }
		|| image.width <= 0 || image.width > 128 || image.width != image.height
		|| destination.width != image.width || destination.height != image.height
		|| source != [f32(0), 0, f32(image.width), f32(image.height)]!
		|| matrix[0] != 1 || matrix[1] != 0 || matrix[2] != 0 || matrix[3] != 1
		|| clip[0] != destination.x || clip[1] != destination.y
		|| clip[2] != image.width || clip[3] != image.height
		|| clip[4..12].any(it != f32(image.width) * .5) {
		return false
	}
	geometry := sampled_png_paint_geometry(destination, clip, matrix) or { return false }
	left, top := geometry.x + page_x, geometry.y + page_y - f32(scroll_y)
	if left != math.floor(left) || top != math.floor(top) { return false }
	bytes := app.background_image_decode_bytes(url) or { return false }
	if !image_bytes_are_jpegxl(bytes) { return false }
	return C.native_draw_sampled_png(image.data, i32(image.width), i32(image.height),
		i32(image.width), i32(image.height), 7, geometry.x, geometry.y,
		geometry.width, geometry.height, &geometry.clip[0], page_x, page_y, f32(scroll_y),
		f32(app.ctx.width), f32(app.ctx.height)) != 0
}

@[export: 'vox_document_jpegxl_circle_pixels']
fn document_jpegxl_circle_pixels(pixels &u8, width i32, height i32, pitch i32, backdrop i32,
	first_x i32, first_y i32, source &u8, sw i32, sh i32, nw i32, nh i32, mode i32,
	x f32, y f32, dw f32, dh f32, clip &f32) i32 {
	if source == unsafe { nil } || clip == unsafe { nil } || sw <= 0 || sw > 128
		|| sh != sw || nw != sw || nh != sh || dw != sw || dh != sh || mode != 7 {
		return 0
	}
	mut clipping := [12]f32{}
	unsafe { vmemcpy(&clipping[0], clip, 12 * int(sizeof(f32))) }
	packed := unsafe { source.vbytes(int(sw) * int(sh) * 4) }
	swap_document_raster_channels(pixels, width, height, pitch)
	defer { swap_document_raster_channels(pixels, width, height, pitch) }
	mut result := draw_document_sampled_image_tiles(pixels, width, height, pitch, backdrop,
		int(first_x), int(first_y), packed, int(sw), int(sh), x, y, dw, dh, int(nw), int(nh),
		clipping, .rgba_quad, false)
	if result == 0 {
		samples := document_image_sample_count(first_x, first_y, width, height)
		if samples != 0 {
			result = ggshape.draw_sampled_image_quad_rgba(pixels, width, height, pitch, backdrop,
				packed, int(sw), int(sh), x, y, int(samples), clipping)
		}
	}
	return result
}
