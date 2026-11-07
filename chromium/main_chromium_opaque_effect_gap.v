module main

import css
import layout
import math
import os

// A bounded saveLayer does not create a compositor surface. An opaque prefix
// can remain the parent of disjoint later paint across this native replay gap.
fn chromium_compositor_opaque_effect_resume(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, parent int, command_index int) bool {
	if parent <= 0 || parent >= plan.layers.len { return false }
	indices := plan.layers[parent].command_indices
	for position, index in indices {
		if index == command_index && position > 0 {
			return chromium_opaque_compositor_effect_gap(commands, plan, parent,
				indices[position - 1] + 1, index)
		}
	}
	return false
}

fn chromium_opaque_compositor_effect_gap(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, parent int, start int, end int) bool {
	if parent <= 0 || parent >= plan.layers.len || start < 0 || end > commands.len
		|| end - start < 3 || plan.command_layers.len != commands.len {
		return false
	}
	owner := plan.command_layers[start]
	if owner <= 0 || owner == parent || owner >= plan.layers.len
		|| !plan.layers[owner].legacy_raster {
		return false
	}
	child := plan.layers[owner].command_indices
	if child.len != end - start { return false }
	opening := &commands[start]
	closing := &commands[end - 1]
	effect := opening.visual_layer_data or { return false }
	finish := closing.visual_layer_data or { return false }
	if opening.kind != 'begin_css_effect_layer' || closing.kind != 'end_css_effect_layer'
		|| effect.kind != .css_effect || finish.kind != effect.kind || effect.scope_id == 0
		|| finish.scope_id != effect.scope_id || effect.opacity <= 0 || effect.opacity >= 1
		|| effect.blend_mode != .normal || effect.filter != none {
		return false
	}
	mut child_ink := layout.LayoutRect{}
	mut has_child := false
	for position, index in child {
		if index != start + position || plan.command_layers[index] != owner { return false }
		if index == start || index == end - 1 { continue }
		command := &commands[index]
		if command.visual_layer_data != none || command.fixed_to_viewport != opening.fixed_to_viewport
			|| command.kind.starts_with('begin_') || command.kind.starts_with('end_') {
			return false
		}
		normalized := layout.PaintCommand{ ...*command, opacity: 1, group_opacity: 1 }
		supported, _ := chromium_shared_recording_leaf_supported(&normalized)
		if !supported {
			return chromium_svg_compositor_layer_declined(parent, index, 'opaque child leaf', command.kind)
		}
		ink := chromium_opaque_effect_visible_ink(&normalized) or {
			return chromium_svg_compositor_layer_declined(parent, index, 'opaque child ink', command.kind)
		}
		if ink.width <= 0 || ink.height <= 0 { continue }
		child_ink = if has_child { chromium_compositor_ink_union(child_ink, ink) } else { ink }
		has_child = true
	}
	if !has_child { return false }
	mut resumed := layout.LayoutRect{}
	mut has_resumed := false
	mut previous := -1
	for index in plan.layers[parent].command_indices {
		if index < 0 || index >= commands.len || index <= previous
			|| plan.command_layers[index] != parent || (index >= start && index < end) {
			return false
		}
		previous = index
		command := &commands[index]
		if command.visual_layer_data != none || command.fixed_to_viewport != opening.fixed_to_viewport
			|| command.opacity != 1 || command.group_opacity != 1 {
			return false
		}
		supported, _ := chromium_shared_recording_leaf_supported(command)
		if !supported {
			return chromium_svg_compositor_layer_declined(parent, index, 'opaque parent leaf', command.kind)
		}
		if index < end { continue }
		ink := chromium_opaque_effect_visible_ink(command) or {
			return chromium_svg_compositor_layer_declined(parent, index, 'opaque resumed ink', command.kind)
		}
		if ink.width <= 0 || ink.height <= 0 { continue }
		if chromium_compositor_ink_overlaps(child_ink, ink) {
			return chromium_svg_compositor_layer_declined(parent, index, 'opaque child overlaps continuation', command.kind)
		}
		resumed = if has_resumed { chromium_compositor_ink_union(resumed, ink) } else { ink }
		has_resumed = true
	}
	if !has_resumed { return false }
	coverage := layout.LayoutRect{resumed.x - 3, resumed.y - 3, resumed.width + 6, resumed.height + 6}
	if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
		eprintln('VOX_OPAQUE_CONTINUATION layer=${parent} gap=${start}:${end} coverage=${coverage.x},${coverage.y},${coverage.width},${coverage.height}')
	}
	for index in plan.layers[parent].command_indices {
		if index >= start { break }
		command := &commands[index]
		if command.kind != 'fill_rect' || command.blur != 0 || command.outer_shadow
			|| command.clip_outs.len != 0 {
			continue
		}
		color := css.parse_color_string(command.color) or { continue }
		if color.a != 255 || (command.srgb_color_data != unsafe { nil }
			&& command.srgb_color_data.components[3] != 1) {
			continue
		}
		mut radii := command.corner_radii
		if radii == layout.BoxRadii{} {
			r := layout.CornerRadius{command.radius, command.radius}
			radii = layout.BoxRadii{r, r, r, r}
		}
		if !chromium_opaque_round_rect_contains(layout.LayoutRect{command.x, command.y, command.width, command.height}, radii, command.transform, coverage) {
			if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
				eprintln('VOX_OPAQUE_PREFIX_OUTSIDE command=${index} rect=${command.x},${command.y},${command.width},${command.height} transform=${command.transform}')
			}
			continue
		}
		if command.has_clip && !chromium_opaque_round_rect_contains(layout.LayoutRect{command.clip_x, command.clip_y, command.clip_width, command.clip_height},
			layout.BoxRadii{}, [f64(1), 0, 0, 1, 0, 0]!, coverage) {
			continue
		}
		mut clips_contain := true
		if command.clip_list != unsafe { nil } {
			for clip in command.clip_list.items {
				if !chromium_opaque_clip_contains(clip, coverage) {
					clips_contain = false
					break
				}
			}
		}
		if clip := command.recording_clip {
			if !chromium_opaque_round_rect_contains(clip, layout.BoxRadii{},
				[f64(1), 0, 0, 1, 0, 0]!, coverage) {
				clips_contain = false
			}
		}
		if clips_contain { return true }
	}
	return false
}

fn chromium_opaque_clip_contains(clip layout.PaintClip, coverage layout.LayoutRect) bool {
	return !clip.is_path && !clip.is_svg_mask && !clip.is_svg_content_mask
		&& chromium_opaque_round_rect_contains(clip.rect, clip.corner_radii, clip.transform, coverage)
}

fn chromium_opaque_effect_visible_ink(command &layout.PaintCommand) ?layout.LayoutRect {
	// Clips and paint servers can shrink this conservative geometry. They do
	// not require the scalar SVG batch's stricter recording eligibility here.
	if command.kind == 'draw_svg_path' {
		if command.stroke_color != '' && command.stroke_width > 0 {
			normalized := layout.PaintCommand{ ...*command, recording_clip: none, opacity: 1, group_opacity: 1 }
			if !chromium_svg_solid_path_supported_with_clips(&normalized, true) { return none }
		}
		return layout.paint_svg_path_native_ink_bounds(command)
	}
	if command.kind == 'draw_text' && command.text == '' {
		if run := command.glyph_run {
			if run.glyphs_.len == 0 { return layout.LayoutRect{} }
		} else {
			return layout.LayoutRect{}
		}
	}
	if command.kind in ['fill_rect', 'fill_rounded_rect', 'paint_uniform_border', 'fill_ellipse',
		'stroke_ellipse', 'stroke_rounded_rect'] {
		if color := css.parse_color_string(command.color) {
			if color.a == 0 && (command.srgb_color_data == unsafe { nil }
				|| command.srgb_color_data.components[3] == 0) {
				return layout.LayoutRect{}
			}
		}
	}
	return chromium_compositor_gap_ink(command)
}

fn chromium_opaque_round_rect_contains(rect layout.LayoutRect, radii layout.BoxRadii,
	input [6]f64, coverage layout.LayoutRect) bool {
	matrix := normalized_paint_transform(input)
	if matrix[0] <= 0 || matrix[3] <= 0 || matrix[1] != 0 || matrix[2] != 0
		|| rect.width <= 0 || rect.height <= 0 {
		return false
	}
	for value in [matrix[0], matrix[3], matrix[4], matrix[5], rect.x, rect.y, rect.width, rect.height,
		coverage.x, coverage.y, coverage.width, coverage.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	for point in [[coverage.x, coverage.y]!, [coverage.x + coverage.width, coverage.y]!,
		[coverage.x + coverage.width, coverage.y + coverage.height]!,
		[coverage.x, coverage.y + coverage.height]!] {
		x := (point[0] - matrix[4]) / matrix[0] - rect.x
		y := (point[1] - matrix[5]) / matrix[3] - rect.y
		if x < 0 || y < 0 || x > rect.width || y > rect.height { return false }
		for index, radius in [radii.top_left, radii.top_right, radii.bottom_right, radii.bottom_left] {
			if radius.x < 0 || radius.y < 0 || math.is_nan(radius.x) || math.is_nan(radius.y)
				|| math.is_inf(radius.x, 0) || math.is_inf(radius.y, 0) {
				return false
			}
			if radius.x == 0 || radius.y == 0 { continue }
			dx := if index in [0, 3] { radius.x - x } else { x - (rect.width - radius.x) }
			dy := if index < 2 { radius.y - y } else { y - (rect.height - radius.y) }
			if dx > 0 && dy > 0 && dx * dx / (radius.x * radius.x) + dy * dy / (radius.y * radius.y) > 1 {
				return false
			}
		}
	}
	return true
}
