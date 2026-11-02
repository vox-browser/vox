module main

import layout
import math
import painting

fn C.native_set_chromium_shared_recording(i32, i32, i32)
fn C.native_set_chromium_layer_shared_recording(i32)

// Root recording requires a supported prefix; independent compositor layers
// may split full-opacity scopes while retaining isolated translucent scopes.
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
		if plan.command_layers[index] < 0 { continue }
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
	mut has_vectors := chromium_contoured_box_supported(command)
		&& command.kind in ['fill_rect','fill_rounded_rect','paint_uniform_border']
	// Native replay discards ordinary leaves with an empty clip before
	// drawing. Hidden accessible controls must not disable the recording;
	// effect boundaries still need their existing balanced replay path.
	if command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0)
		&& !command.kind.starts_with('begin_') && !command.kind.starts_with('end_') {
		return true, false
	}
	if !chromium_shared_recording_clips_supported(command)
		|| command.clip_outs.len > 0 || command.outer_shadow {
		return false, false
	}
	if command.kind == 'paint_outer_box_shadow' && chromium_contoured_box_supported(command) {
		data := command.box_shadow_data
		if data == unsafe { nil } || command.width <= 0 || command.height <= 0
			|| data.content_rect.width <= 0 || data.content_rect.height <= 0
			|| command.blur < 0 || math.is_nan(command.blur) || math.is_inf(command.blur,0) {
			return false,false
		}
		return true,true
	}
	if command.kind == 'paint_inner_box_shadow' {
		data := command.box_shadow_data
		if data == unsafe { nil } || command.width <= 0 || command.height <= 0
			|| data.content_rect.width <= 0 || data.content_rect.height <= 0 {
			return false, false
		}
		return true, true
	}
	if command.blur != 0 { return false, false }
	match command.kind {
		'draw_background_image' {
			data := command.image_data
			if chromium_svg_background_can_share_recording(command) { return true, true }
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
		'paint_rounded_border_top', 'paint_rounded_border_right', 'paint_rounded_border_bottom',
		'paint_rounded_border_left', 'paint_partial_rounded_border' {
			// The rounded-rectangle bridge records these four side widths in
			// the same picture as the background and any SVG contents.
			if command.points.len != 4 { return false, false }
			for width in command.points {
				if width < 0 || math.is_nan(width) || math.is_inf(width, 0) { return false, false }
			}
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

// Full-opacity compositor boundaries may span raster layers. Genuine effects
// still require one complete isolated run.
fn chromium_shared_recording_css_boundary(commands []layout.PaintCommand, index int) bool {
	command := commands[index]
	data := command.visual_layer_data or { return false }
	if command.kind !in ['begin_css_effect_layer', 'end_css_effect_layer']
		|| data.kind != .css_effect || data.blend_mode != .normal || data.scope_id == 0
		|| command.has_clip || command.clip_list != unsafe { nil } || command.clip_outs.len > 0 {
		return false
	}
	step := if command.kind == 'begin_css_effect_layer' { 1 } else { -1 }
	expected := if step == 1 { 'end_css_effect_layer' } else { 'begin_css_effect_layer' }
	mut other := index + step
	for other >= 0 && other < commands.len {
		partner := commands[other]
		if partner_data := partner.visual_layer_data {
			if partner_data.scope_id == data.scope_id {
				return partner.kind == expected
					&& partner_data.kind == .css_effect && partner_data.blend_mode == .normal
					&& partner_data.opacity == data.opacity && !partner.has_clip
					&& partner.clip_list == unsafe { nil } && partner.clip_outs.len == 0
			}
		}
		other += step
	}
	return false
}

// A full-opacity parent picture can resume after another layer's complete CSS
// effect. Native replay flushes before entering the child and restores the
// parent's destination/backdrop policy when that effect ends. No other scope
// may straddle the gap, and omitted parent commands must never be skipped.
fn chromium_shared_recording_child_gap_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, parent int, start int, end int) bool {
	mut scopes := []int{}
	for command_index in start .. end {
		owner := plan.command_layers[command_index]
		if owner <= 0 || owner >= plan.layers.len || owner == parent { return false }
		command := commands[command_index]
		if command.kind == 'begin_css_effect_layer' {
			data := command.visual_layer_data or { return false }
			if data.kind != .css_effect || data.scope_id == 0 { return false }
			for opening in scopes {
				other := commands[opening].visual_layer_data or { return false }
				if other.scope_id == data.scope_id { return false }
			}
			scopes << command_index
		} else if command.kind == 'end_css_effect_layer' {
			if scopes.len == 0 { return false }
			opening := commands[scopes.pop()].visual_layer_data or { return false }
			closing := command.visual_layer_data or { return false }
			if closing.kind != .css_effect || closing.scope_id != opening.scope_id
				|| closing.opacity != opening.opacity || closing.blend_mode != opening.blend_mode {
				return false
			}
		} else if scopes.len == 0 || command.kind.starts_with('begin_')
			|| command.kind.starts_with('end_') {
			return false
		}
	}
	return scopes.len == 0
}

fn chromium_shared_recording_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	indices := layer.command_indices
	if layer.legacy_raster || indices.len == 0 { return false }
	first := indices.first()
	last := indices.last()
	if first < 0 || first >= commands.len || last < first || last >= commands.len
		|| (first > 0 && plan.command_layers[first - 1] == index)
		|| (last + 1 < commands.len && plan.command_layers[last + 1] == index) { return false }
	// Only CSS scopes install the native destination/backdrop policy used by
	// these pictures. A scroll or sparsity layer alone must keep leaf replay.
	mut closed_scopes := 0
	mut scope_depth := 0
	for prior := first - 1; prior >= 0; prior-- {
		command := commands[prior]
		if command.kind == 'end_css_effect_layer' { closed_scopes++ }
		if command.kind != 'begin_css_effect_layer' { continue }
		if closed_scopes > 0 {
			closed_scopes--
			continue
		}
		data := command.visual_layer_data or { return false }
		if data.opacity != 1 || !chromium_shared_recording_css_boundary(commands, prior) { return false }
		scope_depth++
	}
	if closed_scopes != 0 { return false }
	mut has_shared_content := false
	mut svg_end := 0
	mut isolated_scope := false
	for position, command_index in indices {
		if command_index < 0 || command_index >= commands.len
			|| plan.command_layers[command_index] != index
			|| (position > 0 && command_index <= indices[position - 1]) {
			return false
		}
		if position > 0 && command_index != indices[position - 1] + 1 {
			if scope_depth == 0 || isolated_scope
				|| !chromium_shared_recording_child_gap_supported(commands, plan, index,
					indices[position - 1] + 1, command_index) { return false }
		}
		command := unsafe { &commands[command_index] }
		if scope_depth == 0
			&& command.kind !in ['begin_css_effect_layer', 'end_css_effect_layer'] {
			return false
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
		if command.kind in ['begin_css_effect_layer', 'end_css_effect_layer'] {
			if !chromium_shared_recording_css_boundary(commands, command_index) { return false }
			if command.kind == 'begin_css_effect_layer' {
				scope_depth++
			} else {
				if scope_depth == 0 { return false }
				scope_depth--
			}
			data := command.visual_layer_data or { return false }
			if data.opacity != 1 {
				isolated_scope = command.kind == 'begin_css_effect_layer'
				if position == 0 && command.kind == 'begin_css_effect_layer' {
					end_data := commands[last].visual_layer_data or { return false }
					if commands[last].kind != 'end_css_effect_layer' || end_data.scope_id != data.scope_id { return false }
				} else if position == indices.len - 1 && command.kind == 'end_css_effect_layer' {
					begin_data := commands[first].visual_layer_data or { return false }
					if commands[first].kind != 'begin_css_effect_layer' || begin_data.scope_id != data.scope_id { return false }
				} else { return false }
			}
			continue
		}
		if scope_depth == 0 { return false }
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
		if plan.has_paint_metadata && chromium_compositor_css_gradient_supported(command) {
			has_shared_content = true
			continue
		}
		supported, vectors := chromium_shared_recording_leaf_supported(command)
		if !supported { return false }
		has_shared_content = has_shared_content || vectors
	}
	return has_shared_content
}
