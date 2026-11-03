module main

import layout
import math
import os

fn chromium_compositor_ink_union(a layout.LayoutRect, b layout.LayoutRect) layout.LayoutRect {
	x := math.min(a.x, b.x)
	y := math.min(a.y, b.y)
	return layout.LayoutRect{x, y, math.max(a.x + a.width, b.x + b.width) - x, math.max(a.y + a.height, b.y + b.height) - y}
}

fn chromium_compositor_ink_overlaps(a layout.LayoutRect, b layout.LayoutRect) bool {
	// Retain the native leaf's raster fringe at both edges.
	return a.x - 3 < b.x + b.width + 3 && b.x - 3 < a.x + a.width + 3
		&& a.y - 3 < b.y + b.height + 3 && b.y - 3 < a.y + a.height + 3
}

// The ordinary culling bounds deliberately exclude SVG paths and native border
// rings. Bound their actual supported geometry here, without widening culling
// eligibility elsewhere in the player.
fn chromium_compositor_gap_ink(command &layout.PaintCommand) ?layout.LayoutRect {
	if command.kind == 'draw_video' {
		// Frames and posters are clipped to the retained video's viewport,
		// independently of their fitted destination or current frame. Keep a
		// pixel for the device-rectangle rounding performed by VideoPaintable.
		video := command.video_paintable or { return none }
		if command.outer_shadow || command.blur != 0 { return none }
		rect := video.video_rect
		normalized := layout.PaintCommand{
			...*command
			kind: 'fill_rect'
			x: rect.x - 1
			y: rect.y - 1
			width: rect.width + 2
			height: rect.height + 2
		}
		return layout.paint_leaf_native_ink_bounds(&normalized)
	}
	if command.kind == 'paint_inner_box_shadow' {
		data := command.box_shadow_data
		if data == unsafe { nil } || math.is_nan(command.blur) || math.is_inf(command.blur, 0) {
			return none
		}
		// Native inner shadows clip their blurred caster to this content rectangle.
		// The outer caster and blur radius cannot extend the output beyond it.
		rect := data.content_rect
		normalized := layout.PaintCommand{
			...*command
			kind:   'fill_rect'
			blur:   0
			x:      rect.x
			y:      rect.y
			width:  rect.width
			height: rect.height
		}
		return layout.paint_leaf_native_ink_bounds(&normalized)
	}

	if command.kind == 'paint_uniform_border' {
		normalized := layout.PaintCommand{ ...*command, kind: 'stroke_rounded_rect', points: []f64{} }
		return layout.paint_leaf_native_ink_bounds(&normalized)
	}
	if command.kind != 'draw_svg_path' { return layout.paint_leaf_native_ink_bounds(command) }
	if !chromium_svg_solid_path_supported(command) { return none }
	return layout.paint_svg_path_native_ink_bounds(command)
}

// Native replay flushes an isolated parent before intervening contents and
// creates a fresh surface when the parent resumes. This is equivalent
// to one parent picture only when its two spans cannot blend with each other,
// and the resumed span cannot cover the child that Chromium paints above it.
fn chromium_compositor_gap_can_flush_parent(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, parent int, start int, end int,
	viewport layout.LayoutRect) bool {
	if parent <= 0 || parent >= plan.layers.len
		|| plan.command_layers.len != commands.len || start < 0 || end <= start
		|| end > commands.len || viewport.width <= 0 || viewport.height <= 0 {
		return false
	}
	for value in [viewport.x, viewport.y, viewport.width, viewport.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
	if chromium_opaque_compositor_effect_gap(commands,plan,parent,start,end) { return true }
	if !plan.has_paint_metadata { return false }
	if chromium_opaque_compositor_mask_gap(commands, plan, parent, start, end) { return true }
	mut before := layout.LayoutRect{}
	mut after := layout.LayoutRect{}
	mut before_ink := []layout.LayoutRect{}
	mut after_ink := []layout.LayoutRect{}
	mut has_before := false
	mut has_after := false
	for index in plan.layers[parent].command_indices {
		if index < 0 || index >= commands.len || plan.command_layers[index] != parent
			|| (index >= start && index < end) {
			return false
		}
		command := unsafe { &commands[index] }
		if chromium_compositor_leaf_is_culled(command,viewport) { continue }
		if command.fixed_to_viewport || command.visual_layer_data != none
			|| command.kind.starts_with('begin_') || command.kind.starts_with('end_') {
			return false
		}
		ink := chromium_compositor_gap_ink(command) or {
			if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
				eprintln('VOX_PAINT_GAP_UNBOUNDED command=${index} xywh=${command.x},${command.y},${command.width},${command.height} clip=${command.has_clip}:${command.clip_x},${command.clip_y},${command.clip_width},${command.clip_height}')
			}
			return chromium_svg_compositor_layer_declined(parent, index, 'parent gap ink', command.kind)
		}
		if ink.width <= 0 || ink.height <= 0 || ink.x > viewport.width + 3
			|| ink.y > viewport.height + 3 || ink.x + ink.width < -3
			|| ink.y + ink.height < -3 {
			continue
		}
		if index < start {
			before = if has_before { chromium_compositor_ink_union(before, ink) } else { ink }
			has_before = true
			before_ink << ink
		} else {
			after = if has_after { chromium_compositor_ink_union(after, ink) } else { ink }
			has_after = true
			after_ink << ink
		}
	}
	// A completed prefix can publish before any balanced child effect when
	// the resumed parent has no viewport ink. The child still executes in its
	// original order, even if its filter moves pixels into the viewport.
	if !has_after { return chromium_compositor_gap_has_balanced_scopes(commands,start,end) }
	if has_before && has_after && chromium_compositor_ink_overlaps(before, after) {
		// A union fills holes between otherwise disjoint parent leaves, for
		// example a footer background recorded before the intervening contents.
		for prefix in before_ink {
			for suffix in after_ink {
				if chromium_compositor_ink_overlaps(prefix, suffix) {
					if os.getenv('VOX_DIAGNOSTIC_PAINT_LAYER') != '' {
						eprintln('VOX_PAINT_GAP_OVERLAP prefix=${prefix.x},${prefix.y},${prefix.width},${prefix.height} suffix=${suffix.x},${suffix.y},${suffix.width},${suffix.height}')
					}
					return chromium_svg_compositor_layer_declined(parent, start, 'parent spans overlap', '')
				}
			}
		}
	}

	mut masks := []u64{}
	mut mask_owners := []int{}
	for index in start .. end {
		owner := plan.command_layers[index]
		if owner < 0 { continue }
		if owner == parent || owner >= plan.layers.len { return false }
		child := plan.layers[owner]
		command := unsafe { &commands[index] }
		if command.fixed_to_viewport { return false }
		if command.kind in ['begin_svg_mask_layer', 'end_svg_mask_layer'] {
			// A complete SVG mask only removes its children's pixels. Their
			// bounded ink can prove separation without treating a resource or
			// filter scope as an independently drawable leaf.
			mask := command.visual_layer_data or { return false }
			if !child.legacy_raster || mask.kind != .svg_mask || mask.scope_id == 0
				|| mask.opacity != 1 || mask.blend_mode != .normal || mask.filter != none {
				return false
			}
			if command.kind == 'begin_svg_mask_layer' {
				if mask_owners.len > 0 && mask_owners.last() != owner { return false }
				masks << u64(mask.scope_id)
				mask_owners << owner
			} else {
				if masks.len == 0 || masks.last() != u64(mask.scope_id)
					|| mask_owners.last() != owner { return false }
				masks.delete_last()
				mask_owners.delete_last()
			}
			continue
		}
		masked := mask_owners.len > 0 && mask_owners.last() == owner
		if mask_owners.len > 0 && !masked { return false }
		if chromium_compositor_leaf_is_culled(command, viewport) { continue }
		scrollbar := command.scrollbar_axis != '' && command.kind in [
			'fill_rounded_rect',
			'stroke_rounded_rect',
		]
		if (owner != 0 && !child.scroll_contents && !scrollbar && !masked)
			|| (child.legacy_raster && !masked)
			|| command.visual_layer_data != none || command.kind.starts_with('begin_')
			|| command.kind.starts_with('end_') {
			return chromium_svg_compositor_layer_declined(parent, index, 'gap child properties', command.kind)
		}
		// Root leaves and scrollbars can belong to a layer spanning the whole
		// page. Check their actual bounded ink instead of that union. A mask's
		// output likewise cannot extend beyond its bounded children.
		bounds := if owner == 0 || scrollbar || masked {
			chromium_compositor_gap_ink(command) or { return false }
		} else {
			layout.LayoutRect{child.bounds.x - viewport.x, child.bounds.y - viewport.y, child.bounds.width, child.bounds.height}
		}
		for value in [bounds.x, bounds.y, bounds.width, bounds.height] {
			if math.is_nan(value) || math.is_inf(value, 0) { return false }
		}
		if bounds.width <= 0 || bounds.height <= 0 { return false }
		if has_after && chromium_compositor_ink_overlaps(bounds, after) {
			return chromium_svg_compositor_layer_declined(parent, index, 'gap child overlaps resumed parent', command.kind)
		}
	}
	return masks.len == 0
}
