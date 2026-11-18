module cpuraster

// premultiply_rgba_copy returns a packed premultiplied copy of straight-alpha RGBA.
pub fn premultiply_rgba_copy(source []u8, width int, height int) ?[]u8 {
	if width <= 0 || height <= 0 || height > max_i32 || source.len % 4 != 0
		|| width > source.len / 4 / height || width * height != source.len / 4 {
		return none
	}
	output := []u8{len: source.len}
	row_bytes := width * 4
	scan := PremultiplyScan{
		source:    source.data
		output:    output.data
		row_bytes: row_bytes
		pitch:     row_bytes
	}
	run_raster_scans(&scan, height, width, scan_premultiply_rgba_rows)
	return output
}

fn premultiply_rows(mut pixels []u8, width int, height int, pitch int) {
	if width <= 0 || width > pixels.len / 4 || height <= 0 || height > max_i32 {
		return
	}
	row_bytes := width * 4
	if pitch < row_bytes || height - 1 > (pixels.len - row_bytes) / pitch {
		return
	}
	scan := PremultiplyScan{
		source:    pixels.data
		output:    pixels.data
		row_bytes: row_bytes
		pitch:     pitch
	}
	run_raster_scans(&scan, height, width, scan_premultiply_rgba_rows)
}

struct PremultiplyScan {
	source    &u8
	output    &u8
	row_bytes int
	pitch     int
}

fn scan_premultiply_rgba_rows(context voidptr, first i32, end i32) {
	scan := unsafe { &PremultiplyScan(context) }
	if scan.pitch == scan.row_bytes {
		scan.premultiply_span(int(first) * scan.pitch, int(end) * scan.pitch)
		return
	}
	for row in int(first) .. int(end) {
		start := row * scan.pitch
		scan.premultiply_span(start, start + scan.row_bytes)
	}
}

// SkConvertPixels' RGBA_to_rgbA() rounds each color channel to the nearest byte.
// Source and output may be the same buffer. Workers own complete, disjoint rows.
@[inline]
fn (scan &PremultiplyScan) premultiply_span(start int, end int) {
	source := scan.source
	output := scan.output
	unsafe {
		for offset := start; offset < end; offset += 4 {
			alpha := u32(source[offset + 3])
			for channel in 0 .. 3 {
				output[offset + channel] = u8((u32(source[offset + channel]) * alpha + 127) / 255)
			}
			output[offset + 3] = u8(alpha)
		}
	}
}
