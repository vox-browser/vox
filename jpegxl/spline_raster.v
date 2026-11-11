// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn spline_round_u64(value f32) u64 {
	if !(value > 0) { return 0 }
	if value >= f32(18446744073709551616.0) { return u64(0xffffffffffffffff) }
	return u64(math.round(f64(value)))
}

// Draw three disjoint color rows with the verified fused source profile.
// Extra channels are outside this operation. Row coordinates refer to the
// cached frame before image upsampling and color conversion.
pub fn (cache SplineDrawCache) draw_row(mut row [][]f32, row_x int, row_y int) ! {
	if !cache.is_initialized() || cache.width <= 0 || cache.height <= 0
		|| row_x < 0 || row_y < 0 || row_y >= cache.height || row.len != 3
		|| cache.row_starts.len != cache.height + 1 {
		return error('Invalid JPEG XL spline raster context')
	}
	width := row[0].len
	if row_x > cache.width || width > cache.width - row_x {
		return error('JPEG XL spline row exceeds the cached frame')
	}
	for samples in row {
		if samples.len != width { return error('Invalid JPEG XL spline color row shape') }
		for sample in samples {
			if !math.is_finite(sample) { return error('JPEG XL spline background must be finite') }
		}
	}
	first := cache.row_starts[row_y]
	last := cache.row_starts[row_y + 1]
	if first < 0 || last < first || last > cache.row_indices.len {
		return error('Invalid JPEG XL spline row membership')
	}
	for position in first .. last {
		id := cache.row_indices[position]
		if id < 0 || id >= cache.segments.len {
			return error('Invalid JPEG XL spline segment index')
		}
		segment := cache.segments[id]
		if !math.is_finite(segment.center_x) || !math.is_finite(segment.center_y)
			|| !math.is_finite(segment.inv_sigma) || !math.is_finite(segment.sigma_over_4_times_intensity) {
			return error('Invalid JPEG XL spline segment values')
		}
		for color in segment.color {
			if !math.is_finite(color) { return error('JPEG XL spline colors must be finite') }
		}
	}
	for position in first .. last {
		segment := cache.segments[cache.row_indices[position]]
		left := spline_round_u64(segment.center_x - segment.maximum_distance)
		right := spline_round_u64(segment.center_x + segment.maximum_distance) + 1
		start := if left > u64(row_x) { left } else { u64(row_x) }
		end := if right < u64(row_x + width) { right } else { u64(row_x + width) }
		if end <= start { continue }
		dy := f32(row_y) - segment.center_y
		dy_squared := dy * dy
		for x in int(start) .. int(end) {
			dx := f32(x) - segment.center_x
			distance := math.sqrtf(fused_f32(dx, dx, dy_squared))
			upper := fused_f32(distance, f32(0.5), f32(0.35355338))
			lower := fused_f32(distance, f32(0.5), f32(-0.35355338))
			factor := spline_fast_erf(upper * segment.inv_sigma, true) - spline_fast_erf(lower * segment.inv_sigma, true)
			weighted := segment.sigma_over_4_times_intensity * factor
			intensity := weighted * factor
			for c in 0 .. 3 {
				row[c][x - row_x] = fused_f32(segment.color[c], intensity, row[c][x - row_x])
			}
		}
	}
}
