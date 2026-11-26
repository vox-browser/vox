module main

import layout
import math
import os

const serial_paint_screen_geometry = os.getenv('VOX_SERIAL_PAINT_SCREEN_GEOMETRY') == '1'
const paint_screen_geometry_diagnostics = os.getenv('VOX_PAINT_SCREEN_GEOMETRY_DIAGNOSTICS') == '1'
const paint_screen_geometry_command_limit = 16 * 1024

struct PaintCommandScreenGeometry {
	points [8]f32
	matrix [6]f64
	x      f32
	y      f32
	width  f32
	height f32
	ready  bool
}

@[params]
struct PaintCommandReplayOptions {
	glyph_geometry  &layout.RetainedGlyphReplayGeometry = unsafe { nil }
	screen_geometry &PaintCommandScreenGeometry = unsafe { nil }
	gradient_stops  &PaintGradientStops = unsafe { nil }
	skip_transparent_gradient bool
}

fn project_paint_screen_point(matrix [6]f64, x f64, y f64, page_x f32, page_y f32,
	scroll_y f64) (f32, f32) {
	mapped_x, mapped_y := map_normalized_paint_point(matrix, x, y)
	return page_x + f32(mapped_x), page_y + f32(mapped_y - scroll_y)
}

fn map_normalized_paint_point(matrix [6]f64, x f64, y f64) (f64, f64) {
	return matrix[0] * x + matrix[2] * y + matrix[4], matrix[1] * x + matrix[3] * y + matrix[5]
}

fn project_paint_rect_points(command &layout.PaintCommand, matrix [6]f64, page_x f32, page_y f32,
	scroll_y f64) [8]f32 {
	right := command.x + command.width
	bottom := command.y + command.height
	left_top_x, left_top_y := project_paint_screen_point(matrix, command.x, command.y, page_x, page_y, scroll_y)
	right_top_x, right_top_y := project_paint_screen_point(matrix, right, command.y, page_x, page_y, scroll_y)
	right_bottom_x, right_bottom_y := project_paint_screen_point(matrix, right, bottom, page_x, page_y, scroll_y)
	left_bottom_x, left_bottom_y := project_paint_screen_point(matrix, command.x, bottom, page_x, page_y, scroll_y)
	return [left_top_x, left_top_y, right_top_x, right_top_y,
		right_bottom_x, right_bottom_y, left_bottom_x, left_bottom_y]!
}

fn paint_command_screen_geometry(command &layout.PaintCommand, page_x f32, page_y f32,
	scroll_y f64) PaintCommandScreenGeometry {
	matrix := normalized_paint_transform(command.transform)
	points := project_paint_rect_points(command, matrix, page_x, page_y, scroll_y)
	mut left := points[0]
	mut top := points[1]
	mut right := left
	mut bottom := top
	for index := 2; index + 1 < points.len; index += 2 {
		left = math.min(left, points[index])
		top = math.min(top, points[index + 1])
		right = math.max(right, points[index])
		bottom = math.max(bottom, points[index + 1])
	}
	return PaintCommandScreenGeometry{
		points: points
		matrix: matrix
		x: left
		y: top
		width: right - left
		height: bottom - top
		ready: true
	}
}
