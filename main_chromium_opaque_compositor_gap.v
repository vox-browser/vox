module main

import css
import layout
import math

fn chromium_compositor_opaque_mask_resume(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, layer int, command_index int) bool {
	if layer <= 0 || layer >= plan.layers.len || !plan.has_paint_metadata { return false }
	indices := plan.layers[layer].command_indices
	for position, index in indices {
		if index != command_index { continue }
		return position > 0 && chromium_opaque_compositor_mask_gap(commands,plan,layer,
			indices[position - 1] + 1, command_index)
	}
	return false
}

// An opaque parent prefix can be published before a captured mask. All later
// parent ink must stay over that opaque prefix and away from the mask, so the
// resumed picture neither reorders the child nor quantizes transparent overlap.
fn chromium_opaque_compositor_mask_gap(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, parent int, start int, end int) bool {
	if end - start != 3 || start < 0 || end > commands.len { return false }
	owner := plan.command_layers[start]
	if owner < 0 || owner == parent || owner >= plan.layers.len { return false }
	child := plan.layers[owner]
	if !child.legacy_raster || child.command_indices != [start, start + 1, start + 2]
		|| plan.command_layers[start + 1] != owner || plan.command_layers[start + 2] != owner {
		return false
	}
	opening := unsafe { &commands[start] }
	closing := unsafe { &commands[end - 1] }
	if opening.kind != 'begin_svg_mask_layer' || closing.kind != 'end_svg_mask_layer'
		|| opening.fixed_to_viewport || closing.fixed_to_viewport { return false }
	mask := opening.visual_layer_data or { return false }
	finish := closing.visual_layer_data or { return false }
	if mask.kind != .svg_mask || finish.kind != mask.kind || mask.scope_id == 0
		|| finish.scope_id != mask.scope_id || mask.opacity != 1 || mask.blend_mode != .normal
		|| mask.filter != none { return false }
	leaf := unsafe { &commands[start + 1] }
	if leaf.kind != 'fill_rect' || leaf.visual_layer_data != none || leaf.fixed_to_viewport
		|| leaf.opacity != 1 || leaf.group_opacity != 1 || leaf.outer_shadow || leaf.blur != 0
		|| leaf.clip_outs.len != 0 { return false }
	child_ink := chromium_compositor_gap_ink(leaf) or { return false }
	if child_ink.width <= 0 || child_ink.height <= 0 { return false }
	mut resumed := layout.LayoutRect{}
	mut has_resumed := false
	mut previous := -1
	for index in plan.layers[parent].command_indices {
		if index < 0 || index >= commands.len || index <= previous
			|| plan.command_layers[index] != parent || (index >= start && index < end) {
			return false
		}
		previous = index
		command := unsafe { &commands[index] }
		if command.visual_layer_data != none || command.fixed_to_viewport
			|| command.opacity != 1 || command.group_opacity != 1 { return false }
		supported, _ := chromium_shared_recording_leaf_supported(command)
		if !supported { return false }
		if index < end { continue }
		ink := chromium_compositor_gap_ink(command) or { return false }
		if ink.width <= 0 || ink.height <= 0 { continue }
		if chromium_compositor_ink_overlaps(child_ink, ink) { return false }
		resumed = if has_resumed { chromium_compositor_ink_union(resumed, ink) } else { ink }
		has_resumed = true
	}
	if !has_resumed { return false }
	coverage := chromium_compositor_ink_union(child_ink, resumed)
	for index in plan.layers[parent].command_indices {
		if index >= start { break }
		command := unsafe { &commands[index] }
		if command.kind != 'fill_rect' || command.radius != 0
			|| command.corner_radii != layout.BoxRadii{} || command.has_clip
			|| command.clip_list != unsafe { nil } || command.recording_clip != none
			|| command.underlays_next || command.blur != 0 { continue }
		matrix := normalized_paint_transform(command.transform)
		if matrix[0] <= 0 || matrix[3] <= 0 || matrix[1] != 0 || matrix[2] != 0 { continue }
		color := css.parse_color_string(command.color) or { continue }
		if color.a != 255 || (command.srgb_color_data != unsafe { nil }
			&& command.srgb_color_data.components[3] != 1) { continue }
		ink := chromium_compositor_gap_ink(command) or { continue }
		// Whole covered pixels exclude fractional rectangle edges. Keep the
		// native raster fringe inside the opaque area as well.
		if math.ceil(ink.x) <= coverage.x - 3 && math.ceil(ink.y) <= coverage.y - 3
			&& math.floor(ink.x + ink.width) >= coverage.x + coverage.width + 3
			&& math.floor(ink.y + ink.height) >= coverage.y + coverage.height + 3 {
			return true
		}
	}
	return false
}
