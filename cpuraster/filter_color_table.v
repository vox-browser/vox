module cpuraster

import math

struct CanvasColorTableScan {
	pixels         []u8
	row_bytes      int
	tables         [4][256]u8
	reset_rgb      [][4]u8
	opaque_indices [256]u8
	encoded        [256]f64
	linear_rgb     bool
}

// Fuse tables in the same color space before scanning the pixels. Each
// intermediate nonzero-alpha output unpremultiplies to the same table bytes.
pub fn apply_canvas_color_tables_in_place(mut pixels []u8, width int, height int,
	stages [][4][]u8, linear_rgb bool) bool {
	if stages.len == 0 || !untiled_device(pixels, width, height, width * 4) { return false }
	mut tables := [4][256]u8{}
	for channel, values in stages[0] {
		if values.len != 0 && values.len != 256 { return false }
		for value in 0 .. 256 {
			tables[channel][value] = if values.len == 0 { u8(value) } else { values[value] }
		}
	}
	mut reset_rgb := [][4]u8{len: if stages.len > 1 { 256 } else { 0 }}
	for stage in 1 .. stages.len {
		channels := stages[stage]
		if !channels.all(it.len == 0 || it.len == 256) { return false }
		// Once alpha reaches zero the intermediate pixel is transparent
		// black. Track the RGB that later stages build from that zero.
		for alpha in 0 .. 256 {
			if tables[3][alpha] == 0 {
				reset_rgb[alpha] = [u8(0), 0, 0, 1]!
			}
			if reset_rgb[alpha][3] != 0 {
				for k in 0 .. 3 {
					if channels[k].len > 0 {
						reset_rgb[alpha][k] = channels[k][reset_rgb[alpha][k]]
					}
				}
			}
		}
		for channel, values in channels {
			if values.len == 0 { continue }
			for index in 0 .. 256 {
				tables[channel][index] = values[tables[channel][index]]
			}
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
	scan := CanvasColorTableScan{pixels, width * 4, tables, reset_rgb, opaque_indices, encoded, linear_rgb}
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
		mut rgb := [3]u8{}
		if scan.reset_rgb.len != 0 && scan.reset_rgb[alpha][3] != 0 {
			for k in 0 .. 3 {
				rgb[k] = scan.reset_rgb[alpha][k]
			}
		} else {
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
				rgb[k] = scan.tables[k][index]
			}
		}
		for k, mapped in rgb {
			pixels[offset + k] = if scan.linear_rgb {
				general_byte(f32(scan.encoded[mapped] * f64(mapped_alpha)))
			} else {
				u8((u32(mapped) * u32(mapped_alpha) + 127) / 255)
			}
		}
		pixels[offset + 3] = mapped_alpha
	}
}
