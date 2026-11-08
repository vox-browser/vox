module cpuraster

// Resolve source conversion and a deferred color filter before a real blur
// reads pixels. Transparent padding remains zero for these color filters.
fn filter_layer_source_image(image BlurImage, info FilterImageInfo, filter ?ColorFilter) BlurImage {
	mut pixels := []u8{len: image.pixels.len}
	bitmap := info.bitmap(image)
	shader := new_image_shader(bitmap, .clamp, .clamp, false, SkAffine{})
	bounds := Rect{0, 0, f32(image.width), f32(image.height)}
	if mut blitter := canvas_draw_blitter_for_surface(mut pixels, image.width * 4, 0xff000000,
		shader, info.alpha, .src, bounds, filter, info.alpha == 1) {
		blitter.blit_rect(0, 0, image.width, image.height)
	}
	return BlurImage{pixels, image.width, image.height}
}

// FilterResult's deferred color filter is evaluated on the source shader
// before the restore blend, rather than baking it into an 8-bit sprite.
fn draw_color_filtered_sprite(mut pixels []u8, pitch int, image BlurImage, x int, y int, rc &RasterClip, mode BlendMode, matrices []MatrixColorFilter) {
	draw_color_filtered_bitmap(mut pixels, pitch, FilterImageInfo{}.bitmap(image), x, y, rc, mode, matrices, 1)
}

fn draw_color_filtered_bitmap(mut pixels []u8, pitch int, bitmap CanvasBitmap, x int, y int, rc &RasterClip, mode BlendMode, matrices []MatrixColorFilter, source_alpha f32) {
	filter := new_color_filter(matrices) or {
		draw_filter_bitmap(mut pixels, pitch, bitmap, x, y, rc, mode, source_alpha)
		return
	}
	bounds := IRect{x, y, x + bitmap.width, y + bitmap.height}
	unbounded := blend_affects_transparent_black(mode)
	tile := if unbounded { TileMode.decal } else { .clamp }
	shader := new_image_shader(bitmap, tile, tile, false, affine_translate(f32(x), f32(y)))
	dev := if unbounded { rc.bounds() } else { bounds }
	if mut blitter := canvas_filtered_blitter(mut pixels, pitch, 0xff000000, shader, source_alpha, mode,
		Rect{f32(dev.left), f32(dev.top), f32(dev.right), f32(dev.bottom)}, filter, canvas_rgba_uses_legacy()) {
		fill_irect(dev, rc, mut blitter)
	}
}
