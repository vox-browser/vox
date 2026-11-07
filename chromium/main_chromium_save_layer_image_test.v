module main

import layout

fn save_layer_image_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			legacy_raster:   true
			bounds:          layout.LayoutRect{4, 229.09375, 484, 483.90625}
			command_indices: [0, 1, 2]
		}]
		command_layers: [1, 1, 1]
	}
}

fn test_save_layer_image_bounds_keep_ordinary_mask_geometry_within_one_root_column() {
	commands := [layout.PaintCommand{ kind: 'begin_svg_mask_layer' },
		layout.PaintCommand{ kind: 'draw_image' }, layout.PaintCommand{ kind: 'end_svg_mask_layer' }]
	plan := save_layer_image_test_plan()
	grid := ChromiumRasterGrid{ tile_width: 1056, tile_height: 256, columns: 1 }
	bounds := chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) or { panic('missing mask raster') }
	assert bounds == layout.LayoutRect{4, 229.09375, 484, 483.90625}
	assert chromium_save_layer_image_bounds(commands, plan, 0, grid, 1) == none
	assert chromium_save_layer_image_bounds(commands, plan, 2, grid, 1) == none
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 0) == none
	assert chromium_save_layer_image_bounds(commands, plan, 1,
		ChromiumRasterGrid{ tile_width: 2112, tile_height: 416, columns: 1 }, 2) != none
}

fn test_save_layer_image_bounds_leave_independent_fixed_and_filtered_rasters_unchanged() {
	mut commands := [layout.PaintCommand{ kind: 'begin_opacity_layer' },
		layout.PaintCommand{ kind: 'draw_image' }, layout.PaintCommand{ kind: 'end_opacity_layer' }]
	mut plan := save_layer_image_test_plan()
	grid := ChromiumRasterGrid{ tile_width: 1056, tile_height: 256, columns: 1 }
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) != none
	commands[1].fixed_to_viewport = true
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
	commands[1].fixed_to_viewport = false
	commands[0].kind = 'begin_css_filter_layer'
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
	commands[0].kind = 'begin_opacity_layer'
	plan.layers[1].has_fixed_opacity_paint_origin = true
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
	plan.layers[1].has_fixed_opacity_paint_origin = false
	plan.layers[1].legacy_raster = false
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
}

fn test_save_layer_image_bounds_reject_unsupported_grids_overflow_and_stale_indices() {
	commands := [layout.PaintCommand{}, layout.PaintCommand{}, layout.PaintCommand{}]
	mut plan := save_layer_image_test_plan()
	grid := ChromiumRasterGrid{ tile_width: 1056, tile_height: 256, columns: 1 }
	assert chromium_save_layer_image_bounds(commands, plan, 1, ChromiumRasterGrid{}, 1) == none
	assert chromium_save_layer_image_bounds(commands, plan, 1,
		ChromiumRasterGrid{ tile_width: 544, tile_height: 256, columns: 2 }, 1) == none
	plan.layers[1].bounds = layout.LayoutRect{4, 229.09375, 1060, 483.90625}
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
	plan.layers[1].bounds = layout.LayoutRect{-4, 0, 484, 484}
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
	plan.layers[1].bounds = layout.LayoutRect{4, 0, 484, 484}
	plan.layers[1].command_indices = [0, 3]
	assert chromium_save_layer_image_bounds(commands, plan, 1, grid, 1) == none
}
