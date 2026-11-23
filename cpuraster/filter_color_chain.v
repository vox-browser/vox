module cpuraster

import math

pub struct CanvasColorStage {
pub:
	matrix   [20]f32
	channels [4][]u8
	is_table bool
}

struct CanvasColorChainScan {
	pixels        []u8
	row_bytes     int
	stages        []CanvasColorStage
	transparent   [4]u8
	opaque_linear [256]f32
	linear_rgb    bool
}

// A mixed SVG chain shares the layer scan and the color-space conversions.
// Its table stages quantize lookup indices and its final store premultiplies.
pub fn apply_canvas_color_chain_in_place(mut pixels []u8, width int, height int,
	stages []CanvasColorStage, linear_rgb bool) bool {
	if stages.len == 0 || !untiled_device(pixels, width, height, width * 4) { return false }
	for stage in stages {
		if stage.is_table {
			if !stage.channels.all(it.len == 0 || it.len == 256) { return false }
		} else if !stage.matrix.all(is_finite_f32(it)) {
			return false
		}
	}
	mut opaque_linear := [256]f32{}
	if linear_rgb {
		for i in 0 .. 256 {
			opaque_linear[i] = f32(general_decode_srgb(f64(i) / 255))
		}
	}
	scan := CanvasColorChainScan{
		pixels: pixels
		row_bytes: width * 4
		stages: stages
		transparent: canvas_color_chain_pixel([f32(0), 0, 0, 0]!, stages, linear_rgb)
		opaque_linear: opaque_linear
		linear_rgb: linear_rgb
	}
	run_raster_scans(&scan, height, width, scan_canvas_color_chain)
	return true
}

fn canvas_color_chain_pixel(input [4]f32, stages []CanvasColorStage, linear_rgb bool) [4]u8 {
	mut straight := input
	for index in 0 .. stages.len {
		stage := &stages[index]
		if stage.is_table {
			for k, table in stage.channels {
				if table.len != 0 {
					straight[k] = f32(table[general_byte(straight[k] * 255)]) * inv_255
				}
			}
		} else {
			straight = apply_straight_color_matrix(&stage.matrix, straight[0], straight[1],
				straight[2], straight[3], true)
		}
		if straight[3] == 0 {
			straight = [f32(0), 0, 0, 0]!
		}
	}
	alpha := straight[3] * 255
	mut pixel := [u8(0), 0, 0, general_byte(alpha)]!
	for k in 0 .. 3 {
		encoded := if linear_rgb {
			f32(general_encode_srgb(f64(straight[k])))
		} else {
			straight[k]
		}
		pixel[k] = math.min(pixel[3], general_byte(encoded * alpha))
	}
	return pixel
}

fn scan_canvas_color_chain(context voidptr, first i32, end i32) {
	scan := unsafe { &CanvasColorChainScan(context) }
	mut pixels := unsafe { scan.pixels }
	start := int(first) * scan.row_bytes
	stop := int(end) * scan.row_bytes
	for offset := start; offset < stop; offset += 4 {
		alpha := pixels[offset + 3]
		mut pixel := scan.transparent
		if alpha != 0 {
			mut straight := [f32(0), 0, 0, f32(alpha) * inv_255]!
			for k in 0 .. 3 {
				channel := pixels[offset + k]
				if scan.linear_rgb && alpha == 255 {
					straight[k] = scan.opaque_linear[channel]
				} else {
					value := math.min(1.0, f64(channel) / f64(alpha))
					straight[k] = f32(if scan.linear_rgb { general_decode_srgb(value) } else { value })
				}
			}
			pixel = canvas_color_chain_pixel(straight, scan.stages, scan.linear_rgb)
		}
		for k in 0 .. 4 {
			pixels[offset + k] = pixel[k]
		}
	}
}
