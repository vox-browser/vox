module main

import math

fn test_root_capture_grid_changes_only_the_excess_width_and_borrows_sample_ownership() {
	grid := ChromiumRasterGrid{
		tile_width:   2048
		tile_height:  416
		columns:      1
		cells:        [0, 1]
		native_cells: [i32(0), 1]
	}
	actual := chromium_root_capture_grid(grid, 1024, 1, 2, true)
	assert actual.tile_width == 1024 && actual.tile_height == 416 && actual.columns == 1
	assert actual.cells == grid.cells && actual.native_cells == grid.native_cells
	assert voidptr(actual.native_cells.data) == voidptr(grid.native_cells.data)
	assert grid.tile_width == 2048
}

fn test_root_capture_grid_preserves_wide_documents_ordinary_density_and_invalid_inputs() {
	grid := ChromiumRasterGrid{ tile_width: 2048, tile_height: 416, columns: 1 }
	assert chromium_root_capture_grid(grid, 1024, 1, 2, false).tile_width == 2048
	assert chromium_root_capture_grid(grid, 1024, 2, 2, true).tile_width == 2048
	assert chromium_root_capture_grid(ChromiumRasterGrid{ ...grid, columns: 2 }, 1024, 1, 2, true).tile_width == 2048
	assert chromium_root_capture_grid(ChromiumRasterGrid{ ...grid, tile_width: 512 }, 1024, 1, 2, true).tile_width == 512
	assert chromium_root_capture_grid(grid, 0, 1, 2, true).tile_width == 2048
	assert chromium_root_capture_grid(grid, 1024, math.nan(), 2, true).tile_width == 2048
	assert chromium_root_capture_grid(grid, 1024, 1, math.inf(1), true).tile_width == 2048
}
