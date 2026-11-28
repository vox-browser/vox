module cpuraster

// unpremultiply_canvas_rgba returns straight RGBA for the portable GPU upload.
// Keep its integer rounding separate from Skia's readPixels conversion.
pub fn unpremultiply_canvas_rgba(pixels []u8) []u8 {
	if pixels.len % 4 != 0 {
		return []u8{}
	}
	output := []u8{len: pixels.len}
	scan := CanvasUploadScan{
		source: pixels.data
		output: output.data
	}
	tail := run_packed_rgba_scans(&scan, pixels.len, scan_canvas_upload_rows)
	scan.convert(tail, pixels.len)
	return output
}

struct CanvasUploadScan {
	source &u8
	output &u8
}

fn scan_canvas_upload_rows(context voidptr, first i32, end i32) {
	scan := unsafe { &CanvasUploadScan(context) }
	scan.convert(int(first) * packed_rgba_scan_bytes, int(end) * packed_rgba_scan_bytes)
}

const canvas_upload_reciprocal_bits = 24
const canvas_upload_reciprocals = build_canvas_upload_reciprocals()

fn build_canvas_upload_reciprocals() [256]u32 {
	mut reciprocals := [256]u32{}
	for alpha in 1 .. reciprocals.len {
		reciprocals[alpha] = ((u32(1) << canvas_upload_reciprocal_bits) + u32(alpha) - 1) / u32(alpha)
	}
	return reciprocals
}

fn (scan &CanvasUploadScan) convert(first int, end int) {
	source := scan.source
	output := scan.output
	unsafe {
		for offset := first; offset < end; offset += 4 {
			alpha := u32(source[offset + 3])
			if alpha == 0 {
				// The destination was initialized to transparent black.
				continue
			}
			output[offset + 3] = u8(alpha)
			if alpha == 255 {
				for channel in 0 .. 3 {
					output[offset + channel] = source[offset + channel]
				}
				continue
			}
			reciprocal := canvas_upload_reciprocals[alpha]
			for channel in 0 .. 3 {
				numerator := u32(source[offset + channel]) * 255 + alpha / 2
				// The rounded-up reciprocal adds less than 1/256 to the
				// quotient, since numerator < 65536. Fractional steps are
				// at least 1/255, so the shift gives exact integer division.
				value := u32(u64(numerator) * reciprocal >> canvas_upload_reciprocal_bits)
				output[offset + channel] = u8(if value > 255 { 255 } else { value })
			}
		}
	}
}
