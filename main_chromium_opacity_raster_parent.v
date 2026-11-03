module main

import layout

// A CSS opacity saveLayer inside a resumed fixed picture uses that picture's
// raster grid. Require the same immediate parent on both sides and the existing
// bounded, opaque continuation proof; other legacy surfaces keep their policy.
fn chromium_opacity_raster_parent(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) int {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return index
	}
	child := plan.layers[index]
	if !child.legacy_raster || !child.has_fixed_opacity_paint_origin
		|| child.command_indices.len < 3 { return index }
	first := child.command_indices.first()
	end := child.command_indices.last() + 1
	if first <= 0 || first >= commands.len || end <= first || end >= commands.len
		|| !commands[first].fixed_to_viewport {
		return index
	}
	parent := plan.command_layers[first - 1]
	if parent <= 0 || parent >= plan.layers.len || parent == index
		|| plan.command_layers[end] != parent || plan.layers[parent].legacy_raster
		|| !plan.layers[parent].composited_contents { return index }
	return if chromium_opaque_compositor_effect_gap(commands, plan, parent, first, end) {
		parent
	} else { index }
}
