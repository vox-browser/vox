// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

pub struct SplineSegment {
pub:
	center_x                     f32
	center_y                     f32
	maximum_distance             f32
	inv_sigma                    f32
	sigma_over_4_times_intensity f32
	color                        [3]f32
}

pub struct SplineDrawCache {
pub:
	width       int
	height      int
	segments    []SplineSegment
	row_starts  []int
	row_indices []int
}

pub fn (cache SplineDrawCache) is_initialized() bool {
	return cache.row_starts.len != 0
}

fn spline_round_i64(value f32) i64 {
	if math.is_nan(value) { return 0 }
	if value >= f32(9223372036854775808.0) { return i64(9223372036854775807) }
	if value <= f32(-9223372036854775808.0) { return i64(-9223372036854775807 - 1) }
	return i64(math.round(f64(value)))
}

fn spline_segment_rows(segment SplineSegment, height int) (int, int) {
	first := spline_round_i64(segment.center_y - segment.maximum_distance)
	last := spline_round_i64(segment.center_y + segment.maximum_distance)
	end := if last == i64(9223372036854775807) { i64(-9223372036854775807 - 1) } else { last + 1 }
	start_y := if first < 0 {
		0
	} else if first > height {
		height
	} else {
		int(first)
	}
	end_y := if end < 0 {
		0
	} else if end > height {
		height
	} else {
		int(end)
	}
	return start_y, end_y
}

fn spline_continuous_idct(coefficients [32]f32, cosines [32]f32) f32 {
	mut sum := math.f32_from_bits(0x80000000)
	for i in 0 .. 32 {
		product := coefficients[i] * cosines[i]
		sum += product
	}
	return sum * math.f32_from_bits(0x3fb504f3)
}

fn add_cached_spline_segment(mut segments []SplineSegment, point SpacedSplinePoint, color [3]f32, sigma f32, high_precision bool) ! {
	inv_sigma := f32(1) / sigma
	if sigma == 0 || math.is_inf(sigma, 0) || math.is_inf(inv_sigma, 0) || math.is_inf(point.intensity, 0) {
		return
	}
	if segments.len >= 1048576 { return error('JPEG XL spline segments exceed the cache budget') }
	exponent := if high_precision { f32(5) } else { f32(3) }
	mut maximum_color := math.abs(f32(0.01) * point.intensity)
	for value in color {
		weighted := math.abs(value * point.intensity)
		if weighted > maximum_color { maximum_color = weighted }
	}
	scale := f32(-2) * sigma
	squared := scale * sigma
	threshold := math.logf(f32(0.1)) * exponent
	logarithm := threshold - math.logf(maximum_color)
	distance := math.sqrtf(squared * logarithm)
	quarter_sigma := f32(0.25) * sigma
	segments << SplineSegment{
		center_x:                     point.point.x
		center_y:                     point.point.y
		maximum_distance:             distance
		inv_sigma:                    inv_sigma
		sigma_over_4_times_intensity: quarter_sigma * point.intensity
		color:                        color
	}
}

pub fn (set Splines) create_draw_cache(width int, height int, correlation ColorCorrelationParams, high_precision bool, force_level5 bool) !SplineDrawCache {
	if width <= 0 || height <= 0 || set.splines.len != set.starting_points.len || set.splines.len > 1048576
		|| correlation.color_factor == 0 {
		return error('Invalid JPEG XL spline draw-cache context')
	}
	area := u64(modular_sample_count(width, height)!)
	raw_limit := if force_level5 { 8 * area + (u64(1) << 25) } else { 1024 * area + (u64(1) << 32) }
	maximum := if force_level5 { u64(1) << 30 } else { u64(1) << 42 }
	area_limit := if raw_limit < maximum { raw_limit } else { maximum }
	mut total := u64(0)
	mut splines := []Spline{cap: set.splines.len}
	for i, quantized in set.splines {
		spline := quantized.dequantize(set.starting_points[i], set.quantization_adjustment,
			correlation.y_to_x_lf(), correlation.y_to_b_lf(), area_limit)!
		if spline.estimated_area_reached > area_limit - total {
			return error('JPEG XL splines exceed the total area limit')
		}
		total += spline.estimated_area_reached
		spline.validate_adjacent_points()!
		splines << spline
	}
	mut segments := []SplineSegment{}
	pi_over_32 := math.f32_from_bits(0x40490fdb) / f32(32)
	for spline in splines {
		intermediate := spline_curve_points(spline.control_points)!
		spaced := equally_spaced_spline_points(intermediate)!
		if spaced.len == 0 { continue }
		length := f32(spaced.len - 2) * f32(1) + spaced.last().intensity
		if length <= 0 { continue }
		inv_length := f32(1) / length
		for index, point in spaced {
			position := f32(index) * f32(1)
			fraction := position * inv_length
			progress := if fraction < 1 { fraction } else { f32(1) }
			t := f32(31) * progress
			half := t + f32(0.5)
			mut cosines := [32]f32{}
			for i in 0 .. 32 {
				multiplier := pi_over_32 * f32(i)
				cosines[i] = spline_fast_cos(multiplier * half)
			}
			mut color := [3]f32{}
			for c in 0 .. 3 { color[c] = spline_continuous_idct(spline.color_dct[c], cosines) }
			sigma := spline_continuous_idct(spline.sigma_dct, cosines)
			add_cached_spline_segment(mut segments, point, color, sigma, high_precision)!
		}
	}
	// Only in-bounds row membership is needed. Stable segment order gives the
	// same observable prefix as the source's sorted vector, without its unused
	// offscreen tail or a potentially huge per-segment offscreen expansion.
	mut starts := []int{len: height + 1}
	mut entries := 0
	for segment in segments {
		start, end := spline_segment_rows(segment, height)
		if end <= start { continue }
		if end - start > 16777216 - entries {
			return error('JPEG XL spline row indices exceed the cache budget')
		}
		entries += end - start
		for y in start .. end { starts[y + 1]++ }
	}
	for y in 0 .. height { starts[y + 1] += starts[y] }
	mut indices := []int{len: entries}
	mut cursor := starts[..height].clone()
	for id, segment in segments {
		start, end := spline_segment_rows(segment, height)
		for y in start .. end {
			indices[cursor[y]] = id
			cursor[y]++
		}
	}
	return SplineDrawCache{
		width:       width
		height:      height
		segments:    segments
		row_starts:  starts
		row_indices: indices
	}
}
