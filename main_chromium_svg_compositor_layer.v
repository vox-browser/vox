module main

import layout

// Rasterize SVG contents together with their own backgrounds and glyphs before
// blending the layer over its parent. Isolating each path loses painted sibling
// backgrounds; reading the parent directly loses premultiplied edge rounding.
// Existing CSS scopes and layers with gaps retain their existing replay path.
fn chromium_svg_compositor_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	if layer.legacy_raster || !layer.composited_contents || layer.command_indices.len == 0 {
		return false
	}
	first := layer.command_indices.first()
	last := layer.command_indices.last()
	if first < 0 || last >= commands.len || last - first + 1 != layer.command_indices.len
		|| (first > 0 && plan.command_layers[first - 1] == index)
		|| (last + 1 < commands.len && plan.command_layers[last + 1] == index) {
		return false
	}
	mut has_svg := false
	for position, command_index in layer.command_indices {
		if command_index != first + position || plan.command_layers[command_index] != index {
			return false
		}
		command := unsafe { &commands[command_index] }
		if command.opacity != 1 || command.group_opacity != 1 || command.blur != 0
			|| command.outer_shadow || command.clip_outs.len > 0 || command.scrollbar_axis != ''
			|| !chromium_shared_recording_clips_supported(command) {
			return false
		}
		match command.kind {
			'draw_svg_path' {
				if !chromium_svg_solid_path_supported(command) { return false }
				has_svg = true
			}
			'draw_text', 'fill_rect', 'fill_rounded_rect', 'paint_uniform_border' {}
			else { return false }
		}
	}
	return has_svg
}
