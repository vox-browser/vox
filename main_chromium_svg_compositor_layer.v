module main

import layout
import os
import math

fn chromium_svg_compositor_clip_outs_supported(command &layout.PaintCommand) bool {
	if command.clip_outs.len == 0 { return true }
	// Text-decoration skip-ink rectangles already replay in the local fill
	// coordinates. They do not sample the parent or require another resource.
	if command.kind != 'fill_rect' || command.clip_outs.len % 4 != 0
		|| command.clip_outs.len > 32768 { return false }
	for value in command.clip_outs {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	for offset := 0; offset < command.clip_outs.len; offset += 4 {
		if command.clip_outs[offset + 2] < command.clip_outs[offset]
			|| command.clip_outs[offset + 3] < command.clip_outs[offset + 1] { return false }
	}
	return true
}

fn chromium_svg_opacity_group_end(commands []layout.PaintCommand, start int) int {
	if start < 0 || start + 2 >= commands.len || commands[start].kind != 'begin_css_effect_layer'
		|| commands[start + 2].kind != 'end_css_effect_layer' {
		return start
	}
	layer := commands[start].visual_layer_data or { return start }
	end_layer := commands[start + 2].visual_layer_data or { return start }
	if layer.kind != .css_effect || layer.opacity <= 0 || layer.opacity >= 1
		|| layer.blend_mode != .normal || layer.filter != none || layer.scope_id == 0
		|| end_layer.scope_id != layer.scope_id || end_layer.kind != layer.kind {
		return start
	}
	inner := unsafe { &commands[start + 1] }
	if (inner.opacity != 1 && f32(inner.opacity) != f32(layer.opacity))
		|| f32(inner.group_opacity) != f32(layer.opacity)
		|| inner.blur != 0 || inner.outer_shadow || inner.scrollbar_axis != ''
		|| !chromium_shared_recording_clips_supported(inner) {
		return start
	}
	// Check the ordinary solid-path payload without changing retained opacity.
	// Replay still applies that opacity once through the balanced native scope.
	normalized := layout.PaintCommand{...*inner, opacity:1, group_opacity:1}
	if !chromium_svg_solid_path_supported(&normalized) { return start }
	return start + 3
}

// Rasterize SVG and CSS gradient contents with their backgrounds and glyphs before
// blending the layer over its parent. Isolating each path loses painted sibling
// backgrounds; reading the parent directly loses premultiplied edge rounding.
// Complex CSS scopes and layers interrupted by other drawing retain their
// existing replay path; culled gaps contain no drawing to reorder.
fn chromium_svg_identity_scope_end(commands []layout.PaintCommand, layers []int, start int) int {
	if start < 0 || start >= commands.len || layers.len != commands.len { return start }
	opening := &commands[start]
	data := opening.visual_layer_data or { return start }
	if opening.kind != 'begin_css_effect_layer' || data.kind != .css_effect
		|| data.opacity != 1 || data.blend_mode != .normal || data.filter != none
		|| data.scope_id == 0 || opening.has_clip || opening.clip_list != unsafe { nil }
		|| opening.clip_outs.len != 0 || opening.recording_clip != none { return start }
	mut scopes := []u64{}
	for index in start .. commands.len {
		command := &commands[index]
		if command.kind !in ['begin_css_effect_layer','end_css_effect_layer'] { continue }
		boundary := command.visual_layer_data or { return start }
		if boundary.kind != .css_effect || boundary.scope_id == 0 { return start }
		if command.kind == 'begin_css_effect_layer' { scopes << u64(boundary.scope_id); continue }
		if scopes.len == 0 || scopes.last() != u64(boundary.scope_id) { return start }
		scopes.delete_last()
		if scopes.len != 0 { continue }
		if layers[index] != layers[start] || boundary.opacity != 1 || boundary.blend_mode != .normal
			|| boundary.filter != none || command.has_clip || command.clip_list != unsafe { nil }
			|| command.clip_outs.len != 0 || command.recording_clip != none { return start }
		return index+1
	}
	return start
}

fn chromium_svg_compositor_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	return chromium_svg_compositor_layer_supported_for_viewport(commands, plan, index, none)
}

fn chromium_svg_compositor_layer_declined(layer int, command int, reason string, kind string) bool {
	if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
		eprintln('VOX_PAINT_LAYER_DECLINED layer=${layer} command=${command} reason=${reason} kind=${kind}')
	}
	return false
}

fn chromium_svg_compositor_layer_supported_for_viewport(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int, viewport ?layout.LayoutRect) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	if layer.legacy_raster || !layer.composited_contents || layer.command_indices.len == 0 {
		return false
	}
	first := layer.command_indices.first()
	last := layer.command_indices.last()
	if first < 0 || last >= commands.len
		|| (first > 0 && plan.command_layers[first - 1] == index)
		|| (last + 1 < commands.len && plan.command_layers[last + 1] == index) {
		return false
	}
	mut has_svg := false
	mut has_text := false
	mut opacity_end := -1
	mut identity_scope_ends := []int{}
	for position, command_index in layer.command_indices {
		if command_index < first || command_index > last
			|| plan.command_layers[command_index] != index {
			return false
		}
		if position > 0 {
			previous := layer.command_indices[position - 1]
			if command_index <= previous { return false }
			for gap in previous + 1 .. command_index {
				owner := plan.command_layers[gap]
				if owner < 0 { continue }
				rect := viewport or { return false }
				if owner == index || owner >= plan.layers.len || !plan.has_paint_metadata {
					return false
				}
				// Native replay culls these ordinary leaves before selecting
				// their layer. They cannot interrupt the parent's recording,
				// including backgrounds with a larger hit-test extent.
				leaf := unsafe { &commands[gap] }
				if !leaf.fixed_to_viewport && leaf.visual_layer_data == none
					&& !leaf.kind.starts_with('begin_') && !leaf.kind.starts_with('end_')
					&& layout.paint_leaf_is_outside_canvas(leaf, 0, 0, rect.width, rect.height) {
					continue
				}
				child := plan.layers[owner]
				bounds := child.bounds
				if !child.scroll_contents || child.legacy_raster
					|| commands[gap].fixed_to_viewport || commands[gap].visual_layer_data != none
					|| (bounds.x < rect.x + rect.width && bounds.x + bounds.width > rect.x
						&& bounds.y < rect.y + rect.height && bounds.y + bounds.height > rect.y) {
					if chromium_compositor_gap_can_flush_parent(commands, plan, index,
						previous + 1, command_index, rect) { break }
					return chromium_svg_compositor_layer_declined(index, gap, 'interleaved layer', commands[gap].kind)
				}
			}
		}
		if command_index < opacity_end { continue }
		command := unsafe { &commands[command_index] }
		if rect := viewport {
			if chromium_compositor_leaf_is_culled(command, rect) { continue }
		}
		contoured_shadow := command.kind == 'paint_outer_box_shadow' && chromium_contoured_box_supported(command)
		recorded_shadow := contoured_shadow || (!disable_complete_shadow_pictures
			&& chromium_complete_outer_shadow_supported(command))
		if command.opacity != 1 || command.group_opacity != 1
			|| (command.blur != 0 && !recorded_shadow)
			|| command.outer_shadow || !chromium_svg_compositor_clip_outs_supported(command)
			|| command.scrollbar_axis != ''
			|| !chromium_shared_recording_clips_supported(command) {
			return chromium_svg_compositor_layer_declined(index, command_index, 'leaf properties', command.kind)
		}
		had_svg := has_svg
		match command.kind {
			'fill_gradient' {
				if !plan.has_paint_metadata || !chromium_compositor_css_gradient_supported(command) {
					return chromium_svg_compositor_layer_declined(index, command_index, 'CSS gradient', command.kind)
				}
				has_svg = true
			}
			'paint_outer_box_shadow' {
				if !recorded_shadow { return chromium_svg_compositor_layer_declined(index,command_index,'unrecorded leaf',command.kind) }
				has_svg = true
			}
			'paint_inner_box_shadow' {
				supported, _ := chromium_shared_recording_leaf_supported(command)
				if !supported { return chromium_svg_compositor_layer_declined(index,command_index,'unrecorded leaf',command.kind) }
			}
			'begin_css_effect_layer' {
				identity_end := chromium_svg_identity_scope_end(commands,plan.command_layers,command_index)
				if identity_end > command_index { identity_scope_ends << identity_end-1; continue }
				opacity_end = chromium_svg_opacity_group_end(commands, command_index)
				if opacity_end <= command_index || opacity_end > last + 1 { return false }
				has_svg = true
			}
			'end_css_effect_layer' {
				if identity_scope_ends.len == 0 || identity_scope_ends.last() != command_index { return chromium_svg_compositor_layer_declined(index,command_index,'unbalanced effect',command.kind) }
				identity_scope_ends.delete_last()
			}
			'draw_svg_path' {
				if !chromium_svg_compositor_path_supported(command) {
					return chromium_svg_compositor_layer_declined(index, command_index, 'SVG path', command.kind)
				}
				has_svg = true
			}
			'paint_nested_display_list' {
				if !layout.chromium_nested_svg_raster_supported(command) { return false }
				has_svg = true
			}
			'draw_replaced_image', 'draw_svg_image', 'draw_background_image' {
				supported, _ := chromium_shared_recording_leaf_supported(command)
				if !supported { return chromium_svg_compositor_layer_declined(index,command_index,'unrecorded leaf',command.kind) }
			}
			'fill_rect', 'fill_rounded_rect', 'paint_uniform_border' {
				has_svg = has_svg || chromium_contoured_box_supported(command)
			}
			'draw_video' {
				// With no frame source or retained bitmap, draw_command returns
				// before painting any video pixels. Recheck on every replay.
				if disable_complete_shadow_pictures || command.video_frame_source != none
					|| command.video_bitmap != none {
					return chromium_svg_compositor_layer_declined(index, command_index, 'live video', command.kind)
				}
			}
			'draw_text' { has_text = true }
			'fill_ellipse', 'stroke_ellipse', 'stroke_rounded_rect' {}
			else { return chromium_svg_compositor_layer_declined(index, command_index, 'unsupported leaf', command.kind) }
		}
		if has_svg && !had_svg && os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
			eprintln('VOX_PAINT_LAYER_RECORDING_FEATURE layer=${index} command=${command_index} kind=${command.kind} xywh=${command.x},${command.y},${command.width},${command.height} transform=${command.transform}')
		}
	}
	// Culling a distant vector does not remove the promoted layer's
	// transparency boundary. Text still rounds against that transparent
	// surface before blending over the parent, including across safe gaps.
	return (has_svg || has_text) && identity_scope_ends.len == 0
}
