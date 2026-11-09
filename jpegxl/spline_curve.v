// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

fn (point SplinePoint) plus(other SplinePoint) SplinePoint {
	return SplinePoint{ x: point.x + other.x, y: point.y + other.y }
}

fn (point SplinePoint) minus(other SplinePoint) SplinePoint {
	return SplinePoint{ x: point.x - other.x, y: point.y - other.y }
}

fn (point SplinePoint) times(value f32) SplinePoint {
	return SplinePoint{ x: point.x * value, y: point.y * value }
}

fn (point SplinePoint) length() f32 {
	return f32(math.hypot(f64(point.x), f64(point.y)))
}

fn spline_curve_points(points []SplinePoint) ![]SplinePoint {
	if points.len == 0 { return []SplinePoint{} }
	if points.len == 1 { return [points[0]] }
	if points.len > 65536 { return error('JPEG XL spline subdivision exceeds the point budget') }
	mut extended := []SplinePoint{cap: points.len + 2}
	first_difference := points[0].minus(points[1])
	extended << points[0].plus(first_difference)
	extended << points
	last_difference := points.last().minus(points[points.len - 2])
	extended << points.last().plus(last_difference)
	mut result := []SplinePoint{cap: (points.len - 1) * 16 + 1}
	for window in 0 .. points.len - 1 {
		mut p := [4]SplinePoint{}
		for k in 0 .. 4 { p[k] = extended[window + k] }
		mut d := [3]f32{}
		mut t := [4]f32{}
		for k in 0 .. 3 {
			difference := p[k + 1].minus(p[k])
			d[k] = math.sqrtf(difference.length())
			t[k + 1] = t[k] + d[k]
		}
		result << p[1]
		for i in 1 .. 16 {
			fraction := f32(i) / f32(16)
			portion := fraction * d[1]
			tt := d[0] + portion
			mut a := [3]SplinePoint{}
			for k in 0 .. 3 {
				difference := p[k + 1].minus(p[k])
				scaled := difference.times((tt - t[k]) / d[k])
				a[k] = p[k].plus(scaled)
			}
			mut b := [2]SplinePoint{}
			for k in 0 .. 2 {
				difference := a[k + 1].minus(a[k])
				scaled := difference.times((tt - t[k]) / (d[k] + d[k + 1]))
				b[k] = a[k].plus(scaled)
			}
			difference := b[1].minus(b[0])
			scaled := difference.times((tt - t[1]) / d[1])
			result << b[0].plus(scaled)
		}
	}
	result << points.last()
	return result
}

struct SpacedSplinePoint {
	point     SplinePoint
	intensity f32
}

fn append_spaced_spline_point(mut points []SpacedSplinePoint, point SplinePoint, intensity f32) ! {
	if points.len >= 1048576 {
		return error('JPEG XL equally spaced spline points exceed the budget')
	}
	points << SpacedSplinePoint{ point: point, intensity: intensity }
}

fn equally_spaced_spline_points(points []SplinePoint) ![]SpacedSplinePoint {
	mut result := []SpacedSplinePoint{}
	if points.len == 0 { return result }
	append_spaced_spline_point(mut result, points[0], 1)!
	if points.len == 1 { return result }
	mut accumulated := f32(0)
	for index in 0 .. points.len - 1 {
		mut current := points[index]
		next := points[index + 1]
		segment := next.minus(current)
		length := segment.length()
		// The source forms an unused NaN direction for zero-length edges.
		// Its distance and publication state stay unchanged on those edges.
		if length == 0 { continue }
		unit := segment.times(f32(1) / length)
		if accumulated + length >= 1 {
			step := unit.times(f32(1) - accumulated)
			current = current.plus(step)
			append_spaced_spline_point(mut result, current, 1)!
			accumulated -= 1
		}
		accumulated += length
		for accumulated >= 1 {
			step := unit.times(1)
			current = current.plus(step)
			append_spaced_spline_point(mut result, current, 1)!
			accumulated -= 1
		}
	}
	append_spaced_spline_point(mut result, points.last(), accumulated)!
	return result
}
