// vtest build: macos
module main

import layout
import math

fn test_filled_list_disc_matches_independent_brave_coverage() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{width: 1024, height: 256,
		columns: 1, rows: 4}
	mut shape := chromium_filled_ellipse_shape(layout.PaintCommand{
		kind: 'fill_ellipse', x: 744, y: 737, width: 4, height: 4
	}) or { panic('disc descriptor') }
	shape.matrix = [f32(1), 0, -742, 0, 1, -735, 0, 0, 1]!
	shape.red = 34
	shape.green = 34
	shape.blue = 34
	shape.alpha = 255
	mut pixels := []u8{len: 8 * 8 * 4, init: 255}
	assert draw_document_shape_pixels(pixels.data, 8, 8, 32, 1, 742, 735, &shape) == 1
	// Independent Brave pixels from the recovered Reddit list, with zero tolerance.
	expected := [u8(171), 40, 40, 171, 40, 34, 34, 40,
		40, 34, 34, 40, 171, 40, 40, 171]
	for y in 0 .. 8 {
		for x in 0 .. 8 {
			value := if x >= 2 && x < 6 && y >= 2 && y < 6 {
				expected[(y - 2) * 4 + x - 2]
			} else { u8(255) }
			i := (y * 8 + x) * 4
			assert pixels[i..i + 4] == [value, value, value, u8(255)]
		}
	}
}

fn test_filled_ellipse_rejects_invalid_geometry_and_unrelated_commands() {
	for command in [
		layout.PaintCommand{kind: 'stroke_ellipse', width: 4, height: 4},
		layout.PaintCommand{kind: 'fill_ellipse', width: 0, height: 4},
		layout.PaintCommand{kind: 'fill_ellipse', width: 4, height: -1},
		layout.PaintCommand{kind: 'fill_ellipse', x: math.nan(), width: 4, height: 4},
		layout.PaintCommand{kind: 'fill_ellipse', width: math.inf(1), height: 4},
	] {
		assert chromium_filled_ellipse_shape(command) == none
	}
}
