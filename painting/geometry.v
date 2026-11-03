module painting

import math

fn min_int(first int, second int) int {
	return if first < second { first } else { second }
}

fn max_int(first int, second int) int {
	return if first > second { first } else { second }
}

fn abs_int(value int) int {
	return if value < 0 { -value } else { value }
}

// The C++ implementation uses strongly typed CSS- and device-pixel geometry.
// This port keeps the same boundary explicit: CSS geometry uses f64, while
// display-list command bounds use integer device pixels.
pub struct Point {
pub:
	x f64
	y f64
}

pub fn (point Point) add(other Point) Point {
	return Point{point.x + other.x, point.y + other.y}
}

pub fn (point Point) subtract(other Point) Point {
	return Point{point.x - other.x, point.y - other.y}
}

pub fn (point Point) scale(factor f64) Point {
	return Point{point.x * factor, point.y * factor}
}

pub fn (point Point) is_zero() bool {
	return point.x == 0 && point.y == 0
}

pub struct Size {
pub:
	width  f64
	height f64
}

pub struct Rect {
pub:
	x      f64
	y      f64
	width  f64
	height f64
}

pub fn (rect Rect) left() f64 {
	return rect.x
}

pub fn (rect Rect) top() f64 {
	return rect.y
}

pub fn (rect Rect) right() f64 {
	return rect.x + rect.width
}

pub fn (rect Rect) bottom() f64 {
	return rect.y + rect.height
}

pub fn (rect Rect) location() Point {
	return Point{rect.x, rect.y}
}

pub fn (rect Rect) size() Size {
	return Size{rect.width, rect.height}
}

pub fn (rect Rect) is_empty() bool {
	return rect.width <= 0 || rect.height <= 0
}

pub fn (rect Rect) contains(point Point) bool {
	return !rect.is_empty() && point.x >= rect.left() && point.x < rect.right()
		&& point.y >= rect.top() && point.y < rect.bottom()
}

pub fn (rect Rect) intersects(other Rect) bool {
	return !rect.is_empty() && !other.is_empty() && rect.left() < other.right()
		&& other.left() < rect.right() && rect.top() < other.bottom() && other.top() < rect.bottom()
}

pub fn (rect Rect) translated(delta Point) Rect {
	return Rect{rect.x + delta.x, rect.y + delta.y, rect.width, rect.height}
}

pub fn (rect Rect) inflated(top f64, right f64, bottom f64, left f64) Rect {
	return Rect{
		x: rect.x - left
		y: rect.y - top
		width: rect.width + left + right
		height: rect.height + top + bottom
	}
}

pub fn (rect Rect) intersection(other Rect) Rect {
	left := math.max(rect.left(), other.left())
	top := math.max(rect.top(), other.top())
	right := math.min(rect.right(), other.right())
	bottom := math.min(rect.bottom(), other.bottom())
	if right <= left || bottom <= top {
		return Rect{}
	}
	return Rect{left, top, right - left, bottom - top}
}

pub fn (rect Rect) united(other Rect) Rect {
	if rect.is_empty() {
		return other
	}
	if other.is_empty() {
		return rect
	}
	left := math.min(rect.left(), other.left())
	top := math.min(rect.top(), other.top())
	right := math.max(rect.right(), other.right())
	bottom := math.max(rect.bottom(), other.bottom())
	return Rect{left, top, right - left, bottom - top}
}

pub struct IntPoint {
pub:
	x int
	y int
}

pub struct IntSize {
pub:
	width  int
	height int
}

pub struct IntRect {
pub:
	x      int
	y      int
	width  int
	height int
}

pub fn (rect IntRect) left() int {
	return rect.x
}

pub fn (rect IntRect) top() int {
	return rect.y
}

pub fn (rect IntRect) right() int {
	return rect.x + rect.width
}

pub fn (rect IntRect) bottom() int {
	return rect.y + rect.height
}

pub fn (rect IntRect) is_empty() bool {
	return rect.width <= 0 || rect.height <= 0
}

pub fn (rect IntRect) contains(point IntPoint) bool {
	return !rect.is_empty() && point.x >= rect.left() && point.x < rect.right()
		&& point.y >= rect.top() && point.y < rect.bottom()
}

pub fn (rect IntRect) translated(delta IntPoint) IntRect {
	return IntRect{rect.x + delta.x, rect.y + delta.y, rect.width, rect.height}
}

pub fn (rect IntRect) inflated(top int, right int, bottom int, left int) IntRect {
	return IntRect{
		x: rect.x - left
		y: rect.y - top
		width: rect.width + left + right
		height: rect.height + top + bottom
	}
}

pub fn (rect IntRect) intersects(other IntRect) bool {
	return !rect.is_empty() && !other.is_empty() && rect.left() < other.right()
		&& other.left() < rect.right() && rect.top() < other.bottom() && other.top() < rect.bottom()
}

pub fn int_rect_from_two_points(first IntPoint, second IntPoint) IntRect {
	left := min_int(first.x, second.x)
	top := min_int(first.y, second.y)
	right := max_int(first.x, second.x)
	bottom := max_int(first.y, second.y)
	return IntRect{left, top, right - left, bottom - top}
}

pub struct DevicePixelConverter {
	scale_ f64 = 1.0
}

pub fn new_device_pixel_converter(scale f64) !DevicePixelConverter {
	if scale <= 0 || math.is_nan(scale) || math.is_inf(scale, 0) {
		return error('device pixel scale must be finite and positive')
	}
	return DevicePixelConverter{
		scale_: scale
	}
}

pub fn (converter DevicePixelConverter) device_pixels_per_css_pixel() f64 {
	return converter.scale_
}

pub fn (converter DevicePixelConverter) rounded_device_pixels(css_pixels f64) int {
	return int(math.round(css_pixels * converter.scale_))
}

pub fn (converter DevicePixelConverter) enclosing_device_pixels(css_pixels f64) int {
	return int(math.ceil(css_pixels * converter.scale_))
}

pub fn (converter DevicePixelConverter) floored_device_pixels(css_pixels f64) int {
	return int(math.floor(css_pixels * converter.scale_))
}

pub fn (converter DevicePixelConverter) rounded_device_point(point Point) IntPoint {
	return IntPoint{converter.rounded_device_pixels(point.x), converter.rounded_device_pixels(point.y)}
}

pub fn (converter DevicePixelConverter) floored_device_point(point Point) IntPoint {
	return IntPoint{converter.floored_device_pixels(point.x), converter.floored_device_pixels(point.y)}
}

pub fn (converter DevicePixelConverter) enclosing_device_rect(rect Rect) IntRect {
	return IntRect{
		x: converter.floored_device_pixels(rect.x)
		y: converter.floored_device_pixels(rect.y)
		width: converter.enclosing_device_pixels(rect.width)
		height: converter.enclosing_device_pixels(rect.height)
	}
}

pub fn (converter DevicePixelConverter) rounded_device_rect(rect Rect) IntRect {
	left := converter.rounded_device_pixels(rect.left())
	top := converter.rounded_device_pixels(rect.top())
	right := converter.rounded_device_pixels(rect.right())
	bottom := converter.rounded_device_pixels(rect.bottom())
	return IntRect{left, top, right - left, bottom - top}
}

pub fn (converter DevicePixelConverter) enclosing_device_size(size Size) IntSize {
	return IntSize{converter.enclosing_device_pixels(size.width), converter.enclosing_device_pixels(size.height)}
}

pub fn (converter DevicePixelConverter) rounded_device_size(size Size) IntSize {
	return IntSize{converter.rounded_device_pixels(size.width), converter.rounded_device_pixels(size.height)}
}

// Affine is the 2-D projection used by hit testing and visual-context walks.
pub struct Affine {
pub:
	a f64 = 1.0
	b f64
	c f64
	d f64 = 1.0
	e f64
	f f64
}

pub fn (transform Affine) map_point(point Point) Point {
	return Point{
		x: transform.a * point.x + transform.c * point.y + transform.e
		y: transform.b * point.x + transform.d * point.y + transform.f
	}
}

pub fn (transform Affine) map_rect(rect Rect) Rect {
	points := [
		transform.map_point(Point{rect.left(), rect.top()}),
		transform.map_point(Point{rect.right(), rect.top()}),
		transform.map_point(Point{rect.right(), rect.bottom()}),
		transform.map_point(Point{rect.left(), rect.bottom()}),
	]!
	mut min_x := points[0].x
	mut max_x := points[0].x
	mut min_y := points[0].y
	mut max_y := points[0].y
	for index in 1 .. points.len {
		point := points[index]
		min_x = math.min(min_x, point.x)
		max_x = math.max(max_x, point.x)
		min_y = math.min(min_y, point.y)
		max_y = math.max(max_y, point.y)
	}
	return Rect{min_x, min_y, max_x - min_x, max_y - min_y}
}

pub fn (transform Affine) inverse() ?Affine {
	determinant := transform.a * transform.d - transform.b * transform.c
	if math.abs(determinant) <= 1e-12 {
		return none
	}
	return Affine{
		a: transform.d / determinant
		b: -transform.b / determinant
		c: -transform.c / determinant
		d: transform.a / determinant
		e: (transform.c * transform.f - transform.d * transform.e) / determinant
		f: (transform.b * transform.e - transform.a * transform.f) / determinant
	}
}
