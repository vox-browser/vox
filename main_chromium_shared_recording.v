module main

import layout
import math
import painting

fn C.native_set_chromium_shared_recording(i32, i32, i32)
fn C.native_set_chromium_layer_shared_recording(i32)

// Only complete supported scopes can replace their existing leaf rendering.
fn chromium_shared_recording_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan) bool {
	if plan.layers.len == 0 || plan.layers[0].legacy_raster
		|| plan.command_layers.len != commands.len {
		return false
	}
	mut left_root := false
	mut has_vectors := false
	mut svg_end := 0
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		if plan.command_layers[index] != 0 {
			left_root = true
			continue
		}
		if command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0)
			&& !command.kind.starts_with('begin_') && !command.kind.starts_with('end_') {
			continue
		}
		if left_root { return false }
		if index < svg_end { continue }
		// Keep complete SVG batches together, including their own viewport clip.
		svg_end = chromium_svg_rectangular_mask_end(commands, plan.command_layers, index)
		if svg_end == index {
			svg_end = chromium_svg_solid_run_end(commands, plan.command_layers, index)
		}
		if svg_end > index {
			has_vectors = true
			continue
		}
		supported, vectors := chromium_shared_recording_leaf_supported(command)
		if !supported { return false }
		has_vectors = has_vectors || vectors
	}
	return has_vectors
}

fn chromium_shared_recording_clips_supported(command &layout.PaintCommand) bool {
	if !command.has_clip { return command.clip_list == unsafe { nil } }
	for value in [command.clip_x, command.clip_y, command.clip_width, command.clip_height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	if command.clip_list == unsafe { nil } { return true }
	for clip in command.clip_list.items {
		if clip.is_path || clip.is_svg_mask || clip.is_svg_content_mask
			|| clip.path_components.len > 0 {
			return false
		}
		for value in [clip.rect.x, clip.rect.y, clip.rect.width, clip.rect.height] {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
		for value in clip.transform {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
		for radius in [clip.corner_radii.top_left, clip.corner_radii.top_right,
			clip.corner_radii.bottom_right, clip.corner_radii.bottom_left] {
			if radius.x < 0 || radius.y < 0 || math.is_nan(radius.x) || math.is_nan(radius.y)
				|| math.is_inf(radius.x, 0) || math.is_inf(radius.y, 0) {
				return false
			}
		}
	}
	return true
}

fn chromium_shared_recording_leaf_supported(command &layout.PaintCommand) (bool, bool) {
	mut has_vectors := false
	// Native replay discards ordinary leaves with an empty clip before
	// drawing. Hidden accessible controls must not disable the recording;
	// effect boundaries still need their existing balanced replay path.
	if command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0)
		&& !command.kind.starts_with('begin_') && !command.kind.starts_with('end_') {
		return true, false
	}
	if !chromium_shared_recording_clips_supported(command)
		|| command.clip_outs.len > 0 || command.blur != 0 || command.outer_shadow {
		return false, false
	}
	match command.kind {
		'draw_background_image' {
			data := command.image_data
			if data == unsafe { nil } || data.background_blend_mode != .normal
				|| data.background_svg_document != none || data.background_static_svg_resource != none {
				return false, false
			}
			url := data.image_url.to_lower()
			if url.starts_with('data:image/svg+xml') || url.all_before('?').all_before('#').ends_with('.svg') {
				return false, false
			}
		}
		'fill_rect', 'fill_rounded_rect', 'paint_uniform_border', 'stroke_rounded_rect',
		'fill_ellipse', 'stroke_ellipse', 'draw_text', 'draw_replaced_image', 'draw_svg_image' {
		}
		'draw_svg_path' {
			has_vectors = true
			// Read the payload directly: an accessor call on the loop's copy of
			// the command makes current V move that copy to the heap.
			if command.svg_data != unsafe { nil } {
				data := command.svg_data
				// The individual gradient bridge does not implement vector-effect.
				if (data.svg_gradient_data != none && data.non_scaling_stroke) || data.fill_pattern != none
					|| data.stroke_pattern != none || data.stroke_dasharray.len > 0 {
					return false, false
				}
			}
		}
		'paint_nested_display_list' {
			paintable := command.nested_viewport_paintable or { return false, false }
			if !chromium_svg_image_can_share_recording(command)
				|| paintable.border_radii != painting.BorderRadiiData{} {
				return false, false
			}
			has_vectors = true
		}
		else { return false, false }
	}
	if command.image_data != unsafe { nil } {
		url := command.image_data.image_url.to_lower()
		if url.starts_with('data:image/svg+xml') || url.all_before('?').ends_with('.svg') {
			has_vectors = true
		}
	}
	return true, has_vectors
}

fn chromium_shared_recording_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	indices := layer.command_indices
	if layer.legacy_raster || indices.len < 3 { return false }
	mut scope := u64(0)
	mut has_shared_content := false
	mut svg_end := 0
	for position, command_index in indices {
		if command_index < 0 || command_index >= commands.len
			|| plan.command_layers[command_index] != index
			|| (position > 0 && command_index != indices[position - 1] + 1) {
			return false
		}
		command := unsafe { &commands[command_index] }
		if position == 0 || position == indices.len - 1 {
			expected := if position == 0 {
				'begin_css_effect_layer'
			} else {
				'end_css_effect_layer'
			}
			data := command.visual_layer_data or { return false }
			if command.kind != expected || data.kind != .css_effect || data.blend_mode != .normal
				|| data.scope_id == 0 || command.has_clip || command.clip_list != unsafe { nil }
				|| command.clip_outs.len > 0 {
				return false
			}
			if position == 0 {
				scope = data.scope_id
			} else if data.scope_id != scope {
				return false
			}
			continue
		}
		if command_index < svg_end { continue }
		svg_end = chromium_svg_rectangular_mask_end(commands, plan.command_layers, command_index)
		if svg_end == command_index {
			svg_end = chromium_svg_solid_run_end(commands, plan.command_layers, command_index)
		}
		if svg_end > command_index {
			has_shared_content = true
			continue
		}
		// Shadows must draw directly into the same isolated surface as their
		// contents. A separately rounded shadow bitmap changes overlapping blur
		// pixels. External clips and legacy shadow commands keep their fallback.
		if command.kind == 'paint_outer_box_shadow' {
			if command.box_shadow_data == unsafe { nil } || command.has_clip
				|| command.clip_list != unsafe { nil } || command.clip_outs.len > 0 {
				return false
			}
			has_shared_content = true
			continue
		}
		supported, vectors := chromium_shared_recording_leaf_supported(command)
		if !supported { return false }
		has_shared_content = has_shared_content || vectors
	}
	return has_shared_content
}
