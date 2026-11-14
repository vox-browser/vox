module main

import math

// Image coverage uses the same multisample selection as the document tile.
// A draw spanning different selections retains the existing platform path.
@[export: 'vox_document_image_sample_count']
fn document_image_sample_count(first_x i32, first_y i32, width i32, height i32) i32 {
	if width <= 0 || height <= 0 { return 0 }
	grid := document_geometry_grid
	if grid.width <= 2 || grid.height <= 2 || grid.columns <= 0 || grid.rows <= 0 { return 1 }
	x := int(first_x) - int(math.round(grid.origin_x))
	y := int(first_y) - int(math.round(grid.origin_y))
	if x < 0 || y < 0 || x + width > grid.columns * (grid.width - 2) + 2
		|| y + height > grid.rows * (grid.height - 2) + 2 {
		return 0
	}
	mut samples := i32(0)
	for row in geometry_tile_owner(y, grid.height, grid.rows) .. geometry_tile_owner(y + height - 1, grid.height, grid.rows) + 1 {
		for col in geometry_tile_owner(x, grid.width, grid.columns) .. geometry_tile_owner(x + width - 1, grid.width, grid.columns) + 1 {
			current := if i32(row * grid.columns + col) in grid.cells { i32(4) } else { i32(1) }
			if samples != 0 && samples != current { return 0 }
			samples = current
		}
	}
	return samples
}
