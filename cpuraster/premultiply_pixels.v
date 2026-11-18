module cpuraster

// premultiply_rgba_copy returns a packed premultiplied copy of straight-alpha RGBA.
pub fn premultiply_rgba_copy(source []u8, width int, height int) ?[]u8 {
	if width <= 0 || height <= 0 || height > max_i32 || source.len % 4 != 0
		|| width > source.len / 4 / height || width * height != source.len / 4 {
		return none
	}
	output := []u8{len: source.len}
	scan := PremultiplyScan{
		source: source.data
		output: output.data
		width:  width
	}
	run_raster_scans(&scan, height, width, scan_premultiply_rgba_rows)
	return output
}

struct PremultiplyScan {
	source &u8
	output &u8
	width  int
}

fn scan_premultiply_rgba_rows(context voidptr, first i32, end i32) {
	scan := unsafe { &PremultiplyScan(context) }
	output := scan.output
	unsafe {
		for offset := int(first) * scan.width * 4; offset < int(end) * scan.width * 4; offset += 4 {
			alpha := u32(scan.source[offset + 3])
			for channel in 0 .. 3 {
				output[offset + channel] = u8((u32(scan.source[offset + channel]) * alpha + 127) / 255)
			}
			output[offset + 3] = u8(alpha)
		}
	}
}
