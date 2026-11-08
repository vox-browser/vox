module cpuraster

// Resolve a deferred color filter before the next non-identity blur reads
// pixels. The transparent padding remains zero for these color filters.
fn filter_layer_image(image BlurImage, filter ColorFilter) BlurImage {
	mut pixels := []u8{len: image.pixels.len}
	bitmap := CanvasBitmap{pixels: image.pixels, width: image.width, height: image.height,
		pitch: image.width * 4, premultiplied: true}
	shader := new_image_shader(bitmap, .clamp, .clamp, false, SkAffine{})
	bounds := Rect{0, 0, f32(image.width), f32(image.height)}
	if mut blitter := canvas_filtered_blitter(mut pixels, image.width * 4, 0xff000000,
		shader, 1, .src, bounds, filter, true) {
		blitter.blit_rect(0, 0, image.width, image.height)
	}
	return BlurImage{pixels, image.width, image.height}
}

// FilterResult's deferred color filter is evaluated on the source shader
// before the restore blend, rather than baking it into an 8-bit sprite.
fn draw_color_filtered_sprite(mut pixels []u8, pitch int, image BlurImage, x int, y int, rc &RasterClip, mode BlendMode, matrices []MatrixColorFilter) {
	filter := new_color_filter(matrices) or {
		draw_filter_sprite(mut pixels, pitch, image, x, y, rc, mode)
		return
	}
	bounds := IRect{x, y, x + image.width, y + image.height}
	unbounded := blend_affects_transparent_black(mode)
	tile := if unbounded { TileMode.decal } else { .clamp }
	bitmap := CanvasBitmap{pixels: image.pixels, width: image.width, height: image.height,
		pitch: image.width * 4, premultiplied: true}
	shader := new_image_shader(bitmap, tile, tile, false, affine_translate(f32(x), f32(y)))
	dev := if unbounded { rc.bounds() } else { bounds }
	if mut blitter := canvas_filtered_blitter(mut pixels, pitch, 0xff000000, shader, 1, mode,
		Rect{f32(dev.left), f32(dev.top), f32(dev.right), f32(dev.bottom)}, filter, canvas_rgba_uses_legacy()) {
		fill_irect(dev, rc, mut blitter)
	}
}
