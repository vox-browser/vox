module cpuraster

import math

// SkImageFilters::Offset: whole-pixel translations copy; fractional ones
// sample bilinearly, as the deferred transform does.
fn general_offset(image BlurImage, dx f32, dy f32) BlurImage {
	w, h := image.width, image.height
	if !is_finite_f32(dx) || !is_finite_f32(dy) || math.abs(dx) >= f32(w) || math.abs(dy) >= f32(h) {
		return BlurImage{[]u8{len: image.pixels.len}, w, h}
	}
	if dx == f32(math.round(dx)) && dy == f32(math.round(dy)) {
		return general_place(image, int(dx), int(dy), w, h)
	}
	output := []u8{len: image.pixels.len}
	scan := FilterOffsetScan{
		source:    image.pixels
		output:    output
		columns:   []FilterOffsetSample{len: w, init: filter_offset_sample(index, dx, w, 4)}
		row_bytes: w * 4
		height:    h
		dy:        dy
	}
	run_raster_scans(&scan, h, w, scan_filter_offset)
	return BlurImage{output, w, h}
}

struct FilterOffsetSample {
	near     int
	far      int
	fraction f32
}

// Record byte offsets once per axis. An offset of -1 denotes transparent
// black outside the layer.
fn filter_offset_sample(position int, delta f32, extent int, stride int) FilterOffsetSample {
	coordinate := f32(position) - delta
	near := int(math.floor(coordinate))
	far := near + 1
	return FilterOffsetSample{
		near:     if near >= 0 && near < extent { near * stride } else { -1 }
		far:      if far >= 0 && far < extent { far * stride } else { -1 }
		fraction: coordinate - f32(near)
	}
}

struct FilterOffsetScan {
	source    []u8
	output    []u8
	columns   []FilterOffsetSample
	row_bytes int
	height    int
	dy        f32
}

fn scan_filter_offset(context voidptr, first i32, end i32) {
	scan := unsafe { &FilterOffsetScan(context) }
	mut output := unsafe { scan.output }
	for y in int(first) .. int(end) {
		row := filter_offset_sample(y, scan.dy, scan.height, scan.row_bytes)
		out_row := y * scan.row_bytes
		for x, column in scan.columns {
			top_left := filter_offset_index(row.near, column.near)
			top_right := filter_offset_index(row.near, column.far)
			bottom_left := filter_offset_index(row.far, column.near)
			bottom_right := filter_offset_index(row.far, column.far)
			for c in 0 .. 4 {
				p00 := filter_offset_channel(scan.source, top_left, c)
				p10 := filter_offset_channel(scan.source, top_right, c)
				p01 := filter_offset_channel(scan.source, bottom_left, c)
				p11 := filter_offset_channel(scan.source, bottom_right, c)
				top_step := (p10 - p00) * column.fraction
				bottom_step := (p11 - p01) * column.fraction
				top := p00 + top_step
				bottom := p01 + bottom_step
				vertical := (bottom - top) * row.fraction
				output[out_row + x * 4 + c] = general_byte(top + vertical)
			}
		}
	}
}

@[inline]
fn filter_offset_index(row int, column int) int {
	return if row >= 0 && column >= 0 { row + column } else { -1 }
}

@[inline]
fn filter_offset_channel(pixels []u8, index int, channel int) f32 {
	return if index >= 0 { f32(pixels[index + channel]) } else { f32(0) }
}
