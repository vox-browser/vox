module main

import gg
import math
import os

const document_analytic_rect_diagnostic = os.getenv('VOX_DIAGNOSTIC_ANALYTIC_RECT') == '1'

@[export: 'vox_document_analytic_rect_enabled']
fn document_analytic_rect_enabled() i32 {
	return i32(document_analytic_rect_diagnostic)
}

// Native solid rectangles use bottom-up bitmap coordinates. Restrict this
// experiment to opaque fractional thin fills on an untransformed document
// bitmap; the established native clip remains active for publication.
fn document_analytic_rect_geometry(bounds [4]f32, original [4]f32,
	matrix [6]f32, width int, height int) ?[4]f32 {
	if matrix != [f32(1), 0, 0, 1, 0, 0]! || width <= 0 || height <= 0
		|| width > 4096 || height > 4096 {
		return none
	}
	for rect in [bounds, original] {
		if rect[2] <= 0 || rect[3] <= 0 { return none }
		for value in rect { if !math.is_finite(value) { return none } }
		if !math.is_finite(rect[0] + rect[2]) || !math.is_finite(rect[1] + rect[3])
			|| rect[0] + rect[2] == rect[0] || rect[1] + rect[3] == rect[1] {
			return none
		}
	}
	if original[2] > 4 && original[3] > 4 { return none }
	edges := [original[0], original[1], original[0] + original[2], original[1] + original[3]]
	if edges.all(it == math.floor(it)) { return none }
	top := f32(height) - bounds[1] - bounds[3]
	if !math.is_finite(top) || top + bounds[3] == top { return none }
	return [bounds[0], top, bounds[2], bounds[3]]!
}

@[export: 'vox_draw_document_analytic_rect']
fn draw_document_analytic_rect(bounds &f32, original &f32, matrix &f32,
	color u32, width i32, height i32) i32 {
	if !document_analytic_rect_diagnostic || color >> 24 != 255
		|| C.native_document_raster_uses_p3() == 0 || bounds == unsafe { nil }
		|| original == unsafe { nil } || matrix == unsafe { nil } {
		return 0
	}
	mut rectangle := [4]f32{}
	mut source := [4]f32{}
	mut transform := [6]f32{}
	unsafe {
		for i in 0 .. 4 { rectangle[i], source[i] = bounds[i], original[i] }
		for i in 0 .. 6 { transform[i] = matrix[i] }
	}
	paint := document_analytic_rect_geometry(rectangle, source, transform,
		int(width), int(height)) or { return 0 }
	fill := gg.Color{r: u8(color >> 16), g: u8(color >> 8), b: u8(color), a: 255}
	C.native_draw_rounded_rect_srgb(paint[0], paint[1], paint[2], paint[3],
		0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0,
		f32(width), f32(height), fill, 1, 0, 1)
	eprintln('VOX_DOCUMENT_ANALYTIC_RECT original=${source} conditioned=${rectangle} paint=${paint}')
	return 1
}
