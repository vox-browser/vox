module main

import layout
import math

// A promoted box still needs its transparent surface when its ordinary shadow
// cannot join a complete GPU picture. Keep the existing leaf painters inside
// that surface; drawing them over the parent skips premultiplied rounding.
fn chromium_leaf_compositor_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	indices := layer.command_indices
	if layer.legacy_raster || !layer.composited_contents || indices.len == 0 { return false }
	first := indices.first()
	last := indices.last()
	if first < 0 || last >= commands.len || last - first + 1 != indices.len
		|| (first > 0 && plan.command_layers[first - 1] == index)
		|| (last + 1 < commands.len && plan.command_layers[last + 1] == index) {
		return false
	}
	mut has_shadow := false
	for position, command_index in indices {
		if command_index != first + position || plan.command_layers[command_index] != index {
			return false
		}
		command := &commands[command_index]
		if command.opacity != 1 || command.group_opacity != 1 || command.outer_shadow
			|| command.scrollbar_axis != '' || !chromium_shared_recording_clips_supported(command)
			|| !chromium_svg_compositor_clip_outs_supported(command) {
			return false
		}
		for value in [command.x, command.y, command.width, command.height, command.blur,
			command.stroke_width, command.radius] {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
		for value in command.transform {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
		if command.kind == 'paint_outer_box_shadow' {
			if command.box_shadow_data == unsafe { nil } || command.blur < 0 { return false }
			has_shadow = true
		} else if command.blur != 0 || command.kind !in ['draw_text', 'fill_rect', 'fill_rounded_rect',
			'paint_uniform_border'] {
			return false
		}
	}
	return has_shadow
}
