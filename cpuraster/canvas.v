module cpuraster

// Canvas2D path fills, as skia/canvas_raster.cpp's vox_skia_canvas_path()
// draws them with LibWeb Skia for a solid source-over fill without clips,
// filters, shadows or global alpha: writePixels() premultiplies the bitmap,
// SkCanvas::drawPath() fills the path anti-aliased, and readPixels() returns
// the premultiplied surface.

// Segments use skia.Path's encoding: 12 floats per segment, kind (0 move,
// 1 line, 2 quad, 3 cubic, 4 SVG arc, 5 close), point, two control points,
// radii, x-axis rotation, large-arc and sweep flags. Returns none for arcs,
// which are not ported yet.
pub fn canvas_path(segments []f32, even_odd bool) ?Path {
	mut b := PathBuilder{}
	for i := 0; i + 11 < segments.len; i += 12 {
		s := segments[i..i + 12]
		match int(s[0]) {
			0 { b.move_to(s[1], s[2]) }
			1 { b.line_to(s[1], s[2]) }
			2 { b.quad_to(s[3], s[4], s[1], s[2]) }
			3 { b.cubic_to(s[3], s[4], s[5], s[6], s[1], s[2]) }
			4 { return none }
			5 { b.close() }
			else {}
		}
	}
	b.fill_type = if even_odd { .even_odd } else { .winding }
	return b.detach()
}

// SkDrawTiler splits devices wider or taller than this into translated tiles.
const max_untiled_dimension = 8191

// fill_canvas_path fills path with color (an SkColor, 0xAARRGGBB) through
// transform ([a b c d e f]) into width x height RGBA_8888 pixels, which are
// premultiplied when alpha_type is 2 and premultiplied first otherwise.
// Returns false without changing pixels for devices Skia would tile.
pub fn fill_canvas_path(mut pixels []u8, width int, height int, pitch int, alpha_type int, path Path, transform [6]f32, color u32) bool {
	if path.is_inverse_fill() || width <= 0 || height <= 0 || width > max_untiled_dimension
		|| height > max_untiled_dimension || pitch < width * 4 || pitch % 4 != 0
		|| i64(pitch) * i64(height - 1) + i64(width) * 4 > i64(pixels.len) {
		return false
	}
	if alpha_type != 2 {
		premultiply_rows(mut pixels, width, height, pitch)
	}
	matrix := Matrix{transform[0], transform[1], transform[2], transform[3], transform[4], transform[5]}
	mut blitter := new_solid_blitter(mut pixels, pitch, color)
	return anti_fill_path(path.transform(matrix), IRect{0, 0, width, height}, mut blitter)
}

// SkConvertPixels' RGBA_to_rgbA(): (c * a + 127) / 255.
fn premultiply_rows(mut pixels []u8, width int, height int, pitch int) {
	for y in 0 .. height {
		row := y * pitch
		for x in 0 .. width {
			o := row + x * 4
			a := u32(pixels[o + 3])
			for c in 0 .. 3 {
				pixels[o + c] = u8((u32(pixels[o + c]) * a + 127) / 255)
			}
		}
	}
}
