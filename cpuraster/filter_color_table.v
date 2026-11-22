module cpuraster

import math

struct CanvasColorTableScan {
	pixels         []u8
	row_bytes      int
	tables         [4][256]u8
	opaque_indices [256]u8
	encoded        [256]f64
	linear_rgb     bool
}

// The retained SVG tables map straight channel values. A missing table
// supplies the identity lookup, and the result is premultiplied once.
pub fn apply_canvas_color_table_in_place(mut pixels []u8, width int, height int,
	channels [4][]u8, linear_rgb bool) bool {
	if !untiled_device(pixels, width, height, width * 4) { return false }
	mut tables := [4][256]u8{}
	for channel, values in channels {
		if values.len != 0 && values.len != 256 { return false }
		for index in 0 .. 256 {
			tables[channel][index] = if values.len == 0 { u8(index) } else { values[index] }
		}
	}
	mut opaque_indices := [256]u8{}
	mut encoded := [256]f64{}
	for index in 0 .. 256 {
		if linear_rgb {
			value := f64(index) / 255
			opaque_indices[index] = u8(math.round(general_decode_srgb(value) * 255))
			encoded[index] = general_encode_srgb(value)
		} else {
			opaque_indices[index] = u8(index)
		}
	}
	scan := CanvasColorTableScan{pixels, width * 4, tables, opaque_indices, encoded, linear_rgb}
	run_raster_scans(&scan, height, width, scan_canvas_color_table)
	return true
}

fn scan_canvas_color_table(context voidptr, first i32, end i32) {
	scan := unsafe { &CanvasColorTableScan(context) }
	mut pixels := unsafe { scan.pixels }
	start := int(first) * scan.row_bytes
	stop := int(end) * scan.row_bytes
	for offset := start; offset < stop; offset += 4 {
		alpha := u32(pixels[offset + 3])
		mapped_alpha := scan.tables[3][alpha]
		if mapped_alpha == 0 {
			for k in 0 .. 4 {
				pixels[offset + k] = 0
			}
			continue
		}
		for k in 0 .. 3 {
			channel := pixels[offset + k]
			index := if alpha == 255 {
				int(scan.opaque_indices[channel])
			} else if alpha == 0 {
				0
			} else if scan.linear_rgb {
				// Decode the straight sRGB value before rounding to a table index.
				value := math.min(1.0, f64(channel) / f64(alpha))
				int(math.round(general_decode_srgb(value) * 255))
			} else {
				filter_transfer_index(channel, alpha)
			}
			mapped := scan.tables[k][index]
			pixels[offset + k] = if scan.linear_rgb {
				general_byte(f32(scan.encoded[mapped] * f64(mapped_alpha)))
			} else {
				u8((u32(mapped) * u32(mapped_alpha) + 127) / 255)
			}
		}
		pixels[offset + 3] = mapped_alpha
	}
}
