module main

fn test_chromium_raster_grid_retains_viewport_and_content_scale_separately() {
	width, height := chromium_raster_tile_size(1280, 800, 1280, 2720, 1)
	assert width == 1280 && height == 256
	retina_width, retina_height := chromium_raster_tile_size(1024, 684, 2048, 5642, 2)
	assert retina_width == 544 && retina_height == 256
	fixed_width, fixed_height := chromium_raster_tile_size(1024, 684, 102, 204, 2)
	assert fixed_width == 128 && fixed_height == 256
}

fn test_distant_svg_does_not_multisample_another_column_in_the_same_row() {
	grid := chromium_raster_grid([
		ChromiumMSAATrigger{ command_index: 0, left: 497, right: 527, top: 202, bottom: 222 },
	], 1024, 684, 1024, 2821, 0, 0, 2)
	assert grid.columns == 4
	assert grid.cells == [5]
	// The toggle at x=939 occupies column 3, while the SVG occupies column 1.
	assert 7 !in grid.cells && 11 !in grid.cells
}

fn test_msaa_grid_includes_shared_border_texels_on_both_axes() {
	grid := chromium_raster_grid([
		ChromiumMSAATrigger{ left: 270, right: 273, top: 126, bottom: 129 },
	], 1024, 684, 1024, 2821, 0, 0, 2)
	assert grid.cells == [0, 1, 4, 5]
	// The native renderer reads C ints.
	assert grid.native_cells == [i32(0), 1, 4, 5]
}
