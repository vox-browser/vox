module ggshape

import gg.canvas
import math

// Small unscaled images can keep clip coverage in the GPU color calculation
// instead of quantizing a separate alpha mask. Rows are straight RGBA; the
// destination is the same premultiplied BGRA surface as the geometry adapter.
pub fn draw_rounded_image_pixels(pixels &u8, width int, height int, pitch int,
	source []u8, image_width int, image_height int, x f32, y f32, radius f32) bool {
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || pitch < width * 4 || image_width <= 0 || image_height <= 0 || image_width > 32 || image_height > 32 || image_width * image_height > 256 || source.len != image_width * image_height * 4 || !math.is_finite(radius) || radius <= 0 || C.pthread_main_np() == 0 {
		return false
	}
	mut ctx := context() or { return false }
	mut target := ctx.new_surface(width: width, height: height) or { return false }
	defer { target.free() }
	target.write_pixels(pixels, pitch) or { return false }
	rect := canvas.Rect.xywh(x, y, f32(image_width), f32(image_height))
	target.clip_rrect(canvas.RRect.rect_radii(rect, [canvas.Point{radius, radius},
		canvas.Point{radius, radius}, canvas.Point{radius, radius}, canvas.Point{radius, radius}]!), .intersect, true) or { return false }
	for row in 0 .. image_height {
		for col in 0 .. image_width {
			i := (row * image_width + col) * 4
			if source[i + 3] == 0 { continue }
			// Keep the full rounded geometry for each color. A one-pixel draw
			// changes clip reduction and its edge coverage; an integer scissor
			// selects the texel while preserving that geometry.
			target.save()
			target.clip_rect(canvas.Rect.xywh(x + f32(col), y + f32(row), 1, 1), .intersect, false) or { return false }
			target.draw_rect(rect, canvas.Paint{ color: canvas.Color4f.from_rgba8(source[i], source[i + 1], source[i + 2], source[i + 3]), anti_alias: false }) or { return false }
			target.restore()
		}
	}
	target.read_pixels(pixels, pitch) or { return false }
	return true
}

// The native raster boundary transports premultiplied RGBA destination rows;
// gg.canvas reads and writes BGRA. Source rows remain straight RGBA.
@[export: 'vox_document_rounded_image_pixels']
fn document_rounded_image_pixels(pixels &u8, width i32, height i32, pitch i32,
	source &u8, image_width i32, image_height i32, x f32, y f32, radius f32) i32 {
	if pixels == unsafe { nil } || source == unsafe { nil } || width <= 0 || height <= 0
		|| width > 64 || height > 64 || pitch != width * 4 || image_width <= 0 || image_height <= 0
		|| image_width > 32 || image_height > 32 || image_width * image_height > 256 {
		return 0
	}
	mut rows := unsafe { pixels.vbytes(int(pitch) * int(height)) }
	for i in 0 .. int(width) * int(height) {
		rows[i * 4], rows[i * 4 + 2] = rows[i * 4 + 2], rows[i * 4]
	}
	defer {
		for i in 0 .. int(width) * int(height) {
			rows[i * 4], rows[i * 4 + 2] = rows[i * 4 + 2], rows[i * 4]
		}
	}
	return int(draw_rounded_image_pixels(pixels, int(width), int(height), int(pitch),
		unsafe { source.vbytes(int(image_width) * int(image_height) * 4) }, int(image_width), int(image_height), x, y, radius))
}
