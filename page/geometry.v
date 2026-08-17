// Copyright (c) 2026, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibWeb's Page-facing PixelUnits and geometry operations.
module page

import math

pub struct PixelPoint {
pub:
	x f64
	y f64
}

pub struct PixelSize {
pub:
	width  f64
	height f64
}

pub struct PixelRect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub fn (rect PixelRect) right() f64 {
	return rect.x + rect.width
}

pub fn (rect PixelRect) bottom() f64 {
	return rect.y + rect.height
}

pub fn (rect PixelRect) contains(point PixelPoint) bool {
	return point.x >= rect.x && point.x <= rect.right() && point.y >= rect.y
		&& point.y <= rect.bottom()
}

pub fn (rect PixelRect) shrunken(top f64, right f64, bottom f64, left f64) PixelRect {
	return PixelRect{
		x:      rect.x + left
		y:      rect.y + top
		width:  math.max(0.0, rect.width - left - right)
		height: math.max(0.0, rect.height - top - bottom)
	}
}

pub fn constrain_point(point PixelPoint, rect PixelRect) PixelPoint {
	return PixelPoint{
		x: math.max(rect.x, math.min(point.x, rect.right()))
		y: math.max(rect.y, math.min(point.y, rect.bottom()))
	}
}
