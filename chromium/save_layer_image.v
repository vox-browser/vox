module main

import layout
import math

// Ordinary opacity/mask saveLayers are rasterized separately within each
// parent tile. Their image input keeps the saveLayer's horizontal origin and
// the parent tile's vertical intersection, even without an opaque backdrop.
// Fixed effects and multi-column parents retain their established policy.
fn chromium_save_layer_image_bounds(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int, root_grid ChromiumRasterGrid,
	scale f64) ?layout.LayoutRect {
	if index <= 0 || index >= plan.layers.len || root_grid.columns != 1
		|| root_grid.tile_height <= 2 || root_grid.tile_width <= 2
		|| !(scale > 0) || math.is_inf(scale, 0) {
		return none
	}
	layer := plan.layers[index]
	if !layer.legacy_raster || layer.has_fixed_opacity_paint_origin
		|| layer.command_indices.len == 0 {
		return none
	}
	bounds := layer.bounds
	if !(bounds.width > 0 && bounds.height > 0) || bounds.x < 0
		|| (bounds.x + bounds.width) * scale > root_grid.tile_width {
		return none
	}
	for value in [bounds.x, bounds.y, bounds.width, bounds.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return none }
	}
	for command_index in layer.command_indices {
		if command_index < 0 || command_index >= commands.len { return none }
		command := commands[command_index]
		if command.fixed_to_viewport || command.kind in ['begin_css_filter_layer',
			'end_css_filter_layer', 'begin_backdrop_filter_layer', 'end_backdrop_filter_layer'] {
			return none
		}
	}
	return bounds
}
