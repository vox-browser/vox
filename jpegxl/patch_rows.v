// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct PatchFrameReference {
pub:
	info   PatchReferenceInfo
	planes []FloatPlane
}

struct PatchRowSpan {
	position int
	source   int
	x        int
	y        int
	output   int
	width    int
}

// Apply the active patches in bitstream order, clipping both ends to this row
// chunk. Reference rows and destination channels must have disjoint storage.
// The dictionary comes from read_patches; stored frame geometry is rechecked
// against the actual planes before any destination samples are changed.
pub fn (patches PatchesDictionary) apply_row(mut row [][]f32, row_x int, row_y int, extra []ExtraChannelInfo, references []PatchFrameReference) ! {
	if row_x < 0 || row_y < 0 || row_x > 1048576 || row.len != 3 + extra.len
		|| extra.len + 1 != patches.blendings_stride || extra.len > 256 {
		return error('Invalid JPEG XL patch row context')
	}
	width := row[0].len
	if width > 1048576 - row_x || u64(width) * u64(row.len) > 67108864 {
		return error('JPEG XL patch row exceeds the sample budget')
	}
	for samples in row {
		if samples.len != width { return error('Invalid JPEG XL patch destination row') }
	}
	mut checked := [4]bool{}
	mut spans := []PatchRowSpan{}
	for id in patches.patches_for_row(row_y) {
		position := patches.positions[id]
		ref := patches.references[position.reference]
		left := if position.x > row_x { position.x } else { row_x }
		right := if position.x + ref.width < row_x + width {
			position.x + ref.width
		} else {
			row_x + width
		}
		if left >= right { continue }
		if ref.reference >= references.len || !references[ref.reference].info.available {
			return error('Missing JPEG XL patch frame planes')
		}
		source := references[ref.reference]
		if !checked[ref.reference] {
			if !source.info.saved_before_color_transform || source.info.width <= 0 || source.info.height <= 0
				|| source.planes.len != row.len {
				return error('Invalid JPEG XL patch frame context')
			}
			count := modular_sample_count(source.info.width, source.info.height)!
			if u64(count) * u64(source.planes.len) > 67108864 {
				return error('JPEG XL patch frame exceeds the sample budget')
			}
			for plane in source.planes {
				plane.validate()!
				if plane.width != source.info.width || plane.height != source.info.height {
					return error('JPEG XL patch frame planes disagree')
				}
			}
			checked[ref.reference] = true
		}
		x := ref.x0 + left - position.x
		y := ref.y0 + row_y - position.y
		if x < 0 || y < 0 || y >= source.info.height || right - left > source.info.width
			|| x > source.info.width - (right - left) {
			return error('JPEG XL patch row exceeds its reference planes')
		}
		spans << PatchRowSpan{
			position: id
			source:   ref.reference
			x:        x
			y:        y
			output:   left - row_x
			width:    right - left
		}
	}
	for span in spans {
		mut background := [][]f32{cap: row.len}
		mut foreground := [][]f32{cap: row.len}
		for c in 0 .. row.len {
			background << row[c][span.output..span.output + span.width]
			plane := references[span.source].planes[c]
			start := span.y * plane.width + span.x
			foreground << plane.samples[start..start + span.width]
		}
		blending := span.position * patches.blendings_stride
		blend_patch_rows(mut background, foreground, patches.blendings[blending],
			patches.blendings[blending + 1..blending + patches.blendings_stride], extra)!
	}
}
