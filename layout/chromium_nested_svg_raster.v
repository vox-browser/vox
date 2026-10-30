module layout

import math

fn chromium_nested_svg_finite_rect(rect LayoutRect) bool {
	for value in [rect.x, rect.y, rect.width, rect.height]! {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	return rect.width >= 0 && rect.height >= 0
}

fn chromium_nested_svg_clip_supported(command &PaintCommand) bool {
	if command.opacity != 1 || command.group_opacity != 1 || command.blur != 0
		|| command.outer_shadow || command.clip_outs.len != 0 || command.recording_clip != none
		|| command.scrollbar_axis != '' {
		return false
	}
	for value in command.transform {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	if command.has_clip && (!(command.clip_width > 0 && command.clip_height > 0)
		|| !chromium_nested_svg_finite_rect(LayoutRect{
		x:command.clip_x, y:command.clip_y, width:command.clip_width, height:command.clip_height
	})) { return false }
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
				|| clip.path_components.len != 0 || clip.corner_radii != BoxRadii{}
				|| !chromium_nested_svg_finite_rect(clip.rect) {
				return false
			}
			for value in clip.transform {
				if math.is_nan(value) || math.is_inf(value, 0) { return false }
			}
		}
	}
	return true
}

fn chromium_nested_svg_path_supported(command &PaintCommand) bool {
	if command.kind != 'draw_svg_path' || command.svg_data == unsafe { nil } { return false }
	data := command.svg_data
	for value in data.path_transform {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	for value in data.path_data {
		if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return false }
	}
	return data.path_data.len >= compatibility_clip_path_segment_stride
		&& data.path_data.len % compatibility_clip_path_segment_stride == 0
		&& data.svg_gradient_data == none && data.fill_pattern == none && data.stroke_pattern == none
		&& data.stroke_dasharray.len == 0 && !data.non_scaling_stroke
}

fn chromium_nested_svg_mask_supported(clip &PaintClip) bool {
	if !clip.is_svg_content_mask || clip.is_svg_mask || clip.is_path
		|| clip.scope_id == 0 || clip.cache_key == 0 || clip.mask_operations.len == 0
		|| clip.mask_operations.len > 32768 || !chromium_nested_svg_finite_rect(clip.rect)
		|| !(clip.rect.width > 0 && clip.rect.height > 0) {
		return false
	}
	for value in clip.transform {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	for index in 0 .. clip.mask_operations.len {
		operation := unsafe { &clip.mask_operations[index] }
		if operation.kind != .path || !operation.has_fill || operation.has_stroke
			|| operation.opacity != 1 || operation.fill_opacity != 1
			|| operation.path_data.len < compatibility_clip_path_segment_stride
			|| operation.path_data.len % compatibility_clip_path_segment_stride != 0
			|| operation.fill_linear_gradient != none || operation.stroke_linear_gradient != none
			|| operation.fill_radial_gradient != none || operation.stroke_radial_gradient != none
			|| operation.fill_pattern != none || operation.stroke_pattern != none {
			return false
		}
		for value in operation.transform {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
		for value in operation.path_data {
			if math.is_nan(f64(value)) || math.is_inf(f64(value), 0) { return false }
		}
	}
	return true
}

// The ordinary nested SVG player already replays these captured vector masks.
// Validate a complete, resource-independent stream before placing that player
// inside its parent's transparent compositor raster.
pub fn chromium_nested_svg_raster_supported(command &PaintCommand) bool {
	if command.kind != 'paint_nested_display_list' || !chromium_nested_svg_clip_supported(command)
		|| command.nested_viewport_commands.len == 0 || command.nested_viewport_commands.len > 32768 {
		return false
	}
	paintable := command.nested_viewport_paintable or { return false }
	if paintable.border_radii.has_any_radius()
		|| !(paintable.viewport_rect.width > 0 && paintable.viewport_rect.height > 0)
		|| !chromium_nested_svg_finite_rect(LayoutRect{
			x:paintable.viewport_rect.x, y:paintable.viewport_rect.y,
			width:paintable.viewport_rect.width, height:paintable.viewport_rect.height
		}) {
		return false
	}
	if nested := paintable.nested_rect {
		if !chromium_nested_svg_finite_rect(LayoutRect{
			x:nested.x, y:nested.y, width:nested.width, height:nested.height
		}) { return false }
	}
	mut scopes := [64]int{}
	mut depth := 0
	for index in 0 .. command.nested_viewport_commands.len {
		child := unsafe { &command.nested_viewport_commands[index] }
		if !chromium_nested_svg_clip_supported(child) { return false }
		match child.kind {
			'draw_svg_path' {
				if !chromium_nested_svg_path_supported(child) { return false }
			}
			'begin_svg_mask_layer' {
				layer := child.visual_layer_data or { return false }
				if depth == scopes.len || layer.kind != .svg_mask
					|| layer.scope_id != layer.mask_clip.scope_id
					|| !chromium_nested_svg_mask_supported(&layer.mask_clip) { return false }
				scopes[depth] = index
				depth++
			}
			'end_svg_mask_layer' {
				if depth == 0 { return false }
				previous := command.nested_viewport_commands[scopes[depth - 1]].visual_layer_data or { return false }
				layer := child.visual_layer_data or { return false }
				if layer.kind != .svg_mask || layer.scope_id != previous.scope_id
					|| layer.mask_clip.scope_id != previous.mask_clip.scope_id
					|| layer.mask_clip.cache_key != previous.mask_clip.cache_key
					|| layer.mask_clip.rect != previous.mask_clip.rect
					|| layer.mask_clip.transform != previous.mask_clip.transform
					|| layer.mask_clip.mask_luminance != previous.mask_clip.mask_luminance {
					return false
				}
				depth--
			}
			else { return false }
		}
	}
	return depth == 0
}
