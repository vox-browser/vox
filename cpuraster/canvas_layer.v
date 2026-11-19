module cpuraster

// canvas_pixel_aligned_rect recognizes a closed four-corner contour
// without allocating a decoded path.
pub fn canvas_pixel_aligned_rect(segments []f32, transform [6]f32) ?IRect {
	stride := canvas_path_segment_stride
	if segments.len != 5 * stride && segments.len != 6 * stride {
		return none
	}
	if segments[0] != 0 || segments[segments.len - stride] != 5 {
		return none
	}
	if segments.len == 6 * stride && (segments[4 * stride] != 1
		|| segments[4 * stride + 1] != segments[1] || segments[4 * stride + 2] != segments[2]) {
		return none
	}
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	mut corners := [4]Point{}
	// Verify the same device coordinates used by canvas replay.
	limit := f32(max_untiled_dimension)
	for i in 0 .. corners.len {
		offset := i * stride
		if i > 0 && segments[offset] != 1 {
			return none
		}
		point := matrix.map_point(Point{segments[offset + 1], segments[offset + 2]})
		if !(point.x >= -limit && point.x <= limit && point.y >= -limit && point.y <= limit)
			|| point.x != floor_f32(point.x) || point.y != floor_f32(point.y) {
			return none
		}
		corners[i] = point
	}
	verbs := [PathVerb.move, .line, .line, .line, .close]!
	rect := trivial_rect(corners[..], verbs[..]) or { return none }
	pixels := IRect{int(rect.left), int(rect.top), int(rect.right), int(rect.bottom)}
	if pixels.is_empty() {
		return none
	}
	return pixels
}

// fill_opaque_canvas_mask_rect paints an aligned path rectangle into a
// premultiplied mask band. Every covered pixel has full source-over coverage.
pub fn fill_opaque_canvas_mask_rect(mut pixels []u8, width int, first_row int, height int,
	pitch int, segments []f32, transform [6]f32, color u32) bool {
	if color >> 24 != 255 || !untiled_device(pixels, width, height, pitch)
		|| first_row < 0 || first_row > max_untiled_dimension - height {
		return false
	}
	rect := canvas_pixel_aligned_rect(segments, transform) or { return false }
	visible := rect.intersect(IRect{0, first_row, width, first_row + height}) or { return true }
	mut blitter := new_solid_blitter(mut pixels, pitch, color)
	blitter.blit_rect(visible.left, visible.top - first_row, visible.width(), visible.height())
	return true
}

// fill_canvas_mask_path fills a solid or gradient path into a premultiplied
// row band. Geometry and shading both use the original device coordinates.
pub fn fill_canvas_mask_path(mut pixels []u8, width int, first_row int, height int, pitch int, path Path,
	transform [6]f32, color u32, style ?CanvasPaintStyle, opacity f32) bool {
	return fill_canvas_mask_path_surface(mut pixels, width, first_row, height, pitch, path,
		transform, color, style, opacity, canvas_rgba_uses_legacy())
}

fn fill_canvas_mask_path_surface(mut pixels []u8, width int, first_row int, height int, pitch int, path Path,
	transform [6]f32, color u32, style ?CanvasPaintStyle, opacity f32, legacy bool) bool {
	if first_row == 0 {
		return fill_canvas_path_surface(mut pixels, width, height, pitch, 2, path, transform, color,
			style, opacity, .src_over, 0, [], none, legacy)
	}
	if path.is_inverse_fill() || !untiled_device(pixels, width, height, pitch)
		|| first_row < 0 || first_row > max_untiled_dimension - height {
		return false
	}
	if paint_style := style {
		if paint_style is CanvasPattern {
			return false
		}
	}
	paint_color, _ := canvas_paint_source(color, style, 0)
	alpha := canvas_paint_alpha(paint_color, opacity)
	if paint_draws_nothing(.src_over, paint_alpha_byte(alpha), none) {
		return true
	}
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	device := path.transform(matrix)
	shader := canvas_paint_shader(style, matrix)
	mut blitter := canvas_paint_blitter_for_surface(mut pixels, pitch, paint_color, shader, alpha,
		.src_over, device.bounds() or { Rect{} }, legacy) or { return true }
	if mut blitter is SolidBlitter {
		blitter.first_row = first_row
	} else if mut blitter is PipelineBlitter {
		blitter.first_row = first_row
	} else {
		return false
	}
	return anti_fill_path(device, IRect{0, first_row, width, first_row + height}, mut blitter)
}

// restore_canvas_opacity_layer composites a premultiplied row band into a
// target of the same width. Native N32 uses the legacy sprite blend.
pub fn restore_canvas_opacity_layer(mut pixels []u8, pitch int, target_height int, first_row int, image CanvasBitmap, opacity f32) bool {
	if !untiled_device(pixels, image.width, target_height, pitch) || first_row < 0
		|| first_row >= target_height || image.height > target_height - first_row {
		return false
	}
	mut target := if first_row == 0 { pixels } else { pixels[first_row * pitch..] }
	if !canvas_rgba_uses_legacy() && restore_lowp_canvas_layer(mut target, pitch, image, opacity) {
		return true
	}
	rect := [f32(0), 0, f32(image.width), f32(image.height)]!
	return draw_canvas_image(mut target, image.width, target_height - first_row, pitch, 2,
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
	alpha := u32(canvas_image_opacity_byte(opacity))
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
