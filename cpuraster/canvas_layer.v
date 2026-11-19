module cpuraster

// restore_canvas_opacity_layer composites a premultiplied layer at the
// origin of a target of the same width. Native N32 uses the legacy sprite
// blend. Other RGBA surfaces can blend directly into the layer's rows.
pub fn restore_canvas_opacity_layer(mut pixels []u8, pitch int, target_height int, image CanvasBitmap, opacity f32) bool {
	if image.height > target_height || !untiled_device(pixels, image.width, target_height, pitch) {
		return false
	}
	if !canvas_rgba_uses_legacy() && restore_lowp_canvas_layer(mut pixels, pitch, image, opacity) {
		return true
	}
	rect := [f32(0), 0, f32(image.width), f32(image.height)]!
	return draw_canvas_image(mut pixels, image.width, target_height, pitch, 2,
		[f32(1), 0, 0, 1, 0, 0]!, image, rect, rect, false, opacity, .src_over, [])
}

fn restore_lowp_canvas_layer(mut pixels []u8, pitch int, image CanvasBitmap, opacity f32) bool {
	width, height := image.width, image.height
	if !image.premultiplied || image.display_p3 || !(opacity >= 0 && opacity <= 1)
		|| !untiled_device(image.pixels, width, height, image.pitch)
		|| !untiled_device(pixels, width, height, pitch)
		|| raster_spans_overlap(u64(uint(image.pixels.data)), image.pixels.len,
			u64(uint(pixels.data)), pixels.len) {
		return false
	}
	alpha := u32(u8(opacity * f32(255)))
	if alpha == 0 {
		return true
	}
	scan := SpriteBlendScan{
		source:       image.pixels
		target:       pixels
		source_pitch: image.pitch
		target_pitch: pitch
		width:        width
		alpha:        alpha
	}
	run_raster_scans(&scan, height, width, restore_lowp_canvas_layer_rows)
	return true
}

@[direct_array_access]
fn restore_lowp_canvas_layer_rows(context voidptr, first i32, end i32) {
	scan := unsafe { &SpriteBlendScan(context) }
	mut target := unsafe { scan.target }
	for y in int(first) .. int(end) {
		source_row := y * scan.source_pitch
		target_row := y * scan.target_pitch
		if scan.alpha == 255 {
			for x in 0 .. scan.width {
				src := load32_unchecked(scan.source, source_row + x * 4)
				blit_s32a_opaque_pixel(mut target, target_row + x * 4, src)
			}
			continue
		}
		for x in 0 .. scan.width {
			src := load32_unchecked(scan.source, source_row + x * 4)
			if src == 0 {
				continue
			}
			inverse_alpha := 255 - lowp_div255((src >> 24) * scan.alpha)
			offset := target_row + x * 4
			for channel in 0 .. 4 {
				value := (src >> (8 * channel)) & 255
				scaled := lowp_div255(value * scan.alpha)
				backdrop := lowp_div255(u32(target[offset + channel]) * inverse_alpha)
				target[offset + channel] = u8(lowp_min(scaled + backdrop, 255))
			}
		}
	}
}
