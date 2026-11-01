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

// Native replay flushes an isolated parent before an independently scrolling
// child and creates a fresh surface when the parent resumes. This is equivalent
// to one parent picture only when its two spans cannot blend with each other,
// and the resumed span cannot cover the child that Chromium paints above it.
fn chromium_compositor_gap_can_flush_parent(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, parent int, start int, end int,
	viewport layout.LayoutRect) bool {
	if !plan.has_paint_metadata || parent <= 0 || parent >= plan.layers.len
		|| plan.command_layers.len != commands.len || start < 0 || end <= start
		|| end > commands.len || viewport.width <= 0 || viewport.height <= 0 {
		return false
	}
	for value in [viewport.x, viewport.y, viewport.width, viewport.height] {
		if math.is_nan(value) || math.is_inf(value, 0) { return false }
	}
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

	for index in start .. end {
		owner := plan.command_layers[index]
		if owner < 0 { continue }
		if owner == parent || owner >= plan.layers.len { return false }
		child := plan.layers[owner]
		command := unsafe { &commands[index] }
		scrollbar := command.scrollbar_axis != '' && command.kind in [
			'fill_rounded_rect',
			'stroke_rounded_rect',
		]
		if (!child.scroll_contents && !scrollbar) || child.legacy_raster || command.fixed_to_viewport
			|| command.visual_layer_data != none || command.kind.starts_with('begin_')
			|| command.kind.starts_with('end_') {
			return chromium_svg_compositor_layer_declined(parent, index, 'gap child properties', command.kind)
		}
		// A scrollbar's layer can aggregate distant scrollports. Its individual
		// rounded leaf owns the ink at this gap, rather than that union.
		bounds := if scrollbar {
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
	return true
}
